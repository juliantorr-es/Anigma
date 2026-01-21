//
//  ScoutModels.swift
//  HarmoniaModule
//
//  Models for scout findings and migration tasks.
//

import Foundation
import GRDB

// MARK: - Scout Finding

/// Severity of a scout finding.
public enum ScoutFindingSeverity: String, Codable, Sendable, DatabaseValueConvertible, Comparable {
    case info
    case warning
    case error
    case critical

    /// Compare severities based on their raw values.
    public static func < (lhs: ScoutFindingSeverity, rhs: ScoutFindingSeverity) -> Bool {
        let order: [ScoutFindingSeverity] = [.info, .warning, .error, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
            let rhsIndex = order.firstIndex(of: rhs)
        else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// A finding from a scout scan.
public struct ScoutFinding: Codable, Sendable, TableRecord, FetchableRecord, PersistableRecord {
    /// Unique identifier.
    public var id: UUID

    /// Project identifier.
    public var projectId: UUID

    /// Associated migration task (optional).
    public var taskId: UUID?

    /// File path where the issue was found.
    public var filePath: String

    /// Kind of problem (e.g., "swift6-concurrency", "deprecated-api").
    public var problemKind: String

    /// Severity of the finding.
    public var severity: ScoutFindingSeverity

    /// Human-readable description.
    public var description: String

    /// Suggested fix (optional).
    public var suggestedFix: String?

    /// Starting line number (optional).
    public var lineStart: Int?

    /// Ending line number (optional).
    public var lineEnd: Int?

    /// When the finding was created.
    public var createdAt: Date

    /// Associated AST anchor as JSON (optional).
    public var astAnchorJson: String?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        taskId: UUID? = nil,
        filePath: String,
        problemKind: String,
        severity: ScoutFindingSeverity,
        description: String,
        suggestedFix: String? = nil,
        lineStart: Int? = nil,
        lineEnd: Int? = nil,
        createdAt: Date = Date(),
        astAnchorJson: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.taskId = taskId
        self.filePath = filePath
        self.problemKind = problemKind
        self.severity = severity
        self.description = description
        self.suggestedFix = suggestedFix
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.createdAt = createdAt
        self.astAnchorJson = astAnchorJson
    }

    // MARK: - GRDB Table Configuration

    public static var databaseTableName: String { "scout_findings" }

    public enum Columns: String, ColumnExpression {
        case id, projectId, taskId, filePath, problemKind, severity, description
        case suggestedFix, lineStart, lineEnd, createdAt, astAnchorJson
    }
}

// MARK: - Migration Task

/// Status of a migration task.
public enum MigrationTaskStatus: String, Codable, Sendable, DatabaseValueConvertible {
    case pending
    case active
    case completed
    case failed
    case cancelled
}

/// A migration task created from scout findings.
public struct MigrationTask: Codable, Sendable, TableRecord, FetchableRecord, PersistableRecord {
    /// Unique identifier.
    public var id: UUID

    /// Project identifier.
    public var projectId: UUID

    /// Feature category (e.g., "swift6-migration").
    public var featureCategory: String

    /// Current status.
    public var status: MigrationTaskStatus

    /// Priority (higher = more important).
    public var priority: Int

    /// When the task was created.
    public var createdAt: Date

    /// When the task was started (optional).
    public var startedAt: Date?

    /// When the task was completed (optional).
    public var completedAt: Date?

    /// Associated session index (optional).
    public var sessionIndex: Int?

    /// Associated scout finding (optional).
    public var findingId: UUID?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        featureCategory: String,
        status: MigrationTaskStatus = .pending,
        priority: Int = 0,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        sessionIndex: Int? = nil,
        findingId: UUID? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.featureCategory = featureCategory
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.sessionIndex = sessionIndex
        self.findingId = findingId
    }

    // MARK: - GRDB Table Configuration

    public static var databaseTableName: String { "migration_tasks" }

    public enum Columns: String, ColumnExpression {
        case id, projectId, featureCategory, status, priority
        case createdAt, startedAt, completedAt, sessionIndex, findingId
    }
}

// MARK: - Scout Run Summary

/// Summary of a scout run.
public struct ScoutRunSummary: Sendable {
    /// Total findings count.
    public let totalFindings: Int

    /// Findings by severity.
    public let findingsBySeverity: [ScoutFindingSeverity: Int]

    /// Tasks created.
    public let tasksCreated: Int

    public init(
        totalFindings: Int,
        findingsBySeverity: [ScoutFindingSeverity: Int],
        tasksCreated: Int
    ) {
        self.totalFindings = totalFindings
        self.findingsBySeverity = findingsBySeverity
        self.tasksCreated = tasksCreated
    }
}

// MARK: - GRDB Migrations

extension ScoutFinding {
    /// Creates the database table.
    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column(Columns.id.rawValue, .text).primaryKey()
            t.column(Columns.projectId.rawValue, .text).notNull()
            t.column(Columns.taskId.rawValue, .text)
            t.column(Columns.filePath.rawValue, .text).notNull()
            t.column(Columns.problemKind.rawValue, .text).notNull()
            t.column(Columns.severity.rawValue, .text).notNull()
            t.column(Columns.description.rawValue, .text).notNull()
            t.column(Columns.suggestedFix.rawValue, .text)
            t.column(Columns.lineStart.rawValue, .integer)
            t.column(Columns.lineEnd.rawValue, .integer)
            t.column(Columns.createdAt.rawValue, .datetime).notNull()
            t.column(Columns.astAnchorJson.rawValue, .text)

            t.foreignKey(
                [Columns.projectId.rawValue], references: "project_specs", columns: ["id"],
                onDelete: .cascade)
            t.foreignKey(
                [Columns.taskId.rawValue], references: "migration_tasks", columns: ["id"],
                onDelete: .setNull)
        }
    }
}

extension MigrationTask {
    /// Creates the database table.
    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column(Columns.id.rawValue, .text).primaryKey()
            t.column(Columns.projectId.rawValue, .text).notNull()
            t.column(Columns.featureCategory.rawValue, .text).notNull()
            t.column(Columns.status.rawValue, .text).notNull()
            t.column(Columns.priority.rawValue, .integer).notNull()
            t.column(Columns.createdAt.rawValue, .datetime).notNull()
            t.column(Columns.startedAt.rawValue, .datetime)
            t.column(Columns.completedAt.rawValue, .datetime)
            t.column(Columns.sessionIndex.rawValue, .integer)
            t.column(Columns.findingId.rawValue, .text)

            t.foreignKey(
                [Columns.projectId.rawValue], references: "project_specs", columns: ["id"],
                onDelete: .cascade)
            t.foreignKey(
                [Columns.findingId.rawValue], references: "scout_findings", columns: ["id"],
                onDelete: .setNull)
        }
    }
}
