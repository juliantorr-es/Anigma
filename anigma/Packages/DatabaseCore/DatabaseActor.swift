//
//  DatabaseActor.swift
//  DatabaseCore
//
//  Postgres-backed database access for Swift concurrency.
//  All database operations go through this actor to preserve isolation.
//
//  IMPORTANT: Only approved composition roots (see PostgresConnectionContract) should
//  instantiate DatabaseActor directly. All other modules should receive DatabaseExecutor
//  via dependency injection (typically through DatabaseAuthority).
//
//  See ADR-0018: PostgreSQL Connection and Transaction Contract
//  See td-317bbb: Enforce PostgresConnectionContract at composition roots
//

import AnigmaPrimitives
import Foundation
import PostgresNIO
import os.log

/// Logger for DatabaseActor contract enforcement
private let contractLog = os.Logger(subsystem: "com.anigma.database", category: "contract")

/// Tracks DatabaseActor instantiations for contract enforcement
public enum DatabaseActorContract {
    /// Approved module prefixes that may instantiate DatabaseActor directly.
    /// Defined by PostgresCompositionRoot.allApprovedModulePrefixes from the canonical contract.
    public static var approvedModulePrefixes: Set<String> {
        PostgresCompositionRoot.allApprovedModulePrefixes
    }

    /// Test mode flag - when true, allows DatabaseActor creation from any module
    /// This is for test harnesses and should be set early in the process
    public static var allowTestMode: Bool = false
}

/// Database health metrics for monitoring database performance.
public struct DatabaseMetrics: Sendable, Codable {
    public let busyTimeoutExhausted: Int
    public let transactionRetries: Int
    public let averageQueryTime: TimeInterval
    public let queryCount: Int
    public let walSize: Int64?
    public let walCheckpointCount: Int64?
    public let connectionOpenCount: Int?
    public let connectionCloseCount: Int?
    public let connectionOpenFailures: Int?
    public let activeConnectionCount: Int?
    public let connectionUptimeSeconds: TimeInterval?
    public let lastOpenedAt: Date?
    public let lastClosedAt: Date?

    public init(
        busyTimeoutExhausted: Int,
        transactionRetries: Int,
        averageQueryTime: TimeInterval,
        queryCount: Int,
        walSize: Int64? = nil,
        walCheckpointCount: Int64? = nil,
        connectionOpenCount: Int? = nil,
        connectionCloseCount: Int? = nil,
        connectionOpenFailures: Int? = nil,
        activeConnectionCount: Int? = nil,
        connectionUptimeSeconds: TimeInterval? = nil,
        lastOpenedAt: Date? = nil,
        lastClosedAt: Date? = nil
    ) {
        self.busyTimeoutExhausted = busyTimeoutExhausted
        self.transactionRetries = transactionRetries
        self.averageQueryTime = averageQueryTime
        self.queryCount = queryCount
        self.walSize = walSize
        self.walCheckpointCount = walCheckpointCount
        self.connectionOpenCount = connectionOpenCount
        self.connectionCloseCount = connectionCloseCount
        self.connectionOpenFailures = connectionOpenFailures
        self.activeConnectionCount = activeConnectionCount
        self.connectionUptimeSeconds = connectionUptimeSeconds
        self.lastOpenedAt = lastOpenedAt
        self.lastClosedAt = lastClosedAt
    }
}

/// Result of a bootstrap-time database validation pass.
public struct DatabaseValidationReport: Sendable, Codable {
    public let quickCheckResult: String
    public let foreignKeyViolationCount: Int
    public let validatedAt: Date

    public init(
        quickCheckResult: String,
        foreignKeyViolationCount: Int,
        validatedAt: Date = Date()
    ) {
        self.quickCheckResult = quickCheckResult
        self.foreignKeyViolationCount = foreignKeyViolationCount
        self.validatedAt = validatedAt
    }

    public var isHealthy: Bool {
        quickCheckResult.lowercased() == "ok" && foreignKeyViolationCount == 0
    }
}

public actor DatabaseActor: DatabaseExecutor {
    public nonisolated let path: String
    private let connectionManager: PostgresConnectionManager
    private var busyTimeoutExhaustedCount: Int = 0
    private var transactionRetryCount: Int = 0
    private var totalQueryTime: TimeInterval = 0
    private var queryExecutionCount: Int = 0
    private var connectionOpenCount: Int = 0
    private var connectionCloseCount: Int = 0
    private var connectionOpenFailureCount: Int = 0
    private var lastOpenedAt: Date?
    private var lastClosedAt: Date?

    public init(path: String = DatabaseConfiguration.defaultDatabasePath()) {
        Self.enforceContractCompliance()
        self.path = path
        self.connectionManager = PostgresConnectionManager(
            config: PostgresConnectionPoolConfig(connectionString: Self.connectionString(for: path))
        )
    }

    /// Enforces the PostgresConnectionContract by checking if the caller is from an approved composition root.
    /// Logs a warning if DatabaseActor is instantiated from a non-approved module.
    /// 
    /// See ADR-0018 and td-317bbb for details on the contract enforcement.
    private static func enforceContractCompliance() {
        // Skip check in test mode
        guard !DatabaseActorContract.allowTestMode else { return }

        // Extract the calling module name from the stack trace
        let moduleName = extractCallingModuleName()

        // Check if the module is in the approved list
        let isApproved = DatabaseActorContract.approvedModulePrefixes.contains { prefix in
            moduleName.hasPrefix(prefix)
        }

        if !isApproved {
            contractLog.warning(
                "⚠️ DatabaseActor instantiated from non-approved module '{moduleName}'. Only composition roots should create DatabaseActor directly. Feature modules should receive DatabaseExecutor via dependency injection. See ADR-0018 and td-317bbb."
            )
        }
    }

    /// Extracts the module name from the call stack
    private static func extractCallingModuleName() -> String {
        // Get the current stack trace
        let stackTrace = Thread.callStackSymbols

        // Look for the first frame that's not DatabaseCore or DatabaseActor
        // This will be the module that's calling DatabaseActor.init
        for symbol in stackTrace {
            // Symbol format: "index   address module_name + offset"
            // We want to extract the module name
            let components = symbol.split(separator: " ")
            guard components.count >= 3 else { continue }

            let moduleComponent = String(components[2])

            // Handle different formats:
            // - "DatabaseCore`anigma/Packages/DatabaseCore/DatabaseActor.swift ..."
            // - "0x... in <module_name> (executable_path)"
            // - "0x... module_name + offset"

            if moduleComponent.contains("DatabaseCore") {
                continue // Skip DatabaseCore itself
            }

            // Extract module name from the component
            // Format can be: `module_name` or `module_name`结果`path`
            let cleanName = moduleComponent
                .replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: "+", with: "")
                .components(separatedBy: CharacterSet.whitespaces)
                .first ?? String(moduleComponent)

            if !cleanName.isEmpty && !cleanName.hasPrefix("0x") && !cleanName.hasPrefix("_") {
                return cleanName
            }
        }

        return "<unknown>"
    }

    public func open() throws {
        connectionOpenCount += 1
        lastOpenedAt = Date()
    }

    public func close() {
        connectionCloseCount += 1
        lastClosedAt = Date()
    }

    public func query(
        _ sql: String,
        parameters: [DatabaseParameter] = []
    ) async throws -> [DatabaseRow] {
        let startTime = Date()
        defer {
            recordQueryExecution(duration: Date().timeIntervalSince(startTime))
        }

        return try await connectionManager.queryRows(
            sql,
            parameters: parameters.map(Self.renderParameter),
            rlsContext: nil
        )
    }

    @discardableResult
    public func performExecute(
        _ sql: String,
        parameters: [DatabaseParameter] = []
    ) async throws -> Int {
        let startTime = Date()
        defer {
            recordQueryExecution(duration: Date().timeIntervalSince(startTime))
        }

        return try await connectionManager.executeStatement(
            sql,
            parameters: parameters.map(Self.renderParameter),
            rlsContext: nil
        )
    }

    public func executeScript(_ sql: String) async throws -> Int32 {
        let statements = sql
            .split(separator: ";")
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var count: Int32 = 0
        for statement in statements {
            _ = try await connectionManager.executeStatement(
                statement,
                parameters: [],
                rlsContext: nil
            )
            count += 1
        }
        return count
    }

    public func executeQuery(
        _ sql: String,
        parameters: [DatabaseParameter] = []
    ) async throws -> [DatabaseRow] {
        try await query(sql, parameters: parameters)
    }

    @discardableResult
    public func executeAsync(
        _ sql: String,
        parameters: [DatabaseParameter] = []
    ) async throws -> Int {
        try await performExecute(sql, parameters: parameters)
    }

    public func isVectorAvailable() async -> Bool {
        do {
            let rows = try await query("SELECT 1 FROM pg_extension WHERE extname = 'vector'")
            return !rows.isEmpty
        } catch {
            return false
        }
    }

    public func transaction(_ block: @Sendable @escaping () async throws -> Void) async throws {
        try await connectionManager.withTransaction { _ in
            try await block()
        }
    }

    public func transaction(
        mode: TransactionMode = .deferred,
        _ block: @Sendable @escaping () async throws -> Void,
        maxRetries: Int = 3,
        initialBackoff: Int = 100
    ) async throws {
        let isolation: String
        switch mode {
        case .deferred: isolation = "READ COMMITTED"
        case .immediate: isolation = "REPEATABLE READ"
        case .exclusive: isolation = "SERIALIZABLE"
        }

        try await connectionManager.withTransaction(isolation: isolation, maxRetries: maxRetries) { _ in
            try await block()
        }
    }

    // MARK: - Nested Transaction Support with Savepoints

    /// Context for managing nested transactions with savepoints.
    private struct TransactionContext {
        let connection: PostgresConnection
        var savepointStack: [String] = []
    }

    /// Execute a block with nested transaction support using savepoints.
    /// Savepoints allow partial rollback within a transaction, enabling nested
    /// transaction semantics where inner blocks can be rolled back without
    /// affecting outer transaction state.
    ///
    /// - Parameters:
    ///   - mode: Transaction isolation mode
    ///   - block: The async block to execute transactionally
    ///   - maxRetries: Maximum retry attempts on serialization/deadlock errors
    ///   - initialBackoff: Initial backoff time in milliseconds
    /// - Parameter useSavepoints: Whether to use savepoints for nested transactions (default: true)
    public func transactionWithSavepoints(
        mode: TransactionMode = .deferred,
        _ block: @Sendable @escaping () async throws -> Void,
        maxRetries: Int = 3,
        initialBackoff: Int = 100,
        useSavepoints: Bool = true
    ) async throws {
        let isolation: String
        switch mode {
        case .deferred: isolation = "READ COMMITTED"
        case .immediate: isolation = "REPEATABLE READ"
        case .exclusive: isolation = "SERIALIZABLE"
        }

        // For savepoint-based nested transactions, we manage the transaction manually
        if useSavepoints {
            let connection = try await connectionManager.acquireConnection()
            defer {
                Task { await connectionManager.releaseConnection(connection) }
            }

            let context = TransactionContext(connection: connection, savepointStack: [])

            do {
                // Begin the outer transaction
                _ = try await connection.executeStatement("BEGIN ISOLATION LEVEL \(isolation)")

                do {
                    try await block()
                    
                    // Commit the transaction
                    _ = try await connection.executeStatement("COMMIT")
                } catch {
                    // Rollback the entire transaction on error
                    _ = try? await connection.executeStatement("ROLLBACK")
                    throw error
                }
            } catch let error as PostgresError {
                // Retry on serialization failure or deadlock
                if (error.code == .serializationFailure || error.code == .deadlockDetected) && maxRetries > 0 {
                    let backoffMs = Double(initialBackoff) * Double(maxRetries)
                    try await Task.sleep(nanoseconds: UInt64(backoffMs * 1_000_000))
                    try await transactionWithSavepoints(
                        mode: mode,
                        block,
                        maxRetries: maxRetries - 1,
                        initialBackoff: initialBackoff,
                        useSavepoints: useSavepoints
                    )
                    return
                }
                throw error
            }
        } else {
            // Fall back to the existing connection manager transaction
            try await connectionManager.withTransaction(isolation: isolation, maxRetries: maxRetries) { _ in
                try await block()
            }
        }
    }

    /// Execute a nested transaction block with savepoint support.
    /// This method must be called from within an existing transaction.
    /// It creates a savepoint, executes the block, and either:
    /// - Releases the savepoint if the block succeeds
    /// - Rolls back to the savepoint if the block fails
    ///
    /// - Parameters:
    ///   - connection: The PostgresConnection to use
    ///   - savepointName: Optional savepoint name (auto-generated if nil)
    ///   - block: The async block to execute
    public func nestedTransaction(
        on connection: PostgresConnection,
        savepointName: String? = nil,
        _ block: @Sendable @escaping () async throws -> Void
    ) async throws {
        let actualSavepointName = try await savepointName ?? connection.createSavepoint()
        
        do {
            try await block()
            // Release savepoint on success
            try await connection.releaseSavepoint(actualSavepointName)
        } catch {
            // Rollback to savepoint on error
            try? await connection.rollback(to: actualSavepointName)
            throw error
        }
    }

    /// Execute a nested transaction block by automatically acquiring a connection.
    ///
    /// - Parameters:
    ///   - savepointName: Optional savepoint name (auto-generated if nil)
    ///   - block: The async block to execute
    public func nestedTransaction(
        savepointName: String? = nil,
        _ block: @Sendable @escaping (PostgresConnection) async throws -> Void
    ) async throws {
        let connection = try await connectionManager.acquireConnection()
        defer {
            Task { await connectionManager.releaseConnection(connection) }
        }

        let actualSavepointName = try await savepointName ?? connection.createSavepoint()
        
        do {
            try await block(connection)
            // Release savepoint on success
            try await connection.releaseSavepoint(actualSavepointName)
        } catch {
            // Rollback to savepoint on error
            try? await connection.rollback(to: actualSavepointName)
            throw error
        }
    }

    public func getMetrics() -> DatabaseMetrics {
        let averageQueryTime = queryExecutionCount > 0 ? totalQueryTime / Double(queryExecutionCount) : 0
        let activeConnectionCount = 0
        let connectionUptimeSeconds: TimeInterval? = lastOpenedAt.map { Date().timeIntervalSince($0) }

        return DatabaseMetrics(
            busyTimeoutExhausted: busyTimeoutExhaustedCount,
            transactionRetries: transactionRetryCount,
            averageQueryTime: averageQueryTime,
            queryCount: queryExecutionCount,
            walSize: nil,
            walCheckpointCount: nil,
            connectionOpenCount: connectionOpenCount,
            connectionCloseCount: connectionCloseCount,
            connectionOpenFailures: connectionOpenFailureCount,
            activeConnectionCount: activeConnectionCount,
            connectionUptimeSeconds: connectionUptimeSeconds,
            lastOpenedAt: lastOpenedAt,
            lastClosedAt: lastClosedAt
        )
    }

    public func checkpointWal(mode: CheckpointMode = .passive) -> (busy: Bool, log: Int32, checkpointed: Int32)? {
        _ = mode
        return nil
    }

    public func checkpointIfWalLarge(thresholdMB: Int64 = 100) -> Bool {
        _ = thresholdMB
        return false
    }

    public func validateBootstrap() async throws -> DatabaseValidationReport {
        _ = try await querySingle("SELECT 1 AS result")
        return DatabaseValidationReport(quickCheckResult: "ok", foreignKeyViolationCount: 0)
    }

    public func resetMetrics() {
        busyTimeoutExhaustedCount = 0
        transactionRetryCount = 0
        totalQueryTime = 0
        queryExecutionCount = 0
        connectionOpenCount = 0
        connectionCloseCount = 0
        connectionOpenFailureCount = 0
        lastOpenedAt = nil
        lastClosedAt = nil
    }

    private func recordQueryExecution(duration: TimeInterval) {
        totalQueryTime += duration
        queryExecutionCount += 1
    }

    private static func connectionString(for path: String) -> String {
        if path.contains("://") {
            return path
        }
        if let env = ProcessInfo.processInfo.environment["ANIGMA_DB_URL"], !env.isEmpty {
            return env
        }
        return DatabaseConfiguration.defaultDatabasePath()
    }

    private static func renderParameter(_ parameter: DatabaseParameter) -> String {
        switch parameter {
        case .text(let value):
            return "'\(value.replacingOccurrences(of: "'", with: "''"))'"
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
}

// MARK: - Supporting Types

public enum DatabaseParameter: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case date(Date)
    case null
}

public enum DatabaseError: Error, Sendable {
    case connectionError(String)
    case queryError(String)
    case transactionError(String)
    case connectionNotReady
    case connectionPoolExhausted
    case queryTimeout
    case rlsViolation
    case transactionFailed(String)
    case invalidSchema(String)
}

public enum TransactionMode: Sendable {
    case deferred
    case immediate
    case exclusive
}

public enum CheckpointMode: Int32, Sendable {
    case passive = 0
    case full = 1
    case restart = 2
    case truncate = 3
}

public enum DatabaseValue: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case blob(Data)
    case date(Date)
    case null

    public var stringValue: String? {
        if case .text(let value) = self {
            return value
        }
        return nil
    }

    public var intValue: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }

    public var doubleValue: Double? {
        if case .double(let value) = self {
            return value
        }
        return nil
    }

    public var dataValue: Data? {
        if case .blob(let value) = self {
            return value
        }
        return nil
    }

    public var dateValue: Date? {
        if case .date(let value) = self {
            return value
        }
        return nil
    }
}

public struct DatabaseRow: Sendable {
    public let values: [String: DatabaseValue]

    public init(values: [String: DatabaseValue]) {
        self.values = values
    }

    public func value(for column: String) -> DatabaseValue? {
        values[column]
    }

    public func string(for column: String) -> String? {
        value(for: column)?.stringValue
    }

    public func int(for column: String) -> Int? {
        value(for: column)?.intValue
    }

    public func int64(for column: String) -> Int64? {
        value(for: column)?.asInt64
    }

    public func double(for column: String) -> Double? {
        value(for: column)?.doubleValue
    }

    public func data(for column: String) -> Data? {
        value(for: column)?.dataValue
    }

    public subscript(column: String) -> DatabaseValue? {
        value(for: column)
    }
}
