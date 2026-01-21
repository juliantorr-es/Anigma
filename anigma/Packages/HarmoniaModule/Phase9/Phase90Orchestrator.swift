//
//  Phase90Orchestrator.swift
//  HarmoniaModule
//
//  Orchestrates the 7-stage Phase 9.0 loop with full verification.
//  Combines the pure kernel and governed executor with replay verification.
//

import AnigmaPrimitives
import DatabaseCore
import Foundation

/// Orchestrator for executing Phase 9.1 closed loop with deterministic replay verification.
/// Connects pure kernel (no side effects) with governed executor (side effects with evidence).
public actor Phase90Orchestrator {

    private let kernel: Phase9LoopKernel
    private let runner: Phase9LoopRunner
    private let verifier: Phase9ReplayVerifier
    private let targetCategory: String
    private let determinismValidator: InRunDeterminismValidator
    private let commitEnforcer: SingleCommitInvariantEnforcer
    private let evidenceCollector: RuntimeEvidenceCollector

    public init(
        eventLogBytes: Data,
        snapshotRootHash: String,
        policyPackVersion: String,
        toolchainVersion: String,
        targetCategory: String,
        session: SessionContext
    ) {
        let toolRouter = ToolRouter(
            loopBreaker: ToolCallLoopBreaker(),
            policyGate: PolicyGate(),
            evidenceRecorder: LoopMockEvidenceRecorder(),
            toolRegistry: ToolRegistry.shared
        )

        // Create Phase 9.1 policies
        let scoringPolicy = ScoringPolicy(
            version: "v1-base",
            errorWeight: 100,
            warningWeight: 50,
            complexityWeight: -10,
            recencyBonus: 5
        )

        let budgetPolicy = CandidateBudgetPolicy(
            candidatesPerTarget: 5,
            maxCandidatesToKeep: 10,
            scoringThreshold: 0
        )

        let stopCondition = StopCondition(
            maxTargetsToProcess: 3,
            maxSuccessfulTransitions: 1,
            stopOnFirstFailure: true,
            timeoutSequenceNumber: 0
        )

        self.kernel = Phase9LoopKernel(
            eventLogBytes: eventLogBytes,
            snapshotRootHash: snapshotRootHash,
            policyPackVersion: policyPackVersion,
            toolchainVersion: toolchainVersion,
            deterministicSeed: "seed-\(policyPackVersion)-\(toolchainVersion)-\(snapshotRootHash)",
            irStore: IRStore(),
            scoringPolicy: scoringPolicy,
            budgetPolicy: budgetPolicy,
            stopCondition: stopCondition
        )

        self.runner = Phase9LoopRunner(
            toolRouter: toolRouter,
            policyGate: PolicyGate(),
            session: session
        )

        // Create the replay verifier as hard gate
        self.verifier = Phase9ReplayVerifierFactory.createStandard(kernel: kernel)

        // Initialize runtime validators
        self.determinismValidator = InRunDeterminismValidator()
        self.commitEnforcer = SingleCommitInvariantEnforcer()

        // Initialize evidence collector with session ID
        self.evidenceCollector = RuntimeEvidenceCollector(sessionId: session.sessionId)

        self.targetCategory = targetCategory
    }

    /// Execute the full 7-stage loop with mandatory verification gate.
    /// Verification failure invalidates the entire run and preserves the log.
    public func executeLoop() async throws -> Phase90Result {
        var outputs: [String: String] = [:]
        let evidenceId: String = UUID().uuidString
        _ = true

        print("[Phase 9] Starting Phase 9.1 loop with multi-target enumeration")

        // Phase 9.2: Default pinned inputs for concurrency and policy
        let concurrencyLevel = 1  // Default to sequential
        let scoringPolicyVersion = kernel.scoringPolicy.version
        let abTestAssignment = "control"  // Default assignment

        // Record pinned inputs to event log
        try await runner.recordPinnedInputs(
            concurrencyLevel: concurrencyLevel,
            scoringPolicyVersion: scoringPolicyVersion,
            abTestAssignment: abTestAssignment
        )

        // Stage 0: Target Enumeration (kernel only)
        print("[Phase 9] Stage 0: Enumerating targets...")
        let (enumeratedTargets, enumerationHash) = try await kernel.enumerateTargets(
            scope: "directory:sources")

        // Record Stage 0 emission in outputs
        outputs["stage0_hash"] = enumerationHash
        outputs["stage0_target_count"] = "\(enumeratedTargets.count)"

        // Create enumeration results as stage artifact
        let scoringPolicyHash = try kernel.scoringPolicy.hash()
        _ = EnumerationResults(
            enumeratedTargets: enumeratedTargets,
            targetCount: enumeratedTargets.count,
            scoringPolicyHash: scoringPolicyHash,
            ranking: Array(0..<enumeratedTargets.count),
            hasDuplicates: false,
            policyHash: enumerationHash
        )

        // Validate enumeration determinism before proceeding
        try await determinismValidator.recordEnumeration(
            scope: "directory:sources",
            targets: enumeratedTargets,
            scoringPolicyHash: scoringPolicyHash,
            digest: enumerationHash
        )

        // Capture Stage 0 evidence
        try await evidenceCollector.captureStageEvidence(
            stage: 0,
            stageName: "Target Enumeration",
            evidenceType: "enumeration_results",
            workspaceSnapshotHash: kernel.snapshotRootHash,
            inputs: [
                "scope": "directory:sources",
                "scoringPolicyHash": scoringPolicyHash,
                "concurrencyLevel": "\(concurrencyLevel)",
                "scoringPolicyVersion": scoringPolicyVersion,
                "abTestAssignment": abTestAssignment
            ],
            outputs: [
                "targetCount": "\(enumeratedTargets.count)",
                "enumerationHash": enumerationHash
            ],
            artifacts: [:],
            metrics: [:],
            governance: [
                "deterministic": determinismValidator.hasViolations ? "false" : "true"
            ]
        )

        print(
            "[Phase 9] Stage 0 complete: Enumerated \(enumeratedTargets.count) targets (deterministic, evidence captured)"
        )

        // Stage 1: Trace Normalization (kernel only)
        print("[Phase 9] Stage 1: Normalizing traces...")
        let (trace, traceHash) = try kernel.normalizeTrace()
        outputs["stage1_hash"] = traceHash

        // Capture Stage 1 evidence
        try await evidenceCollector.captureStageEvidence(
            stage: 1,
            stageName: "Trace Normalization",
            evidenceType: "trace_processing",
            workspaceSnapshotHash: kernel.snapshotRootHash,
            inputs: [:],
            outputs: [
                "normalizedEventCount": "\(trace.normalizedEventCount)",
                "originalEventCount": "\(trace.originalEventCount)",
                "traceHash": traceHash
            ],
            artifacts: [:],
            metrics: [:],
            governance: [:]
        )

        print(
            "[Phase 9] Stage 1 complete: Normalized \(trace.normalizedEventCount)/\(trace.originalEventCount) events (evidence captured)"
        )

        // Stage 2: Metrics Computation (kernel only)
        print("[Phase 9] Stage 2: Computing metrics...")
        let irStore = IRStore()

        let (metrics, metricsHash) = try await kernel.computeMetrics(from: irStore)
        outputs["stage2_hash"] = metricsHash

        // Capture Stage 2 evidence
        try await evidenceCollector.captureStageEvidence(
            stage: 2,
            stageName: "Metrics Computation",
            evidenceType: "metrics_results",
            workspaceSnapshotHash: kernel.snapshotRootHash,
            inputs: [:],
            outputs: [
                "category": targetCategory,
                "metricsHash": metricsHash
            ],
            artifacts: [:],
            metrics: [:],
            governance: [:]
        )

        print(
            "[Phase 9] Stage 2 complete: Computed metrics for target: \(targetCategory) (evidence captured)"
        )

        // Stage 3: Target Selection (kernel only)
        print("[Phase 9] Stage 3: Selecting target...")
        let (target, targetHash) = try kernel.selectTarget(
            from: metrics, targetCategory: targetCategory)
        outputs["stage3_hash"] = targetHash

        // Capture Stage 3 evidence
        try await evidenceCollector.captureStageEvidence(
            stage: 3,
            stageName: "Target Selection",
            evidenceType: "target_selection",
            workspaceSnapshotHash: kernel.snapshotRootHash,
            inputs: [:],
            outputs: [
                "selectedTargetId": target.targetId,
                "targetType": target.targetType,
                "targetHash": targetHash
            ],
            artifacts: [:],
            metrics: [:],
            governance: [
                "deterministic": determinismValidator.hasViolations ? "false" : "true"
            ]
        )

        // Validate selection determinism
        try await determinismValidator.recordSelection(
            selectedTargetId: target.targetId,
            rank: 1,
            rationale: target.rationale
        )

        print(
            "[Phase 9] Stage 3 complete: Selected target: \(target.targetId) (\(target.targetType)), deterministic selection confirmed"
        )

        // Stage 4: Candidate Generation (kernel only)
        print("[Phase 9] Stage 4: Generating candidates...")
        let candidateCount = 5  // K parameter
        let (candidates, candidatesHash) = try kernel.generateCandidates(
            for: target, candidateCount: candidateCount)
        outputs["stage4_hash"] = candidatesHash
        print("[Phase 9] Stage 4 complete: Generated \(candidates.candidates.count) candidates")

        // Stage 5: Validation & Policy Evaluation (runner with tool interactions)
        print("[Phase 9] Stage 5: Validating candidates...")

        let validationResults = try await runner.validateCandidates(
            candidates: candidates,
            against: kernel.snapshotRootHash
        )

        outputs["stage5_validation_results"] = "votes:\(validationResults.votes.count)"
        print(
            "[Phase 9] Stage 5 complete: Validation completed with \(validationResults.votes.count) votes"
        )

        // Stage 6: Single Transition Commit (runner with tool interactions)
        print("[Phase 9] Stage 6: Applying approved transition...")

        // Enforce single-commit invariant before attempting transition
        try await commitEnforcer.attemptCommit(
            reason: "Stage 6 state transition for target \(target.targetId)")

        guard let approvedCandidate = validationResults.approvedCandidate else {
            let error = NoApprovedCandidateError()
            print("[Phase 9] ERROR: No approved candidate found")
            throw error
        }

        let stateTransition = try await runner.commitTransition(
            for: approvedCandidate,
            toSnapshot: kernel.snapshotRootHash
        )

        outputs["stage6_transition_hash"] = BLAKE3Digest.hex(
            of: try JSONEncoder().encode(stateTransition))
        print(
            "[Phase 9] Stage 6 complete: State transition committed to \(stateTransition.toState)")

        // Stage 7: Mandatory Replay Verification Gate
        print("[Phase 9] Stage 7: Verifying replay as mandatory gate...")

        // Get the event log preserved from the run
        let eventLogBytes = try await runner.getEventLogBytes()

        // Create verification inputs based on pinned environment
        // Phase 9.2: Include concurrency level and policy version as pinned inputs
        let verificationInputs = VerificationInputs(
            eventLogBytes: eventLogBytes,
            workspaceSnapshotHash: kernel.snapshotRootHash,
            policyPackHash: kernel.policyPackVersion,
            normalizerVersion: InputNormalizer.currentVersion,
            toolchainFingerprint: kernel.toolchainVersion,
            sessionSeed: kernel.deterministicSeed,
            concurrencyLevel: concurrencyLevel,
            scoringPolicyVersion: scoringPolicyVersion,
            abTestAssignment: abTestAssignment
        )

        // Run formal verification - this is a hard gate
        let verificationResult = try await verifier.verify(verificationInputs)

        switch verificationResult {
        case .pass:
            print("[Phase 9] Stage 7 complete: DETERMINISTIC - verification passed")
        case .fail(let report):
            // Create verification failure that preserves the log
            let gateError = VerificationGateError(
                stage: report.stage,
                classification: report.classification,
                firstDiffOffset: report.firstDiffOffset,
                artifactId: report.artifactId
            )

            // Record verification failure as first-class artifact
            let failureDescription = "\(report.stage):\(report.classification)"
            try await evidenceCollector.captureStageEvidence(
                stage: 7,
                stageName: "Replay Verification",
                evidenceType: "verification_failure",
                workspaceSnapshotHash: kernel.snapshotRootHash,
                inputs: [:],
                outputs: ["failure": failureDescription],
                artifacts: [:],
                metrics: [:],
                governance: [:]
            )

            // Fail closed - verification is mandatory
            throw gateError
        }

        // Create result - verification passed so deterministic is true
        return Phase90Result(
            success: true,
            evidenceId: evidenceId,
            resultTypes: [
                "Enumeration",
                "Normalization",
                "Metrics",
                "Selection",
                "Generation",
                "Validation",
                "Transition",
                "Verification"
            ],
            stageOutputHashes: outputs,
            stateTransition: stateTransition
        )
    }
}

// MARK: - Supporting Types

public struct Phase90Result: Codable, Sendable {
    public let success: Bool
    public let evidenceId: String
    public let resultTypes: [String]  // Stage names
    public let stageOutputHashes: [String: String]  // Hash at each stage boundary
    public let stateTransition: StateTransition?  // Final state transition if any
}

/// Error when no candidate is approved during validation
public struct NoApprovedCandidateError: Error, LocalizedError {
    var localizedDescription: String? = "No approved candidate found during validation"
}

/// Error when mandatory verification gate fails
public struct VerificationGateError: Error, LocalizedError {
    public let stage: String
    public let classification: String
    public let firstDiffOffset: Int
    public let artifactId: String

    public var localizedDescription: String? {
        return
            "Verification gate failed at stage \(stage): \(classification) at offset \(firstDiffOffset) in artifact \(artifactId)"
    }
}
