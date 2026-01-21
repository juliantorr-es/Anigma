import Foundation

public actor FtsIndexSystem {
    private let database: ContextumDatabase

    public init(database: ContextumDatabase) {
        self.database = database
    }

    public func updateIndex(sourceId: String) async throws {
        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .ingest,
            outcome: .success,
            diagnosticPayload: ["action": "fts_index_update", "source_id": sourceId]
        )

        try await database.insertEvent(event)
    }
}
