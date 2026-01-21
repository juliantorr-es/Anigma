//
//  SessionDatabaseMigration.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Migration for session database boundaries and lifecycle management.
public enum SessionDatabaseMigration {
    public static func migrate(_ db: DatabaseActor) async throws {
        try await db.execute("BEGIN TRANSACTION")
        do {
            try await createSessionTrackerTables(db)
            try await createIndexes(db)
            try await db.execute("COMMIT TRANSACTION")
        } catch {
            _ = try? await db.execute("ROLLBACK TRANSACTION")
            throw error
        }
    }

    private static func createSessionTrackerTables(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS session_databases (
                session_id TEXT PRIMARY KEY,
                database_path TEXT NOT NULL,
                created_at REAL NOT NULL,
                expires_at REAL NOT NULL,
                status TEXT NOT NULL,
                metadata BLOB
            );
            """
        )

        try await db.execute(
            """
            CREATE TABLE IF NOT EXISTS session_cleanup_events (
                cleanup_id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                cleaned_at REAL NOT NULL,
                deleted_bytes INTEGER,
                tables_affected INTEGER,
                reason TEXT
            );
            """
        )
    }

    private static func createIndexes(_ db: DatabaseActor) async throws {
        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_session_dbs_status
            ON session_databases(status, expires_at);
            """
        )

        try await db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_session_cleanup_session
            ON session_cleanup_events(session_id, cleaned_at);
            """
        )
    }
}
