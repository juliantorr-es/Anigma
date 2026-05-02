//
//  TestTimeComputeGovernanceCompat.swift
//  HarmoniaModule
//
//  Minimal compatibility surface for test-time compute governance.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import InferenceCore
@preconcurrency import Foundation

public struct ReasoningBudget: Sendable, Codable {
    public let minThinkingTokens: Int
    public let maxThinkingTokens: Int
    public let strategy: ReasoningStrategy
    public let allowedTiers: Set<ReasoningTier>
    public let verificationRequired: Bool
    public let earlyTermination: EarlyTerminationPolicy

    public enum ReasoningStrategy: String, Sendable, Codable {
        case conservative
        case `default`
        case aggressive
        case verificationOnly
        case fullTwoTier
    }

    public enum ReasoningTier: String, Sendable, Codable, Hashable {
        case direct
        case symbolic
        case neural
        case trmSubsolver
        case hybrid
    }

    public struct EarlyTerminationPolicy: Sendable, Codable {
        public let enabled: Bool
        public let confidenceThreshold: Double
        public let maxRepeatedPatterns: Int
        public let minStepsBeforeTermination: Int

        public init(
            enabled: Bool = true,
            confidenceThreshold: Double = 0.9,
            maxRepeatedPatterns: Int = 3,
            minStepsBeforeTermination: Int = 2
        ) {
            self.enabled = enabled
            self.confidenceThreshold = confidenceThreshold
            self.maxRepeatedPatterns = maxRepeatedPatterns
            self.minStepsBeforeTermination = minStepsBeforeTermination
        }

        public static let standard = EarlyTerminationPolicy()
        public static let disabled = EarlyTerminationPolicy(enabled: false)
    }

    public init(
        minThinkingTokens: Int = 50,
        maxThinkingTokens: Int = 2000,
        strategy: ReasoningStrategy = .default,
        allowedTiers: Set<ReasoningTier> = [.direct, .neural],
        verificationRequired: Bool = false,
        earlyTermination: EarlyTerminationPolicy = .standard
    ) {
        self.minThinkingTokens = minThinkingTokens
        self.maxThinkingTokens = maxThinkingTokens
        self.strategy = strategy
        self.allowedTiers = allowedTiers
        self.verificationRequired = verificationRequired
        self.earlyTermination = earlyTermination
    }

    public static let dsps = ReasoningBudget(
        minThinkingTokens: 100,
        maxThinkingTokens: 4000,
        strategy: .aggressive,
        allowedTiers: [.neural, .symbolic, .hybrid],
        verificationRequired: true,
        earlyTermination: .init(enabled: true, confidenceThreshold: 0.95, maxRepeatedPatterns: 2, minStepsBeforeTermination: 3)
    )

    public static let transcriptum = ReasoningBudget(
        minThinkingTokens: 200,
        maxThinkingTokens: 5000,
        strategy: .fullTwoTier,
        allowedTiers: [.neural, .symbolic, .trmSubsolver, .hybrid],
        verificationRequired: true,
        earlyTermination: .init(enabled: true, confidenceThreshold: 0.98, maxRepeatedPatterns: 2, minStepsBeforeTermination: 4)
    )

    public static let chat = ReasoningBudget(
        minThinkingTokens: 20,
        maxThinkingTokens: 500,
        strategy: .conservative,
        allowedTiers: [.direct, .neural],
        verificationRequired: false,
        earlyTermination: .init(enabled: true, confidenceThreshold: 0.8, maxRepeatedPatterns: 2, minStepsBeforeTermination: 1)
    )

    public static let code = ReasoningBudget(
        minThinkingTokens: 50,
        maxThinkingTokens: 1500,
        strategy: .default,
        allowedTiers: [.neural, .symbolic],
        verificationRequired: false,
        earlyTermination: .standard
    )
}

public struct StructuredReasoningTrace: Sendable, Codable, Identifiable {
    public let id: String
    public let taskId: String
    public let createdAt: Date
    public let budget: ReasoningBudget
    public let steps: [ReasoningStep]
    public let outcome: ReasoningOutcome
    public let metrics: ReasoningMetrics
    public let violations: [BudgetViolation]

    public struct ReasoningStep: Sendable, Codable, Identifiable {
        public let id: String
        public let stepNumber: Int
        public let tier: ReasoningBudget.ReasoningTier
        public let description: String
        public let inputContext: [String]
        public let outputProduced: String
        public let tokensUsed: Int
        public let confidenceLevel: Double
        public let timestamp: Date

        public init(
            id: String = UUID().uuidString,
            stepNumber: Int,
            tier: ReasoningBudget.ReasoningTier,
            description: String,
            inputContext: [String],
            outputProduced: String,
            tokensUsed: Int,
            confidenceLevel: Double,
            timestamp: Date = Date()
        ) {
            self.id = id
            self.stepNumber = stepNumber
            self.tier = tier
            self.description = description
            self.inputContext = inputContext
            self.outputProduced = outputProduced
            self.tokensUsed = tokensUsed
            self.confidenceLevel = confidenceLevel
            self.timestamp = timestamp
        }
    }

    public enum ReasoningOutcome: String, Sendable, Codable {
        case completed
        case terminatedEarly
        case budgetExhausted
        case verificationFailed
        case insufficientData
    }

    public struct ReasoningMetrics: Sendable, Codable {
        public let totalTokensUsed: Int
        public let stepsExecuted: Int
        public let averageConfidence: Double
        public let finalConfidence: Double
        public let tiersUsed: Set<ReasoningBudget.ReasoningTier>
        public let verificationPassed: Bool?
        public let wallClockTime: TimeInterval

        public init(
            totalTokensUsed: Int,
            stepsExecuted: Int,
            averageConfidence: Double,
            finalConfidence: Double,
            tiersUsed: Set<ReasoningBudget.ReasoningTier>,
            verificationPassed: Bool?,
            wallClockTime: TimeInterval
        ) {
            self.totalTokensUsed = totalTokensUsed
            self.stepsExecuted = stepsExecuted
            self.averageConfidence = averageConfidence
            self.finalConfidence = finalConfidence
            self.tiersUsed = tiersUsed
            self.verificationPassed = verificationPassed
            self.wallClockTime = wallClockTime
        }
    }

    public struct BudgetViolation: Sendable, Codable {
        public let type: ViolationType
        public let description: String
        public let timestamp: Date

        public enum ViolationType: String, Sendable, Codable {
            case tokenLimitApproaching
            case tokenLimitExceeded
            case disallowedTier
            case verificationSkipped
            case repetitivePattern
        }

        public init(type: ViolationType, description: String, timestamp: Date = Date()) {
            self.type = type
            self.description = description
            self.timestamp = timestamp
        }
    }

    public init(
        id: String = UUID().uuidString,
        taskId: String,
        createdAt: Date = Date(),
        budget: ReasoningBudget,
        steps: [ReasoningStep],
        outcome: ReasoningOutcome,
        metrics: ReasoningMetrics,
        violations: [BudgetViolation] = []
    ) {
        self.id = id
        self.taskId = taskId
        self.createdAt = createdAt
        self.budget = budget
        self.steps = steps
        self.outcome = outcome
        self.metrics = metrics
        self.violations = violations
    }
}

public actor ReasoningGovernor {
    private let budget: ReasoningBudget
    private let taskId: String
    private var tokensUsed = 0
    private var steps: [StructuredReasoningTrace.ReasoningStep] = []
    private var violations: [StructuredReasoningTrace.BudgetViolation] = []
    private var patternHistory: [String] = []
    private let startTime: Date

    public init(budget: ReasoningBudget, taskId: String) {
        self.budget = budget
        self.taskId = taskId
        self.startTime = Date()
    }

    public func canProceed(tier: ReasoningBudget.ReasoningTier, estimatedTokens: Int) -> ReasoningDecision {
        guard budget.allowedTiers.contains(tier) else {
            let violation = StructuredReasoningTrace.BudgetViolation(type: .disallowedTier, description: "Tier \(tier.rawValue) not allowed by budget")
            violations.append(violation)
            return .denied(reason: "Tier \(tier.rawValue) not allowed")
        }

        let projected = tokensUsed + estimatedTokens
        if projected > budget.maxThinkingTokens {
            let violation = StructuredReasoningTrace.BudgetViolation(type: .tokenLimitExceeded, description: "Would exceed token limit: \(projected) > \(budget.maxThinkingTokens)")
            violations.append(violation)
            return .denied(reason: "Would exceed token budget")
        }

        let warningThreshold = Int(Double(budget.maxThinkingTokens) * 0.8)
        if projected > warningThreshold {
            let violation = StructuredReasoningTrace.BudgetViolation(type: .tokenLimitApproaching, description: "Approaching token limit: \(projected)/\(budget.maxThinkingTokens)")
            violations.append(violation)
            return .allowed(warning: "Approaching token limit")
        }

        return .allowed(warning: nil)
    }

    public func recordStep(_ step: StructuredReasoningTrace.ReasoningStep) {
        steps.append(step)
        tokensUsed += step.tokensUsed
        let pattern = "\(step.tier.rawValue):\(step.description.prefix(20))"
        patternHistory.append(pattern)

        if patternHistory.count >= budget.earlyTermination.maxRepeatedPatterns {
            let recent = patternHistory.suffix(budget.earlyTermination.maxRepeatedPatterns)
            if Set(recent).count == 1 {
                violations.append(.init(type: .repetitivePattern, description: "Repetitive reasoning pattern detected"))
            }
        }
    }

    public func shouldTerminateEarly(currentConfidence: Double) -> Bool {
        guard budget.earlyTermination.enabled else { return false }
        guard steps.count >= budget.earlyTermination.minStepsBeforeTermination else { return false }
        return currentConfidence >= budget.earlyTermination.confidenceThreshold
    }

    public func hasMetMinimum() -> Bool {
        tokensUsed >= budget.minThinkingTokens
    }

    public func generateTrace(outcome: StructuredReasoningTrace.ReasoningOutcome, verificationPassed: Bool?) -> StructuredReasoningTrace {
        let avgConfidence = steps.isEmpty ? 0.0 : steps.map(\.confidenceLevel).reduce(0, +) / Double(steps.count)
        let finalConfidence = steps.last?.confidenceLevel ?? 0.0
        let tiersUsed = Set(steps.map(\.tier))
        let metrics = StructuredReasoningTrace.ReasoningMetrics(
            totalTokensUsed: tokensUsed,
            stepsExecuted: steps.count,
            averageConfidence: avgConfidence,
            finalConfidence: finalConfidence,
            tiersUsed: tiersUsed,
            verificationPassed: verificationPassed,
            wallClockTime: Date().timeIntervalSince(startTime)
        )
        return StructuredReasoningTrace(taskId: taskId, budget: budget, steps: steps, outcome: outcome, metrics: metrics, violations: violations)
    }

    public enum ReasoningDecision: Sendable {
        case allowed(warning: String?)
        case denied(reason: String)
    }
}

public actor DomainBudgetRegistry {
    private var domainBudgets: [String: ReasoningBudget] = [
        "dsps": .dsps,
        "transcriptum": .transcriptum,
        "chat": .chat,
        "code": .code
    ]
    private var tenantOverrides: [String: [String: ReasoningBudget]] = [:]

    public init() {}

    public func getBudget(domain: String, tenantId: String) -> ReasoningBudget {
        if let tenant = tenantOverrides[tenantId], let budget = tenant[domain] {
            return budget
        }
        return domainBudgets[domain] ?? ReasoningBudget()
    }

    public func setDomainBudget(_ budget: ReasoningBudget, for domain: String) {
        domainBudgets[domain] = budget
    }

    public func setTenantOverride(_ budget: ReasoningBudget, for domain: String, tenantId: String) {
        tenantOverrides[tenantId, default: [:]][domain] = budget
    }
}

public struct ReasoningTraceRenderer {
    public static func renderText(_ trace: StructuredReasoningTrace) -> String {
        var lines: [String] = []
        lines.append("Task: \(trace.taskId)")
        lines.append("Outcome: \(trace.outcome.rawValue)")
        lines.append("Steps: \(trace.metrics.stepsExecuted)")
        lines.append("Tokens: \(trace.metrics.totalTokensUsed)")
        for step in trace.steps {
            lines.append("[\(step.tier.rawValue)] \(step.description)")
        }
        if !trace.violations.isEmpty {
            lines.append("Violations:")
            lines.append(contentsOf: trace.violations.map { "- \($0.type.rawValue): \($0.description)" })
        }
        return lines.joined(separator: "\n")
    }

    public static func renderSummary(_ trace: StructuredReasoningTrace) -> String {
        let confidence = String(format: "%.0f%%", trace.metrics.finalConfidence * 100)
        let tiers = trace.metrics.tiersUsed.map(\.rawValue).joined(separator: ", ")
        return "\(trace.outcome.rawValue) | \(trace.metrics.stepsExecuted) steps | \(trace.metrics.totalTokensUsed) tokens | Confidence: \(confidence)\nTiers: \(tiers)"
    }
}
