//
//  DelegateTool.swift
//  HarmoniaModule
//
//  Tool that allows the local orchestrator to delegate tasks to external CLI wrappers or cloud APIs.
//

import AnigmaPrimitives
import AnigmaCLICore
import AnigmaCLIProviders
import AnigmaCLIRouter
import Foundation

/// Input for the DelegateTool
public struct DelegateToolInput: Codable, Sendable {
    /// The summary of the task to delegate
    public let summary: String

    /// Optional detailed description of the task
    public let details: String?

    /// Optional provider ID to force (e.g., "cloud-deepseek")
    public let providerId: String?

    /// Required capabilities for the sub-task (e.g., ["chat", "tools"])
    public let requiredCapabilities: [String]?

    public init(
        summary: String,
        details: String? = nil,
        providerId: String? = nil,
        requiredCapabilities: [String]? = nil
    ) {
        self.summary = summary
        self.details = details
        self.providerId = providerId
        self.requiredCapabilities = requiredCapabilities
    }
}

/// Output of the DelegateTool
public struct DelegateToolOutput: Codable, Sendable {
    /// Whether a suitable provider was found
    public let providerFound: Bool

    /// The ID of the selected provider
    public let selectedProviderId: String?

    /// The display name of the selected provider
    public let selectedProviderName: String?

    /// The kind of provider (local, cliWrapper, cloud)
    public let providerKind: String?

    /// Message explaining the delegation result
    public let message: String

    public init(
        providerFound: Bool,
        selectedProviderId: String? = nil,
        selectedProviderName: String? = nil,
        providerKind: String? = nil,
        message: String
    ) {
        self.providerFound = providerFound
        self.selectedProviderId = selectedProviderId
        self.selectedProviderName = selectedProviderName
        self.providerKind = providerKind
        self.message = message
    }
}

/// Tool that enables local-to-cloud/cli delegation
public struct DelegateTool: Sendable {
    private let registry: ProviderRegistry
    private let router: TaskRouter

    public init(
        registry: ProviderRegistry = ProviderRegistry(),
        router: TaskRouter? = nil
    ) {
        self.registry = registry
        self.router = router ?? TaskRouter(registry: registry)
    }

    public func execute(_ request: ToolCallRequest, session: SessionContext) async -> ToolCallResponse {
        guard let input = try? JSONDecoder().decode(DelegateToolInput.self, from: Data(request.parameters.utf8)) else {
            return ToolCallResponse(
                status: .failed,
                toolName: "delegate",
                diagnosis: "Failed to parse DelegateToolInput from parameters."
            )
        }

        let taskIntent = TaskIntent(
            summary: input.summary,
            details: input.details,
            source: .cli
        )

        let capabilities = Set((input.requiredCapabilities ?? ["chat"]).compactMap { ProviderCapability(rawValue: $0) })

        // 1. If providerId is forced, check if it exists and is available
        if let forcedId = input.providerId {
            let available = registry.statuses().first { $0.descriptor.id == forcedId && $0.available }
            if let available {
                return respondWithSelection(available.descriptor, taskId: taskIntent.id)
            } else {
                return ToolCallResponse(
                    status: .failed,
                    toolName: "delegate",
                    diagnosis: "Forced provider '\(forcedId)' is not available or does not exist."
                )
            }
        }

        // 2. Use router to find best match (filtering out local if we want to force external/cloud)
        // By default, the router prefers local. If the orchestrator is already local,
        // it might want to delegate specifically to non-local providers.
        let decision = router.route(task: taskIntent, requiredCapabilities: capabilities)

        guard let selected = decision.selected else {
            return ToolCallResponse(
                status: .failed,
                toolName: "delegate",
                diagnosis: "No suitable provider found for delegation. \(decision.reason)"
            )
        }

        return respondWithSelection(selected, taskId: taskIntent.id)
    }

    private func respondWithSelection(_ provider: ProviderDescriptor, taskId: UUID) -> ToolCallResponse {
        let output = DelegateToolOutput(
            providerFound: true,
            selectedProviderId: provider.id,
            selectedProviderName: provider.displayName,
            providerKind: provider.kind.rawValue,
            message: "Delegation successful. Provider '\(provider.displayName)' (\(provider.id)) selected."
        )

        guard let data = try? JSONEncoder().encode(output) else {
            return ToolCallResponse(
                status: .failed,
                toolName: "delegate",
                diagnosis: "Failed to encode DelegateToolOutput."
            )
        }

        return ToolCallResponse(
            status: .success,
            result: data,
            toolName: "delegate",
            diagnosis: "Delegated task to \(provider.displayName) (\(provider.kind.rawValue))"
        )
    }
}
