import DatabaseCore
import Foundation

/// Central actor for managing security events in the Anigma platform.
/// Thread-safe via actor isolation and backed by the shared PostgreSQL stack.
/// 
/// IMPORTANT: This actor should receive a `DatabaseExecutor` via dependency injection.
/// Only composition roots (AnigmaDaemon, AnigmaApp, CLI tools) should create DatabaseActor directly.
/// See ADR-0018 and td-317bbb for details.
public actor SecurityEventsManager: Sendable {
    private let database: any DatabaseExecutor

    // MARK: - Initialization

    /// Preferred initializer - receives DatabaseExecutor via dependency injection.
    public init(database: any DatabaseExecutor) async throws {
        self.database = database
        try await initializeDatabase()
    }



    // MARK: - Database Setup

    private func initializeDatabase() async throws {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS security_events (
                id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                engine_id TEXT,
                operation TEXT,
                severity TEXT NOT NULL,
                engine_type TEXT,
                zone TEXT,
                capability TEXT,
                doctrine_rule TEXT,
                research_bundle_id TEXT,
                task_id TEXT,
                reason TEXT,
                attempted_action TEXT,
                blocked_action TEXT,
                metadata TEXT,
                created_at TEXT NOT NULL,
                indexed_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_security_events_event_type ON security_events(event_type);
            CREATE INDEX IF NOT EXISTS idx_security_events_severity ON security_events(severity);
            CREATE INDEX IF NOT EXISTS idx_security_events_created_at ON security_events(created_at);
            CREATE INDEX IF NOT EXISTS idx_security_events_engine_id ON security_events(engine_id);
        """

        _ = try await database.execute(createTableSQL)
    }

    // MARK: - Event Recording

    public func recordEvent(
        type: SecurityEventType,
        severity: SecurityEventSeverity,
        engineId: String?,
        operation: String? = nil,
        details: SecurityEventDetails
    ) async throws {
        let eventId = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())

        let metadataJSON = try metadataJSONString(from: details.metadata)

        let insertSQL = """
            INSERT INTO security_events (
                id, event_type, engine_id, operation, severity,
                engine_type, zone, capability, doctrine_rule,
                research_bundle_id, task_id, reason, attempted_action,
                blocked_action, metadata, created_at, indexed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        _ = try await database.execute(
            insertSQL,
            parameters: [
                .text(eventId),
                .text(type.rawValue),
                engineId.map(DatabaseParameter.text) ?? .null,
                operation.map(DatabaseParameter.text) ?? .null,
                .text(severity.rawValue),
                details.engineType.map(DatabaseParameter.text) ?? .null,
                details.zone.map(DatabaseParameter.text) ?? .null,
                details.capability.map(DatabaseParameter.text) ?? .null,
                details.doctrineRule.map(DatabaseParameter.text) ?? .null,
                details.researchBundleId.map(DatabaseParameter.text) ?? .null,
                details.taskId.map(DatabaseParameter.text) ?? .null,
                details.reason.map(DatabaseParameter.text) ?? .null,
                details.attemptedAction.map(DatabaseParameter.text) ?? .null,
                details.blockedAction.map(DatabaseParameter.text) ?? .null,
                metadataJSON.map(DatabaseParameter.text) ?? .null,
                .text(now),
                .text(now)
            ]
        )
    }

    // MARK: - Querying

    public func getEventsByType(_ type: SecurityEventType) async throws -> [SecurityEvent] {
        try await fetchEvents(
            sql: "SELECT * FROM security_events WHERE event_type = ? ORDER BY created_at DESC",
            parameters: [.text(type.rawValue)]
        )
    }

    public func getEventsByDateRange(from: Date, to: Date) async throws -> [SecurityEvent] {
        let formatter = ISO8601DateFormatter()
        return try await fetchEvents(
            sql: "SELECT * FROM security_events WHERE created_at BETWEEN ? AND ? ORDER BY created_at DESC",
            parameters: [
                .text(formatter.string(from: from)),
                .text(formatter.string(from: to))
            ]
        )
    }

    public func getEventsBySeverity(_ severity: SecurityEventSeverity) async throws -> [SecurityEvent] {
        try await fetchEvents(
            sql: "SELECT * FROM security_events WHERE severity = ? ORDER BY created_at DESC",
            parameters: [.text(severity.rawValue)]
        )
    }

    public func getEventsByEngineId(_ engineId: String) async throws -> [SecurityEvent] {
        try await fetchEvents(
            sql: "SELECT * FROM security_events WHERE engine_id = ? ORDER BY created_at DESC",
            parameters: [.text(engineId)]
        )
    }

    // MARK: - Statistics

    public func getEventStats() async throws -> SecurityEventStats {
        var stats = SecurityEventStats()

        if let totalRow = try await database.querySingle("SELECT COUNT(*) AS count FROM security_events"),
           let total = totalRow.int(for: "count") {
            stats.totalEvents = total
        }

        let formatter = ISO8601DateFormatter()
        let cutoffTime = formatter.string(from: Date(timeIntervalSinceNow: -86400))
        if let recentRow = try await database.querySingle(
            "SELECT COUNT(*) AS count FROM security_events WHERE created_at > ?",
            parameters: [.text(cutoffTime)]
        ), let recent = recentRow.int(for: "count") {
            stats.recentEvents24h = recent
        }

        let typeRows = try await database.query(
            "SELECT event_type, COUNT(*) AS count FROM security_events GROUP BY event_type"
        )
        for row in typeRows {
            if let type = row.string(for: "event_type"), let count = row.int(for: "count") {
                stats.eventsByType[type] = count
            }
        }

        let severityRows = try await database.query(
            "SELECT severity, COUNT(*) AS count FROM security_events GROUP BY severity"
        )
        for row in severityRows {
            if let severity = row.string(for: "severity"), let count = row.int(for: "count") {
                stats.eventsBySeverity[severity] = count
            }
        }

        return stats
    }

    // MARK: - Private Helpers

    private func fetchEvents(sql: String, parameters: [DatabaseParameter]) async throws -> [SecurityEvent] {
        let rows = try await database.query(sql, parameters: parameters)
        return rows.compactMap(Self.decodeEvent(row:))
    }

    private static func decodeEvent(row: DatabaseRow) -> SecurityEvent? {
        guard
            let id = row.string(for: "id"),
            let type = row.string(for: "event_type"),
            let severity = row.string(for: "severity"),
            let createdAt = row.string(for: "created_at")
        else {
            return nil
        }

        let metadata = decodeMetadata(row.string(for: "metadata"))

        let details = SecurityEventDetails(
            engineType: row.string(for: "engine_type"),
            engineId: row.string(for: "engine_id"),
            zone: row.string(for: "zone"),
            capability: row.string(for: "capability"),
            doctrineRule: row.string(for: "doctrine_rule"),
            researchBundleId: row.string(for: "research_bundle_id"),
            taskId: row.string(for: "task_id"),
            reason: row.string(for: "reason"),
            attemptedAction: row.string(for: "attempted_action"),
            blockedAction: row.string(for: "blocked_action"),
            metadata: metadata
        )

        return SecurityEvent(
            id: id,
            type: type,
            engineId: row.string(for: "engine_id"),
            operation: row.string(for: "operation"),
            severity: severity,
            details: details,
            createdAt: createdAt
        )
    }

    private static func decodeMetadata(_ json: String?) -> [String: String] {
        guard let json,
              let data = json.data(using: .utf8),
              let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            return [:]
        }

        return dictionary
    }

    private func metadataJSONString(from metadata: [String: String]?) throws -> String? {
        guard let metadata, !metadata.isEmpty else {
            return nil
        }

        let data = try JSONSerialization.data(withJSONObject: metadata, options: [])
        return String(data: data, encoding: .utf8)
    }
}
