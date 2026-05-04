import Foundation
import MessagingContracts

public actor PostgresEventLog: EventStreamPersistence {
    public typealias StreamId = AnigmaEventStreamId
    public typealias Cursor = EventCursor

    private let connection: PostgresConnection
    private var cursors: [String: UInt64] = [:]

    public init(connection: PostgresConnection) {
        self.connection = connection
    }

    public func append(_ event: EventEnvelope, toStream streamId: AnigmaEventStreamId) async throws -> EventAppendReceipt {
        let streamKey = self.streamKey(streamId)
        let position = (cursors[streamKey] ?? 0) + 1
        cursors[streamKey] = position

        let sql = """
            INSERT INTO event_log (event_id, stream_id, position, payload, metadata, created_at)
            VALUES (gen_random_uuid(), $1, $2, $3, $4, NOW())
            RETURNING event_id, position
        """

        let result = try await connection.queryOne(sql, [streamKey, position, event.payload, event.metadata], decoding: EventInsertResult.self)

        guard let result else {
            throw MessagingError.jobNotFound
        }

        return EventAppendReceipt(
            position: UInt64(position),
            streamId: streamId,
            timestamp: Timestamp(Date().timeIntervalSince1970),
            eventId: result.event_id
        )
    }

    /// nonisolated: This method creates its own Task and does not modify actor-isolated state.
    /// It only reads from the database via connection (which is safe for concurrent reads).
    /// The actor's mutable state (cursors) is NOT accessed by this method.
    /// This allows PostgresEventLog (actor) to conform to EventStreamPersistence (Sendable protocol).
    public nonisolated func subscribe(to streamId: AnigmaEventStreamId, from cursor: EventCursor?) -> AsyncThrowingStream<EventEnvelope, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let streamKey = self.streamKey(streamId)
                let startPosition = cursor?.position ?? 0

                let sql = """
                    SELECT position, payload, metadata, created_at
                    FROM event_log
                    WHERE stream_id = $1 AND position >= $2
                    ORDER BY position ASC
                """

                let results = try await connection.queryAll(sql, [streamKey, startPosition], decoding: LogEvent.self)

                for result in results {
                    let envelope = EventEnvelope(
                        streamId: streamId,
                        payload: result.payload,
                        metadata: result.metadata
                    )
                    continuation.yield(envelope)
                }

                continuation.finish()
            }
        }
    }

    public func replay(streamId: AnigmaEventStreamId, from startCursor: EventCursor?, to endCursor: EventCursor?) async throws -> [EventEnvelope] {
        let streamKey = self.streamKey(streamId)
        let startPosition = startCursor?.position ?? 0
        let endPosition = endCursor?.position ?? UInt64.max

        let sql = """
            SELECT position, payload, metadata, created_at
            FROM event_log
            WHERE stream_id = $1 AND position >= $2 AND position <= $3
            ORDER BY position ASC
        """

        let results = try await connection.queryAll(sql, [streamKey, startPosition, endPosition], decoding: LogEvent.self)

        return results.map { result in
            EventEnvelope(
                streamId: streamId,
                payload: result.payload,
                metadata: result.metadata
            )
        }
    }

    public func getStreamMetadata(streamId: AnigmaEventStreamId) async throws -> StreamMetadata {
        let streamKey = self.streamKey(streamId)

        let sql = """
            SELECT
                COUNT(*) as count,
                MIN(position) as min_pos,
                MAX(position) as max_pos
            FROM event_log
            WHERE stream_id = $1
        """

        guard let result = try await connection.queryOne(sql, [streamKey], decoding: StreamStats.self) else {
            return StreamMetadata(streamId: streamId, eventCount: 0)
        }

        var oldestCursor: EventCursor?
        var newestCursor: EventCursor?

        if let minPos = result.min_pos {
            oldestCursor = EventCursor(position: UInt64(minPos), streamId: streamId)
        }
        if let maxPos = result.max_pos {
            newestCursor = EventCursor(position: UInt64(maxPos), streamId: streamId)
        }

        return StreamMetadata(
            streamId: streamId,
            eventCount: UInt64(result.count),
            oldestCursor: oldestCursor,
            newestCursor: newestCursor,
            retentionPolicy: StreamRetentionPolicy()
        )
    }

    /// nonisolated: Pure function, no actor state access.
    /// Only performs string formatting on input parameters.
    private nonisolated func streamKey(_ streamId: AnigmaEventStreamId) -> String {
        return "stream:{\(streamId.projectId)}:{\(streamId.topic)}:{\(streamId.partitionKey ?? "default")}"
    }

    private struct EventInsertResult: Decodable {
        let event_id: UUID
        let position: UInt64
    }

    private struct LogEvent: Decodable {
        let position: UInt64
        let payload: Data
        let metadata: [String: String]
        let created_at: Date
    }

    private struct StreamStats: Decodable {
        let count: Int
        let min_pos: UInt64?
        let max_pos: UInt64?
    }
}