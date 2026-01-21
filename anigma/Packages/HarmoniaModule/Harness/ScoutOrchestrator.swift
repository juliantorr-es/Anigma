//
//  ScoutOrchestrator.swift
//  HarmoniaModule
//
//  Orchestrates scout execution and migration task management.
//

import Foundation

/// Protocol for project scouts.
public protocol ProjectScout: Sendable {
    /// Scans a project for issues.
    /// - Parameter projectId: The project identifier.
    /// - Returns: Array of scout findings.
    func scan(projectId: UUID) async throws -> [ScoutFinding]
}

/// Orchestrates scout execution and migration task management.
public actor ScoutOrchestrator {
    /// The project harness store.
    private let store: ProjectHarnessStore

    /// Registered scouts by name.
    private var scouts: [String: any ProjectScout]

    /// Creates a new scout orchestrator.
    /// - Parameter store: The project harness store.
    public init(store: ProjectHarnessStore) {
        self.store = store
        self.scouts = [:]
    }

    /// Registers a scout.
    /// - Parameters:
    ///   - scout: The scout to register.
    ///   - name: The name to register the scout under.
    public func register(scout: any ProjectScout, name: String) {
        scouts[name] = scout
    }

    /// Runs a scout for a project.
    /// - Parameters:
    ///   - scoutName: The name of the scout to run.
    ///   - projectId: The project identifier.
    ///   - createTasks: Whether to create migration tasks from findings.
    /// - Returns: Summary of the scout run.
    public func runScout(
        _ scoutName: String,
        for projectId: UUID,
        createTasks: Bool = true
    ) async throws -> ScoutRunSummary {
        guard let scout = scouts[scoutName] else {
            throw ScoutError.scoutNotFound(scoutName)
        }

        // Run the scout
        let findings = try await scout.scan(projectId: projectId)

        // Save findings
        try await store.saveScoutFindings(findings)

        // Create tasks if requested
        var tasksCreated = 0
        if createTasks {
            // Group findings by problem kind to create tasks
            let findingsByKind = Dictionary(grouping: findings) { $0.problemKind }

            for (problemKind, kindFindings) in findingsByKind {
                let tasks = try await createMigrationTasks(
                    from: kindFindings,
                    featureCategory: problemKind
                )
                tasksCreated += tasks.count
            }
        }

        // Calculate severity counts
        var severityCounts: [ScoutFindingSeverity: Int] = [:]
        for finding in findings {
            severityCounts[finding.severity, default: 0] += 1
        }

        return ScoutRunSummary(
            totalFindings: findings.count,
            findingsBySeverity: severityCounts,
            tasksCreated: tasksCreated
        )
    }

    /// Creates migration tasks from scout findings.
    /// - Parameters:
    ///   - findings: The scout findings to create tasks from.
    ///   - featureCategory: The feature category for the tasks.
    /// - Returns: Array of created migration tasks.
    public func createMigrationTasks(
        from findings: [ScoutFinding],
        featureCategory: String
    ) async throws -> [MigrationTask] {
        guard let firstFinding = findings.first else {
            return []
        }

        let projectId = firstFinding.projectId

        // Create one task per finding (could be optimized later)
        var tasks: [MigrationTask] = []
        var taskIds: [UUID: UUID] = [:] // findingId -> taskId

        for finding in findings {
            let task = MigrationTask(
                projectId: projectId,
                featureCategory: featureCategory,
                status: .pending,
                priority: priorityForSeverity(finding.severity),
                findingId: finding.id
            )
            tasks.append(task)
            taskIds[finding.id] = task.id
        }

        // Save tasks
        try await store.saveMigrationTasks(tasks)

        // Associate findings with their tasks
        for (findingId, taskId) in taskIds {
            try await store.associateFindingWithTask(findingId: findingId, taskId: taskId)
        }

        return tasks
    }

    /// Gets the next pending migration tasks.
    /// - Parameters:
    ///   - projectId: The project identifier.
    ///   - featureCategory: Optional feature category filter.
    ///   - limit: Maximum number of tasks to return.
    /// - Returns: Array of pending migration tasks.
    public func nextPendingTasks(
        projectId: UUID,
        featureCategory: String? = nil,
        limit: Int = 10
    ) async throws -> [MigrationTask] {
        return try await store.getPendingMigrationTasks(
            projectId: projectId,
            featureCategory: featureCategory,
            limit: limit
        )
    }

    /// Marks a migration task as active.
    /// - Parameter taskId: The task identifier.
    public func markTaskActive(_ taskId: UUID) async throws {
        try await store.updateMigrationTaskStatus(taskId, status: .active)
    }

    /// Marks a migration task as completed.
    /// - Parameters:
    ///   - taskId: The task identifier.
    ///   - sessionIndex: Optional session index where the task was executed.
    public func markTaskCompleted(_ taskId: UUID, sessionIndex: Int? = nil) async throws {
        try await store.markMigrationTaskCompleted(taskId, sessionIndex: sessionIndex)
    }

    /// Marks a migration task as failed.
    /// - Parameters:
    ///   - taskId: The task identifier.
    ///   - sessionIndex: Optional session index where the task failed.
    public func markTaskFailed(_ taskId: UUID, sessionIndex: Int? = nil) async throws {
        try await store.markMigrationTaskFailed(taskId, sessionIndex: sessionIndex)
    }

    /// Gets migration tasks for a project.
    /// - Parameters:
    ///   - projectId: The project identifier.
    ///   - featureCategory: Optional feature category filter.
    ///   - status: Optional status filter.
    ///   - limit: Maximum number of tasks to return.
    /// - Returns: Array of migration tasks.
    public func getTasks(
        projectId: UUID,
        featureCategory: String? = nil,
        status: MigrationTaskStatus? = nil,
        limit: Int = 100
    ) async throws -> [MigrationTask] {
        return try await store.getMigrationTasks(
            projectId: projectId,
            featureCategory: featureCategory,
            status: status,
            limit: limit
        )
    }

    /// Gets scout findings for a project.
    /// - Parameters:
    ///   - projectId: The project identifier.
    ///   - problemKind: Optional problem kind filter.
    ///   - severity: Optional severity filter.
    ///   - limit: Maximum number of findings to return.
    /// - Returns: Array of scout findings.
    public func getFindings(
        projectId: UUID,
        problemKind: String? = nil,
        severity: ScoutFindingSeverity? = nil,
        limit: Int = 100
    ) async throws -> [ScoutFinding] {
        return try await store.getScoutFindings(
            projectId: projectId,
            problemKind: problemKind,
            severity: severity,
            limit: limit
        )
    }

    /// Gets unassigned scout findings (without associated tasks).
    /// - Parameters:
    ///   - projectId: The project identifier.
    ///   - limit: Maximum number of findings to return.
    /// - Returns: Array of unassigned scout findings.
    public func getUnassignedFindings(projectId: UUID, limit: Int = 100) async throws -> [ScoutFinding] {
        return try await store.getUnassignedScoutFindings(projectId: projectId, limit: limit)
    }

    // MARK: - Private Helpers

    /// Gets priority for a severity level.
    private func priorityForSeverity(_ severity: ScoutFindingSeverity) -> Int {
        switch severity {
        case .critical: return 100
        case .error: return 75
        case .warning: return 50
        case .info: return 25
        }
    }
}

// MARK: - Errors

/// Scout-related errors.
public enum ScoutError: Error, Sendable {
    /// Scout not found.
    case scoutNotFound(String)

    /// No pending tasks.
    case noPendingTasks

    /// Task not found.
    case taskNotFound(UUID)

    /// Finding not found.
    case findingNotFound(UUID)
}

extension ScoutError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .scoutNotFound(let name):
            return "Scout not found: \(name)"
        case .noPendingTasks:
            return "No pending migration tasks"
        case .taskNotFound(let id):
            return "Migration task not found: \(id)"
        case .findingNotFound(let id):
            return "Scout finding not found: \(id)"
        }
    }
}
