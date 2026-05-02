//
//  GovernanceEngine.swift
//  AnigmaCLIGovernance
//
//  Governance checks for task contracts and routing decisions.
//

import AnigmaCLICore
import AnigmaCLIProviders
import Foundation

public enum GovernanceSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct GovernanceIssue: Sendable, Codable, Hashable {
    public let severity: GovernanceSeverity
    public let message: String

    public init(severity: GovernanceSeverity, message: String) {
        self.severity = severity
        self.message = message
    }
}

public struct GovernanceDecision: Sendable, Codable, Hashable {
    public let allowed: Bool
    public let issues: [GovernanceIssue]
    public let violation: GovernanceViolationPayload?

    public init(allowed: Bool, issues: [GovernanceIssue], violation: GovernanceViolationPayload? = nil) {
        self.allowed = allowed
        self.issues = issues
        self.violation = violation
    }
}

/// Lightweight violation payload for CLI-level governance decisions
public struct GovernanceViolationPayload: Sendable, Codable, Hashable {
    public let principal: String?
    public let projectId: String?
    public let operation: String
    public let module: String?
    public let evaluatedModeSource: String?
    public let failedCheckIds: [String]
    public let failedMessages: [String]
    public let timestamp: Date

    public init(
        principal: String?,
        projectId: String?,
        operation: String,
        module: String?,
        evaluatedModeSource: String?,
        failedCheckIds: [String],
        failedMessages: [String],
        timestamp: Date = Date()
    ) {
        self.principal = principal
        self.projectId = projectId
        self.operation = operation
        self.module = module
        self.evaluatedModeSource = evaluatedModeSource
        self.failedCheckIds = failedCheckIds
        self.failedMessages = failedMessages
        self.timestamp = timestamp
    }
}

public struct GovernanceEngine: Sendable {
    private let policy: ContractPolicy

    public init(policy: ContractPolicy = .default) {
        self.policy = policy
    }

    public func evaluate(
        task: TaskIntent,
        contract: TaskContract,
        provider: ProviderDescriptor?,
        requiredCapabilities: Set<ProviderCapability>
    ) -> GovernanceDecision {
        var issues: [GovernanceIssue] = []
        var failedCheckIds: [String] = []
        var failedMessages: [String] = []

        if task.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(GovernanceIssue(severity: .error, message: "Task summary is empty."))
            failedCheckIds.append("task-summary-empty")
            failedMessages.append("Task summary is empty.")
        }

        if contract.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(GovernanceIssue(severity: .error, message: "Contract objective is empty."))
            failedCheckIds.append("contract-objective-empty")
            failedMessages.append("Contract objective is empty.")
        }

        if contract.requirements.isEmpty {
            issues.append(GovernanceIssue(severity: .error, message: "Contract has no requirements."))
            failedCheckIds.append("contract-requirements-empty")
            failedMessages.append("Contract has no requirements.")
        }

        let missingCriteria = missingBaselineCriteria(in: contract.acceptanceCriteria)
        if !missingCriteria.isEmpty {
            let message = "Contract missing baseline acceptance criteria: \(missingCriteria.joined(separator: ", "))."
            issues.append(
                GovernanceIssue(
                    severity: .error,
                    message: message
                )
            )
            failedCheckIds.append("acceptance-criteria-incomplete")
            failedMessages.append(message)
        }

        guard let provider else {
            issues.append(GovernanceIssue(severity: .error, message: "No provider selected for execution."))
            failedCheckIds.append("no-provider-selected")
            failedMessages.append("No provider selected for execution.")
            
            let allowed = !issues.contains { $0.severity == .error }
            let violation = allowed ? nil : GovernanceViolationPayload(
                principal: nil,
                projectId: nil,
                operation: "execute-task",
                module: "governance-engine",
                evaluatedModeSource: nil,
                failedCheckIds: failedCheckIds,
                failedMessages: failedMessages
            )
            return GovernanceDecision(allowed: false, issues: issues, violation: violation)
        }

        let missingCapabilities = requiredCapabilities.subtracting(provider.capabilities)
        if !missingCapabilities.isEmpty {
            let missing = missingCapabilities.map { $0.rawValue }.sorted().joined(separator: ", ")
            let message = "Provider \(provider.id) missing required capabilities: \(missing)."
            issues.append(
                GovernanceIssue(
                    severity: .error,
                    message: message
                )
            )
            failedCheckIds.append("provider-capabilities-insufficient")
            failedMessages.append(message)
        }

        let allowed = !issues.contains { $0.severity == .error }
        let violation = allowed ? nil : GovernanceViolationPayload(
            principal: nil,
            projectId: nil,
            operation: "execute-task",
            module: "governance-engine",
            evaluatedModeSource: nil,
            failedCheckIds: failedCheckIds,
            failedMessages: failedMessages
        )
        return GovernanceDecision(allowed: allowed, issues: issues, violation: violation)
    }

    private func missingBaselineCriteria(in acceptance: [String]) -> [String] {
        let lowercased = acceptance.map { $0.lowercased() }
        return policy.bannedPatterns.compactMap { pattern in
            let token = pattern.token.lowercased()
            let hasToken = lowercased.contains { $0.contains(token) }
            return hasToken ? nil : pattern.token
        }
    }
}
