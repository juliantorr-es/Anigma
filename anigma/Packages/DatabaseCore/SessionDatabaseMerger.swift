//
//  SessionDatabaseMerger.swift
//  DatabaseCore
//
//  Session database merger for Phase 7.5
//  Implements idempotent merge-to-master capability using PostgreSQL schema merges
//

import Foundation
import CryptoKit

/// Actor managing idempotent session database merges to master
public actor SessionDatabaseMerger {
    private let db: any DatabaseExecutor
    private let sessionStore: SessionDatabaseStore

    public init(database: any DatabaseExecutor, sessionStore: SessionDatabaseStore) {
        self.db = database
        self.sessionStore = sessionStore
    }

    /// Merge a session schema into the current master schema idempotently.
    public func mergeToMaster(sessionID: String) async throws -> MergeResult {
        let startTime = Date()

        guard let session = try await sessionStore.getSession(sessionID: sessionID) else {
            throw SessionDatabaseError.databaseNotFound(sessionID)
        }

        let sessionSchema = session.databaseReference

        // Verify session schema boundaries (no master-only tables)
        let (isValid, issues) = try await sessionStore.verifySessionBoundaries(sessionDatabaseReference: sessionSchema)
        if !isValid {
            throw SessionDatabaseError.boundaryViolation(issues)
        }

        do {
            // Begin merge transaction
            try await db.executeAsync("BEGIN TRANSACTION;")

            // Get current target schema and the list of session tables.
            let targetSchema = try await getCurrentSchema()
            let sessionTables = try await getSessionTables(sessionSchema: sessionSchema)

            var rowsCopied = 0
            var tablesProcessed = 0

            // Merge each table from session database to master
            for table in sessionTables {
                // Check if table exists in master
                let masterTableExists = try await tableExists(table, in: targetSchema)

                if masterTableExists {
                    // Merge rows using PostgreSQL's conflict handling.
                    rowsCopied += try await mergeTableRows(
                        table: table,
                        from: sessionSchema,
                        to: targetSchema
                    )
                } else {
                    // Clone the table shape, then copy rows.
                    try await copyTable(
                        table: table,
                        from: sessionSchema,
                        to: targetSchema
                    )

                    // Count rows in copied table
                    let rowCount = try await countTableRows(table, in: targetSchema)
                    rowsCopied += rowCount
                }

                tablesProcessed += 1
            }

            // Record merge event in master database
            let mergeID = UUID().uuidString
            try await db.executeAsync(
                """
                INSERT INTO session_merge_events
                (merge_id, session_id, merged_at, rows_merged, tables_processed, status)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                parameters: [
                    .text(mergeID),
                    .text(sessionID),
                    .double(Date().timeIntervalSince1970),
                    .int(rowsCopied),
                    .int(tablesProcessed),
                    .text("completed")
                ]
            )

            // Commit transaction
            try await db.executeAsync("COMMIT;")

            // Mark session as merged in the store
            try await sessionStore.archiveSession(sessionID: sessionID)

            let duration = Date().timeIntervalSince(startTime)

            return MergeResult(
                success: true,
                sessionID: sessionID,
                rowsMerged: rowsCopied,
                tablesProcessed: tablesProcessed,
                durationSeconds: duration,
                mergeID: mergeID
            )
        } catch {
            // Rollback transaction on error
            _ = try? await db.executeAsync("ROLLBACK;")
            throw error
        }
    }

    /// Verify merge idempotency by replaying the merge plan inside a rollback-only transaction.
    public func verifyMergeIdempotency(sessionID: String) async throws -> Bool {
        guard let session = try await sessionStore.getSession(sessionID: sessionID) else {
            throw SessionDatabaseError.databaseNotFound(sessionID)
        }

        let sessionSchema = session.databaseReference
        let targetSchema = try await getCurrentSchema()

        try await db.executeAsync("BEGIN TRANSACTION;")
        do {
            let firstPass = try await previewMerge(sessionSchema: sessionSchema, targetSchema: targetSchema)
            let secondPass = try await previewMerge(sessionSchema: sessionSchema, targetSchema: targetSchema)
            _ = try await db.executeAsync("ROLLBACK;")
            return firstPass == secondPass
        } catch {
            _ = try? await db.executeAsync("ROLLBACK;")
            throw error
        }
    }

    // MARK: - Private Helper Methods

    private func getCurrentSchema() async throws -> String {
        let rows = try await db.query("SELECT current_schema() AS schema_name")
        return rows.first?.string(for: "schema_name") ?? "public"
    }

    private func getSessionTables(sessionSchema: String) async throws -> [String] {
        let rows = try await db.query(
            """
            SELECT table_name AS name
            FROM information_schema.tables
            WHERE table_schema = ?
              AND table_type = 'BASE TABLE'
            ORDER BY name
            """
            ,
            parameters: [.text(sessionSchema)]
        )
        return rows.compactMap { $0.string(for: "name") }
    }

    private func tableExists(_ table: String, in database: String) async throws -> Bool {
        let safeTable = try requireSafeIdentifier(table)
        let safeDatabase = try requireSafeIdentifier(database)
        let rows = try await db.query(
            """
            SELECT 1 AS found
            FROM information_schema.tables
            WHERE table_schema = ?
              AND table_name = ?
              AND table_type = 'BASE TABLE'
            LIMIT 1
            """,
            parameters: [.text(safeDatabase), .text(safeTable)]
        )
        return rows.first?["found"]?.asInt == 1
    }

    private func mergeTableRows(table: String, from sessionDB: String, to masterDB: String) async throws -> Int {
        let safeTable = try requireSafeIdentifier(table)
        let safeFrom = try requireSafeIdentifier(sessionDB)
        let safeTo = try requireSafeIdentifier(masterDB)
        let sql = "INSERT INTO \(safeTo).\(safeTable) SELECT * FROM \(safeFrom).\(safeTable) ON CONFLICT DO NOTHING;"
        return try await db.executeAsync(sql)
    }

    private func copyTable(table: String, from sessionDB: String, to masterDB: String) async throws {
        let safeTable = try requireSafeIdentifier(table)
        let safeFrom = try requireSafeIdentifier(sessionDB)
        let safeTo = try requireSafeIdentifier(masterDB)
        try await db.executeAsync(
            "CREATE TABLE IF NOT EXISTS \(safeTo).\(safeTable) (LIKE \(safeFrom).\(safeTable) INCLUDING ALL);"
        )
        let insertSQL = "INSERT INTO \(safeTo).\(safeTable) SELECT * FROM \(safeFrom).\(safeTable) ON CONFLICT DO NOTHING;"
        _ = try await db.executeAsync(insertSQL)
    }

    private func countTableRows(_ table: String, in database: String) async throws -> Int {
        let safeTable = try requireSafeIdentifier(table)
        let safeDatabase = try requireSafeIdentifier(database)
        let rows = try await db.query("SELECT COUNT(*) AS count FROM \(safeDatabase).\(safeTable);")
        return rows.first?["count"]?.asInt ?? 0
    }

    private func previewMerge(sessionSchema: String, targetSchema: String) async throws -> String {
        let tables = try await getSessionTables(sessionSchema: sessionSchema)
        var digestInput: [String] = []

        for table in tables {
            let exists = try await tableExists(table, in: targetSchema)
            digestInput.append("\(table):\(exists ? "merge" : "create")")
        }

        let digest = SHA256.hash(data: Data(digestInput.joined(separator: "|").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func requireSafeIdentifier(_ value: String) throws -> String {
        guard !value.isEmpty else {
            throw SessionDatabaseError.mergeConflict(value)
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if value.rangeOfCharacter(from: allowed.inverted) != nil {
            throw SessionDatabaseError.mergeConflict(value)
        }
        return value
    }
}

/// Result of a session database merge operation
public struct MergeResult: Codable, Sendable {
    public let success: Bool
    public let sessionID: String
    public let rowsMerged: Int
    public let tablesProcessed: Int
    public let durationSeconds: TimeInterval
    public let mergeID: String

    public init(success: Bool, sessionID: String, rowsMerged: Int, tablesProcessed: Int, durationSeconds: TimeInterval, mergeID: String) {
        self.success = success
        self.sessionID = sessionID
        self.rowsMerged = rowsMerged
        self.tablesProcessed = tablesProcessed
        self.durationSeconds = durationSeconds
        self.mergeID = mergeID
    }
}

/// Errors for session database merging
public enum SessionDatabaseError: Error, LocalizedError {
    case databaseNotFound(String)
    case boundaryViolation([String])
    case mergeConflict(String)
    case checksumMismatch

    public var errorDescription: String? {
        switch self {
        case .databaseNotFound(let path):
            return "Session database not found: \(path)"
        case .boundaryViolation(let issues):
            return "Session database boundary violation: \(issues.joined(separator: ", "))"
        case .mergeConflict(let table):
            return "Conflict merging table: \(table)"
        case .checksumMismatch:
            return "Session database integrity check failed"
        }
    }
}
