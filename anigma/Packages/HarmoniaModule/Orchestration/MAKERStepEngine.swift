//
//  MAKERStepEngine.swift
//  HarmoniaModule
//
//  Phase 8.5.3: MAKER Step Engine as minimal orchestrator
//  Emits proposals, runs validations, records votes/decisions, and commits
//  state transitions as append-only events following the Architect→Builder→Validator→Scribe→Scout pattern.
//

import ContractsCore
@preconcurrency import Foundation
import AnigmaPrimitives

// MARK: - Step Proposal

/// A proposal for improvement or change within a governed session.
public struct StepProposal: Codable, Sendable {
    public let proposalId: String
    public let sessionId: String
    public let targetType: String // "code", "config", "policy", etc.
    public let description: String
    public let candidateActions: [ProposedAction]
    public let estimatedRisk: Double // 0.0 to 1.0
    public let sequenceNumber: Int

    public init(
        sessionId: String,
        targetType: String,
        description: String,
        candidateActions: [ProposedAction],
        estimatedRisk: Double = 0.5
    ) {
        self.proposalId = "prop-\(sessionId.hashValue)-\(targetType.hashValue)"
        self.sessionId = sessionId
        self.targetType = targetType
        self.description = description
        self.candidateActions = candidateActions
        self.estimatedRisk = estimatedRisk
        self.sequenceNumber = Swift.abs(sessionId.hashValue)
    }
}

/// A single proposed action within a proposal.
public struct ProposedAction: Codable, Sendable {
    public let actionId: String
    public let actionType: String // "patch", "config_update", "policy_change", etc.
    public let operation: String
    public let validation: [String: String] // "type" -> validation check ID

    public init(
        actionType: String,
        operation: String,
        validation: [String: String] = [:]
    ) {
        self.actionId = "action-\(actionType.hashValue)-\(operation.hashValue)"
        self.actionType = actionType
        self.operation = operation
        self.validation = validation
    }
}

// MARK: - Step Execution Result

/// Result of executing a proposed step through the decision cycle.
public struct StepExecutionResult: Codable, Sendable {
    public let stepId: String
    public let proposalId: String
    public let sessionId: String
    public let status: String // "approved", "denied", "blocked", "error"
    public let selectedAction: ProposedAction?
    public let votes: [String: Vote]
    public let finalDecision: String
    public let appliedStateTransition: StateTransition?
    public let evidenceId: String?
    public let sequenceNumber: Int

    public init(
        stepId: String,
        proposalId: String,
        sessionId: String,
        status: String,
        selectedAction: ProposedAction? = nil,
        votes: [String: Vote] = [:],
        finalDecision: String,
        appliedStateTransition: StateTransition? = nil,
        evidenceId: String? = nil
    ) {
        self.stepId = stepId
        self.proposalId = proposalId
        self.sessionId = sessionId
        self.status = status
        self.selectedAction = selectedAction
        self.votes = votes
        self.finalDecision = finalDecision
        self.appliedStateTransition = appliedStateTransition
        self.evidenceId = evidenceId
        self.sequenceNumber = Swift.abs(sessionId.hashValue)
    }
}

/// A vote recorded during decision phase.
public struct Vote: Codable, Sendable {
    public let voterId: String
    public let decision: String // "approve", "deny", "abstain"
    public let reason: String
    public let confidence: Double // 0.0 to 1.0
    public let sequenceNumber: Int

    public init(
        voterId: String,
        decision: String,
        reason: String,
        confidence: Double = 0.5
    ) {
        self.voterId = voterId
        self.decision = decision
        self.reason = reason
        self.confidence = confidence
        self.sequenceNumber = Date().timeIntervalSince1970.hashValue
    }
}

/// A state transition committed by the engine.
public struct StateTransition: Codable, Sendable {
    public let transitionId: String
    public let fromState: String
    public let toState: String
    public let appliedActionId: String
    public let metadata: [String: String]
    public let sequenceNumber: Int

    public init(
        fromState: String,
        toState: String,
        appliedActionId: String,
        metadata: [String: String] = [:]
    ) {
        self.transitionId = UUID().uuidString
        self.fromState = fromState
        self.toState = toState
        self.appliedActionId = appliedActionId
        self.metadata = metadata
        self.sequenceNumber = Date().timeIntervalSince1970.hashValue
    }
}

// MARK: - MAKER Step Engine

/// MAKER Step Engine: Orchestrator for proposal→validation→decision→commit cycle.
/// Follows: Architect (propose) → Builder (validate) → Validator (evaluate) → Scribe (record) → Scout (verify).
public actor MAKERStepEngine {
    private let policyGate: PolicyGate
    private let sessionContext: SessionContext
    private var completedSteps: [StepExecutionResult] = []

    public init(policyGate: PolicyGate, sessionContext: SessionContext) {
        self.policyGate = policyGate
        self.sessionContext = sessionContext
    }

    /// Execute a complete step from proposal to commit.
    /// Returns result with approval status and applied transition (if approved).
    public func executeStep(proposal: StepProposal) async -> StepExecutionResult {
        let stepId = UUID().uuidString

        // Step 1: Architect → Propose (already done, proposal provided)

        // Step 2: Builder → Validate candidates against current state
        let validationResults = await validateCandidates(proposal: proposal)

        // Step 3: Validator → Evaluate against policies
        let policyDecision = await evaluatePolicy(proposal: proposal, validations: validationResults)

        // Step 4: Scribe → Record votes and decision
        let votes = await recordVotes(stepId: stepId, proposal: proposal, policyDecision: policyDecision)

        // Step 5: Scout → Apply state transition if approved
        let appliedTransition = policyDecision.isApproved ?
            applyStateTransition(proposal: proposal, selectedAction: proposal.candidateActions.first) : nil

        // Compile result
        let result = StepExecutionResult(
            stepId: stepId,
            proposalId: proposal.proposalId,
            sessionId: sessionContext.sessionId,
            status: policyDecision.isApproved ? "approved" : policyDecision.isBlocked ? "blocked" : "denied",
            selectedAction: proposal.candidateActions.first,
            votes: votes,
            finalDecision: policyDecision.reason,
            appliedStateTransition: appliedTransition,
            evidenceId: UUID().uuidString
        )

        // Store result for audit
        completedSteps.append(result)

        return result
    }

    /// Validate candidate actions against current state.
    private func validateCandidates(proposal: StepProposal) async -> [String: Bool] {
        var validations: [String: Bool] = [:]

        for action in proposal.candidateActions {
            // Perform basic validation
            let isValid = !action.operation.isEmpty && !action.actionType.isEmpty
            validations[action.actionId] = isValid
        }

        return validations
    }

    /// Evaluate proposal against governance policies.
    private func evaluatePolicy(proposal: StepProposal, validations: [String: Bool]) async -> PolicyEvaluation {
        // Check if all validations passed
        let allValid = validations.values.allSatisfy { $0 }

        // Risk-based decision
        let riskThreshold = 0.7
        let riskAcceptable = proposal.estimatedRisk < riskThreshold

        // Permission check
        let hasPermission = sessionContext.permissions.contains(.modifyCode)

        // Compile decision
        let isApproved = allValid && riskAcceptable && hasPermission
        let reason = isApproved ?
            "Proposal approved: valid, acceptable risk, sufficient permissions" :
            "Proposal denied: validation=\(allValid), risk=\(riskAcceptable), permission=\(hasPermission)"

        return PolicyEvaluation(
            isApproved: isApproved,
            isBlocked: !riskAcceptable,
            reason: reason
        )
    }

    /// Record votes from decision authority.
    private func recordVotes(stepId: String, proposal: StepProposal, policyDecision: PolicyEvaluation) async -> [String: Vote] {
        var votes: [String: Vote] = [:]

        let policyVote = Vote(
            voterId: "policy-gate",
            decision: policyDecision.isApproved ? "approve" : "deny",
            reason: policyDecision.reason,
            confidence: policyDecision.isApproved ? 0.9 : 0.8
        )

        votes["policy-gate"] = policyVote

        return votes
    }

    /// Apply state transition if approved.
    private func applyStateTransition(proposal: StepProposal, selectedAction: ProposedAction?) -> StateTransition? {
        guard let action = selectedAction else { return nil }

        let transition = StateTransition(
            fromState: "pending",
            toState: "applied",
            appliedActionId: action.actionId,
            metadata: [
                "proposal_type": proposal.targetType,
                "risk_level": String(format: "%.2f", proposal.estimatedRisk)
            ]
        )

        return transition
    }

    /// Get all completed steps in this session.
    public func getCompletedSteps() -> [StepExecutionResult] {
        return completedSteps
    }

    /// Get summary of step execution status.
    public func getSummary() -> StepEngineSummary {
        let total = completedSteps.count
        let approved = completedSteps.filter { $0.status == "approved" }.count
        let denied = completedSteps.filter { $0.status == "denied" }.count
        let blocked = completedSteps.filter { $0.status == "blocked" }.count

        return StepEngineSummary(
            totalSteps: total,
            approvedSteps: approved,
            deniedSteps: denied,
            blockedSteps: blocked,
            sessionId: sessionContext.sessionId
        )
    }
}

// MARK: - Supporting Types

/// Policy evaluation result from governance layer.
struct PolicyEvaluation {
    let isApproved: Bool
    let isBlocked: Bool
    let reason: String
}

/// Summary of step engine activity.
public struct StepEngineSummary: Codable, Sendable {
    public let totalSteps: Int
    public let approvedSteps: Int
    public let deniedSteps: Int
    public let blockedSteps: Int
    public let sessionId: String

    public var approvalRate: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(approvedSteps) / Double(totalSteps)
    }
}
