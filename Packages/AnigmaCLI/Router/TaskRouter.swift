//
//  TaskRouter.swift
//  AnigmaCLIRouter
//
//  Routing policy and provider selection for the CLI orchestrator.
//

import AnigmaCLICore
import AnigmaCLIProviders
import Foundation

public struct RoutingPolicy: Sendable, Codable {
    public let localFirst: Bool
    public let allowExternalCLI: Bool
    public let allowCloudFallback: Bool

    public init(localFirst: Bool, allowExternalCLI: Bool, allowCloudFallback: Bool) {
        self.localFirst = localFirst
        self.allowExternalCLI = allowExternalCLI
        self.allowCloudFallback = allowCloudFallback
    }

    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> RoutingPolicy {
        let allowExternal = RoutingPolicy.boolValue(from: environment, key: "ANIGMA_EXTERNAL_CLIS_ENABLE", defaultValue: true)
        let allowCloud = RoutingPolicy.boolValue(from: environment, key: "ANIGMA_CLOUD_ENABLE", defaultValue: true)
        return RoutingPolicy(localFirst: true, allowExternalCLI: allowExternal, allowCloudFallback: allowCloud)
    }

    private static func boolValue(from environment: [String: String], key: String, defaultValue: Bool) -> Bool {
        guard let raw = environment[key]?.lowercased(), !raw.isEmpty else {
            return defaultValue
        }
        switch raw {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }
}

public struct RouteDecision: Sendable, Codable {
    public let taskId: UUID
    public let requiredCapabilities: [ProviderCapability]
    public let selected: ProviderDescriptor?
    public let candidates: [ProviderDescriptor]
    public let policy: RoutingPolicy
    public let reason: String

    public init(
        taskId: UUID,
        requiredCapabilities: [ProviderCapability],
        selected: ProviderDescriptor?,
        candidates: [ProviderDescriptor],
        policy: RoutingPolicy,
        reason: String
    ) {
        self.taskId = taskId
        self.requiredCapabilities = requiredCapabilities
        self.selected = selected
        self.candidates = candidates
        self.policy = policy
        self.reason = reason
    }
}

public struct TaskRouter: Sendable {
    private let registry: ProviderRegistry
    private let policy: RoutingPolicy

    public init(
        registry: ProviderRegistry,
        policy: RoutingPolicy = .fromEnvironment()
    ) {
        self.registry = registry
        self.policy = policy
    }

    public func route(
        task: TaskIntent,
        requiredCapabilities: Set<ProviderCapability>
    ) -> RouteDecision {
        var candidates = registry.availableProviders(required: requiredCapabilities)
        candidates = filterByPolicy(candidates)
        let sorted = candidates.sorted(by: providerSort)
        let selection = sorted.first
        let reason: String
        if let selection {
            reason = "Selected \(selection.id) with local-first policy."
        } else {
            reason = "No available providers matched required capabilities."
        }

        return RouteDecision(
            taskId: task.id,
            requiredCapabilities: requiredCapabilities.sorted { $0.rawValue < $1.rawValue },
            selected: selection,
            candidates: sorted,
            policy: policy,
            reason: reason
        )
    }

    private func filterByPolicy(_ providers: [ProviderDescriptor]) -> [ProviderDescriptor] {
        providers.filter { provider in
            switch provider.kind {
            case .local:
                return true
            case .cliWrapper:
                return policy.allowExternalCLI
            case .cloud:
                return policy.allowCloudFallback
            }
        }
    }

    private func providerSort(lhs: ProviderDescriptor, rhs: ProviderDescriptor) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }

        let lhsRank = kindRank(lhs.kind)
        let rhsRank = kindRank(rhs.kind)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        return lhs.displayName < rhs.displayName
    }

    private func kindRank(_ kind: ProviderKind) -> Int {
        guard policy.localFirst else {
            return 0
        }

        switch kind {
        case .local:
            return 0
        case .cliWrapper:
            return 1
        case .cloud:
            return 2
        }
    }
}
