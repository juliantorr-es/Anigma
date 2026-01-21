//
//  ContractPolicy.swift
//  AnigmaCLIGovernance
//
//  Policy checks for contract enforcement.
//

import Foundation

public struct ContractPattern: Sendable, Codable, Hashable {
    public let token: String
    public let message: String

    public init(token: String, message: String) {
        self.token = token
        self.message = message
    }
}

public struct ContractViolation: Sendable, Codable, Hashable {
    public let token: String
    public let message: String

    public init(token: String, message: String) {
        self.token = token
        self.message = message
    }
}

public struct ContractEvaluation: Sendable, Codable, Hashable {
    public let passed: Bool
    public let violations: [ContractViolation]

    public init(passed: Bool, violations: [ContractViolation]) {
        self.passed = passed
        self.violations = violations
    }
}

public struct ContractPolicy: Sendable, Codable, Hashable {
    public let bannedPatterns: [ContractPattern]

    public init(bannedPatterns: [ContractPattern]) {
        self.bannedPatterns = bannedPatterns
    }

    public static let `default` = ContractPolicy(
        bannedPatterns: [
            ContractPattern(token: "todo", message: "TODO markers are not allowed."),
            ContractPattern(token: "fixme", message: "FIXME markers are not allowed."),
            ContractPattern(token: "stub", message: "Stub placeholders are not allowed."),
            ContractPattern(token: "quick fix", message: "Quick-fix phrasing is not allowed."),
            ContractPattern(token: "commented out", message: "Commented-out code is not allowed.")
        ]
    )

    public func evaluate(text: String) -> ContractEvaluation {
        let lowercased = text.lowercased()
        let violations = bannedPatterns.compactMap { pattern -> ContractViolation? in
            if lowercased.contains(pattern.token.lowercased()) {
                return ContractViolation(token: pattern.token, message: pattern.message)
            }
            return nil
        }

        return ContractEvaluation(passed: violations.isEmpty, violations: violations)
    }
}
