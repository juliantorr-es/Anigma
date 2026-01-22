//
//  SQLiteJobPersistence.swift
//  AnigmaCore
//
//  SQLite-based job persistence for crash recovery and audit trails.
//

import Foundation
import AnigmaPrimitives
import SQLite3

/// SQLite-based implementation of JobPersistence protocol.
public actor SQLiteJobPersistence: JobPersistence {
    private let dbPath: String
    private var connection: OpaquePointer?
    
    public init(dbPath: String) {
        self.dbPath = dbPath
    }
    
    /// Open database connection and create schema.
    public func initialize() throws {
        guard connection == nil else { return }
        
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to open database: \(errMsg)")
        }
        connection = db
        
        // Configure SQLite for better concurrency
        configureDatabase(db)
        
        // Create schema
        try createSchema()
    }
    
    private func configureDatabase(_ db: OpaquePointer?) {
        guard let db = db else { return }
        
        // Enable WAL mode for better concurrency
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA journal_mode=WAL;", -1, &stmt, nil) == SQLITE_OK {
            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        
        // Set busy timeout to 5 seconds
        if sqlite3_prepare_v2(db, "PRAGMA busy_timeout=5000;", -1, &stmt, nil) == SQLITE_OK {
            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        
        // Enable foreign keys
        if sqlite3_prepare_v2(db, "PRAGMA foreign_keys=ON;", -1, &stmt, nil) == SQLITE_OK {
            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
    
    private func createSchema() throws {
        guard let db = connection else {
            throw JobError.executionFailed("Database not initialized")
        }
        
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS job_records (
                id TEXT PRIMARY KEY,
                job_json TEXT NOT NULL,
                status TEXT NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                last_attempt_at REAL,
                completed_at REAL,
                result_json TEXT,
                error TEXT,
                deferral_reason TEXT,
                deferred_until REAL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            
            CREATE INDEX IF NOT EXISTS idx_job_records_status ON job_records(status);
            CREATE INDEX IF NOT EXISTS idx_job_records_created_at ON job_records(created_at);
            CREATE INDEX IF NOT EXISTS idx_job_records_deferred_until ON job_records(deferred_until);
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableSQL, -1, &stmt, nil) == SQLITE_OK {
            let result = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
            if result != SQLITE_DONE {
                let errMsg = String(cString: sqlite3_errmsg(db))
                throw JobError.executionFailed("Failed to create schema: \(errMsg)")
            }
        } else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to prepare schema: \(errMsg)")
        }
    }
    
    // MARK: - JobPersistence Implementation
    
    public func save(record: JobRecord) async throws {
        guard let db = connection else {
            throw JobError.executionFailed("Database not initialized")
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .sortedKeys
        
        let jobData = try encoder.encode(record.job)
        let jobJSON = String(data: jobData, encoding: .utf8) ?? "{}"
        
        let resultData = record.result.map { try? encoder.encode($0) }
        let resultJSON = resultData.flatMap { String(data: $0, encoding: .utf8) }
        
        let now = Date().timeIntervalSince1970
        let lastAttempt = record.lastAttemptAt?.timeIntervalSince1970
        let completed = record.completedAt?.timeIntervalSince1970
        let deferredUntil = record.deferredUntil?.timeIntervalSince1970
        
        let sql = """
            INSERT OR REPLACE INTO job_records (
                id, job_json, status, attempts, last_attempt_at,
                completed_at, result_json, error, deferral_reason,
                deferred_until, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to prepare save statement: \(errMsg)")
        }
        
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, record.id.raw, -1, nil)
        sqlite3_bind_text(stmt, 2, jobJSON, -1, nil)
        sqlite3_bind_text(stmt, 3, record.status.rawValue, -1, nil)
        sqlite3_bind_int(stmt, 4, Int32(record.attempts))
        
        if let lastAttempt = lastAttempt {
            sqlite3_bind_double(stmt, 5, lastAttempt)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        
        if let completed = completed {
            sqlite3_bind_double(stmt, 6, completed)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        
        if let resultJSON = resultJSON {
            sqlite3_bind_text(stmt, 7, resultJSON, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        
        if let error = record.error {
            sqlite3_bind_text(stmt, 8, error, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        
        if let deferralReason = record.deferralReason {
            sqlite3_bind_text(stmt, 9, deferralReason, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        
        if let deferredUntil = deferredUntil {
            sqlite3_bind_double(stmt, 10, deferredUntil)
        } else {
            sqlite3_bind_null(stmt, 10)
        }
        
        sqlite3_bind_double(stmt, 11, record.job.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 12, now)
        
        let result = sqlite3_step(stmt)
        if result != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to save job record: \(errMsg)")
        }
    }
    
    public func load(jobId: JobId) async throws -> JobRecord? {
        guard let db = connection else {
            throw JobError.executionFailed("Database not initialized")
        }
        
        let sql = "SELECT * FROM job_records WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to prepare load statement: \(errMsg)")
        }
        
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, jobId.raw, -1, nil)
        
        let result = sqlite3_step(stmt)
        if result == SQLITE_ROW {
            return try decodeJobRecord(from: stmt)
        } else if result == SQLITE_DONE {
            return nil
        } else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to load job record: \(errMsg)")
        }
    }
    
    public func loadActiveJobs() async throws -> [JobRecord] {
        return try await loadJobs(status: Set([.pending, .scheduled, .running, .retrying, .deferred]))
    }
    
    public func loadJobs(status: Set<JobStatus>? = nil, limit: Int? = nil) async throws -> [JobRecord] {
        guard let db = connection else {
            throw JobError.executionFailed("Database not initialized")
        }
        
        var sql = "SELECT * FROM job_records"
        var params: [String] = []
        
        if let status = status, !status.isEmpty {
            let statusPlaceholders = status.map { "?" }.joined(separator: ", ")
            sql += " WHERE status IN (\(statusPlaceholders))"
            params.append(contentsOf: status.map { $0.rawValue })
        }
        
        sql += " ORDER BY created_at DESC"
        
        if let limit = limit {
            sql += " LIMIT ?"
            params.append("\(limit)")
        }
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to prepare query statement: \(errMsg)")
        }
        
        defer { sqlite3_finalize(stmt) }
        
        // Bind parameters
        for (index, param) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), param, -1, nil)
        }
        
        var records: [JobRecord] = []
        var result = sqlite3_step(stmt)
        
        while result == SQLITE_ROW {
            if let record = try? decodeJobRecord(from: stmt) {
                records.append(record)
            }
            result = sqlite3_step(stmt)
        }
        
        if result != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to query job records: \(errMsg)")
        }
        
        return records
    }
    
    public func delete(jobId: JobId) async throws {
        guard let db = connection else {
            throw JobError.executionFailed("Database not initialized")
        }
        
        let sql = "DELETE FROM job_records WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to prepare delete statement: \(errMsg)")
        }
        
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, jobId.raw, -1, nil)
        
        let result = sqlite3_step(stmt)
        if result != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to delete job record: \(errMsg)")
        }
    }
    
    public func cleanup(before date: Date) async throws {
        guard let db = connection else {
            throw JobError.executionFailed("Database not initialized")
        }
        
        let timestamp = date.timeIntervalSince1970
        let sql = "DELETE FROM job_records WHERE created_at < ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to prepare cleanup statement: \(errMsg)")
        }
        
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, timestamp)
        
        let result = sqlite3_step(stmt)
        if result != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw JobError.executionFailed("Failed to cleanup job records: \(errMsg)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func decodeJobRecord(from stmt: OpaquePointer?) throws -> JobRecord {
        guard let stmt = stmt else {
            throw JobError.executionFailed("Invalid statement for decoding")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        // Decode job JSON
        let jobJSON = String(cString: sqlite3_column_text(stmt, 1))
        let jobData = Data(jobJSON.utf8)
        let job = try decoder.decode(Job.self, from: jobData)
        
        // Decode status
        let statusRaw = String(cString: sqlite3_column_text(stmt, 2))
        let status = JobStatus(rawValue: statusRaw) ?? .pending
        
        // Decode other fields
        let attempts = Int(sqlite3_column_int(stmt, 3))
        
        let lastAttemptAt: Date? = {
            let value = sqlite3_column_double(stmt, 4)
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }()
        
        let completedAt: Date? = {
            let value = sqlite3_column_double(stmt, 5)
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }()
        
        let result: JobResult? = {
            guard let resultJSON = sqlite3_column_text(stmt, 6) else { return nil }
            let resultData = Data(String(cString: resultJSON).utf8)
            return try? decoder.decode(JobResult.self, from: resultData)
        }()
        
        let error = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
        let deferralReason = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        
        let deferredUntil: Date? = {
            let value = sqlite3_column_double(stmt, 9)
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }()
        
        return JobRecord(
            job: job,
            status: status,
            attempts: attempts,
            lastAttemptAt: lastAttemptAt,
            completedAt: completedAt,
            result: result,
            error: error,
            deferralReason: deferralReason,
            deferredUntil: deferredUntil
        )
    }
    
    deinit {
        if let connection = connection {
            sqlite3_close(connection)
        }
    }
}