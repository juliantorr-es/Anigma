//
//  TargetEnumerator.swift
//  HarmoniaModule
//
//  Deterministic enumeration and ranking of improvement targets for Phase 9.1.
//  Produces a canonical, stable list of targets with explicit ordering rules.
//  All ordering is deterministic - no filesystem iteration, tool output order, or dict order.
//

import AnigmaPrimitives
@preconcurrency import Foundation

/// Enumerated improvement target for Phase 9.1 multi-target runs.
public struct EnumeratedTarget: Codable, Sendable, Equatable {
    public let targetId: String
    public let targetType: String
    public let scope: String  // e.g., "component:core", "directory:sources/parsing"
    public let description: String
    public let metrics: TargetMetrics
    public let rank: Int  // Deterministic rank from enumeration

    public init(
        targetId: String,
        targetType: String,
        scope: String,
        description: String,
        metrics: TargetMetrics,
        rank: Int
    ) {
        self.targetId = targetId
        self.targetType = targetType
        self.scope = scope
        self.description = description
        self.metrics = metrics
        self.rank = rank
    }
}

/// Metrics for a target used in deterministic ranking.
public struct TargetMetrics: Codable, Sendable, Equatable {
    public let errorCount: Int
    public let warningCount: Int
    public let complexityScore: Int  // Integer-safe complexity metric
    public let lastModifiedSequence: Int  // Sequence number, not wall-clock time

    public init(
        errorCount: Int,
        warningCount: Int,
        complexityScore: Int,
        lastModifiedSequence: Int
    ) {
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.complexityScore = complexityScore
        self.lastModifiedSequence = lastModifiedSequence
    }
}

/// Scoring function configuration for deterministic target ranking.
public struct ScoringPolicy: Codable, Sendable, Equatable {
    public let version: String  // Policy version hash
    public let errorWeight: Int
    public let warningWeight: Int
    public let complexityWeight: Int
    public let recencyBonus: Int

    public init(
        version: String,
        errorWeight: Int = 100,
        warningWeight: Int = 50,
        complexityWeight: Int = -10,
        recencyBonus: Int = 5
    ) {
        self.version = version
        self.errorWeight = errorWeight
        self.warningWeight = warningWeight
        self.complexityWeight = complexityWeight
        self.recencyBonus = recencyBonus
    }

    /// Create hash of the scoring policy for determinism verification
    public func hash() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(self)
        return BLAKE3Digest.hex(of: data)
    }
}

/// Candidate budgeting policy for Phase 9.1.
public struct CandidateBudgetPolicy: Codable, Sendable, Equatable {
    public let candidatesPerTarget: Int  // K value
    public let maxCandidatesToKeep: Int  // Pruning rule
    public let scoringThreshold: Int  // Early-exit if score below threshold

    public init(
        candidatesPerTarget: Int = 5,
        maxCandidatesToKeep: Int = 10,
        scoringThreshold: Int = 0
    ) {
        self.candidatesPerTarget = candidatesPerTarget
        self.maxCandidatesToKeep = maxCandidatesToKeep
        self.scoringThreshold = scoringThreshold
    }
}

/// Stop condition specification for Phase 9.1 loops.
public struct StopCondition: Codable, Sendable, Equatable {
    public let maxTargetsToProcess: Int
    public let maxSuccessfulTransitions: Int
    public let stopOnFirstFailure: Bool
    public let timeoutSequenceNumber: Int  // Sequence-based timeout, not wall-clock

    public init(
        maxTargetsToProcess: Int = 1,
        maxSuccessfulTransitions: Int = 1,
        stopOnFirstFailure: Bool = true,
        timeoutSequenceNumber: Int = 0
    ) {
        self.maxTargetsToProcess = maxTargetsToProcess
        self.maxSuccessfulTransitions = maxSuccessfulTransitions
        self.stopOnFirstFailure = stopOnFirstFailure
        self.timeoutSequenceNumber = timeoutSequenceNumber
    }
}

/// Deterministic target enumerator for Phase 9.1.
/// Produces a canonical list of targets from IR with stable ordering.
public struct TargetEnumerator {

    /// Enumerate targets from IR store with deterministic ordering.
    public static func enumerate(
        from irStore: IRStore,
        scope: String,
        scoringPolicy: ScoringPolicy
    ) async throws -> [EnumeratedTarget] {

        // Get all projects in the scope
        let allProjects = await irStore.listProjects()
        let scopedProjects = allProjects.filter { project in
            project.scope == scope
        }

        // Convert to targets and rank them deterministically
        var targets: [EnumeratedTarget] = []

        for project in scopedProjects.sorted(by: { $0.projectId < $1.projectId }) {
            let components = await irStore.getComponentsForProject(project.projectId)

            // Sort components deterministically by ID
            for component in components.sorted(by: { $0.componentId < $1.componentId }) {
                let metrics = try await computeTargetMetrics(
                    for: component,
                    in: irStore
                )

                let score = try computeScore(
                    metrics: metrics,
                    policy: scoringPolicy
                )

                let target = EnumeratedTarget(
                    targetId: component.componentId,
                    targetType: component.type,
                    scope: "\(project.name):\(component.name)",
                    description: "Improvement target for \(component.name)",
                    metrics: metrics,
                    rank: score
                )

                targets.append(target)
            }
        }

        // Sort by rank (highest first), then by ID for determinism
        targets.sort { a, b in
            if a.rank != b.rank {
                return a.rank > b.rank
            }
            return a.targetId < b.targetId
        }

        // Add canonical ranks based on sorted position
        return targets.enumerated().map { index, target in
            EnumeratedTarget(
                targetId: target.targetId,
                targetType: target.targetType,
                scope: target.scope,
                description: target.description,
                metrics: target.metrics,
                rank: index + 1
            )
        }
    }

    /// Compute metrics for a target from IR data.
    private static func computeTargetMetrics(
        for component: IRComponent,
        in irStore: IRStore
    ) async throws -> TargetMetrics {

        // Get all traces for this component
        let allTraces = await irStore.getTracesByEventType("tool_completed")
        let componentTraces = allTraces.filter { trace in
            trace.sourceEntity == component.componentId
        }

        let errorCount = componentTraces.filter { trace in
            trace.details["status"] == "failed"
        }.count

        let warningCount = componentTraces.filter { trace in
            trace.details["severity"] == "warning"
        }.count

        // Complexity is derived from metrics
        let metrics = await irStore.getMetricsForEntity(component.componentId)
        let complexityScore = metrics.reduce(0) { sum, metric in
            metric.value > 0 ? sum + Int(metric.value) : sum
        }

        let sequence = deterministicSequenceNumber(
            for: component,
            metrics: metrics
        )

        return TargetMetrics(
            errorCount: errorCount,
            warningCount: warningCount,
            complexityScore: complexityScore,
            lastModifiedSequence: sequence
        )
    }

    /// Compute deterministic integer score for a target.
    /// Score is derived only from metrics and policy - no randomness.
    private static func computeScore(
        metrics: TargetMetrics,
        policy: ScoringPolicy
    ) throws -> Int {

        var score = 0

        // Apply weighted scoring
        score += metrics.errorCount * policy.errorWeight
        score += metrics.warningCount * policy.warningWeight
        score -= metrics.complexityScore * policy.complexityWeight
        score += policy.recencyBonus * (metrics.lastModifiedSequence % 10)

        return max(0, score)  // Ensure non-negative
    }

    private static func deterministicSequenceNumber(
        for component: IRComponent,
        metrics: [IRMetrics]
    ) -> Int {
        let metricFingerprint =
            metrics
            .map { "\($0.metricType)=\($0.value)" }
            .sorted()
            .joined(separator: "|")

        let fields = [
            component.componentId,
            component.name,
            component.projectId,
            component.type,
            component.filePath ?? "",
            component.hash ?? "",
            metricFingerprint
        ]
        let digest = BLAKE3Digest.hex(
            of: (fields.joined(separator: "|")).data(using: .utf8) ?? Data())
        let value = UInt64(digest.prefix(16), radix: 16) ?? 0
        return Int(value % UInt64(Int.max))
    }
}

/// Records enumeration results in event log.
public struct TargetEnumerationEvent: GovernanceEvent {
    public let eventId: String
    public var eventType: String = "targets.enumerated"
    public var version: Int = 1
    public let timestamp: Date
    public let sessionId: String
    public let scope: String
    public let targetCount: Int
    public let scoringPolicyHash: String
    public let enumeratedTargets: [EnumeratedTarget]

    public init(
        sessionId: String,
        scope: String,
        targets: [EnumeratedTarget],
        scoringPolicyHash: String
    ) {
        self.eventId = "targets-enumerated-\(sessionId.prefix(8))"
        self.timestamp = Date()
        self.sessionId = sessionId
        self.scope = scope
        self.targetCount = targets.count
        self.scoringPolicyHash = scoringPolicyHash
        self.enumeratedTargets = targets
    }
}

/// Validates that target enumeration meets determinism contract.
public struct TargetEnumerationContract {

    /// Verify enumeration is deterministic and policy-driven.
    public static func validate(_ targets: [EnumeratedTarget]) throws {
        // All targets must have valid IDs
        for target in targets {
            guard !target.targetId.isEmpty else {
                throw TargetEnumerationError.emptyTargetId
            }
        }

        // Ranks must be sequential and non-zero
        let expectedRanks = Set(1...targets.count)
        let actualRanks = Set(targets.map { $0.rank })

        guard expectedRanks == actualRanks else {
            throw TargetEnumerationError.nonSequentialRanks(
                expected: expectedRanks, actual: actualRanks)
        }

        // Targets must be sorted by rank
        for i in 0..<targets.count - 1 {
            guard targets[i].rank < targets[i + 1].rank else {
                throw TargetEnumerationError.unsortedTargets(position: i)
            }
        }
    }
}

/// Errors in target enumeration.
public enum TargetEnumerationError: Error, LocalizedError {
    case emptyTargetId
    case nonSequentialRanks(expected: Set<Int>, actual: Set<Int>)
    case unsortedTargets(position: Int)
    case scoringPolicyMismatch(expected: String, actual: String)

    public var localizedDescription: String? {
        switch self {
        case .emptyTargetId:
            return "Target enumeration produced empty target ID"
        case .nonSequentialRanks(let expected, let actual):
            return "Target ranks are not sequential: expected \(expected), got \(actual)"
        case .unsortedTargets(let position):
            return "Targets not properly sorted by rank at position \(position)"
        case .scoringPolicyMismatch(let expected, let actual):
            return "Scoring policy mismatch: expected \(expected), got \(actual)"
        }
    }
}
