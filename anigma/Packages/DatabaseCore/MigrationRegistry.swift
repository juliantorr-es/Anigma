//
//  MigrationRegistry.swift
//  DatabaseCore
//

import Foundation

/// Central place to apply schema migrations for DatabaseCore consumers.
public enum MigrationRegistry {
    /// Applies all known migrations. Safe to call multiple times.
    public static func applyMigrations(using db: any DatabaseExecutor) async throws {
        try await db.transaction {
            try await createContractJobsIfNeeded(db)
            try await createContractReceipts(db)
            try await createArtifacts(db)
            try await applyVaultMigrations(using: db)
            
            // Note: These migrations still expect DatabaseActor or have their own adaptation logic.
            if let actor = db as? DatabaseActor {
                try await ContentAddressedMigration.migrate(actor)
                try await MasterLedgerMigration.migrate(actor)
                try await SessionDatabaseMigration.migrate(actor)
            }
        }
    }

    /// Applies vault-related schema migrations. Safe to call multiple times.
    public static func applyVaultMigrations(using db: any DatabaseExecutor) async throws {
        try await db.executeAsync(
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
        try await db.executeAsync(
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
        try await db.executeAsync(
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
        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_vault_artifacts_kind
            ON vault_artifacts(kind);
            """
        )
        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_vault_edges_parent
            ON vault_edges(parent_sha256_hex);
            """
        )
        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_vault_access_log_hash
            ON vault_access_log(sha256_hex);
            """
        )
        try await db.executeAsync(
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
        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_retention_events_timestamp
            ON retention_events(started_at);
            """
        )
    }

    private static func createContractJobsIfNeeded(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS contract_jobs (
                job_id TEXT PRIMARY KEY,
                contract_type TEXT NOT NULL,
                status TEXT NOT NULL,
                input_payload BLOB,
                output_payload BLOB,
                error_message TEXT,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            """)
    }

    private static func createContractReceipts(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS contract_receipts (
                receipt_id TEXT PRIMARY KEY,
                job_id TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                signature TEXT NOT NULL,
                signer_id TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            """)
    }

    private static func createArtifacts(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS artifacts (
                artifact_id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                metadata BLOB,
                created_at REAL NOT NULL
            );
            """)
    }

    /// Adds a column to a table if it does not already exist.
    private static func addColumnIfMissing(
        db: any DatabaseExecutor,
        table: String,
        column: String,
        type: String
    ) async throws {
        let rows = try await db.query("PRAGMA table_info(\(table));")
        let exists = rows.contains { $0.string(for: "name") == column }

        if !exists {
            try await db.executeAsync("ALTER TABLE \(table) ADD COLUMN \(column) \(type);")
        }
    }
}
