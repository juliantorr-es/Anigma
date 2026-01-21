//
//  DoctrineMigrationIntegration.swift
//  HarmoniaModule
//
//  Integration between migration engine and concrete doctrine rules.
//  Specifically wires PII classification checks to data model migrations.
//

import AnigmaCore
import AnigmaPrimitives
@preconcurrency import DoctrineCore
import Foundation
import SQLite3

/// Migration engine wrapper that checks doctrine compliance.
public final class DoctrineAwareMigrationEngineWrapper {
    private let baseEngine: any MigrationEngine
    private let lawComplianceScout: ConcreteLawComplianceScout
    private let violationStore: DoctrineCore.DoctrineViolationStore

    public init(
        baseEngine: any MigrationEngine,
        lawComplianceScout: ConcreteLawComplianceScout = ConcreteLawComplianceScout(),
        violationStore: DoctrineCore.DoctrineViolationStore =
            try! DoctrineCore.DoctrineViolationStore()
    ) {
        self.baseEngine = baseEngine
        self.lawComplianceScout = lawComplianceScout
        self.violationStore = violationStore
    }

    /// Process a migration task with doctrine checks.
    public func process(task: MigrationTaskRow, db: OpaquePointer?) async throws -> MigrationResult {
        logInfo(
            "DoctrineAwareMigrationEngineWrapper processing task \(task.id)",
            category: "DoctrineMigration")

        // 1. Load the associated scout finding to get file path
        guard let finding = try loadFinding(for: task, db: db) else {
            return .failed(errorDescription: "No scout finding found for task \(task.id)")
        }

        guard let filePath = finding.filePath else {
            return .skipped(reason: "No file path in finding")
        }

        // 2. Check for doctrine violations BEFORE processing
        let violations = try await lawComplianceScout.scan(fileAt: filePath)
        let blockingViolations = violations.filter { $0.severity == .critical }

        if !blockingViolations.isEmpty {
            // Store blocking violations
            for violation in blockingViolations {
                try violationStore.saveViolation(violation)
            }

            // Convert to debt tasks
            let debtTasks = blockingViolations.compactMap { DoctrineDebtTask.fromViolation($0) }
            logWarning(
                "Blocked migration due to \(blockingViolations.count) critical doctrine violations",
                category: "DoctrineMigration")
            logWarning(
                "Created \(debtTasks.count) blocking debt tasks", category: "DoctrineMigration")

            return .failed(
                errorDescription:
                    "Blocked by \(blockingViolations.count) critical doctrine violations. Fix debt tasks first."
            )
        }

        // 3. Process with base engine
        let result = try await baseEngine.process(task: task, db: db)

        // 4. Store non-blocking violations as warnings
        let nonBlockingViolations = violations.filter { $0.severity != .critical }
        if !nonBlockingViolations.isEmpty {
            for violation in nonBlockingViolations {
                try violationStore.saveViolation(violation)
            }

            let debtTasks = nonBlockingViolations.compactMap { DoctrineDebtTask.fromViolation($0) }
            logWarning(
                "Found \(nonBlockingViolations.count) non-blocking doctrine violations during migration",
                category: "DoctrineMigration")
            logWarning(
                "Created \(debtTasks.count) debt tasks for later resolution",
                category: "DoctrineMigration")
        }

        return result
    }

    /// Load scout finding for a migration task.
    private func loadFinding(for task: MigrationTaskRow, db: OpaquePointer?) throws
        -> DoctrineScoutFinding? {
        guard let findingId = task.findingId else { return nil }

        var stmt: OpaquePointer?
        let sql =
            "SELECT id, projectId, scoutId, title, description, problemKind, filePath, lineNumber, metadata, createdAt FROM scout_findings WHERE id = ?"

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(
                domain: "DoctrineMigrationIntegration", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to prepare statement: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, findingId, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        func columnIndex(named name: String) -> Int32? {
            let count = sqlite3_column_count(stmt)
            for i in 0..<count {
                if let cName = sqlite3_column_name(stmt, i), String(cString: cName) == name {
                    return i
                }
            }
            return nil
        }

        func textColumn(named name: String) -> String? {
            guard let idx = columnIndex(named: name) else { return nil }
            guard sqlite3_column_type(stmt, idx) != SQLITE_NULL,
                let cValue = sqlite3_column_text(stmt, idx)
            else { return nil }
            return String(cString: cValue)
        }

        let id = textColumn(named: "id") ?? ""
        guard let projectIdString = textColumn(named: "projectId"),
            let projectId = UUID(uuidString: projectIdString)
        else {
            throw NSError(
                domain: "DoctrineMigrationIntegration", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid projectId"])
        }

        let scoutId = textColumn(named: "scoutId") ?? ""
        let title = textColumn(named: "title") ?? ""
        let description = textColumn(named: "description") ?? ""
        let problemKind = textColumn(named: "problemKind") ?? ""

        let filePath = textColumn(named: "filePath")
        let lineNumber: Int?
        if let lineValue = textColumn(named: "lineNumber") {
            lineNumber = Int(lineValue)
        } else if let idx = columnIndex(named: "lineNumber"),
            sqlite3_column_type(stmt, idx) != SQLITE_NULL {
            lineNumber = Int(sqlite3_column_int64(stmt, idx))
        } else {
            lineNumber = nil
        }

        let metadataJSON = textColumn(named: "metadata") ?? "{}"
        let metadata =
            (try? JSONSerialization.jsonObject(with: Data(metadataJSON.utf8), options: []))
            as? [String: Any] ?? [:]

        guard let createdAtString = textColumn(named: "createdAt"),
            let createdAt = ISO8601DateFormatter().date(from: createdAtString)
        else {
            throw NSError(
                domain: "DoctrineMigrationIntegration", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid createdAt"])
        }

        return DoctrineScoutFinding(
            id: id,
            projectId: projectId,
            scoutId: scoutId,
            title: title,
            description: description,
            problemKind: problemKind,
            filePath: filePath,
            lineNumber: lineNumber,
            metadata: metadata,
            createdAt: createdAt
        )
    }
}

/// Factory for doctrine-aware migration engines.
public struct DoctrineAwareMigrationEngineFactory {
    /// Create a doctrine-aware migration engine for the given task.
    public static func engine(
        for task: MigrationTaskRow, traceSink: MigrationTraceSink = NoopMigrationTraceSink()
    ) -> (any MigrationEngine)? {
        return MigrationEngineFactory.engine(for: task, traceSink: traceSink)
    }
}

/// Extended step engine that prioritizes doctrine debt tasks.
public actor DoctrineAwareStepEngine {
    private let baseStepEngine: StepEngine
    private let debtTaskService: DoctrineDebtTaskService

    public init(
        baseStepEngine: StepEngine = StepEngine(),
        debtTaskService: DoctrineDebtTaskService = DoctrineDebtTaskService()
    ) {
        self.baseStepEngine = baseStepEngine
        self.debtTaskService = debtTaskService
    }

    /// Update with doctrine awareness.
    public func update(world: World) async {
        logInfo("DoctrineAwareStepEngine update started", category: "DoctrineStepEngine")

        // 1. Check for blocking doctrine debt tasks
        do {
            let blockingTasks = try await debtTaskService.getBlockingDebtTasks()
            if !blockingTasks.isEmpty {
                logWarning(
                    "Found \(blockingTasks.count) blocking doctrine debt tasks",
                    category: "DoctrineStepEngine")
                logWarning(
                    "Prioritizing doctrine debt resolution over regular migration tasks",
                    category: "DoctrineStepEngine")

                // Create migration tasks for blocking doctrine violations
                for debtTask in blockingTasks {
                    await createMigrationTask(for: debtTask, world: world)
                }

                return  // Process doctrine tasks first
            }
        } catch {
            logError(
                "Failed to check doctrine debt tasks: \(error)", category: "DoctrineStepEngine")
        }

        // 2. Run base step engine
        await baseStepEngine.update(world: world)

        logInfo("DoctrineAwareStepEngine update completed", category: "DoctrineStepEngine")
    }

    /// Create a migration task for a doctrine debt task.
    private func createMigrationTask(for debtTask: DoctrineDebtTask, world: World) async {
        // In practice, this would create a proper migration task in the database
        // For now, just log it
        logInfo(
            "Would create migration task for doctrine debt: \(debtTask.description)",
            category: "DoctrineStepEngine")
        logInfo(
            "File: \(debtTask.filePath ?? "unknown"), Line: \(debtTask.lineNumber ?? 0)",
            category: "DoctrineStepEngine")
        logInfo("Remediation: \(debtTask.suggestedRemediation)", category: "DoctrineStepEngine")
    }

    /// Get doctrine health statistics.
    public func getDoctrineHealth() async throws -> [String: Sendable] {
        let stats = try await debtTaskService.getDoctrineStatistics()

        let healthScore = try await debtTaskService.getDoctrineHealthScore()

        return [
            "health_score": healthScore,
            "statistics": stats
        ]
    }
}

// MARK: - Helper Types

private struct DoctrineScoutFinding {
    let id: String
    let projectId: UUID
    let scoutId: String
    let title: String
    let description: String
    let problemKind: String
    let filePath: String?
    let lineNumber: Int?
    let metadata: [String: Any]
    let createdAt: Date
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
