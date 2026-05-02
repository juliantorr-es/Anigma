//
//  DatabaseHousekeeping.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation
import AnigmaPrimitives

/// Database health statistics structure for PostgreSQL-backed storage.
public struct DatabaseHealthStats: Sendable {
    public let databaseSizeBytes: Int64
    public let walBytes: Int64
    public let liveTupleCount: Int
    public let deadTupleCount: Int
    public let tableCount: Int
    public let fragmentationRatio: Double

    public init(
        databaseSizeBytes: Int64,
        walBytes: Int64,
        liveTupleCount: Int,
        deadTupleCount: Int,
        tableCount: Int,
        fragmentationRatio: Double
    ) {
        self.databaseSizeBytes = databaseSizeBytes
        self.walBytes = walBytes
        self.liveTupleCount = liveTupleCount
        self.deadTupleCount = deadTupleCount
        self.tableCount = tableCount
        self.fragmentationRatio = fragmentationRatio
    }
}

/// PostgreSQL WAL management for bounded log growth.
public actor WALManager {
    private let db: any DatabaseExecutor
    private let config: WALConfig

    public init(database: any DatabaseExecutor, config: WALConfig = .default) {
        self.db = database
        self.config = config
    }

    /// Get current WAL volume in bytes.
    public func getWALSize() async throws -> Int64 {
        do {
            let rows = try await db.query("""
                SELECT COALESCE(SUM(wal_bytes), 0) AS wal_bytes
                FROM pg_stat_wal
                """)
            return rows.first?.int64(for: "wal_bytes") ?? 0
        } catch {
            return 0
        }
    }

    /// Perform WAL checkpoint if size exceeds threshold.
    public func checkpointIfNeeded() async throws -> WALCheckpointResult {
        let walSize = try await getWALSize()
        let thresholdBytes = Int64(config.checkpointThresholdMb * 1024 * 1024)

        if walSize >= thresholdBytes {
            return try await performCheckpoint(mode: config.checkpointMode)
        }

        return WALCheckpointResult(
            checkpointPerformed: false,
            walSizeBefore: walSize,
            walSizeAfter: walSize,
            duration: 0
        )
    }

    /// Perform WAL checkpoint with specified mode.
    public func performCheckpoint(mode: WALCheckpointMode = .truncate) async throws -> WALCheckpointResult {
        let startTime = Date()
        let walSizeBefore = try await getWALSize()
        _ = mode
        try await db.executeAsync("CHECKPOINT")

        let walSizeAfter = try await getWALSize()
        let duration = Date().timeIntervalSince(startTime)

        return WALCheckpointResult(
            checkpointPerformed: true,
            walSizeBefore: walSizeBefore,
            walSizeAfter: walSizeAfter,
            duration: duration
        )
    }

    /// Configure WAL-related maintenance parameters for optimal performance.
    public func configureWAL() async throws {
        // PostgreSQL handles WAL mode server-side. We keep the session aligned
        // with conservative maintenance settings rather than backend-specific knobs.
        try await db.executeAsync("SET statement_timeout = '30s'")
        try await db.executeAsync("SET lock_timeout = '5s'")
        try await db.executeAsync("SET idle_in_transaction_session_timeout = '30s'")
        try await db.executeAsync("CHECKPOINT")
    }
}

/// Database maintenance operations (VACUUM, ANALYZE).
public actor DatabaseMaintenance {
    private let db: any DatabaseExecutor
    private let config: MaintenanceConfig

    public init(database: any DatabaseExecutor, config: MaintenanceConfig = .default) {
        self.db = database
        self.config = config
    }

    /// Get current database size.
    public func getDatabaseSize() async throws -> Int64 {
        let rows = try await db.query("""
            SELECT COALESCE(pg_database_size(current_database()), 0) AS database_size_bytes
            """)
        return rows.first?.int64(for: "database_size_bytes") ?? 0
    }

    /// Run full VACUUM if fragmentation exceeds threshold.
    public func vacuumIfNeeded() async throws -> VacuumResult {
        let stats = try await getMaintenanceCounts()
        let totalTuples = max(stats.liveTupleCount + stats.deadTupleCount, 1)
        let fragmentationRatio = Double(stats.deadTupleCount) / Double(totalTuples)

        if fragmentationRatio >= config.fragmentationThreshold {
            return try await performVacuum(mode: .full)
        }

        return VacuumResult(
            vacuumPerformed: false,
            sizeBeforeMb: Double(try await getDatabaseSize()) / (1024 * 1024),
            sizeAfterMb: Double(try await getDatabaseSize()) / (1024 * 1024),
            duration: 0,
            fragmentationRatio: fragmentationRatio
        )
    }

    /// Perform full or incremental VACUUM.
    public func performVacuum(mode: VacuumMode = .full) async throws -> VacuumResult {
        let startTime = Date()
        let sizeBefore = try await getDatabaseSize()

        switch mode {
        case .full:
            try await db.executeAsync("VACUUM (ANALYZE)")
        case .incremental:
            try await db.executeAsync("ANALYZE")
        }

        let sizeAfter = try await getDatabaseSize()
        let duration = Date().timeIntervalSince(startTime)
        let stats = try await getMaintenanceCounts()
        let totalTuples = max(stats.liveTupleCount + stats.deadTupleCount, 1)
        let fragmentationRatio = Double(stats.deadTupleCount) / Double(totalTuples)

        return VacuumResult(
            vacuumPerformed: true,
            sizeBeforeMb: Double(sizeBefore) / (1024 * 1024),
            sizeAfterMb: Double(sizeAfter) / (1024 * 1024),
            duration: duration,
            fragmentationRatio: fragmentationRatio
        )
    }

    /// Run ANALYZE to update query statistics.
    public func analyzeDatabase() async throws -> AnalyzeResult {
        let startTime = Date()
        try await db.executeAsync("ANALYZE")
        let duration = Date().timeIntervalSince(startTime)

        return AnalyzeResult(
            analyzed: true,
            duration: duration
        )
    }

    /// Run complete maintenance cycle (ANALYZE + optional VACUUM).
    public func runFullMaintenance() async throws -> FullMaintenanceResult {
        var result = FullMaintenanceResult()

        // Run analysis
        result.analyzeResult = try await analyzeDatabase()

        // Check if VACUUM is needed
        let stats = try await getMaintenanceCounts()
        let totalTuples = max(stats.liveTupleCount + stats.deadTupleCount, 1)
        let fragmentationRatio = Double(stats.deadTupleCount) / Double(totalTuples)

        if fragmentationRatio >= config.fragmentationThreshold {
            result.vacuumResult = try await performVacuum(mode: .full)
        }

        return result
    }

    /// Retrieve current database health metrics.
    public func getDatabaseHealthStats() async throws -> DatabaseHealthStats {
        let dbSize = try await getDatabaseSize()

        let walSize = try await WALManager(database: db, config: .default).getWALSize()
        let counts = try await getMaintenanceCounts()
        let totalTuples = max(counts.liveTupleCount + counts.deadTupleCount, 1)
        let fragmentationRatio = Double(counts.deadTupleCount) / Double(totalTuples)

        return DatabaseHealthStats(
            databaseSizeBytes: dbSize,
            walBytes: walSize,
            liveTupleCount: counts.liveTupleCount,
            deadTupleCount: counts.deadTupleCount,
            tableCount: counts.tableCount,
            fragmentationRatio: fragmentationRatio
        )
    }

    /// Get PostgreSQL maintenance statistics.
    private func getMaintenanceCounts() async throws -> MaintenanceCounts {
        let rows = try await db.query(
            """
            SELECT
                COALESCE(SUM(n_live_tup), 0) AS live_tuple_count,
                COALESCE(SUM(n_dead_tup), 0) AS dead_tuple_count,
                COUNT(*) AS table_count
            FROM pg_stat_user_tables
            """
        )

        let liveTupleCount = rows.first?.int(for: "live_tuple_count") ?? 0
        let deadTupleCount = rows.first?.int(for: "dead_tuple_count") ?? 0
        let tableCount = rows.first?.int(for: "table_count") ?? 0

        return MaintenanceCounts(
            liveTupleCount: liveTupleCount,
            deadTupleCount: deadTupleCount,
            tableCount: tableCount
        )
    }
}

// MARK: - Configuration Types

/// WAL checkpoint mode.
public enum WALCheckpointMode: Sendable {
    case passive
    case restart
    case restart_
    case truncate
}

/// VACUUM mode.
public enum VacuumMode: Sendable {
    case full
    case incremental
}

/// WAL configuration.
public struct WALConfig: Sendable {
    public let checkpointThresholdMb: Int
    public let checkpointMode: WALCheckpointMode

    public static let `default` = WALConfig(
        checkpointThresholdMb: 10,
        checkpointMode: .truncate
    )

    public static let aggressive = WALConfig(
        checkpointThresholdMb: 5,
        checkpointMode: .truncate
    )

    public static let conservative = WALConfig(
        checkpointThresholdMb: 50,
        checkpointMode: .restart
    )

    public init(
        checkpointThresholdMb: Int = 10,
        checkpointMode: WALCheckpointMode = .truncate
    ) {
        self.checkpointThresholdMb = checkpointThresholdMb
        self.checkpointMode = checkpointMode
    }
}

/// Maintenance configuration.
public struct MaintenanceConfig: Sendable, Codable {
    public let fragmentationThreshold: Double
    public let incrementalVacuumPages: Int
    public let analyzeInterval: TimeInterval
    public let vacuumInterval: TimeInterval

    public static let `default` = MaintenanceConfig(
        fragmentationThreshold: 0.20, // 20% free space triggers VACUUM
        incrementalVacuumPages: 1000,
        analyzeInterval: 3600, // 1 hour
        vacuumInterval: 86400 // 1 day
    )

    public static let aggressive = MaintenanceConfig(
        fragmentationThreshold: 0.10,
        incrementalVacuumPages: 500,
        analyzeInterval: 1800,
        vacuumInterval: 43200
    )

    public static let conservative = MaintenanceConfig(
        fragmentationThreshold: 0.30,
        incrementalVacuumPages: 2000,
        analyzeInterval: 7200,
        vacuumInterval: 172800
    )

    public init(
        fragmentationThreshold: Double = 0.20,
        incrementalVacuumPages: Int = 1000,
        analyzeInterval: TimeInterval = 3600,
        vacuumInterval: TimeInterval = 86400
    ) {
        self.fragmentationThreshold = fragmentationThreshold
        self.incrementalVacuumPages = incrementalVacuumPages
        self.analyzeInterval = analyzeInterval
        self.vacuumInterval = vacuumInterval
    }
}

// MARK: - Result Types

/// Result of WAL checkpoint operation.
public struct WALCheckpointResult: Codable, Sendable {
    public let checkpointPerformed: Bool
    public let walSizeBefore: Int64
    public let walSizeAfter: Int64
    public let duration: TimeInterval

    public var bytesFreed: Int64 {
        walSizeBefore - walSizeAfter
    }
}

/// Result of VACUUM operation.
public struct VacuumResult: Codable, Sendable {
    public let vacuumPerformed: Bool
    public let sizeBeforeMb: Double
    public let sizeAfterMb: Double
    public let duration: TimeInterval
    public let fragmentationRatio: Double

    public var spaceSavedMb: Double {
        sizeBeforeMb - sizeAfterMb
    }
}

/// Result of ANALYZE operation.
public struct AnalyzeResult: Codable, Sendable {
    public let analyzed: Bool
    public let duration: TimeInterval
}

/// Result of full maintenance cycle.
public struct FullMaintenanceResult: Encodable, Sendable {
    public var analyzeResult: AnalyzeResult?
    public var vacuumResult: VacuumResult?

    public init(
        analyzeResult: AnalyzeResult? = nil,
        vacuumResult: VacuumResult? = nil
    ) {
        self.analyzeResult = analyzeResult
        self.vacuumResult = vacuumResult
    }
}

/// PostgreSQL maintenance counts.
private struct MaintenanceCounts: Sendable {
    let liveTupleCount: Int
    let deadTupleCount: Int
    let tableCount: Int
}
