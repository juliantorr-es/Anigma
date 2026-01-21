//
//  Swift6MigrationState.swift
//  HarmoniaModule
//
//  Explicit state model for Swift 6 migration domain.
//

import Foundation

/// Outcome of a session for a Swift 6 migration task.
public struct Swift6SessionOutcome: Sendable, Codable {
    /// Session index.
    public var sessionIndex: Int

    /// Health score from the session.
    public var healthScore: Double

    /// Whether the session was tainted.
    public var tainted: Bool

    /// Configuration ID used for the session.
    public var configId: String

    /// Feature category of the session.
    public var featureCategory: String

    /// When the session occurred.
    public var timestamp: Date

    /// Creates a new session outcome.
    public init(
        sessionIndex: Int,
        healthScore: Double,
        tainted: Bool,
        configId: String,
        featureCategory: String,
        timestamp: Date = Date()
    ) {
        self.sessionIndex = sessionIndex
        self.healthScore = healthScore
        self.tainted = tainted
        self.configId = configId
        self.featureCategory = featureCategory
        self.timestamp = timestamp
    }
}

/// Summary of a file's Swift 6 migration status.
public struct Swift6FileSummary: Sendable, Codable {
    /// File path.
    public var path: String

    /// All scout findings for this file.
    public var findings: [ScoutFinding]

    /// Migration tasks for this file.
    public var tasks: [MigrationTask]

    /// Index of the last session that touched this file.
    public var lastTouchedSession: Int?

    /// Outcome of the last session for this file.
    public var lastOutcome: Swift6SessionOutcome?

    /// Whether this file has any tainted sessions in recent history.
    public var hasRecentTaintedSessions: Bool

    /// Creates a new file summary.
    public init(
        path: String,
        findings: [ScoutFinding],
        tasks: [MigrationTask],
        lastTouchedSession: Int? = nil,
        lastOutcome: Swift6SessionOutcome? = nil,
        hasRecentTaintedSessions: Bool = false
    ) {
        self.path = path
        self.findings = findings
        self.tasks = tasks
        self.lastTouchedSession = lastTouchedSession
        self.lastOutcome = lastOutcome
        self.hasRecentTaintedSessions = hasRecentTaintedSessions
    }

    /// Number of open tasks for this file.
    public var openTaskCount: Int {
        tasks.filter { $0.status == .pending || $0.status == .active }.count
    }

    /// Highest severity among findings for this file.
    public var highestSeverity: ScoutFindingSeverity {
        findings.map { $0.severity }.max() ?? .info
    }

    /// Whether this file has any pending migration work.
    public var hasPendingWork: Bool {
        openTaskCount > 0
    }
}

/// Complete state snapshot for Swift 6 migration domain.
public struct Swift6MigrationState: Sendable, Codable {
    /// Project identifier.
    public var projectId: UUID

    /// Total number of scout findings.
    public var totalFindings: Int

    /// Total number of migration tasks.
    public var totalTasks: Int

    /// Number of open (pending/active) tasks.
    public var openTasks: Int

    /// Number of tainted sessions in recent history.
    public var taintedSessions: Int

    /// Recent session outcomes (last N sessions).
    public var recentSessions: [Swift6SessionOutcome]

    /// File summaries grouped by file path.
    public var files: [Swift6FileSummary]

    /// Overall health score (average of recent sessions).
    public var overallHealthScore: Double

    /// Whether migration is complete (no open tasks).
    public var isComplete: Bool {
        openTasks == 0
    }

    /// Creates a new migration state.
    public init(
        projectId: UUID,
        totalFindings: Int,
        totalTasks: Int,
        openTasks: Int,
        taintedSessions: Int,
        recentSessions: [Swift6SessionOutcome],
        files: [Swift6FileSummary],
        overallHealthScore: Double
    ) {
        self.projectId = projectId
        self.totalFindings = totalFindings
        self.totalTasks = totalTasks
        self.openTasks = openTasks
        self.taintedSessions = taintedSessions
        self.recentSessions = recentSessions
        self.files = files
        self.overallHealthScore = overallHealthScore
    }

    /// Files with pending work, sorted by priority.
    public var filesWithPendingWork: [Swift6FileSummary] {
        files.filter { $0.hasPendingWork }.sorted { file1, file2 in
            // Sort by: highest severity first, then most open tasks
            if file1.highestSeverity != file2.highestSeverity {
                return file1.highestSeverity.rawValue > file2.highestSeverity.rawValue
            }
            return file1.openTaskCount > file2.openTaskCount
        }
    }

    /// Files that have had tainted sessions recently.
    public var filesWithRecentTaintedSessions: [Swift6FileSummary] {
        files.filter { $0.hasRecentTaintedSessions }
    }

    /// Whether there are any files with recent tainted sessions.
    public var hasRecentTaintedFiles: Bool {
        !filesWithRecentTaintedSessions.isEmpty
    }
}

/// Policy configuration for Swift 6 migration.
public struct Swift6MigrationPolicy: Sendable, Codable {
    /// Maximum number of files to work on per session.
    public var maxFilesPerSession: Int

    /// Whether to avoid files with recent tainted sessions.
    public var avoidTaintedAreas: Bool

    /// Number of sessions to consider "recent" for taint avoidance.
    public var taintMemorySessions: Int

    /// Preference for high severity tasks.
    public var preferHighSeverity: Bool

    /// Whether to allow rescouts when no tasks are available.
    public var allowRescouts: Bool

    /// Default policy for self-host projects.
    public static let `default` = Swift6MigrationPolicy(
        maxFilesPerSession: 1,
        avoidTaintedAreas: true,
        taintMemorySessions: 3,
        preferHighSeverity: true,
        allowRescouts: true
    )

    /// Creates a new migration policy.
    public init(
        maxFilesPerSession: Int = 1,
        avoidTaintedAreas: Bool = true,
        taintMemorySessions: Int = 3,
        preferHighSeverity: Bool = true,
        allowRescouts: Bool = true
    ) {
        self.maxFilesPerSession = maxFilesPerSession
        self.avoidTaintedAreas = avoidTaintedAreas
        self.taintMemorySessions = taintMemorySessions
        self.preferHighSeverity = preferHighSeverity
        self.allowRescouts = allowRescouts
    }
}
