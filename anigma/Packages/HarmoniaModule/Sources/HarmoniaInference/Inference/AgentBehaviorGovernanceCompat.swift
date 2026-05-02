//
//  AgentBehaviorGovernanceCompat.swift
//  HarmoniaModule
//
//  Minimal compatibility surface for agent behavior governance.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import InferenceCore
@preconcurrency import Foundation

public enum AgentBehaviorFailure: String, Sendable, Codable, CaseIterable {
    case analysisParalysis
    case rogueActionSequence
    case prematureDisengagement
    case repetitiveReasoning
    case ungroundedConfidence
    case uncheckedHighImpact
}

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

public struct AgentBehaviorConstraints: Sendable, Codable {
    public var maxReasoningWithoutAction: Int
    public var maxConsecutiveToolCalls: Int
    public var maxWritesPerTurn: Int
    public var requireUncertaintyAcknowledgment: Bool
    public var maxUnverifiedConfidence: Double
    public var environmentCheckTools: Set<String>
    public var highImpactOperations: Set<String>
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

    public static let strict = AgentBehaviorConstraints(
        maxReasoningWithoutAction: 1000,
        maxConsecutiveToolCalls: 2,
        maxWritesPerTurn: 2,
        requireUncertaintyAcknowledgment: true,
        maxUnverifiedConfidence: 0.5,
        minWriteInterval: 1.0
    )

    public static let `default` = AgentBehaviorConstraints()

    public static let relaxed = AgentBehaviorConstraints(
        maxReasoningWithoutAction: 5000,
        maxConsecutiveToolCalls: 10,
        maxWritesPerTurn: 20,
        requireUncertaintyAcknowledgment: false,
        maxUnverifiedConfidence: 0.9,
        minWriteInterval: 0.1
    )
}

public enum ViolationAction: String, Sendable, Codable {
    case logOnly
    case warn
    case forceEnvironmentCheck
    case requireConfirmation
    case pauseAndReview
    case terminateTurn
    case blockAndEscalate
}

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

public enum BehaviorCheckResult: Sendable {
    case ok
    case turnNotFound
    case violation(BehaviorViolation)

    public var isOk: Bool {
        if case .ok = self { return true }
        return false
    }
}

public struct AgentTurnSummary: Sendable {
    public let turnId: String
    public let duration: TimeInterval
    public let reasoningTokens: Int
    public let toolCalls: Int
    public let writes: Int
    public let violations: [BehaviorViolation]

    public var wasClean: Bool { violations.isEmpty }

    public var worstViolationSeverity: BehaviorViolationSeverity? {
        violations.map(\.severity).max()
    }
}

public struct BehaviorStatistics: Sendable {
    public let totalViolations: Int
    public let violationsByType: [AgentBehaviorFailure: Int]
    public let violationsBySeverity: [BehaviorViolationSeverity: Int]
    public let activeTurns: Int
}

private struct ToolCallRecord: Sendable {
    let toolName: String
    let timestamp: Date
    let isEnvironmentCheck: Bool
    let waitedForResult: Bool
}

private struct WriteOperationRecord: Sendable {
    let operationType: String
    let timestamp: Date
}

private struct AgentTurnState: Sendable {
    let turnId: String
    let startedAt: Date
    var reasoningTokens: Int = 0
    var toolCallsMade: [ToolCallRecord] = []
    var writeOperations: [WriteOperationRecord] = []
    var lastEnvironmentCheck: Date?
    var uncertaintyAcknowledged = false
    var violations: [BehaviorViolation] = []
}

public actor AgentBehaviorGovernor {
    private var activeTurns: [String: AgentTurnState] = [:]
    private var contextConstraints: [String: AgentBehaviorConstraints] = [:]
    private var defaultConstraints: AgentBehaviorConstraints = .default
    private var violationHistory: [BehaviorViolation] = []
    private let maxHistorySize = 500

    public init() {}

    public func startTurn(turnId: String = UUID().uuidString) -> String {
        activeTurns[turnId] = AgentTurnState(turnId: turnId, startedAt: Date())
        return turnId
    }

    public func endTurn(_ turnId: String) -> AgentTurnSummary? {
        guard let state = activeTurns.removeValue(forKey: turnId) else { return nil }
        return AgentTurnSummary(
            turnId: turnId,
            duration: Date().timeIntervalSince(state.startedAt),
            reasoningTokens: state.reasoningTokens,
            toolCalls: state.toolCallsMade.count,
            writes: state.writeOperations.count,
            violations: state.violations
        )
    }

    public func recordReasoning(
        turnId: String,
        tokens: Int,
        context: String
    ) -> BehaviorCheckResult {
        guard var state = activeTurns[turnId] else { return .turnNotFound }
        state.reasoningTokens += tokens
        let constraints = getConstraints(for: context)
        if state.reasoningTokens > constraints.maxReasoningWithoutAction && state.toolCallsMade.isEmpty {
            let violation = BehaviorViolation(
                failure: .analysisParalysis,
                severity: .moderate,
                description: "Agent generated \(state.reasoningTokens) tokens without taking any action",
                suggestedAction: .forceEnvironmentCheck
            )
            state.violations.append(violation)
            recordViolation(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }
        activeTurns[turnId] = state
        return .ok
    }

    public func recordToolCall(
        turnId: String,
        toolName: String,
        context: String,
        waitedForResult: Bool = true
    ) -> BehaviorCheckResult {
        guard var state = activeTurns[turnId] else { return .turnNotFound }
        let constraints = getConstraints(for: context)
        let isEnvCheck = constraints.environmentCheckTools.contains(toolName)
        state.toolCallsMade.append(
            ToolCallRecord(
                toolName: toolName,
                timestamp: Date(),
                isEnvironmentCheck: isEnvCheck,
                waitedForResult: waitedForResult
            )
        )
        if isEnvCheck { state.lastEnvironmentCheck = Date() }

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
                recordViolation(violation)
                activeTurns[turnId] = state
                return .violation(violation)
            }
        }

        activeTurns[turnId] = state
        return .ok
    }

    public func recordWrite(
        turnId: String,
        operationType: String,
        targetEntity: String?,
        context: String,
        wasConfirmed: Bool = false
    ) -> BehaviorCheckResult {
        guard var state = activeTurns[turnId] else { return .turnNotFound }
        let constraints = getConstraints(for: context)

        state.writeOperations.append(
            WriteOperationRecord(operationType: operationType, timestamp: Date())
        )

        if constraints.highImpactOperations.contains(operationType) && !wasConfirmed {
            let violation = BehaviorViolation(
                failure: .uncheckedHighImpact,
                severity: .severe,
                description: "High-impact operation '\(operationType)' executed without confirmation",
                suggestedAction: .blockAndEscalate
            )
            state.violations.append(violation)
            recordViolation(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }

        if state.writeOperations.count > constraints.maxWritesPerTurn {
            let violation = BehaviorViolation(
                failure: .rogueActionSequence,
                severity: .moderate,
                description: "Exceeded max writes per turn: \(state.writeOperations.count) > \(constraints.maxWritesPerTurn)",
                suggestedAction: .pauseAndReview
            )
            state.violations.append(violation)
            recordViolation(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }

        activeTurns[turnId] = state
        return .ok
    }

    public func recordAnswer(
        turnId: String,
        confidence: Double,
        hadToolVerification: Bool,
        context: String
    ) -> BehaviorCheckResult {
        guard var state = activeTurns[turnId] else { return .turnNotFound }
        let constraints = getConstraints(for: context)

        if confidence > constraints.maxUnverifiedConfidence && !hadToolVerification {
            let violation = BehaviorViolation(
                failure: .ungroundedConfidence,
                severity: .warning,
                description: "High confidence (\(confidence)) answer without tool verification",
                suggestedAction: .warn
            )
            state.violations.append(violation)
            recordViolation(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }

        if state.lastEnvironmentCheck == nil && state.toolCallsMade.isEmpty {
            let violation = BehaviorViolation(
                failure: .prematureDisengagement,
                severity: .moderate,
                description: "Produced answer without checking any external signals",
                suggestedAction: .forceEnvironmentCheck
            )
            state.violations.append(violation)
            recordViolation(violation)
            activeTurns[turnId] = state
            return .violation(violation)
        }

        activeTurns[turnId] = state
        return .ok
    }

    public func acknowledgeUncertainty(turnId: String) {
        guard var state = activeTurns[turnId] else { return }
        state.uncertaintyAcknowledged = true
        activeTurns[turnId] = state
    }

    public func setConstraints(_ constraints: AgentBehaviorConstraints, for context: String) {
        contextConstraints[context] = constraints
    }

    public func statistics() -> BehaviorStatistics {
        let byFailure = Dictionary(grouping: violationHistory, by: \.failure).mapValues(\.count)
        let bySeverity = Dictionary(grouping: violationHistory, by: \.severity).mapValues(\.count)
        return BehaviorStatistics(
            totalViolations: violationHistory.count,
            violationsByType: byFailure,
            violationsBySeverity: bySeverity,
            activeTurns: activeTurns.count
        )
    }

    public func pruneHistory() {
        if violationHistory.count > maxHistorySize {
            violationHistory.removeFirst(violationHistory.count - maxHistorySize)
        }
    }

    public func governedContext(
        turnId: String,
        context: String
    ) -> GovernedInferenceContext {
        GovernedInferenceContext(turnId: turnId, context: context, governor: self)
    }

    private func getConstraints(for context: String) -> AgentBehaviorConstraints {
        contextConstraints[context] ?? defaultConstraints
    }

    private func recordViolation(_ violation: BehaviorViolation) {
        violationHistory.append(violation)
        if violationHistory.count > maxHistorySize {
            violationHistory.removeFirst(violationHistory.count - maxHistorySize)
        }
    }
}

public struct GovernedInferenceContext: Sendable {
    public let turnId: String
    public let context: String
    public let governor: AgentBehaviorGovernor

    public func recordReasoning(tokens: Int) async -> Bool {
        let result = await governor.recordReasoning(turnId: turnId, tokens: tokens, context: context)
        return result.isOk
    }

    public func recordTool(name: String, waitedForResult: Bool) async -> Bool {
        let result = await governor.recordToolCall(turnId: turnId, toolName: name, context: context, waitedForResult: waitedForResult)
        return result.isOk
    }

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
