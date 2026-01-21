//
//  SecurityEventsManager.swift
//  AnigmaCore
//
//  Centralized security event logging for observability.
//  This actor lives in Tier 2 (Platform Runtime) as it performs execution and storage.
//

import Foundation
import SQLite3
import AnigmaPrimitives
import SecurityEventsManager

/// Centralized security event logging.
public actor SecurityEventsManager {

    private let dbPath: String

    public init(dbPath: String = "harmonia_harness.sqlite") {
        self.dbPath = dbPath
    }

    /// Log a security event to the database.
    public func logEvent(
        type: SecurityEventType,
        severity: SecurityEventSeverity,
        engineId: String? = nil,
        operation: String? = nil,
        details: SecurityEventDetails
    ) {
        logInfo("[SECURITY] Event: \(type.rawValue) [\(severity.rawValue)]", category: "SecurityEvents")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            logError("[SECURITY] Failed to open database for event logging: \(errMsg)", category: "SecurityEvents")
            return
        }
        defer { sqlite3_close(db) }

        do {
            try insertEvent(
                db: db,
                type: type,
                severity: severity,
                engineId: engineId,
                operation: operation,
                details: details
            )
        } catch {
            logError("[SECURITY] Failed to log security event: \(error)", category: "SecurityEvents")
        }
    }

    /// Log a capability blocked event.
    public func logCapabilityBlocked(
        engineId: String,
        operation: String,
        capability: String,
        reason: String,
        zone: String? = nil
    ) {
        let details = SecurityEventDetails(
            engineType: nil,
            engineId: engineId,
            zone: zone,
            capability: capability,
            reason: reason,
            attemptedAction: operation
        )

        logEvent(
            type: .capabilityBlocked,
            severity: .medium,
            engineId: engineId,
            operation: operation,
            details: details
        )
    }

    /// Log a doctrine violation event.
    public func logDoctrineViolation(
        engineId: String,
        operation: String,
        ruleId: String,
        reason: String,
        severity: SecurityEventSeverity = .medium
    ) {
        let details = SecurityEventDetails(
            engineType: nil,
            engineId: engineId,
            doctrineRule: ruleId,
            reason: reason,
            attemptedAction: operation
        )

        logEvent(
            type: .doctrineViolation,
            severity: severity,
            engineId: engineId,
            operation: operation,
            details: details
        )
    }

    /// Log a research inadequacy event.
    public func logResearchInadequate(
        moduleId: String,
        researchBundleId: String?,
        adequacyScore: Double,
        reason: String
    ) {
        let details = SecurityEventDetails(
            researchBundleId: researchBundleId,
            reason: "Research inadequate for module \(moduleId): \(reason) (score: \(adequacyScore))"
        )

        logEvent(
            type: .researchInadequate,
            severity: .medium,
            operation: "module_creation",
            details: details
        )
    }

    /// Log a trust tier change event.
    public func logTrustChange(
        subjectId: String,
        subjectKind: String,
        oldTier: String,
        newTier: String,
        reason: String,
        changedBy: String? = nil
    ) {
        let details = SecurityEventDetails(
            engineId: subjectId,
            reason: "Trust tier changed from \(oldTier) to \(newTier): \(reason)"
        )

        // String comparison for tiers
        let eventType: SecurityEventType = newTier > oldTier ? .trustPromoted : .trustDegraded
        let severity: SecurityEventSeverity = newTier < oldTier ? .high : .medium

        logEvent(
            type: eventType,
            severity: severity,
            engineId: subjectId,
            operation: "trust_change",
            details: details
        )
    }

    /// Log a governance mode change event.
    public func logModeChange(
        oldMode: String,
        newMode: String,
        reason: String,
        changedBy: String
    ) {
        let details = SecurityEventDetails(
            reason: "Governance mode changed from \(oldMode) to \(newMode): \(reason)"
        )

        logEvent(
            type: .modeChanged,
            severity: .medium,
            operation: "mode_change",
            details: details
        )
    }

    /// Log a red-team attack detection event.
    public func logRedTeamAttack(
        attackType: String,
        detectedBy: String,
        description: String,
        severity: SecurityEventSeverity = .critical
    ) {
        let details = SecurityEventDetails(
            reason: "Red-team attack detected: \(attackType) - \(description)"
        )

        logEvent(
            type: .redTeamAttack,
            severity: severity,
            operation: "red_team_test",
            details: details
        )
    }

    /// Get security events for observability.
    public func getEvents(
        type: SecurityEventType? = nil,
        severity: SecurityEventSeverity? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) -> [SecurityEvent] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

        var conditions: [String] = []
        var params: [Any] = []

        if let type = type {
            conditions.append("event_type = ?")
            params.append(type.rawValue)
        }

        if let severity = severity {
            conditions.append("severity = ?")
            params.append(severity.rawValue)
        }

        var sql = "SELECT id, event_type, engine_id, operation, severity, details, created_at FROM security_events"
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY created_at DESC LIMIT ? OFFSET ?"
        params.append(limit)
        params.append(offset)

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in params.enumerated() {
            let paramIndex = Int32(index + 1)
            if let stringParam = param as? String {
                sqlite3_bind_text(stmt, paramIndex, stringParam, -1, nil)
            } else if let intParam = param as? Int {
                sqlite3_bind_int64(stmt, paramIndex, Int64(intParam))
            }
        }

        var events: [SecurityEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let event = parseEventRow(stmt: stmt) {
                events.append(event)
            }
        }

        return events
    }

    /// Get security event statistics for observability.
    public func getEventStats() -> SecurityEventStats {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            return SecurityEventStats()
        }
        defer { sqlite3_close(db) }

        var stats = SecurityEventStats()

        // Total events
        let totalSql = "SELECT COUNT(*) FROM security_events"
        if let total = queryCount(db: db, sql: totalSql) {
            stats.totalEvents = total
        }

        // Events by type
        let typeSql = "SELECT event_type, COUNT(*) FROM security_events GROUP BY event_type"
        var typeStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, typeSql, -1, &typeStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(typeStmt) }
            while sqlite3_step(typeStmt) == SQLITE_ROW {
                let type = String(cString: sqlite3_column_text(typeStmt, 0))
                let count = Int(sqlite3_column_int64(typeStmt, 1))
                stats.eventsByType[type] = count
            }
        }

        // Events by severity
        let severitySql = "SELECT severity, COUNT(*) FROM security_events GROUP BY severity"
        var severityStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, severitySql, -1, &severityStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(severityStmt) }
            while sqlite3_step(severityStmt) == SQLITE_ROW {
                let severity = String(cString: sqlite3_column_text(severityStmt, 0))
                let count = Int(sqlite3_column_int64(severityStmt, 1))
                stats.eventsBySeverity[severity] = count
            }
        }

        // Recent events (last 24 hours)
        let recentSql = "SELECT COUNT(*) FROM security_events WHERE created_at >= datetime('now', '-1 day')"
        if let recent = queryCount(db: db, sql: recentSql) {
            stats.recentEvents24h = recent
        }

        return stats
    }

    // MARK: - Private Methods

    private func insertEvent(
        db: OpaquePointer?,
        type: SecurityEventType,
        severity: SecurityEventSeverity,
        engineId: String?,
        operation: String?,
        details: SecurityEventDetails
    ) throws {
        let sql = """
        INSERT INTO security_events (id, event_type, engine_id, operation, severity, details, created_at)
        VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SecurityEventsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare statement: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        let eventId = UUID().uuidString
        sqlite3_bind_text(stmt, 1, eventId, -1, nil)
        sqlite3_bind_text(stmt, 2, type.rawValue, -1, nil)

        if let engineId = engineId {
            sqlite3_bind_text(stmt, 3, engineId, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 3)
        }

        if let operation = operation {
            sqlite3_bind_text(stmt, 4, operation, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 4)
        }

        sqlite3_bind_text(stmt, 5, severity.rawValue, -1, nil)

        let detailsJSON = try JSONEncoder().encode(details)
        let detailsString = String(data: detailsJSON, encoding: .utf8) ?? "{}"
        sqlite3_bind_text(stmt, 6, detailsString, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SecurityEventsManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to insert event: \(errMsg)"])
        }
    }

    private func parseEventRow(stmt: OpaquePointer?) -> SecurityEvent? {
        guard let idCString = sqlite3_column_text(stmt, 0),
              let typeCString = sqlite3_column_text(stmt, 1),
              let severityCString = sqlite3_column_text(stmt, 4),
              let detailsCString = sqlite3_column_text(stmt, 5),
              let createdAtCString = sqlite3_column_text(stmt, 6) else {
            return nil
        }

        let id = String(cString: idCString)
        let type = String(cString: typeCString)
        let severity = String(cString: severityCString)
        let detailsJSON = String(cString: detailsCString)
        let createdAt = String(cString: createdAtCString)

        let engineId = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 2))
        let operation = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 3))

        let details = try? JSONDecoder().decode(SecurityEventDetails.self, from: Data(detailsJSON.utf8))

        return SecurityEvent(
            id: id,
            type: type,
            engineId: engineId,
            operation: operation,
            severity: severity,
            details: details ?? SecurityEventDetails(),
            createdAt: createdAt
        )
    }

    private func queryCount(db: OpaquePointer?, sql: String) -> Int? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return nil
    }
}
