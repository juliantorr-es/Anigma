//
//  CLIIntegrationTests.swift
//  AnigmaCLITests
//
//  Integration tests for end-to-end workflows.
//

import XCTest
@testable import AnigmaCLIDatabase
@testable import AnigmaCLICore

final class CLIIntegrationTests: XCTestCase {
    var db: CLIDatabaseActor!
    var receiptManager: CLIReceiptManager!
    var runManager: CLIRunManager!
    var indexManager: CLIIndexManager!
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

        receiptManager = CLIReceiptManager(database: db)
        runManager = CLIRunManager(database: db, receiptManager: receiptManager)
        indexManager = CLIIndexManager(database: db)
        worktreeManager = CLIWorktreeManager(database: db)
    }

    override func tearDown() async throws {
        db.close()
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Full Run Workflow

    func testCompleteRunWorkflow() async throws {
        // 1. Create run
        let run = try await runManager.createRun(
            taskSummary: "Integration test task",
            taskDetails: "Full workflow test",
            mode: .run,
            dryRun: false,
            worktreePath: nil
        )

        XCTAssertEqual(run.status, .pending)

        // 2. Update to running
        try await runManager.updateRunStatus(runID: run.runID, status: .running)

        // 3. Record steps
        let step1 = try await runManager.recordStep(
            runID: run.runID,
            stepNumber: 1,
            actionType: "planning",
            actionData: "Plan the task"
        )

        try await runManager.updateStepStatus(stepID: step1.stepID, status: .running)
        try await runManager.updateStepStatus(stepID: step1.stepID, status: .completed)

        let step2 = try await runManager.recordStep(
            runID: run.runID,
            stepNumber: 2,
            actionType: "execution",
            actionData: "Execute the task"
        )

        try await runManager.updateStepStatus(stepID: step2.stepID, status: .running)
        try await runManager.updateStepStatus(stepID: step2.stepID, status: .completed)

        // 4. Complete run
        try await runManager.updateRunStatus(
            runID: run.runID,
            status: .completed,
            message: "Task completed successfully"
        )

        // 5. Verify final state
        let finalRun = try await runManager.getRun(runID: run.runID)
        XCTAssertEqual(finalRun?.status, .completed)

        let steps = try await runManager.getSteps(runID: run.runID)
        XCTAssertEqual(steps.count, 2)
        XCTAssertTrue(steps.allSatisfy { $0.status == .completed })

        // 6. Verify receipts
        let receipts = try await receiptManager.listReceipts(runID: run.runID)
        XCTAssertGreaterThanOrEqual(receipts.count, 1) // At least run_start
    }

    // MARK: - Run with Worktree

    func testRunWithWorktree() async throws {
        // 1. Acquire worktree
        let worktreePath = tempDir.appendingPathComponent("worktree-test").path
        let lease = try await worktreeManager.acquireLease(
            worktreePath: worktreePath,
            purpose: "integration test",
            runID: nil
        )

        // 2. Create run with worktree
        let run = try await runManager.createRun(
            taskSummary: "Task with worktree",
            mode: .run,
            dryRun: false,
            worktreePath: worktreePath
        )

        XCTAssertEqual(run.worktreePath, worktreePath)

        // 3. Complete run
        try await runManager.updateRunStatus(runID: run.runID, status: .completed)

        // 4. Release worktree
        try await worktreeManager.releaseLease(leaseID: lease.leaseID)

        let releasedLease = try await worktreeManager.getLease(leaseID: lease.leaseID)
        XCTAssertEqual(releasedLease?.status, "released")
    }

    // MARK: - Index and Search

    func testIndexAndSearch() async throws {
        // 1. Add chunks to index
        try await indexManager.addChunk(
            chunkID: "chunk-1",
            path: "test/file1.swift",
            content: "func testFunction() { print(\"Hello\") }",
            startLine: 1,
            endLine: 3,
            chunkType: "function"
        )

        try await indexManager.addChunk(
            chunkID: "chunk-2",
            path: "test/file2.swift",
            content: "class TestClass { var name: String }",
            startLine: 1,
            endLine: 1,
            chunkType: "class"
        )

        // 2. Search for content
        let results = try await indexManager.search(
            query: "test",
            limit: 10
        )

        XCTAssertGreaterThanOrEqual(results.count, 1)

        // 3. Get chunk
        let chunk = try await indexManager.getChunk(chunkID: "chunk-1")
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.path, "test/file1.swift")
    }

    // MARK: - Receipt Chain Integrity

    func testReceiptChainIntegrity() async throws {
        let runID = UUID().uuidString

        // Generate a chain of receipts
        let receipt1 = try await receiptManager.recordRunStart(runID: runID, mode: "run", dryRun: false)
        let receipt2 = try await receiptManager.recordToolCall(
            runID: runID,
            stepID: nil,
            toolName: "tool1",
            request: "req1",
            response: "res1",
            approved: true
        )
        let receipt3 = try await receiptManager.recordToolCall(
            runID: runID,
            stepID: nil,
            toolName: "tool2",
            request: "req2",
            response: "res2",
            approved: true
        )

        // Verify chain
        XCTAssertNil(receipt1.parentHash)
        XCTAssertEqual(receipt2.parentHash, receipt1.receiptHash)
        XCTAssertEqual(receipt3.parentHash, receipt2.receiptHash)

        // Verify all receipts retrievable
        let allReceipts = try await receiptManager.listReceipts(runID: runID)
        XCTAssertEqual(allReceipts.count, 3)

        // Verify chain continuity
        for i in 1..<allReceipts.count {
            XCTAssertEqual(
                allReceipts[i].parentHash,
                allReceipts[i - 1].receiptHash,
                "Receipt chain broken at index \(i)"
            )
        }
    }

    // MARK: - Loop Breaker Integration

    func testLoopBreakerWithRun() async throws {
        let run = try await runManager.createRun(
            taskSummary: "Loop breaker test",
            mode: .run,
            dryRun: false
        )

        let config = LoopBreakerConfig(maxSteps: 5)
        let loopBreaker = CLILoopBreaker(runID: run.runID, config: config)

        // Execute steps until limit
        for i in 1...5 {
            await loopBreaker.recordStep()

            _ = try await runManager.recordStep(
                runID: run.runID,
                stepNumber: i,
                actionType: "test_step",
                actionData: "Step \(i)"
            )
        }

        // Should not trigger yet
        XCTAssertNil(await loopBreaker.shouldStop())

        // One more step triggers limit
        await loopBreaker.recordStep()
        let stopResult = await loopBreaker.shouldStop()

        XCTAssertNotNil(stopResult)
        XCTAssertEqual(stopResult?.reason, .maxSteps)

        // Record stop receipt
        _ = try await receiptManager.recordLoopBreaker(
            runID: run.runID,
            result: stopResult!
        )

        // Update run as cancelled
        try await runManager.updateRunStatus(
            runID: run.runID,
            status: .cancelled,
            message: "Loop breaker triggered"
        )

        let finalRun = try await runManager.getRun(runID: run.runID)
        XCTAssertEqual(finalRun?.status, .cancelled)
    }

    // MARK: - Tool Execution Integration

    func testToolExecutionWithTracking() async throws {
        let run = try await runManager.createRun(
            taskSummary: "Tool execution test",
            mode: .run,
            dryRun: false
        )

        let step = try await runManager.recordStep(
            runID: run.runID,
            stepNumber: 1,
            actionType: "tool_execution",
            actionData: "Execute tools"
        )

        // Record tool calls
        _ = try await receiptManager.recordToolCall(
            runID: run.runID,
            stepID: step.stepID,
            toolName: "read_file",
            request: "/path/to/file.txt",
            response: "file_hash_abc123",
            approved: true
        )

        _ = try await receiptManager.recordToolCall(
            runID: run.runID,
            stepID: step.stepID,
            toolName: "write_file",
            request: "/path/to/output.txt",
            response: "success",
            approved: true
        )

        // Verify receipts
        let receipts = try await receiptManager.listReceipts(runID: run.runID)
        let toolReceipts = receipts.filter { $0.type == .toolCall }

        XCTAssertEqual(toolReceipts.count, 2)
    }

    // MARK: - Multi-Run Scenario

    func testMultipleRunsConcurrent() async throws {
        // Create multiple runs
        let run1 = try await runManager.createRun(taskSummary: "Task 1", mode: .run, dryRun: false)
        let run2 = try await runManager.createRun(taskSummary: "Task 2", mode: .run, dryRun: false)
        let run3 = try await runManager.createRun(taskSummary: "Task 3", mode: .plan, dryRun: true)

        // Update statuses concurrently
        try await runManager.updateRunStatus(runID: run1.runID, status: .running)
        try await runManager.updateRunStatus(runID: run2.runID, status: .running)
        try await runManager.updateRunStatus(runID: run3.runID, status: .completed)

        // Verify
        let allRuns = try await runManager.listRuns(limit: 10)
        XCTAssertGreaterThanOrEqual(allRuns.count, 3)

        let runningRuns = try await runManager.listRuns(limit: 10, status: .running)
        XCTAssertEqual(runningRuns.count, 2)

        let completedRuns = try await runManager.listRuns(limit: 10, status: .completed)
        XCTAssertGreaterThanOrEqual(completedRuns.count, 1)
    }
}
