//
//  ConcurrentTargetEnumerator.swift
//  HarmoniaModule
//
//  Concurrent target enumeration for Phase 9.2.
//  Enables deterministic parallel processing of targets while preserving ordering guarantees.
//

import AnigmaPrimitives
@preconcurrency import Foundation

/// Concurrent target enumerator for Phase 9.2.
/// Processes targets in parallel while maintaining deterministic ordering.
public actor ConcurrentTargetEnumerator {

    /// Enumerate targets with concurrent processing.
    /// Results are deterministically merged by targetId.
    public func enumerateParallel(
        from irStore: IRStore,
        scope: String,
        scoringPolicy: ScoringPolicy,
        stopCondition: StopCondition,
        concurrencyLevel: Int
    ) async throws -> [EnumeratedTarget] {

        // Get all projects in the scope
        let allProjects = await irStore.listProjects()
        let scopedProjects = allProjects.filter { project in
            project.scope == scope
        }

        // Partition projects for parallel processing
        let partitions = partitionProjects(scopedProjects, into: concurrencyLevel)

        // Process each partition in parallel
        var allTargetsSets: [[EnumeratedTarget]] = []

        for partition in partitions {
            async let partitionTargets = processPartition(
                partition,
                irStore: irStore,
                scoringPolicy: scoringPolicy,
                stopCondition: stopCondition
            )

            let targets = try await partitionTargets
            allTargetsSets.append(targets)
        }

        // Deterministically merge results
        let mergedTargets =
            allTargetsSets
            .flatMap { $0 }
            .sorted { lhs, rhs in
                if lhs.rank == rhs.rank {
                    return lhs.targetId < rhs.targetId
                }
                return lhs.rank < rhs.rank
            }

        // Apply final policy-based limits
        let targets = try applyStopCondition(mergedTargets, stopCondition: stopCondition)

        // Re-rank to maintain sequential ranks after merge
        let rerankedTargets = rerank(targets)

        return rerankedTargets
    }

    /// Partition projects for parallel processing.
    private func partitionProjects(
        _ projects: [IRProject],
        into concurrencyLevel: Int
    ) -> [[IRProject]] {

        // Simple hash-based partitioning for deterministic distribution
        var partitions: [[IRProject]] = Array(repeating: [], count: max(1, concurrencyLevel))

        for (index, project) in projects.enumerated() {
            let partitionIndex = index % max(1, concurrencyLevel)
            partitions[partitionIndex].append(project)
        }

        return partitions
    }

    /// Process a single partition of projects.
    private func processPartition(
        _ projects: [IRProject],
        irStore: IRStore,
        scoringPolicy: ScoringPolicy,
        stopCondition: StopCondition
    ) async throws -> [EnumeratedTarget] {

        var partitionTargets: [EnumeratedTarget] = []

        // Sort projects within partition for deterministic order despite parallel execution
        let sortedProjects = projects.sorted { $0.projectId < $1.projectId }

        for project in sortedProjects {
            let components = await irStore.getComponentsForProject(project.projectId)

            // Sort components deterministically
            let sortedComponents = components.sorted { $0.componentId < $1.componentId }

            for component in sortedComponents {
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

                partitionTargets.append(target)
            }
        }

        return partitionTargets
    }

    /// Compute metrics for a target from IR data.
    private func computeTargetMetrics(
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
    private func computeScore(
        metrics: TargetMetrics,
        policy: ScoringPolicy
    ) throws -> Int {

        var score = 0

        // Apply weighted scoring
        score += metrics.errorCount * policy.errorWeight
        score += metrics.warningCount * policy.warningWeight
        score -= metrics.complexityScore * policy.complexityWeight
        score += policy.recencyBonus * (metrics.lastModifiedSequence % 10)

        return max(0, score)
    }

    private func deterministicSequenceNumber(
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

    /// Apply stop condition limits.
    private func applyStopCondition(
        _ targets: [EnumeratedTarget],
        stopCondition: StopCondition
    ) throws -> [EnumeratedTarget] {

        // Apply target count limit
        let limitedTargets = Array(targets.prefix(stopCondition.maxTargetsToProcess))

        return limitedTargets
    }

    /// Re-rank targets with sequential numbers after merging.
    private func rerank(_ targets: [EnumeratedTarget]) -> [EnumeratedTarget] {
        var rerankedTargets: [EnumeratedTarget] = []

        for (index, target) in targets.enumerated() {
            let updatedTarget = EnumeratedTarget(
                targetId: target.targetId,
                targetType: target.targetType,
                scope: target.scope,
                description: target.description,
                metrics: target.metrics,
                rank: index + 1
            )
            rerankedTargets.append(updatedTarget)
        }

        return rerankedTargets
    }
}
