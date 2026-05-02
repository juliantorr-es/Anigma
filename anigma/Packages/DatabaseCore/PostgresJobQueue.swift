//
//  PostgresJobQueue.swift
//  DatabaseCore
//
//  PostgreSQL JobQueue abstraction using SKIP LOCKED pattern.
//  Provides efficient job claiming and processing.
//
//  See td-a53d9f: Create JobQueue abstraction using SKIP LOCKED
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation
import AnigmaPrimitives

// MARK: - Job Status

/// Job status enumeration
public enum PostgresJobStatus: String, Sendable, Codable, CaseIterable {
    case pending
    case claimed
    case processing
    case completed
    case failed
    case deadlettered
    
    public var isTerminal: Bool {
        [.completed, .failed, .deadlettered].contains(self)
    }
    
    public var isActive: Bool {
        [.claimed, .processing].contains(self)
    }
}

// MARK: - Job Priority

/// Job priority levels
public enum PostgresJobPriority: Int, Sendable, Codable, CaseIterable {
    case low = 1
    case normal = 2
    case high = 3
    case urgent = 4
}

// MARK: - Job Record

/// Base job record structure
public protocol PostgresJob: Sendable, Codable {
    var id: UUID { get }
    var queueName: String { get }
    var status: PostgresJobStatus { get set }
    var priority: PostgresJobPriority { get }
    var payload: [String: AnyCodable] { get }
    var claimedBy: String? { get set }
    var claimedAt: Date? { get set }
    var startedAt: Date? { get set }
    var completedAt: Date? { get set }
    var error: String? { get set }
    var attemptCount: Int { get set }
    var maxAttempts: Int { get }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
    
    var isTerminal: Bool { get }
    var canBeRetried: Bool { get }
    
    static var tableName: String { get }
    static var schema: String { get }
    
    /// Create a job from a database row
    static func fromRow(_ row: DatabaseRow, schema: String, table: String) -> Self?
}

public extension PostgresJob {
    var isTerminal: Bool { status.isTerminal }
    var canBeRetried: Bool { !status.isTerminal && attemptCount < maxAttempts }
}

// MARK: - Concrete Job Record

/// Default PostgreSQL job record implementation
public struct PostgresJobRecord: PostgresJob {
    public static var tableName: String { "jobs" }
    public static var schema: String { "anigma" }
    
    public let id: UUID
    public let queueName: String
    public var status: PostgresJobStatus
    public let priority: PostgresJobPriority
    public let payload: [String: AnyCodable]
    public var claimedBy: String?
    public var claimedAt: Date?
    public var startedAt: Date?
    public var completedAt: Date?
    public var error: String?
    public var attemptCount: Int
    public let maxAttempts: Int
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        queueName: String = "default",
        status: PostgresJobStatus = .pending,
        priority: PostgresJobPriority = .normal,
        payload: [String: AnyCodable] = [:],
        claimedBy: String? = nil,
        claimedAt: Date? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        error: String? = nil,
        attemptCount: Int = 0,
        maxAttempts: Int = 3,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.queueName = queueName
        self.status = status
        self.priority = priority
        self.payload = payload
        self.claimedBy = claimedBy
        self.claimedAt = claimedAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.error = error
        self.attemptCount = attemptCount
        self.maxAttempts = maxAttempts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Job Queue

/// PostgreSQL job queue using SKIP LOCKED for efficient job claiming
public actor PostgresJobQueue<Job: PostgresJob> {
    private let database: any DatabaseExecutor
    private let tableName: String
    private let schemaName: String
    
    public init(database: any DatabaseExecutor, schema: String = Job.schema, table: String = Job.tableName) {
        self.database = database
        self.schemaName = schema
        self.tableName = table
    }
    
    // MARK: - Schema Setup
    
    /// Create the job table if it doesn't exist
    public func setup() async throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS " + schemaName + "." + tableName + " (
            id UUID PRIMARY KEY,
            queue_name TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            priority INTEGER NOT NULL DEFAULT 2,
            payload JSONB NOT NULL DEFAULT '{}',
            claimed_by TEXT,
            claimed_at TIMESTAMPTZ,
            started_at TIMESTAMPTZ,
            completed_at TIMESTAMPTZ,
            error TEXT,
            attempt_count INTEGER NOT NULL DEFAULT 0,
            max_attempts INTEGER NOT NULL DEFAULT 3,
            created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT fk_queue CHECK (status IN ('pending', 'claimed', 'processing', 'completed', 'failed', 'deadlettered'))
        )
        """
        _ = try await database.executeAsync(sql)
        
        // Create indexes
        _ = try await database.executeAsync(
            "CREATE INDEX IF NOT EXISTS idx_" + tableName + "_queue_status ON " + schemaName + "." + tableName + " (queue_name, status)"
        )
        _ = try await database.executeAsync(
            "CREATE INDEX IF NOT EXISTS idx_" + tableName + "_priority ON " + schemaName + "." + tableName + " (priority DESC) WHERE status = 'pending'"
        )
        _ = try await database.executeAsync(
            "CREATE INDEX IF NOT EXISTS idx_" + tableName + "_claimed ON " + schemaName + "." + tableName + " (claimed_by) WHERE status = 'claimed'"
        )
    }
    
    // MARK: - Add Jobs
    
    /// Add a new job to the queue
    @discardableResult
    public func add(
        _ job: Job,
        queueName: String? = nil
    ) async throws -> Job {
        var job = job
        let overrideQueue = queueName ?? job.queueName
        
        let sql = """
        INSERT INTO " + schemaName + "." + tableName + " (
            id, queue_name, status, priority, payload, 
            claimed_by, claimed_at, started_at, completed_at, error,
            attempt_count, max_attempts, created_at, updated_at
        ) VALUES (
            $1, $2, $3, $4, $5,
            $6, $7, $8, $9, $10,
            $11, $12, $13, $14
        )
        ON CONFLICT (id) DO UPDATE SET
            queue_name = EXCLUDED.queue_name,
            status = EXCLUDED.status,
            priority = EXCLUDED.priority,
            payload = EXCLUDED.payload,
            updated_at = EXCLUDED.updated_at
        RETURNING *
        """
        
        let parameters: [DatabaseParameter] = [
            .text(job.id.uuidString),
            .text(overrideQueue),
            .text(job.status.rawValue),
            .int(job.priority.rawValue),
            .text(AnyCodable.encodeToJSON(job.payload)),
            .text(job.claimedBy ?? ""),
            .text(job.claimedAt?.iso8601 ?? ""),
            .text(job.startedAt?.iso8601 ?? ""),
            .text(job.completedAt?.iso8601 ?? ""),
            .text(job.error ?? ""),
            .int(job.attemptCount),
            .int(job.maxAttempts),
            .text(job.createdAt.iso8601),
            .text(job.updatedAt.iso8601)
        ]
        
        let rows = try await database.query(sql, parameters: parameters)
        guard let row = rows.first, let storedJob = Job.fromRow(row, schema: schemaName, table: tableName) else { return job }
        
        return storedJob
    }
    
    // MARK: - Claim Jobs
    
    /// Claim a job using SKIP LOCKED pattern
    public func claim(
        workerID: String,
        queueName: String = "default",
        limit: Int = 1,
        priority: PostgresJobPriority? = nil
    ) async throws -> [Job] {
        let priorityFilter = priority.map { "priority = '" + String($0.rawValue) + "'" } ?? "TRUE"
        
        let sql = """
        WITH claimed_items AS (
            SELECT * FROM " + schemaName + "." + tableName + " 
            WHERE queue_name = $1 
              AND status = 'pending'
              AND " + priorityFilter + "
            ORDER BY priority DESC, created_at ASC
            FOR UPDATE SKIP LOCKED
            LIMIT $2
        )
        UPDATE " + schemaName + "." + tableName + " 
        SET 
            status = 'claimed',
            claimed_by = $3,
            claimed_at = CURRENT_TIMESTAMP,
            attempt_count = attempt_count + 1,
            updated_at = CURRENT_TIMESTAMP
        WHERE id IN (SELECT id FROM claimed_items)
        RETURNING *
        """
        
        let parameters: [DatabaseParameter] = [
            .text(queueName),
            .int(limit),
            .text(workerID)
        ]
        
        let rows = try await database.query(sql, parameters: parameters)
        return rows.compactMap { Job.fromRow($0, schema: schemaName, table: tableName) }
    }
    
    // MARK: - Update Job Status
    
    /// Start processing a job
    public func start(_ jobID: UUID) async throws -> Job? {
        let sql = """
        UPDATE " + schemaName + "." + tableName + " 
        SET status = 'processing', started_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE id = $1 AND status IN ('claimed', 'pending')
        RETURNING *
        """
        let rows = try await database.query(sql, parameters: [.text(jobID.uuidString)])
        return rows.compactMap { Job.fromRow($0, schema: schemaName, table: tableName) }.first
    }
    
    /// Complete a job
    public func complete(_ jobID: UUID) async throws -> Job? {
        let sql = """
        UPDATE " + schemaName + "." + tableName + " 
        SET status = 'completed', completed_at = CURRENT_TIMESTAMP, 
            error = NULL, updated_at = CURRENT_TIMESTAMP
        WHERE id = $1 AND status IN ('processing', 'claimed')
        RETURNING *
        """
        let rows = try await database.query(sql, parameters: [.text(jobID.uuidString)])
        return rows.compactMap { Job.fromRow($0, schema: schemaName, table: tableName) }.first
    }
    
    /// Fail a job
    public func fail(_ jobID: UUID, error: String) async throws -> Job? {
        let nextStatus: String
        
        // Get current attempt count first
        let checkSql = "SELECT attempt_count, max_attempts FROM " + schemaName + "." + tableName + " WHERE id = $1"
        let checkRows = try await database.query(checkSql, parameters: [.text(jobID.uuidString)])
        
        if let row = checkRows.first,
           let attempts = row.int(for: "attempt_count"),
           let max = row.int(for: "max_attempts"),
           attempts >= max {
            nextStatus = "deadlettered"
        } else {
            nextStatus = "pending"
        }
        
        let sql = """
        UPDATE " + schemaName + "." + tableName + " 
        SET status = $2, error = $3, updated_at = CURRENT_TIMESTAMP
        WHERE id = $1 AND status IN ('processing', 'claimed')
        RETURNING *
        """
        let rows = try await database.query(sql, parameters: [
            .text(jobID.uuidString),
            .text(nextStatus),
            .text(error)
        ])
        return rows.compactMap { Job.fromRow($0, schema: schemaName, table: tableName) }.first
    }
    
    // MARK: - Query Jobs
    
    /// Get job by ID
    public func get(_ jobID: UUID) async throws -> Job? {
        let sql = "SELECT * FROM " + schemaName + "." + tableName + " WHERE id = $1"
        let rows = try await database.query(sql, parameters: [.text(jobID.uuidString)])
        return rows.compactMap { Job.fromRow($0, schema: schemaName, table: tableName) }.first
    }
    
    /// Get jobs by status
    public func get(byStatus status: PostgresJobStatus, queueName: String? = nil) async throws -> [Job] {
        let queueFilter = queueName.map { _ in "AND queue_name = $2" } ?? ""
        let sql = "SELECT * FROM " + schemaName + "." + tableName + " WHERE status = $1 " + queueFilter
        var parameters: [DatabaseParameter] = [.text(status.rawValue)]
        if let queueName {
            parameters.append(.text(queueName))
        }
        let rows = try await database.query(sql, parameters: parameters)
        return rows.compactMap { Job.fromRow($0, schema: schemaName, table: tableName) }
    }
    
    /// Get pending jobs count
    public func pendingCount(queueName: String? = nil) async throws -> Int {
        let queueFilter = queueName.map { _ in "AND queue_name = $2" } ?? ""
        let sql = "SELECT COUNT(*) as count FROM " + schemaName + "." + tableName + " WHERE status = 'pending' " + queueFilter
        var parameters: [DatabaseParameter] = []
        if let queueName {
            parameters = [.text("pending"), .text(queueName)]
        }
        let rows = try await database.query(sql, parameters: parameters)
        return rows.first?.int(for: "count") ?? 0
    }
    
    // MARK: - Statistics
    
    /// Get queue statistics
    public func stats(queueName: String? = nil) async throws -> PostgresJobQueueStats {
        let queueFilter = queueName.map { _ in "AND queue_name = $2" } ?? ""
        
        let pendingSql = "SELECT COUNT(*) as count FROM " + schemaName + "." + tableName + " WHERE status = 'pending' " + queueFilter
        let processingSql = "SELECT COUNT(*) as count FROM " + schemaName + "." + tableName + " WHERE status IN ('claimed', 'processing') " + queueFilter
        let failedSql = "SELECT COUNT(*) as count FROM " + schemaName + "." + tableName + " WHERE status IN ('failed', 'deadlettered') " + queueFilter
        let completedSql = "SELECT COUNT(*) as count FROM " + schemaName + "." + tableName + " WHERE status = 'completed' " + queueFilter
        
        var params: [DatabaseParameter] = []
        if let queueName {
            params = [.text(queueName)]
        }
        
        var pendingRows: [DatabaseRow]
        var processingRows: [DatabaseRow]
        var failedRows: [DatabaseRow]
        var completedRows: [DatabaseRow]
        
        async let p = params.isEmpty ? 
            try await database.query(pendingSql) : 
            try await database.query(pendingSql, parameters: params)
        async let pr = params.isEmpty ? 
            try await database.query(processingSql) : 
            try await database.query(processingSql, parameters: params)
        async let f = params.isEmpty ? 
            try await database.query(failedSql) : 
            try await database.query(failedSql, parameters: params)
        async let c = params.isEmpty ? 
            try await database.query(completedSql) : 
            try await database.query(completedSql, parameters: params)
        
        pendingRows = try await p
        processingRows = try await pr
        failedRows = try await f
        completedRows = try await c
        
        return PostgresJobQueueStats(
            pending: pendingRows.first?.int(for: "count") ?? 0,
            processing: processingRows.first?.int(for: "count") ?? 0,
            failed: failedRows.first?.int(for: "count") ?? 0,
            completed: completedRows.first?.int(for: "count") ?? 0,
            queueName: queueName
        )
    }
}

// MARK: - Statistics

public struct PostgresJobQueueStats: Sendable, Codable {
    public let pending: Int
    public let processing: Int
    public let failed: Int
    public let completed: Int
    public let queueName: String?
    
    public init(pending: Int, processing: Int, failed: Int, completed: Int, queueName: String? = nil) {
        self.pending = pending
        self.processing = processing
        self.failed = failed
        self.completed = completed
        self.queueName = queueName
    }
}

// MARK: - Row Conversion

extension PostgresJobRecord {
    public static func fromRow(_ row: DatabaseRow, schema: String, table: String) -> PostgresJobRecord? {
        guard let idString = row.string(for: "id"),
              let id = UUID(uuidString: idString) else { return nil }
        
        return PostgresJobRecord(
            id: id,
            queueName: row.string(for: "queue_name") ?? "default",
            status: PostgresJobStatus(rawValue: row.string(for: "status") ?? "pending") ?? .pending,
            priority: PostgresJobPriority(rawValue: row.int(for: "priority") ?? 2) ?? .normal,
            payload: (try? JSONDecoder().decode([String: AnyCodable].self, from: 
                (row.string(for: "payload") ?? "{}").data(using: .utf8) ?? Data())) ?? [:],
            claimedBy: row.string(for: "claimed_by"),
            claimedAt: row.date(for: "claimed_at"),
            startedAt: row.date(for: "started_at"),
            completedAt: row.date(for: "completed_at"),
            error: row.string(for: "error"),
            attemptCount: row.int(for: "attempt_count") ?? 0,
            maxAttempts: row.int(for: "max_attempts") ?? 3,
            createdAt: row.date(for: "created_at") ?? Date(),
            updatedAt: row.date(for: "updated_at") ?? Date()
        )
    }
}

// MARK: - Date Formatting

extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}

extension String {
    var date: Date? {
        ISO8601DateFormatter().date(from: self)
    }
}
