//
//  ParallelScoringPipeline.swift
//  HarmoniaModule
//
//  Parallel scoring pipeline for Phase 9.2 concurrency hardening.
//  Maintains deterministic ordering while leveraging parallel processing.
//

import Foundation

/// Parallel scoring pipeline for Phase 9.2.
/// Processes targets in parallel while maintaining deterministic scoring.
public actor ParallelScoringPipeline {

    private let scoringFunction: (TargetMetrics, ScoringPolicy) -> Int

    public init() {
        // Default scoring function imported from TargetEnumerator
        self.scoringFunction = { metrics, policy in
            var score = 0
            score += metrics.errorCount * policy.errorWeight
            score += metrics.warningCount * policy.warningWeight
            score -= metrics.complexityScore * policy.complexityWeight
            score += policy.recencyBonus * (metrics.lastModifiedSequence % 10)
            return max(0, score)
        }
    }

    /// Score targets in parallel, maintaining deterministic ordering.
    /// Returns sorted list with deterministic ranking.
    public func scoreTargets(
        _ targets: [EnumeratedTarget],
        policy: ScoringPolicy,
        concurrencyLevel: Int
    ) async throws -> [EnumeratedTarget] {

        // Partition targets for parallel processing
        let targetBatches = partitionTargets(targets, batchSize: max(1, targets.count / concurrencyLevel))

        // Process each batch in parallel
        var scoredBatches: [[EnumeratedTarget]] = []

        for batch in targetBatches {
            async let scoredBatch = processBatch(batch, policy: policy)
            let result = try await scoredBatch
            scoredBatches.append(result)
        }

        // Deterministically merge results
        let mergedTargets = DeterministicMerge.mergeEnumeratedTargets(scoredBatches)

        // Apply deterministic rank assignment
        let rankedTargets = assignRanks(mergedTargets)

        return rankedTargets
    }

    /// Partition targets into batches for parallel processing.
    private func partitionTargets(
        _ targets: [EnumeratedTarget],
        batchSize: Int
    ) -> [[EnumeratedTarget]] {

        var batches: [[EnumeratedTarget]] = []
        var currentBatch: [EnumeratedTarget] = []

        for target in targets {
            currentBatch.append(target)

            if currentBatch.count >= batchSize {
                batches.append(currentBatch)
                currentBatch = []
            }
        }

        // Add any remaining targets
        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }

        return batches
    }

    /// Process a batch of targets with scoring.
    private func processBatch(
        _ targets: [EnumeratedTarget],
        policy: ScoringPolicy
    ) async throws -> [EnumeratedTarget] {

        var scoredTargets: [EnumeratedTarget] = []

        for target in targets {
            // Apply scoring
            let score = scoringFunction(target.metrics, policy)

            // Update target with new score
            let scoredTarget = EnumeratedTarget(
                targetId: target.targetId,
                targetType: target.targetType,
                scope: target.scope,
                description: target.description,
                metrics: target.metrics,
                rank: score
            )
            scoredTargets.append(scoredTarget)
        }

        return scoredTargets
    }

    /// Assign sequential ranks after merging and sorting.
    private func assignRanks(_ targets: [EnumeratedTarget]) -> [EnumeratedTarget] {
        var rankedTargets: [EnumeratedTarget] = []

        for (index, target) in targets.enumerated() {
            let updatedTarget = EnumeratedTarget(
                targetId: target.targetId,
                targetType: target.targetType,
                scope: target.scope,
                description: target.description,
                metrics: target.metrics,
                rank: index + 1
            )
            rankedTargets.append(updatedTarget)
        }

        return rankedTargets
    }
}
