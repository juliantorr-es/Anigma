//
//  ProjectHarnessStore+Scouts.swift
//  HarmoniaModule
//
//  Store extensions for scout findings and migration tasks.
//

import Foundation
import GRDB

// MARK: - Scout Findings Store Methods

extension ProjectHarnessStore {
    /// Saves scout findings to the database.
    public func saveScoutFindings(_ findings: [ScoutFinding]) async throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try await dbPool.write { db in
            for finding in findings {
                try finding.save(db)
            }
        }
    }

    /// Lists recent sessions for this project.
    /// Required by ProjectExecutionSurface protocol.
    public func listRecentSessions(limit: Int) async throws -> [SessionReport] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }
        let resolvedProjectId = projectId

        return try await dbPool.read { db in
            let request = SessionReport.filter(ScoutFinding.Columns.projectId == resolvedProjectId)
                .order(SessionReport.Columns.generatedAt.desc)
                .limit(limit)

            return try request.fetchAll(db)
        }
    }

    /// Gets scout findings for a project.
    public func getScoutFindings(
        projectId: UUID,
        problemKind: String? = nil,
        severity: ScoutFindingSeverity? = nil,
        limit: Int = 100
    ) async throws -> [ScoutFinding] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }
        let resolvedProjectId = projectId

        return try await dbPool.read { db in
            var request = ScoutFinding.filter(ScoutFinding.Columns.projectId == resolvedProjectId)

            if let problemKind = problemKind {
                request = request.filter(ScoutFinding.Columns.problemKind == problemKind)
            }

            if let severity = severity {
                request = request.filter(ScoutFinding.Columns.severity == severity)
            }

            request = request.order(ScoutFinding.Columns.createdAt.desc)
                .limit(limit)

            return try request.fetchAll(db)
        }
    }

    /// Gets scout findings without associated tasks.
    public func getUnassignedScoutFindings(projectId: UUID, limit: Int = 100) async throws -> [ScoutFinding] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }
        let resolvedProjectId = projectId

        return try await dbPool.read { db in
            let request = ScoutFinding
                .filter(ScoutFinding.Columns.projectId == resolvedProjectId)
                .filter(ScoutFinding.Columns.taskId == nil)
                .order(ScoutFinding.Columns.createdAt.desc)
                .limit(limit)

            return try request.fetchAll(db)
        }
    }

    /// Associates a scout finding with a migration task.
    public func associateFindingWithTask(findingId: UUID, taskId: UUID) async throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try await dbPool.write { db in
            guard var finding = try ScoutFinding.fetchOne(db, key: findingId) else {
                throw HarnessError.scoutFindingNotFound(findingId)
            }

            finding.taskId = taskId
            try finding.update(db)
        }
    }
}

// MARK: - Migration Tasks Store Methods

extension ProjectHarnessStore {
    /// Saves migration tasks to the database.
    public func saveMigrationTasks(_ tasks: [MigrationTask]) async throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try await dbPool.write { db in
            for task in tasks {
                try task.save(db)
            }
        }
    }

    /// Gets migration tasks for a project.
    public func getMigrationTasks(
        projectId: UUID,
        featureCategory: String? = nil,
        status: MigrationTaskStatus? = nil,
        limit: Int = 100
    ) async throws -> [MigrationTask] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }
        let resolvedProjectId = projectId

        return try await dbPool.read { db in
            var request = MigrationTask.filter(MigrationTask.Columns.projectId == resolvedProjectId)

            if let featureCategory = featureCategory {
                request = request.filter(MigrationTask.Columns.featureCategory == featureCategory)
            }

            if let status = status {
                request = request.filter(MigrationTask.Columns.status == status)
            }

            request = request.order(MigrationTask.Columns.priority.desc, MigrationTask.Columns.createdAt.asc)
                .limit(limit)

            return try request.fetchAll(db)
        }
    }

    /// Gets pending migration tasks for a project.
    public func getPendingMigrationTasks(
        projectId: UUID,
        featureCategory: String? = nil,
        limit: Int = 100
    ) async throws -> [MigrationTask] {
        return try await getMigrationTasks(
            projectId: projectId,
            featureCategory: featureCategory,
            status: .pending,
            limit: limit
        )
    }

    /// Updates a migration task status.
    public func updateMigrationTaskStatus(
        _ taskId: UUID,
        status: MigrationTaskStatus,
        sessionIndex: Int? = nil
    ) async throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try await dbPool.write { db in
            guard var task = try MigrationTask.fetchOne(db, key: taskId) else {
                throw HarnessError.migrationTaskNotFound(taskId)
            }

            task.status = status

            switch status {
            case .active:
                task.startedAt = Date()
            case .completed, .failed:
                task.completedAt = Date()
                task.sessionIndex = sessionIndex
            case .pending, .cancelled:
                // No additional updates needed
                break
            }

            try task.update(db)
        }
    }

    /// Marks a migration task as completed.
    public func markMigrationTaskCompleted(_ taskId: UUID, sessionIndex: Int? = nil) async throws {
        try await updateMigrationTaskStatus(taskId, status: .completed, sessionIndex: sessionIndex)
    }

    /// Marks a migration task as failed.
    public func markMigrationTaskFailed(_ taskId: UUID, sessionIndex: Int? = nil) async throws {
        try await updateMigrationTaskStatus(taskId, status: .failed, sessionIndex: sessionIndex)
    }

    /// Gets a migration task by ID.
    public func getMigrationTask(_ taskId: UUID) async throws -> MigrationTask? {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try await dbPool.read { db in
            try MigrationTask.fetchOne(db, key: taskId)
        }
    }
}

// MARK: - Error Extensions

extension HarnessError {
    /// Scout finding not found error.
    public static func scoutFindingNotFound(_ id: UUID) -> HarnessError {
        HarnessError.invalidProjectState("Scout finding not found: \(id)")
    }

    /// Migration task not found error.
    public static func migrationTaskNotFound(_ id: UUID) -> HarnessError {
        HarnessError.invalidProjectState("Migration task not found: \(id)")
    }
}
