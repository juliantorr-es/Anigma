//
//  Rulepack.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Represents evaluation of a rulepack action.
public struct RuleEvaluation: Sendable, Codable {
    public let violatedRules: [String]
    public let handledPolicies: [String]

    public var isCompliant: Bool {
        violatedRules.isEmpty
    }

    public init(violatedRules: [String] = [], handledPolicies: [String] = []) {
        self.violatedRules = violatedRules
        self.handledPolicies = handledPolicies
    }
}

/// Represents a declarative rulepack.
public struct Rulepack: Sendable {
    public let hardInvariants: Set<String>
    public let policies: [String: String]

    public init(hardInvariants: Set<String>, policies: [String: String]) {
        self.hardInvariants = hardInvariants
        self.policies = policies
    }

    public static func load(from url: URL) throws -> Rulepack {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let definition = try decoder.decode(RulepackDefinition.self, from: data)
        return Rulepack(
            hardInvariants: Set(definition.hardInvariants),
            policies: definition.policies ?? [:]
        )
    }

    public func evaluate(action: RuleAction) -> RuleEvaluation {
        var violated: [String] = []
        var handled: [String] = []

        for requiredRule in action.requiredRules {
            if hardInvariants.contains(requiredRule) {
                violated.append(requiredRule)
            } else if policies.keys.contains(requiredRule) {
                handled.append(requiredRule)
            }
        }

        return RuleEvaluation(violatedRules: violated, handledPolicies: handled)
    }
}

/// Definition for decoding JSON-based rulepacks.
private struct RulepackDefinition: Codable {
    let hardInvariants: [String]
    let policies: [String: String]?
}

/// Action that may trigger rule evaluation.
public struct RuleAction: Sendable {
    public let name: String
    public let requiredRules: [String]

    public init(name: String, requiredRules: [String]) {
        self.name = name
        self.requiredRules = requiredRules
    }
}
