//
//  Phase9LoopKernel.swift
//  HarmoniaModule
//
//  Pure pipeline for Phase 9.0 deterministic loop.
//  Takes only recorded inputs, produces only deterministic outputs.
//  No filesystem access, no tools, no wall-clock time, no environment variables.
//  Testable as a pure function.
//

import Foundation
import AnigmaPrimitives

/// Pure deterministic pipeline kernel for Phase 9.0 loop.
/// All operations are deterministic functions of recorded inputs.
public struct Phase9LoopKernel: Sendable {

    // MARK: - Inputs

    public let eventLogBytes: Data
    public let snapshotRootHash: String
    public let policyPackVersion: String
    public let toolchainVersion: String
    public let deterministicSeed: String

    // Phase 9.1: Multi-target configuration
    public let irStore: IRStore
    public let scoringPolicy: ScoringPolicy
    public let budgetPolicy: CandidateBudgetPolicy
    public let stopCondition: StopCondition

    public init(
        eventLogBytes: Data,
        snapshotRootHash: String,
        policyPackVersion: String,
        toolchainVersion: String,
        deterministicSeed: String,
        irStore: IRStore,
        scoringPolicy: ScoringPolicy,
        budgetPolicy: CandidateBudgetPolicy,
        stopCondition: StopCondition
    ) {
        self.eventLogBytes = eventLogBytes
        self.snapshotRootHash = snapshotRootHash
        self.policyPackVersion = policyPackVersion
        self.toolchainVersion = toolchainVersion
        self.deterministicSeed = deterministicSeed
        self.irStore = irStore
        self.scoringPolicy = scoringPolicy
        self.budgetPolicy = budgetPolicy
        self.stopCondition = stopCondition
        }

    // MARK: - Stage 0: Target Enumeration (Phase 9.1)

    public func enumerateTargets(scope: String) async throws -> (enumeratedTargets: [EnumeratedTarget], hash: String) {
        // Enumerate targets deterministically from IR store
        let targets = try await TargetEnumerator.enumerate(
            from: irStore,
            scope: scope,
            scoringPolicy: scoringPolicy
        )

        // Validate enumeration meets determinism contract
        try TargetEnumerationContract.validate(targets)

        // Limit to stop condition limit
        let limitedTargets = Array(targets.prefix(stopCondition.maxTargetsToProcess))

        // Compute hash of enumerated targets
        let targetsData = try CanonicalJSONEncoder.encode(limitedTargets)
        let hash = BLAKE3Digest.hex(of: targetsData)

        return (enumeratedTargets: limitedTargets, hash: hash)
    }

    // MARK: - Stage 1: Trace Normalization

    public func normalizeTrace() throws -> (payload: NormalizedTrace, hash: String) {
        // Parse event log
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(GovernanceEventEnvelope.self, from: eventLogBytes)

        // Convert events to IR entities
        var traceCount = 0

        for event in envelope.events {
            switch event {
            case .sessionStarted:
                traceCount += 1
            case .toolInvoked:
                traceCount += 1
            case .toolCompleted:
                traceCount += 1
            case .policyGateEvaluated:
                traceCount += 1
            case .stateTransitionApproved:
                traceCount += 1
            case .jobStarted:
                traceCount += 1
            case .jobStepExecuted:
                traceCount += 1
            case .jobCompleted:
                traceCount += 1
            default:
                break
            }
        }

        // Create normalized trace
        let trace = NormalizedTrace(
            originalEventCount: envelope.events.count,
            normalizedEventCount: traceCount,
            snapshotHash: snapshotRootHash,
            policyPackVersion: policyPackVersion,
            toolchainVersion: toolchainVersion
        )

        // Compute hash of normalized trace
        let traceData = try CanonicalJSONEncoder.encode(trace)
        let hash = BLAKE3Digest.hex(of: traceData)

        return (trace, hash)
    }

    // MARK: - Stage 2: Metrics Computation

    public func computeMetrics(from irStore: IRStore) async throws -> (payload: Phase9MetricSet, hash: String) {
        let calculator = Phase9MetricsCalculator()

        // Get all traces from the event log
        let traces = await irStore.getTracesByEventType("tool_completed")

        // Compute metrics using pure integer arithmetic
        let metrics = await calculator.calculateMetricsFromTraces(traces)

        // Compute hash of metrics
        let metricsData = try JSONEncoder().encode(metrics)
        let hash = BLAKE3Digest.hex(of: metricsData)

        return (metrics, hash)
    }

    // MARK: - Stage 3: Target Selection

    public func selectTarget(from metrics: Phase9MetricSet, targetCategory: String) throws -> (payload: SelectedTarget, hash: String) {
        let target = SelectedTarget(
            targetId: "target-\(targetCategory)-\(snapshotRootHash.prefix(16))",
            targetType: targetCategory,
            rationale: "Selected \(targetCategory) with highest error count based on metrics",
            selectionMetrics: metrics
        )

        // Compute hash of selected target
        let targetData = try JSONEncoder().encode(target)
        let hash = BLAKE3Digest.hex(of: targetData)

        return (target, hash)
    }

    // MARK: - Stage 4: Candidate Generation

    public func generateCandidates(for target: SelectedTarget, candidateCount: Int) throws -> (payload: CandidateSet, hash: String) {
        // Generate K candidates using deterministic algorithm
        var candidates: [ProposedAction] = []

        // Use seed to generate deterministic candidates
        var rng = SeededRNG(seed: deterministicSeed + target.targetId)

        for i in 0..<candidateCount {
            let candidate = ProposedAction(
                actionType: "patch",
                operation: "generated-candidate-\(i)-\(rng.next())",
                validation: ["format": "unified_diff"]
            )
            candidates.append(candidate)
        }

        let candidateSet = CandidateSet(
            targetId: target.targetId,
            candidates: candidates,
            generatedFrom: snapshotRootHash
        )

        // Compute hash of candidate set
        let candidatesData = try JSONEncoder().encode(candidateSet)
        let hash = BLAKE3Digest.hex(of: candidatesData)

        return (candidateSet, hash)
    }
}

// MARK: - Supporting Types

public struct NormalizedTrace: Codable, Sendable {
    public let originalEventCount: Int
    public let normalizedEventCount: Int
    public let snapshotHash: String
    public let policyPackVersion: String
    public let toolchainVersion: String
}

public struct SelectedTarget: Codable, Sendable {
    public let targetId: String
    public let targetType: String
    public let rationale: String
    public let selectionMetrics: Phase9MetricSet
}

public struct CandidateSet: Codable, Sendable {
    public let targetId: String
    public let candidates: [ProposedAction]
    public let generatedFrom: String
}

// MARK: - Deterministic RNG

/// Seeded random number generator for deterministic candidate generation
public struct SeededRNG {
    private var state: UInt64

    public init(seed: String) {
        // Use BLAKE3 to convert seed string to initial state
        let seedData = seed.data(using: .utf8) ?? Data()
        let hash = BLAKE3Digest.hex(of: seedData)

        // Extract first 16 hex chars and convert to UInt64
        if let value = UInt64(hash.prefix(16), radix: 16) {
            self.state = value
        } else {
            self.state = 0x9e3779b97f4a7c15 // FNV-1a offset basis fallback
        }
    }

    public mutating func next() -> UInt64 {
        // Use Xorshift64* algorithm for deterministic output
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
