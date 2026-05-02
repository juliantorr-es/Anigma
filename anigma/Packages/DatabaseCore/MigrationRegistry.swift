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
            try await SchemaRegistry.ensureRegistryTable(using: db)
            try await createContractJobsIfNeeded(db)
            try await createRefinementJobsIfNeeded(db)
            try await createContractReceipts(db)
            try await createArtifacts(db)
            try await applyVaultMigrations(using: db)
            try await ContentAddressedMigration.migrate(db)
            try await MasterLedgerMigration.migrate(db)
            try await SessionDatabaseMigration.migrate(db)
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
                id BIGSERIAL PRIMARY KEY,
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
        try await RetentionEventSchema.register(using: db)
    }

    private static func createContractJobsIfNeeded(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS contract_jobs (
                id TEXT PRIMARY KEY,
                contract_id TEXT NOT NULL,
                session_id TEXT NOT NULL,
                queue_key TEXT NOT NULL UNIQUE,
                payload TEXT NOT NULL,
                status TEXT NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                error TEXT,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            """)
        try await db.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_contract_jobs_session_status_created
            ON contract_jobs(session_id, status, created_at);
            """)
        try await db.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_contract_jobs_queue_key
            ON contract_jobs(queue_key);
            """)
    }

    private static func createRefinementJobsIfNeeded(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS refinement_jobs (
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                artifact_id TEXT NOT NULL,
                status TEXT NOT NULL,
                claimed_by TEXT,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                priority INTEGER NOT NULL DEFAULT 0,
                retry_count INTEGER NOT NULL DEFAULT 0,
                max_retries INTEGER NOT NULL DEFAULT 3,
                error TEXT
            );
            """)
        try await db.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_refinement_jobs_pending
            ON refinement_jobs(project_id, status, priority DESC, created_at ASC);
            """)
        try await db.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_refinement_jobs_claimed_by
            ON refinement_jobs(claimed_by);
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
        let rows = try await db.query(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = current_schema()
              AND table_name = ?
            """,
            parameters: [.text(table)]
        )
        let exists = rows.contains { $0.string(for: "column_name") == column }

        if !exists {
            try await db.executeAsync("ALTER TABLE \(table) ADD COLUMN \(column) \(type);")
        }
    }
}
