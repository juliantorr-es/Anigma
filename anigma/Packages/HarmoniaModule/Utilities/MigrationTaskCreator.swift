//
//  MigrationTaskCreator.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import DatabaseCore
//
//  MigrationTaskCreator.swift
//  HarmoniaModule/Utilities
//
//  Creates migration tasks from scout findings.
//

import Foundation
import SQLite3
import AnigmaCore

/// Creates a migration task in the database from a scout finding.
/// Returns the ID of the created task, or nil if failed.
public func createMigrationTask(
    from finding: ScoutFinding,
    db: OpaquePointer?,
    featureCategory: String? = nil,
    researchBundleId: String? = nil
) -> String? {
    guard let db = db else {
        logError("Database connection is nil", category: "MigrationTaskCreator")
        return nil
    }

    let taskId = UUID().uuidString
    let defaultCategory = featureCategory ?? mapProblemKindToCategory(finding.problemKind)
    let priority = mapSeverityToPriority(finding.severity)

    var stmt: OpaquePointer?
    let sql = """
        INSERT INTO migration_tasks (
            id, projectId, featureCategory, status, priority,
            findingId, research_bundle_id, createdAt, updatedAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
    """
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        let errMsg = String(cString: sqlite3_errmsg(db))
        logError("Failed to prepare insert statement: \(errMsg)", category: "MigrationTaskCreator")
        return nil
    }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, taskId, -1, sqliteTransientDestructor)

    let projectIdData = finding.projectId.asBlobData
    _ = projectIdData.withUnsafeBytes { bytes in
        sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(projectIdData.count), sqliteTransientDestructor)
    }

    sqlite3_bind_text(stmt, 3, defaultCategory, -1, sqliteTransientDestructor)
    sqlite3_bind_text(stmt, 4, "pending", -1, sqliteTransientDestructor)
    sqlite3_bind_int64(stmt, 5, Int64(priority))
    sqlite3_bind_text(stmt, 6, finding.id.uuidString, -1, sqliteTransientDestructor)

    if let researchBundleId = researchBundleId {
        sqlite3_bind_text(stmt, 7, researchBundleId, -1, sqliteTransientDestructor)
    } else {
        sqlite3_bind_null(stmt, 7)
    }

    if sqlite3_step(stmt) == SQLITE_DONE {
        logInfo("Created migration task \(taskId) for finding \(finding.id)", category: "MigrationTaskCreator")
        // Update the scout_finding's taskId column (if exists)
        updateFindingTaskId(db: db, findingId: finding.id.uuidString, taskId: taskId)
        return taskId
    } else {
        let errMsg = String(cString: sqlite3_errmsg(db))
        logError("Failed to insert migration task: \(errMsg)", category: "MigrationTaskCreator")
        return nil
    }
}

/// Updates the scout_findings table with the task ID.
private func updateFindingTaskId(db: OpaquePointer?, findingId: String, taskId: String) {
    var stmt: OpaquePointer?
    let sql = "UPDATE scout_findings SET taskId = ? WHERE id = ?"
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
        sqlite3_bind_text(stmt, 1, taskId, -1, nil)
        sqlite3_bind_text(stmt, 2, findingId, -1, nil)
        if sqlite3_step(stmt) == SQLITE_DONE {
            logDebug("Updated finding \(findingId) with taskId \(taskId)", category: "MigrationTaskCreator")
        } else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            logWarning("Failed to update finding taskId: \(errMsg)", category: "MigrationTaskCreator")
        }
        sqlite3_finalize(stmt)
    }
}

/// Maps a scout problem kind to a migration feature category.
private func mapProblemKindToCategory(_ problemKind: String) -> String {
    // Default mapping; can be extended
    switch problemKind {
    case "SendableConformance":
        return "swift6-migration"
    case "SessionViolation", "LowAnalysisRatio":
        return "governance"
    case "MigrationTask":
        return "swift6-migration"
    default:
        return "general"
    }
}

/// Maps scout severity to migration task priority.
private func mapSeverityToPriority(_ severity: ScoutFindingSeverity) -> Int {
    switch severity {
    case .critical: return 3
    case .error: return 2
    case .warning: return 1
    case .info: return 0
    }
}

/// Creates migration tasks for findings that don't have an associated task yet.
public func createTasksForFindings(
    _ findings: [ScoutFinding],
    db: OpaquePointer?,
    featureCategory: String? = nil
) -> [String] {
    guard let db = db else { return [] }

    var createdIds: [String] = []
    for finding in findings {
        // Check if a task already exists for this finding
        if let existing = findTaskForFinding(db: db, findingId: finding.id.uuidString) {
            logDebug("Finding \(finding.id) already has task \(existing)", category: "MigrationTaskCreator")
            continue
        }
        if let taskId = createMigrationTask(from: finding, db: db, featureCategory: featureCategory) {
            createdIds.append(taskId)
        }
    }
    logInfo("Created \(createdIds.count) migration tasks from \(findings.count) findings", category: "MigrationTaskCreator")
    return createdIds
}

/// Finds the task ID associated with a finding (if any).
private func findTaskForFinding(db: OpaquePointer?, findingId: String) -> String? {
    var stmt: OpaquePointer?
    let sql = "SELECT taskId FROM scout_findings WHERE id = ?"
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, findingId, -1, nil)
    if sqlite3_step(stmt) == SQLITE_ROW {
        if sqlite3_column_type(stmt, 0) != SQLITE_NULL {
            return String(cString: sqlite3_column_text(stmt, 0))
        }
    }
    return nil
}
