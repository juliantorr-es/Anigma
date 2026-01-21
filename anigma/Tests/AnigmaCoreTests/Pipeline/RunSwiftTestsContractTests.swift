//
//  RunSwiftTestsContractTests.swift
//  AnigmaCoreTests
//
//  Unit tests for AnigmaCoreTests.
//

import XCTest
@testable import AnigmaCore
@testable import ContractsCore

private actor FakeTestRunner: TestCommandRunning {
    var called = false
    var lastRequest: TestCommandRequest?
    var result: TestCommandResult

    init(result: TestCommandResult) {
        self.result = result
    }

    func runTests(_ request: TestCommandRequest) async throws -> TestCommandResult {
        called = true
        lastRequest = request
        return result
    }
}

final class RunSwiftTestsContractTests: XCTestCase {
    func testSuccessfulRunProducesEnvelope() async throws {
        let runner = FakeTestRunner(
            result: TestCommandResult(exitCode: 0, stdout: "ok", stderr: "", durationMs: 123, commitHash: "abc", isDirty: false)
        )
        let inputMetrics = ExecutionMetrics(wallTimeMs: 0, executor: "tester")
        let receipt = ContractReceipt.placeholder(
            contractID: RunSwiftTestsContract.id,
            runID: "run-1",
            sessionID: "sess-1",
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: inputMetrics
        )
        let envelope = ArtifactEnvelope(
            schemaVersion: RunSwiftTestsContract.inputSchemaVersion,
            payload: TestRunInput(packagePath: "/tmp", testTargets: ["UnitTests"], filter: nil, environment: [:], commitHash: "abc", isDirty: false),
            evidenceRefs: [],
            metrics: inputMetrics,
            receipt: receipt
        )
        let ctx = ContractContext(
            contractID: RunSwiftTestsContract.id,
            runID: "run-1",
            sessionID: "sess-1",
            trustTier: .silver,
            securityZone: .restricted,
            budgets: ContractBudgets(),
            executorIdentity: "tester",
            testRunner: runner
        )

        let output = try await RunSwiftTestsContract.execute(input: envelope, ctx: ctx)
        try RunSwiftTestsContract.validate(output: output)

        let called = await runner.called
        XCTAssertTrue(called)
        XCTAssertEqual(output.payload.exitCode, 0)
        XCTAssertEqual(output.payload.stdout, "ok")
        XCTAssertEqual(output.metrics.wallTimeMs, 123)
        XCTAssertEqual(output.payload.commitHash, "abc")
        XCTAssertEqual(output.payload.isDirty, false)
    }

    func testNonZeroExitCodeFailsValidation() async throws {
        let runner = FakeTestRunner(
            result: TestCommandResult(exitCode: 1, stdout: "fail", stderr: "boom", durationMs: 10, commitHash: "abc", isDirty: false)
        )
        let inputMetrics = ExecutionMetrics(wallTimeMs: 0, executor: "tester")
        let receipt = ContractReceipt.placeholder(
            contractID: RunSwiftTestsContract.id,
            runID: "run-2",
            sessionID: "sess-1",
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: inputMetrics
        )
        let envelope = ArtifactEnvelope(
            schemaVersion: RunSwiftTestsContract.inputSchemaVersion,
            payload: TestRunInput(packagePath: "/tmp", testTargets: ["UnitTests"], filter: nil, environment: [:], commitHash: "abc", isDirty: false),
            evidenceRefs: [],
            metrics: inputMetrics,
            receipt: receipt
        )
        let ctx = ContractContext(
            contractID: RunSwiftTestsContract.id,
            runID: "run-2",
            sessionID: "sess-1",
            trustTier: .silver,
            securityZone: .restricted,
            budgets: ContractBudgets(),
            executorIdentity: "tester",
            testRunner: runner
        )

        let output = try await RunSwiftTestsContract.execute(input: envelope, ctx: ctx)
        XCTAssertThrowsError(try RunSwiftTestsContract.validate(output: output))
    }
}
