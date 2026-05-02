import Foundation

// MARK: - Extensions for Backward Compatibility

extension CoordinatorLease {
    public var isValid: Bool {
        return expiresAt > Timestamp(Date().timeIntervalSince1970)
    }
}

extension WorkerPresence {
    public var isStale: Bool {
        return lastSeen < Timestamp(Date().timeIntervalSince1970) - 30  // 30 seconds stale threshold
    }
}

extension EventEnvelope {
    public var cursor: EventCursor {
        return EventCursor(position: 0, streamId: streamId)
    }
}

// MARK: - JobStatus
public enum JobStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case claimed
    case completed
    case failed
    case deadLettered
    case cancelled
}

public enum MessagingError: Error {
    case invalidStreamId
    case leaseNotFound
    case leaseAlreadyHeld
    case leaseExpired
    case jobNotFound
    case insertFailed
    case queryFailed
}

public struct MessagingDatabaseSchema {
    public static let ephemeralStreamsTable = "ephemeral_streams"
    public static let workQueueTable = "work_queue"
    public static let eventLogTable = "event_log"
    public static let streamLeasesTable = "stream_leases"
}

// MARK: - Core Types

public protocol EventStreamId: Hashable, Codable, Sendable {
    var projectId: String { get }
    var topic: String { get }
    var partitionKey: String? { get }
    var displayName: String? { get }
}

public struct AnigmaEventStreamId: EventStreamId, Codable, Hashable, Sendable {
    public let projectId: String
    public let topic: String
    public let partitionKey: String?
    public let displayName: String?

    public init(
        projectId: String,
        topic: String,
        partitionKey: String? = nil,
        displayName: String? = nil
    ) {
        self.projectId = projectId
        self.topic = topic
        self.partitionKey = partitionKey
        self.displayName = displayName
    }
}

public struct EventCursor: Hashable, Codable, Sendable {
    public let position: UInt64
    public let streamId: AnigmaEventStreamId
    public let checkpointId: UUID?

    public init(
        position: UInt64,
        streamId: AnigmaEventStreamId,
        checkpointId: UUID? = nil
    ) {
        self.position = position
        self.streamId = streamId
        self.checkpointId = checkpointId
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(UInt64.self, forKey: .position)
        streamId = try container.decode(AnigmaEventStreamId.self, forKey: .streamId)
        checkpointId = try container.decodeIfPresent(UUID.self, forKey: .checkpointId)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(streamId, forKey: .streamId)
        try container.encodeIfPresent(checkpointId, forKey: .checkpointId)
    }

    private enum CodingKeys: String, CodingKey {
        case position, streamId, checkpointId
    }
}

// MARK: - Event Types

public struct EventEnvelope: Codable, Sendable {
    public let streamId: AnigmaEventStreamId
    public let payload: Data
    public let metadata: [String: String]

    public init(
        streamId: AnigmaEventStreamId,
        payload: Data,
        metadata: [String: String] = [:]
    ) {
        self.streamId = streamId
        self.payload = payload
        self.metadata = metadata
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streamId = try container.decode(AnigmaEventStreamId.self, forKey: .streamId)
        payload = try container.decode(Data.self, forKey: .payload)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(streamId, forKey: .streamId)
        try container.encode(payload, forKey: .payload)
        try container.encode(metadata, forKey: .metadata)
    }

    private enum CodingKeys: String, CodingKey {
        case streamId, payload, metadata
    }
}

public struct EventCheckpoint: Codable, Sendable {
    public let checkpointId: UUID
    public let streamId: AnigmaEventStreamId
    public let position: UInt64
    public let createdAt: Timestamp

    public init(
        checkpointId: UUID,
        streamId: AnigmaEventStreamId,
        position: UInt64,
        createdAt: Timestamp
    ) {
        self.checkpointId = checkpointId
        self.streamId = streamId
        self.position = position
        self.createdAt = createdAt
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checkpointId = try container.decode(UUID.self, forKey: .checkpointId)
        streamId = try container.decode(AnigmaEventStreamId.self, forKey: .streamId)
        position = try container.decode(UInt64.self, forKey: .position)
        createdAt = try container.decode(Timestamp.self, forKey: .createdAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(checkpointId, forKey: .checkpointId)
        try container.encode(streamId, forKey: .streamId)
        try container.encode(position, forKey: .position)
        try container.encode(createdAt, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case checkpointId, streamId, position, createdAt
    }
}

public struct EventAppendReceipt: Codable, Sendable {
    public let position: UInt64
    public let streamId: AnigmaEventStreamId
    public let timestamp: Timestamp
    public let eventId: UUID

    public init(
        position: UInt64,
        streamId: AnigmaEventStreamId,
        timestamp: Timestamp,
        eventId: UUID
    ) {
        self.position = position
        self.streamId = streamId
        self.timestamp = timestamp
        self.eventId = eventId
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(UInt64.self, forKey: .position)
        streamId = try container.decode(AnigmaEventStreamId.self, forKey: .streamId)
        timestamp = try container.decode(Timestamp.self, forKey: .timestamp)
        eventId = try container.decode(UUID.self, forKey: .eventId)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(streamId, forKey: .streamId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(eventId, forKey: .eventId)
    }

    private enum CodingKeys: String, CodingKey {
        case position, streamId, timestamp, eventId
    }
}

public struct StreamMetadata: Codable, Sendable {
    public var streamId: AnigmaEventStreamId
    public var eventCount: UInt64
    public var oldestCursor: EventCursor?

    public init(
        streamId: AnigmaEventStreamId,
        eventCount: UInt64 = 0,
        oldestCursor: EventCursor? = nil
    ) {
        self.streamId = streamId
        self.eventCount = eventCount
        self.oldestCursor = oldestCursor
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streamId = try container.decode(AnigmaEventStreamId.self, forKey: .streamId)
        eventCount = try container.decode(UInt64.self, forKey: .eventCount)
        oldestCursor = try container.decodeIfPresent(EventCursor.self, forKey: .oldestCursor)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(streamId, forKey: .streamId)
        try container.encode(eventCount, forKey: .eventCount)
        try container.encodeIfPresent(oldestCursor, forKey: .oldestCursor)
    }

    private enum CodingKeys: String, CodingKey {
        case streamId, eventCount, oldestCursor
    }
}

// MARK: - Work Queue Types

public struct WorkQueueEnvelope: Codable, Sendable {
    public let jobId: UUID
    public let payload: Data
    public let metadata: [String: String]
    public let retryPolicy: RetryPolicy
    public let createdAt: Timestamp

    public init(
        jobId: UUID,
        payload: Data,
        metadata: [String: String] = [:],
        retryPolicy: RetryPolicy,
        createdAt: Timestamp
    ) {
        self.jobId = jobId
        self.payload = payload
        self.metadata = metadata
        self.retryPolicy = retryPolicy
        self.createdAt = createdAt
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try container.decode(UUID.self, forKey: .jobId)
        payload = try container.decode(Data.self, forKey: .payload)
        metadata = try container.decode([String: String].self, forKey: .metadata)
        retryPolicy = try container.decode(RetryPolicy.self, forKey: .retryPolicy)
        createdAt = try container.decode(Timestamp.self, forKey: .createdAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jobId, forKey: .jobId)
        try container.encode(payload, forKey: .payload)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(retryPolicy, forKey: .retryPolicy)
        try container.encode(createdAt, forKey: .createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case jobId, payload, metadata, retryPolicy, createdAt
    }
}

public struct JobLease: Codable, Sendable {
    public let leaseId: UUID
    public let jobId: UUID
    public let workerId: String
    public let claimedAt: Timestamp
    public let expiresAt: Timestamp

    public init(
        leaseId: UUID,
        jobId: UUID,
        workerId: String,
        claimedAt: Timestamp,
        expiresAt: Timestamp
    ) {
        self.leaseId = leaseId
        self.jobId = jobId
        self.workerId = workerId
        self.claimedAt = claimedAt
        self.expiresAt = expiresAt
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leaseId = try container.decode(UUID.self, forKey: .leaseId)
        jobId = try container.decode(UUID.self, forKey: .jobId)
        workerId = try container.decode(String.self, forKey: .workerId)
        claimedAt = try container.decode(Timestamp.self, forKey: .claimedAt)
        expiresAt = try container.decode(Timestamp.self, forKey: .expiresAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leaseId, forKey: .leaseId)
        try container.encode(jobId, forKey: .jobId)
        try container.encode(workerId, forKey: .workerId)
        try container.encode(claimedAt, forKey: .claimedAt)
        try container.encode(expiresAt, forKey: .expiresAt)
    }

    private enum CodingKeys: String, CodingKey {
        case leaseId, jobId, workerId, claimedAt, expiresAt
    }
}

public struct JobOperationReceipt: Codable, Sendable {
    public let jobId: UUID
    public let leaseId: UUID
    public let operation: String
    public let status: String
    public let timestamp: Timestamp
    public let metadata: [String: String]

    public init(
        jobId: UUID,
        leaseId: UUID,
        operation: String,
        status: String,
        timestamp: Timestamp,
        metadata: [String: String] = [:]
    ) {
        self.jobId = jobId
        self.leaseId = leaseId
        self.operation = operation
        self.status = status
        self.timestamp = timestamp
        self.metadata = metadata
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try container.decode(UUID.self, forKey: .jobId)
        leaseId = try container.decode(UUID.self, forKey: .leaseId)
        operation = try container.decode(String.self, forKey: .operation)
        status = try container.decode(String.self, forKey: .status)
        timestamp = try container.decode(Timestamp.self, forKey: .timestamp)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jobId, forKey: .jobId)
        try container.encode(leaseId, forKey: .leaseId)
        try container.encode(operation, forKey: .operation)
        try container.encode(status, forKey: .status)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(metadata, forKey: .metadata)
    }

    private enum CodingKeys: String, CodingKey {
        case jobId, leaseId, operation, status, timestamp, metadata
    }
}

public struct DeadLetterRecord: Codable, Sendable {
    public let jobId: UUID
    public let reason: String
    public let failedAt: Timestamp
    public let attemptCount: Int
    public let lastWorkerId: String

    public init(
        jobId: UUID,
        reason: String,
        failedAt: Timestamp,
        attemptCount: Int,
        lastWorkerId: String
    ) {
        self.jobId = jobId
        self.reason = reason
        self.failedAt = failedAt
        self.attemptCount = attemptCount
        self.lastWorkerId = lastWorkerId
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try container.decode(UUID.self, forKey: .jobId)
        reason = try container.decode(String.self, forKey: .reason)
        failedAt = try container.decode(Timestamp.self, forKey: .failedAt)
        attemptCount = try container.decode(Int.self, forKey: .attemptCount)
        lastWorkerId = try container.decode(String.self, forKey: .lastWorkerId)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jobId, forKey: .jobId)
        try container.encode(reason, forKey: .reason)
        try container.encode(failedAt, forKey: .failedAt)
        try container.encode(attemptCount, forKey: .attemptCount)
        try container.encode(lastWorkerId, forKey: .lastWorkerId)
    }

    private enum CodingKeys: String, CodingKey {
        case jobId, reason, failedAt, attemptCount, lastWorkerId
    }
}

public struct CoordinatorLease: Codable, Sendable {
    public let leaseId: UUID
    public let key: String
    public let holder: String
    public let expiresAt: Timestamp

    public init(
        leaseId: UUID,
        key: String,
        holder: String,
        expiresAt: Timestamp
    ) {
        self.leaseId = leaseId
        self.key = key
        self.holder = holder
        self.expiresAt = expiresAt
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leaseId = try container.decode(UUID.self, forKey: .leaseId)
        key = try container.decode(String.self, forKey: .key)
        holder = try container.decode(String.self, forKey: .holder)
        expiresAt = try container.decode(Timestamp.self, forKey: .expiresAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leaseId, forKey: .leaseId)
        try container.encode(key, forKey: .key)
        try container.encode(holder, forKey: .holder)
        try container.encode(expiresAt, forKey: .expiresAt)
    }

    private enum CodingKeys: String, CodingKey {
        case leaseId, key, holder, expiresAt
    }
}

public struct CoordinationReceipt: Codable, Sendable {
    public let leaseId: UUID
    public let operation: String
    public let timestamp: Timestamp
    public let signature: String

    public init(
        leaseId: UUID,
        operation: String,
        timestamp: Timestamp,
        signature: String
    ) {
        self.leaseId = leaseId
        self.operation = operation
        self.timestamp = timestamp
        self.signature = signature
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leaseId = try container.decode(UUID.self, forKey: .leaseId)
        operation = try container.decode(String.self, forKey: .operation)
        timestamp = try container.decode(Timestamp.self, forKey: .timestamp)
        signature = try container.decode(String.self, forKey: .signature)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leaseId, forKey: .leaseId)
        try container.encode(operation, forKey: .operation)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(signature, forKey: .signature)
    }

    private enum CodingKeys: String, CodingKey {
        case leaseId, operation, timestamp, signature
    }
}

public struct WorkerPresence: Codable, Sendable {
    public let workerId: WorkerId
    public let status: PresenceStatus
    public let lastSeen: Timestamp

    public init(
        workerId: WorkerId,
        status: PresenceStatus,
        lastSeen: Timestamp
    ) {
        self.workerId = workerId
        self.status = status
        self.lastSeen = lastSeen
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workerId = try container.decode(WorkerId.self, forKey: .workerId)
        status = try container.decode(PresenceStatus.self, forKey: .status)
        lastSeen = try container.decode(Timestamp.self, forKey: .lastSeen)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workerId, forKey: .workerId)
        try container.encode(status, forKey: .status)
        try container.encode(lastSeen, forKey: .lastSeen)
    }

    private enum CodingKeys: String, CodingKey {
        case workerId, status, lastSeen
    }
}

public struct RateLimitDecision: Codable, Sendable {
    public let allowed: Bool
    public let remainingTokens: Int
    public let retryAfterMs: Int?
    public let policy: RateLimitPolicy

    public init(
        allowed: Bool,
        remainingTokens: Int,
        retryAfterMs: Int? = nil,
        policy: RateLimitPolicy
    ) {
        self.allowed = allowed
        self.remainingTokens = remainingTokens
        self.retryAfterMs = retryAfterMs
        self.policy = policy
    }

    // Manual Codable
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allowed = try container.decode(Bool.self, forKey: .allowed)
        remainingTokens = try container.decode(Int.self, forKey: .remainingTokens)
        retryAfterMs = try container.decodeIfPresent(Int.self, forKey: .retryAfterMs)
        policy = try container.decode(RateLimitPolicy.self, forKey: .policy)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(allowed, forKey: .allowed)
        try container.encode(remainingTokens, forKey: .remainingTokens)
        try container.encodeIfPresent(retryAfterMs, forKey: .retryAfterMs)
        try container.encode(policy, forKey: .policy)
    }

    private enum CodingKeys: String, CodingKey {
        case allowed, remainingTokens, retryAfterMs, policy
    }
}

// MARK: - Protocols

public protocol MessagingBackedScheduler: Sendable {
    func start() async throws
    func stop() async throws
    func schedule(_ task: @escaping @Sendable () async -> Void, after delay: Double) async -> UniqueIdentifier
    func cancel(_ taskId: UniqueIdentifier) async
}

public protocol EventStreamPersistence: Sendable {
    associatedtype StreamId: EventStreamId
    associatedtype Cursor: Hashable & Codable & Sendable
    
    func append(_ event: EventEnvelope, toStream streamId: StreamId) async throws -> EventAppendReceipt
    func subscribe(to streamId: StreamId, from cursor: Cursor?) -> AsyncThrowingStream<EventEnvelope, Error>
    func replay(streamId: StreamId, from startCursor: Cursor?, to endCursor: Cursor?) async throws -> [EventEnvelope]
    func getStreamMetadata(streamId: StreamId) async throws -> StreamMetadata
}

public protocol WorkQueuePersistence: Sendable {
    associatedtype JobId: Hashable & Codable & Sendable
    associatedtype LeaseId: Hashable & Codable & Sendable
    
    func enqueue(_ job: WorkQueueEnvelope) async throws -> JobOperationReceipt
    func dequeue(workerId: String, limit: Int) async throws -> [WorkQueueEnvelope]
    func lease(jobId: JobId, workerId: String, ttlSeconds: Int) async throws -> JobLease
    func complete(jobId: JobId, leaseId: LeaseId) async throws -> JobOperationReceipt
    func fail(jobId: JobId, leaseId: LeaseId, reason: String) async throws -> JobOperationReceipt
    func nack(jobId: JobId, leaseId: LeaseId) async throws -> JobOperationReceipt
    func getJobStatus(jobId: JobId) async throws -> JobStatus
    func recoverExpiredLeases() async throws -> Int
}

public protocol CoordinatorService: Sendable {
    associatedtype LeaseId: Hashable & Codable & Sendable
    
    func acquireLease(key: String, holder: WorkerId, ttlSeconds: Int) async throws -> CoordinatorLease
    func refreshLease(leaseId: LeaseId, ttlSeconds: Int) async throws -> CoordinationReceipt
    func releaseLease(leaseId: LeaseId) async throws -> CoordinationReceipt
    func heartbeat(workerId: WorkerId, ttlSeconds: Int) async throws -> WorkerPresence
    func checkPresence(workerId: WorkerId) async throws -> PresenceStatus
}

public protocol RateLimiter {
    func checkLimit(clientId: String, policy: RateLimitPolicy) async throws -> RateLimitDecision
}

// MARK: - Supporting Types

public typealias WorkerId = String
public typealias Timestamp = Double
public typealias UniqueIdentifier = UUID

// Type aliases for convenience
public typealias WorkQueue = any WorkQueuePersistence
public typealias EphemeralCoordinator = any CoordinatorService

public struct RetryPolicy: Codable, Sendable {
    public let maxAttempts: Int
    public let backoffSeconds: [Double]
    
    public init(maxAttempts: Int, backoffSeconds: [Double]) {
        self.maxAttempts = maxAttempts
        self.backoffSeconds = backoffSeconds
    }
}

public struct RateLimitPolicy: Codable, Sendable {
    public let maxTokens: Int
    public let windowSeconds: Double
    
    public init(maxTokens: Int, windowSeconds: Double) {
        self.maxTokens = maxTokens
        self.windowSeconds = windowSeconds
    }
}

public enum PresenceStatus: String, Codable, Sendable {
    case alive
    case stale
    case unknown
}