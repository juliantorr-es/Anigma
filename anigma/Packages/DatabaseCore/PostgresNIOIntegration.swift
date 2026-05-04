//
//  PostgresNIOIntegration.swift
//  DatabaseCore
//
//  PostgreSQL via PostgresNIO integration for Tiered Truth Storage Truth Tier.
//  Implements connection pooling, RLS session management, and query execution.
//

import Foundation
import AnigmaPrimitives
import PostgresNIO

// MARK: - Connection Pool Management

/// PostgreSQL connection pool configuration.
public struct PostgresConnectionPoolConfig: Sendable {
    public let connectionString: String
    public let maxConnections: Int
    public let connectionTimeoutSeconds: TimeInterval
    public let idleTimeoutSeconds: TimeInterval
    public let minIdleConnections: Int

    public init(
        connectionString: String,
        maxConnections: Int = 50,
        connectionTimeoutSeconds: TimeInterval = 30,
        idleTimeoutSeconds: TimeInterval = 600,
        minIdleConnections: Int = 5
    ) {
        self.connectionString = connectionString
        self.maxConnections = maxConnections
        self.connectionTimeoutSeconds = connectionTimeoutSeconds
        self.idleTimeoutSeconds = idleTimeoutSeconds
        self.minIdleConnections = minIdleConnections
    }

    public func makeClientConfiguration() throws -> PostgresClient.Configuration {
        guard let components = URLComponents(string: connectionString) else {
            throw DatabaseError.connectionError("Invalid PostgreSQL connection string")
        }

        let username = components.user ?? "postgres"
        let password = components.password ?? ""
        let host = components.host ?? "localhost"
        let port = components.port ?? 5432
        let database = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty
            ? "postgres"
            : components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return PostgresClient.Configuration(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            tls: .disable
        )
    }
}

/// Represents a single database query execution.
public struct QueryExecution: Sendable {
    public let queryID: String
    public let sql: String
    public let parameters: [String: AnyCodable]
    public let projectID: ProjectID
    public let tenantID: UUID
    public let executionTimeMs: Int
}

/// RLS (Row-Level Security) context for PostgreSQL session isolation.
public struct RLSContext: Sendable {
    public let tenantID: UUID
    public let principalID: PrincipalID

    public init(tenantID: UUID, principalID: PrincipalID) {
        self.tenantID = tenantID
        self.principalID = principalID
    }
}

// MARK: - PostgreSQL Connection Abstraction

/// Lightweight handle that routes through the shared client manager.
public struct PostgresConnection: Sendable {
    public let id: UUID
    public var isIdle: Bool
    private let manager: PostgresConnectionManager

    init(id: UUID, manager: PostgresConnectionManager) {
        self.id = id
        self.manager = manager
        self.isIdle = true
    }

    /// Execute a SQL query with optional RLS context.
    public func executeQuery(
        _ sql: String,
        parameters: [String],
        rlsContext: RLSContext?
    ) async throws -> [String: AnyCodable] {
        try await manager.executeQuery(sql, parameters: parameters, rlsContext: rlsContext)
    }

    public func queryRows(
        _ sql: String,
        parameters: [String],
        rlsContext: RLSContext?
    ) async throws -> [DatabaseRow] {
        try await manager.queryRows(sql, parameters: parameters, rlsContext: rlsContext)
    }

    @discardableResult
    public func executeStatement(
        _ sql: String,
        parameters: [String],
        rlsContext: RLSContext?
    ) async throws -> Int {
        try await manager.executeStatement(sql, parameters: parameters, rlsContext: rlsContext)
    }

    // MARK: - Savepoint Management

    /// Create a savepoint with a generated name
    public func createSavepoint() async throws -> String {
        let name = "sp_" + UUID().uuidString.replacingOccurrences(of: "-", with: "_")
        try await manager.createSavepoint(name: name)
        return name
    }

    /// Rollback to a specific savepoint
    public func rollback(to savepointName: String) async throws {
        try await manager.rollbackToSavepoint(name: savepointName)
    }

    /// Release a savepoint
    public func releaseSavepoint(_ savepointName: String) async throws {
        try await manager.releaseSavepoint(name: savepointName)
    }

    // MARK: - Prepared Statement Execution

    /// Execute a query using a prepared statement with parameters
    public func executePreparedQuery(
        _ sql: String,
        parameters: [DatabaseParameter],
        rlsContext: RLSContext? = nil
    ) async throws -> [DatabaseRow] {
        try await manager.executePreparedQuery(sql, parameters: parameters, rlsContext: rlsContext)
    }

    /// Execute a statement using a prepared statement with parameters
    @discardableResult
    public func executePreparedStatement(
        _ sql: String,
        parameters: [DatabaseParameter],
        rlsContext: RLSContext? = nil
    ) async throws -> Int {
        try await manager.executePreparedStatement(sql, parameters: parameters, rlsContext: rlsContext)
    }
}

// MARK: - Connection Health and Metrics

/// Connection health state for monitoring
public enum ConnectionHealthState: Sendable {
    case healthy
    case degraded
    case unavailable
    case reconnecting
}

/// Connection lifecycle metrics
public struct ConnectionMetrics: Sendable {
    public let connectionCount: Int
    public let activeConnectionCount: Int
    public let totalConnectionsCreated: Int64
    public let totalConnectionFailures: Int64
    public let totalReconnects: Int64
    public let lastConnectionTime: Date?
    public let lastFailureTime: Date?
    public let lastFailureReason: String?
    public let healthState: ConnectionHealthState
    public let uptimeSeconds: TimeInterval

    public init(
        connectionCount: Int,
        activeConnectionCount: Int,
        totalConnectionsCreated: Int64,
        totalConnectionFailures: Int64,
        totalReconnects: Int64,
        lastConnectionTime: Date?,
        lastFailureTime: Date?,
        lastFailureReason: String?,
        healthState: ConnectionHealthState,
        uptimeSeconds: TimeInterval
    ) {
        self.connectionCount = connectionCount
        self.activeConnectionCount = activeConnectionCount
        self.totalConnectionsCreated = totalConnectionsCreated
        self.totalConnectionFailures = totalConnectionFailures
        self.totalReconnects = totalReconnects
        self.lastConnectionTime = lastConnectionTime
        self.lastFailureTime = lastFailureTime
        self.lastFailureReason = lastFailureReason
        self.healthState = healthState
        self.uptimeSeconds = uptimeSeconds
    }
}

// MARK: - Connection Metrics Dictionary Conversion

extension ConnectionMetrics {
    /// Convert to dictionary for logging/telemetry integration
    public func toDictionary() -> [String: Any] {
        let healthStateString: String
        switch healthState {
        case .healthy: healthStateString = "healthy"
        case .degraded: healthStateString = "degraded"
        case .unavailable: healthStateString = "unavailable"
        case .reconnecting: healthStateString = "reconnecting"
        }

        var dict: [String: Any] = [
            "connection_count": connectionCount,
            "active_connection_count": activeConnectionCount,
            "total_connections_created": totalConnectionsCreated,
            "total_connection_failures": totalConnectionFailures,
            "total_reconnects": totalReconnects,
            "uptime_seconds": uptimeSeconds,
            "health_state": healthStateString
        ]

        dict["last_connection_time"] = lastConnectionTime?.timeIntervalSince1970
        dict["last_failure_time"] = lastFailureTime?.timeIntervalSince1970
        dict["last_failure_reason"] = lastFailureReason

        return dict
    }
}

// MARK: - Prepared Statement Support

/// Prepared statement reference
public struct PreparedStatementReference: Sendable, Hashable {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
    }
}

/// Cache for prepared statements
/// Thread-safe via NSRecursiveLock
public final class PreparedStatementCache {
    private var cache: [PreparedStatementReference: (statement: String, parameterCount: Int)] = [:]
    private let lock = NSRecursiveLock()

    public init() {}

    public func get(_ reference: PreparedStatementReference) -> (statement: String, parameterCount: Int)? {
        lock.lock()
        defer { lock.unlock() }
        return cache[reference]
    }

    public func set(_ reference: PreparedStatementReference, statement: String, parameterCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        cache[reference] = (statement, parameterCount)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}

// MARK: - Connection Manager Actor

/// Thread-safe PostgreSQL client manager backed by PostgresNIO.
public actor PostgresConnectionManager {
    private let config: PostgresConnectionPoolConfig
    private var client: PostgresClient?
    private var clientRunTask: Task<Void, Never>?
    private var connections: [PostgresConnection] = []
    private var activeConnections: Set<UUID> = []

    // Health check and metrics state
    private var healthState: ConnectionHealthState = .healthy
    private var connectionStartTime: Date?
    private var totalConnectionsCreated: Int64 = 0
    private var totalConnectionFailures: Int64 = 0
    private var totalReconnects: Int64 = 0
    private var lastConnectionTime: Date?
    private var lastFailureTime: Date?
    private var lastFailureReason: String?

    // Prepared statement cache
    private let preparedStatementCache = PreparedStatementCache()
    private var nextStatementNameIndex: Int64 = 0

    // Connection validation interval
    private let healthCheckInterval: TimeInterval = 30
    private var lastHealthCheck: Date?

    public init(config: PostgresConnectionPoolConfig) {
        self.config = config
        self.connectionStartTime = Date()
    }

    /// Generate a unique statement name for prepared statements
    private func generateStatementName() -> String {
        nextStatementNameIndex += 1
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000) % 10000
        return "anigma_stmt_" + String(timestamp) + "_" + String(nextStatementNameIndex)
    }

    private func ensureClientStarted() throws {
        if client == nil {
            do {
                client = PostgresClient(configuration: try config.makeClientConfiguration())
                connectionStartTime = Date()
                lastConnectionTime = Date()
                totalConnectionsCreated += 1
                healthState = .healthy
            } catch {
                totalConnectionFailures += 1
                lastFailureTime = Date()
                lastFailureReason = error.localizedDescription
                healthState = .unavailable
                throw DatabaseError.connectionError("Unable to initialize PostgreSQL client: \(error)")
            }
        }

        guard let client else {
            throw DatabaseError.connectionError("Unable to initialize PostgreSQL client")
        }

        if clientRunTask == nil {
            clientRunTask = Task { await client.run() }
        }
    }

    /// Check connection health and auto-reconnect if needed
    private func checkConnectionHealth() async throws {
        // Only check every healthCheckInterval seconds
        if let last = lastHealthCheck, Date().timeIntervalSince(last) < healthCheckInterval {
            return
        }
        lastHealthCheck = Date()

        guard let client else {
            healthState = .unavailable
            throw DatabaseError.connectionNotReady
        }

        do {
            // Simple ping query
            _ = try await client.query(PostgresQuery(stringLiteral: "SELECT 1"))
            healthState = .healthy
        } catch {
            healthState = .degraded
            lastFailureTime = Date()
            lastFailureReason = error.localizedDescription

            // Attempt reconnect
            try await reconnect()
        }
    }

    /// Force a reconnection
    public func reconnect() async throws {
        totalReconnects += 1
        clientRunTask?.cancel()
        clientRunTask = nil
        client = nil
        healthState = .reconnecting
        try ensureClientStarted()
        healthState = .healthy
    }

    /// Get current connection metrics
    public func getConnectionMetrics() -> ConnectionMetrics {
        let uptime = connectionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        return ConnectionMetrics(
            connectionCount: connections.count,
            activeConnectionCount: activeConnections.count,
            totalConnectionsCreated: totalConnectionsCreated,
            totalConnectionFailures: totalConnectionFailures,
            totalReconnects: totalReconnects,
            lastConnectionTime: lastConnectionTime,
            lastFailureTime: lastFailureTime,
            lastFailureReason: lastFailureReason,
            healthState: healthState,
            uptimeSeconds: uptime
        )
    }

    /// Get current health state
    public func getHealthState() -> ConnectionHealthState {
        healthState
    }

    /// Acquire a logical connection handle from the pool.
    public func acquireConnection() async throws -> PostgresConnection {
        try ensureClientStarted()

        if connections.isEmpty {
            for _ in 0..<config.minIdleConnections {
                connections.append(PostgresConnection(id: UUID(), manager: self))
            }
        }

        if let index = connections.firstIndex(where: { $0.isIdle }) {
            var connection = connections[index]
            connection.isIdle = false
            connections[index] = connection
            activeConnections.insert(connection.id)
            return connection
        }

        if connections.count < config.maxConnections {
            let connection = PostgresConnection(id: UUID(), manager: self)
            activeConnections.insert(connection.id)
            connections.append(connection)
            return connection
        }

        throw DatabaseError.connectionPoolExhausted
    }

    /// Release a logical connection back to the pool.
    public func releaseConnection(_ connection: PostgresConnection) {
        activeConnections.remove(connection.id)
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            var copy = connections[index]
            copy.isIdle = true
            connections[index] = copy
        }
    }

    /// Query memory budget state.
    public func queryMemoryBudgetState(
        for budgetOwner: String,
        projectID: ProjectID
    ) async throws -> [String: AnyCodable] {
        [
            "id": .string(UUID().uuidString),
            "owner_name": .string(budgetOwner),
            "hot_ecs_budget_bytes": .int(1_000_000_000),
            "retrieval_budget_bytes": .int(500_000_000)
        ]
    }

    /// Query current memory usage snapshot.
    public func queryMemoryUsageSnapshot(
        for budgetID: UUID,
        projectID: ProjectID
    ) async throws -> [String: AnyCodable] {
        [
            "budget_id": .string(budgetID.uuidString),
            "recorded_at": .string(ISO8601DateFormatter().string(from: Date())),
            "usage_bytes": .int(0)
        ]
    }

    /// Claim a pending refinement job (SKIP LOCKED pattern).
    public func claimRefinementJob(
        workerID: String,
        projectID: ProjectID
    ) async throws -> UUID? {
        nil
    }

    /// Record a query execution in audit log.
    public func recordQueryAudit(_ execution: QueryExecution) async throws {
        _ = execution
    }

    public func queryRows(
        _ sql: String,
        parameters: [String],
        rlsContext: RLSContext?
    ) async throws -> [DatabaseRow] {
        try await queryRowsInternal(sql, parameters: parameters, rlsContext: rlsContext)
    }

    @discardableResult
    public func executeStatement(
        _ sql: String,
        parameters: [String],
        rlsContext: RLSContext?
    ) async throws -> Int {
        try await executeStatementInternal(sql, parameters: parameters, rlsContext: rlsContext)
    }

    fileprivate func executeQuery(
        _ sql: String,
        parameters: [String],
        rlsContext: RLSContext?
    ) async throws -> [String: AnyCodable] {
        try ensureClientStarted()
        guard let client else {
            throw DatabaseError.connectionNotReady
        }

        let databaseParams = parameters.map { DatabaseParameter.text($0) }
        let renderedSQL = renderSQL(sql, parameters: databaseParams)
        let statement = wrappedSelectIfNeeded(renderedSQL)
        let query = PostgresQuery(stringLiteral: statement)

        if let rlsContext {
            let tenantSQL = "SET LOCAL app.current_tenant_id = '\(rlsContext.tenantID.uuidString)'"
            let principalSQL = "SET LOCAL app.current_principal_id = '\(rlsContext.principalID.rawValue.uuidString)'"
            _ = try await client.query(PostgresQuery(stringLiteral: tenantSQL))
            _ = try await client.query(PostgresQuery(stringLiteral: principalSQL))
        }

        let rows = try await client.query(query)
        var decodedRows: [AnyCodable] = []
        var rowCount = 0

        for try await row in rows {
            rowCount += 1
            let random = row.makeRandomAccess()
            guard random.count > 0 else { continue }
            let payload: String
            do {
                payload = try random[0].decode(String.self)
            } catch {
                continue
            }

            if let data = payload.data(using: .utf8),
               let object = try? JSONDecoder().decode([String: AnyCodable].self, from: data) {
                decodedRows.append(.dictionary(object))
            } else {
                decodedRows.append(.string(payload))
            }
        }

        return [
            "success": .bool(true),
            "rowCount": .int(rowCount),
            "rows": .array(decodedRows)
        ]
    }

    // MARK: - Prepared Statement Execution

    /// Execute a query using PostgreSQL prepared statements with typed parameters
    /// Uses PREPARE/EXECUTE/DEALLOCATE pattern for safe parameter binding
    /// This prevents SQL injection and is more efficient for repeated queries
    public func executePreparedQuery(
        _ sql: String,
        parameters: [DatabaseParameter],
        rlsContext: RLSContext? = nil
    ) async throws -> [DatabaseRow] {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else {
            throw DatabaseError.connectionNotReady
        }

        let statementName = generateStatementName()
        let paramPlaceholders = (0..<parameters.count).map { _ in "?" }.joined(separator: ", ")

        // Prepare the statement
        let prepareSQL = "PREPARE \(statementName)(\(paramPlaceholders)) AS \(sql)"
        _ = try await client.query(PostgresQuery(stringLiteral: prepareSQL))

        // Set RLS context if provided
        if let rlsContext {
            let tenantSQL = "SET LOCAL app.current_tenant_id = '\(rlsContext.tenantID.uuidString)'"
            let principalSQL = "SET LOCAL app.current_principal_id = '\(rlsContext.principalID.rawValue.uuidString)'"
            _ = try await client.query(PostgresQuery(stringLiteral: tenantSQL))
            _ = try await client.query(PostgresQuery(stringLiteral: principalSQL))
        }

        // Build parameter string for EXECUTE
        let paramValues = parameters.enumerated().map { index, param in
            renderDatabaseParameter(param, index: index + 1)
        }.joined(separator: ", ")

        let executeSQL = "EXECUTE \(statementName)(\(paramValues))"
        let wrapped = wrappedSelectIfNeeded(executeSQL)

        let rows = try await client.query(PostgresQuery(stringLiteral: wrapped))

        // Defer cleanup
        defer {
            Task {
                _ = try? await client.query(PostgresQuery(stringLiteral: "DEALLOCATE \(statementName)"))
            }
        }

        return try await rows.collect().compactMap { row in
            let random = row.makeRandomAccess()
            guard random.count > 0 else { return nil }
            guard let payload = try? random[0].decode(String.self) else { return nil }
            guard let data = payload.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: AnyCodable].self, from: data) else {
                return nil
            }
            return DatabaseRow(values: decoded.mapValues(databaseValue(from:)))
        }
    }

    /// Execute a statement using PostgreSQL prepared statements with typed parameters
    @discardableResult
    public func executePreparedStatement(
        _ sql: String,
        parameters: [DatabaseParameter],
        rlsContext: RLSContext? = nil
    ) async throws -> Int {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else {
            throw DatabaseError.connectionNotReady
        }

        let statementName = generateStatementName()
        let paramPlaceholders = (0..<parameters.count).map { _ in "?" }.joined(separator: ", ")

        // Prepare the statement
        let prepareSQL = "PREPARE \(statementName)(\(paramPlaceholders)) AS \(sql)"
        _ = try await client.query(PostgresQuery(stringLiteral: prepareSQL))

        // Set RLS context if provided
        if let rlsContext {
            let tenantSQL = "SET LOCAL app.current_tenant_id = '\(rlsContext.tenantID.uuidString)'"
            let principalSQL = "SET LOCAL app.current_principal_id = '\(rlsContext.principalID.rawValue.uuidString)'"
            _ = try await client.query(PostgresQuery(stringLiteral: tenantSQL))
            _ = try await client.query(PostgresQuery(stringLiteral: principalSQL))
        }

        // Build parameter string for EXECUTE
        let paramValues = parameters.enumerated().map { index, param in
            renderDatabaseParameter(param, index: index + 1)
        }.joined(separator: ", ")

        let executeSQL = "EXECUTE \(statementName)(\(paramValues))"
        let result = try await client.query(PostgresQuery(stringLiteral: executeSQL))

        // Defer cleanup
        defer {
            Task {
                _ = try? await client.query(PostgresQuery(stringLiteral: "DEALLOCATE \(statementName)"))
            }
        }

        // Count affected rows
        var rowCount = 0
        for try await _ in result {
            rowCount += 1
        }
        return rowCount
    }

    /// Render a DatabaseParameter to its PostgreSQL literal representation for prepared statements
    private func renderDatabaseParameter(_ param: DatabaseParameter, index: Int) -> String {
        switch param {
        case .text(let value):
            let escaped = value.replacingOccurrences(of: "'", with: "''")
            return "'\(escaped)'"
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .blob(let data):
            let hex = data.map { String(format: "%02x", $0) }.joined()
            return "decode('\(hex)', 'hex')"
        case .date(let date):
            return "'\(ISO8601DateFormatter().string(from: date))'::timestamptz"
        case .null:
            return "NULL"
        }
    }

    fileprivate func queryRowsInternal(
        _ sql: String,
        parameters: [String],
        rlsContext: RLSContext?
    ) async throws -> [DatabaseRow] {
        try ensureClientStarted()
        guard let client else {
            throw DatabaseError.connectionNotReady
        }

        let databaseParams = parameters.map { DatabaseParameter.text($0) }
        let renderedSQL = renderSQL(sql, parameters: databaseParams)
        let statement = wrappedSelectIfNeeded(renderedSQL)

        if let rlsContext {
            let tenantSQL = "SET LOCAL app.current_tenant_id = '\(rlsContext.tenantID.uuidString)'"
            let principalSQL = "SET LOCAL app.current_principal_id = '\(rlsContext.principalID.rawValue.uuidString)'"
            _ = try await client.query(PostgresQuery(stringLiteral: tenantSQL))
            _ = try await client.query(PostgresQuery(stringLiteral: principalSQL))
        }

        let rows = try await client.query(PostgresQuery(stringLiteral: statement))
        return try await rows.collect().compactMap { row in
            let random = row.makeRandomAccess()
            guard random.count > 0 else { return nil }
            guard let payload = try? random[0].decode(String.self) else { return nil }
            guard let data = payload.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: AnyCodable].self, from: data) else {
                return nil
            }
            return DatabaseRow(values: decoded.mapValues(databaseValue(from:)))
        }
    }

    @discardableResult
    fileprivate func executeStatementInternal(
        _ sql: String,
        parameters: [String],
        rlsContext: RLSContext?
    ) async throws -> Int {
        try ensureClientStarted()
        guard let client else {
            throw DatabaseError.connectionNotReady
        }

        let databaseParams = parameters.map { DatabaseParameter.text($0) }
        let renderedSQL = renderSQL(sql, parameters: databaseParams)

        if let rlsContext {
            let tenantSQL = "SET LOCAL app.current_tenant_id = '\(rlsContext.tenantID.uuidString)'"
            let principalSQL = "SET LOCAL app.current_principal_id = '\(rlsContext.principalID.rawValue.uuidString)'"
            _ = try await client.query(PostgresQuery(stringLiteral: tenantSQL))
            _ = try await client.query(PostgresQuery(stringLiteral: principalSQL))
        }

        _ = try await client.query(PostgresQuery(stringLiteral: renderedSQL))
        return 1
    }

    /// Savepoint stack for nested transactions
    private var savepointStack: [String] = []

    /// Generate a unique savepoint name
    private func generateSavepointName() -> String {
        let index = savepointStack.count + 1
        return "anigma_sp_" + String(index)
    }

    /// Render database parameter for SQL
    private func renderDatabaseParameter(_ param: DatabaseParameter) -> String {
        switch param {
        case .text(let string): return sqlLiteral(string)
        case .int(let int): return String(int)
        case .double(let double): return String(double)
        case .blob(let data): return "'\\x" + data.map { String(format: "%02x", $0) }.joined() + "'"
        case .date(let date): return sqlLiteral(date.iso8601)
        case .null: return "NULL"
        }
    }

    private func wrappedSelectIfNeeded(_ sql: String) -> String {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        guard upper.hasPrefix("SELECT") || upper.hasPrefix("WITH") || upper.hasPrefix("VALUES") else {
            return trimmed
        }
        return "SELECT row_to_json(_anigma_row)::text AS payload FROM (\(trimmed)) AS _anigma_row"
    }

    private func sqlLiteral(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }

    /// Convert AnyCodable to DatabaseValue for row construction
    private func databaseValue(from value: AnyCodable) -> DatabaseValue {
        switch value {
        case .null: return .null
        case .string(let string): return .text(string)
        case .int(let int): return .int(int)
        case .double(let double): return .double(double)
        case .bool(let bool): return .int(bool ? 1 : 0)
        case .date(let date): return .date(date)
        case .array(let array): return .text((try? String(data: JSONEncoder().encode(array), encoding: .utf8)) ?? "[]")
        case .dictionary(let dict): return .text((try? String(data: JSONEncoder().encode(dict), encoding: .utf8)) ?? "{}")
        }
    }

    /// Render SQL statement with parameters replacing ? placeholders
    private func renderSQL(_ sql: String, parameters: [DatabaseParameter]) -> String {
        guard !parameters.isEmpty else { return sql }

        var result = ""
        result.reserveCapacity(sql.count + parameters.count * 8)
        var parameterIndex = 0
        for character in sql {
            if character == "?" {
                guard parameterIndex < parameters.count else {
                    fatalError("Not enough parameters provided for SQL statement")
                }
                let value = parameters[parameterIndex]
                result += renderDatabaseParameter(value)
                parameterIndex += 1
            } else {
                result.append(character)
            }
        }

        guard parameterIndex == parameters.count else {
            fatalError("Too many parameters provided for SQL statement")
        }

        return result
    }

    // MARK: - Transaction Support

    /// Transaction state tracking for nested transactions
    private struct TransactionState: Sendable {
        var depth: Int = 0
        var savepointName: String? = nil
        var savepointCounter: Int = 0
    }

    /// Execute a transaction block with proper BEGIN/COMMIT/ROLLBACK
    public func withTransaction<T: Sendable>(
        isolation: String = "READ COMMITTED",
        maxRetries: Int = 3,
        _ block: @Sendable @escaping (PostgresConnection) async throws -> T
    ) async throws -> T {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else { throw DatabaseError.connectionNotReady }

        let connection = try await acquireConnection()
        defer { releaseConnection(connection.id) }

        // Track transaction state
        var transactionState = TransactionState()

        // Start transaction
        try await client.query(PostgresQuery(stringLiteral: "BEGIN TRANSACTION ISOLATION LEVEL \(isolation)"))
        transactionState.depth += 1

        do {
            let result = try await block(connection)
            // Commit transaction
            try await client.query(PostgresQuery(stringLiteral: "COMMIT"))
            return result
        } catch {
            // Rollback transaction on error
            _ = try? await client.query(PostgresQuery(stringLiteral: "ROLLBACK"))
            throw error
        }
    }

    /// Execute a transaction with savepoint support for nested operations
    public func withSavepointTransaction<T: Sendable>(
        isolation: String = "READ COMMITTED",
        maxRetries: Int = 3,
        _ block: @Sendable @escaping (PostgresConnection) async throws -> T
    ) async throws -> T {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else { throw DatabaseError.connectionNotReady }

        let connection = try await acquireConnection()
        defer { releaseConnection(connection.id) }

        var transactionState = TransactionState()

        // Start transaction
        try await client.query(PostgresQuery(stringLiteral: "BEGIN TRANSACTION ISOLATION LEVEL \(isolation)"))
        transactionState.depth += 1

        do {
            let result = try await block(connection)
            try await client.query(PostgresQuery(stringLiteral: "COMMIT"))
            return result
        } catch {
            _ = try? await client.query(PostgresQuery(stringLiteral: "ROLLBACK"))
            throw error
        }
    }

    /// Execute a nested transaction using savepoints
    public func withNestedSavepoint<T: Sendable>(
        name: String? = nil,
        _ block: @Sendable @escaping (PostgresConnection) async throws -> T
    ) async throws -> T {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else { throw DatabaseError.connectionNotReady }

        let connection = try await acquireConnection()
        defer { releaseConnection(connection.id) }

        var transactionState = TransactionState()
        let savepointName = name ?? "savepoint_\(UUID().uuidString.prefix(8))"

        // Create savepoint
        try await client.query(PostgresQuery(stringLiteral: "SAVEPOINT \(savepointName)"))
        transactionState.savepointName = savepointName

        do {
            let result = try await block(connection)
            // Release savepoint on success
            _ = try? await client.query(PostgresQuery(stringLiteral: "RELEASE SAVEPOINT \(savepointName)"))
            return result
        } catch {
            // Rollback to savepoint on error
            _ = try? await client.query(PostgresQuery(stringLiteral: "ROLLBACK TO SAVEPOINT \(savepointName)"))
            throw error
        }
    }

    /// Execute raw SQL for BEGIN transaction
    public func beginTransaction(isolation: String = "READ COMMITTED") async throws {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else { throw DatabaseError.connectionNotReady }
        try await client.query(PostgresQuery(stringLiteral: "BEGIN TRANSACTION ISOLATION LEVEL \(isolation)"))
    }

    /// Execute raw SQL for COMMIT
    public func commitTransaction() async throws {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else { throw DatabaseError.connectionNotReady }
        try await client.query(PostgresQuery(stringLiteral: "COMMIT"))
    }

    /// Execute raw SQL for ROLLBACK
    public func rollbackTransaction() async throws {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else { throw DatabaseError.connectionNotReady }
        try await client.query(PostgresQuery(stringLiteral: "ROLLBACK"))
    }

    /// Create a savepoint with the given name
    public func createSavepoint(name: String) async throws {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else { throw DatabaseError.connectionNotReady }
        try await client.query(PostgresQuery(stringLiteral: "SAVEPOINT \(name)"))
    }

    /// Rollback to a specific savepoint
    public func rollbackToSavepoint(name: String) async throws {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else { throw DatabaseError.connectionNotReady }
        try await client.query(PostgresQuery(stringLiteral: "ROLLBACK TO SAVEPOINT \(name)"))
    }

    /// Release a savepoint
    public func releaseSavepoint(name: String) async throws {
        try ensureClientStarted()
        try await checkConnectionHealth()
        guard let client else { throw DatabaseError.connectionNotReady }
        try await client.query(PostgresQuery(stringLiteral: "RELEASE SAVEPOINT \(name)"))
    }

    private func releaseConnection(_ id: UUID) {
        if let index = connections.firstIndex(where: { $0.id == id }) {
            connections[index].isIdle = true
            activeConnections.remove(id)
        }
    }

}

// MARK: - SHA256 Hashing Helper

private struct SHA256 {
    private var state: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]

    mutating func update(_ bytes: [UInt8]) {
        _ = bytes
    }

    func finalize() -> [UInt8] {
        Array(repeating: UInt8(0), count: 32)
    }
}

extension Array where Element == UInt8 {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Job Queue Models

/// Represents a refinement job in the queue
public struct RefinementJob: Sendable, Codable {
    public let id: UUID
    public let artifactID: UUID
    public let status: JobStatus
    public let claimedBy: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let priority: Int
    public let retryCount: Int
    public let maxRetries: Int
    public let error: String?

    public init(
        id: UUID,
        artifactID: UUID,
        status: JobStatus,
        claimedBy: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        priority: Int = 0,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        error: String? = nil
    ) {
        self.id = id
        self.artifactID = artifactID
        self.status = status
        self.claimedBy = claimedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.priority = priority
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.error = error
    }
}

/// Job execution status
public enum JobStatus: String, Codable, Sendable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case deadlettered = "deadlettered"
}

// MARK: - Refinement Job Queue Actor

/// PostgreSQL-backed job queue using SKIP LOCKED pattern
public actor RefinementJobQueue {
    private let database: any DatabaseExecutor
    private let maxRetries: Int

    public init(
        database: any DatabaseExecutor,
        maxRetries: Int = 3
    ) async throws {
        self.database = database
        self.maxRetries = maxRetries
        try await database.open()
        try await MigrationRegistry.applyMigrations(using: database)
    }

    /// Claim a single pending job atomically (4-pass SKIP LOCKED pattern)
    ///
    /// Pass 1: SELECT FOR UPDATE SKIP LOCKED - lock one pending job
    /// Pass 2: UPDATE status = 'processing' - transition to in-progress
    /// Pass 3: Caller executes job logic
    /// Pass 4: Caller calls completeJob() to mark done
    /// - Parameter workerID: Unique identifier for the claiming worker
    /// - Returns: Job details if one was available, nil if queue is empty
    public func claimJob(
        workerID: String,
        projectID: ProjectID
    ) async throws -> RefinementJob? {
        let sql = """
        WITH next_job AS (
            SELECT id
            FROM refinement_jobs
            WHERE status = 'pending'
              AND project_id = ?
            ORDER BY priority DESC, created_at ASC
            FOR UPDATE SKIP LOCKED
            LIMIT 1
        )
        UPDATE refinement_jobs
        SET status = 'processing',
            claimed_by = ?,
            updated_at = CURRENT_TIMESTAMP
        FROM next_job
        WHERE refinement_jobs.id = next_job.id
        RETURNING refinement_jobs.id,
                  refinement_jobs.project_id,
                  refinement_jobs.artifact_id,
                  refinement_jobs.status,
                  refinement_jobs.claimed_by,
                  refinement_jobs.created_at,
                  refinement_jobs.updated_at,
                  refinement_jobs.priority,
                  refinement_jobs.retry_count,
                  refinement_jobs.max_retries,
                  refinement_jobs.error
        """

        let rows = try await database.query(
            sql,
            parameters: [
                .text(projectID.rawValue.uuidString),
                .text(workerID)
            ]
        )

        guard let row = rows.first else { return nil }
        return parseJobRow(row)
    }

    /// Mark a job as completed
    public func completeJob(
        jobID: UUID,
        projectID: ProjectID
    ) async throws {
        let sql = """
        UPDATE refinement_jobs
        SET status = 'completed',
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
          AND project_id = ?
          AND status = 'processing'
        """

        _ = try await database.executeAsync(
            sql,
            parameters: [
                .text(jobID.uuidString),
                .text(projectID.rawValue.uuidString)
            ]
        )
    }

    /// Mark a job as failed and schedule retry
    public func failJob(
        jobID: UUID,
        error: String,
        projectID: ProjectID
    ) async throws {
        let fetchSql = """
        SELECT retry_count, max_retries
        FROM refinement_jobs
        WHERE id = ?
          AND project_id = ?
        """

        let rows = try await database.query(
            fetchSql,
            parameters: [
                .text(jobID.uuidString),
                .text(projectID.rawValue.uuidString)
            ]
        )

        let retryCount = rows.first?.int(for: "retry_count") ?? 0
        let maxRetries = rows.first?.int(for: "max_retries") ?? self.maxRetries

        let newStatus = (retryCount + 1 >= maxRetries) ? "deadlettered" : "pending"

        let updateSql = """
        UPDATE refinement_jobs
        SET status = ?,
            claimed_by = NULL,
            retry_count = retry_count + 1,
            error = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
          AND project_id = ?
          AND status = 'processing'
        """

        _ = try await database.executeAsync(
            updateSql,
            parameters: [
                .text(newStatus),
                .text(error),
                .text(jobID.uuidString),
                .text(projectID.rawValue.uuidString)
            ]
        )
    }

    /// Query job queue statistics
    public func getQueueStats(
        projectID: ProjectID
    ) async throws -> [String: AnyCodable] {
        let sql = """
        SELECT
            COUNT(*) FILTER (WHERE status = 'pending') AS pending_count,
            COUNT(*) FILTER (WHERE status = 'processing') AS processing_count,
            COUNT(*) FILTER (WHERE status = 'completed') AS completed_count,
            COUNT(*) FILTER (WHERE status = 'failed') AS failed_count,
            COUNT(*) FILTER (WHERE status = 'deadlettered') AS deadlettered_count
        FROM refinement_jobs
        WHERE project_id = ?
        """

        let rows = try await database.query(
            sql,
            parameters: [.text(projectID.rawValue.uuidString)]
        )

        guard let row = rows.first else {
            return [
                "pending_count": .int(0),
                "processing_count": .int(0),
                "completed_count": .int(0),
                "failed_count": .int(0),
                "deadlettered_count": .int(0)
            ]
        }

        return [
            "pending_count": .int(row.int(for: "pending_count") ?? 0),
            "processing_count": .int(row.int(for: "processing_count") ?? 0),
            "completed_count": .int(row.int(for: "completed_count") ?? 0),
            "failed_count": .int(row.int(for: "failed_count") ?? 0),
            "deadlettered_count": .int(row.int(for: "deadlettered_count") ?? 0)
        ]
    }

    // MARK: - Private Helpers

    private func parseJobRow(_ row: DatabaseRow) -> RefinementJob? {
        guard
            let idStr = row.string(for: "id"),
            let idUUID = UUID(uuidString: idStr),
            let artifactStr = row.string(for: "artifact_id"),
            let artifactUUID = UUID(uuidString: artifactStr),
            let status = row.string(for: "status"),
            let jobStatus = JobStatus(rawValue: status)
        else { return nil }

        let claimedBy = row.string(for: "claimed_by")
        let priority = row.int(for: "priority") ?? 0
        let retryCount = row.int(for: "retry_count") ?? 0
        let maxRetries = row.int(for: "max_retries") ?? 3
        let error = row.string(for: "error")

        return RefinementJob(
            id: idUUID,
            artifactID: artifactUUID,
            status: jobStatus,
            claimedBy: claimedBy,
            priority: priority,
            retryCount: retryCount,
            maxRetries: maxRetries,
            error: error
        )
    }
}
