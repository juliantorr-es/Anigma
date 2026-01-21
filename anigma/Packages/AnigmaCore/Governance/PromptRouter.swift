//
//  PromptRouter.swift
//  AnigmaCore
//
//  Intelligent routing and classification of prompts for governance.
//

import Foundation

/// Classification of a prompt's intent and risk level.
public struct PromptClassification: Sendable, Codable {
    public let intent: PromptIntent
    public let riskScore: Double // 0.0 to 1.0
    public let requiredClearance: FunctionClearance
    public let identifiedEntities: [String]
    public let applicablePolicyId: String
}

public enum PromptIntent: String, Sendable, Codable {
    case generalTask
    case sensitiveDataQuery
    case policyInquiry
    case systemAction
    case adversarialAttempt
}

/// Actor that evaluates prompts before they are sent to inference.
public actor PromptRouter {
    public init() {}

    public func classify(_ prompt: String) async -> PromptClassification {
        let normalized = prompt.lowercased()

        // Policy Mapping Table
        // - SEC-001: Adversarial Defense
        // - PRIV-001: Data Privacy
        // - GOV-001: General Usage

        if containsAdversarialPatterns(normalized) {
            return PromptClassification(
                intent: .adversarialAttempt,
                riskScore: 0.9,
                requiredClearance: .critical,
                identifiedEntities: [],
                applicablePolicyId: "SEC-001"
            )
        }

        if normalized.contains("pii") || normalized.contains("password") {
            return PromptClassification(
                intent: .sensitiveDataQuery,
                riskScore: 0.7,
                requiredClearance: .sensitive,
                identifiedEntities: [],
                applicablePolicyId: "PRIV-001"
            )
        }

        return PromptClassification(
            intent: .generalTask,
            riskScore: 0.1,
            requiredClearance: .regular,
            identifiedEntities: [],
            applicablePolicyId: "GOV-001"
        )
    }

    private func containsAdversarialPatterns(_ prompt: String) -> Bool {
        let patterns = ["ignore previous instructions", "system prompt", "developer mode", "jailbreak"]
        return patterns.contains { prompt.contains($0) }
    }
}
