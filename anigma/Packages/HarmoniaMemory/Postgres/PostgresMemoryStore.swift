import AnigmaCore
import AnigmaPrimitives
import DatabaseCore
import Foundation

public actor PostgresMemoryStore {
    private let connectionManager: PostgresConnectionManager
    private let config: MemoryConfig
    private var isInitialized = false

    public init(config: MemoryConfig = .default) async throws {
        self.config = config
        self.connectionManager = PostgresConnectionManager(
            config: PostgresConnectionPoolConfig(connectionString: config.databasePath)
        )
        try await initialize()
    }

    public func initialize() async throws {
        guard !isInitialized else { return }
        try await createSchema()
        isInitialized = true
    }

    private func createSchema() async throws {
        _ = try await execute("""
            CREATE TABLE IF NOT EXISTS observations (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                tenant_id TEXT NOT NULL,
                observation_type TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                source TEXT NOT NULL,
                event_data TEXT NOT NULL,
                tool_call_id TEXT,
                tool_call_name TEXT,
                tool_call_args TEXT,
                result_success BOOLEAN,
                result_output TEXT,
                result_duration_ms INTEGER,
                result_metrics TEXT,
                error_domain TEXT,
                error_code INTEGER,
                error_message TEXT,
                error_stack_trace TEXT,
                error_recoverable BOOLEAN,
                tags TEXT,
                metadata TEXT,
                is_sensitive BOOLEAN NOT NULL DEFAULT FALSE,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """)

        _ = try await execute("""
            CREATE TABLE IF NOT EXISTS session_summaries (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL UNIQUE,
                tenant_id TEXT NOT NULL,
                session_start TEXT NOT NULL,
                session_end TEXT,
                observation_count INTEGER NOT NULL DEFAULT 0,
                tool_call_count INTEGER NOT NULL DEFAULT 0,
                tool_success_count INTEGER NOT NULL DEFAULT 0,
                tool_error_count INTEGER NOT NULL DEFAULT 0,
                decision_count INTEGER NOT NULL DEFAULT 0,
                session_tags TEXT,
                agent_id TEXT,
                mode TEXT,
                model TEXT,
                is_sensitive BOOLEAN NOT NULL DEFAULT FALSE,
                summary_text TEXT,
                updated_at TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """)

        _ = try await execute("""
            CREATE TABLE IF NOT EXISTS code_abstractions (
                id TEXT PRIMARY KEY,
                path TEXT NOT NULL,
                line INTEGER NOT NULL,
                category TEXT NOT NULL,
                abstraction_name TEXT NOT NULL,
                interface_hash TEXT NOT NULL,
                metadata TEXT,
                indexed_at TEXT NOT NULL
            )
            """)

        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_observations_session_timestamp ON observations(session_id, timestamp DESC);")
        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_observations_type_timestamp ON observations(observation_type, timestamp DESC);")
        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_observations_tool_call ON observations(tool_call_name, timestamp DESC);")
        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_summaries_session ON session_summaries(session_id);")
        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_summaries_tenant ON session_summaries(tenant_id, updated_at DESC);")
        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_code_abstractions_category_name ON code_abstractions(category, abstraction_name);")
        _ = try await execute("CREATE INDEX IF NOT EXISTS idx_code_abstractions_interface_hash ON code_abstractions(interface_hash);")
    }

    public func storeObservation(_ observation: MemoryObservation) async throws {
        _ = try await execute(
            """
            INSERT INTO observations (
                id, session_id, tenant_id, observation_type, timestamp, source, event_data,
                tool_call_id, tool_call_name, tool_call_args,
                result_success, result_output, result_duration_ms, result_metrics,
                error_domain, error_code, error_message, error_stack_trace, error_recoverable,
                tags, metadata, is_sensitive, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                session_id = EXCLUDED.session_id,
                tenant_id = EXCLUDED.tenant_id,
                observation_type = EXCLUDED.observation_type,
                timestamp = EXCLUDED.timestamp,
                source = EXCLUDED.source,
                event_data = EXCLUDED.event_data,
                tool_call_id = EXCLUDED.tool_call_id,
                tool_call_name = EXCLUDED.tool_call_name,
                tool_call_args = EXCLUDED.tool_call_args,
                result_success = EXCLUDED.result_success,
                result_output = EXCLUDED.result_output,
                result_duration_ms = EXCLUDED.result_duration_ms,
                result_metrics = EXCLUDED.result_metrics,
                error_domain = EXCLUDED.error_domain,
                error_code = EXCLUDED.error_code,
                error_message = EXCLUDED.error_message,
                error_stack_trace = EXCLUDED.error_stack_trace,
                error_recoverable = EXCLUDED.error_recoverable,
                tags = EXCLUDED.tags,
                metadata = EXCLUDED.metadata,
                is_sensitive = EXCLUDED.is_sensitive
            """,
            parameters: observationInsertParameters(observation)
        )

        if var summary = try await getSessionSummary(sessionId: observation.sessionId) {
            summary.update(with: observation)
            try await updateSessionSummary(summary)
        } else {
            var summary = MemorySessionSummary.initial(
                sessionId: observation.sessionId,
                tenantId: observation.tenantId
            )
            summary.update(with: observation)
            try await updateSessionSummary(summary)
        }
    }

    public func storeCodeAbstraction(
        id: String = UUID().uuidString,
        path: String,
        line: Int,
        category: String,
        abstractionName: String,
        interfaceHash: String,
        metadata: String? = nil
    ) async throws {
        _ = try await execute(
            """
            INSERT INTO code_abstractions
                (id, path, line, category, abstraction_name, interface_hash, metadata, indexed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                path = EXCLUDED.path,
                line = EXCLUDED.line,
                category = EXCLUDED.category,
                abstraction_name = EXCLUDED.abstraction_name,
                interface_hash = EXCLUDED.interface_hash,
                metadata = EXCLUDED.metadata,
                indexed_at = EXCLUDED.indexed_at
            """,
            parameters: [
                id,
                path,
                String(line),
                category,
                abstractionName,
                interfaceHash,
                metadata ?? "__ANIGMA_NULL__",
                iso8601String(Date())
            ]
        )
    }

    public func searchObservations(
        query: String,
        sessionId: String? = nil,
        tenantId: String? = nil,
        limit: Int = 100
    ) async throws -> [MemoryObservation] {
        var sql = """
        SELECT * FROM observations
        WHERE 1=1
        """
        var parameters: [String] = []

        if !query.isEmpty {
            sql += " AND (event_data ILIKE ? OR COALESCE(tags, '') ILIKE ? OR COALESCE(metadata, '') ILIKE ?)"
            let pattern = "%\(query)%"
            parameters.append(contentsOf: [pattern, pattern, pattern])
        }
        if let sessionId {
            sql += " AND session_id = ?"
            parameters.append(sessionId)
        }
        if let tenantId {
            sql += " AND tenant_id = ?"
            parameters.append(tenantId)
        }

        sql += " ORDER BY timestamp DESC LIMIT \(limit)"
        let rows = try await fetchRows(sql, parameters: parameters)
        return rows.compactMap(makeObservation(from:))
    }

    public func getSessionSummary(sessionId: String) async throws -> MemorySessionSummary? {
        let rows = try await fetchRows(
            "SELECT * FROM session_summaries WHERE session_id = ? LIMIT 1",
            parameters: [sessionId]
        )
        guard let row = rows.first else { return nil }
        return makeSummary(from: row)
    }

    public func updateSessionSummary(_ summary: MemorySessionSummary) async throws {
        _ = try await execute(
            """
            INSERT INTO session_summaries (
                id, session_id, tenant_id, session_start, session_end,
                observation_count, tool_call_count, tool_success_count, tool_error_count,
                decision_count, session_tags, agent_id, mode, model,
                is_sensitive, summary_text, updated_at, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (session_id) DO UPDATE SET
                session_end = EXCLUDED.session_end,
                observation_count = EXCLUDED.observation_count,
                tool_call_count = EXCLUDED.tool_call_count,
                tool_success_count = EXCLUDED.tool_success_count,
                tool_error_count = EXCLUDED.tool_error_count,
                decision_count = EXCLUDED.decision_count,
                session_tags = EXCLUDED.session_tags,
                agent_id = EXCLUDED.agent_id,
                mode = EXCLUDED.mode,
                model = EXCLUDED.model,
                is_sensitive = EXCLUDED.is_sensitive,
                summary_text = EXCLUDED.summary_text,
                updated_at = EXCLUDED.updated_at
            """,
            parameters: sessionSummaryInsertParameters(summary)
        )
    }

    public func getObservationsForSession(sessionId: String, limit: Int = 100) async throws -> [MemoryObservation] {
        let rows = try await fetchRows(
            "SELECT * FROM observations WHERE session_id = ? ORDER BY timestamp DESC LIMIT \(limit)",
            parameters: [sessionId]
        )
        return rows.compactMap(makeObservation(from:))
    }

    public func getObservationsByType(
        type: ObservationType,
        tenantId: String? = nil,
        limit: Int = 100
    ) async throws -> [MemoryObservation] {
        var sql = "SELECT * FROM observations WHERE observation_type = ?"
        var parameters = [type.rawValue]
        if let tenantId {
            sql += " AND tenant_id = ?"
            parameters.append(tenantId)
        }
        sql += " ORDER BY timestamp DESC LIMIT \(limit)"
        let rows = try await fetchRows(sql, parameters: parameters)
        return rows.compactMap(makeObservation(from:))
    }

    public func getActiveSessions(tenantId: String? = nil) async throws -> [MemorySessionSummary] {
        var sql = "SELECT * FROM session_summaries WHERE session_end IS NULL"
        var parameters: [String] = []
        if let tenantId {
            sql += " AND tenant_id = ?"
            parameters.append(tenantId)
        }
        sql += " ORDER BY updated_at DESC"
        let rows = try await fetchRows(sql, parameters: parameters)
        return rows.compactMap(makeSummary(from:))
    }

    public func endSession(sessionId: String) async throws {
        if var summary = try await getSessionSummary(sessionId: sessionId) {
            summary.endSession()
            try await updateSessionSummary(summary)
        }
    }

    public func deleteOldObservations(olderThan days: Int) async throws -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffString = iso8601String(cutoff)
        return try await execute(
            "DELETE FROM observations WHERE timestamp < ?",
            parameters: [cutoffString]
        )
    }

    public func getStats() async throws -> DatabaseStats {
        let observationCount = try await count(from: "observations")
        let summaryCount = try await count(from: "session_summaries")
        let activeSessions = try await count(from: "session_summaries WHERE session_end IS NULL", wrapWhereClause: false)
        return DatabaseStats(
            observationCount: observationCount,
            summaryCount: summaryCount,
            activeSessions: activeSessions,
            databasePath: config.databasePath
        )
    }

    private func count(from table: String, wrapWhereClause: Bool = true) async throws -> Int {
        let sql = wrapWhereClause ? "SELECT COUNT(*) AS count FROM \(table)" : "SELECT COUNT(*) AS count FROM \(table)"
        let rows = try await fetchRows(sql, parameters: [])
        return rows.first.flatMap { intValue($0["count"]) } ?? 0
    }

    private func execute(_ sql: String, parameters: [String] = []) async throws -> Int {
        let connection = try await connectionManager.acquireConnection()
        defer { Task { await connectionManager.releaseConnection(connection) } }
        let result = try await connection.executeQuery(sql, parameters: parameters, rlsContext: nil)
        return intValue(result["rowCount"]) ?? 0
    }

    private func fetchRows(_ sql: String, parameters: [String]) async throws -> [[String: DatabaseCore.AnyCodable]] {
        let connection = try await connectionManager.acquireConnection()
        defer { Task { await connectionManager.releaseConnection(connection) } }
        let result = try await connection.executeQuery(sql, parameters: parameters, rlsContext: nil)
        return rowsValue(result["rows"])
    }

    private func rowsValue(_ value: DatabaseCore.AnyCodable?) -> [[String: DatabaseCore.AnyCodable]] {
        guard case .array(let array)? = value else { return [] }
        return array.compactMap { entry in
            if case .dictionary(let dict) = entry { return dict }
            return nil
        }
    }

    private func stringValue(_ value: DatabaseCore.AnyCodable?) -> String? {
        switch value {
        case .string(let string):
            return string
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .date(let date):
            return iso8601String(date)
        case .array, .dictionary, .null, .none:
            return nil
        }
    }

    private func makeObservation(from row: [String: DatabaseCore.AnyCodable]) -> MemoryObservation? {
        guard
            let id = uuidValue(row["id"]),
            let sessionId = stringValue(row["session_id"]),
            let tenantId = stringValue(row["tenant_id"]),
            let typeRaw = stringValue(row["observation_type"]),
            let timestamp = dateValue(row["timestamp"]),
            let sourceRaw = stringValue(row["source"]),
            let eventData = stringValue(row["event_data"])
        else {
            return nil
        }

        let toolCallID = stringValue(row["tool_call_id"])
        let toolCall: ToolCall?
        if let id = toolCallID {
            guard let name = stringValue(row["tool_call_name"]) else { return nil }
            let arguments = decodeStringDictionary(stringValue(row["tool_call_args"]))
            toolCall = ToolCall(id: id, name: name, arguments: arguments)
        } else {
            toolCall = nil
        }

        let result: ObservationResult?
        if let success = boolValue(row["result_success"]) {
            result = ObservationResult(
                success: success,
                output: stringValue(row["result_output"]),
                durationMs: intValue(row["result_duration_ms"]),
                metrics: decodeDoubleDictionary(stringValue(row["result_metrics"]))
            )
        } else {
            result = nil
        }

        let error: ObservationError?
        if let domain = stringValue(row["error_domain"]) {
            error = ObservationError(
                domain: domain,
                code: intValue(row["error_code"]) ?? 0,
                message: stringValue(row["error_message"]) ?? "",
                stackTrace: stringValue(row["error_stack_trace"]),
                isRecoverable: boolValue(row["error_recoverable"]) ?? false
            )
        } else {
            error = nil
        }

        return MemoryObservation(
            id: id,
            sessionId: sessionId,
            tenantId: tenantId,
            observationType: ObservationType(rawValue: typeRaw) ?? .systemEvent,
            timestamp: timestamp,
            source: ObservationSource(rawValue: sourceRaw) ?? .system,
            eventData: eventData,
            toolCall: toolCall,
            result: result,
            error: error,
            tags: decodeStringArray(stringValue(row["tags"])),
            metadata: decodeStringDictionary(stringValue(row["metadata"])),
            isSensitive: boolValue(row["is_sensitive"]) ?? false
        )
    }

    private func makeSummary(from row: [String: DatabaseCore.AnyCodable]) -> MemorySessionSummary? {
        guard
            let id = uuidValue(row["id"]),
            let sessionId = stringValue(row["session_id"]),
            let tenantId = stringValue(row["tenant_id"]),
            let sessionStart = dateValue(row["session_start"]),
            let observationCount = intValue(row["observation_count"]),
            let toolCallCount = intValue(row["tool_call_count"]),
            let toolSuccessCount = intValue(row["tool_success_count"]),
            let toolErrorCount = intValue(row["tool_error_count"]),
            let decisionCount = intValue(row["decision_count"]),
            let updatedAt = dateValue(row["updated_at"])
        else {
            return nil
        }

        return MemorySessionSummary(
            id: id,
            sessionId: sessionId,
            tenantId: tenantId,
            sessionStart: sessionStart,
            sessionEnd: dateValue(row["session_end"]),
            observationCount: observationCount,
            toolCallCount: toolCallCount,
            toolSuccessCount: toolSuccessCount,
            toolErrorCount: toolErrorCount,
            decisionCount: decisionCount,
            sessionTags: decodeStringArray(stringValue(row["session_tags"])),
            agentId: stringValue(row["agent_id"]),
            mode: stringValue(row["mode"]),
            model: stringValue(row["model"]),
            isSensitive: boolValue(row["is_sensitive"]) ?? false,
            summaryText: stringValue(row["summary_text"]),
            updatedAt: updatedAt
        )
    }

    private func observationInsertParameters(_ observation: MemoryObservation) -> [String] {
        [
            observation.id.uuidString,
            observation.sessionId,
            observation.tenantId,
            observation.observationType.rawValue,
            iso8601String(observation.timestamp),
            observation.source.rawValue,
            observation.eventData,
            observation.toolCall?.id ?? "__ANIGMA_NULL__",
            observation.toolCall?.name ?? "__ANIGMA_NULL__",
            observation.toolCall.map { encodeJSON($0.arguments) } ?? "__ANIGMA_NULL__",
            observation.result.map { $0.success ? "true" : "false" } ?? "__ANIGMA_NULL__",
            observation.result?.output ?? "__ANIGMA_NULL__",
            observation.result.map { String($0.durationMs ?? 0) } ?? "__ANIGMA_NULL__",
            observation.result.map(encodeJSON) ?? "__ANIGMA_NULL__",
            observation.error?.domain ?? "__ANIGMA_NULL__",
            observation.error.map { String($0.code) } ?? "__ANIGMA_NULL__",
            observation.error?.message ?? "__ANIGMA_NULL__",
            observation.error?.stackTrace ?? "__ANIGMA_NULL__",
            observation.error.map { $0.isRecoverable ? "true" : "false" } ?? "__ANIGMA_NULL__",
            encodeJSONArray(observation.tags),
            encodeJSON(observation.metadata),
            observation.isSensitive ? "true" : "false",
            iso8601String(Date())
        ]
    }

    private func sessionSummaryInsertParameters(_ summary: MemorySessionSummary) -> [String] {
        [
            summary.id.uuidString,
            summary.sessionId,
            summary.tenantId,
            iso8601String(summary.sessionStart),
            summary.sessionEnd.map(iso8601String) ?? "__ANIGMA_NULL__",
            String(summary.observationCount),
            String(summary.toolCallCount),
            String(summary.toolSuccessCount),
            String(summary.toolErrorCount),
            String(summary.decisionCount),
            encodeJSONArray(summary.sessionTags),
            summary.agentId ?? "__ANIGMA_NULL__",
            summary.mode ?? "__ANIGMA_NULL__",
            summary.model ?? "__ANIGMA_NULL__",
            summary.isSensitive ? "true" : "false",
            summary.summaryText ?? "__ANIGMA_NULL__",
            iso8601String(summary.updatedAt),
            iso8601String(Date())
        ]
    }

    private func intValue(_ value: DatabaseCore.AnyCodable?) -> Int? {
        switch value {
        case .int(let int):
            return int
        case .double(let double):
            return Int(double)
        case .string(let string):
            return Int(string)
        default:
            return nil
        }
    }

    private func boolValue(_ value: DatabaseCore.AnyCodable?) -> Bool? {
        switch value {
        case .bool(let bool):
            return bool
        case .string(let string):
            return Bool(string)
        default:
            return nil
        }
    }

    private func uuidValue(_ value: DatabaseCore.AnyCodable?) -> UUID? {
        guard let string = stringValue(value) else { return nil }
        return UUID(uuidString: string)
    }

    private func dateValue(_ value: DatabaseCore.AnyCodable?) -> Date? {
        guard let string = stringValue(value) else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: string) {
            return date
        }
        if let interval = Double(string) {
            return Date(timeIntervalSince1970: interval)
        }
        return nil
    }

    private func decodeStringArray(_ json: String?) -> [String] {
        guard
            let json,
            let data = json.data(using: .utf8),
            let array = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return array
    }

    private func decodeStringDictionary(_ json: String?) -> [String: String] {
        guard
            let json,
            let data = json.data(using: .utf8),
            let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return dict
    }

    private func decodeDoubleDictionary(_ json: String?) -> [String: Double] {
        guard
            let json,
            let data = json.data(using: .utf8),
            let dict = try? JSONDecoder().decode([String: Double].self, from: data)
        else {
            return [:]
        }
        return dict
    }

    private func encodeJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func encodeJSONArray(_ array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

public struct DatabaseStats: Sendable {
    public let observationCount: Int
    public let summaryCount: Int
    public let activeSessions: Int
    public let databasePath: String
}
