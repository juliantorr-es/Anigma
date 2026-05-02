//
//  PostgresQueuePrimitives.swift
//  DatabaseCore
//
//  PostgreSQL queue and lock primitives for work queue processing.
//

import Foundation
import AnigmaPrimitives

// MARK: - Advisory Lock Types

/// PostgreSQL advisory lock class (session vs transaction level)
public enum AdvisoryLockClass: Sendable {
    case session
    case transaction
}

/// Advisory lock identifier (64-bit class and object IDs)
public struct AdvisoryLockKey: Hashable, Sendable, Codable, Equatable {
    public let classID: Int64
    public let objectID: Int64

    public init(classID: Int64, objectID: Int64) {
        self.classID = classID
        self.objectID = objectID
    }

    public static func fromUUID(_ uuid: UUID) -> AdvisoryLockKey {
        let bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
        let classPart = bytes[0..<8].reduce(Int64(0)) { ($0 << 8) | Int64($1) }
        let objectPart = bytes[8..<16].reduce(Int64(0)) { ($0 << 8) | Int64($1) }
        return AdvisoryLockKey(classID: classPart, objectID: objectPart)
    }

    public static var anigmaNamespace: Int64 { 0x414e49474d41 }
}

/// Result of an advisory lock operation
public struct AdvisoryLockResult: Sendable, Codable, Equatable {
    public let lockKey: AdvisoryLockKey
    public let acquired: Bool
    public let error: String?

    public init(lockKey: AdvisoryLockKey, acquired: Bool, error: String? = nil) {
        self.lockKey = lockKey
        self.acquired = acquired
        self.error = error
    }
}

// MARK: - Queue Types

/// Lock mode for row-level locking
public enum LockMode: String, Sendable, Codable, CaseIterable {
    case rowShare, rowExclusive, shareUpdateExclusive
    case share, shareRowExclusive, exclusive, accessShare
}

/// Queue item status
public enum QueueItemStatus: String, Sendable, Codable, CaseIterable {
    case pending, claimed, processing, completed, failed, deadlettered

    public var isTerminal: Bool {
        [.completed, .failed, .deadlettered].contains(self)
    }
}

/// SKIP LOCKED configuration
public struct SkipLockedConfig: Sendable, Codable, Equatable {
    public let limit: Int
    public let lockMode: LockMode
    public let skipLocked: Bool
    public let forUpdate: Bool
    public let nowait: Bool
    public let orderBy: String?

    public init(
        limit: Int = 1,
        lockMode: LockMode = .rowExclusive,
        skipLocked: Bool = true,
        forUpdate: Bool = true,
        nowait: Bool = false,
        orderBy: String? = nil
    ) {
        self.limit = limit
        self.lockMode = lockMode
        self.skipLocked = skipLocked
        self.forUpdate = forUpdate
        self.nowait = nowait
        self.orderBy = orderBy
    }
}

// MARK: - Advisory Lock Manager

/// Manages PostgreSQL advisory locks for coordination
public final class PostgresAdvisoryLockManager: Sendable {
    private let database: any DatabaseExecutor

    public init(database: any DatabaseExecutor) {
        self.database = database
    }

    /// Acquire an advisory lock (non-blocking)
    public func tryLock(_ lockKey: AdvisoryLockKey, class lockClass: AdvisoryLockClass = .session) async throws -> AdvisoryLockResult {
        let function = lockClass == .session ? "pg_try_advisory_lock" : "pg_try_advisory_xact_lock"
        let sql = "SELECT " + function + "(" + String(lockKey.classID) + ", " + String(lockKey.objectID) + ") AS acquired"
        let rows = try await database.query(sql)
        let acquired = rows.first?.int(for: "acquired") ?? 0
        return AdvisoryLockResult(lockKey: lockKey, acquired: acquired == 1)
    }

    /// Acquire an advisory lock (blocking)
    public func lock(_ lockKey: AdvisoryLockKey, class lockClass: AdvisoryLockClass = .session) async throws -> AdvisoryLockResult {
        let function = lockClass == .session ? "pg_advisory_lock" : "pg_advisory_xact_lock"
        let sql = "SELECT " + function + "(" + String(lockKey.classID) + ", " + String(lockKey.objectID) + ") AS acquired"
        let rows = try await database.query(sql)
        let acquired = rows.first?.int(for: "acquired") ?? 0
        return AdvisoryLockResult(lockKey: lockKey, acquired: acquired == 1)
    }

    /// Release an advisory lock
    public func unlock(_ lockKey: AdvisoryLockKey, class lockClass: AdvisoryLockClass = .session) async throws -> Bool {
        let function = "pg_advisory_unlock"
        let sql = "SELECT " + function + "(" + String(lockKey.classID) + ", " + String(lockKey.objectID) + ") AS released"
        let rows = try await database.query(sql)
        return (rows.first?.int(for: "released") ?? 0) == 1
    }

    /// Generate lock key for a named resource
    public func lockKey(for resource: String, namespace: Int64 = AdvisoryLockKey.anigmaNamespace) -> AdvisoryLockKey {
        let hash = resource.utf8.reduce(into: 0) { $0 = $0 &* 31 &+ Int($1) }
        let objectID = Int64(truncatingIfNeeded: hash)
        return AdvisoryLockKey(classID: namespace, objectID: objectID)
    }
}

// MARK: - SKIP LOCKED Query Builder

/// Builds SKIP LOCKED queries for efficient work queue processing
public final class SkipLockedQueryBuilder {
    private var table: String
    private var selectColumns: [String] = ["*"]
    private var whereClause: String?
    private var whereParameters: [DatabaseParameter] = []
    private var orderBy: String?
    private var limitCount: Int = 1
    private var forUpdate: Bool = true
    private var skipLocked: Bool = true
    private var nowait: Bool = false
    private var joins: [String] = []

    public init(table: String) {
        self.table = table
    }

    public func select(_ columns: [String]) -> Self {
        self.selectColumns = columns
        return self
    }

    public func matching(_ clause: String, parameters: [DatabaseParameter] = []) -> Self {
        self.whereClause = clause
        self.whereParameters = parameters
        return self
    }

    public func orderBy(_ clause: String) -> Self {
        self.orderBy = clause
        return self
    }

    public func limit(_ count: Int) -> Self {
        self.limitCount = count
        return self
    }

    public func skipLocked(_ enabled: Bool = true) -> Self {
        self.skipLocked = enabled
        return self
    }

    public func nowait(_ enabled: Bool = true) -> Self {
        self.nowait = enabled
        return self
    }

    public func forUpdate(_ enabled: Bool = true) -> Self {
        self.forUpdate = enabled
        return self
    }

    public func join(_ sql: String) -> Self {
        self.joins.append(sql)
        return self
    }

    public func build() -> (sql: String, parameters: [DatabaseParameter]) {
        var sql = "SELECT " + selectColumns.joined(separator: ", ") + " FROM " + table
        for join in joins {
            sql += " " + join
        }
        if let whereClause {
            sql += " WHERE " + whereClause
        }
        if let orderBy {
            sql += " ORDER BY " + orderBy
        }
        sql += " LIMIT " + String(limitCount)

        var lockingParts: [String] = []
        if forUpdate { lockingParts.append("FOR UPDATE") }
        if skipLocked { lockingParts.append("SKIP LOCKED") }
        if nowait { lockingParts.append("NOWAIT") }
        if !lockingParts.isEmpty {
            sql += " " + lockingParts.joined(separator: " ")
        }

        return (sql, whereParameters)
    }
}

// MARK: - LISTEN/NOTIFY Event System

/// Notification channel
public struct NotificationChannel: Hashable, Sendable, Codable, Equatable {
    public let name: String
    public init(_ name: String) { self.name = name }

    public static let jobQueue = NotificationChannel("anigma.job_queue")
    public static let modelEvents = NotificationChannel("anigma.model_events")
    public static let governance = NotificationChannel("anigma.governance")
}

/// Notification payload
public struct NotificationPayload: Sendable, Codable {
    public let channel: NotificationChannel
    public let message: String
    public let data: [String: AnyCodable]?
    public let timestamp: Date

    public init(channel: NotificationChannel, message: String, data: [String: AnyCodable]? = nil) {
        self.channel = channel
        self.message = message
        self.data = data
        self.timestamp = Date()
    }
}

/// LISTEN/NOTIFY manager
public final class PostgresNotificationManager: Sendable {
    private let database: any DatabaseExecutor

    public init(database: any DatabaseExecutor) {
        self.database = database
    }

    public func notify(channel: NotificationChannel, message: String, data: [String: AnyCodable]? = nil) async throws {
        let payload = NotificationPayload(channel: channel, message: message, data: data)
        let jsonData = try JSONEncoder().encode(payload)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let escaped = jsonString.replacingOccurrences(of: "'", with: "''")
        let sql = "NOTIFY " + channel.name + ", '" + escaped + "'"
        _ = try await database.executeAsync(sql)
    }

    public func notifySimple(channel: NotificationChannel, message: String) async throws {
        let escaped = message.replacingOccurrences(of: "'", with: "''")
        let sql = "NOTIFY " + channel.name + ", '" + escaped + "'"
        _ = try await database.executeAsync(sql)
    }

    public func listen(on channel: NotificationChannel) async throws {
        let sql = "LISTEN " + channel.name
        _ = try await database.executeAsync(sql)
    }

    public func unlisten(from channel: NotificationChannel) async throws {
        let sql = "UNLISTEN " + channel.name
        _ = try await database.executeAsync(sql)
    }

    public func getListeningChannels() async throws -> [NotificationChannel] {
        let rows = try await database.query("SELECT channel FROM pg_listening_channels()")
        return rows.compactMap { row in
            row.string(for: "channel").map { NotificationChannel($0) }
        }
    }
}

// MARK: - Work Queue with SKIP LOCKED

/// Generic work queue using SKIP LOCKED pattern
public final class PostgresWorkQueue<T>: Sendable {
    private let database: any DatabaseExecutor
    private let tableName: String
    private let queueName: String

    public init(database: any DatabaseExecutor, tableName: String, queueName: String = "default") {
        self.database = database
        self.tableName = tableName
        self.queueName = queueName
    }

    /// Claim items atomically using SKIP LOCKED
    public func claim(workerID: String, limit: Int = 1) async throws -> [DatabaseRow] {
        let sql = """
        WITH selected AS (
            SELECT * FROM " + tableName + " 
            WHERE status = 'pending' AND queue_name = ?
            ORDER BY priority DESC, created_at ASC
            FOR UPDATE SKIP LOCKED LIMIT " + String(limit) + "
        )
        UPDATE " + tableName + " SET status = 'claimed', claimed_by = ?, claimed_at = CURRENT_TIMESTAMP
        FROM selected WHERE " + tableName + ".id = selected.id
        RETURNING selected.*
        """
        let rows = try await database.query(sql, parameters: [.text(queueName), .text(workerID)])
        return rows
    }

    /// Complete a queue item
    public func complete(itemID: String) async throws {
        let sql = "UPDATE " + tableName + " SET status = 'completed', updated_at = CURRENT_TIMESTAMP WHERE id = ? AND status IN ('claimed', 'processing')"
        _ = try await database.executeAsync(sql, parameters: [.text(itemID)])
    }

    /// Fail a queue item
    public func fail(itemID: String, error: String) async throws {
        let sql = "UPDATE " + tableName + " SET status = 'failed', error = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
        _ = try await database.executeAsync(sql, parameters: [.text(error), .text(itemID)])
    }
}

// MARK: - Leader Election with Advisory Locks

/// Leader election using advisory locks
public final class PostgresLeaderElector: Sendable {
    private let database: any DatabaseExecutor
    private let lockKey: AdvisoryLockKey
    private let lockManager: PostgresAdvisoryLockManager

    public init(database: any DatabaseExecutor, lockKey: AdvisoryLockKey) {
        self.database = database
        self.lockKey = lockKey
        self.lockManager = PostgresAdvisoryLockManager(database: database)
    }

    public func isLeader() async throws -> Bool {
        let result = try await lockManager.tryLock(lockKey, class: .session)
        return result.acquired
    }

    public func becomeLeader() async throws -> Bool {
        _ = try await lockManager.unlock(lockKey, class: .session)
        let result = try await lockManager.tryLock(lockKey, class: .session)
        return result.acquired
    }

    public func resign() async throws {
        _ = try await lockManager.unlock(lockKey, class: .session)
    }
}

// MARK: - Errors

public enum PostgresQueueError: Error, CustomStringConvertible, Sendable {
    case lockNotAcquired, lockAlreadyHeld, queueEmpty
    case itemAlreadyClaimed(String), maxRetriesExceeded(String)
    case notificationFailed(String, String), listenFailed(String)

    public var description: String {
        switch self {
        case .lockNotAcquired: return "Failed to acquire advisory lock"
        case .lockAlreadyHeld: return "Lock already held by another process"
        case .queueEmpty: return "Queue is empty"
        case let .itemAlreadyClaimed(id): return "Item '" + id + "' already claimed"
        case let .maxRetriesExceeded(id): return "Item '" + id + "' exceeded max retries"
        case let .notificationFailed(ch, msg): return "Notify failed on '" + ch + "': " + msg
        case let .listenFailed(ch): return "Listen failed on '" + ch + "'"
        }
    }
}
