//
//  PostgresJobPersistence.swift
//  AnigmaCore
//
//  PostgreSQL-backed job persistence for crash recovery and audit trails.
//

import AnigmaFoundation
import AnigmaGovernance
import DatabaseCore
import Foundation
import AnigmaPrimitives

/// PostgreSQL-backed implementation of `JobPersistence`.
/// 
/// IMPORTANT: This class should receive a `DatabaseExecutor` via dependency injection.
/// Only composition roots should create DatabaseActor directly.
/// See ADR-0018 and td-317bbb for details.
public actor PostgresJobPersistence: JobPersistence {
    private let database: any DatabaseExecutor
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    /// Preferred initializer - receives DatabaseExecutor via dependency injection.
    public init(database: any DatabaseExecutor) {
        self.database = database
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder.dateEncodingStrategy = .secondsSince1970
        self.jsonEncoder.outputFormatting = [.sortedKeys]
        self.jsonDecoder.dateDecodingStrategy = .secondsSince1970
    }
    

    
    public func initialize() async throws {
        try await database.execute("""
            CREATE TABLE IF NOT EXISTS job_records (
                id TEXT PRIMARY KEY,
                job_json JSONB NOT NULL,
                status TEXT NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                last_attempt_at DOUBLE PRECISION,
                completed_at DOUBLE PRECISION,
                result_json JSONB,
                error TEXT,
                deferral_reason TEXT,
                deferred_until DOUBLE PRECISION,
                created_at DOUBLE PRECISION NOT NULL,
                updated_at DOUBLE PRECISION NOT NULL
            )
        """)
        try await database.execute("""
            CREATE INDEX IF NOT EXISTS idx_job_records_status ON job_records(status)
        """)
        try await database.execute("""
            CREATE INDEX IF NOT EXISTS idx_job_records_created_at ON job_records(created_at)
        """)
        try await database.execute("""
            CREATE INDEX IF NOT EXISTS idx_job_records_deferred_until ON job_records(deferred_until)
        """)
    }
    
    public func save(record: JobRecord) async throws {
        let jobJSON = try encode(record.job)
        let resultJSON = try encode(record.result)
        let now = Date().timeIntervalSince1970
        
        try await database.execute(
            """
            INSERT INTO job_records (
                id, job_json, status, attempts, last_attempt_at,
                completed_at, result_json, error, deferral_reason,
                deferred_until, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                job_json = EXCLUDED.job_json,
                status = EXCLUDED.status,
                attempts = EXCLUDED.attempts,
                last_attempt_at = EXCLUDED.last_attempt_at,
                completed_at = EXCLUDED.completed_at,
                result_json = EXCLUDED.result_json,
                error = EXCLUDED.error,
                deferral_reason = EXCLUDED.deferral_reason,
                deferred_until = EXCLUDED.deferred_until,
                created_at = EXCLUDED.created_at,
                updated_at = EXCLUDED.updated_at
            """,
            parameters: [
                .text(record.id.raw),
                jobJSON,
                .text(record.status.rawValue),
                .int(record.attempts),
                dbpTime(record.lastAttemptAt?.timeIntervalSince1970),
                dbpTime(record.completedAt?.timeIntervalSince1970),
                resultJSON,
                dbp(record.error),
                dbp(record.deferralReason),
                dbpTime(record.deferredUntil?.timeIntervalSince1970),
                dbpTime(record.job.createdAt.timeIntervalSince1970),
                dbpTime(now)
            ]
        )
    }
    
    public func load(jobId: JobId) async throws -> JobRecord? {
        try await queryJobs(
            status: nil,
            limit: nil,
            whereClause: "id = ?",
            parameters: [.text(jobId.raw)]
        ).first
    }
    
    public func loadActiveJobs() async throws -> [JobRecord] {
        try await queryJobs(
            status: Set<AnigmaFoundation.JobStatus>([
                .pending,
                .scheduled,
                .running,
                .retrying,
                .deferred
            ]),
            limit: nil,
            whereClause: nil,
            parameters: []
        )
    }
    
    public func loadJobs(status: Set<AnigmaFoundation.JobStatus>?, limit: Int?) async throws -> [JobRecord] {
        try await queryJobs(status: status, limit: limit, whereClause: nil, parameters: [])
    }
    
    public func delete(jobId: JobId) async throws {
        try await database.execute(
            "DELETE FROM job_records WHERE id = ?",
            parameters: [.text(jobId.raw)]
        )
    }
    
    public func cleanup(before date: Date) async throws {
        try await database.execute(
            "DELETE FROM job_records WHERE created_at < ?",
            parameters: [dbpTime(date.timeIntervalSince1970)]
        )
    }
    
    private func queryJobs(
        status: Set<AnigmaFoundation.JobStatus>?,
        limit: Int?,
        whereClause: String?,
        parameters: [DatabaseParameter]
    ) async throws -> [JobRecord] {
        var sql = "SELECT * FROM job_records"
        var queryParameters = parameters
        
        if let status = status, !status.isEmpty {
            let statusPlaceholders = status.map { _ in "?" }.joined(separator: ", ")
            sql += whereClause == nil ? " WHERE " : " AND "
            sql += "status IN (\(statusPlaceholders))"
            queryParameters.append(contentsOf: status.map { .text($0.rawValue) })
        } else if let whereClause {
            sql += " WHERE \(whereClause)"
        }
        
        sql += " ORDER BY created_at DESC"
        
        if let limit {
            sql += " LIMIT ?"
            queryParameters.append(.int(limit))
        }
        
        let rows = try await database.query(sql, parameters: queryParameters)
        return try rows.map(decodeJobRecord)
    }
    
    private func encode<T: Encodable>(_ value: T?) throws -> DatabaseParameter {
        guard let value else { return .null }
        let data = try jsonEncoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw JobError.executionFailed("Failed to encode JSON payload")
        }
        return .text(json)
    }
    
    private func decodeJobRecord(_ row: DatabaseRow) throws -> JobRecord {
        guard let jobJSON = row.string(for: "job_json") else {
            throw JobError.executionFailed("Missing job_json column")
        }
        guard let jobData = jobJSON.data(using: .utf8) else {
            throw JobError.executionFailed("Invalid job_json payload")
        }
        
        let job = try jsonDecoder.decode(Job.self, from: jobData)
        let status = AnigmaFoundation.JobStatus(rawValue: row.string(for: "status") ?? "") ?? .pending
        let attempts = row.int(for: "attempts") ?? 0
        let lastAttemptAt = row.double(for: "last_attempt_at").map(Date.init(timeIntervalSince1970:))
        let completedAt = row.double(for: "completed_at").map(Date.init(timeIntervalSince1970:))
        let deferredUntil = row.double(for: "deferred_until").map(Date.init(timeIntervalSince1970:))
        let error = row.string(for: "error")
        let deferralReason = row.string(for: "deferral_reason")
        let result = try decodeResult(row.string(for: "result_json"))
        
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
    
    private func decodeResult(_ json: String?) throws -> JobResult? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try jsonDecoder.decode(JobResult.self, from: data)
    }
}
