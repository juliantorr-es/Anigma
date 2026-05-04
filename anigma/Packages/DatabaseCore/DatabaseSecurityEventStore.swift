//
//  DatabaseSecurityEventStore.swift
//  DatabaseCore
//
//  DatabaseCore-backed implementation of SecurityEventStore protocol.
//  This adapter bridges the portable SecurityEventsContracts to the concrete
//  DatabaseCore persistence layer.
//
//  This implements the SecurityEventStore contract using DatabaseExecutor,
//  DatabaseParameter, and DatabaseRow from DatabaseCore.

import Foundation
import SecurityEventsContracts

/// DatabaseCore-backed implementation of SecurityEventStore.
/// 
/// This concrete store uses DatabaseExecutor to persist security events to the
/// underlying SQL database. It provides the implementation that SecurityEventsManager
/// depends on via the SecurityEventStore protocol.
public actor DatabaseSecurityEventStore: SecurityEventStore {
    private let database: any DatabaseExecutor

    // MARK: - Initialization

    /// Initializes the store with a DatabaseExecutor.
    /// 
    /// - Parameter database: The database executor to use for persistence operations.
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

    // MARK: - SecurityEventWriteStore

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

        let parameters: [DatabaseParameter] = [
            .text(eventId),
            .text(type.rawValue),
            engineId.map { .text($0) } ?? .null,
            operation.map { .text($0) } ?? .null,
            .text(severity.rawValue),
            details.engineType.map { .text($0) } ?? .null,
            details.zone.map { .text($0) } ?? .null,
            details.capability.map { .text($0) } ?? .null,
            details.doctrineRule.map { .text($0) } ?? .null,
            details.researchBundleId.map { .text($0) } ?? .null,
            details.taskId.map { .text($0) } ?? .null,
            details.reason.map { .text($0) } ?? .null,
            details.attemptedAction.map { .text($0) } ?? .null,
            details.blockedAction.map { .text($0) } ?? .null,
            metadataJSON.map { .text($0) } ?? .null,
            .text(now),
            .text(now)
        ]

        _ = try await database.execute(insertSQL, parameters: parameters)
    }

    // MARK: - SecurityEventReadStore

    public func getEventsByType(_ type: String) async throws -> [SecurityEventsContracts.SecurityEvent] {
        try await fetchEvents(
            sql: "SELECT * FROM security_events WHERE event_type = ? ORDER BY created_at DESC",
            parameters: [.text(type)]
        )
    }

    public func getEventsByDateRange(from: Date, to: Date) async throws -> [SecurityEventsContracts.SecurityEvent] {
        let formatter = ISO8601DateFormatter()
        return try await fetchEvents(
            sql: "SELECT * FROM security_events WHERE created_at BETWEEN ? AND ? ORDER BY created_at DESC",
            parameters: [
                .text(formatter.string(from: from)),
                .text(formatter.string(from: to))
            ]
        )
    }

    public func getEventsBySeverity(_ severity: String) async throws -> [SecurityEventsContracts.SecurityEvent] {
        try await fetchEvents(
            sql: "SELECT * FROM security_events WHERE severity = ? ORDER BY created_at DESC",
            parameters: [.text(severity)]
        )
    }

    public func getEventsByEngineId(_ engineId: String) async throws -> [SecurityEventsContracts.SecurityEvent] {
        try await fetchEvents(
            sql: "SELECT * FROM security_events WHERE engine_id = ? ORDER BY created_at DESC",
            parameters: [.text(engineId)]
        )
    }

    public func getEventStats() async throws -> SecurityEventsContracts.SecurityEventStats {
        var stats = SecurityEventsContracts.SecurityEventStats()

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

    private func fetchEvents(sql: String, parameters: [DatabaseParameter]) async throws -> [SecurityEventsContracts.SecurityEvent] {
        let rows = try await database.query(sql, parameters: parameters)
        return rows.compactMap(Self.decodeEvent(row:))
    }

    private static func decodeEvent(row: DatabaseRow) -> SecurityEventsContracts.SecurityEvent? {
        guard
            let id = row.string(for: "id"),
            let type = row.string(for: "event_type"),
            let severity = row.string(for: "severity"),
            let createdAt = row.string(for: "created_at")
        else {
            return nil
        }

        let metadata = decodeMetadata(row.string(for: "metadata"))

        let details = SecurityEventsContracts.SecurityEventDetails(
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

        return SecurityEventsContracts.SecurityEvent(
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
