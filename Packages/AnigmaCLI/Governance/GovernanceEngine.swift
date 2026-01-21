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

    public init(allowed: Bool, issues: [GovernanceIssue]) {
        self.allowed = allowed
        self.issues = issues
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

        if task.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(GovernanceIssue(severity: .error, message: "Task summary is empty."))
        }

        if contract.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(GovernanceIssue(severity: .error, message: "Contract objective is empty."))
        }

        if contract.requirements.isEmpty {
            issues.append(GovernanceIssue(severity: .error, message: "Contract has no requirements."))
        }

        let missingCriteria = missingBaselineCriteria(in: contract.acceptanceCriteria)
        if !missingCriteria.isEmpty {
            issues.append(
                GovernanceIssue(
                    severity: .error,
                    message: "Contract missing baseline acceptance criteria: \(missingCriteria.joined(separator: ", "))."
                )
            )
        }

        guard let provider else {
            issues.append(GovernanceIssue(severity: .error, message: "No provider selected for execution."))
            return GovernanceDecision(allowed: false, issues: issues)
        }

        let missingCapabilities = requiredCapabilities.subtracting(provider.capabilities)
        if !missingCapabilities.isEmpty {
            let missing = missingCapabilities.map { $0.rawValue }.sorted().joined(separator: ", ")
            issues.append(
                GovernanceIssue(
                    severity: .error,
                    message: "Provider \(provider.id) missing required capabilities: \(missing)."
                )
            )
        }

        let allowed = !issues.contains { $0.severity == .error }
        return GovernanceDecision(allowed: allowed, issues: issues)
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
