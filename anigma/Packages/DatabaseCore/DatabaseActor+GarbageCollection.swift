//
//  DatabaseActor+GarbageCollection.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation
import ContractsCore

/// Extension on DatabaseActor for garbage collection operations.
public extension DatabaseActor {

    /// Create or get a garbage collector engine.
    func makeGarbageCollectorEngine(policyManager: RetentionPolicyManager) -> GarbageCollectorEngine {
        return GarbageCollectorEngine(database: self, policyManager: policyManager)
    }

    /// Run garbage collection with dry-run support.
    func runGarbageCollection(
        dryRun: Bool = true,
        maxItems: Int = 1000
    ) async throws -> GarbageCollectionResult {
        let policyManager = try await RetentionPolicyManager(database: self)
        let gc = GarbageCollectorEngine(database: self, policyManager: policyManager)

        let result = try await gc.runGarbageCollection(
            dryRun: dryRun,
            maxItemsToDelete: maxItems
        )

        // Verify invariants after cleanup
        let invariantChecker = GovernanceInvariantChecker(database: self)
        let invariantResult = try await invariantChecker.verifyAllInvariants()

        // Store invariants with GC results
        if !invariantResult.passed || !dryRun {
            try await recordInvariantCheck(invariantResult: invariantResult)
        }

        return result
    }

    /// Record invariant check results for audit trail.
    private func recordInvariantCheck(invariantResult: InvariantCheckResult) async throws {
        let resultData = try JSONEncoder().encode(invariantResult)
        let resultJson = String(data: resultData, encoding: .utf8) ?? "{}"

        try performExecute("""
            INSERT INTO invariant_checks (
                check_id, timestamp, passed, details_json,
                violations_json
            ) VALUES (?, ?, ?, ?, ?)
        """, parameters: [
            .text(UUID().uuidString),
            .double(invariantResult.timestamp.timeIntervalSince1970),
            .int(invariantResult.passed ? 1 : 0),
            .text(resultJson),
            .text((try? String(data: JSONEncoder().encode(invariantResult.violations), encoding: .utf8)) ?? "[]")
        ])
    }

    /// Verify that no artifacts are orphaned (referenced in artifact_references but not in content_addressed_artifacts).
    func verifyArtifactIntegrity() async throws -> (orphanedReferences: Int, missingArtifacts: Int) {
        // Find references to non-existent artifacts
        let orphanedRows = try await query(
            """
            SELECT COUNT(*) as count FROM artifact_references
            WHERE content_hash NOT IN (
                SELECT content_hash FROM content_addressed_artifacts
            )
            AND deleted_at IS NULL
            """
        )

        let orphanedCount = orphanedRows.first?.int(for: "count") ?? 0

        // Find artifacts with zero references but still in content table
        let unreferencedRows = try await query(
            """
            SELECT COUNT(*) as count FROM content_addressed_artifacts
            WHERE reference_count = 0
            """
        )

        let unreferencedCount = unreferencedRows.first?.int(for: "count") ?? 0

        return (orphanedCount, unreferencedCount)
    }
}
