import SecurityEventsContracts
import Foundation

/// Central actor for managing security events in the Anigma platform.
/// Thread-safe via actor isolation.
/// 
/// IMPORTANT: This actor should receive a SecurityEventStore via dependency injection.
/// Only composition roots (AnigmaDaemon, AnigmaApp, CLI tools) should provide the concrete store.
/// See ADR-0018 and td-317bbb for details.
public actor SecurityEventsManager: Sendable {
    private let store: any SecurityEventStore

    // MARK: - Initialization

    /// Preferred initializer - receives SecurityEventStore via dependency injection.
    public init(store: any SecurityEventStore) {
        self.store = store
    }



    // MARK: - Event Recording

    public func recordEvent(
        type: SecurityEventType,
        severity: SecurityEventSeverity,
        engineId: String?,
        operation: String? = nil,
        details: SecurityEventDetails
    ) async throws {
        try await store.recordEvent(
            type: type,
            severity: severity,
            engineId: engineId,
            operation: operation,
            details: details
        )
    }

    // MARK: - Querying

    public func getEventsByType(_ type: SecurityEventType) async throws -> [SecurityEvent] {
        try await store.getEventsByType(type.rawValue)
    }

    public func getEventsByDateRange(from: Date, to: Date) async throws -> [SecurityEvent] {
        try await store.getEventsByDateRange(from: from, to: to)
    }

    public func getEventsBySeverity(_ severity: SecurityEventSeverity) async throws -> [SecurityEvent] {
        try await store.getEventsBySeverity(severity.rawValue)
    }

    public func getEventsByEngineId(_ engineId: String) async throws -> [SecurityEvent] {
        try await store.getEventsByEngineId(engineId)
    }

    // MARK: - Statistics

    public func getEventStats() async throws -> SecurityEventStats {
        try await store.getEventStats()
    }
}
