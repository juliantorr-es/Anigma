//
//  DeterministicMerge.swift
//  HarmoniaModule
//
//  Deterministic merge utility for concurrent results in Phase 9.2.
//  Ensures output is identical regardless of execution order.
//

@preconcurrency import Foundation

/// Utility for deterministic merging of concurrent results.
/// Ensures final result is identical regardless of execution order.
public struct DeterministicMerge {

    /// Merge multiple result sets into a single canonical order.
    /// The result is identical regardless of the order of execution.
    /// - Parameter results: Array of result sets from concurrent tasks
    /// - Returns: Merged and sorted results in canonical order
    public static func merge<T: Comparable>(_ results: [[T]]) -> [T] {
        let allItems = results.flatMap { $0 }
        return allItems.sorted()
    }

    /// Merge enumerated targets with deterministic ordering.
    /// Specialized for EnumeratedTarget to preserve determinism contract.
    public static func mergeEnumeratedTargets(_ results: [[EnumeratedTarget]]) -> [EnumeratedTarget] {
        // Flatten all results
        let allTargets = results.flatMap { $0 }

        // Remove duplicates based on targetId
        var uniqueTargets: [String: EnumeratedTarget] = [:]
        for target in allTargets {
            uniqueTargets[target.targetId] = target
        }

        // Convert to array and sort by deterministic key
        let uniqueTargetArray = Array(uniqueTargets.values)

        // Sort by score (descending) then by targetId (ascending) for determinism
        let sortedTargets = uniqueTargetArray.sorted { a, b in
            if a.rank != b.rank {
                return a.rank > b.rank  // Higher scores first
            }
            return a.targetId < b.targetId  // Alphabetical tie-breaker
        }

        return sortedTargets
    }
}
