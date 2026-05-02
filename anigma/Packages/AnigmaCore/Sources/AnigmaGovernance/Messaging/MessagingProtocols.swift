import Foundation
import MessagingContracts

public struct EventProvenance: Codable, Sendable {
    public let source: String
    public let sourceCapabilityId: String

    public init(source: String, sourceCapabilityId: String) {
        self.source = source
        self.sourceCapabilityId = sourceCapabilityId
    }
}

public typealias AnigmaEventCursor = EventCursor

public struct StreamRetentionPolicy: Codable, Sendable {
    public let maxAgeSeconds: Int
    public let maxSizeBytes: Int

    public init(maxAgeSeconds: Int = 86400, maxSizeBytes: Int = 1024 * 1024 * 1024) {
        self.maxAgeSeconds = maxAgeSeconds
        self.maxSizeBytes = maxSizeBytes
    }
}

public enum JobPriority: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical
}

public struct StreamMetadata: Codable, Sendable {
    public var streamId: AnigmaEventStreamId
    public var eventCount: UInt64
    public var oldestCursor: EventCursor?
    public var newestCursor: EventCursor?
    public var retentionPolicy: StreamRetentionPolicy

    public init(
        streamId: AnigmaEventStreamId,
        eventCount: UInt64 = 0,
        oldestCursor: EventCursor? = nil,
        newestCursor: EventCursor? = nil,
        retentionPolicy: StreamRetentionPolicy = StreamRetentionPolicy()
    ) {
        self.streamId = streamId
        self.eventCount = eventCount
        self.oldestCursor = oldestCursor
        self.newestCursor = newestCursor
        self.retentionPolicy = retentionPolicy
    }
}

/// Persistence layer for event streams with Swift 6 concurrency support
public protocol EventStreamPersistence: Sendable {
    associatedtype StreamId: EventStreamId & Sendable
    associatedtype Cursor: Hashable & Codable & Sendable

    /// Append an event to a stream
    func append(_ event: EventEnvelope, toStream streamId: StreamId) async throws -> EventAppendReceipt

    /// Subscribe to a stream from a given cursor position
    /// - Returns: An async stream of events
    func subscribe(to streamId: StreamId, from cursor: Cursor?) -> AsyncThrowingStream<EventEnvelope, Error>

    /// Replay events from a stream within a cursor range
    func replay(streamId: StreamId, from startCursor: Cursor?, to endCursor: Cursor?) async throws -> [EventEnvelope]

    /// Get metadata for a stream
    func getStreamMetadata(streamId: StreamId) async throws -> StreamMetadata
}

/// Persistence layer for work queue operations with Swift 6 concurrency support
public protocol WorkQueuePersistence: Sendable {
    func enqueue(_ job: WorkQueueEnvelope) async throws -> JobOperationReceipt
    func dequeue(workerId: String, limit: Int) async throws -> [WorkQueueEnvelope]
    func lease(jobId: UUID, workerId: String, ttlSeconds: Int) async throws -> JobLease
    func complete(jobId: UUID, leaseId: UUID) async throws -> JobOperationReceipt
    func fail(jobId: UUID, leaseId: UUID, reason: String) async throws -> JobOperationReceipt
    func nack(jobId: UUID, leaseId: UUID) async throws -> JobOperationReceipt
    func getJobStatus(jobId: UUID) async throws -> JobStatus
    func recoverExpiredLeases() async throws -> Int
}

/// Service for distributed coordination with Swift 6 concurrency support
public protocol CoordinatorService: Sendable {
    func acquireLease(key: String, holder: String, ttlSeconds: Int) async throws -> CoordinatorLease
    func refreshLease(leaseId: UUID, ttlSeconds: Int) async throws -> CoordinationReceipt
    func releaseLease(leaseId: UUID) async throws -> CoordinationReceipt
    func heartbeat(workerId: String, ttlSeconds: Int) async throws -> WorkerPresence
    func checkPresence(workerId: String) async throws -> PresenceStatus
}