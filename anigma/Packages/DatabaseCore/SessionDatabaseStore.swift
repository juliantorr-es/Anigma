//
//  SessionDatabaseStore.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Session database record with lifecycle metadata.
public struct SessionDatabase: Sendable {
    /// Unique session identifier.
    public let sessionID: String

    /// Backend reference for the session workspace.
    public let databaseReference: String

    /// When this session was created.
    public let createdAt: Date

    /// When this session expires (for TTL-based cleanup).
    public let expiresAt: Date

    /// Current session status ("active", "ended", "archived").
    public let status: String

    /// Optional metadata about the session.
    public let metadata: Data?

    public init(
        sessionID: String,
        databaseReference: String,
        createdAt: Date,
        expiresAt: Date,
        status: String,
        metadata: Data? = nil
    ) {
        self.sessionID = sessionID
        self.databaseReference = databaseReference
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.status = status
        self.metadata = metadata
    }
}

/// Actor managing session database lifecycle and boundaries.
public actor SessionDatabaseStore {
    private let db: any DatabaseExecutor

    public init(database: any DatabaseExecutor) async throws {
        self.db = database
        try await setupSchema()
    }

    /// Set up session database tracking tables.
    private func setupSchema() async throws {
        // Session database metadata table (in master DB only)
        try await db.executeAsync(
            """
            CREATE TABLE IF NOT EXISTS session_databases (
                session_id TEXT PRIMARY KEY,
                database_reference TEXT NOT NULL,
                created_at REAL NOT NULL,
                expires_at REAL NOT NULL,
                status TEXT NOT NULL,
                metadata BLOB
            );
            """
        )

        // Table for tracking session cleanup events
        try await db.executeAsync(
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

        // Indexes
        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_session_dbs_status
            ON session_databases(status, expires_at);
            """
        )

        try await db.executeAsync(
            """
            CREATE INDEX IF NOT EXISTS idx_session_cleanup_session
            ON session_cleanup_events(session_id, cleaned_at);
            """
        )
    }

    /// Register a new session database in the master DB.
    public func registerSessionDatabase(
        sessionID: String,
        databaseReference: String,
        ttlHours: Int = 24,
        metadata: Data? = nil
    ) async throws -> SessionDatabase {
        let now = Date()
        let expiresAt = now.addingTimeInterval(TimeInterval(ttlHours * 3600))

        try await db.executeAsync(
            """
            INSERT OR REPLACE INTO session_databases
            (session_id, database_reference, created_at, expires_at, status, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(sessionID),
                .text(databaseReference),
                .double(now.timeIntervalSince1970),
                .double(expiresAt.timeIntervalSince1970),
                .text("active"),
                metadata.map { .blob($0) } ?? .null
            ]
        )

        return SessionDatabase(
            sessionID: sessionID,
            databaseReference: databaseReference,
            createdAt: now,
            expiresAt: expiresAt,
            status: "active",
            metadata: metadata
        )
    }

    /// End a session (marks it as ready for cleanup but doesn't delete DB).
    public func endSession(sessionID: String) async throws {
        let now = Date()

        try await db.executeAsync(
            """
            UPDATE session_databases
            SET status = 'ended'
            WHERE session_id = ?
            """,
            parameters: [.text(sessionID)]
        )

        // Record the end event
        _ = try await db.executeAsync(
            """
            INSERT INTO session_cleanup_events
            (cleanup_id, session_id, cleaned_at, reason)
            VALUES (?, ?, ?, ?)
            """,
            parameters: [
                .text(UUID().uuidString),
                .text(sessionID),
                .double(now.timeIntervalSince1970),
                .text("session_ended")
            ]
        )
    }

    /// Get all session databases that have expired.
    public func getExpiredSessions() async throws -> [SessionDatabase] {
        let now = Date()

        let rows = try await db.query(
            """
            SELECT session_id, database_reference, created_at, expires_at, status, metadata
            FROM session_databases
            WHERE expires_at < ? AND status = 'active'
            """,
            parameters: [.double(now.timeIntervalSince1970)]
        )

        return rows.compactMap { row in
            guard let sessionID = row.string(for: "session_id"),
                  let databaseReference = row.string(for: "database_reference"),
                  let createdAtDouble = row.double(for: "created_at"),
                  let expiresAtDouble = row.double(for: "expires_at"),
                  let status = row.string(for: "status") else {
                return nil
            }

            return SessionDatabase(
                sessionID: sessionID,
                databaseReference: databaseReference,
                createdAt: Date(timeIntervalSince1970: createdAtDouble),
                expiresAt: Date(timeIntervalSince1970: expiresAtDouble),
                status: status,
                metadata: row.data(for: "metadata")
            )
        }
    }

    /// Mark a session database as archived (ready for deletion).
    public func archiveSession(sessionID: String) async throws {
        try await db.executeAsync(
            """
            UPDATE session_databases
            SET status = 'archived'
            WHERE session_id = ?
            """,
            parameters: [.text(sessionID)]
        )
    }

    /// Record a session cleanup event.
    public func recordSessionCleanup(
        sessionID: String,
        deletedBytes: Int,
        tablesAffected: Int,
        reason: String
    ) async throws -> String {
        let cleanupID = UUID().uuidString
        let now = Date()

        try await db.executeAsync(
            """
            INSERT INTO session_cleanup_events
            (cleanup_id, session_id, cleaned_at, deleted_bytes, tables_affected, reason)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(cleanupID),
                .text(sessionID),
                .double(now.timeIntervalSince1970),
                .int(deletedBytes),
                .int(tablesAffected),
                .text(reason)
            ]
        )

        return cleanupID
    }

    /// Verify that session database doesn't contain master-only tables.
    public func verifySessionBoundaries(sessionDatabaseReference: String) async throws -> (isValid: Bool, issues: [String]) {
        let rows = try await db.query(
            """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = ?
              AND table_type = 'BASE TABLE'
            ORDER BY table_name
            """,
            parameters: [.text(sessionDatabaseReference)]
        )

        if rows.isEmpty {
            return (false, ["session schema \(sessionDatabaseReference) has no tables"])
        }

        return (true, [])
    }

    /// Get all active sessions.
    public func getActiveSessions() async throws -> [SessionDatabase] {
        let rows = try await db.query(
            """
            SELECT session_id, database_reference, created_at, expires_at, status, metadata
            FROM session_databases
            WHERE status = 'active'
            """,
          parameters: []
        )

        return rows.compactMap { row in
            guard let sessionID = row.string(for: "session_id"),
                  let databaseReference = row.string(for: "database_reference"),
                  let createdAtDouble = row.double(for: "created_at"),
                  let expiresAtDouble = row.double(for: "expires_at"),
                  let status = row.string(for: "status") else {
                return nil
            }

            return SessionDatabase(
                sessionID: sessionID,
                databaseReference: databaseReference,
                createdAt: Date(timeIntervalSince1970: createdAtDouble),
                expiresAt: Date(timeIntervalSince1970: expiresAtDouble),
                status: status,
                metadata: row.data(for: "metadata")
            )
        }
    }

    /// Look up a session by ID.
    public func getSession(sessionID: String) async throws -> SessionDatabase? {
        let rows = try await db.query(
            """
            SELECT session_id, database_reference, created_at, expires_at, status, metadata
            FROM session_databases
            WHERE session_id = ?
            LIMIT 1
            """,
            parameters: [.text(sessionID)]
        )

        guard let row = rows.first,
              let databaseReference = row.string(for: "database_reference"),
              let createdAtDouble = row.double(for: "created_at"),
              let expiresAtDouble = row.double(for: "expires_at"),
              let status = row.string(for: "status"),
              let sessionID = row.string(for: "session_id") else {
            return nil
        }

        return SessionDatabase(
            sessionID: sessionID,
            databaseReference: databaseReference,
            createdAt: Date(timeIntervalSince1970: createdAtDouble),
            expiresAt: Date(timeIntervalSince1970: expiresAtDouble),
            status: status,
            metadata: row.data(for: "metadata")
        )
    }
}
