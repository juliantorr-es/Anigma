import Foundation
import MessagingContracts

/// In-memory implementation of EventStreamPersistence for test usage only.
/// 
/// SAFETY: This class is only used in test contexts (InMemoryImplementations).
/// It is NOT used in production. The mutable state (events, checkpoints) is confined
/// to individual test scenarios where there is no concurrent access.
/// 
/// @unchecked Sendable is safe here because:
/// 1. Test-only: This implementation is never shared across tasks/concurrent contexts in production
/// 2. Single-threaded tests: Test scenarios that use this are single-threaded
/// 3. No shared instances: Each test creates its own instance
///
/// If this ever needs to be used in concurrent test contexts, convert to actor or add
/// proper synchronization.
public class InMemoryEventLog: @unchecked Sendable, EventStreamPersistence {
    public typealias StreamId = AnigmaEventStreamId
    public typealias Cursor = EventCursor

    private var events: [String: [EventEnvelope]] = [:]
    private var checkpoints: [UUID: EventCheckpoint] = [:]

    public init() {}

    public func append(_ event: EventEnvelope, toStream streamId: AnigmaEventStreamId) async throws -> EventAppendReceipt {
        let streamKey = self.streamKey(streamId)
        var streamEvents = events[streamKey] ?? []
        
        // Append event
        streamEvents.append(event)
        events[streamKey] = streamEvents
        
        // Create receipt
        let receipt = EventAppendReceipt(
            position: UInt64(streamEvents.count),
            streamId: streamId,
            timestamp: Timestamp(Date().timeIntervalSince1970),
            eventId: UUID()
        )
        
        return receipt
    }

    public func subscribe(to streamId: AnigmaEventStreamId, from cursor: EventCursor?) -> AsyncThrowingStream<EventEnvelope, Error> {
        let streamKey = self.streamKey(streamId)
        let streamEvents = events[streamKey] ?? []
        
        return AsyncThrowingStream { continuation in
            for event in streamEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    public func replay(streamId: AnigmaEventStreamId, from startCursor: EventCursor?, to endCursor: EventCursor?) async throws -> [EventEnvelope] {
        let streamKey = self.streamKey(streamId)
        let streamEvents = self.getEvents(for: streamKey)
        
        let startPos = startCursor?.position ?? 0
        let endPos = endCursor?.position ?? UInt64(streamEvents.count)
        
        return Array(streamEvents[Int(startPos)..<Int(endPos)])
    }

    public func getStreamMetadata(streamId: AnigmaEventStreamId) async throws -> StreamMetadata {
        let streamKey = self.streamKey(streamId)
        let stats = self.getStreamStats(for: streamKey)
        
        return StreamMetadata(
            streamId: streamId,
            eventCount: stats.count,
            oldestCursor: stats.oldest,
            newestCursor: stats.newest,
            retentionPolicy: StreamRetentionPolicy()
        )
    }

    public func saveCheckpoint(_ checkpoint: EventCheckpoint) async throws {
        checkpoints[checkpoint.checkpointId] = checkpoint
    }

    public func getCheckpoint(_ checkpointId: UUID) async throws -> EventCheckpoint? {
        return checkpoints[checkpointId]
    }

    // MARK: - Private Helpers

    private func streamKey(_ streamId: AnigmaEventStreamId) -> String {
        return "stream:{\(streamId.projectId)}:{\(streamId.topic)}:{\(streamId.partitionKey ?? "default")}"
    }

    private func getEvents(for key: String) -> [EventEnvelope] {
        return events[key] ?? []
    }

    private func getStreamStats(for key: String) -> (count: UInt64, oldest: EventCursor?, newest: EventCursor?) {
        let streamEvents = events[key] ?? []
        
        guard !streamEvents.isEmpty else {
            return (0, nil, nil)
        }
        
        return (
            UInt64(streamEvents.count),
            EventCursor(position: 0, streamId: streamEvents[0].streamId),
            EventCursor(position: UInt64(streamEvents.count - 1), streamId: streamEvents.last!.streamId)
        )
    }
}