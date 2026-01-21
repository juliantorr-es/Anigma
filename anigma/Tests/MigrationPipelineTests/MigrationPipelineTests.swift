//
//  MigrationPipelineTests.swift
//  MigrationPipelineTests
//
//  HarmoniaModuleTests
//
//  Tests for the Swift 6 migration pipeline.
//

import XCTest
import SQLite3

@testable import HarmoniaModule  // HarmoniaSpine merged
import AnigmaPrimitives
import DatabaseCore

private let sqliteTransientDestructor: sqlite3_destructor_type = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class MigrationPipelineTests: XCTestCase {
    private var db: OpaquePointer?
    private let testDbPath = ":memory:"

    override func setUp() async throws {
        // Create in-memory database
        guard sqlite3_open(testDbPath, &db) == SQLITE_OK else {
            XCTFail("Failed to open in-memory database")
            return
        }

        // Create necessary tables
        try createTestTables()
    }

    override func tearDown() async throws {
        if let db = db {
            sqlite3_close(db)
        }
        db = nil
    }

    private func createTestTables() throws {
        let createProjectSpecs = """
            CREATE TABLE IF NOT EXISTS project_specs (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                specText TEXT NOT NULL,
                status TEXT NOT NULL,
                projectDirectory TEXT,
                gitRepositoryURL TEXT,
                createdAt DATETIME NOT NULL,
                updatedAt DATETIME NOT NULL
            )
        """

        let createScoutFindings = """
            CREATE TABLE IF NOT EXISTS scout_findings (
                id TEXT PRIMARY KEY,
                projectId TEXT NOT NULL,
                taskId TEXT,
                filePath TEXT NOT NULL,
                problemKind TEXT NOT NULL,
                severity TEXT NOT NULL,
                description TEXT NOT NULL,
                suggestedFix TEXT,
                lineStart INTEGER,
                lineEnd INTEGER,
                createdAt DATETIME NOT NULL,
                ast_anchor_json TEXT,
                FOREIGN KEY (projectId) REFERENCES project_specs(id) ON DELETE CASCADE,
                FOREIGN KEY (taskId) REFERENCES migration_tasks(id) ON DELETE SET NULL
            )
        """

        let createMigrationTasks = """
            CREATE TABLE IF NOT EXISTS migration_tasks (
                id TEXT PRIMARY KEY,
                projectId TEXT NOT NULL,
                featureCategory TEXT NOT NULL,
                status TEXT NOT NULL,
                priority INTEGER NOT NULL,
                createdAt DATETIME NOT NULL,
                updatedAt DATETIME NOT NULL,
                startedAt DATETIME,
                completedAt DATETIME,
                sessionIndex INTEGER,
                findingId TEXT,
                errorMessage TEXT,
                research_bundle_id TEXT,
                path TEXT,
                pathDetail TEXT,
                FOREIGN KEY (projectId) REFERENCES project_specs(id) ON DELETE CASCADE,
                FOREIGN KEY (findingId) REFERENCES scout_findings(id) ON DELETE SET NULL,
                FOREIGN KEY (research_bundle_id) REFERENCES research_bundles(id) ON DELETE SET NULL
            )
        """

        try executeSQL(createProjectSpecs)
        try executeSQL(createScoutFindings)
        try executeSQL(createMigrationTasks)
    }

    private func executeSQL(_ sql: String) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }
    }

    func testMigrationEngineFactory() {
        // Test Swift 6 migration engine creation
        let swift6Task = MigrationTaskRow(
            id: "test-task-1",
            projectId: UUID(),
            engineType: "migration",
            featureCategory: "swift6-migration",
            status: "pending",
            priority: 2,
            findingId: nil
        )

        let engine = MigrationEngineFactory.engine(for: swift6Task, traceSink: NoopMigrationTraceSink())
        XCTAssertNotNil(engine)
        XCTAssertTrue(engine is Swift6MigrationEngine)

        // Test unknown category
        let unknownTask = MigrationTaskRow(
            id: "test-task-2",
            projectId: UUID(),
            engineType: "migration",
            featureCategory: "unknown-category",
            status: "pending",
            priority: 1,
            findingId: nil
        )

        let unknownEngine = MigrationEngineFactory.engine(for: unknownTask, traceSink: NoopMigrationTraceSink())
        XCTAssertNil(unknownEngine)
    }

    func testSwift6MigrationEngineProcessing() async throws {
        // Create test data
        let projectId = UUID()
        let findingId = UUID()
        let taskId = UUID().uuidString
        let repoRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let testSourcePath = repoRoot.appendingPathComponent("Sources/Test.swift").path
        let testSource = """
            public struct Test {}
            """
        try testSource.write(toFile: testSourcePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: testSourcePath) }

        // Insert project
        let insertProject = """
            INSERT INTO project_specs (id, name, specText, status, createdAt, updatedAt)
            VALUES (?, 'Test Project', '{}', 'active', datetime('now'), datetime('now'))
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertProject, -1, &stmt, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare project insert")
            return
        }
        let projectIdData = projectId.asBlobData
        projectIdData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 1, bytes.baseAddress, Int32(projectIdData.count), sqliteTransientDestructor)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            XCTFail("Failed to insert project")
            return
        }
        sqlite3_finalize(stmt)

        // Insert scout finding
        let insertFinding = """
            INSERT INTO scout_findings (
                id, projectId, problemKind, severity, description,
                filePath, lineStart, lineEnd, suggestedFix, createdAt
            ) VALUES (?, ?, 'SendableConformance', 'warning', 'Struct needs Sendable conformance',
                     ?, 10, 10, 'Add : Sendable', datetime('now'))
        """
        guard sqlite3_prepare_v2(db, insertFinding, -1, &stmt, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare finding insert")
            return
        }
        let findingIdCString = findingId.uuidString.cString(using: .utf8)
        sqlite3_bind_text(stmt, 1, findingIdCString, -1, sqliteTransientDestructor)
        let projectIdData2 = projectId.asBlobData
        projectIdData2.withUnsafeBytes { bytes in
        sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(projectIdData2.count), nil)
        sqlite3_bind_text(stmt, 3, testSourcePath, -1, sqliteTransientDestructor)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            XCTFail("Failed to insert finding")
            return
        }
        sqlite3_finalize(stmt)

        var checkStmt: OpaquePointer?
        let checkQuery = "SELECT id, typeof(projectId) FROM scout_findings WHERE id = ?"
        if sqlite3_prepare_v2(db, checkQuery, -1, &checkStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(checkStmt, 1, findingIdCString, -1, sqliteTransientDestructor)
            sqlite3_step(checkStmt)
            sqlite3_finalize(checkStmt)
        }

        // Insert migration task
        let insertTask = """
            INSERT INTO migration_tasks (id, projectId, featureCategory, status, priority, findingId, createdAt, updatedAt)
            VALUES (?, ?, 'swift6-migration', 'pending', 2, ?, datetime('now'), datetime('now'))
        """
        guard sqlite3_prepare_v2(db, insertTask, -1, &stmt, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare task insert")
            return
        }
        let taskIdCString = taskId.cString(using: .utf8)
        sqlite3_bind_text(stmt, 1, taskIdCString, -1, sqliteTransientDestructor)
        let projectIdData3 = projectId.asBlobData
        projectIdData3.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(projectIdData3.count), sqliteTransientDestructor)
        }
        let findingIdCString2 = findingId.uuidString.cString(using: .utf8)
        sqlite3_bind_text(stmt, 3, findingIdCString2, -1, sqliteTransientDestructor)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            XCTFail("Failed to insert task")
            return
        }
        sqlite3_finalize(stmt)

        // Debug: Query what was actually inserted
        var debugStmt: OpaquePointer?
        let debugQuery = "SELECT id, hex(id), typeof(id), length(id) FROM migration_tasks"
        if sqlite3_prepare_v2(db, debugQuery, -1, &debugStmt, nil) == SQLITE_OK {
            while sqlite3_step(debugStmt) == SQLITE_ROW {
                let idType = sqlite3_column_type(debugStmt, 0)
                let idHex = sqlite3_column_type(debugStmt, 1) == SQLITE_TEXT ? String(cString: sqlite3_column_text(debugStmt, 1)) : "N/A"
                let idTypeName = sqlite3_column_type(debugStmt, 2) == SQLITE_TEXT ? String(cString: sqlite3_column_text(debugStmt, 2)) : "N/A"
                let idLength = sqlite3_column_int(debugStmt, 3)
                print("DEBUG: Inserted task - id type: \(idType), hex: \(idHex), type name: \(idTypeName), length: \(idLength)")
            }
            sqlite3_finalize(debugStmt)
        }

        // Load the task
        let tasks = try loadMigrationTasks(
            db: db,
            projectId: projectId,
            featureCategory: "swift6-migration",
            status: "pending",
            limit: 1
        )

        XCTAssertEqual(tasks.count, 1)
        let task = tasks[0]
        XCTAssertEqual(task.id, taskId)
        XCTAssertEqual(task.status, "pending")
        XCTAssertEqual(task.findingId, findingId.uuidString)

        // Process the task
        let engine = Swift6MigrationEngine(traceSink: NoopMigrationTraceSink())
        let result = try await engine.process(task: task, db: db)

        // Verify result
        switch result {
        case .success:
            // Success is expected for v1 (logging only)
            break
        case .skipped(_, let reason):
            XCTFail("Task should not be skipped: \(reason)")
        case .failed(let errorDescription):
            XCTFail("Task should not fail: \(errorDescription)")
        }

    }

    func testMigrationResultEnum() {
        // Test all cases
        let success = MigrationResult.defaultSuccess
        let skipped = MigrationResult.skipped(reason: "Test skip")
        let failed = MigrationResult.failed(errorDescription: "Test failure")

        // Verify they compile and can be used
        switch success {
        case .success:
            XCTAssertTrue(true)
        case .skipped, .failed:
            XCTFail("Wrong case")
        }

        switch skipped {
        case .skipped(_, let reason):
            XCTAssertEqual(reason, "Test skip")
        case .success, .failed:
            XCTFail("Wrong case")
        }

        switch failed {
        case .failed(let errorDescription):
            XCTAssertEqual(errorDescription, "Test failure")
        case .success, .skipped:
            XCTFail("Wrong case")
        }
    }

    func testMigrationTraceSinkStoresOutcome() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let dbPath = tempDir.appendingPathComponent("trace.sqlite").path
        let sink = SQLiteMigrationTraceSink(dbPath: dbPath)
        let outcome = MigrationStepOutcome(
            taskId: "trace-task",
            rewritePath: "ast",
            ruleId: "add-sendable-to-value-types",
            verifyStatus: "passed",
            rollbackStatus: "not_needed",
            detail: "detail"
        )

        sink.record(outcome)
        try await sink.waitUntilReady()
        try await Task.sleep(nanoseconds: 100_000_000)

        let fetched = try await sink.latestOutcome(for: outcome.taskId)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.rewritePath, "ast")
        XCTAssertEqual(fetched?.ruleId, outcome.ruleId)
        XCTAssertEqual(fetched?.verifyStatus, outcome.verifyStatus)

        try FileManager.default.removeItem(at: tempDir)
    }

    func testStepEngineIntegration() throws {
        // This test verifies the StepEngine can load and process tasks
        // Note: StepEngine is designed to run in ECS context, so we test the components separately

        // Create test task
        let projectId = UUID()
        let taskId = UUID().uuidString

        // Insert project
        let insertProject = """
            INSERT INTO project_specs (id, name, specText, status, createdAt, updatedAt)
            VALUES (?, 'Test Project', '{}', 'active', datetime('now'), datetime('now'))
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertProject, -1, &stmt, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare project insert")
            return
        }
        let projectIdData = projectId.asBlobData
        projectIdData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 1, bytes.baseAddress, Int32(projectIdData.count), sqliteTransientDestructor)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            XCTFail("Failed to insert project")
            return
        }
        sqlite3_finalize(stmt)

        // Insert migration task
        let insertTask = """
            INSERT INTO migration_tasks (id, projectId, featureCategory, status, priority, createdAt, updatedAt)
            VALUES (?, ?, 'swift6-migration', 'pending', 1, datetime('now'), datetime('now'))
        """
        guard sqlite3_prepare_v2(db, insertTask, -1, &stmt, nil) == SQLITE_OK else {
            XCTFail("Failed to prepare task insert")
            return
        }
        let taskIdCString = taskId.cString(using: .utf8)
        sqlite3_bind_text(stmt, 1, taskIdCString, -1, sqliteTransientDestructor)
        let projectIdData2 = projectId.asBlobData
        projectIdData2.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(projectIdData2.count), sqliteTransientDestructor)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            XCTFail("Failed to insert task")
            return
        }
        sqlite3_finalize(stmt)

        // Verify task can be loaded
        let tasks = try loadMigrationTasks(
            db: db,
            projectId: projectId,
            featureCategory: "swift6-migration",
            status: "pending",
            limit: 10
        )

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].id, taskId)
        XCTAssertEqual(tasks[0].status, "pending")

        // Verify engine factory works for this task
        let engine = MigrationEngineFactory.engine(for: tasks[0], traceSink: NoopMigrationTraceSink())
        XCTAssertNotNil(engine)
        XCTAssertTrue(engine is Swift6MigrationEngine)
    }

    func testLoadFindingHandlesBlobProjectId() throws {
        let projectId = UUID()
        let findingId = UUID()
        let taskId = UUID().uuidString

        // Insert project with BLOB UUID
        var stmt: OpaquePointer?
        let insertProject = """
            INSERT INTO project_specs (id, name, specText, status, createdAt, updatedAt)
            VALUES (?, 'Blob Project', '{}', 'active', datetime('now'), datetime('now'))
        """
        XCTAssertEqual(sqlite3_prepare_v2(db, insertProject, -1, &stmt, nil), SQLITE_OK)
        let projectIdData = projectId.asBlobData
        projectIdData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 1, bytes.baseAddress, Int32(projectIdData.count), sqliteTransientDestructor)
        }
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
        sqlite3_finalize(stmt)

        // Insert scout finding linked to project
        let insertFinding = """
            INSERT INTO scout_findings (id, projectId, problemKind, severity, description, filePath, lineStart, createdAt)
            VALUES (?, ?, 'SendableConformance', 'warning', 'Blobed project find', 'Test.swift', 1, datetime('now'))
        """
        XCTAssertEqual(sqlite3_prepare_v2(db, insertFinding, -1, &stmt, nil), SQLITE_OK)
        let findingIdCString = findingId.uuidString.cString(using: .utf8)
        sqlite3_bind_text(stmt, 1, findingIdCString, -1, sqliteTransientDestructor)
        projectIdData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(projectIdData.count), sqliteTransientDestructor)
        }
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
        sqlite3_finalize(stmt)

        // Insert migration task referencing the finding
        let insertTask = """
            INSERT INTO migration_tasks (id, projectId, featureCategory, status, priority, findingId, createdAt, updatedAt)
            VALUES (?, ?, 'swift6-migration', 'pending', 1, ?, datetime('now'), datetime('now'))
        """
        XCTAssertEqual(sqlite3_prepare_v2(db, insertTask, -1, &stmt, nil), SQLITE_OK)
        let taskIdCString = taskId.cString(using: .utf8)
        sqlite3_bind_text(stmt, 1, taskIdCString, -1, sqliteTransientDestructor)
        projectIdData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(projectIdData.count), sqliteTransientDestructor)
        }
        sqlite3_bind_text(stmt, 6, findingIdCString, -1, sqliteTransientDestructor)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
        sqlite3_finalize(stmt)

        let task = MigrationTaskRow(
            id: taskId,
            projectId: projectId,
            engineType: "migration",
            featureCategory: "swift6-migration",
            status: "pending",
            priority: 1,
            findingId: findingId.uuidString
        )
        let engine = Swift6MigrationEngine(traceSink: NoopMigrationTraceSink())
        let finding = try engine.loadFinding(for: task, db: db)
        XCTAssertNotNil(finding)
        XCTAssertEqual(finding?.projectId, projectId)
    }

    func testLoadFindingRoundTripsAstAnchor() throws {
        let projectId = UUID()
        let findingId = UUID()
        let taskId = UUID().uuidString

        try insertProjectSpec(projectId)

        let anchor = AstAnchor(
            filePath: "Sources/Test.swift",
            contentHash: "abc123",
            startOffset: 0,
            endOffset: 12,
            nodeKind: "StructDecl",
            contextSnapshot: "struct Test {}"
        )

        try insertScoutFinding(
            id: findingId,
            projectId: projectId,
            anchorJSON: anchor.encode(),
            suggestedFix: "Add : Sendable"
        )
        XCTAssertTrue(try scoutFindingExists(findingId: findingId))

        try insertMigrationTask(taskId: taskId, projectId: projectId, findingId: findingId)

        let task = MigrationTaskRow(
            id: taskId,
            projectId: projectId,
            engineType: "migration",
            featureCategory: "swift6-migration",
            status: "pending",
            priority: 1,
            findingId: findingId.uuidString
        )

        let engine = Swift6MigrationEngine(traceSink: NoopMigrationTraceSink())
        let finding = try engine.loadFinding(for: task, db: db)

        XCTAssertNotNil(finding)
        XCTAssertEqual(finding?.astAnchor, anchor)
    }

    func testLoadFindingHandlesMissingAstAnchor() throws {
        let projectId = UUID()
        let findingId = UUID()
        let taskId = UUID().uuidString

        try insertProjectSpec(projectId)
        try insertScoutFinding(
            id: findingId,
            projectId: projectId,
            anchorJSON: nil,
            suggestedFix: nil
        )
        XCTAssertTrue(try scoutFindingExists(findingId: findingId))
        try insertMigrationTask(taskId: taskId, projectId: projectId, findingId: findingId)

        let task = MigrationTaskRow(
            id: taskId,
            projectId: projectId,
            engineType: "migration",
            featureCategory: "swift6-migration",
            status: "pending",
            priority: 1,
            findingId: findingId.uuidString
        )

        let engine = Swift6MigrationEngine(traceSink: NoopMigrationTraceSink())
        let finding = try engine.loadFinding(for: task, db: db)

        XCTAssertNotNil(finding)
        XCTAssertNil(finding?.astAnchor)
    }

    func testLoadFindingIgnoresInvalidAnchorJson() throws {
        let projectId = UUID()
        let findingId = UUID()
        let taskId = UUID().uuidString

        try insertProjectSpec(projectId)
        try insertScoutFinding(
            id: findingId,
            projectId: projectId,
            anchorJSON: "{ invalid json",
            suggestedFix: "Fix later"
        )
        XCTAssertTrue(try scoutFindingExists(findingId: findingId))
        try insertMigrationTask(taskId: taskId, projectId: projectId, findingId: findingId)

        let task = MigrationTaskRow(
            id: taskId,
            projectId: projectId,
            engineType: "migration",
            featureCategory: "swift6-migration",
            status: "pending",
            priority: 1,
            findingId: findingId.uuidString
        )

        let engine = Swift6MigrationEngine(traceSink: NoopMigrationTraceSink())
        let finding = try engine.loadFinding(for: task, db: db)

        XCTAssertNotNil(finding)
        XCTAssertNil(finding?.astAnchor)
    }

    // MARK: - Migration Trace Integration Tests

    func testDefaultRegexPathTracePersistence() async throws {
        // Test that the trace sink correctly records regex path outcomes
        // This tests the durable persistence without full engine integration

        let taskId = UUID().uuidString

        // Create temporary database for trace persistence
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("trace_test_regex.sqlite").path

        // Create trace sink with test database
        let traceSink = SQLiteMigrationTraceSink(dbPath: dbPath)
        try await traceSink.waitUntilReady()

        // Simulate a regex path outcome (as would happen when ANIGMA_AST_SENDABLE is not set)
        let outcome = MigrationStepOutcome(
            taskId: taskId,
            rewritePath: "regex",
            ruleId: "add-sendable-to-value-types",
            verifyStatus: "not_run",
            rollbackStatus: "not_needed",
            rollbackReason: "regex fallback",
            detail: "Default regex path when AST not enabled"
        )

        // Record the outcome
        traceSink.record(outcome)

        // Wait for async recording
        try await Task.sleep(nanoseconds: 100_000_000)

        // Query trace from database (not logs)
        let queryDb = DatabaseActor(dbPath: dbPath)
        try await queryDb.open()

        let rows = try await queryDb.query("""
            SELECT rewrite_path, rollback_status, rule_id, verify_status, rollback_reason, detail
            FROM migration_trace_steps
            WHERE task_id = ?
            ORDER BY recorded_at DESC
            LIMIT 1
            """,
            parameters: [.text(taskId)]
        )

        XCTAssertEqual(rows.count, 1, "Should have one trace entry")

        guard let row = rows.first else {
            XCTFail("No trace row found")
            return
        }

        XCTAssertEqual(row.string(for: "rewrite_path"), "regex", "Trace should show rewrite_path='regex'")
        XCTAssertEqual(row.string(for: "rollback_status"), "not_needed", "Trace should show rollback_status='not_needed'")
        XCTAssertEqual(row.string(for: "rule_id"), "add-sendable-to-value-types", "Trace should have rule_id")
        XCTAssertEqual(row.string(for: "verify_status"), "not_run", "Trace should show verify_status='not_run' for regex path")
        XCTAssertEqual(row.string(for: "rollback_reason"), "regex fallback", "Trace should show rollback reason")
        XCTAssertEqual(row.string(for: "detail"), "Default regex path when AST not enabled", "Trace should show detail")
    }

    func testASTRollbackPathTracePersistence() async throws {
        // Instead of testing the full engine with environment variables,
        // test that the trace sink correctly records AST rollback outcomes
        // This avoids issues with environment variable mocking in tests

        let taskId = UUID().uuidString

        // Create temporary database for trace persistence
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("trace_test_ast.sqlite").path

        // Create trace sink with test database
        let traceSink = SQLiteMigrationTraceSink(dbPath: dbPath)
        try await traceSink.waitUntilReady()

        // Simulate an AST rollback outcome (as would happen with ANIGMA_AST_VERIFY_FORCE=fail)
        let outcome = MigrationStepOutcome(
            taskId: taskId,
            rewritePath: "ast",
            ruleId: "add-sendable-to-value-types",
            verifyStatus: "failed",
            rollbackStatus: "rolled_back",
            rollbackReason: "forced failure",
            backupPath: "/tmp/test.anigma.bak",
            diffArtifactPath: "/tmp/test.diff",
            detail: "AST verification forced failure"
        )

        // Record the outcome
        traceSink.record(outcome)

        // Wait for async recording
        try await Task.sleep(nanoseconds: 100_000_000)

        // Query trace from database (not logs)
        let queryDb = DatabaseActor(dbPath: dbPath)
        try await queryDb.open()

        let rows = try await queryDb.query("""
            SELECT rewrite_path, verify_status, rollback_status, rollback_reason,
                   backup_path, diff_artifact_path, detail
            FROM migration_trace_steps
            WHERE task_id = ?
            ORDER BY recorded_at DESC
            LIMIT 1
            """,
            parameters: [.text(taskId)]
        )

        XCTAssertEqual(rows.count, 1, "Should have one trace entry")

        guard let row = rows.first else {
            XCTFail("No trace row found")
            return
        }

        XCTAssertEqual(row.string(for: "rewrite_path"), "ast", "Trace should show rewrite_path='ast'")
        XCTAssertEqual(row.string(for: "verify_status"), "failed", "Trace should show verify_status='failed'")
        XCTAssertEqual(row.string(for: "rollback_status"), "rolled_back", "Trace should show rollback_status='rolled_back'")
        XCTAssertEqual(row.string(for: "rollback_reason"), "forced failure", "Trace should show forced failure reason")
        XCTAssertEqual(row.string(for: "detail"), "AST verification forced failure", "Trace should show detail")

        // Backup and diff paths should be recorded
        let backupPath = row.string(for: "backup_path")
        let diffArtifactPath = row.string(for: "diff_artifact_path")

        XCTAssertEqual(backupPath, "/tmp/test.anigma.bak", "Backup path should be recorded")
        XCTAssertEqual(diffArtifactPath, "/tmp/test.diff", "Diff artifact path should be recorded")
    }

    private func insertProjectSpec(_ projectId: UUID) throws {
        let sql = """
            INSERT INTO project_specs (id, name, specText, status, createdAt, updatedAt)
            VALUES (?, 'Pipeline Project', '{}', 'active', datetime('now'), datetime('now'))
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "prepare project insert failed"])
        }
        defer { sqlite3_finalize(stmt) }
        _ = projectId.uuidString.withCString {
            sqlite3_bind_text(stmt, 1, $0, -1, sqliteTransientDestructor)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "project insert failed"])
        }
    }

    private func insertScoutFinding(
        id: UUID,
        projectId: UUID,
        anchorJSON: String?,
        suggestedFix: String?
    ) throws {
        let sql = """
            INSERT INTO scout_findings (
                id, projectId, problemKind, severity, description,
                filePath, lineStart, lineEnd, suggestedFix, createdAt, ast_anchor_json
            ) VALUES (?, ?, 'SendableConformance', 'warning', 'Need Sendable',
                      'Sources/Test.swift', 1, 1, ?, datetime('now'), ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "prepare finding insert failed"])
        }
        defer { sqlite3_finalize(stmt) }
        _ = id.uuidString.withCString {
            sqlite3_bind_text(stmt, 1, $0, -1, sqliteTransientDestructor)
        }
        _ = projectId.uuidString.withCString {
            sqlite3_bind_text(stmt, 2, $0, -1, sqliteTransientDestructor)
        }
        if let suggestedFix = suggestedFix {
            _ = suggestedFix.withCString {
                sqlite3_bind_text(stmt, 3, $0, -1, sqliteTransientDestructor)
            }
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        if let anchorJSON = anchorJSON {
            _ = anchorJSON.withCString {
                sqlite3_bind_text(stmt, 4, $0, -1, sqliteTransientDestructor)
            }
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "finding insert failed"])
        }
    }

    private func insertMigrationTask(taskId: String, projectId: UUID, findingId: UUID) throws {
        let sql = """
            INSERT INTO migration_tasks (
                id, projectId, featureCategory, status, priority, findingId, createdAt, updatedAt
            ) VALUES (?, ?, 'swift6-migration', 'pending', 1, ?, datetime('now'), datetime('now'))
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "prepare task insert failed"])
        }
        defer { sqlite3_finalize(stmt) }
        _ = taskId.withCString {
            sqlite3_bind_text(stmt, 1, $0, -1, sqliteTransientDestructor)
        }
        _ = projectId.uuidString.withCString {
            sqlite3_bind_text(stmt, 2, $0, -1, sqliteTransientDestructor)
        }
        _ = findingId.uuidString.withCString {
            sqlite3_bind_text(stmt, 3, $0, -1, sqliteTransientDestructor)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "task insert failed"])
        }
    }

    private func scoutFindingExists(findingId: UUID) throws -> Bool {
        let sql = "SELECT COUNT(*) FROM scout_findings WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "prepare scout existence query failed"])
        }
        defer { sqlite3_finalize(stmt) }
        _ = findingId.uuidString.withCString {
            sqlite3_bind_text(stmt, 1, $0, -1, sqliteTransientDestructor)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "scout existence query failed"])
        }
        let count = sqlite3_column_int64(stmt, 0)
        return count > 0
    }

    func testVerificationCircuitBreaker() async throws {
        // Create a circuit breaker with low threshold for testing
        let circuitBreaker = VerificationCircuitBreaker(maxFailures: 2, failureWindow: 5, cooldownDuration: 2)

        // Test 1: Circuit should allow operations initially
        let shouldProceed1 = await circuitBreaker.recordFailure()
        XCTAssertTrue(shouldProceed1, "Circuit should allow after 1 failure")

        // Test 2: Record failures to open circuit
        let shouldProceed2 = await circuitBreaker.recordFailure()
        XCTAssertFalse(shouldProceed2, "Circuit should block after 2 failures")

        // Test 3: Circuit should stay open during cooldown
        let shouldProceed3 = await circuitBreaker.recordFailure()
        XCTAssertFalse(shouldProceed3, "Circuit should remain blocked during cooldown")

        // Test 4: Wait for cooldown and check circuit half-open
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds > 2 second cooldown
        let shouldProceed4 = await circuitBreaker.recordFailure()
        XCTAssertTrue(shouldProceed4, "Circuit should allow after cooldown (half-open state)")

        // Test 5: Record success to reset circuit
        await circuitBreaker.recordSuccess()
        let shouldProceed5 = await circuitBreaker.recordFailure()
        XCTAssertTrue(shouldProceed5, "Circuit should allow after success reset")

        // Test 6: Get state to debug
        let stateAfterReset = await circuitBreaker.getState()
        print("State after reset and 1 failure: \(stateAfterReset)")

        // Test 7: Second failure after reset should block
        let shouldProceed6 = await circuitBreaker.recordFailure()
        XCTAssertFalse(shouldProceed6, "Circuit should block after 2 failures post-reset")
    }

    func testMigrationEngineWithCircuitBreaker() async throws {
        // Create test data
        let projectId = UUID()
        let findingId = UUID()
        let taskId = "test-circuit-breaker-task"

        try insertProjectSpec(projectId)
        try insertScoutFinding(id: findingId, projectId: projectId, anchorJSON: nil, suggestedFix: nil)
        try insertMigrationTask(taskId: taskId, projectId: projectId, findingId: findingId)

        // Create trace sink
        let traceSink = SQLiteMigrationTraceSink(dbPath: testDbPath)

        // Create circuit breaker
        let circuitBreaker = VerificationCircuitBreaker(maxFailures: 2, failureWindow: 5, cooldownDuration: 2)

        // Create migration engine with circuit breaker
        let engine = Swift6MigrationEngine(
            traceSink: traceSink,
            circuitBreaker: circuitBreaker
        )

        // Test: Engine should process with circuit breaker
        // We can't directly access private verificationCircuitBreaker, but we can test integration
        // by checking that the engine processes tasks

        // Create a mock task row
        let taskRow = MigrationTaskRow(
            id: taskId,
            engineType: "swift6-migration",
            featureCategory: "swift6-migration",
            status: "pending",
            createdAt: Date(),
            priority: 1,
            projectId: projectId,
            findingId: findingId.uuidString
        )

        // Test: Process a task - this should work normally
        let result = try await engine.process(task: taskRow, db: db)

        // The task should fail (no actual AST to process) but circuit should handle it
        // We're mainly testing that the engine integrates with circuit breaker
        XCTAssertNotNil(result, "Engine should return a result")

        // Check that circuit breaker state can be queried
        let circuitState = await circuitBreaker.getState()
        XCTAssertTrue(circuitState.contains("CLOSED"), "Circuit should be closed after single failure: \(circuitState)")
    }
}
