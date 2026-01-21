//
//  VaultIndexStore.swift
//  StorageCore
//
//  Database-backed index for vault metadata.
//

import DatabaseCore
import Foundation

/// Database index for vault metadata and access logs.
public actor VaultIndexStore {
    private let db: DatabaseActor

    public init(database: DatabaseActor) async throws {
        self.db = database
        try await MigrationRegistry.applyVaultMigrations(using: db)
    }

    /// Insert or update an artifact record.
    public func upsertArtifact(_ artifact: VaultArtifactRef) async throws {
        try await db.execute(
            """
            INSERT INTO vault_artifacts
            (sha256_hex, byte_len, mime, kind, created_at, key_id, object_relpath, previous_receipt_hash)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(sha256_hex) DO UPDATE SET
                byte_len = excluded.byte_len,
                mime = excluded.mime,
                kind = excluded.kind,
                key_id = excluded.key_id,
                object_relpath = excluded.object_relpath,
                previous_receipt_hash = excluded.previous_receipt_hash
            """,
            parameters: [
                .text(artifact.sha256Hex),
                .int(artifact.byteLen),
                .text(artifact.mime),
                .text(artifact.kind.rawValue),
                .double(artifact.createdAt.timeIntervalSince1970),
                .text(artifact.keyId),
                .text(artifact.objectRelpath),
                artifact.previousReceiptHash.map { .text($0) } ?? .null
            ]
        )
    }

    /// Fetch a stored artifact record.
    public func fetchArtifact(hash: String) async throws -> VaultArtifactRef? {
        let rows = try await db.query(
            """
            SELECT sha256_hex, byte_len, mime, kind, created_at, key_id, object_relpath, previous_receipt_hash
            FROM vault_artifacts
            WHERE sha256_hex = ?
            LIMIT 1
            """,
            parameters: [.text(hash)]
        )
        guard let row = rows.first,
            let sha256Hex = row.string(for: "sha256_hex"),
            let byteLen = row.int(for: "byte_len"),
            let mime = row.string(for: "mime"),
            let kindRaw = row.string(for: "kind"),
            let createdAtDouble = row.double(for: "created_at"),
            let keyId = row.string(for: "key_id"),
            let objectRelpath = row.string(for: "object_relpath"),
            let kind = VaultArtifactKind(rawValue: kindRaw)
        else {
            return nil
        }

        return VaultArtifactRef(
            sha256Hex: sha256Hex,
            byteLen: byteLen,
            mime: mime,
            kind: kind,
            keyId: keyId,
            objectRelpath: objectRelpath,
            previousReceiptHash: row.string(for: "previous_receipt_hash"),
            createdAt: Date(timeIntervalSince1970: createdAtDouble)
        )
    }

    /// Record a provenance edge between artifacts.
    public func recordEdge(
        parentHash: String,
        childHash: String,
        relation: String,
        runId: String?,
        stepId: String?
    ) async throws {
        try await db.execute(
            """
            INSERT OR IGNORE INTO vault_edges
            (parent_sha256_hex, child_sha256_hex, relation, run_id, step_id)
            VALUES (?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(parentHash),
                .text(childHash),
                .text(relation),
                runId.map { .text($0) } ?? .null,
                stepId.map { .text($0) } ?? .null
            ]
        )
    }

    /// Record an access log entry.
    public func recordAccess(
        at: Date,
        actorId: String?,
        action: String,
        sha256Hex: String,
        decision: VaultDecision,
        reason: String?
    ) async throws {
        try await db.execute(
            """
            INSERT INTO vault_access_log
            (at_utc, actor_id, action, sha256_hex, decision, reason)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .double(at.timeIntervalSince1970),
                actorId.map { .text($0) } ?? .null,
                .text(action),
                .text(sha256Hex),
                .text(decision.rawValue),
                reason.map { .text($0) } ?? .null
            ]
        )
    }

    /// List artifacts for retention review.
    public func listArtifacts(olderThan: Date) async throws -> [VaultArtifactRef] {
        let rows = try await db.query(
            """
            SELECT sha256_hex, byte_len, mime, kind, created_at, key_id, object_relpath, previous_receipt_hash
            FROM vault_artifacts
            WHERE created_at < ?
            """,
            parameters: [.double(olderThan.timeIntervalSince1970)]
        )
        return rows.compactMap { row in
            guard let sha256Hex = row.string(for: "sha256_hex"),
                let byteLen = row.int(for: "byte_len"),
                let mime = row.string(for: "mime"),
                let kindRaw = row.string(for: "kind"),
                let createdAtDouble = row.double(for: "created_at"),
                let keyId = row.string(for: "key_id"),
                let objectRelpath = row.string(for: "object_relpath"),
                let kind = VaultArtifactKind(rawValue: kindRaw)
            else {
                return nil
            }

            return VaultArtifactRef(
                sha256Hex: sha256Hex,
                byteLen: byteLen,
                mime: mime,
                kind: kind,
                keyId: keyId,
                objectRelpath: objectRelpath,
                previousReceiptHash: row.string(for: "previous_receipt_hash"),
                createdAt: Date(timeIntervalSince1970: createdAtDouble)
            )
        }
    }

    /// List all artifact records in the vault index.
    public func listAllArtifacts() async throws -> [VaultArtifactRef] {
        let rows = try await db.query(
            """
            SELECT sha256_hex, byte_len, mime, kind, created_at, key_id, object_relpath, previous_receipt_hash
            FROM vault_artifacts
            """
        )
        return rows.compactMap { row in
            guard let sha256Hex = row.string(for: "sha256_hex"),
                let byteLen = row.int(for: "byte_len"),
                let mime = row.string(for: "mime"),
                let kindRaw = row.string(for: "kind"),
                let createdAtDouble = row.double(for: "created_at"),
                let keyId = row.string(for: "key_id"),
                let objectRelpath = row.string(for: "object_relpath"),
                let kind = VaultArtifactKind(rawValue: kindRaw)
            else {
                return nil
            }

            return VaultArtifactRef(
                sha256Hex: sha256Hex,
                byteLen: byteLen,
                mime: mime,
                kind: kind,
                keyId: keyId,
                objectRelpath: objectRelpath,
                previousReceiptHash: row.string(for: "previous_receipt_hash"),
                createdAt: Date(timeIntervalSince1970: createdAtDouble)
            )
        }
    }

    /// Remove an artifact record.
    public func deleteArtifact(hash: String) async throws {
        try await db.execute(
            "DELETE FROM vault_artifacts WHERE sha256_hex = ?",
            parameters: [.text(hash)]
        )
    }

    /// Record a retention event in the master retention ledger.
    public func recordRetentionEvent(report: VaultGCReport) async throws {
        let summary: [String: Any] = [
            "vault_gc": [
                "scanned": report.scanned,
                "deleted": report.deleted,
                "bytes_freed": report.bytesFreed,
                "dry_run": report.dryRun
            ]
        ]
        let hashes = try JSONEncoder().encode(report.deletedHashes)
        let summaryData = try JSONSerialization.data(withJSONObject: summary, options: [])
        let retentionId = UUID().uuidString
        let startedAt = Date().timeIntervalSince1970
        let completedAt = startedAt
        let metadata: [String: Any] = [
            "policy_version": report.policyVersion,
            "deleted_hashes": String(data: hashes, encoding: .utf8) ?? "[]",
            "retention_summary": String(data: summaryData, encoding: .utf8) ?? "{}",
            "created_by": "storagecore-vault"
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [])

        try await db.execute(
            """
            INSERT INTO retention_events (
                retention_id, policy_version_hash, started_at, completed_at,
                artifacts_deleted, payload_bytes_freed, deletion_reason, metadata
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(retentionId),
                .text(report.policyHash),
                .double(startedAt),
                .double(completedAt),
                .int(report.deleted),
                .int(Int(report.bytesFreed)),
                .text("vault_gc"),
                .blob(metadataData)
            ]
        )
    }
}
