//
//  MasterLedgerMigration.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Migration for master ledger with thinned payload references.
public enum MasterLedgerMigration {
    public static func migrate(_ db: DatabaseActor) async throws {
        do {
            try await db.execute("BEGIN TRANSACTION")
            try await createMasterLedgerTables(db)
            try await createIndexes(db)
            try await db.execute("COMMIT TRANSACTION")
        } catch {
            _ = try? await db.execute("ROLLBACK TRANSACTION")
            throw error
        }
    }

    private static func createMasterLedgerTables(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS master_ledger_events (
                event_id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                tool_name TEXT NOT NULL,
                session_id TEXT NOT NULL,
                status TEXT NOT NULL,
                precondition_hash TEXT,
                file_hash_before TEXT,
                result_content_hash TEXT,
                error_signature TEXT,
                timestamp REAL NOT NULL,
                duration_ms INTEGER,
                metadata BLOB
            );
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
    }

    private static func createIndexes(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_session
            ON master_ledger_events(session_id, timestamp);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_type
            ON master_ledger_events(event_type, status);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_tool
            ON master_ledger_events(tool_name);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_timestamp
            ON master_ledger_events(timestamp);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_retention_events_timestamp
            ON retention_events(started_at);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_content_hash
            ON master_ledger_events(result_content_hash);
            """
        )
    }
}
