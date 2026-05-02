import HarmoniaWorkflowContracts

import ContractsCore
import ArtifactStoreModule

//
//  GarbageCollector.swift
//  HarmoniaModule
//
//  Database housekeeping with retention policy enforcement.
//  Bounded storage with auditable deletion trail.
//

@preconcurrency import Foundation
import Foundation
import AnigmaPrimitives
import AnigmaCore
import ContractsCore
import DatabaseCore
import os.log

public typealias GCRetentionPolicy = ContractsCore.RetentionPolicy

private let log = Logger(subsystem: "com.anigma.harmonia", category: "housekeeping")

/// Garbage collector for evidence and artifact cleanup.
public actor GarbageCollector {
    private let masterDb: any DatabaseCore.DatabaseExecutor
    private let artifactStore: ArtifactStore
    private let sessionManager: SessionManager
    private let artifactAuthority: (any ArtifactAuthority)?

    public init(
        masterDb: any DatabaseCore.DatabaseExecutor,
        artifactStore: ArtifactStore,
        sessionManager: SessionManager
    ) {
        self.masterDb = masterDb
        self.artifactStore = artifactStore
        self.sessionManager = sessionManager
        self.artifactAuthority = nil
    }
    
    public init(
        artifactAuthority: any ArtifactAuthority,
        masterDb: (any DatabaseCore.DatabaseExecutor)? = nil,
        sessionManager: SessionManager
    ) {
        self.artifactAuthority = artifactAuthority
        self.masterDb = masterDb ?? DummyDatabaseExecutor()
        self.artifactStore = ArtifactStore(artifactAuthority: artifactAuthority, db: self.masterDb)
        self.sessionManager = sessionManager
    }

    /// Run garbage collection with specified policy.
    public func runGC(
        policy: GCRetentionPolicy,
        dryRun: Bool = true
    ) async throws -> GCReport {
        let startTime = Date()
        let policyHash = policy.policyHash

        log.info("🧹 Starting garbage collection (dry-run: \(dryRun)")
        log.info("📋 Policy hash: \(policyHash, privacy: .public)")

        // Check policy hash consistency if required
        if policy.gc.requirePolicyHashMatch {
            try await validatePolicyHash(policyHash)
        }

        var report = GCReport(
            startTime: startTime,
            policyHash: policyHash,
            dryRun: dryRun
        )

        // 1. Clean up session databases
        let sessionReport = try await cleanupSessionDatabases(
            policy: policy,
            dryRun: dryRun
        )
        report.sessionCleanup = sessionReport

        // 2. Clean up expired artifacts
        let artifactReport = try await cleanupArtifacts(
            policy: policy,
            dryRun: dryRun
        )
        report.artifactCleanup = artifactReport

        // 3. Run database maintenance
        if !dryRun {
            try await performDatabaseMaintenance(policy: policy)
        }

        let endTime = Date()
        report.endTime = endTime
        report.duration = endTime.timeIntervalSince(report.startTime)

        // Write retention event if not dry run
        if !dryRun {
            try await writeRetentionEvent(report: report, policyHash: policyHash)
        }

        return report
    }

    /// Clean up expired session databases.
    private func cleanupSessionDatabases(
        policy: GCRetentionPolicy,
        dryRun: Bool
    ) async throws -> SessionCleanupReport {
        let cutoffDate = Date().addingTimeInterval(
            -TimeInterval(policy.sessionDb.ttlDays * 24 * 60 * 60)
        )

        // Get expired sessions
        let expiredSessions = try await masterDb.query("""
            SELECT session_id, agent_id, start_time, end_time
            FROM session_lifecycle
            WHERE start_time < ?
              AND status IN ('completed', 'terminated')
            ORDER BY start_time ASC
        """, parameters: [.text(String(Int(cutoffDate.timeIntervalSince1970)))])

        var sessionsToDelete: [String] = []
        var totalSizeFreed: Int64 = 0

        for sessionRow in expiredSessions {
            guard let sessionId = sessionRow.string(for: "session_id") else {
                fatalError("Failed to unwrap sessionId")
            }
            guard let sessionDbPath = await sessionManager.getSessionDbPath(sessionId) else {
                sessionsToDelete.append(sessionId)
                continue
            }

            // Check session DB size
            if let attributes = try? FileManager.default.attributesOfItem(atPath: sessionDbPath),
               let sizeValue = attributes[FileAttributeKey.size] as? NSNumber {
                totalSizeFreed += sizeValue.int64Value
            }

            sessionsToDelete.append(sessionId)
        }

        // Delete session DBs if not dry run
        if !dryRun && !sessionsToDelete.isEmpty {
            for sessionId in sessionsToDelete {
                try await sessionManager.deleteSession(sessionId: sessionId)
            }
        }

        return SessionCleanupReport(
            sessionsScanned: expiredSessions.count,
            sessionsDeleted: dryRun ? 0 : sessionsToDelete.count,
            bytesFreed: totalSizeFreed,
            cutoffDate: cutoffDate
        )
    }

    /// Clean up expired artifacts.
    private func cleanupArtifacts(
        policy: GCRetentionPolicy,
        dryRun: Bool
    ) async throws -> ArtifactCleanupReport {
        var artifactsDeleted = 0
        var bytesFreed: Int64 = 0
        var deletedHashes: [String] = []

        // Get eligible artifacts in batches
        let batchSize = min(policy.gc.maxDeletePerRun, 1000)
        var offset = 0

        while true {
            let eligibleArtifacts = try await artifactStore.getEligibleArtifacts(
                olderThanDays: policy.artifacts.defaultTtlDays,
                limit: batchSize
            )

            guard !eligibleArtifacts.isEmpty else { break }

            for artifact in eligibleArtifacts {
                // Check artifact-specific retention rules
                let ttlDays = policy.artifacts.ttlForArtifact(
                    artifactType: "unknown",
                    sizeBytes: artifact.byteLength
                )

                let cutoffDate = Date().addingTimeInterval(
                    -TimeInterval(ttlDays * 24 * 60 * 60)
                )

                // Skip if not old enough
                if artifact.storedAt > cutoffDate {
                    continue
                }

                // Check total storage limit
                let currentStats = try await artifactStore.getStorageStats()
                if currentStats.totalBytes >= Int64(policy.artifacts.maxTotalStorageGb * 1024 * 1024 * 1024) {
                    log.warning("⚠️  Storage limit reached, skipping artifact deletion")
                    break
                }

                if !dryRun {
                    let freedBytes = try await artifactStore.deleteArtifact(hash: artifact.hash)
                    bytesFreed += freedBytes
                    artifactsDeleted += 1
                    deletedHashes.append(artifact.hash)
                } else {
                    artifactsDeleted += 1
                    bytesFreed += artifact.byteLength
                    deletedHashes.append(artifact.hash)
                }
            }

            offset += batchSize
            if artifactsDeleted >= policy.gc.maxDeletePerRun {
                print("⚠️  Reached max delete limit for this run")
                break
            }
        }

        return ArtifactCleanupReport(
            artifactsScanned: artifactsDeleted,
            artifactsDeleted: dryRun ? 0 : artifactsDeleted,
            bytesFreed: bytesFreed,
            deletedHashes: deletedHashes
        )
    }

    /// Perform database maintenance (VACUUM, checkpoint).
    private func performDatabaseMaintenance(policy: GCRetentionPolicy) async throws {
        print("🔧 Performing database maintenance...")

        // Get current storage stats
        let stats = try await artifactStore.getStorageStats()
        let reclaimableBytes = stats.totalBytes - stats.compressedBytes

        // Run VACUUM if enough space can be reclaimed
        if reclaimableBytes >= Int64(policy.gc.vacuumThresholdMb * 1024 * 1024) {
            print("🗑️  Running VACUUM on artifact store...")
            _ = try await masterDb.executeAsync("VACUUM artifacts", parameters: [])

            // Incremental VACUUM on master if needed
            if stats.totalBytes >= Int64(policy.gc.vacuumThresholdMb * 2 * 1024 * 1024) {
                print("🗑️  Running incremental VACUUM on master ledger...")
                _ = try await masterDb.executeAsync("VACUUM evidence_chain", parameters: [])
            }
        }

        // WAL checkpoint if large enough
        let walSize = try await getWalSize()
        if walSize >= Int64(policy.gc.checkpointWalMb * 1024 * 1024) {
            print("📝 Running WAL checkpoint...")
            _ = try await masterDb.executeAsync("PRAGMA wal_checkpoint(TRUNCATE)", parameters: [])
        }
    }

    /// Validate policy hash against last stored.
    private func validatePolicyHash(_ policyHash: String) async throws {
        let rows = try await masterDb.query("""
            SELECT policy_hash FROM retention_events
            ORDER BY completed_at DESC
            LIMIT 1
        """)

        if let lastHash = rows.first?.string(for: "policy_hash"), lastHash != policyHash {
            print("⚠️  Policy hash changed from last run")
            print("   Previous: \(lastHash)")
            print("   Current:  \(policyHash)")
        }
    }

    /// Write retention event to master ledger.
    private func writeRetentionEvent(report: GCReport, policyHash: String) async throws {
        let eventId = UUID().uuidString
        let startTime = String(Int(report.startTime.timeIntervalSince1970))
        let endTime = String(Int(report.endTime!.timeIntervalSince1970))

        let summaryObject: [String: Any] = [
            "sessionCleanup": [
                "sessionsDeleted": report.sessionCleanup?.sessionsDeleted ?? 0,
                "bytesFreed": report.sessionCleanup?.bytesFreed ?? 0
            ],
            "artifactCleanup": [
                "artifactsDeleted": report.artifactCleanup?.artifactsDeleted ?? 0,
                "bytesFreed": report.artifactCleanup?.bytesFreed ?? 0
            ]
        ]

        let summaryData = try JSONSerialization.data(withJSONObject: summaryObject, options: .sortedKeys)
        let summaryJson = String(data: summaryData, encoding: .utf8) ?? "{}"

        let deletedHashes = report.artifactCleanup?.deletedHashes ?? []
        let deletedHashesData = try JSONSerialization.data(withJSONObject: deletedHashes, options: .sortedKeys)
        let deletedHashesJson = String(data: deletedHashesData, encoding: .utf8) ?? "[]"

        try await masterDb.executeAsync("""
            INSERT INTO retention_events (
                event_id, policy_hash, policy_version, event_type,
                started_at, completed_at, artifacts_deleted, artifacts_freed_bytes,
                sessions_deleted, affected_artifact_hashes, retention_summary,
                created_by
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            .text(eventId),
            .text(policyHash),
            .text("1.0"),
            .text("gc_run"),
            .text(startTime),
            .text(endTime),
            .int(Int(report.artifactCleanup?.artifactsDeleted ?? 0)),
            .int(Int(report.artifactCleanup?.bytesFreed ?? 0)),
            .int(report.sessionCleanup?.sessionsDeleted ?? 0),
            .text(deletedHashesJson),
            .text(summaryJson),
            .text("harmonia-gc")
        ])
    }

    /// Get current WAL file size.
    private func getWalSize() async throws -> Int64 {
        _ = try await masterDb.query("PRAGMA wal_checkpoint(TRUNCATE)", parameters: [])
        // This is a simplified approach - in production would check actual WAL file size
        return 0
    }
}

// Report types are defined in GCReport.swift

private actor DummyDatabaseExecutor: DatabaseCore.DatabaseExecutor {
    @discardableResult
    func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int { 0 }

    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow] { [] }

    @discardableResult
    func executeAsync(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int { 0 }

    func transaction(_ block: @Sendable () async throws -> Void) async throws {
        try await block()
    }

    func open() throws {}
    func close() {}

    nonisolated var path: String { "memory://dummy-gc" }
}
