//
//  TestTimeComputeGovernance.swift
//  HarmoniaModule
//
//  Radically Legible AI: Test-time compute as an explicit, governed knob.
//  All "thinking" is structured, logged, and governable - not hidden latent soup.
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import AnigmaCore

// MARK: - Reasoning Budget

/// Explicit budget for test-time compute / reasoning.
public struct ReasoningBudget: Sendable, Codable {
    public let minThinkingTokens: Int
    public let maxThinkingTokens: Int
    public let strategy: ReasoningStrategy
    public let allowedTiers: Set<ReasoningTier>
    public let verificationRequired: Bool
    public let earlyTermination: EarlyTerminationPolicy

    public enum ReasoningStrategy: String, Sendable, Codable {
        case conservative   // Minimal thinking, faster responses
        case `default`      // Balanced approach
        case aggressive     // More thinking, better accuracy
        case verificationOnly // Only verify, don't reason deeply
        case fullTwoTier    // Use both symbolic and neural tiers
    }

    public enum ReasoningTier: String, Sendable, Codable, Hashable {
        case direct         // Simple lookup/generation
        case symbolic       // Symbolic reasoning only
        case neural         // LLM reasoning
        case trmSubsolver   // TRM-style recursive solver
        case hybrid         // Symbolic + neural
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

    // MARK: - Presets per Domain

    /// DSPS/Accommodations - needs careful, verifiable reasoning
    public static let dsps = ReasoningBudget(
        minThinkingTokens: 100,
        maxThinkingTokens: 4000,
        strategy: .aggressive,
        allowedTiers: [.neural, .symbolic, .hybrid],
        verificationRequired: true,
        earlyTermination: EarlyTerminationPolicy(
            enabled: true,
            confidenceThreshold: 0.95,
            maxRepeatedPatterns: 2,
            minStepsBeforeTermination: 3
        )
    )

    /// Transcriptum/Academic records - high stakes, full verification
    public static let transcriptum = ReasoningBudget(
        minThinkingTokens: 200,
        maxThinkingTokens: 5000,
        strategy: .fullTwoTier,
        allowedTiers: [.neural, .symbolic, .trmSubsolver, .hybrid],
        verificationRequired: true,
        earlyTermination: EarlyTerminationPolicy(
            enabled: true,
            confidenceThreshold: 0.98,
            maxRepeatedPatterns: 2,
            minStepsBeforeTermination: 4
        )
    )

    /// Simple chat/tutoring - faster, less verification needed
    public static let chat = ReasoningBudget(
        minThinkingTokens: 20,
        maxThinkingTokens: 500,
        strategy: .conservative,
        allowedTiers: [.direct, .neural],
        verificationRequired: false,
        earlyTermination: EarlyTerminationPolicy(
            enabled: true,
            confidenceThreshold: 0.8,
            maxRepeatedPatterns: 2,
            minStepsBeforeTermination: 1
        )
    )

    /// Code generation - moderate reasoning, structure-focused
    public static let code = ReasoningBudget(
        minThinkingTokens: 50,
        maxThinkingTokens: 1500,
        strategy: .default,
        allowedTiers: [.neural, .symbolic],
        verificationRequired: false,
        earlyTermination: .standard
    )
}

// MARK: - Structured Reasoning Trace

/// A fully structured, inspectable reasoning trace.
/// Not a blob of text - a machine-readable record.
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
        case completed              // Successfully reached conclusion
        case terminatedEarly        // Early termination due to confidence
        case budgetExhausted        // Hit token limit
        case verificationFailed     // Verification step failed
        case insufficientData       // Couldn't reason with available info
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

// MARK: - Reasoning Governor

/// Governs test-time compute according to budget and policy.
public actor ReasoningGovernor {
    private let budget: ReasoningBudget
    private let taskId: String
    private var tokensUsed: Int = 0
    private var steps: [StructuredReasoningTrace.ReasoningStep] = []
    private var violations: [StructuredReasoningTrace.BudgetViolation] = []
    private var patternHistory: [String] = []
    private let startTime: Date

    public init(budget: ReasoningBudget, taskId: String) {
        self.budget = budget
        self.taskId = taskId
        self.startTime = Date()
    }

    /// Check if a reasoning step is allowed.
    public func canProceed(tier: ReasoningBudget.ReasoningTier, estimatedTokens: Int) -> ReasoningDecision {
        // Check tier allowance
        guard budget.allowedTiers.contains(tier) else {
            let violation = StructuredReasoningTrace.BudgetViolation(
                type: .disallowedTier,
                description: "Tier \(tier.rawValue) not allowed by budget"
            )
            violations.append(violation)
            return .denied(reason: "Tier \(tier.rawValue) not allowed")
        }

        // Check token budget
        let projectedTokens = tokensUsed + estimatedTokens
        if projectedTokens > budget.maxThinkingTokens {
            let violation = StructuredReasoningTrace.BudgetViolation(
                type: .tokenLimitExceeded,
                description: "Would exceed token limit: \(projectedTokens) > \(budget.maxThinkingTokens)"
            )
            violations.append(violation)
            return .denied(reason: "Would exceed token budget")
        }

        // Warn if approaching limit
        let warningThreshold = Int(Double(budget.maxThinkingTokens) * 0.8)
        if projectedTokens > warningThreshold {
            let violation = StructuredReasoningTrace.BudgetViolation(
                type: .tokenLimitApproaching,
                description: "Approaching token limit: \(projectedTokens)/\(budget.maxThinkingTokens)"
            )
            violations.append(violation)
            return .allowed(warning: "Approaching token limit")
        }

        return .allowed(warning: nil)
    }

    /// Record a completed reasoning step.
    public func recordStep(_ step: StructuredReasoningTrace.ReasoningStep) {
        steps.append(step)
        tokensUsed += step.tokensUsed

        // Track pattern for repetition detection
        let pattern = "\(step.tier.rawValue):\(step.description.prefix(20))"
        patternHistory.append(pattern)

        // Check for repetitive patterns
        if patternHistory.count >= budget.earlyTermination.maxRepeatedPatterns {
            let recentPatterns = patternHistory.suffix(budget.earlyTermination.maxRepeatedPatterns)
            if Set(recentPatterns).count == 1 {
                let violation = StructuredReasoningTrace.BudgetViolation(
                    type: .repetitivePattern,
                    description: "Repetitive reasoning pattern detected"
                )
                violations.append(violation)
            }
        }
    }

    /// Check if early termination should occur.
    public func shouldTerminateEarly(currentConfidence: Double) -> Bool {
        guard budget.earlyTermination.enabled else { return false }
        guard steps.count >= budget.earlyTermination.minStepsBeforeTermination else { return false }

        return currentConfidence >= budget.earlyTermination.confidenceThreshold
    }

    /// Check if we've used enough tokens (hit minimum).
    public func hasMetMinimum() -> Bool {
        tokensUsed >= budget.minThinkingTokens
    }

    /// Generate the final trace.
    public func generateTrace(outcome: StructuredReasoningTrace.ReasoningOutcome, verificationPassed: Bool?) -> StructuredReasoningTrace {
        let avgConfidence = steps.isEmpty ? 0.0 : steps.map { $0.confidenceLevel }.reduce(0, +) / Double(steps.count)
        let finalConfidence = steps.last?.confidenceLevel ?? 0.0
        let tiersUsed = Set(steps.map { $0.tier })
        let wallClockTime = Date().timeIntervalSince(startTime)

        let metrics = StructuredReasoningTrace.ReasoningMetrics(
            totalTokensUsed: tokensUsed,
            stepsExecuted: steps.count,
            averageConfidence: avgConfidence,
            finalConfidence: finalConfidence,
            tiersUsed: tiersUsed,
            verificationPassed: verificationPassed,
            wallClockTime: wallClockTime
        )

        return StructuredReasoningTrace(
            taskId: taskId,
            budget: budget,
            steps: steps,
            outcome: outcome,
            metrics: metrics,
            violations: violations
        )
    }

    public enum ReasoningDecision: Sendable {
        case allowed(warning: String?)
        case denied(reason: String)
    }
}

// MARK: - Domain Budget Registry

/// Registry of reasoning budgets per domain.
public actor DomainBudgetRegistry {
    private var domainBudgets: [String: ReasoningBudget] = [
        "dsps": .dsps,
        "transcriptum": .transcriptum,
        "chat": .chat,
        "code": .code
    ]

    private var tenantOverrides: [String: [String: ReasoningBudget]] = [:]

    public init() {}

    /// Get the budget for a domain and tenant.
    public func getBudget(domain: String, tenantId: String) -> ReasoningBudget {
        // Check tenant-specific override first
        if let tenantBudgets = tenantOverrides[tenantId],
           let budget = tenantBudgets[domain] {
            return budget
        }

        // Fall back to domain default
        return domainBudgets[domain] ?? ReasoningBudget()
    }

    /// Set a domain-wide budget.
    public func setDomainBudget(_ budget: ReasoningBudget, for domain: String) {
        domainBudgets[domain] = budget
    }

    /// Set a tenant-specific override.
    public func setTenantOverride(_ budget: ReasoningBudget, for domain: String, tenantId: String) {
        if tenantOverrides[tenantId] == nil {
            tenantOverrides[tenantId] = [:]
        }
        tenantOverrides[tenantId]?[domain] = budget
    }

    /// List all configured domains.
    public func listDomains() -> [String] {
        Array(domainBudgets.keys)
    }
}

// MARK: - Reasoning Trace Renderer

/// Renders reasoning traces for human inspection.
public struct ReasoningTraceRenderer {

    public static func renderText(_ trace: StructuredReasoningTrace) -> String {
        var lines: [String] = []

        lines.append("═══════════════════════════════════════════════════════════")
        lines.append("                  REASONING TRACE")
        lines.append("═══════════════════════════════════════════════════════════")
        lines.append("Task: \(trace.taskId)")
        lines.append("Outcome: \(trace.outcome.rawValue)")
        lines.append("")

        // Budget Summary
        lines.append("┌─ BUDGET ───────────────────────────────────────────────┐")
        lines.append("│ Strategy: \(trace.budget.strategy.rawValue.padding(toLength: 43, withPad: " ", startingAt: 0))│")
        let tokenRange = "\(trace.budget.minThinkingTokens)-\(trace.budget.maxThinkingTokens)"
        lines.append("│ Token Range: \(tokenRange.padding(toLength: 40, withPad: " ", startingAt: 0))│")
        let verReq = trace.budget.verificationRequired ? "Yes" : "No"
        lines.append("│ Verification Required: \(verReq.padding(toLength: 30, withPad: " ", startingAt: 0))│")
        lines.append("└────────────────────────────────────────────────────────┘")
        lines.append("")

        // Metrics
        lines.append("┌─ METRICS ──────────────────────────────────────────────┐")
        lines.append("│ Tokens Used: \(String(trace.metrics.totalTokensUsed).padding(toLength: 40, withPad: " ", startingAt: 0))│")
        lines.append("│ Steps Executed: \(String(trace.metrics.stepsExecuted).padding(toLength: 37, withPad: " ", startingAt: 0))│")
        lines.append("│ Final Confidence: \(String(format: "%.2f", trace.metrics.finalConfidence).padding(toLength: 35, withPad: " ", startingAt: 0))│")
        lines.append("│ Wall Clock: \(String(format: "%.2fs", trace.metrics.wallClockTime).padding(toLength: 41, withPad: " ", startingAt: 0))│")
        if let verified = trace.metrics.verificationPassed {
            let verStatus = verified ? "PASSED ✓" : "FAILED ✗"
            lines.append("│ Verification: \(verStatus.padding(toLength: 39, withPad: " ", startingAt: 0))│")
        }
        lines.append("└────────────────────────────────────────────────────────┘")
        lines.append("")

        // Steps
        lines.append("┌─ REASONING STEPS ────────────────────────────────────────┐")
        for step in trace.steps {
            let tierIcon: String
            switch step.tier {
            case .direct: tierIcon = "→"
            case .symbolic: tierIcon = "⚙"
            case .neural: tierIcon = "🧠"
            case .trmSubsolver: tierIcon = "🔄"
            case .hybrid: tierIcon = "⚡"
            }

            let confidence = String(format: "%.0f%%", step.confidenceLevel * 100)
            lines.append("│ \(step.stepNumber). \(tierIcon) \(step.description.prefix(40)) [\(confidence)]".padding(toLength: 56, withPad: " ", startingAt: 0) + "│")
        }
        lines.append("└──────────────────────────────────────────────────────────┘")

        // Violations
        if !trace.violations.isEmpty {
            lines.append("")
            lines.append("┌─ BUDGET VIOLATIONS ──────────────────────────────────────┐")
            for violation in trace.violations {
                lines.append("│ ⚠ \(violation.type.rawValue): \(violation.description.prefix(35))│")
            }
            lines.append("└──────────────────────────────────────────────────────────┘")
        }

        lines.append("")
        lines.append("═══════════════════════════════════════════════════════════")

        return lines.joined(separator: "\n")
    }

    /// Render a short summary.
    public static func renderSummary(_ trace: StructuredReasoningTrace) -> String {
        let outcomeIcon: String
        switch trace.outcome {
        case .completed: outcomeIcon = "✓"
        case .terminatedEarly: outcomeIcon = "⏱"
        case .budgetExhausted: outcomeIcon = "⚠"
        case .verificationFailed: outcomeIcon = "✗"
        case .insufficientData: outcomeIcon = "?"
        }

        let confidence = String(format: "%.0f%%", trace.metrics.finalConfidence * 100)
        let tiers = trace.metrics.tiersUsed.map { $0.rawValue }.joined(separator: ", ")

        return """
        \(outcomeIcon) \(trace.outcome.rawValue) | \(trace.metrics.stepsExecuted) steps | \(trace.metrics.totalTokensUsed) tokens | Confidence: \(confidence)
        Tiers: \(tiers)
        """
    }
}
