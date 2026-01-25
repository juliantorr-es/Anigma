//
//  ExecutionCorePolicyEvaluator.swift
//  HarmoniaModule
//
//  PolicyEvaluator adapter that bridges ExecutionCore protocol to HarmoniaModule's existing governance mechanisms.
//  Maintains policy boundary while allowing ExecutionCore to record decisions.
//

import ExecutionCore
@preconcurrency import Foundation
import TelemetryCore

/// Adapter that makes HarmoniaModule's governance mechanisms compatible with ExecutionCore's PolicyEvaluator protocol.
/// This ensures no policy logic duplication and maintains the architectural boundary.
public actor ExecutionCorePolicyEvaluator: PolicyEvaluator {
    public let evaluatorID: String = "execution-core-adapter"

    private let swift6StepEngine: any Swift6StepEngine

    public init(engine: any Swift6StepEngine = BasicSwift6StepEngine()) {
        self.swift6StepEngine = engine
    }

    public func evaluatePhaseTransition(
        from currentPhase: String,
        to requestedPhase: String,
        authority: String,
        context: [String: Sendable]
    ) async throws -> ExecutionCore.PolicyDecision {

        // Create Harmonia request context
        let requestContext = createPolicyRequestContext(
            currentPhase: currentPhase,
            requestedPhase: requestedPhase,
            authority: authority,
            context: context
        )

        let migrationState = buildMigrationState(from: context)
        let policy = Swift6MigrationPolicy.default
        let intent = swift6StepEngine.chooseNextStep(from: migrationState, policy: policy)

        let (decision, reason) = convertIntentToDecision(intent)

        let contextHash = TelemetryHash(input: serializeContext(requestContext))
        let metadata: [String: TelemetryValue] = [
            "intent": .hashedToken(TelemetryHash(input: "\(intent)")),
            "currentPhase": .hashedToken(TelemetryHash(input: currentPhase)),
            "requestedPhase": .hashedToken(TelemetryHash(input: requestedPhase)),
            "authority": .hashedToken(TelemetryHash(input: authority))
        ]

        return ExecutionCore.PolicyDecision(
            decision: decision,
            reasonCode: reason,
            authority: authority,
            contextHash: contextHash,
            metadata: metadata
        )
    }

    // MARK: - Helper Methods

    /// Creates a policy request context from ExecutionCore parameters
    private func createPolicyRequestContext(
        currentPhase: String,
        requestedPhase: String,
        authority: String,
        context: [String: Sendable]
    ) -> [String: Sendable] {
        return [
            "currentPhase": currentPhase,
            "requestedPhase": requestedPhase,
            "authority": authority,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "sessionId": UUID().uuidString,
            "requester": authority,
            "metadata": context
        ]
    }

    /// Converts step intent to a policy decision.
    private func convertIntentToDecision(_ intent: Swift6StepIntent) -> (ReceiptDecision, String) {
        switch intent {
        case .runTask:
            return (.allowed, "swift6_step_run_task")
        case .rescoutFile:
            return (.auditRequired, "swift6_step_rescout")
        case .pause(let reason):
            return (.denied, "swift6_step_pause:\(reason)")
        }
    }

    /// Build a minimal migration state from the incoming context.
    private func buildMigrationState(from context: [String: Sendable]) -> Swift6MigrationState {
        return Swift6MigrationState(
            projectId: context["projectId"] as? UUID ?? UUID(),
            totalFindings: context["totalFindings"] as? Int ?? 0,
            totalTasks: context["totalTasks"] as? Int ?? 0,
            openTasks: context["openTasks"] as? Int ?? 0,
            taintedSessions: context["taintedSessions"] as? Int ?? 0,
            recentSessions: [],
            files: [],
            overallHealthScore: context["overallHealthScore"] as? Double ?? 1.0
        )
    }

    /// Serializes context for hash calculation.
    private func serializeContext(_ context: [String: Sendable]) -> String {
        return context.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
    }
}
