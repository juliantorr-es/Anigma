//
//  MigrationRegistry.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Central place to apply schema migrations for DatabaseCore consumers.
public enum MigrationRegistry {
    /// Applies all known migrations. Safe to call multiple times.
    public static func applyMigrations(using db: DatabaseActor) async throws {
        try await db.transaction {
            try await createContractJobsIfNeeded(db)
            try await createContractReceipts(db)
            try await createArtifacts(db)
            try await applyVaultMigrations(using: db)
            try await ContentAddressedMigration.migrate(db)
            try await MasterLedgerMigration.migrate(db)
            try await SessionDatabaseMigration.migrate(db)
        }
    }

    /// Applies vault-related schema migrations. Safe to call multiple times.
    public static func applyVaultMigrations(using db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS vault_artifacts (
                sha256_hex TEXT PRIMARY KEY,
                byte_len INTEGER NOT NULL,
                mime TEXT NOT NULL,
                kind TEXT NOT NULL,
                created_at REAL NOT NULL,
                key_id TEXT NOT NULL,
                object_relpath TEXT NOT NULL,
                previous_receipt_hash TEXT
            );
            """
        )
        // Add previous_receipt_hash if upgrading from older schema.
        try await addColumnIfMissing(
            db: db, table: "vault_artifacts", column: "previous_receipt_hash", type: "TEXT")
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS vault_edges (
                parent_sha256_hex TEXT NOT NULL,
                child_sha256_hex TEXT NOT NULL,
                relation TEXT NOT NULL,
                run_id TEXT,
                step_id TEXT,
                PRIMARY KEY (parent_sha256_hex, child_sha256_hex, relation)
            );
            """
        )
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS vault_access_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                at_utc REAL NOT NULL,
                actor_id TEXT,
                action TEXT NOT NULL,
                sha256_hex TEXT NOT NULL,
                decision TEXT NOT NULL,
                reason TEXT
            );
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_vault_artifacts_kind
            ON vault_artifacts(kind);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_vault_edges_parent
            ON vault_edges(parent_sha256_hex);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_vault_access_log_hash
            ON vault_access_log(sha256_hex);
            """
        )
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS retention_events (
                retention_id TEXT PRIMARY KEY,
                policy_version_hash TEXT NOT NULL,
                started_at REAL NOT NULL,
                completed_at REAL NOT NULL,
                artifacts_deleted INTEGER,
                payload_bytes_freed INTEGER,
                deletion_reason TEXT,
                metadata BLOB
            );
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_retention_events_timestamp
            ON retention_events(started_at);
            """
        )
    }

    private static func createContractJobsIfNeeded(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS contract_jobs (
                id TEXT PRIMARY KEY,
                contract_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                queue_key TEXT NOT NULL,
                payload TEXT NOT NULL,
                status TEXT NOT NULL,
                attempts INTEGER NOT NULL,
                error TEXT,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            """
        )
        // Add queue_key if upgrading from older schema.
        try await addColumnIfMissing(
            db: db, table: "contract_jobs", column: "queue_key", type: "TEXT NOT NULL DEFAULT ''")
        try await db.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_contract_jobs_queue_key
            ON contract_jobs(queue_key);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_contract_jobs_session_status
            ON contract_jobs(session_id, status);
            """
        )
    }

    private static func createContractReceipts(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS contract_receipts (
                run_id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                contract_id TEXT NOT NULL,
                status TEXT NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL NOT NULL,
                provenance_hash TEXT NOT NULL,
                receipt_json BLOB NOT NULL,
                input_key TEXT NOT NULL
            );
            """
        )
        try await db.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_contract_receipts_unique
            ON contract_receipts(session_id, contract_id, input_key, provenance_hash);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_contract_receipts_lookup
            ON contract_receipts(session_id, contract_id, input_key);
            """
        )
    }

    private static func createArtifacts(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS artifacts (
                artifact_id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                contract_id TEXT NOT NULL,
                schema_version INTEGER NOT NULL,
                artifact_key TEXT NOT NULL,
                payload_json BLOB NOT NULL,
                evidence_json BLOB NOT NULL,
                metrics_json BLOB NOT NULL,
                envelope_json BLOB NOT NULL,
                receipt_json BLOB NOT NULL,
                created_at REAL NOT NULL
            );
            """
        )
        try await db.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_artifacts_key
            ON artifacts(artifact_key);
            """
        )
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_artifacts_session_contract
            ON artifacts(session_id, contract_id);
            """
        )
    }

    // MARK: - Migration Helpers

    /// Adds a column to a table if it does not already exist.
    private static func addColumnIfMissing(
        db: DatabaseActor,
        table: String,
        column: String,
        type: String
    ) async throws {
        let rows = try await db.query("PRAGMA table_info(\(table));")
        let exists = rows.contains { $0.string(for: "name") == column }

        if !exists {
            try await db.execute("ALTER TABLE \(table) ADD COLUMN \(column) \(type);")
        }
    }
}
