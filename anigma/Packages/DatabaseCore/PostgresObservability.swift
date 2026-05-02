//
//  PostgresObservability.swift
//  DatabaseCore
//
//  PostgreSQL observability and monitoring primitives.
//

import Foundation

// MARK: - Statistics Types

/// Connection state from pg_stat_activity
public enum ConnectionState: String, Sendable, Codable, CaseIterable {
    case active, idle, idleInTransaction, idleInTransactionAborted
    case fastpathFunctionCall, disabled
}

/// Backend type from pg_stat_activity
public enum BackendType: String, Sendable, Codable, CaseIterable {
    case clientBackend, autovacuumWorker, autovacuumLauncher
    case walSender, walReceiver, backgroundWriter, backgroundCheckpointer
    case checkpointer, startup, walWriter, logicalReplicationWorker
    case parallelQueryWorker
}

// MARK: - Activity Models

/// Single row from pg_stat_activity
public struct PostgresActivity: Sendable, Codable, Identifiable {
    public let id: Int64
    public let datid: Int64
    public let datname: String
    public let pid: Int32
    public let usesysid: Int64
    public let usename: String
    public let applicationName: String?
    public let clientAddr: String?
    public let clientPort: Int32?
    public let backendStart: Date
    public let xactStart: Date?
    public let queryStart: Date?
    public let stateChange: Date
    public let state: ConnectionState
    public let backendXid: Int64?
    public let backendXmin: Int64?
    public let query: String?
    public let backendType: BackendType?

    public var isActive: Bool { state == .active }
    public var isIdle: Bool {
        [.idle, .idleInTransaction, .idleInTransactionAborted].contains(state)
    }

    public init(
        id: Int64, datid: Int64, datname: String, pid: Int32, usesysid: Int64,
        usename: String, applicationName: String?, clientAddr: String?, clientPort: Int32?,
        backendStart: Date, xactStart: Date?, queryStart: Date?, stateChange: Date,
        state: ConnectionState, backendXid: Int64?, backendXmin: Int64?,
        query: String?, backendType: BackendType?
    ) {
        self.id = id
        self.datid = datid
        self.datname = datname
        self.pid = pid
        self.usesysid = usesysid
        self.usename = usename
        self.applicationName = applicationName
        self.clientAddr = clientAddr
        self.clientPort = clientPort
        self.backendStart = backendStart
        self.xactStart = xactStart
        self.queryStart = queryStart
        self.stateChange = stateChange
        self.state = state
        self.backendXid = backendXid
        self.backendXmin = backendXmin
        self.query = query
        self.backendType = backendType
    }
}

/// Aggregated activity statistics
public struct PostgresActivitySummary: Sendable, Codable {
    public let totalConnections: Int
    public let activeConnections: Int
    public let idleConnections: Int
    public let idleInTransaction: Int
    public let connectionsByApplication: [String: Int]
    public let connectionsByDatabase: [String: Int]
    public let oldestConnectionDuration: TimeInterval?
    public let longestRunningQuery: TimeInterval?

    public init(
        totalConnections: Int, activeConnections: Int, idleConnections: Int,
        idleInTransaction: Int, connectionsByApplication: [String: Int],
        connectionsByDatabase: [String: Int], oldestConnectionDuration: TimeInterval?,
        longestRunningQuery: TimeInterval?
    ) {
        self.totalConnections = totalConnections
        self.activeConnections = activeConnections
        self.idleConnections = idleConnections
        self.idleInTransaction = idleInTransaction
        self.connectionsByApplication = connectionsByApplication
        self.connectionsByDatabase = connectionsByDatabase
        self.oldestConnectionDuration = oldestConnectionDuration
        self.longestRunningQuery = longestRunningQuery
    }
}

// MARK: - Database Statistics

/// Statistics from pg_stat_database
public struct PostgresDatabaseStats: Sendable, Codable, Identifiable {
    public let id: Int64
    public let datname: String
    public let numBackends: Int32
    public let xactCommit: Int64
    public let xactRollback: Int64
    public let blksRead: Int64
    public let blksHit: Int64
    public let tupReturned: Int64
    public let tupFetched: Int64
    public let tupInserted: Int64
    public let tupUpdated: Int64
    public let tupDeleted: Int64
    public let conflicts: Int64
    public let deadlocks: Int64

    public var cacheHitRatio: Double {
        let total = blksHit + blksRead
        guard total > 0 else { return 0 }
        return Double(blksHit) / Double(total)
    }

    public var commitRatio: Double {
        let total = xactCommit + xactRollback
        guard total > 0 else { return 0 }
        return Double(xactCommit) / Double(total)
    }

    public init(
        id: Int64, datname: String, numBackends: Int32,
        xactCommit: Int64, xactRollback: Int64, blksRead: Int64, blksHit: Int64,
        tupReturned: Int64, tupFetched: Int64, tupInserted: Int64,
        tupUpdated: Int64, tupDeleted: Int64, conflicts: Int64, deadlocks: Int64
    ) {
        self.id = id
        self.datname = datname
        self.numBackends = numBackends
        self.xactCommit = xactCommit
        self.xactRollback = xactRollback
        self.blksRead = blksRead
        self.blksHit = blksHit
        self.tupReturned = tupReturned
        self.tupFetched = tupFetched
        self.tupInserted = tupInserted
        self.tupUpdated = tupUpdated
        self.tupDeleted = tupDeleted
        self.conflicts = conflicts
        self.deadlocks = deadlocks
    }
}

/// Table statistics from pg_stat_user_tables
public struct PostgresTableStats: Sendable, Codable, Identifiable {
    public let id: Int64
    public let schemaname: String
    public let relname: String
    public let seqScan: Int64
    public let idxScan: Int64
    public let nLiveTup: Int64
    public let nIns: Int64
    public let nUpd: Int64
    public let nDel: Int64

    public var fullName: String { schemaname + "." + relname }
    public var totalScans: Int64 { seqScan + idxScan }
    public var totalModifications: Int64 { nIns + nUpd + nDel }

    public init(
        id: Int64, schemaname: String, relname: String,
        seqScan: Int64, idxScan: Int64, nLiveTup: Int64,
        nIns: Int64, nUpd: Int64, nDel: Int64
    ) {
        self.id = id
        self.schemaname = schemaname
        self.relname = relname
        self.seqScan = seqScan
        self.idxScan = idxScan
        self.nLiveTup = nLiveTup
        self.nIns = nIns
        self.nUpd = nUpd
        self.nDel = nDel
    }
}

// MARK: - Observability Manager

/// Manages PostgreSQL observability and monitoring
public final class PostgresObservabilityManager: Sendable {
    private let database: any DatabaseExecutor

    public init(database: any DatabaseExecutor) {
        self.database = database
    }

    // MARK: - Activity Monitoring

    /// Get all active connections
    public func getActivity() async throws -> [PostgresActivity] {
        let rows = try await database.query("""
            SELECT id, datid, datname, pid, usesysid, usename,
                   application_name, client_addr, client_port,
                   backend_start, xact_start, query_start, state_change,
                   state, backend_xid, backend_xmin, query, backend_type
            FROM pg_stat_activity
            WHERE pid != pg_backend_pid()
            AND backend_type != 'autovacuum worker'
            ORDER BY state, query_start
            """)

        return rows.compactMap { try? parseActivityRow($0) }
    }

    /// Get activity summary
    public func getActivitySummary() async throws -> PostgresActivitySummary {
        let activity = try await getActivity()
        var connectionsByApp: [String: Int] = [:]
        var connectionsByDB: [String: Int] = [:]
        var activeCount = 0
        var idleCount = 0
        var idleInTxCount = 0
        var oldestDuration: TimeInterval?
        var longestQuery: TimeInterval?

        for conn in activity {
            if let app = conn.applicationName {
                connectionsByApp[app, default: 0] += 1
            }
            connectionsByDB[conn.datname, default: 0] += 1

            if conn.isActive { activeCount += 1 }
            if conn.isIdle {
                idleCount += 1
                if [.idleInTransaction, .idleInTransactionAborted].contains(conn.state) {
                    idleInTxCount += 1
                }
            }

            let duration = Date().timeIntervalSince(conn.backendStart)
            if oldestDuration == nil || duration > oldestDuration! {
                oldestDuration = duration
            }
            if let qd = conn.queryStart.map({ Date().timeIntervalSince($0) }), 
               longestQuery == nil || qd > longestQuery! {
                longestQuery = qd
            }
        }

        return PostgresActivitySummary(
            totalConnections: activity.count,
            activeConnections: activeCount,
            idleConnections: idleCount,
            idleInTransaction: idleInTxCount,
            connectionsByApplication: connectionsByApp,
            connectionsByDatabase: connectionsByDB,
            oldestConnectionDuration: oldestDuration,
            longestRunningQuery: longestQuery
        )
    }

    /// Kill a connection by PID
    public func killConnection(pid: Int32) async throws {
        let sql = "SELECT pg_terminate_backend(" + String(pid) + ")"
        _ = try await database.executeAsync(sql)
    }

    // MARK: - Database Statistics

    /// Get database-level statistics
    public func getDatabaseStats() async throws -> [PostgresDatabaseStats] {
        let rows = try await database.query("""
            SELECT datid as id, datname, numbackends,
                   xact_commit, xact_rollback, blks_read, blks_hit,
                   tup_returned, tup_fetched, tup_inserted, tup_updated, tup_deleted,
                   conflicts, deadlocks
            FROM pg_stat_database WHERE datname IS NOT NULL ORDER BY datname
            """)

        return rows.compactMap { try? parseDatabaseStatsRow($0) }
    }

    /// Get table-level statistics
    public func getTableStats(schema: String? = nil) async throws -> [PostgresTableStats] {
        var schemaFilter = ""
        if let schema {
            schemaFilter = "WHERE schemaname = '" + schema.escaped + "'"
        }
        let rows = try await database.query(
            "SELECT relid as id, schemaname, relname, seq_scan, idx_scan, n_live_tup, n_ins, n_upd, n_del FROM pg_stat_user_tables " + schemaFilter + " ORDER BY n_live_tup DESC"
        )
        return rows.compactMap { try? parseTableStatsRow($0) }
    }

    // MARK: - Lock Monitoring

    /// Get current locks (waiting locks only)
    public func getWaitingLocks() async throws -> [DatabaseRow] {
        let rows = try await database.query("""
            SELECT locktype, relation::regclass, mode, granted, pid
            FROM pg_locks WHERE NOT granted
            ORDER BY mode
            """)
        return rows
    }

    /// Get blocking lock chains
    public func getBlockingLocks() async throws -> [DatabaseRow] {
        let rows = try await database.query("""
            SELECT blocked_locks.pid AS blocked_pid, blocking_locks.pid AS blocking_pid,
                   blocked_activity.query AS blocked_statement,
                   blocking_activity.query AS blocking_statement
            FROM pg_catalog.pg_locks blocked_locks
            JOIN pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
            JOIN pg_catalog.pg_locks blocking_locks
                ON blocking_locks.locktype = blocked_locks.locktype
                AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
                AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
                AND blocking_locks.pid != blocked_locks.pid
            JOIN pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
            WHERE NOT blocked_locks.granted
            """)
        return rows
    }

    // MARK: - Replication Monitoring

    /// Get replication statistics
    public func getReplicationStats() async throws -> [DatabaseRow] {
        let rows = try await database.query("""
            SELECT pid, usename, application_name, client_addr, state,
                   pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as replay_lag_bytes
            FROM pg_stat_replication
            ORDER BY replay_lag_bytes DESC
            """)
        return rows
    }

    // MARK: - Helper Parsers

    private func parseActivityRow(_ row: DatabaseRow) throws -> PostgresActivity {
        let id = row.int64(for: "id") ?? 0
        let datid = row.int64(for: "datid") ?? 0
        let datname = row.string(for: "datname") ?? ""
        let pid = row.int32(for: "pid") ?? 0
        let usesysid = row.int64(for: "usesysid") ?? 0
        let usename = row.string(for: "usename") ?? ""
        let appName = row.string(for: "application_name")
        let clientAddr = row.string(for: "client_addr")
        let clientPort = row.int32(for: "client_port")
        let backendStart = parseTimestamp(row.string(for: "backend_start")) ?? Date()
        let xactStart = parseTimestamp(row.string(for: "xact_start"))
        let queryStart = parseTimestamp(row.string(for: "query_start"))
        let stateChange = parseTimestamp(row.string(for: "state_change")) ?? Date()
        let stateRaw = row.string(for: "state") ?? ""
        let state = ConnectionState(rawValue: stateRaw) ?? .idle
        let backendXid = row.int64(for: "backend_xid")
        let backendXmin = row.int64(for: "backend_xmin")
        let query = row.string(for: "query")
        let backendTypeRaw = row.string(for: "backend_type")
        let backendType = backendTypeRaw.flatMap { BackendType(rawValue: $0) }

        return PostgresActivity(
            id: id, datid: datid, datname: datname, pid: pid, usesysid: usesysid,
            usename: usename, applicationName: appName, clientAddr: clientAddr,
            clientPort: clientPort, backendStart: backendStart, xactStart: xactStart,
            queryStart: queryStart, stateChange: stateChange, state: state,
            backendXid: backendXid, backendXmin: backendXmin, query: query,
            backendType: backendType
        )
    }

    private func parseDatabaseStatsRow(_ row: DatabaseRow) throws -> PostgresDatabaseStats {
        PostgresDatabaseStats(
            id: row.int64(for: "id") ?? 0,
            datname: row.string(for: "datname") ?? "",
            numBackends: row.int32(for: "numbackends") ?? 0,
            xactCommit: row.int64(for: "xact_commit") ?? 0,
            xactRollback: row.int64(for: "xact_rollback") ?? 0,
            blksRead: row.int64(for: "blks_read") ?? 0,
            blksHit: row.int64(for: "blks_hit") ?? 0,
            tupReturned: row.int64(for: "tup_returned") ?? 0,
            tupFetched: row.int64(for: "tup_fetched") ?? 0,
            tupInserted: row.int64(for: "tup_inserted") ?? 0,
            tupUpdated: row.int64(for: "tup_updated") ?? 0,
            tupDeleted: row.int64(for: "tup_deleted") ?? 0,
            conflicts: row.int64(for: "conflicts") ?? 0,
            deadlocks: row.int64(for: "deadlocks") ?? 0
        )
    }

    private func parseTableStatsRow(_ row: DatabaseRow) throws -> PostgresTableStats {
        PostgresTableStats(
            id: row.int64(for: "id") ?? 0,
            schemaname: row.string(for: "schemaname") ?? "",
            relname: row.string(for: "relname") ?? "",
            seqScan: row.int64(for: "seq_scan") ?? 0,
            idxScan: row.int64(for: "idx_scan") ?? 0,
            nLiveTup: row.int64(for: "n_live_tup") ?? 0,
            nIns: row.int64(for: "n_ins") ?? 0,
            nUpd: row.int64(for: "n_upd") ?? 0,
            nDel: row.int64(for: "n_del") ?? 0
        )
    }

    private func parseTimestamp(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}

// MARK: - String Extension

extension String {
    var escaped: String { replacingOccurrences(of: "'", with: "''") }
}

// MARK: - Errors

public enum PostgresObservabilityError: Error, CustomStringConvertible, Sendable {
    case connectionKillFailed(pid: Int32, reason: String)
    case queryFailed(String)

    public var description: String {
        switch self {
        case let .connectionKillFailed(pid, reason):
            return "Failed to kill connection " + String(pid) + ": " + reason
        case let .queryFailed(r):
            return "Observability query failed: " + r
        }
    }
}
