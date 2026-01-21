//
//  CLIDatabaseTests.swift
//  AnigmaCLITests
//
//  Unit tests for database layer.
//

import XCTest
@testable import AnigmaCLIDatabase

final class CLIDatabaseTests: XCTestCase {
    var db: CLIDatabaseActor!
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let config = CLIDatabaseConfig(
            path: tempDir.appendingPathComponent("test.db").path
        )
        db = CLIDatabaseActor(config: config)
        try await db.open()
    }

    override func tearDown() async throws {
        db.close()
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Database Initialization

    func testDatabaseCreation() async throws {
        // Database should be created and opened
        let rows = try await db.query("SELECT name FROM sqlite_master WHERE type='table'", parameters: [])
        XCTAssertFalse(rows.isEmpty, "Database should have tables")
    }

    func testSchemaTablesExist() async throws {
        let expectedTables = ["runs", "steps", "receipts", "chunks", "worktree_leases"]

        for tableName in expectedTables {
            let rows = try await db.query(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
                parameters: [.text(tableName)]
            )
            XCTAssertEqual(rows.count, 1, "Table '\(tableName)' should exist")
        }
    }

    func testFTS5TableExists() async throws {
        let rows = try await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks_fts'",
            parameters: []
        )
        XCTAssertEqual(rows.count, 1, "FTS5 table should exist")
    }

    // MARK: - Query Operations

    func testInsertAndQuery() async throws {
        let runID = UUID().uuidString

        try await db.execute("""
            INSERT INTO runs (run_id, task_summary, mode, status, created_at)
            VALUES (?, ?, ?, ?, ?)
            """, parameters: [
                .text(runID),
                .text("Test task"),
                .text("run"),
                .text("pending"),
                .double(Date().timeIntervalSince1970)
            ])

        let rows = try await db.query(
            "SELECT run_id, task_summary FROM runs WHERE run_id = ?",
            parameters: [.text(runID)]
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?["run_id"]?.asString, runID)
        XCTAssertEqual(rows.first?["task_summary"]?.asString, "Test task")
    }

    func testTransactionRollback() async throws {
        let runID = UUID().uuidString

        do {
            try await db.execute("BEGIN TRANSACTION", parameters: [])

            try await db.execute("""
                INSERT INTO runs (run_id, task_summary, mode, status, created_at)
                VALUES (?, ?, ?, ?, ?)
                """, parameters: [
                    .text(runID),
                    .text("Test task"),
                    .text("run"),
                    .text("pending"),
                    .double(Date().timeIntervalSince1970)
                ])

            try await db.execute("ROLLBACK", parameters: [])
        } catch {
            XCTFail("Transaction should not throw: \(error)")
        }

        let rows = try await db.query(
            "SELECT run_id FROM runs WHERE run_id = ?",
            parameters: [.text(runID)]
        )

        XCTAssertEqual(rows.count, 0, "Rolled back insert should not exist")
    }
}

// MARK: - Receipt Manager Tests

final class CLIReceiptManagerTests: XCTestCase {
    var db: CLIDatabaseActor!
    var receiptManager: CLIReceiptManager!
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let config = CLIDatabaseConfig(
            path: tempDir.appendingPathComponent("test.db").path
        )
        db = CLIDatabaseActor(config: config)
        try await db.open()

        receiptManager = CLIReceiptManager(database: db)
    }

    override func tearDown() async throws {
        db.close()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRecordRunStart() async throws {
        let runID = UUID().uuidString

        let receipt = try await receiptManager.recordRunStart(
            runID: runID,
            mode: "run",
            dryRun: false
        )

        XCTAssertEqual(receipt.runID, runID)
        XCTAssertEqual(receipt.type, .runStart)
        XCTAssertFalse(receipt.receiptHash.isEmpty)
        XCTAssertNil(receipt.parentHash, "First receipt should have no parent")
    }

    func testReceiptChaining() async throws {
        let runID = UUID().uuidString

        let receipt1 = try await receiptManager.recordRunStart(runID: runID, mode: "run", dryRun: false)
        let receipt2 = try await receiptManager.recordToolCall(
            runID: runID,
            stepID: nil,
            toolName: "test_tool",
            request: "test",
            response: "ok",
            approved: true
        )

        XCTAssertNotNil(receipt2.parentHash, "Second receipt should have parent")
        XCTAssertEqual(receipt2.parentHash, receipt1.receiptHash, "Chain should be maintained")
    }

    func testListReceipts() async throws {
        let runID = UUID().uuidString

        _ = try await receiptManager.recordRunStart(runID: runID, mode: "run", dryRun: false)
        _ = try await receiptManager.recordToolCall(
            runID: runID,
            stepID: nil,
            toolName: "test_tool",
            request: "test",
            response: "ok",
            approved: true
        )

        let receipts = try await receiptManager.listReceipts(runID: runID)
        XCTAssertEqual(receipts.count, 2)
        XCTAssertEqual(receipts[0].type, .runStart)
        XCTAssertEqual(receipts[1].type, .toolCall)
    }
}

// MARK: - Run Manager Tests

final class CLIRunManagerTests: XCTestCase {
    var db: CLIDatabaseActor!
    var receiptManager: CLIReceiptManager!
    var runManager: CLIRunManager!
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let config = CLIDatabaseConfig(
            path: tempDir.appendingPathComponent("test.db").path
        )
        db = CLIDatabaseActor(config: config)
        try await db.open()

        receiptManager = CLIReceiptManager(database: db)
        runManager = CLIRunManager(database: db, receiptManager: receiptManager)
    }

    override func tearDown() async throws {
        db.close()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testCreateRun() async throws {
        let run = try await runManager.createRun(
            taskSummary: "Test task",
            taskDetails: nil,
            mode: .run,
            dryRun: false,
            worktreePath: nil
        )

        XCTAssertFalse(run.runID.isEmpty)
        XCTAssertEqual(run.taskSummary, "Test task")
        XCTAssertEqual(run.mode, .run)
        XCTAssertEqual(run.status, .pending)
    }

    func testUpdateRunStatus() async throws {
        let run = try await runManager.createRun(
            taskSummary: "Test task",
            mode: .run,
            dryRun: false
        )

        try await runManager.updateRunStatus(
            runID: run.runID,
            status: .running
        )

        let updated = try await runManager.getRun(runID: run.runID)
        XCTAssertEqual(updated?.status, .running)
    }

    func testRecordStep() async throws {
        let run = try await runManager.createRun(
            taskSummary: "Test task",
            mode: .run,
            dryRun: false
        )

        let step = try await runManager.recordStep(
            runID: run.runID,
            stepNumber: 1,
            actionType: "test_action",
            actionData: "test data"
        )

        XCTAssertFalse(step.stepID.isEmpty)
        XCTAssertEqual(step.stepNumber, 1)
        XCTAssertEqual(step.actionType, "test_action")
        XCTAssertEqual(step.status, .pending)
    }

    func testListRuns() async throws {
        _ = try await runManager.createRun(taskSummary: "Task 1", mode: .run, dryRun: false)
        _ = try await runManager.createRun(taskSummary: "Task 2", mode: .plan, dryRun: true)

        let runs = try await runManager.listRuns(limit: 10)
        XCTAssertGreaterThanOrEqual(runs.count, 2)
    }
}

// MARK: - Loop Breaker Tests

final class CLILoopBreakerTests: XCTestCase {
    func testMaxStepsLimit() async throws {
        let config = LoopBreakerConfig(maxSteps: 3)
        let loopBreaker = CLILoopBreaker(runID: UUID().uuidString, config: config)

        await loopBreaker.recordStep()
        await loopBreaker.recordStep()
        await loopBreaker.recordStep()

        // Should not trigger yet
        XCTAssertNil(await loopBreaker.shouldStop())

        await loopBreaker.recordStep()

        // Should trigger on 4th step
        let result = await loopBreaker.shouldStop()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.reason, .maxSteps)
    }

    func testMaxWallTimeLimit() async throws {
        let config = LoopBreakerConfig(maxWallTimeSeconds: 1.0)
        let loopBreaker = CLILoopBreaker(runID: UUID().uuidString, config: config)

        // Should not trigger immediately
        XCTAssertNil(await loopBreaker.shouldStop())

        // Wait for time limit
        try await Task.sleep(nanoseconds: 1_100_000_000) // 1.1s

        // Should trigger
        let result = await loopBreaker.shouldStop()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.reason, .maxWallTime)
    }

    func testRepeatedCallsDetection() async throws {
        let config = LoopBreakerConfig(repeatedCallThreshold: 2)
        let loopBreaker = CLILoopBreaker(runID: UUID().uuidString, config: config)

        await loopBreaker.recordToolCall(toolName: "test", args: "same")
        XCTAssertNil(await loopBreaker.shouldStop())

        await loopBreaker.recordToolCall(toolName: "test", args: "same")

        // Should trigger on 2nd identical call
        let result = await loopBreaker.shouldStop()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.reason, .repeatedCalls)
    }

    func testCountersTracking() async throws {
        let config = LoopBreakerConfig()
        let loopBreaker = CLILoopBreaker(runID: UUID().uuidString, config: config)

        await loopBreaker.recordStep()
        await loopBreaker.recordToolCall(toolName: "test", args: "arg1")
        await loopBreaker.recordTokens(count: 100)
        await loopBreaker.recordSpend(amount: 0.05)

        let counters = await loopBreaker.getCurrentCounters()
        XCTAssertEqual(counters.steps, 1)
        XCTAssertEqual(counters.toolCalls, 1)
        XCTAssertEqual(counters.tokens, 100)
        XCTAssertEqual(counters.spend, 0.05)
    }
}

// MARK: - Worktree Manager Tests

final class CLIWorktreeManagerTests: XCTestCase {
    var db: CLIDatabaseActor!
    var worktreeManager: CLIWorktreeManager!
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let config = CLIDatabaseConfig(
            path: tempDir.appendingPathComponent("test.db").path
        )
        db = CLIDatabaseActor(config: config)
        try await db.open()

        worktreeManager = CLIWorktreeManager(database: db)
    }

    override func tearDown() async throws {
        db.close()
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testAcquireLease() async throws {
        let path = tempDir.appendingPathComponent("worktree1").path

        let lease = try await worktreeManager.acquireLease(
            worktreePath: path,
            purpose: "test",
            runID: nil
        )

        XCTAssertFalse(lease.leaseID.isEmpty)
        XCTAssertEqual(lease.worktreePath, path)
        XCTAssertEqual(lease.status, "active")
        XCTAssertFalse(lease.locked)
    }

    func testReleaseLease() async throws {
        let path = tempDir.appendingPathComponent("worktree2").path

        let lease = try await worktreeManager.acquireLease(
            worktreePath: path,
            purpose: "test",
            runID: nil
        )

        try await worktreeManager.releaseLease(leaseID: lease.leaseID)

        let released = try await worktreeManager.getLease(leaseID: lease.leaseID)
        XCTAssertEqual(released?.status, "released")
    }

    func testListLeases() async throws {
        let path1 = tempDir.appendingPathComponent("worktree1").path
        let path2 = tempDir.appendingPathComponent("worktree2").path

        _ = try await worktreeManager.acquireLease(worktreePath: path1, purpose: "test1", runID: nil)
        _ = try await worktreeManager.acquireLease(worktreePath: path2, purpose: "test2", runID: nil)

        let leases = try await worktreeManager.listLeases()
        XCTAssertGreaterThanOrEqual(leases.count, 2)
    }
}
