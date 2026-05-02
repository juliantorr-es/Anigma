//
//  JobQueue.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation
import FoundationContracts
import EvidenceContracts
import GovernanceContracts

/// Status for a queued contract execution job.
public enum RunContractJobStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case running
    case completed
    case failed
    case quarantined

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .quarantined:
            return true
        case .pending, .running:
            return false
        }
    }
}

/// Payload describing a contract run request.
public struct RunContractJobPayload: Codable, Sendable {
    public let contractID: ContractID
    public let sessionID: String
    public let inputArtifactIDs: [String]
    public let inputKey: String

    public init(contractID: ContractID, sessionID: String, inputArtifactIDs: [String], inputKey: String) {
        self.contractID = contractID
        self.sessionID = sessionID
        self.inputArtifactIDs = inputArtifactIDs
        self.inputKey = inputKey
    }

    enum CodingKeys: String, CodingKey {
        case contractID
        case sessionID
        case inputArtifactIDs
        case inputKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.contractID = try container.decode(ContractID.self, forKey: .contractID)
        self.sessionID = try container.decode(String.self, forKey: .sessionID)
        self.inputArtifactIDs = try container.decode([String].self, forKey: .inputArtifactIDs)
        self.inputKey = try container.decodeIfPresent(String.self, forKey: .inputKey) ?? ""
    }
}

/// Persisted job record for a contract execution.
public struct RunContractJobRecord: Codable, Sendable, Identifiable {
    public let id: String
    public let payload: RunContractJobPayload
    public let queueKey: String
    public var status: RunContractJobStatus
    public var attempts: Int
    public var error: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        payload: RunContractJobPayload,
        queueKey: String,
        status: RunContractJobStatus = .pending,
        attempts: Int = 0,
        error: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.payload = payload
        self.queueKey = queueKey
        self.status = status
        self.attempts = attempts
        self.error = error
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// PostgreSQL-backed queue for contract execution jobs.
public actor ContractJobQueue {
    private let database: any DatabaseExecutor
    private let idGenerator: () -> String
    private let now: () -> Date

    public init(
        database: any DatabaseExecutor,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        now: @escaping () -> Date = { Date() }
    ) async throws {
        self.database = database
        self.idGenerator = idGenerator
        self.now = now
        try await database.open()
        try await MigrationRegistry.applyMigrations(using: database)
    }

    /// Enqueue a job for execution.
    @discardableResult
    public func enqueue(_ payload: RunContractJobPayload) async throws -> RunContractJobRecord {
        let id = idGenerator()
        let created = now()
        let record = RunContractJobRecord(
            id: id,
            payload: payload,
            queueKey: id,
            status: .pending,
            attempts: 0,
            error: nil,
            createdAt: created,
            updatedAt: created
        )
        try await persist(record)
        return record
    }

    /// Enqueue a job idempotently by queueKey.
    @discardableResult
    public func enqueueIdempotent(_ payload: RunContractJobPayload, queueKey: String) async throws -> RunContractJobRecord {
        let id = idGenerator()
        let created = now()
        let record = RunContractJobRecord(
            id: id,
            payload: payload,
            queueKey: queueKey,
            status: .pending,
            attempts: 0,
            error: nil,
            createdAt: created,
            updatedAt: created
        )

        let inserted = try await persist(record, allowIgnore: true)
        if inserted {
            return record
        }

        if let existing = try await fetchByQueueKey(queueKey) {
            return existing
        }
        // Fallback: return record even if not found (should not happen)
        return record
    }

    /// Dequeue the next ready job for a session and mark it running.
    public func dequeueNextReady(sessionID: String) async throws -> RunContractJobRecord? {
        let rows = try await database.query(
            """
            SELECT id, queue_key, payload, status, attempts, error, created_at, updated_at
            FROM contract_jobs
            WHERE status = 'pending' AND session_id = ?
            ORDER BY created_at ASC
            LIMIT 1
            """,
            parameters: [.text(sessionID)]
        )

        guard let row = rows.first,
              let record = try decode(row: row)
        else { return nil }

        var running = record
        running.status = .running
        running.attempts += 1
        running.updatedAt = now()

        try await update(record: running)
        return running
    }

    /// Mark a job as completed.
    public func markCompleted(_ id: String) async throws -> RunContractJobRecord? {
        guard var record = try await fetch(id: id) else { return nil }
        record.status = .completed
        record.updatedAt = now()
        try await update(record: record)
        return record
    }

    /// Mark a job as failed or quarantined. If `allowRetry` is true, it returns the job to pending.
    public func markFailed(_ id: String, error: String, allowRetry: Bool) async throws -> RunContractJobRecord? {
        guard var record = try await fetch(id: id) else { return nil }
        record.error = error
        record.status = allowRetry ? .pending : .failed
        record.updatedAt = now()
        try await update(record: record)
        return record
    }

    /// Mark a job as quarantined.
    public func markQuarantined(_ id: String, reason: String) async throws -> RunContractJobRecord? {
        guard var record = try await fetch(id: id) else { return nil }
        record.error = reason
        record.status = .quarantined
        record.updatedAt = now()
        try await update(record: record)
        return record
    }

    /// Fetch all jobs for a session.
    public func fetchJobs(sessionID: String) async throws -> [RunContractJobRecord] {
        let rows = try await database.query(
            """
            SELECT id, queue_key, payload, status, attempts, error, created_at, updated_at
            FROM contract_jobs
            WHERE session_id = ?
            """,
            parameters: [.text(sessionID)]
        )
        return try rows.compactMap { try decode(row: $0) }
    }

    /// Fetch a job by identifier.
    public func fetch(id: String) async throws -> RunContractJobRecord? {
        let rows = try await database.query(
            """
            SELECT id, queue_key, payload, status, attempts, error, created_at, updated_at
            FROM contract_jobs
            WHERE id = ?
            """,
            parameters: [.text(id)]
        )
        guard let row = rows.first else { return nil }
        return try decode(row: row)
    }

    /// Count pending jobs for a session.
    public func pendingCount(sessionID: String) async throws -> Int {
        let rows = try await database.query(
            """
            SELECT COUNT(*) as count
            FROM contract_jobs
            WHERE status = 'pending' AND session_id = ?
            """,
            parameters: [.text(sessionID)]
        )
        return rows.first?.int(for: "count") ?? 0
    }

    private func persist(_ record: RunContractJobRecord) async throws {
        _ = try await persist(record, allowIgnore: false)
    }

    @discardableResult
    private func persist(_ record: RunContractJobRecord, allowIgnore: Bool) async throws -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(record.payload)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"

        let sql = """
            INSERT \(allowIgnore ? "OR IGNORE" : "") INTO contract_jobs (id, contract_id, session_id, queue_key, payload, status, attempts, error, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

        let changes = try await database.executeAsync(
            """
            \(sql)
            """,
            parameters: [
                .text(record.id),
                .text(record.payload.contractID.name),
                .text(record.payload.sessionID),
                .text(record.queueKey),
                .text(payloadString),
                .text(record.status.rawValue),
                .int(record.attempts),
                record.error.map(DatabaseParameter.text) ?? .null,
                .double(record.createdAt.timeIntervalSince1970),
                .double(record.updatedAt.timeIntervalSince1970)
            ]
        )
        return changes > 0
    }

    private func update(record: RunContractJobRecord) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(record.payload)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "{}"

        _ = try await database.executeAsync(
            """
            UPDATE contract_jobs
            SET payload = ?, status = ?, attempts = ?, error = ?, updated_at = ?
            WHERE id = ?
            """,
            parameters: [
                .text(payloadString),
                .text(record.status.rawValue),
                .int(record.attempts),
                record.error.map(DatabaseParameter.text) ?? .null,
                .double(record.updatedAt.timeIntervalSince1970),
                .text(record.id)
            ]
        )
    }

    private func fetchByQueueKey(_ queueKey: String) async throws -> RunContractJobRecord? {
        let rows = try await database.query(
            """
            SELECT id, queue_key, payload, status, attempts, error, created_at, updated_at
            FROM contract_jobs
            WHERE queue_key = ?
            LIMIT 1
            """,
            parameters: [.text(queueKey)]
        )
        guard let row = rows.first else { return nil }
        return try decode(row: row)
    }

    private func decode(row: DatabaseRow) throws -> RunContractJobRecord? {
        guard
            let id = row.string(for: "id"),
            let queueKey = row.string(for: "queue_key"),
            let payloadText = row.string(for: "payload"),
            let statusRaw = row.string(for: "status"),
            let status = RunContractJobStatus(rawValue: statusRaw),
            let attempts = row.int(for: "attempts"),
            let createdAtDouble = row.value(for: "created_at")?.doubleValue,
            let updatedAtDouble = row.value(for: "updated_at")?.doubleValue
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payloadData = Data(payloadText.utf8)
        let payload = try decoder.decode(RunContractJobPayload.self, from: payloadData)

        let createdAt = Date(timeIntervalSince1970: createdAtDouble)
        let updatedAt = Date(timeIntervalSince1970: updatedAtDouble)

        let record = RunContractJobRecord(
            id: id,
            payload: payload,
            queueKey: queueKey,
            status: status,
            attempts: attempts,
            error: row.string(for: "error"),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        return record
    }
}
