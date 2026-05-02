//
//  MasterLedgerMigration.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Migration for master ledger with thinned payload references.
public enum MasterLedgerMigration {
    public static func migrate(_ db: any DatabaseExecutor) async throws {
        do {
            try await db.executeAsync("BEGIN TRANSACTION")
            try await createMasterLedgerTables(db)
            try await createIndexes(db)
            try await db.executeAsync("COMMIT TRANSACTION")
        } catch {
            _ = try? await db.executeAsync("ROLLBACK TRANSACTION")
            throw error
        }
    }

    private static func createMasterLedgerTables(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS master_ledger_events (
                event_id UUID PRIMARY KEY,
                event_type TEXT NOT NULL,
                tool_name TEXT NOT NULL,
                session_id UUID NOT NULL,
                status TEXT NOT NULL,
                precondition_hash TEXT,
                file_hash_before TEXT,
                result_content_hash TEXT,
                error_signature TEXT,
                timestamp TIMESTAMPTZ NOT NULL,
                duration_ms INTEGER,
                metadata JSONB
            );
            """
        )

        try await RetentionEventSchema.register(using: db)
    }

    private static func createIndexes(_ db: any DatabaseExecutor) async throws {
        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_session
            ON master_ledger_events(session_id, timestamp);
            """
        )

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_type
            ON master_ledger_events(event_type, status);
            """
        )

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_tool
            ON master_ledger_events(tool_name);
            """
        )

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_timestamp
            ON master_ledger_events(timestamp);
            """
        )

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_master_events_content_hash
            ON master_ledger_events(result_content_hash);
            """
        )
    }
}
