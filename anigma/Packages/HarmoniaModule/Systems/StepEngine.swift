//
//  StepEngine.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import AnigmaCore
import AnigmaPrimitives
import DatabaseCore
@preconcurrency import Foundation
import SQLite3

//
//  StepEngine.swift
//  HarmoniaModule/Systems
//
//  Step engine for processing migration tasks.
//  Loads pending migration tasks from the database and executes steps.
//

public struct StepEngine: System {
  public var name: String { "StepEngine" }

  private let dbPath: String
  private let traceSink: MigrationTraceSink

  public init(dbPath: String = DatabaseConfiguration.defaultDatabasePath()) {
    self.dbPath = dbPath
    self.traceSink = SQLiteMigrationTraceSink(dbPath: dbPath)
    logInfo(
      "StepEngine initialized with SQLite trace sink at path: \(dbPath)", category: "StepEngine")
  }

  public func update(world: World) async {
    logInfo("StepEngine update started", category: "StepEngine")

    // Open database connection
    var db: OpaquePointer?
    guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
      let errMsg = String(cString: sqlite3_errmsg(db))
      logError("Failed to open database at \(dbPath): \(errMsg)", category: "StepEngine")
      return
    }
    defer { sqlite3_close(db) }

    // Load project specs to get project IDs
    let projectIds = await loadProjectIds(db: db)
    logInfo("Found \(projectIds.count) project(s)", category: "StepEngine")

    for projectId in projectIds {
      await processProject(projectId: projectId, db: db)
    }

    logInfo("StepEngine update completed", category: "StepEngine")
  }

  private func loadProjectIds(db: OpaquePointer?) async -> [UUID] {
    var ids: [UUID] = []
    var stmt: OpaquePointer?
    let sql = "SELECT hex(id) FROM project_specs"
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    logInfo(
      "sqlite3_prepare_v2 for project_specs returned: \(rc), stmt: \(stmt != nil ? "valid" : "nil")",
      category: "StepEngine")

    if rc == SQLITE_OK && stmt != nil {
      while sqlite3_step(stmt) == SQLITE_ROW {
        let hex = String(cString: sqlite3_column_text(stmt, 0))
        if let uuid = UUID(hexString: hex) {
          ids.append(uuid)
        } else {
          logWarning("Invalid project ID hex: \(hex)", category: "StepEngine")
        }
      }
      sqlite3_finalize(stmt)
    } else {
      let errMsg = String(cString: sqlite3_errmsg(db))
      logError(
        "Failed to prepare project_specs query: rc=\(rc), error=\(errMsg)", category: "StepEngine")
      if stmt != nil {
        sqlite3_finalize(stmt)
      }
    }
    return ids
  }

  private func processProject(projectId: UUID, db: OpaquePointer?) async {
    logInfo("Processing project \(projectId)", category: "StepEngine")

    // Load pending migration tasks for this project
    let tasks: [AnigmaCore.MigrationTaskRow]
    do {
      tasks = try loadMigrationTasks(
        db: db,
        projectId: projectId,
        featureCategory: nil,  // Process all categories
        status: "pending",
        limit: 10
      )
      logInfo(
        "Loaded \(tasks.count) migration tasks for project \(projectId)", category: "StepEngine")
    } catch {
      logError("Failed to load migration tasks: \(error)", category: "StepEngine")
      return
    }

    logInfo("Found \(tasks.count) pending migration tasks", category: "StepEngine")

    // Process tasks in priority order
    let sortedTasks = tasks.sorted { $0.priority > $1.priority }
    for task in sortedTasks {
      await processTask(task, db: db)
    }
  }

  private func processTask(_ task: AnigmaCore.MigrationTaskRow, db: OpaquePointer?) async {
    logInfo(
      "Processing migration task \(task.id) [\(task.featureCategory)] priority \(task.priority)",
      category: "StepEngine")

    // Get security-wrapped migration engine for this task
    let securityFactory = SecurityAwareMigrationEngineFactory(traceSink: traceSink)
    guard let engine = securityFactory.engine(for: task) else {
      logError(
        "No security-wrapped migration engine found for feature category: \(task.featureCategory)",
        category: "StepEngine")
      updateTaskStatus(
        db: db, taskId: task.id, newStatus: "failed", path: nil, detail: nil,
        errorMessage: "No migration engine found for category: \(task.featureCategory)")
      return
    }

    // Check if this is a blocked engine (capability violation)
    if let blockedEngine = engine as? BlockedMigrationEngine {
      await handleBlockedEngine(blockedEngine, task: task, db: db)
      return
    }

    do {
      // Process the task with the migration engine
      let result = try await engine.process(task: task, db: db)

      // Update task status based on result
      switch result {
      case .success:
        updateTaskStatus(
          db: db, taskId: task.id, newStatus: "completed", path: result.path, detail: result.detail)
        logInfo("Task \(task.id) completed successfully", category: "StepEngine")

      case .skipped(let skippedPath, let reason, let skippedDetail):
        updateTaskStatus(
          db: db, taskId: task.id, newStatus: "skipped", path: skippedPath, detail: skippedDetail,
          errorMessage: reason)
        logInfo("Task \(task.id) skipped: \(reason)", category: "StepEngine")

      case .failed(let errorDescription, let failedPath, let failedDetail):
        updateTaskStatus(
          db: db, taskId: task.id, newStatus: "failed", path: failedPath, detail: failedDetail,
          errorMessage: errorDescription)
        logError("Task \(task.id) failed: \(errorDescription)", category: "StepEngine")
      }

    } catch {
      let errorDescription = "Engine error: \(error.localizedDescription)"
      updateTaskStatus(
        db: db, taskId: task.id, newStatus: "failed", path: nil, detail: nil,
        errorMessage: errorDescription)
      logError("Task \(task.id) failed with error: \(error)", category: "StepEngine")
    }
  }

  /// Handle a blocked migration engine (capability violation).
  private func handleBlockedEngine(
    _ blockedEngine: BlockedMigrationEngine, task: AnigmaCore.MigrationTaskRow, db: OpaquePointer?
  ) async {
    logWarning(
      "Task \(task.id) blocked by security policy: \(blockedEngine.reason)", category: "StepEngine")

    do {
      // Process with blocked engine (creates debt task)
      let result = try await blockedEngine.process(task: task, db: db)

      // Update task status to "blocked" instead of "failed"
      switch result {
      case .failed(let errorDescription, let failedPath, let failedDetail):
        // Blocked engines always return .failed, but we treat it as "blocked" status
        updateTaskStatus(
          db: db, taskId: task.id, newStatus: "blocked", path: failedPath, detail: failedDetail,
          errorMessage: errorDescription)
        logWarning("Task \(task.id) blocked: \(errorDescription)", category: "StepEngine")

      default:
        // Should never happen, but handle gracefully
        updateTaskStatus(
          db: db, taskId: task.id, newStatus: "blocked", path: nil, detail: nil,
          errorMessage: blockedEngine.reason)
        logWarning("Task \(task.id) blocked: \(blockedEngine.reason)", category: "StepEngine")
      }

    } catch {
      let errorDescription = "Blocked engine error: \(error.localizedDescription)"
      updateTaskStatus(
        db: db, taskId: task.id, newStatus: "blocked", path: nil, detail: nil,
        errorMessage: errorDescription)
      logError("Task \(task.id) blocked with error: \(error)", category: "StepEngine")
    }
  }

  private func updateTaskStatus(
    db: OpaquePointer?, taskId: String, newStatus: String, path: String?, detail: String?,
    errorMessage: String? = nil
  ) {
    guard let db = db else { return }
    var stmt: OpaquePointer?
    let sql: String
    if errorMessage != nil {
      sql =
        "UPDATE migration_tasks SET status = ?, errorMessage = ?, path = ?, pathDetail = ? WHERE id = ?"
    } else {
      sql = "UPDATE migration_tasks SET status = ?, path = ?, pathDetail = ? WHERE id = ?"
    }

    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      let errMsg = String(cString: sqlite3_errmsg(db))
      logError("Failed to prepare update statement: \(errMsg)", category: "StepEngine")
      return
    }

    var bindIndex: Int32 = 1
    sqlite3_bind_text(stmt, bindIndex, newStatus, -1, nil)
    bindIndex += 1

    if let errorMessage = errorMessage {
      sqlite3_bind_text(stmt, bindIndex, errorMessage, -1, nil)
      bindIndex += 1
    }

    bindTextOrNull(path, at: bindIndex, stmt: stmt)
    bindIndex += 1
    bindTextOrNull(detail, at: bindIndex, stmt: stmt)
    bindIndex += 1
    sqlite3_bind_text(stmt, bindIndex, taskId, -1, sqliteTransientDestructor)

    if sqlite3_step(stmt) == SQLITE_DONE {
      logDebug("Updated task \(taskId) status to \(newStatus)", category: "StepEngine")
    } else {
      let errMsg = String(cString: sqlite3_errmsg(db))
      logError("Failed to update task \(taskId): \(errMsg)", category: "StepEngine")
    }
    sqlite3_finalize(stmt)
  }

  private func bindTextOrNull(_ text: String?, at index: Int32, stmt: OpaquePointer?) {
    guard let stmt = stmt else { return }
    if let text = text {
      sqlite3_bind_text(stmt, index, text, -1, nil)
    } else {
      sqlite3_bind_null(stmt, index)
    }
  }
}
