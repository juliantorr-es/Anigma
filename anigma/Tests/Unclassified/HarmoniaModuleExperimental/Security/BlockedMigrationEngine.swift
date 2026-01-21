//
//  BlockedMigrationEngine.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Placeholder engine returned when capabilities are insufficient.
//  Creates debt tasks for security violations.
//

import Foundation
import SQLite3
import AnigmaCore
import HarmoniaModule

// MARK: - Blocked Migration Engine

/// Engine returned when capability validation fails.
/// Creates debt tasks for security violations instead of processing.
public struct BlockedMigrationEngine: MigrationEngine {
    public let reason: String
    public let taskId: String
    public let engineType: EngineType // Still needs to be moved
    public let timestamp: Date

    public init(
        reason: String,
        taskId: String,
        engineType: EngineType, // Still needs to be moved
        timestamp: Date = Date()
    ) {
        self.reason = reason
        self.taskId = taskId
        self.engineType = engineType
        self.timestamp = timestamp
    }

    public func process(task: AnigmaCore.MigrationTaskRow, db: OpaquePointer?) async throws -> MigrationResult {
        logWarning("BlockedMigrationEngine processing task \(task.id) - capability violation", category: "BlockedEngine")

        // 1. Create capability debt task in database
        let debtTaskCreated = createCapabilityDebtTask(task: task, db: db)

        // 2. Log the blocking event
        logBlockingEvent(task: task, debtTaskCreated: debtTaskCreated)

        // 3. Return blocked result
        return .failed(errorDescription: """
        Blocked by security policy: \(reason)

        Engine type: \(engineType.rawValue)
        Task: \(task.id)
        Feature category: \(task.featureCategory)

        A capability debt task has been created. Fix the security violation before retrying.
        """)
    }

    /// Create a capability debt task in the database.
    private func createCapabilityDebtTask(task: AnigmaCore.MigrationTaskRow, db: OpaquePointer?) -> Bool {
        let debtTask = CapabilityDebtTask(
            id: UUID().uuidString,
            originalTaskId: task.id,
            engineType: engineType, // Still needs to be moved
            reason: reason,
            createdAt: timestamp,
            status: .pending,
            priority: .high
        )

        do {
            try insertDebtTask(debtTask, db: db)
            logInfo("Capability debt task created: \(debtTask.id)", category: "BlockedEngine")
            return true
        } catch {
            logError("Failed to create capability debt task: \(error)", category: "BlockedEngine")
            return false
        }
    }

    /// Insert debt task into database.
    private func insertDebtTask(_ debtTask: CapabilityDebtTask, db: OpaquePointer?) throws {
        var stmt: OpaquePointer?
        let sql = """
        INSERT OR REPLACE INTO capability_debt_tasks (
            id, original_task_id, engine_type, reason, created_at,
            status, priority, resolved_at, resolution
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare statement: \(errMsg)"])
        }

        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, debtTask.id, -1, nil)
        sqlite3_bind_text(stmt, 2, debtTask.originalTaskId, -1, nil)
        sqlite3_bind_text(stmt, 3, debtTask.engineType.rawValue, -1, nil)
        sqlite3_bind_text(stmt, 4, debtTask.reason, -1, nil)
        sqlite3_bind_double(stmt, 5, debtTask.createdAt.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 6, debtTask.status.rawValue, -1, nil)
        sqlite3_bind_text(stmt, 7, debtTask.priority.rawValue, -1, nil)

        if let resolvedAt = debtTask.resolvedAt {
            sqlite3_bind_double(stmt, 8, resolvedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 8)
        }

        if let resolution = debtTask.resolution {
            sqlite3_bind_text(stmt, 9, resolution, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 9)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert debt task: \(errMsg)"])
        }

        logDebug("Capability debt task inserted: \(debtTask.id)", category: "BlockedEngine")
    }

    /// Log blocking event for audit trail.
    private func logBlockingEvent(task: AnigmaCore.MigrationTaskRow, debtTaskCreated: Bool) {
        // Log to console for immediate visibility
        let event = [
            "type": "capability_blocked",
            "task_id": task.id,
            "engine_type": engineType.rawValue, // Still needs to be moved
            "reason": reason,
            "debt_task_created": debtTaskCreated,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "feature_category": task.featureCategory
        ]

        if let eventData = try? JSONSerialization.data(withJSONObject: event, options: .prettyPrinted),
           let eventString = String(data: eventData, encoding: .utf8) {
            print("[SECURITY][BLOCKED] \(eventString)")
        }

        // Log to security events database for observability
        // SecurityEventsManager needs to be instantiated from AnigmaCore or passed in
        let securityManager = SecurityEventsManager(dbPath: "harmonia_harness.sqlite")
        securityManager.emitCapabilityBlocked(
            engineId: engineType.rawValue, // Still needs to be moved
            operation: "migration_engine_blocked",
            severity: .high,
            details: [
                "task_id": task.id,
                "reason": reason,
                "debt_task_created": String(debtTaskCreated),
                "feature_category": task.featureCategory
            ]
        )
    }
}

// MARK: - Capability Debt Task

/// Debt task created when capability validation fails.
public struct CapabilityDebtTask: Sendable, Codable {
    public let id: String
    public let originalTaskId: String
    public let engineType: EngineType // Still needs to be moved
    public let reason: String
    public let createdAt: Date
    public let status: DebtTaskStatus
    public let priority: DebtTaskPriority
    public let resolvedAt: Date?
    public let resolution: String?

    public init(
        id: String = UUID().uuidString,
        originalTaskId: String,
        engineType: EngineType, // Still needs to be moved
        reason: String,
        createdAt: Date = Date(),
        status: DebtTaskStatus = .pending,
        priority: DebtTaskPriority = .medium,
        resolvedAt: Date? = nil,
        resolution: String? = nil
    ) {
        self.id = id
        self.originalTaskId = originalTaskId
        self.engineType = engineType
        self.reason = reason
        self.createdAt = createdAt
        self.status = status
        self.priority = priority
        self.resolvedAt = resolvedAt
        self.resolution = resolution
    }
}

/// Status of a capability debt task.
public enum DebtTaskStatus: String, Sendable, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case resolved = "resolved"
    case ignored = "ignored"
}

/// Priority of a capability debt task.
public enum DebtTaskPriority: String, Sendable, Codable, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    public static func < (lhs: DebtTaskPriority, rhs: DebtTaskPriority) -> Bool {
        let order: [DebtTaskPriority] = [.low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Debt Task Service

/// Service for managing capability debt tasks.
public actor CapabilityDebtTaskService {
    private let dbPath: String

    public init(dbPath: String = "harmonia_harness.sqlite") {
        self.dbPath = dbPath
    }

    /// Get all pending capability debt tasks.
    public func getPendingDebtTasks() throws -> [CapabilityDebtTask] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open database"])
        }
        defer { sqlite3_close(db) }

        ensureDebtTasksTableExists(db: db)

        var stmt: OpaquePointer?
        let sql = "SELECT * FROM capability_debt_tasks WHERE status = 'pending' ORDER BY created_at DESC"

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare query"])
        }
        defer { sqlite3_finalize(stmt) }

        var tasks: [CapabilityDebtTask] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let task = parseDebtTask(from: stmt) {
                tasks.append(task)
            }
        }

        return tasks
    }

    /// Get debt tasks by engine type.
    public func getDebtTasks(for engineType: EngineType) throws -> [CapabilityDebtTask] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open database"])
        }
        defer { sqlite3_close(db) }

        ensureDebtTasksTableExists(db: db)

        var stmt: OpaquePointer?
        let sql = "SELECT * FROM capability_debt_tasks WHERE engine_type = ? ORDER BY created_at DESC"

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare query"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, engineType.rawValue, -1, nil)

        var tasks: [CapabilityDebtTask] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let task = parseDebtTask(from: stmt) {
                tasks.append(task)
            }
        }

        return tasks
    }

    /// Update debt task status.
    public func updateDebtTaskStatus(
        _ taskId: String,
        status: DebtTaskStatus,
        resolution: String? = nil
    ) throws {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open database"])
        }
        defer { sqlite3_close(db) }

        ensureDebtTasksTableExists(db: db)

        var stmt: OpaquePointer?
        let sql: String
        let resolvedAt = status == .resolved ? Date() : nil

        if let resolution = resolution {
            sql = "UPDATE capability_debt_tasks SET status = ?, resolution = ?, resolved_at = ? WHERE id = ?"
        } else {
            sql = "UPDATE capability_debt_tasks SET status = ?, resolved_at = ? WHERE id = ?"
        }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare update"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, status.rawValue, -1, nil)

        if let resolution = resolution {
            sqlite3_bind_text(stmt, 2, resolution, -1, nil)
            if let resolvedAt = resolvedAt {
                sqlite3_bind_double(stmt, 3, resolvedAt.timeIntervalSince1970)
                sqlite3_bind_text(stmt, 4, taskId, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 3)
                sqlite3_bind_text(stmt, 4, taskId, -1, nil)
            }
        } else {
            if let resolvedAt = resolvedAt {
                sqlite3_bind_double(stmt, 2, resolvedAt.timeIntervalSince1970)
                sqlite3_bind_text(stmt, 3, taskId, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 2)
                sqlite3_bind_text(stmt, 3, taskId, -1, nil)
            }
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to update debt task: \(errMsg)"])
        }

        logInfo("Updated debt task \(taskId) status to \(status.rawValue)", category: "DebtTaskService")
    }

    /// Get statistics about capability debt tasks.
    public func getDebtTaskStatistics() throws -> [String: Any] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open database"])
        }
        defer { sqlite3_close(db) }

        ensureDebtTasksTableExists(db: db)

        var stats: [String: Any] = [:]

        // Total tasks
        var stmt: OpaquePointer?
        let totalSql = "SELECT COUNT(*) FROM capability_debt_tasks"
        if sqlite3_prepare_v2(db, totalSql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                stats["total"] = Int(sqlite3_column_int(stmt, 0))
            }
            sqlite3_finalize(stmt)
        }

        // Tasks by status
        let statusSql = "SELECT status, COUNT(*) FROM capability_debt_tasks GROUP BY status"
        if sqlite3_prepare_v2(db, statusSql, -1, &stmt, nil) == SQLITE_OK {
            var statusCounts: [String: Int] = [:]
            while sqlite3_step(stmt) == SQLITE_ROW {
                let status = String(cString: sqlite3_column_text(stmt, 0))
                let count = Int(sqlite3_column_int(stmt, 1))
                statusCounts[status] = count
            }
            stats["by_status"] = statusCounts
            sqlite3_finalize(stmt)
        }

        // Tasks by engine type
        let engineSql = "SELECT engine_type, COUNT(*) FROM capability_debt_tasks GROUP BY engine_type"
        if sqlite3_prepare_v2(db, engineSql, -1, &stmt, nil) == SQLITE_OK {
            var engineCounts: [String: Int] = [:]
            while sqlite3_step(stmt) == SQLITE_ROW {
                let engineType = String(cString: sqlite3_column_text(stmt, 0))
                let count = Int(sqlite3_column_int(stmt, 1))
                engineCounts[engineType] = count
            }
            stats["by_engine_type"] = engineCounts
            sqlite3_finalize(stmt)
        }

        // Oldest pending task
        let oldestSql = "SELECT created_at FROM capability_debt_tasks WHERE status = 'pending' ORDER BY created_at ASC LIMIT 1"
        if sqlite3_prepare_v2(db, oldestSql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_double(stmt, 0)
                let date = Date(timeIntervalSince1970: timestamp)
                stats["oldest_pending"] = ISO8601DateFormatter().string(from: date)
            }
            sqlite3_finalize(stmt)
        }

        return stats
    }

    // MARK: - Private Helpers

    private func ensureDebtTasksTableExists(db: OpaquePointer?) {
        let createTable = """
        CREATE TABLE IF NOT EXISTS capability_debt_tasks (
            id TEXT PRIMARY KEY,
            original_task_id TEXT NOT NULL,
            engine_type TEXT NOT NULL,
            reason TEXT NOT NULL,
            created_at REAL NOT NULL,
            status TEXT NOT NULL,
            priority TEXT NOT NULL,
            resolved_at REAL,
            resolution TEXT,
            FOREIGN KEY (original_task_id) REFERENCES migration_tasks(id)
        )
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, createTable, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    private func parseDebtTask(from stmt: OpaquePointer?) -> CapabilityDebtTask? {
        guard let id = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
              let originalTaskId = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
              let engineTypeStr = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }),
              let engineType = EngineType(rawValue: engineTypeStr), // Still needs to be moved
              let reason = sqlite3_column_text(stmt, 3).map({ String(cString: $0) }),
              let statusStr = sqlite3_column_text(stmt, 5).map({ String(cString: $0) }),
              let status = DebtTaskStatus(rawValue: statusStr),
              let priorityStr = sqlite3_column_text(stmt, 6).map({ String(cString: $0) }),
              let priority = DebtTaskPriority(rawValue: priorityStr) else {
            return nil
        }

        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))

        let resolvedAt: Date?
        if sqlite3_column_type(stmt, 7) != SQLITE_NULL {
            resolvedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
        } else {
            resolvedAt = nil
        }

        let resolution: String?
        if sqlite3_column_type(stmt, 8) != SQLITE_NULL,
           let resolutionText = sqlite3_column_text(stmt, 8) {
            resolution = String(cString: resolutionText)
        } else {
            resolution = nil
        }

        return CapabilityDebtTask(
            id: id,
            originalTaskId: originalTaskId,
            engineType: engineType, // Still needs to be moved
            reason: reason,
            createdAt: createdAt,
            status: status,
            priority: priority,
            resolvedAt: resolvedAt,
            resolution: resolution
        )
    }
}

// MARK: - Logging Helper

private func logInfo(_ message: String, category: String) {
    print("[INFO][\(category)] \(message)")
}

private func logWarning(_ message: String, category: String) {
    print("[WARNING][\(category)] \(message)")
}

private func logError(_ message: String, category: String) {
    print("[ERROR][\(category)] \(message)")
}

private func logDebug(_ message: String, category: String) {
    #if DEBUG
    print("[DEBUG][\(category)] \(message)")
    #endif
}
