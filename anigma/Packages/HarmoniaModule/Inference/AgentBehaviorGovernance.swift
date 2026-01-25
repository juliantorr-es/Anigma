//
//  AgentBehaviorGovernance.swift
//  HarmoniaModule
//
//  Prevents agent overthinking, rogue actions, and premature disengagement.
//  Implements the "disciplined reasoning" patterns from research on LLM failure modes.
//
//  Three failure modes addressed:
//  1. Analysis Paralysis - endless thinking without action
//  2. Rogue Actions - tool spam and unchecked write sequences
//  3. Premature Disengagement - giving up instead of checking signals
//

@preconcurrency import Foundation
import AnigmaCore

// MARK: - Agent Behavior Patterns

/// Types of agent behavior failures to detect and prevent.
public enum AgentBehaviorFailure: String, Sendable, Codable, CaseIterable {
    /// Agent is stuck in planning loop without taking actions.
    case analysisParalysis

    /// Agent is spamming tools/writes without waiting for feedback.
    case rogueActionSequence

    /// Agent gave up prematurely instead of checking available signals.
    case prematureDisengagement

    /// Agent is repeating the same reasoning without progress.
    case repetitiveReasoning

    /// Agent produced confident answer without tool verification.
    case ungroundedConfidence

    /// Agent is making high-impact changes without confirmation.
    case uncheckedHighImpact
}

/// Severity of behavior violation.
public enum BehaviorViolationSeverity: String, Sendable, Codable, Comparable {
    case warning
    case moderate
    case severe
    case critical

    public static func < (lhs: Self, rhs: Self) -> Bool {
        let order: [Self] = [.warning, .moderate, .severe, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Behavior Constraints

/// Constraints defining acceptable agent behavior.
public struct AgentBehaviorConstraints: Sendable, Codable {
    /// Maximum reasoning tokens before required action.
    public var maxReasoningWithoutAction: Int

    /// Maximum consecutive tool calls without waiting for results.
    public var maxConsecutiveToolCalls: Int

    /// Maximum write operations in a single turn.
    public var maxWritesPerTurn: Int

    /// Whether to require explicit uncertainty acknowledgment.
    public var requireUncertaintyAcknowledgment: Bool

    /// Maximum confidence score for claims without tool verification.
    public var maxUnverifiedConfidence: Double

    /// Tools that reset the action counter (considered "checking environment").
    public var environmentCheckTools: Set<String>

    /// High-impact operations requiring step-up auth or confirmation.
    public var highImpactOperations: Set<String>

    /// Minimum interval between consecutive writes (seconds).
    public var minWriteInterval: TimeInterval

    public init(
        maxReasoningWithoutAction: Int = 2000,
        maxConsecutiveToolCalls: Int = 3,
        maxWritesPerTurn: Int = 5,
        requireUncertaintyAcknowledgment: Bool = true,
        maxUnverifiedConfidence: Double = 0.7,
        environmentCheckTools: Set<String> = ["read_file", "search", "query", "get_status"],
        highImpactOperations: Set<String> = ["delete", "update_policy", "create_user", "modify_record"],
        minWriteInterval: TimeInterval = 0.5
    ) {
        self.maxReasoningWithoutAction = maxReasoningWithoutAction
        self.maxConsecutiveToolCalls = maxConsecutiveToolCalls
        self.maxWritesPerTurn = maxWritesPerTurn
        self.requireUncertaintyAcknowledgment = requireUncertaintyAcknowledgment
        self.maxUnverifiedConfidence = maxUnverifiedConfidence
        self.environmentCheckTools = environmentCheckTools
        self.highImpactOperations = highImpactOperations
        self.minWriteInterval = minWriteInterval
    }

    // MARK: - Presets

    /// Strict constraints for DSPS/Transcriptum domains.
    public static let strict = AgentBehaviorConstraints(
        maxReasoningWithoutAction: 1000,
        maxConsecutiveToolCalls: 2,
        maxWritesPerTurn: 2,
        requireUncertaintyAcknowledgment: true,
        maxUnverifiedConfidence: 0.5,
        minWriteInterval: 1.0
    )

    /// Default constraints for general use.
    public static let `default` = AgentBehaviorConstraints()

    /// Relaxed constraints for exploratory/dev use.
    public static let relaxed = AgentBehaviorConstraints(
        maxReasoningWithoutAction: 5000,
        maxConsecutiveToolCalls: 10,
        maxWritesPerTurn: 20,
        requireUncertaintyAcknowledgment: false,
        maxUnverifiedConfidence: 0.9,
        minWriteInterval: 0.1
    )
}

// MARK: - Agent Turn State

/// Tracks state within an agent turn for behavior analysis.
public struct AgentTurnState: Sendable {
    public let turnId: String
    public let startedAt: Date
    public var reasoningTokens: Int
    public var toolCallsMade: [ToolCallRecord]
    public var writeOperations: [WriteOperationRecord]
    public var lastActionAt: Date?
    public var lastEnvironmentCheck: Date?
    public var uncertaintyAcknowledged: Bool
    public var violations: [BehaviorViolation]

    public init(turnId: String = UUID().uuidString) {
        self.turnId = turnId
        self.startedAt = Date()
        self.reasoningTokens = 0
        self.toolCallsMade = []
        self.writeOperations = []
        self.lastActionAt = nil
        self.lastEnvironmentCheck = nil
        self.uncertaintyAcknowledged = false
        self.violations = []
    }

    /// Time since last action.
    public var timeSinceLastAction: TimeInterval? {
        guard let last = lastActionAt else { return nil }
        return Date().timeIntervalSince(last)
    }

    /// Whether turn has exceeded reasoning limits.
    public func hasExceededReasoningLimit(_ limit: Int) -> Bool {
        reasoningTokens > limit && toolCallsMade.isEmpty
    }

    /// Count of consecutive tool calls without environment check.
    public var consecutiveToolsWithoutCheck: Int {
        var count = 0
        for call in toolCallsMade.reversed() {
            if call.isEnvironmentCheck {
                break
            }
            count += 1
        }
        return count
    }
}

/// Record of a tool call.
public struct ToolCallRecord: Sendable {
    public let toolName: String
    public let timestamp: Date
    public let isEnvironmentCheck: Bool
    public let waitedForResult: Bool

    public init(
        toolName: String,
        isEnvironmentCheck: Bool = false,
        waitedForResult: Bool = true
    ) {
        self.toolName = toolName
        self.timestamp = Date()
        self.isEnvironmentCheck = isEnvironmentCheck
        self.waitedForResult = waitedForResult
    }
}

/// Record of a write operation.
public struct WriteOperationRecord: Sendable {
    public let operationType: String
    public let targetEntity: String?
    public let timestamp: Date
    public let isHighImpact: Bool
    public let wasConfirmed: Bool

    public init(
        operationType: String,
        targetEntity: String? = nil,
        isHighImpact: Bool = false,
        wasConfirmed: Bool = false
    ) {
        self.operationType = operationType
        self.targetEntity = targetEntity
        self.timestamp = Date()
        self.isHighImpact = isHighImpact
        self.wasConfirmed = wasConfirmed
    }
}

/// A detected behavior violation.
public struct BehaviorViolation: Sendable, Codable {
    public let id: String
    public let failure: AgentBehaviorFailure
    public let severity: BehaviorViolationSeverity
    public let description: String
    public let timestamp: Date
    public let suggestedAction: ViolationAction

    public init(
        failure: AgentBehaviorFailure,
        severity: BehaviorViolationSeverity,
        description: String,
        suggestedAction: ViolationAction
    ) {
        self.id = UUID().uuidString
        self.failure = failure
        self.severity = severity
        self.description = description
        self.timestamp = Date()
        self.suggestedAction = suggestedAction
    }
}

/// Actions to take on violation.
public enum ViolationAction: String, Sendable, Codable {
    case logOnly
    case warn
    case forceEnvironmentCheck
    case requireConfirmation
    case pauseAndReview
    case terminateTurn
    case blockAndEscalate
}

// MARK: - Behavior Governor

/// Monitors and governs agent behavior to prevent failure modes.
public actor AgentBehaviorGovernor {
    /// Current active turns by turn ID.
    private var activeTurns: [String: AgentTurnState] = [:]

    /// Constraints by context (tenant/workspace).
    private var contextConstraints: [String: AgentBehaviorConstraints] = [:]

    /// Default constraints.
    private var defaultConstraints: AgentBehaviorConstraints = .default

    /// Violation history for patterns.
    private var violationHistory: [BehaviorViolation] = []

    /// Maximum history size.
    private let maxHistorySize = 500

    public init() {}

    // MARK: - Turn Management

    /// Starts a new agent turn.
    public func startTurn(turnId: String = UUID().uuidString) -> String {
        let state = AgentTurnState(turnId: turnId)
        activeTurns[turnId] = state
        return turnId
    }

    /// Ends a turn and returns summary.
    public func endTurn(_ turnId: String) -> AgentTurnSummary? {
        guard let state = activeTurns.removeValue(forKey: turnId) else {
            return nil
        }

        return AgentTurnSummary(
            turnId: turnId,
            duration: Date().timeIntervalSince(state.startedAt),
            reasoningTokens: state.reasoningTokens,
            toolCalls: state.toolCallsMade.count,
            writes: state.writeOperations.count,
            violations: state.violations
        )
    }

    // MARK: - Behavior Tracking

    /// Records reasoning tokens generated.
    public func recordReasoning(
        turnId: String,
        tokens: Int,
        context: String
    ) -> BehaviorCheckResult {
        guard var state = activeTurns[turnId] else {
            return .turnNotFound
        }

        state.reasoningTokens += tokens

        let constraints = getConstraints(for: context)

        // Check for analysis paralysis
        if state.hasExceededReasoningLimit(constraints.maxReasoningWithoutAction) {
            let violation = BehaviorViolation(
                failure: .analysisParalysis,
                severity: .moderate,
                description: "Agent has generated \(state.reasoningTokens) tokens without taking any action",
                suggestedAction: .forceEnvironmentCheck
            )
            state.violations.append(violation)
            violationHistory.append(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }

        activeTurns[turnId] = state
        return .ok
    }

    /// Records a tool call.
    public func recordToolCall(
        turnId: String,
        toolName: String,
        context: String,
        waitedForResult: Bool = true
    ) -> BehaviorCheckResult {
        guard var state = activeTurns[turnId] else {
            return .turnNotFound
        }

        let constraints = getConstraints(for: context)
        let isEnvCheck = constraints.environmentCheckTools.contains(toolName)

        let record = ToolCallRecord(
            toolName: toolName,
            isEnvironmentCheck: isEnvCheck,
            waitedForResult: waitedForResult
        )
        state.toolCallsMade.append(record)
        state.lastActionAt = Date()

        if isEnvCheck {
            state.lastEnvironmentCheck = Date()
        }

        // Check for rogue action sequence
        if !waitedForResult {
            let consecutiveWithoutWait = state.toolCallsMade.suffix(constraints.maxConsecutiveToolCalls)
                .filter { !$0.waitedForResult }.count

            if consecutiveWithoutWait >= constraints.maxConsecutiveToolCalls {
                let violation = BehaviorViolation(
                    failure: .rogueActionSequence,
                    severity: .severe,
                    description: "Agent made \(consecutiveWithoutWait) consecutive tool calls without waiting for results",
                    suggestedAction: .pauseAndReview
                )
                state.violations.append(violation)
                violationHistory.append(violation)
                activeTurns[turnId] = state
                return .violation(violation)
            }
        }

        activeTurns[turnId] = state
        return .ok
    }

    /// Records a write operation.
    public func recordWrite(
        turnId: String,
        operationType: String,
        targetEntity: String?,
        context: String,
        wasConfirmed: Bool = false
    ) -> BehaviorCheckResult {
        guard var state = activeTurns[turnId] else {
            return .turnNotFound
        }

        let constraints = getConstraints(for: context)
        let isHighImpact = constraints.highImpactOperations.contains(operationType)

        // Check write interval
        if let lastWrite = state.writeOperations.last {
            let interval = Date().timeIntervalSince(lastWrite.timestamp)
            if interval < constraints.minWriteInterval {
                let violation = BehaviorViolation(
                    failure: .rogueActionSequence,
                    severity: .moderate,
                    description: "Write operations too rapid: \(interval)s interval (min: \(constraints.minWriteInterval)s)",
                    suggestedAction: .requireConfirmation
                )
                state.violations.append(violation)
                violationHistory.append(violation)
            }
        }

        let record = WriteOperationRecord(
            operationType: operationType,
            targetEntity: targetEntity,
            isHighImpact: isHighImpact,
            wasConfirmed: wasConfirmed
        )
        state.writeOperations.append(record)
        state.lastActionAt = Date()

        // Check for high-impact without confirmation
        if isHighImpact && !wasConfirmed {
            let violation = BehaviorViolation(
                failure: .uncheckedHighImpact,
                severity: .severe,
                description: "High-impact operation '\(operationType)' executed without confirmation",
                suggestedAction: .blockAndEscalate
            )
            state.violations.append(violation)
            violationHistory.append(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }

        // Check for write spam
        if state.writeOperations.count > constraints.maxWritesPerTurn {
            let violation = BehaviorViolation(
                failure: .rogueActionSequence,
                severity: .moderate,
                description: "Exceeded max writes per turn: \(state.writeOperations.count) > \(constraints.maxWritesPerTurn)",
                suggestedAction: .pauseAndReview
            )
            state.violations.append(violation)
            violationHistory.append(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }

        activeTurns[turnId] = state
        return .ok
    }

    /// Records an answer/conclusion being produced.
    public func recordAnswer(
        turnId: String,
        confidence: Double,
        hadToolVerification: Bool,
        context: String
    ) -> BehaviorCheckResult {
        guard var state = activeTurns[turnId] else {
            return .turnNotFound
        }

        let constraints = getConstraints(for: context)

        // Check for ungrounded confidence
        if confidence > constraints.maxUnverifiedConfidence && !hadToolVerification {
            let violation = BehaviorViolation(
                failure: .ungroundedConfidence,
                severity: .warning,
                description: "High confidence (\(confidence)) answer without tool verification",
                suggestedAction: .warn
            )
            state.violations.append(violation)
            violationHistory.append(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }

        // Check for premature disengagement
        let hasCheckedEnvironment = state.lastEnvironmentCheck != nil
        if !hasCheckedEnvironment && state.toolCallsMade.isEmpty {
            let violation = BehaviorViolation(
                failure: .prematureDisengagement,
                severity: .moderate,
                description: "Produced answer without checking any external signals",
                suggestedAction: .forceEnvironmentCheck
            )
            state.violations.append(violation)
            violationHistory.append(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }

        activeTurns[turnId] = state
        return .ok
    }

    /// Acknowledges uncertainty in the turn.
    public func acknowledgeUncertainty(turnId: String) {
        if var state = activeTurns[turnId] {
            state.uncertaintyAcknowledged = true
            activeTurns[turnId] = state
        }
    }

    // MARK: - Constraint Management

    /// Sets constraints for a context.
    public func setConstraints(_ constraints: AgentBehaviorConstraints, for context: String) {
        contextConstraints[context] = constraints
    }

    /// Gets constraints for a context.
    private func getConstraints(for context: String) -> AgentBehaviorConstraints {
        contextConstraints[context] ?? defaultConstraints
    }

    // MARK: - Analytics

    /// Gets behavior statistics.
    public func statistics() -> BehaviorStatistics {
        let byFailure = Dictionary(grouping: violationHistory) { $0.failure }
            .mapValues { $0.count }

        let bySeverity = Dictionary(grouping: violationHistory) { $0.severity }
            .mapValues { $0.count }

        return BehaviorStatistics(
            totalViolations: violationHistory.count,
            violationsByType: byFailure,
            violationsBySeverity: bySeverity,
            activeTurns: activeTurns.count
        )
    }

    /// Prunes old history.
    public func pruneHistory() {
        if violationHistory.count > maxHistorySize {
            violationHistory.removeFirst(violationHistory.count - maxHistorySize)
        }
    }
}

// MARK: - Supporting Types

/// Result of a behavior check.
public enum BehaviorCheckResult: Sendable {
    case ok
    case turnNotFound
    case violation(BehaviorViolation)

    public var isOk: Bool {
        if case .ok = self { return true }
        return false
    }
}

/// Summary of an agent turn.
public struct AgentTurnSummary: Sendable {
    public let turnId: String
    public let duration: TimeInterval
    public let reasoningTokens: Int
    public let toolCalls: Int
    public let writes: Int
    public let violations: [BehaviorViolation]

    public var wasClean: Bool { violations.isEmpty }

    public var worstViolationSeverity: BehaviorViolationSeverity? {
        violations.map { $0.severity }.max()
    }
}

/// Behavior statistics.
public struct BehaviorStatistics: Sendable {
    public let totalViolations: Int
    public let violationsByType: [AgentBehaviorFailure: Int]
    public let violationsBySeverity: [BehaviorViolationSeverity: Int]
    public let activeTurns: Int
}

// MARK: - Integration with Inference Service

extension AgentBehaviorGovernor {
    /// Creates a governed inference context.
    public func governedContext(
        turnId: String,
        context: String
    ) -> GovernedInferenceContext {
        GovernedInferenceContext(
            turnId: turnId,
            context: context,
            governor: self
        )
    }
}

/// Context wrapper for governed inference.
public struct GovernedInferenceContext: Sendable {
    public let turnId: String
    public let context: String
    public let governor: AgentBehaviorGovernor

    /// Records reasoning and returns whether to continue.
    public func recordReasoning(tokens: Int) async -> Bool {
        let result = await governor.recordReasoning(
            turnId: turnId,
            tokens: tokens,
            context: context
        )
        return result.isOk
    }

    /// Records tool call and returns whether to proceed.
    public func recordTool(name: String, waitedForResult: Bool) async -> Bool {
        let result = await governor.recordToolCall(
            turnId: turnId,
            toolName: name,
            context: context,
            waitedForResult: waitedForResult
        )
        return result.isOk
    }

    /// Records write and returns whether allowed.
    public func recordWrite(
        operation: String,
        target: String?,
        confirmed: Bool
    ) async -> Bool {
        let result = await governor.recordWrite(
            turnId: turnId,
            operationType: operation,
            targetEntity: target,
            context: context,
            wasConfirmed: confirmed
        )
        return result.isOk
    }
}
