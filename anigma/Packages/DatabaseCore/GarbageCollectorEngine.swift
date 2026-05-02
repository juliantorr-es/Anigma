//
//  GarbageCollectorEngine.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation
import FoundationContracts
import EvidenceContracts
import GovernanceContracts

/// Garbage collector engine for content-addressed artifact storage.
public actor GarbageCollectorEngine {
    private let db: any DatabaseExecutor
    private let policyManager: RetentionPolicyManager

    public init(database: any DatabaseExecutor, policyManager: RetentionPolicyManager) {
        self.db = database
        self.policyManager = policyManager
    }

    /// Run garbage collection with full eligibility proof.
    public func runGarbageCollection(
        dryRun: Bool = true,
        policy: RetentionPolicy? = nil,
        maxItemsToDelete: Int = 1000
    ) async throws -> GarbageCollectionResult {
        let startTime = Date()
        let currentPolicy = policy ?? RetentionPolicy.production

        // Load current policy manager state
        let activePolicy = await policyManager.getCurrentPolicy() ?? currentPolicy

        // Stage 1: Identify eligible artifacts
        let eligibilityProofs = try await identifyEligibleArtifacts(
            policy: activePolicy,
            maxItems: maxItemsToDelete
        )

        // Stage 2: Verify reference integrity
        let verifiedDeletions = try await verifyNoOrphanReferences(
            for: eligibilityProofs
        )

        // Stage 3: Perform deletions (if not dry-run)
        var deletionResult = DeletionResult()
        if !dryRun {
            deletionResult = try await performDeletions(
                verifiedDeletions: verifiedDeletions,
                policy: activePolicy
            )
        } else {
            // In dry-run mode, just estimate
            deletionResult = DeletionResult(
                artifactsDeleted: verifiedDeletions.count,
                bytesFreed: Int64(verifiedDeletions.reduce(0) { $0 + $1.artifact.payloadSize }),
                deletedHashes: verifiedDeletions.map { $0.artifact.contentHash }
            )
        }

        // Stage 4: Record retention event and housekeeping
        var housekeepingResult: HousekeepingResult?
        if !dryRun {
            try await recordRetentionEvent(
                policy: activePolicy,
                result: deletionResult
            )

            // Run post-deletion housekeeping (WAL, VACUUM, ANALYZE)
            housekeepingResult = try await performPostDeletionHousekeeping()
        }

        return GarbageCollectionResult(
            startTime: startTime,
            endTime: Date(),
            dryRun: dryRun,
            policyHash: activePolicy.policyHash,
            eligibleCount: eligibilityProofs.count,
            verifiedCount: verifiedDeletions.count,
            deletionResult: deletionResult,
            housekeepingResult: housekeepingResult
        )
    }

    /// Identify artifacts eligible for deletion based on policy.
    private func identifyEligibleArtifacts(
        policy: RetentionPolicy,
        maxItems: Int
    ) async throws -> [EligibilityProof] {
        let ledger = try await MasterLedgerStore(database: db)

        // Query all content-addressed artifacts
        let rows = try await db.query(
            """
            SELECT content_hash, payload_size, reference_count, first_seen_at
            FROM content_addressed_artifacts
            ORDER BY first_seen_at ASC
            LIMIT ?
            """,
            parameters: [.int(maxItems)]
        )

        var proofs: [EligibilityProof] = []
        let now = Date()

        for row in rows {
            guard let hash = row.string(for: "content_hash"),
                  let firstSeenDouble = row.double(for: "first_seen_at") else {
                continue
            }

            let artifact = ContentAddressedArtifact(
                contentHash: hash,
                hashAlgorithm: "sha256:1",
                payload: Data(),
                payloadSize: row.int(for: "payload_size") ?? 0,
                isCompressed: false,
                firstSeenAt: Date(timeIntervalSince1970: firstSeenDouble),
                referenceCount: row.int(for: "reference_count") ?? 0
            )

            let contentAge = now.timeIntervalSince(artifact.firstSeenAt)

            // Check eligibility
            let eligibility = policy.shouldRetain(
                contentHash: hash,
                policyClass: "artifacts",
                artifactType: "unknown",
                contentAge: contentAge,
                referenceCount: artifact.referenceCount
            )

            if eligibility.isEligibleForDeletion {
                // Verify not referenced in master ledger
                let inMasterLedger = try await ledger.eventReferencesContent(contentHash: hash)

                let proof = EligibilityProof(
                    artifact: artifact,
                    eligibility: eligibility,
                    referencedInMasterLedger: inMasterLedger,
                    contentAge: contentAge
                )

                proofs.append(proof)
            }
        }

        return proofs
    }

    /// Verify that deletions won't create orphan references.
    private func verifyNoOrphanReferences(
        for proofs: [EligibilityProof]
    ) async throws -> [EligibilityProof] {
        var verified: [EligibilityProof] = []

        for proof in proofs {
            // Double-check not referenced in master ledger
            if !proof.referencedInMasterLedger {
                // Safe to delete - no master ledger references
                verified.append(proof)
            }
        }

        return verified
    }

    /// Perform actual deletions and record tombstones.
    private func performDeletions(
        verifiedDeletions: [EligibilityProof],
        policy: RetentionPolicy
    ) async throws -> DeletionResult {

        var deletedHashes: [String] = []
        var bytesFreed: Int64 = 0

        for proof in verifiedDeletions {
            // Delete artifact from content-addressed store
            _ = try await db.executeAsync(
                """
                DELETE FROM content_addressed_artifacts
                WHERE content_hash = ?
                """,
                parameters: [.text(proof.artifact.contentHash)]
            )

            deletedHashes.append(proof.artifact.contentHash)
            bytesFreed += Int64(proof.artifact.payloadSize)

            // Tombstone in artifact references (mark as deleted but keep hash)
            _ = try await db.executeAsync(
                """
                UPDATE artifact_references
                SET deleted_at = ?
                WHERE content_hash = ?
                """,
                parameters: [
                    .double(Date().timeIntervalSince1970),
                    .text(proof.artifact.contentHash)
                ]
            )
        }

        return DeletionResult(
            artifactsDeleted: verifiedDeletions.count,
            bytesFreed: bytesFreed,
            deletedHashes: deletedHashes
        )
    }

    /// Record a retention event in the master ledger.
    private func recordRetentionEvent(
        policy: RetentionPolicy,
        result: DeletionResult
    ) async throws {
        // Store retention event in master ledger
        let eventId = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let deletedHashesData = try JSONSerialization.data(withJSONObject: result.deletedHashes, options: .sortedKeys)
        let deletedHashesJson = String(data: deletedHashesData, encoding: .utf8) ?? "[]"

        try await db.executeAsync("""
            INSERT INTO retention_events (
                event_id, policy_hash, policy_version, event_type,
                started_at, completed_at, artifacts_deleted, artifacts_freed_bytes,
                sessions_deleted, affected_artifact_hashes, retention_summary,
                created_by
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            .text(eventId),
            .text(policy.policyHash),
            .text("1.0"),
            .text("gc_run"),
            .double(now),
            .double(now),
            .int(result.artifactsDeleted),
            .int(Int(result.bytesFreed)),
            .int(0),
            .text(deletedHashesJson),
            .text("{}"),
            .text("harmonia-gc")
        ])
    }

    /// Perform WAL checkpoint after deletions.
    private func performPostDeletionHousekeeping() async throws -> HousekeepingResult? {
        // Initialize WAL manager
        let walConfig = WALConfig.default
        let walManager = WALManager(database: db, config: walConfig)

        // Check if WAL needs checkpointing
        let checkpointResult = try await walManager.checkpointIfNeeded()

        // Initialize database maintenance
        let maintenanceConfig = MaintenanceConfig.default
        let maintenance = DatabaseMaintenance(database: db, config: maintenanceConfig)

        // Run maintenance cycle if needed
        let maintenanceResult = try await maintenance.runFullMaintenance()

        return HousekeepingResult(
            checkpointResult: checkpointResult,
            maintenanceResult: maintenanceResult
        )
    }
}

/// Eligibility proof for artifact deletion.
public struct EligibilityProof: Sendable {
    public let artifact: ContentAddressedArtifact
    public let eligibility: RetentionEligibility
    public let referencedInMasterLedger: Bool
    public let contentAge: TimeInterval
}

/// Result of garbage collection.
public struct GarbageCollectionResult: Encodable, Sendable {
    public let startTime: Date
    public let endTime: Date
    public let dryRun: Bool
    public let policyHash: String
    public let eligibleCount: Int
    public let verifiedCount: Int
    public let deletionResult: DeletionResult
    public let housekeepingResult: HousekeepingResult?

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

/// Result of deletion operation.
public struct DeletionResult: Encodable, Sendable {
    public let artifactsDeleted: Int
    public let bytesFreed: Int64
    public let deletedHashes: [String]

    public init(
        artifactsDeleted: Int = 0,
        bytesFreed: Int64 = 0,
        deletedHashes: [String] = []
    ) {
        self.artifactsDeleted = artifactsDeleted
        self.bytesFreed = bytesFreed
        self.deletedHashes = deletedHashes
    }
}

/// Result of database housekeeping operations.
public struct HousekeepingResult: Encodable, Sendable {
    public let checkpointResult: WALCheckpointResult
    public let maintenanceResult: FullMaintenanceResult

    public init(
        checkpointResult: WALCheckpointResult,
        maintenanceResult: FullMaintenanceResult
    ) {
        self.checkpointResult = checkpointResult
        self.maintenanceResult = maintenanceResult
    }
}
