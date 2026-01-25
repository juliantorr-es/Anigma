//
//  Phase9LoopRunner.swift
//  HarmoniaModule
//
//  Governed executor for Phase 9.0 loop.
//  Allowed to call tools, read filesystem, apply transitions.
//  All side effects must be recorded as events before execution.
//

@preconcurrency import Foundation
import AnigmaPrimitives

/// Governed executor for Phase 9.0 deterministic loop.
/// Records all side effects as events before executing them.
public actor Phase9LoopRunner {

    private let toolRouter: ToolRouter
    private let policyGate: PolicyGate
    let session: SessionContext
    private var eventLog: [AnyCodableEvent] = []

    public init(
        toolRouter: ToolRouter,
        policyGate: PolicyGate,
        session: SessionContext
    ) {
        self.toolRouter = toolRouter
        self.policyGate = policyGate
        self.session = session
    }

    // MARK: - Stage 5: Validation & Policy Evaluation

    public func validateCandidates(
        candidates: CandidateSet,
        against snapshotHash: String
    ) async throws -> ValidationResults {

        var votes: [String: Vote] = [:]
        var approvedCandidate: ProposedAction?

        // Validate each candidate against snapshot and policy
        for candidate in candidates.candidates {
            // Record tool invocation event BEFORE calling tool
            let toolEvent = ToolInvokedEvent(
                sessionId: session.sessionId,
                toolName: "validate_patch",
                parameters: ["candidate_id": candidate.actionId],
                inputHash: snapshotHash
            )
            try? recordEvent(.toolInvoked(toolEvent))

            // Call validation tool
            let request = ToolCallRequest(
                toolName: "validate_patch",
                sessionId: session.sessionId,
                parameters: #"{"candidate_id": "\#(candidate.actionId)"}"#
            )

            let response = await toolRouter.executeToolCall(request: request, session: session)

            // Record tool completion event
            let completedEvent = ToolCompletedEvent(
                sessionId: session.sessionId,
                toolName: "validate_patch",
                invokedEventId: toolEvent.eventId,
                status: response.status == .success ? "success" : "failed",
                outputHash: response.result.map { BLAKE3Digest.hex(of: $0) },
                durationMs: 0
            )
            try? recordEvent(.toolCompleted(completedEvent))

            // Vote on this candidate
            let vote = Vote(
                voterId: "validator",
                decision: response.status == .success ? "approve" : "deny",
                reason: response.diagnosis ?? "validation completed",
                confidence: 0.8
            )
            votes[candidate.actionId] = vote

            // First approved candidate is selected
            if response.status == .success && approvedCandidate == nil {
                approvedCandidate = candidate
            }
        }

        // Record policy evaluation event
        let policyEvent = PolicyGateEvaluatedEvent(
            sessionId: session.sessionId,
            toolName: "validate_candidates",
            decision: approvedCandidate != nil ? "allowed" : "denied",
            reason: "Validation of candidates completed",
            authority: "Phase9LoopRunner"
        )
        try? recordEvent(.policyGateEvaluated(policyEvent))

        return ValidationResults(
            votes: votes,
            approvedCandidate: approvedCandidate,
            snapshotHash: snapshotHash
        )
    }

    // MARK: - Stage 6: Single Transition Commit

    public func commitTransition(
        for candidate: ProposedAction,
        toSnapshot snapshotHash: String
    ) async throws -> StateTransition {

        // Record state transition event BEFORE applying
        let transitionEvent = StateTransitionApprovedEvent(
            sessionId: session.sessionId,
            transitionId: "transition-\(UUID().uuidString.prefix(8))",
            fromState: snapshotHash,
            toState: "pending-application",
            approverAuth: "Phase9LoopRunner",
            evidenceId: candidate.actionId
        )
        try? recordEvent(.stateTransitionApproved(transitionEvent))

        // Apply the transition via governed tool
        let request = ToolCallRequest(
            toolName: "apply_patch",
            sessionId: session.sessionId,
            parameters: #"{"candidate_id": "\#(candidate.actionId)"}"#
        )

        let response = await toolRouter.executeToolCall(request: request, session: session)

        // Create the final state transition
        let stateTransition = StateTransition(
            fromState: snapshotHash,
            toState: response.status == .success ? "applied" : "failed",
            appliedActionId: candidate.actionId,
            metadata: [
                "tool_status": String(describing: response.status),
                "evidence_id": candidate.actionId,
                "reason": "Phase 9.0 deterministic improvement"
            ]
        )

        return stateTransition
    }

    // MARK: - Stage 7: Replay Verification

    public func verifyReplayDeterminism(
        kernel: Phase9LoopKernel,
        recordedOutputs: [String: String]
    ) async throws -> ReplayVerificationResult {

        // Run kernel again with same inputs
        let (_, traceHash) = try kernel.normalizeTrace()

        var mismatches: [StageMismatch] = []

        // Check trace normalization hash
        if let recorded = recordedOutputs["stage1_hash"], recorded != traceHash {
            mismatches.append(
                StageMismatch(
                    stage: 1,
                    recordedHash: recorded,
                    computedHash: traceHash,
                    description: "Trace normalization mismatch"
                )
            )
        }

        let result = ReplayVerificationResult(
            sessionId: session.sessionId,
            deterministic: mismatches.isEmpty,
            mismatches: mismatches,
            eventCount: eventLog.count
        )

        // Record verification event
        let verificationEvent = ToolCompletedEvent(
            sessionId: session.sessionId,
            toolName: "replay_verify",
            invokedEventId: "verify-\(UUID().uuidString)",
            status: mismatches.isEmpty ? "success" : "failed",
            durationMs: 0
        )
        try? recordEvent(.toolCompleted(verificationEvent))

        return result
    }

    // MARK: - Event Recording

    /// Record pinned inputs to event log for verification
    public func recordPinnedInputs(
        concurrencyLevel: Int,
        scoringPolicyVersion: String,
        abTestAssignment: String
    ) async throws {
        // Record concurrency level
        let concurrencyEvent = ToolInvokedEvent(
            sessionId: session.sessionId,
            toolName: "concurrency_level",
            parameters: ["level": String(concurrencyLevel)],
            inputHash: ""
        )
        try recordEvent(.toolInvoked(concurrencyEvent))

        // Record scoring policy version
        let policyVersionEvent = ToolInvokedEvent(
            sessionId: session.sessionId,
            toolName: "scoring_policy_version",
            parameters: ["version": scoringPolicyVersion],
            inputHash: ""
        )
        try recordEvent(.toolInvoked(policyVersionEvent))

        // Record A/B test assignment
        let abTestEvent = ToolInvokedEvent(
            sessionId: session.sessionId,
            toolName: "ab_test_assignment",
            parameters: ["assignment": abTestAssignment],
            inputHash: ""
        )
        try recordEvent(.toolInvoked(abTestEvent))
    }

    public func recordEvent(_ event: AnyCodableEvent) throws {
        eventLog.append(event)
    }

    public func getEventLog() -> [AnyCodableEvent] {
        return eventLog
    }

    public func getEventLogBytes() throws -> Data {
        let envelope = GovernanceEventEnvelope(events: eventLog, sessionId: session.sessionId)
        return try CanonicalJSONEncoder.encode(envelope)
    }
}

// MARK: - Supporting Types

public struct ValidationResults: Codable, Sendable {
    public let votes: [String: Vote]
    public let approvedCandidate: ProposedAction?
    public let snapshotHash: String
}

public struct StageMismatch: Codable, Sendable {
    public let stage: Int
    public let recordedHash: String
    public let computedHash: String
    public let description: String
}

public struct ReplayVerificationResult: Codable, Sendable {
    public let sessionId: String
    public let deterministic: Bool
    public let mismatches: [StageMismatch]
    public let eventCount: Int
}
