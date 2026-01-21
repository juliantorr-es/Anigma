import Foundation

public actor IngestNormalizeSystem {
    private let database: ContextumDatabase

    public init(database: ContextumDatabase) {
        self.database = database
    }

    public func process(source: ContextSourceComponent) async throws {
        // Phase 0: Just log the event, actual content fetching happens elsewhere
        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .ingest,
            receiptId: source.receiptId,
            outcome: .success
        )

        try await database.insertEvent(event)
    }
}
