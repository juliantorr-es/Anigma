//
//  SecurityStatusCommand.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  CLI command for security observability and status.
//

import Foundation
import ArgumentParser
import SQLite3
import HarmoniaModule

/// CLI commands for security observability.
public struct SecurityCommands {
    private let dbPath: String

    public init(dbPath: String = "./harmonia_harness.sqlite") {
        self.dbPath = dbPath
    }

    /// Show security status and metrics.
    public func status() throws {
        print("🔒 Security Status")
        print("==================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        // Check if database is initialized
        if !DatabaseInitializer.isDatabaseInitialized(at: dbPath) {
            print("📭 Database not initialized. Run 'harmonia security init' first.")
            return
        }

        // Get event counts by type
        let eventCounts = try getEventCounts(db: db)
        print("\n📊 Security Events:")
        for (type, count) in eventCounts.sorted(by: { $0.value > $1.value }) {
            print("  • \(type): \(count)")
        }

        // Get event counts by severity
        let severityCounts = try getSeverityCounts(db: db)
        print("\n⚠️  Event Severity:")
        for (severity, count) in severityCounts.sorted(by: { $0.value > $1.value }) {
            print("  • \(severity): \(count)")
        }

        // Get recent events
        let recentEvents = try getRecentEvents(db: db, limit: 5)
        if !recentEvents.isEmpty {
            print("\n🕐 Recent Events:")
            for event in recentEvents {
                print("  • [\(event.timestamp)] \(event.type) - \(event.severity)")
                if let engine = event.engineId {
                    print("    Engine: \(engine)")
                }
                if let operation = event.operation {
                    print("    Operation: \(operation)")
                }
            }
        }

        // Get blocking rate
        let blockingRate = try getBlockingRate(db: db)
        print("\n🚫 Blocking Rate: \(String(format: "%.1f", blockingRate * 100))%")

        // Get trust statistics
        let trustStats = try getTrustStatistics(db: db)
        print("\n🤝 Trust Statistics:")
        print("  • Average trust: \(trustStats.averageTrust)")
        print("  • High trust subjects: \(trustStats.highTrustCount)")
        print("  • Total subjects: \(trustStats.totalSubjects)")

        // Get governance mode
        let governanceMode = try getGovernanceMode(db: db)
        print("\n🏛️  Governance Mode: \(governanceMode)")

        // Get database stats
        let dbStats = DatabaseInitializer.getDatabaseStats(at: dbPath)
        print("\n🗄️  Database Statistics:")
        for (table, count) in dbStats.sorted(by: { $0.key < $1.key }) {
            print("  • \(table): \(count)")
        }
    }

    /// Initialize security database.
    public func initialize() throws {
        print("🔧 Initializing security database...")

        let success = DatabaseInitializer.initializeDatabase(at: dbPath)
        if success {
            print("✅ Security database initialized at: \(dbPath)")

            // Show initial status
            try status()
        } else {
            print("❌ Failed to initialize security database")
        }
    }

    /// Show detailed event log.
    public func events(limit: Int = 20, type: String? = nil, severity: String? = nil) throws {
        print("📋 Security Events")
        print("==================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        var sql = """
        SELECT id, event_type, engine_id, operation, severity, details, created_at
        FROM security_events
        WHERE 1=1
        """

        var params: [String] = []
        if let type = type {
            sql += " AND event_type = ?"
            params.append(type)
        }
        if let severity = severity {
            sql += " AND severity = ?"
            params.append(severity)
        }

        sql += " ORDER BY created_at DESC LIMIT ?"
        params.append(String(limit))

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare query: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), param, -1, SQLITE_TRANSIENT)
        }

        var events: [SecurityEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let eventType = String(cString: sqlite3_column_text(stmt, 1))
            let engineId = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let operation = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let severity = String(cString: sqlite3_column_text(stmt, 4))
            let details = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let timestamp = String(cString: sqlite3_column_text(stmt, 6))

            events.append(SecurityEvent(
                id: id,
                type: eventType,
                engineId: engineId,
                operation: operation,
                severity: severity,
                details: details,
                timestamp: timestamp
            ))
        }

        if events.isEmpty {
            print("📭 No security events found")
            if type != nil || severity != nil {
                print("Try removing filters or run 'harmonia security init'")
            }
            return
        }

        print("Found \(events.count) events:")
        for event in events {
            print("\n---")
            print("ID: \(event.id)")
            print("Type: \(event.type)")
            print("Severity: \(event.severity)")
            print("Timestamp: \(event.timestamp)")
            if let engineId = event.engineId {
                print("Engine: \(engineId)")
            }
            if let operation = event.operation {
                print("Operation: \(operation)")
            }
            if let details = event.details {
                print("Details: \(details)")
            }
        }
    }

    /// Show trust state.
    public func trust(subjectKind: String? = nil) throws {
        print("🤝 Trust State")
        print("==============")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        var sql = """
        SELECT subject_id, subject_kind, current_trust_tier, last_changed_at, changed_by, reason
        FROM trust_state
        WHERE 1=1
        """

        var params: [String] = []
        if let kind = subjectKind {
            sql += " AND subject_kind = ?"
            params.append(kind)
        }

        sql += " ORDER BY subject_kind, subject_id"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare query: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), param, -1, SQLITE_TRANSIENT)
        }

        var subjects: [TrustSubject] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let subjectId = String(cString: sqlite3_column_text(stmt, 0))
            let subjectKind = String(cString: sqlite3_column_text(stmt, 1))
            let trustTier = String(cString: sqlite3_column_text(stmt, 2))
            let lastChanged = String(cString: sqlite3_column_text(stmt, 3))
            let changedBy = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let reason = sqlite3_column_text(stmt, 5).map { String(cString: $0) }

            subjects.append(TrustSubject(
                id: subjectId,
                kind: subjectKind,
                trustTier: trustTier,
                lastChanged: lastChanged,
                changedBy: changedBy,
                reason: reason
            ))
        }

        if subjects.isEmpty {
            print("📭 No trust subjects found")
            if subjectKind != nil {
                print("Try removing the subject kind filter")
            }
            return
        }

        // Group by kind
        let grouped = Dictionary(grouping: subjects) { $0.kind }

        for (kind, kindSubjects) in grouped.sorted(by: { $0.key < $1.key }) {
            print("\n\(kind.uppercased()):")
            for subject in kindSubjects {
                print("  • \(subject.id): \(subject.trustTier)")
                print("    Last changed: \(subject.lastChanged)")
                if let changedBy = subject.changedBy {
                    print("    Changed by: \(changedBy)")
                }
                if let reason = subject.reason {
                    print("    Reason: \(reason)")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func getEventCounts(db: OpaquePointer?) throws -> [String: Int] {
        let sql = """
        SELECT event_type, COUNT(*) as count
        FROM security_events
        GROUP BY event_type
        ORDER BY count DESC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SecurityCommands", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get event counts: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        var counts: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let type = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int64(stmt, 1))
            counts[type] = count
        }

        return counts
    }

    private func getSeverityCounts(db: OpaquePointer?) throws -> [String: Int] {
        let sql = """
        SELECT severity, COUNT(*) as count
        FROM security_events
        GROUP BY severity
        ORDER BY
            CASE severity
                WHEN 'critical' THEN 1
                WHEN 'high' THEN 2
                WHEN 'medium' THEN 3
                WHEN 'low' THEN 4
                ELSE 5
            END
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SecurityCommands", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get severity counts: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        var counts: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let severity = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int64(stmt, 1))
            counts[severity] = count
        }

        return counts
    }

    private func getRecentEvents(db: OpaquePointer?, limit: Int) throws -> [SecurityEvent] {
        let sql = """
        SELECT id, event_type, engine_id, operation, severity, created_at
        FROM security_events
        ORDER BY created_at DESC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SecurityCommands", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get recent events: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(limit))

        var events: [SecurityEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let eventType = String(cString: sqlite3_column_text(stmt, 1))
            let engineId = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let operation = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let severity = String(cString: sqlite3_column_text(stmt, 4))
            let timestamp = String(cString: sqlite3_column_text(stmt, 5))

            events.append(SecurityEvent(
                id: id,
                type: eventType,
                engineId: engineId,
                operation: operation,
                severity: severity,
                details: nil,
                timestamp: timestamp
            ))
        }

        return events
    }

    private func getBlockingRate(db: OpaquePointer?) throws -> Double {
        let sql = """
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN event_type IN ('capability_blocked', 'doctrine_violation', 'research_inadequate') THEN 1 ELSE 0 END) as blocked
        FROM security_events
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SecurityCommands", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get blocking rate: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let total = Double(sqlite3_column_int64(stmt, 0))
            let blocked = Double(sqlite3_column_int64(stmt, 1))

            if total > 0 {
                return blocked / total
            }
        }

        return 0.0
    }

    private func getTrustStatistics(db: OpaquePointer?) throws -> TrustStatistics {
        let sql = """
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN current_trust_tier IN ('gold', 'platinum') THEN 1 ELSE 0 END) as high_trust,
            AVG(CASE
                WHEN current_trust_tier = 'bronze' THEN 1
                WHEN current_trust_tier = 'silver' THEN 2
                WHEN current_trust_tier = 'gold' THEN 3
                WHEN current_trust_tier = 'platinum' THEN 4
                ELSE 0
            END) as avg_score
        FROM trust_state
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SecurityCommands", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to get trust statistics: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let total = Int(sqlite3_column_int64(stmt, 0))
            let highTrust = Int(sqlite3_column_int64(stmt, 1))
            let avgScore = sqlite3_column_double(stmt, 2)

            // Convert score back to tier name
            let avgTier: String
            switch avgScore {
            case 0..<1.5: avgTier = "bronze"
            case 1.5..<2.5: avgTier = "silver"
            case 2.5..<3.5: avgTier = "gold"
            default: avgTier = "platinum"
            }

            return TrustStatistics(
                totalSubjects: total,
                highTrustCount: highTrust,
                averageTrust: avgTier
            )
        }

        return TrustStatistics(totalSubjects: 0, highTrustCount: 0, averageTrust: "bronze")
    }

    private func getGovernanceMode(db: OpaquePointer?) throws -> String {
        let sql = "SELECT mode FROM governance_mode WHERE id = 1"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SecurityCommands", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get governance mode: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 0))
        }

        return "unknown"
    }
}

// MARK: - Data Structures

private struct SecurityEvent {
    let id: String
    let type: String
    let engineId: String?
    let operation: String?
    let severity: String
    let details: String?
    let timestamp: String
}

private struct TrustSubject {
    let id: String
    let kind: String
    let trustTier: String
    let lastChanged: String
    let changedBy: String?
    let reason: String?
}

private struct TrustStatistics {
    let totalSubjects: Int
    let highTrustCount: Int
    let averageTrust: String
}

// MARK: - Argument Parser

@main
public struct SecurityCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "harmonia-security",
        abstract: "Security observability and management",
        subcommands: [
            StatusCommand.self,
            InitCommand.self,
            EventsCommand.self,
            TrustCommand.self
        ]
    )

    public init() {}
}

// MARK: - Subcommands

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show security status and metrics"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = SecurityCommands(dbPath: dbPath)
        try commands.status()
    }
}

struct InitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize security database"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = SecurityCommands(dbPath: dbPath)
        try commands.initialize()
    }
}

struct EventsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "events",
        abstract: "Show security events"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Option(name: .shortAndLong, help: "Maximum number of events to show")
    var limit: Int = 20

    @Option(name: .shortAndLong, help: "Filter by event type")
    var type: String?

    @Option(name: .shortAndLong, help: "Filter by severity")
    var severity: String?

    func run() throws {
        let commands = SecurityCommands(dbPath: dbPath)
        try commands.events(limit: limit, type: type, severity: severity)
    }
}

struct TrustCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trust",
        abstract: "Show trust state"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Option(name: .shortAndLong, help: "Filter by subject kind")
    var kind: String?

    func run() throws {
        let commands = SecurityCommands(dbPath: dbPath)
        try commands.trust(subjectKind: kind)
    }
}
