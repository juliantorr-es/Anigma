//
//  PostgresMetrics.swift
//  DatabaseCore
//
//  PostgreSQL metrics collection and monitoring.
//
//  See td-659c7e: Integrate pg_stat_statements for query metrics
//  See td-c074e2: Populate DatabaseMetrics with live PostgreSQL stats
//  See td-0cb394: Add slow query logging for queries >100ms
//  See td-f4513d: Implement connection pool metrics
//  See td-36edb3: Add health check endpoint for PostgreSQL
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation

// MARK: - Query Metrics

/// Metrics for a single executed query
public struct PostgresQueryMetrics: Sendable, Codable {
    public let queryID: UUID
    public let query: String
    public let executionCount: Int64
    public let totalTimeMs: Double
    public let minTimeMs: Double
    public let maxTimeMs: Double
    public let meanTimeMs: Double
    public let stddevTimeMs: Double
    public let rowsReturned: Int64
    
    public init(
        queryID: UUID = UUID(),
        query: String,
        executionCount: Int64 = 0,
        totalTimeMs: Double = 0,
        minTimeMs: Double = 0,
        maxTimeMs: Double = 0,
        meanTimeMs: Double = 0,
        stddevTimeMs: Double = 0,
        rowsReturned: Int64 = 0
    ) {
        self.queryID = queryID
        self.query = query
        self.executionCount = executionCount
        self.totalTimeMs = totalTimeMs
        self.minTimeMs = minTimeMs
        self.maxTimeMs = maxTimeMs
        self.meanTimeMs = meanTimeMs
        self.stddevTimeMs = stddevTimeMs
        self.rowsReturned = rowsReturned
    }
}

/// Slow query log entry
public struct SlowQueryLogEntry: Sendable, Codable {
    public let id: UUID
    public let query: String
    public let executionTimeMs: Double
    public let thresholdMs: Double
    public let timestamp: Date
    public let caller: String?
    public let parameters: [String: AnyCodable]?
    
    public init(
        id: UUID = UUID(),
        query: String,
        executionTimeMs: Double,
        thresholdMs: Double = 100,
        timestamp: Date = Date(),
        caller: String? = nil,
        parameters: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.query = query
        self.executionTimeMs = executionTimeMs
        self.thresholdMs = thresholdMs
        self.timestamp = timestamp
        self.caller = caller
        self.parameters = parameters
    }
}

// MARK: - pg_stat_statements Integration

/// Metrics from pg_stat_statements extension
public struct PgStatStatementsMetrics: Sendable, Codable {
    public let query: String
    public let calls: Int64
    public let totalExecTimeMs: Double
    public let minExecTimeMs: Double
    public let maxExecTimeMs: Double
    public let meanExecTimeMs: Double
    public let stddevExecTimeMs: Double
    public let rows: Int64
    public let sharedBlkHits: Int64
    public let sharedBlkReads: Int64
    public let sharedBlkDirtied: Int64
    public let sharedBlkWritten: Int64
    public let localBlkHits: Int64
    public let localBlkReads: Int64
    public let localBlkDirtied: Int64
    public let localBlkWritten: Int64
    public let tempBlkReads: Int64
    public let tempBlkWritten: Int64
    public let blkReadTimeMs: Double
    public let blkWriteTimeMs: Double
    
    public init(
        query: String,
        calls: Int64,
        totalExecTimeMs: Double,
        minExecTimeMs: Double,
        maxExecTimeMs: Double,
        meanExecTimeMs: Double,
        stddevExecTimeMs: Double,
        rows: Int64,
        sharedBlkHits: Int64,
        sharedBlkReads: Int64,
        sharedBlkDirtied: Int64,
        sharedBlkWritten: Int64,
        localBlkHits: Int64,
        localBlkReads: Int64,
        localBlkDirtied: Int64,
        localBlkWritten: Int64,
        tempBlkReads: Int64,
        tempBlkWritten: Int64,
        blkReadTimeMs: Double,
        blkWriteTimeMs: Double
    ) {
        self.query = query
        self.calls = calls
        self.totalExecTimeMs = totalExecTimeMs
        self.minExecTimeMs = minExecTimeMs
        self.maxExecTimeMs = maxExecTimeMs
        self.meanExecTimeMs = meanExecTimeMs
        self.stddevExecTimeMs = stddevExecTimeMs
        self.rows = rows
        self.sharedBlkHits = sharedBlkHits
        self.sharedBlkReads = sharedBlkReads
        self.sharedBlkDirtied = sharedBlkDirtied
        self.sharedBlkWritten = sharedBlkWritten
        self.localBlkHits = localBlkHits
        self.localBlkReads = localBlkReads
        self.localBlkDirtied = localBlkDirtied
        self.localBlkWritten = localBlkWritten
        self.tempBlkReads = tempBlkReads
        self.tempBlkWritten = tempBlkWritten
        self.blkReadTimeMs = blkReadTimeMs
        self.blkWriteTimeMs = blkWriteTimeMs
    }
}

// MARK: - Connection Pool Metrics

/// Connection pool metrics
public struct PostgresConnectionPoolMetrics: Sendable, Codable {
    public let totalConnections: Int
    public let activeConnections: Int
    public let idleConnections: Int
    public let waiters: Int
    public let minPoolSize: Int
    public let maxPoolSize: Int
    public let connectionTimeoutMs: Double
    public let idleTimeoutMs: Double
    
    public init(
        totalConnections: Int,
        activeConnections: Int,
        idleConnections: Int,
        waiters: Int,
        minPoolSize: Int,
        maxPoolSize: Int,
        connectionTimeoutMs: Double,
        idleTimeoutMs: Double
    ) {
        self.totalConnections = totalConnections
        self.activeConnections = activeConnections
        self.idleConnections = idleConnections
        self.waiters = waiters
        self.minPoolSize = minPoolSize
        self.maxPoolSize = maxPoolSize
        self.connectionTimeoutMs = connectionTimeoutMs
        self.idleTimeoutMs = idleTimeoutMs
    }
}

// MARK: - Health Check

/// PostgreSQL health check result
public struct PostgresHealthCheckResult: Sendable, Codable {
    public let status: HealthStatus
    public let version: String?
    public let uptimeSeconds: Double?
    public let activeConnections: Int
    public let maxConnections: Int
    public let connectionRate: Double
    public let lastError: String?
    public let checkedAt: Date
    
    public enum HealthStatus: String, Sendable, Codable {
        case healthy
        case degraded
        case unavailable
    }
    
    public var isHealthy: Bool { status == .healthy }
    
    public init(
        status: HealthStatus,
        version: String? = nil,
        uptimeSeconds: Double? = nil,
        activeConnections: Int,
        maxConnections: Int,
        connectionRate: Double = 0,
        lastError: String? = nil,
        checkedAt: Date = Date()
    ) {
        self.status = status
        self.version = version
        self.uptimeSeconds = uptimeSeconds
        self.activeConnections = activeConnections
        self.maxConnections = maxConnections
        self.connectionRate = connectionRate
        self.lastError = lastError
        self.checkedAt = checkedAt
    }
}

// MARK: - Metrics Manager

/// Manages PostgreSQL metrics collection
public final class PostgresMetricsManager {
    private let database: any DatabaseExecutor
    private let slowQueryThresholdMs: Double
    private var slowQueryLog: [SlowQueryLogEntry] = []
    private var maxSlowQueryLogEntries: Int
    private let lock = NSRecursiveLock()
    
    public init(
        database: any DatabaseExecutor,
        slowQueryThresholdMs: Double = 100,
        maxSlowQueryLogEntries: Int = 1000
    ) {
        self.database = database
        self.slowQueryThresholdMs = slowQueryThresholdMs
        self.maxSlowQueryLogEntries = maxSlowQueryLogEntries
    }
    
    // MARK: - Health Check
    
    /// Perform a comprehensive health check
    public func healthCheck() async throws -> PostgresHealthCheckResult {
        // 1. Basic connectivity check
        var status: PostgresHealthCheckResult.HealthStatus = .healthy
        var version: String?
        var uptimeSeconds: Double?
        
        do {
            let versionRow = try await database.query("SELECT version()")
            version = versionRow.first?.string(for: "version")
        } catch {
            status = .unavailable
            return PostgresHealthCheckResult(
                status: status,
                activeConnections: 0,
                maxConnections: 0,
                lastError: error.localizedDescription
            )
        }
        
        // 2. Get connection info
        let connectionRows = try await database.query(
            "SELECT count(*) as active, current_setting('max_connections') as max_connections FROM pg_stat_activity WHERE state = 'active'"
        )
        let activeConnections = connectionRows.first?.int(for: "active") ?? 0
        let maxConnections = connectionRows.first?.int(for: "max_connections") ?? 100
        
        // 3. Check pg_stat_activity for health
        do {
            _ = try await database.query("SELECT 1 FROM pg_stat_activity WHERE pid = pg_backend_pid()")
        } catch {
            status = .degraded
        }
        
        // 4. Get uptime
        let uptimeRow = try await database.query("SELECT EXTRACT(EPOCH FROM (now() - pg_postmaster_start_time())) as uptime")
        uptimeSeconds = uptimeRow.first?.double(for: "uptime")
        
        let connectionRate = activeConnections > 0 ? Double(activeConnections) / Double(maxConnections) : 0
        
        return PostgresHealthCheckResult(
            status: status,
            version: version,
            uptimeSeconds: uptimeSeconds,
            activeConnections: activeConnections,
            maxConnections: maxConnections,
            connectionRate: connectionRate
        )
    }
    
    // MARK: - pg_stat_statements
    
    /// Check if pg_stat_statements extension is available
    public func isPgStatStatementsAvailable() async throws -> Bool {
        let rows = try await database.query(
            "SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'"
        )
        return !rows.isEmpty
    }
    
    /// Enable pg_stat_statements if not already enabled
    public func enablePgStatStatements() async throws {
        let isAvailable = try await isPgStatStatementsAvailable()
        if !isAvailable {
            // Note: In production, extension creation requires superuser
            // But for some setups it might already be created
            _ = try? await database.executeAsync("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")
        }
    }
    
    /// Get top slowest queries from pg_stat_statements
    public func getSlowestQueries(limit: Int = 10) async throws -> [PgStatStatementsMetrics] {
        let rows = try await database.query("""
            SELECT 
                query, calls, total_exec_time, min_exec_time, max_exec_time, 
                mean_exec_time, stddev_exec_time, rows, 
                shared_blks_hit, shared_blks_read, shared_blks_dirtied, shared_blks_written,
                local_blks_hit, local_blks_read, local_blks_dirtied, local_blks_written,
                temp_blks_read, temp_blks_written, blk_read_time, blk_write_time
            FROM pg_stat_statements 
            ORDER BY mean_exec_time DESC 
            LIMIT \(limit)
        """)
        
        return rows.compactMap { row in
            PgStatStatementsMetrics(
                query: row.string(for: "query") ?? "",
                calls: row.int64(for: "calls") ?? 0,
                totalExecTimeMs: (row.double(for: "total_exec_time") ?? 0) * 1000,
                minExecTimeMs: (row.double(for: "min_exec_time") ?? 0) * 1000,
                maxExecTimeMs: (row.double(for: "max_exec_time") ?? 0) * 1000,
                meanExecTimeMs: (row.double(for: "mean_exec_time") ?? 0) * 1000,
                stddevExecTimeMs: (row.double(for: "stddev_exec_time") ?? 0) * 1000,
                rows: row.int64(for: "rows") ?? 0,
                sharedBlkHits: row.int64(for: "shared_blks_hit") ?? 0,
                sharedBlkReads: row.int64(for: "shared_blks_read") ?? 0,
                sharedBlkDirtied: row.int64(for: "shared_blks_dirtied") ?? 0,
                sharedBlkWritten: row.int64(for: "shared_blks_written") ?? 0,
                localBlkHits: row.int64(for: "local_blks_hit") ?? 0,
                localBlkReads: row.int64(for: "local_blks_read") ?? 0,
                localBlkDirtied: row.int64(for: "local_blks_dirtied") ?? 0,
                localBlkWritten: row.int64(for: "local_blks_written") ?? 0,
                tempBlkReads: row.int64(for: "temp_blks_read") ?? 0,
                tempBlkWritten: row.int64(for: "temp_blks_written") ?? 0,
                blkReadTimeMs: (row.double(for: "blk_read_time") ?? 0) * 1000,
                blkWriteTimeMs: (row.double(for: "blk_write_time") ?? 0) * 1000
            )
        }
    }
    
    /// Reset pg_stat_statements
    public func resetPgStatStatements() async throws {
        _ = try await database.executeAsync("SELECT pg_stat_statements_reset()")
    }
    
    // MARK: - Slow Query Logging
    
    /// Log a slow query
    public func logSlowQuery(
        query: String,
        executionTimeMs: Double,
        caller: String? = nil,
        parameters: [String: AnyCodable]? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        guard executionTimeMs >= slowQueryThresholdMs else { return }
        
        let entry = SlowQueryLogEntry(
            query: query,
            executionTimeMs: executionTimeMs,
            thresholdMs: slowQueryThresholdMs,
            caller: caller,
            parameters: parameters
        )
        
        slowQueryLog.append(entry)
        
        // Trim log if too large
        if slowQueryLog.count > maxSlowQueryLogEntries {
            slowQueryLog.removeFirst(slowQueryLog.count - maxSlowQueryLogEntries)
        }
    }
    
    /// Get recent slow queries
    public func getSlowQueries(limit: Int = 100) -> [SlowQueryLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return Array(slowQueryLog.suffix(limit))
    }
    
    /// Clear slow query log
    public func clearSlowQueryLog() {
        lock.lock()
        defer { lock.unlock() }
        slowQueryLog.removeAll()
    }
    
    // MARK: - Connection Pool Metrics
    
    /// Get connection pool metrics
    public func getConnectionPoolMetrics() -> PostgresConnectionPoolMetrics? {
        // This would be populated from ConnectionManager's metrics
        // For now, return nil as it's tracked separately
        return nil
    }
    
    // MARK: - Aggregated Metrics
    
    /// Get comprehensive metrics summary
    public func getMetricsSummary() async throws -> PostgresMetricsSummary {
        let health = try await healthCheck()
        let isPgStatAvailable = try await isPgStatStatementsAvailable()
        let slowQueries = getSlowQueries(limit: 10)
        
        return PostgresMetricsSummary(
            health: health,
            isPgStatStatementsAvailable: isPgStatAvailable,
            totalSlowQueries: slowQueries.count,
            slowQueryThresholdMs: slowQueryThresholdMs
        )
    }
}

// MARK: - Metrics Summary

public struct PostgresMetricsSummary: Sendable, Codable {
    public let health: PostgresHealthCheckResult
    public let isPgStatStatementsAvailable: Bool
    public let totalSlowQueries: Int
    public let slowQueryThresholdMs: Double
    
    public init(
        health: PostgresHealthCheckResult,
        isPgStatStatementsAvailable: Bool,
        totalSlowQueries: Int,
        slowQueryThresholdMs: Double
    ) {
        self.health = health
        self.isPgStatStatementsAvailable = isPgStatStatementsAvailable
        self.totalSlowQueries = totalSlowQueries
        self.slowQueryThresholdMs = slowQueryThresholdMs
    }
}
