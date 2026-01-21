//
//  SQLiteMemoryStore.swift
//  HarmoniaMemory
//
//  GRDB-based SQLite storage for memory observations and summaries.
//  Supports FTS5 full-text search and relational queries.
//

import Foundation
import GRDB
import SQLite3
import AnigmaCore

/// SQLite storage for memory observations and summaries.
public actor SQLiteMemoryStore {
    /// Database connection pool.
    private var dbPool: DatabasePool?

    /// Configuration.
    private let config: MemoryConfig

    /// Whether store is initialized.
    private var isInitialized = false

    public init(config: MemoryConfig = .default) {
        self.config = config
    }

    /// Initializes the database connection and creates tables.
    public func initialize() async throws {
        guard !isInitialized else { return }

        let databasePath = expandDatabasePath(config.databasePath)
        let databaseURL = URL(fileURLWithPath: databasePath)

        // Create parent directory if needed
        let parentDir = databaseURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // Configure database pool
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            // Enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            // Enable WAL mode for better concurrency
            try db.execute(sql: "PRAGMA journal_mode = WAL")

            // Enable FTS5 if requested
            if self.config.enableFTS {
                try db.execute(sql: "PRAGMA case_sensitive_like = OFF")
            }
        }

        dbPool = try DatabasePool(path: databaseURL.path, configuration: configuration)

        // Create tables
        try migrate()

        isInitialized = true
    }

    /// Creates or migrates database schema.
    private func migrate() throws {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        try pool.write { db in
            // Create observations table
            try db.create(table: "observations", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull().indexed()
                t.column("tenant_id", .text).notNull().indexed()
                t.column("observation_type", .text).notNull()
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("source", .text).notNull()
                t.column("event_data", .text).notNull()
                t.column("tool_call_id", .text)
                t.column("tool_call_name", .text)
                t.column("tool_call_args", .text)
                t.column("result_success", .boolean)
                t.column("result_output", .text)
                t.column("result_duration_ms", .integer)
                t.column("result_metrics", .text)
                t.column("error_domain", .text)
                t.column("error_code", .integer)
                t.column("error_message", .text)
                t.column("error_stack_trace", .text)
                t.column("error_recoverable", .boolean)
                t.column("tags", .text)
                t.column("metadata", .text)
                t.column("is_sensitive", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull().defaults(to: "CURRENT_TIMESTAMP")
            }

            // Create session summaries table
            try db.create(table: "session_summaries", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull().unique().indexed()
                t.column("tenant_id", .text).notNull().indexed()
                t.column("session_start", .datetime).notNull()
                t.column("session_end", .datetime)
                t.column("observation_count", .integer).notNull().defaults(to: 0)
                t.column("tool_call_count", .integer).notNull().defaults(to: 0)
                t.column("tool_success_count", .integer).notNull().defaults(to: 0)
                t.column("tool_error_count", .integer).notNull().defaults(to: 0)
                t.column("decision_count", .integer).notNull().defaults(to: 0)
                t.column("session_tags", .text)
                t.column("agent_id", .text)
                t.column("mode", .text)
                t.column("model", .text)
                t.column("is_sensitive", .boolean).notNull().defaults(to: false)
                t.column("summary_text", .text)
                t.column("updated_at", .datetime).notNull()
                t.column("created_at", .datetime).notNull().defaults(to: "CURRENT_TIMESTAMP")
            }

            // Create code abstractions table
            try db.create(table: "code_abstractions", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("path", .text).notNull()
                t.column("line", .integer).notNull()
                t.column("category", .text).notNull()
                t.column("abstraction_name", .text).notNull()
                t.column("interface_hash", .text).notNull()
                t.column("metadata", .text)
                t.column("indexed_at", .datetime).notNull()
            }

            // Create indexes for code abstractions
            try db.create(index: "idx_code_abstractions_category_name", on: "code_abstractions", columns: ["category", "abstraction_name"], ifNotExists: true)
            try db.create(index: "idx_code_abstractions_interface_hash", on: "code_abstractions", columns: ["interface_hash"], ifNotExists: true)

            // Create FTS5 virtual table for full-text search
            if config.enableFTS {
                try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS observations_fts USING fts5(
                    session_id,
                    tenant_id,
                    event_data,
                    tags,
                    metadata,
                    content='observations',
                    content_rowid='rowid'
                )
                """)

                // Create triggers to keep FTS index updated
                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS observations_ai AFTER INSERT ON observations BEGIN
                    INSERT INTO observations_fts(rowid, session_id, tenant_id, event_data, tags, metadata)
                    VALUES (new.rowid, new.session_id, new.tenant_id, new.event_data, new.tags, new.metadata);
                END;
                """)

                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS observations_ad AFTER DELETE ON observations BEGIN
                    INSERT INTO observations_fts(observations_fts, rowid, session_id, tenant_id, event_data, tags, metadata)
                    VALUES('delete', old.rowid, old.session_id, old.tenant_id, old.event_data, old.tags, old.metadata);
                END;
                """)

                try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS observations_au AFTER UPDATE ON observations BEGIN
                    INSERT INTO observations_fts(observations_fts, rowid, session_id, tenant_id, event_data, tags, metadata)
                    VALUES('delete', old.rowid, old.session_id, old.tenant_id, old.event_data, old.tags, old.metadata);
                    INSERT INTO observations_fts(rowid, session_id, tenant_id, event_data, tags, metadata)
                    VALUES (new.rowid, new.session_id, new.tenant_id, new.event_data, new.tags, new.metadata);
                END;
                """)
            }

            // Create indexes
            try db.create(index: "idx_observations_session_timestamp", on: "observations", columns: ["session_id", "timestamp"], ifNotExists: true)
            try db.create(index: "idx_observations_type_timestamp", on: "observations", columns: ["observation_type", "timestamp"], ifNotExists: true)
            try db.create(index: "idx_observations_tool_call", on: "observations", columns: ["tool_call_name", "timestamp"], ifNotExists: true)
            try db.create(index: "idx_summaries_session", on: "session_summaries", columns: ["session_id"], ifNotExists: true)
            try db.create(index: "idx_summaries_tenant", on: "session_summaries", columns: ["tenant_id", "updated_at"], ifNotExists: true)
        }
    }

    /// Stores an observation.
    public func storeObservation(_ observation: MemoryObservation) async throws {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        try await pool.write { db in
            // Insert observation
            try observation.insert(db)

            // Update or create session summary
            var summary: MemorySessionSummary
            if let existing = try MemorySessionSummary.fetchOne(db, key: observation.sessionId) {
                summary = existing
                summary.update(with: observation)
                try summary.update(db)
            } else {
                summary = MemorySessionSummary.initial(
                    sessionId: observation.sessionId,
                    tenantId: observation.tenantId
                )
                summary.update(with: observation)
                try summary.insert(db)
            }
        }
    }

    /// Stores a code abstraction in the code_abstractions table.
    public func storeCodeAbstraction(
        id: String = UUID().uuidString,
        path: String,
        line: Int,
        category: String,
        abstractionName: String,
        interfaceHash: String,
        metadata: String? = nil
    ) async throws {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        try await pool.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO code_abstractions
                (id, path, line, category, abstraction_name, interface_hash, metadata, indexed_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    id, path, line, category, abstractionName, interfaceHash,
                    metadata, Date()
                ]
            )
        }
    }

    /// Searches observations using FTS5.
    public func searchObservations(
        query: String,
        sessionId: String? = nil,
        tenantId: String? = nil,
        limit: Int = 100
    ) async throws -> [MemoryObservation] {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        return try await pool.read { db in
            var sql = """
            SELECT o.* FROM observations o
            """

            var arguments: [String] = []

            if self.config.enableFTS && !query.isEmpty {
                sql += """
                 JOIN observations_fts fts ON o.rowid = fts.rowid
                 WHERE observations_fts MATCH ?
                """
                arguments.append(query)

                if let sessionId = sessionId {
                    sql += " AND o.session_id = ?"
                    arguments.append(sessionId)
                }

                if let tenantId = tenantId {
                    sql += " AND o.tenant_id = ?"
                    arguments.append(tenantId)
                }
            } else {
                sql += " WHERE 1=1"

                if let sessionId = sessionId {
                    sql += " AND o.session_id = ?"
                    arguments.append(sessionId)
                }

                if let tenantId = tenantId {
                    sql += " AND o.tenant_id = ?"
                    arguments.append(tenantId)
                }

                if !query.isEmpty {
                    sql += " AND (o.event_data LIKE ? OR o.tags LIKE ?)"
                    let likeQuery = "%\(query)%"
                    arguments.append(likeQuery)
                    arguments.append(likeQuery)
                }
            }

            sql += " ORDER BY o.timestamp DESC LIMIT ?"
            arguments.append(String(limit))

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.compactMap { row in
                try? MemoryObservation(row: row)
            }
        }
    }

    /// Gets a session summary.
    public func getSessionSummary(sessionId: String) async throws -> MemorySessionSummary? {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        return try await pool.read { db in
            try MemorySessionSummary.fetchOne(db, key: sessionId)
        }
    }

    /// Updates a session summary.
    public func updateSessionSummary(_ summary: MemorySessionSummary) async throws {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        try await pool.write { db in
            if try summary.exists(db) {
                try summary.update(db)
            } else {
                try summary.insert(db)
            }
        }
    }

    /// Gets observations for a session.
    public func getObservationsForSession(
        sessionId: String,
        limit: Int = 100
    ) async throws -> [MemoryObservation] {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        return try await pool.read { db in
            try MemoryObservation
                .filter(Column("session_id") == sessionId)
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Gets observations by type.
    public func getObservationsByType(
        type: ObservationType,
        tenantId: String? = nil,
        limit: Int = 100
    ) async throws -> [MemoryObservation] {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        return try await pool.read { db in
            var query = MemoryObservation.filter(Column("observation_type") == type.rawValue)

            if let tenantId = tenantId {
                query = query.filter(Column("tenant_id") == tenantId)
            }

            return try query
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Gets active sessions (no session_end).
    public func getActiveSessions(tenantId: String? = nil) async throws -> [MemorySessionSummary] {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        return try await pool.read { db in
            var query = MemorySessionSummary.filter(Column("session_end") == nil)

            if let tenantId = tenantId {
                query = query.filter(Column("tenant_id") == tenantId)
            }

            return try query
                .order(Column("updated_at").desc)
                .fetchAll(db)
        }
    }

    /// Ends a session.
    public func endSession(sessionId: String) async throws {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        try await pool.write { db in
            if var summary = try MemorySessionSummary.fetchOne(db, key: sessionId) {
                summary.endSession()
                try summary.update(db)
            }
        }
    }

    /// Deletes old observations (cleanup).
    public func deleteOldObservations(olderThan days: Int) async throws -> Int {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        return try await pool.write { db in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

            // Count before deletion for return value
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM observations WHERE timestamp < ?",
                arguments: [cutoffDate]
            ) ?? 0

            if count > 0 {
                try db.execute(
                    sql: "DELETE FROM observations WHERE timestamp < ?",
                    arguments: [cutoffDate]
                )
            }

            return count
        }
    }

    /// Gets database statistics.
    public func getStats() async throws -> DatabaseStats {
        guard let pool = dbPool else {
            throw MemoryError.databaseNotInitialized
        }

        return try await pool.read { db in
            let observationCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM observations") ?? 0
            let summaryCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM session_summaries") ?? 0
            let activeSessions = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM session_summaries WHERE session_end IS NULL") ?? 0

            return DatabaseStats(
                observationCount: observationCount,
                summaryCount: summaryCount,
                activeSessions: activeSessions,
                databasePath: self.config.databasePath
            )
        }
    }

    // MARK: - Private Helpers

    private func expandDatabasePath(_ path: String) -> String {
        if path.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return home + path.dropFirst(1)
        }
        return path
    }
}

// MARK: - GRDB Record Conformance

extension MemoryObservation: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "observations" }

    public init(row: Row) throws {
        id = UUID(uuidString: row["id"]) ?? UUID()
        sessionId = row["session_id"]
        tenantId = row["tenant_id"]
        observationType = ObservationType(rawValue: row["observation_type"]) ?? .toolCall
        timestamp = row["timestamp"]
        source = ObservationSource(rawValue: row["source"]) ?? .system
        eventData = row["event_data"]

        if let toolCallId: String = row["tool_call_id"] {
            toolCall = ToolCall(
                id: toolCallId,
                name: row["tool_call_name"],
                arguments: decodeJSON(row["tool_call_args"] ?? "{}")
            )
        } else {
            toolCall = nil
        }

        if let success: Bool = row["result_success"] {
            result = ObservationResult(
                success: success,
                output: row["result_output"],
                durationMs: row["result_duration_ms"],
                metrics: decodeJSON(row["result_metrics"] ?? "{}")
            )
        } else {
            result = nil
        }

        if let errorDomain: String = row["error_domain"] {
            error = ObservationError(
                domain: errorDomain,
                code: row["error_code"],
                message: row["error_message"],
                stackTrace: row["error_stack_trace"],
                isRecoverable: row["error_recoverable"] ?? false
            )
        } else {
            error = nil
        }

        tags = decodeJSONArray(row["tags"] ?? "[]")
        metadata = decodeJSON(row["metadata"] ?? "{}")
        isSensitive = row["is_sensitive"]
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["session_id"] = sessionId
        container["tenant_id"] = tenantId
        container["observation_type"] = observationType.rawValue
        container["timestamp"] = timestamp
        container["source"] = source.rawValue
        container["event_data"] = eventData

        if let toolCall = toolCall {
            container["tool_call_id"] = toolCall.id
            container["tool_call_name"] = toolCall.name
            container["tool_call_args"] = encodeJSON(toolCall.arguments)
        }

        if let result = result {
            container["result_success"] = result.success
            container["result_output"] = result.output
            container["result_duration_ms"] = result.durationMs
            container["result_metrics"] = encodeJSON(result.metrics)
        }

        if let error = error {
            container["error_domain"] = error.domain
            container["error_code"] = error.code
            container["error_message"] = error.message
            container["error_stack_trace"] = error.stackTrace
            container["error_recoverable"] = error.isRecoverable
        }

        container["tags"] = encodeJSONArray(tags)
        container["metadata"] = encodeJSON(metadata)
        container["is_sensitive"] = isSensitive
    }
}

extension MemorySessionSummary: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "session_summaries" }

    public init(row: Row) throws {
        id = UUID(uuidString: row["id"]) ?? UUID()
        sessionId = row["session_id"]
        tenantId = row["tenant_id"]
        sessionStart = row["session_start"]
        sessionEnd = row["session_end"]
        observationCount = row["observation_count"]
        toolCallCount = row["tool_call_count"]
        toolSuccessCount = row["tool_success_count"]
        toolErrorCount = row["tool_error_count"]
        decisionCount = row["decision_count"]
        sessionTags = decodeJSONArray(row["session_tags"] ?? "[]")
        agentId = row["agent_id"]
        mode = row["mode"]
        model = row["model"]
        isSensitive = row["is_sensitive"]
        summaryText = row["summary_text"]
        updatedAt = row["updated_at"]
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["session_id"] = sessionId
        container["tenant_id"] = tenantId
        container["session_start"] = sessionStart
        container["session_end"] = sessionEnd
        container["observation_count"] = observationCount
        container["tool_call_count"] = toolCallCount
        container["tool_success_count"] = toolSuccessCount
        container["tool_error_count"] = toolErrorCount
        container["decision_count"] = decisionCount
        container["session_tags"] = encodeJSONArray(sessionTags)
        container["agent_id"] = agentId
        container["mode"] = mode
        container["model"] = model
        container["is_sensitive"] = isSensitive
        container["summary_text"] = summaryText
        container["updated_at"] = updatedAt
    }
}

// MARK: - Supporting Types

/// Database statistics.
public struct DatabaseStats: Sendable {
    public let observationCount: Int
    public let summaryCount: Int
    public let activeSessions: Int
    public let databasePath: String
}

/// Memory errors.
public enum MemoryError: Error, Sendable {
    case databaseNotInitialized
    case invalidQuery
    case storageLimitExceeded
    case permissionDenied
}

// MARK: - JSON Helpers

private func decodeJSON<T: Decodable>(_ jsonString: String) -> T {
    guard let data = jsonString.data(using: .utf8),
          let decoded = try? JSONDecoder().decode(T.self, from: data) else {
        // Return empty/default value
        if T.self == [String: String].self {
            return [:] as! T
        } else if T.self == [String: Double].self {
            return [:] as! T
        } else if T.self == [String: Any].self {
            return [:] as! T
        }
        fatalError("Failed to decode JSON for type \(T.self)")
    }
    return decoded
}

private func decodeJSONArray(_ jsonString: String) -> [String] {
    guard let data = jsonString.data(using: .utf8),
          let decoded = try? JSONDecoder().decode([String].self, from: data) else {
        return []
    }
    return decoded
}

private func encodeJSON<T: Encodable>(_ value: T) -> String {
    guard let data = try? JSONEncoder().encode(value),
          let jsonString = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return jsonString
}

private func encodeJSONArray(_ array: [String]) -> String {
    guard let data = try? JSONEncoder().encode(array),
          let jsonString = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return jsonString
}
