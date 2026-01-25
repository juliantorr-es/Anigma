//
//  DatabaseHousekeeping.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// WAL (Write-Ahead Log) management for bounded log growth.
public actor WALManager {
    private let db: DatabaseActor
    private let config: WALConfig

    public init(database: DatabaseActor, config: WALConfig = .default) {
        self.db = database
        self.config = config
    }

    /// Get current WAL file size in bytes.
    public func getWALSize() async throws -> Int64 {
        let dbPath = db.path
        let walPath = dbPath + "-wal"

        if FileManager.default.fileExists(atPath: walPath) {
            let attributes = try FileManager.default.attributesOfItem(atPath: walPath)
            if let size = attributes[FileAttributeKey.size] as? NSNumber {
                return size.int64Value
            }
        }
        return 0
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

        let modeString: String
        switch mode {
        case .passive:
            modeString = "PASSIVE"
        case .restart:
            modeString = "RESTART"
        case .restart_:
            modeString = "RESTART"
        case .truncate:
            modeString = "TRUNCATE"
        }

        try await db.executeAsync("PRAGMA wal_checkpoint(\(modeString))")

        let walSizeAfter = try await getWALSize()
        let duration = Date().timeIntervalSince(startTime)

        return WALCheckpointResult(
            checkpointPerformed: true,
            walSizeBefore: walSizeBefore,
            walSizeAfter: walSizeAfter,
            duration: duration
        )
    }

    /// Configure WAL parameters for optimal performance.
    public func configureWAL() async throws {
        // Set WAL mode
        try await db.executeAsync("PRAGMA journal_mode = WAL")

        // Set WAL autocheckpoint threshold
        let autocheckpoint = config.autoCheckpointFrames
        try await db.executeAsync("PRAGMA wal_autocheckpoint = \(autocheckpoint)")

        // Synchronous mode for durability
        try await db.executeAsync("PRAGMA synchronous = NORMAL")

        // Memory-mapped I/O for performance
        try await db.executeAsync("PRAGMA mmap_size = \(config.mmapSize)")
    }
}

/// Database maintenance operations (VACUUM, ANALYZE).
public actor DatabaseMaintenance {
    private let db: DatabaseActor
    private let config: MaintenanceConfig

    public init(database: DatabaseActor, config: MaintenanceConfig = .default) {
        self.db = database
        self.config = config
    }

    /// Get current database file size.
    public func getDatabaseSize() async throws -> Int64 {
        let dbPath = db.path
        if FileManager.default.fileExists(atPath: dbPath) {
            let attributes = try FileManager.default.attributesOfItem(atPath: dbPath)
            if let size = attributes[FileAttributeKey.size] as? NSNumber {
                return size.int64Value
            }
        }
        return 0
    }

    /// Run full VACUUM if fragmentation exceeds threshold.
    public func vacuumIfNeeded() async throws -> VacuumResult {
        let pageCounts = try await getPageCounts()
        let fragmentationRatio = Double(pageCounts.freePages) / Double(pageCounts.totalPages)

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
            try await db.executeAsync("VACUUM")
        case .incremental:
            let incrPages = config.incrementalVacuumPages
            try await db.executeAsync("PRAGMA incremental_vacuum(\(incrPages))")
        }

        let sizeAfter = try await getDatabaseSize()
        let duration = Date().timeIntervalSince(startTime)
        let pageCounts = try await getPageCounts()
        let fragmentationRatio = Double(pageCounts.freePages) / Double(pageCounts.totalPages)

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
        let pageCounts = try await getPageCounts()
        let fragmentationRatio = Double(pageCounts.freePages) / Double(pageCounts.totalPages)

        if fragmentationRatio >= config.fragmentationThreshold {
            result.vacuumResult = try await performVacuum(mode: .full)
        }

        return result
    }

    /// Retrieve current database health metrics (delegates to DatabaseActor).
    public func getDatabaseHealthStats() async throws -> DatabaseHealthStats {
        try await db.getDatabaseHealthStats()
    }

    /// Get page count statistics.
    private func getPageCounts() async throws -> PageCounts {
        let rows = try await db.query("PRAGMA page_count")
        let pageCount = rows.first?.int(for: "page_count") ?? 0

        let freeRows = try await db.query("PRAGMA freelist_count")
        let freePages = freeRows.first?.int(for: "freelist_count") ?? 0

        return PageCounts(totalPages: pageCount, freePages: freePages)
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
    public let autoCheckpointFrames: Int
    public let mmapSize: Int

    public static let `default` = WALConfig(
        checkpointThresholdMb: 10,
        checkpointMode: .truncate,
        autoCheckpointFrames: 1000,
        mmapSize: 30_000_000 // 30MB
    )

    public static let aggressive = WALConfig(
        checkpointThresholdMb: 5,
        checkpointMode: .truncate,
        autoCheckpointFrames: 500,
        mmapSize: 30_000_000
    )

    public static let conservative = WALConfig(
        checkpointThresholdMb: 50,
        checkpointMode: .restart,
        autoCheckpointFrames: 5000,
        mmapSize: 30_000_000
    )

    public init(
        checkpointThresholdMb: Int = 10,
        checkpointMode: WALCheckpointMode = .truncate,
        autoCheckpointFrames: Int = 1000,
        mmapSize: Int = 30_000_000
    ) {
        self.checkpointThresholdMb = checkpointThresholdMb
        self.checkpointMode = checkpointMode
        self.autoCheckpointFrames = autoCheckpointFrames
        self.mmapSize = mmapSize
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

/// Page count information.
private struct PageCounts: Sendable {
    let totalPages: Int
    let freePages: Int
}
