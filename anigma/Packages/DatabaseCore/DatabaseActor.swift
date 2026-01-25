//
//  DatabaseActor.swift
//  DatabaseCore
//
//  Thread-safe SQLite database access for Swift 6 concurrency.
//  All database operations go through this actor to prevent
//  data races and ensure proper actor isolation.
//

import Foundation
import SQLite3
import VectorStoreCapsule

/// Database health metrics for monitoring SQLite performance.
public struct DatabaseMetrics: Sendable, Codable {
    public let busyTimeoutExhausted: Int
    public let transactionRetries: Int
    public let averageQueryTime: TimeInterval
    public let queryCount: Int
    public let walSize: Int64?
    public let walCheckpointCount: Int64?

    public init(
        busyTimeoutExhausted: Int,
        transactionRetries: Int,
        averageQueryTime: TimeInterval,
        queryCount: Int,
        walSize: Int64? = nil,
        walCheckpointCount: Int64? = nil
    ) {
        self.busyTimeoutExhausted = busyTimeoutExhausted
        self.transactionRetries = transactionRetries
        self.averageQueryTime = averageQueryTime
        self.queryCount = queryCount
        self.walSize = walSize
        self.walCheckpointCount = walCheckpointCount
    }
}

/// Thread-safe database access actor.
public actor DatabaseActor {
    private let dbPath: String
    private var connection: OpaquePointer?

    // Monitoring metrics
    private var busyTimeoutExhaustedCount: Int = 0
    private var transactionRetryCount: Int = 0
    private var totalQueryTime: TimeInterval = 0
    private var queryExecutionCount: Int = 0
    
    private var vectorAvailable: Bool = false
    private var vectorVersion: String?

    public init(dbPath: String = DatabaseConfiguration.defaultDatabasePath()) {
        self.dbPath = dbPath
    }

    /// Absolute path for the backing SQLite file.
    public nonisolated var path: String { dbPath }

    /// Open database connection (thread-safe).
    public func open() throws {
        guard connection == nil else { return }

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.connectionError("Failed to open database: \(errMsg)")
        }
        connection = db

        // Set SQLite pragmas for better concurrency
        // 1. busy_timeout: wait up to 5 seconds for locks instead of failing immediately
        // 2. journal_mode=WAL: enable Write-Ahead Logging for better read/write concurrency
        var pragmaStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA busy_timeout=5000;", -1, &pragmaStmt, nil) == SQLITE_OK {
            _ = sqlite3_step(pragmaStmt)
            sqlite3_finalize(pragmaStmt)
        }

        if sqlite3_prepare_v2(db, "PRAGMA journal_mode=WAL;", -1, &pragmaStmt, nil) == SQLITE_OK {
            _ = sqlite3_step(pragmaStmt)
            sqlite3_finalize(pragmaStmt)
        }
        
        // Load vector extension
        loadVectorExtension()
    }
    
    private func loadVectorExtension() {
        guard let db = connection else { return }
        
        do {
            try VectorStore.registerExtension(with: UnsafeMutableRawPointer(db))
            vectorAvailable = true
            vectorVersion = VectorStore.version
            logInfo("sqlite-vec loaded successfully (version: \(vectorVersion ?? "unknown"))")
        } catch {
            logWarning("Failed to load sqlite-vec: \(error)")
            vectorAvailable = false
        }
    }
    
    public func isVectorAvailable() -> Bool {
        return vectorAvailable
    }
    
    public func getVectorVersion() -> String? {
        return vectorVersion
    }

    private func ensureOpen() throws {
        if connection == nil {
            try open()
        }
    }

    /// Close database connection (thread-safe).
    public func close() {
        if let conn = connection {
            sqlite3_close(conn)
            connection = nil
        }
    }

    /// Execute a query and return rows.
    public func query(
        _ sql: String,
        parameters: [DatabaseParameter] = []
    ) async throws -> [DatabaseRow] {
        try ensureOpen()
        guard let db = connection else {
            throw DatabaseError.connectionError("Database not open")
        }

        let startTime = Date()
        defer {
            let queryTime = Date().timeIntervalSince(startTime)
            totalQueryTime += queryTime
            queryExecutionCount += 1
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryError("Failed to prepare query: \(errMsg)")
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in parameters.enumerated() {
            let paramIndex = Int32(index + 1)
            switch param {
            case .text(let value):
                sqlite3_bind_text(stmt, paramIndex, value, -1, SQLITE_TRANSIENT)
            case .int(let value):
                sqlite3_bind_int64(stmt, paramIndex, Int64(value))
            case .double(let value):
                sqlite3_bind_double(stmt, paramIndex, value)
            case .blob(let data):
                _ = data.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(
                        stmt, paramIndex, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
                }
            case .null:
                sqlite3_bind_null(stmt, paramIndex)
            }
        }

        // Fetch rows
        var rows: [DatabaseRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var values: [String: DatabaseValue] = [:]
            let columnCount = sqlite3_column_count(stmt)

            for i in 0..<columnCount {
                let columnName = String(cString: sqlite3_column_name(stmt, i))
                let columnType = sqlite3_column_type(stmt, i)

                switch columnType {
                case SQLITE_INTEGER:
                    values[columnName] = .int(Int(sqlite3_column_int64(stmt, i)))
                case SQLITE_FLOAT:
                    values[columnName] = .double(sqlite3_column_double(stmt, i))
                case SQLITE_TEXT:
                    values[columnName] = .text(String(cString: sqlite3_column_text(stmt, i)))
                case SQLITE_BLOB:
                    let bytes = sqlite3_column_blob(stmt, i)
                    let length = Int(sqlite3_column_bytes(stmt, i))
                    if let bytes {
                        let data = Data(bytes: bytes, count: length)
                        values[columnName] = .blob(data)
                    } else {
                        values[columnName] = .null
                    }
                case SQLITE_NULL:
                    values[columnName] = .null
                default:
                    values[columnName] = .null
                }
            }
            rows.append(DatabaseRow(values: values))
        }

        return rows
    }

    /// Execute an update/insert/delete.
    @discardableResult public func performExecute(
        _ sql: String,
        parameters: [DatabaseParameter] = []
    ) throws -> Int {
        try ensureOpen()
        guard let db = connection else {
            throw DatabaseError.connectionError("Database not open")
        }

        let startTime = Date()
        defer {
            let queryTime = Date().timeIntervalSince(startTime)
            totalQueryTime += queryTime
            queryExecutionCount += 1
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryError("Failed to prepare statement: \(errMsg)")
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in parameters.enumerated() {
            let paramIndex = Int32(index + 1)
            switch param {
            case .text(let value):
                sqlite3_bind_text(stmt, paramIndex, value, -1, SQLITE_TRANSIENT)
            case .int(let value):
                sqlite3_bind_int64(stmt, paramIndex, Int64(value))
            case .double(let value):
                sqlite3_bind_double(stmt, paramIndex, value)
            case .blob(let data):
                _ = data.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(
                        stmt, paramIndex, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
                }
            case .null:
                sqlite3_bind_null(stmt, paramIndex)
            }
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryError("Failed to execute statement: \(errMsg)")
        }

        return Int(sqlite3_changes(db))
    }

    /// Execute a multi-statement SQL script.
    @discardableResult public func executeScript(_ sql: String) throws -> Int32 {
        try ensureOpen()
        guard let db = connection else {
            throw DatabaseError.connectionError("Database not open")
        }

        var errorMessage: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQL error"
            sqlite3_free(errorMessage)
            throw DatabaseError.queryError("Failed to execute script: \(message)")
        }

        return result
    }

    /// Alias for query to match legacy call sites.
    public func executeQuery(
        _ sql: String,
        parameters: [DatabaseParameter] = []
    ) async throws -> [DatabaseRow] {
        try await query(sql, parameters: parameters)
    }

    /// Async wrapper for execute method to support actor-to-actor calls
    @discardableResult public func executeAsync(
        _ sql: String,
        parameters: [DatabaseParameter] = []
    ) async throws -> Int {
        return try performExecute(sql, parameters: parameters)
    }

    /// Execute multiple statements in a transaction.
    public func transaction(_ block: @Sendable () async throws -> Void) async throws {
        try await transaction(mode: .deferred, block)
    }

    /// Execute multiple statements in a transaction with specified mode.
    /// - Parameter mode: Transaction mode (.deferred, .immediate, .exclusive)
    /// - Parameter block: The async block to execute within the transaction
    /// - Parameter maxRetries: Maximum number of retries for SQLITE_BUSY (default: 3)
    /// - Parameter initialBackoff: Initial backoff in milliseconds (default: 100)
    public func transaction(
        mode: TransactionMode = .deferred, _ block: @Sendable () async throws -> Void,
        maxRetries: Int = 3,
        initialBackoff: Int = 100
    ) async throws {
        guard let db = connection else {
            throw DatabaseError.connectionError("Database not open")
        }

        let beginSQL: String
        switch mode {
        case .deferred:
            beginSQL = "BEGIN DEFERRED TRANSACTION"
        case .immediate:
            beginSQL = "BEGIN IMMEDIATE TRANSACTION"
        case .exclusive:
            beginSQL = "BEGIN EXCLUSIVE TRANSACTION"
        }

        // Try to begin transaction with retry logic for SQLITE_BUSY
        for attempt in 0...maxRetries {
            if attempt > 0 {
                // Exponential backoff: 100ms, 200ms, 400ms, etc.
                let backoffMs = initialBackoff * Int(pow(2.0, Double(attempt - 1)))
                try await Task.sleep(nanoseconds: UInt64(backoffMs) * 1_000_000)
                transactionRetryCount += 1
            }

            let result = sqlite3_exec(db, beginSQL, nil, nil, nil)
            if result == SQLITE_OK {
                break
            } else if result == SQLITE_BUSY && attempt < maxRetries {
                continue
            } else {
                if result == SQLITE_BUSY {
                    busyTimeoutExhaustedCount += 1
                }
                let errMsg = String(cString: sqlite3_errmsg(db))
                throw DatabaseError.transactionError(
                    "Failed to begin transaction after \(attempt + 1) attempts: \(errMsg)")
            }
        }

        do {
            try await block()
            guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
                throw DatabaseError.transactionError("Failed to commit transaction")
            }
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    /// Get current database health metrics.
    public func getMetrics() -> DatabaseMetrics {
        let averageQueryTime =
            queryExecutionCount > 0 ? totalQueryTime / Double(queryExecutionCount) : 0

        // Try to get WAL information if connection is open
        var walSize: Int64?
        var walCheckpointCount: Int64?

        if let db = connection {
            // Get WAL file size
            let walPath = dbPath + "-wal"
            if FileManager.default.fileExists(atPath: walPath) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: walPath)
                    walSize = (attributes[.size] as? NSNumber)?.int64Value
                } catch {
                    // Ignore errors getting file size
                }
            }

            // Get WAL checkpoint count from pragma
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "PRAGMA wal_checkpoint;", -1, &stmt, nil) == SQLITE_OK {
                _ = sqlite3_step(stmt)
                // The pragma returns 3 columns: busy, log, checkpointed
                // We can get checkpointed pages count from column 2 (0-indexed)
                walCheckpointCount = sqlite3_column_int64(stmt, 2)
                sqlite3_finalize(stmt)
            }
        }

        return DatabaseMetrics(
            busyTimeoutExhausted: busyTimeoutExhaustedCount,
            transactionRetries: transactionRetryCount,
            averageQueryTime: averageQueryTime,
            queryCount: queryExecutionCount,
            walSize: walSize,
            walCheckpointCount: walCheckpointCount
        )
    }

    /// Perform a WAL checkpoint to reduce WAL file size.
    /// - Parameter mode: Checkpoint mode (.passive, .full, .restart, .truncate)
    /// - Returns: Tuple with (busy: Bool, log: Int32, checkpointed: Int32) or nil if failed
    public func checkpointWal(mode: CheckpointMode = .passive) -> (
        busy: Bool, log: Int32, checkpointed: Int32
    )? {
        guard let db = connection else { return nil }

        var log: Int32 = 0
        var checkpointed: Int32 = 0
        let result = sqlite3_wal_checkpoint_v2(db, nil, mode.rawValue, &log, &checkpointed)

        if result == SQLITE_OK {
            return (false, log, checkpointed)
        } else if result == SQLITE_BUSY {
            return (true, log, checkpointed)
        }
        return nil
    }

    /// Check if WAL is growing without checkpoints (starvation detection).
    /// - Parameter thresholdMB: Size threshold in MB to trigger checkpoint (default: 100MB)
    /// - Returns: true if checkpoint was performed, false otherwise
    public func checkpointIfWalLarge(thresholdMB: Int64 = 100) -> Bool {
        guard connection != nil else { return false }

        let walPath = dbPath + "-wal"
        guard FileManager.default.fileExists(atPath: walPath) else { return false }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: walPath)
            guard let size = attributes[.size] as? NSNumber else { return false }

            let sizeMB = size.int64Value / (1024 * 1024)
            if sizeMB > thresholdMB {
                // WAL is large, try to checkpoint
                if let result = checkpointWal(mode: .passive), result.checkpointed > 0 {
                    logInfo(
                        "Performed WAL checkpoint: checkpointed \(result.checkpointed) pages (WAL was \(sizeMB)MB)"
                    )
                    return true
                }
            }
        } catch {
            // Ignore errors
        }

        return false
    }

    /// Log a message (internal use).
    private func logInfo(_ message: String) {
        fputs("[DatabaseActor] \(message)\n", stderr)
    }

    /// Log a warning message (internal use).
    private func logWarning(_ message: String) {
        fputs("[DatabaseActor] [WARNING] \(message)\n", stderr)
    }

    /// Reset all metrics counters.
    public func resetMetrics() {
        busyTimeoutExhaustedCount = 0
        transactionRetryCount = 0
        totalQueryTime = 0
        queryExecutionCount = 0
    }

    // deinit removed: OpaquePointer cannot be accessed safely from nonisolated deinit.
    // The OS will reclaim the connection on process exit, or user should call .close().
}

// MARK: - Supporting Types

public enum DatabaseParameter: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case null
}

public enum DatabaseError: Error, Sendable {
    case connectionError(String)
    case queryError(String)
    case transactionError(String)
}

public enum TransactionMode: Sendable {
    case deferred
    case immediate
    case exclusive
}

public enum CheckpointMode: Int32, Sendable {
    case passive = 0  // SQLITE_CHECKPOINT_PASSIVE
    case full = 1  // SQLITE_CHECKPOINT_FULL
    case restart = 2  // SQLITE_CHECKPOINT_RESTART
    case truncate = 3  // SQLITE_CHECKPOINT_TRUNCATE
}

public enum DatabaseValue: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case null

    var stringValue: String? {
        switch self {
        case .text(let value):
            return value
        default:
            return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        default:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        default:
            return nil
        }
    }

    var dataValue: Data? {
        switch self {
        case .blob(let value):
            return value
        default:
            return nil
        }
    }

}

public struct DatabaseRow: Sendable {
    public let values: [String: DatabaseValue]

    public init(values: [String: DatabaseValue]) {
        self.values = values
    }

    public func value(for column: String) -> DatabaseValue? {
        values[column]
    }

    public func string(for column: String) -> String? {
        value(for: column)?.stringValue
    }

    public func int(for column: String) -> Int? {
        value(for: column)?.intValue
    }

    public func int64(for column: String) -> Int64? {
        value(for: column)?.asInt64
    }

    public func double(for column: String) -> Double? {
        value(for: column)?.doubleValue
    }

    public func data(for column: String) -> Data? {
        value(for: column)?.dataValue
    }

    public subscript(column: String) -> DatabaseValue? {
        value(for: column)
    }
}
// SQLITE_TRANSIENT shim for Swift
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

let SQLITE_TRANSIENT = unsafeBitCast(
    -1, to: (@convention(c) (UnsafeMutableRawPointer?) -> Void).self)
