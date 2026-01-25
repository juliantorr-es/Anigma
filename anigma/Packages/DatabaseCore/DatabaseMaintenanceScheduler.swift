//
//  DatabaseMaintenanceScheduler.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Scheduler for automated database maintenance operations.
/// Coordinates VACUUM and ANALYZE based on usage patterns and time intervals.
public actor DatabaseMaintenanceScheduler {
    private let db: DatabaseActor
    private let config: MaintenanceScheduleConfig
    private var isRunning = false
    private var maintenanceTask: Task<Void, Error>?

    public init(database: DatabaseActor, config: MaintenanceScheduleConfig = .default) {
        self.db = database
        self.config = config
    }

    /// Start the scheduled maintenance task.
    public func startScheduling() async throws {
        guard !isRunning else { return }

        isRunning = true

        // Create maintenance task
        maintenanceTask = Task {
            while isRunning && !Task.isCancelled {
                // Run maintenance cycle
                let maintenance = DatabaseMaintenance(database: db, config: config.maintenanceConfig)

                // Check if we should run ANALYZE
                if shouldRunAnalyze() {
                    _ = try await maintenance.analyzeDatabase()
                }

                // Check if we should run VACUUM
                if shouldRunVacuum() {
                    _ = try await maintenance.runFullMaintenance()
                }

                // Wait for next schedule check
                try await Task.sleep(nanoseconds: UInt64(config.checkIntervalSeconds * 1_000_000_000))
            }
        }
    }

    /// Stop the scheduled maintenance task.
    public func stopScheduling() async {
        isRunning = false
        maintenanceTask?.cancel()
        maintenanceTask = nil
    }

    /// Force a maintenance run regardless of schedule.
    public func forceMaintenanceRun() async throws {
        let maintenance = DatabaseMaintenance(database: db, config: config.maintenanceConfig)
        _ = try await maintenance.runFullMaintenance()
    }

    /// Get the schedule status.
    public func getScheduleStatus() -> MaintenanceScheduleStatus {
        return MaintenanceScheduleStatus(
            isRunning: isRunning,
            config: config,
            lastCheck: Date()
        )
    }

    /// Check if ANALYZE should run based on schedule.
    private func shouldRunAnalyze() -> Bool {
        // In production, this would check actual last run time from database
        return true // Simplified for demo
    }

    /// Check if VACUUM should run based on fragmentation or schedule.
    private func shouldRunVacuum() -> Bool {
        // In production, this would check actual fragmentation metrics
        return false // Simplified for demo to avoid frequent VACUUM
    }
}

/// Configuration for maintenance scheduling.
public struct MaintenanceScheduleConfig: Sendable, Codable {
    public let checkIntervalSeconds: TimeInterval
    public let maintenanceConfig: MaintenanceConfig
    public let enableAutoVacuum: Bool
    public let enableAutoAnalyze: Bool
    public let preferredMaintenanceHours: ClosedRange<Int> // 0-23 hours

    public static let `default` = MaintenanceScheduleConfig(
        checkIntervalSeconds: 3600, // 1 hour
        maintenanceConfig: .default,
        enableAutoVacuum: true,
        enableAutoAnalyze: true,
        preferredMaintenanceHours: 2...5 // 2AM-5AM
    )

    public static let aggressive = MaintenanceScheduleConfig(
        checkIntervalSeconds: 1800, // 30 minutes
        maintenanceConfig: .aggressive,
        enableAutoVacuum: true,
        enableAutoAnalyze: true,
        preferredMaintenanceHours: 0...6 // 12AM-6AM
    )

    public static let conservative = MaintenanceScheduleConfig(
        checkIntervalSeconds: 86400, // 24 hours
        maintenanceConfig: .conservative,
        enableAutoVacuum: true,
        enableAutoAnalyze: true,
        preferredMaintenanceHours: 3...4 // 3AM-4AM
    )

    public init(
        checkIntervalSeconds: TimeInterval = 3600,
        maintenanceConfig: MaintenanceConfig = .default,
        enableAutoVacuum: Bool = true,
        enableAutoAnalyze: Bool = true,
        preferredMaintenanceHours: ClosedRange<Int> = 2...5
    ) {
        self.checkIntervalSeconds = checkIntervalSeconds
        self.maintenanceConfig = maintenanceConfig
        self.enableAutoVacuum = enableAutoVacuum
        self.enableAutoAnalyze = enableAutoAnalyze
        self.preferredMaintenanceHours = preferredMaintenanceHours
    }
}

/// Current status of the maintenance scheduler.
public struct MaintenanceScheduleStatus: Sendable, Codable {
    public let isRunning: Bool
    public let config: MaintenanceScheduleConfig
    public let lastCheck: Date

    public init(isRunning: Bool, config: MaintenanceScheduleConfig, lastCheck: Date = Date()) {
        self.isRunning = isRunning
        self.config = config
        self.lastCheck = lastCheck
    }
}

/// Maintenance history tracker.
public actor MaintenanceHistory {
    private let db: DatabaseActor
    private let maxHistoryCount: Int

    public init(database: DatabaseActor, maxHistoryCount: Int = 100) {
        self.db = database
        self.maxHistoryCount = maxHistoryCount
    }

    /// Record a maintenance operation.
    public func recordMaintenance(
        operation: MaintenanceOperation,
        result: MaintenanceOperationResult
    ) async throws {
        let timestamp = Date().timeIntervalSince1970
        let resultData = try JSONEncoder().encode(result)
        let resultJson = String(data: resultData, encoding: .utf8) ?? "{}"

        try await db.executeAsync("""
            INSERT INTO maintenance_history (
                operation_id, operation_type, started_at, completed_at,
                result_json, config_json
            ) VALUES (?, ?, ?, ?, ?, ?)
        """, parameters: [
            .text(UUID().uuidString),
            .text(operation.rawValue),
            .double(timestamp),
            .double(timestamp),
            .text(resultJson),
            .text("{}")
        ])

        // Trim old history
        try await trimHistory()
    }

    /// Get recent maintenance history.
    public func getRecentHistory(limit: Int = 10) async throws -> [MaintenanceHistoryEntry] {
        let rows = try await db.query("""
            SELECT operation_id, operation_type, started_at, completed_at,
                   result_json, config_json
            FROM maintenance_history
            ORDER BY started_at DESC
            LIMIT ?
        """, parameters: [.int(limit)])

        return rows.compactMap { row in
            guard let id = row.string(for: "operation_id"),
                  let operationString = row.string(for: "operation_type"),
                  let operation = MaintenanceOperation(rawValue: operationString),
                  let resultJson = row.string(for: "result_json"),
                  let resultData = resultJson.data(using: .utf8),
                  let result = try? JSONDecoder().decode(MaintenanceOperationResult.self, from: resultData),
                  let startedAtDouble = row.double(for: "started_at") else {
                return nil
            }

            let completedAt = Date(timeIntervalSince1970: startedAtDouble)

            return MaintenanceHistoryEntry(
                operationId: id,
                operation: operation,
                startedAt: completedAt,
                completedAt: completedAt,
                result: result
            )
        }
    }

    /// Trim old history entries.
    private func trimHistory() async throws {
        try await db.executeAsync("""
            DELETE FROM maintenance_history
            WHERE id NOT IN (
                SELECT id FROM maintenance_history
                ORDER BY started_at DESC
                LIMIT ?
            )
        """, parameters: [.int(maxHistoryCount)])
    }
}

/// Types of maintenance operations.
public enum MaintenanceOperation: String, Sendable, Codable {
    case walCheckpoint = "wal_checkpoint"
    case vacuum = "vacuum"
    case analyze = "analyze"
    case fullMaintenance = "full_maintenance"
}

/// Result of a maintenance operation.
public struct MaintenanceOperationResult: Sendable, Codable {
    public let success: Bool
    public let durationSeconds: TimeInterval
    public let bytesFreed: Int64
    public let errorMessage: String?

    public init(
        success: Bool = true,
        durationSeconds: TimeInterval = 0,
        bytesFreed: Int64 = 0,
        errorMessage: String? = nil
    ) {
        self.success = success
        self.durationSeconds = durationSeconds
        self.bytesFreed = bytesFreed
        self.errorMessage = errorMessage
    }
}

/// Entry in maintenance history.
public struct MaintenanceHistoryEntry: Sendable, Codable {
    public let operationId: String
    public let operation: MaintenanceOperation
    public let startedAt: Date
    public let completedAt: Date
    public let result: MaintenanceOperationResult
}
