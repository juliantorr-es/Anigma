import Foundation

public actor AgentStatsAggregateSystem {
    private let database: ContextumDatabase

    public init(database: ContextumDatabase) {
        self.database = database
    }

    public func recordExecution(
        agentId: String,
        taskTaxonomy: String,
        durationMs: Int,
        outcome: TelemetryEventComponent.Outcome,
        errorCode: String? = nil
    ) async throws {
        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .agentExecution,
            agentId: agentId,
            durationMs: durationMs,
            outcome: outcome,
            errorCode: errorCode
        )

        try await database.insertEvent(event)
    }

    public func getStats(agentId: String, taskTaxonomy: String) async throws -> AgentStatsComponent? {
        try await database.getAgentStats(agentId: agentId, taskTaxonomy: taskTaxonomy)
    }
}
