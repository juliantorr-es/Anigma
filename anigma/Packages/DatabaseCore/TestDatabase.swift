//
//  TestDatabase.swift
//  DatabaseCore
//
//  Deterministic database ownership for tests.
//  Each test gets its own isolated database to prevent locking.
//

import Foundation
import SQLite3

/// Isolated test database with deterministic ownership.
/// Prevents "database is locked" errors in concurrent test environments.
public struct TestDatabase {
    private let dbPath: String
    private let tempDir: String

    public init(testName: String) throws {
        // Create unique temp directory for each test
        let testId = UUID().uuidString.prefix(8)
        self.tempDir = NSTemporaryDirectory() + "/anigma_test_\(testId)_\(testName)"

        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        self.dbPath = tempDir + "/test.db"
    }

    /// Opens database with exclusive locking to prevent concurrent access.
    public func openDatabase() throws -> OpaquePointer? {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_EXCLUSIVE

        guard sqlite3_open_v2(self.dbPath, &db, flags, nil) == SQLITE_OK else {
            throw NSError(domain: "TestDatabase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open database"])
        }

        // Enable WAL mode for better concurrency
        executeSQL(db, "PRAGMA journal_mode=WAL")
        executeSQL(db, "PRAGMA synchronous=NORMAL")
        executeSQL(db, "PRAGMA busy_timeout=5000") // 5 second timeout

        return db
    }

    /// Executes a simple SQL statement safely.
    private func executeSQL(_ db: OpaquePointer?, _ sql: String) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("⚠️ TestDatabase: Failed to execute '\(sql)': \(errMsg)")
            return
        }

        defer { sqlite3_finalize(stmt) }

        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("⚠️ TestDatabase: SQL step failed: \(errMsg)")
        }
    }

    /// Closes database and cleans up temp directory.
    public func cleanup() throws {
        // Close any open connections
        if FileManager.default.fileExists(atPath: dbPath) {
            var db: OpaquePointer?
            sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil)
            if db != nil {
                sqlite3_close(db)
            }
        }

        // Remove temp directory
        if FileManager.default.fileExists(atPath: tempDir) {
            try FileManager.default.removeItem(atPath: tempDir)
        }
    }

    /// Gets the database path for external connections.
    public var path: String { dbPath }
}
