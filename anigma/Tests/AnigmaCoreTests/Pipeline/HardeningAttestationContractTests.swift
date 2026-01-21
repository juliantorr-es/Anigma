//
//  HardeningAttestationContractTests.swift
//  AnigmaCoreTests
//
//  Unit tests for AnigmaCoreTests.
//

import XCTest
@testable import AnigmaCore
@testable import ContractsCore

final class HardeningAttestationContractTests: XCTestCase {
    func testAttestationRequiresReceipts() async throws {
        let metrics = ExecutionMetrics(wallTimeMs: 0, executor: "tester")
        let receipt = ContractReceipt.placeholder(
            contractID: HardeningAttestationContract.id,
            runID: "run-att",
            sessionID: "sess-att",
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: metrics
        )
        let input = HardeningAttestationInput(
            commitHash: "abc123",
            testCommitHash: "abc123",
            testTreeIsDirty: false,
            pipelineSchemaVersions: ["pipeline.pdf.segment": 1],
            testReceiptHashes: [],
            enduranceReceiptHashes: ["end-1"],
            migrationVersion: "v1",
            environment: [:]
        )
        let envelope = ArtifactEnvelope(
            schemaVersion: HardeningAttestationContract.inputSchemaVersion,
            payload: input,
            evidenceRefs: [],
            metrics: metrics,
            receipt: receipt
        )
        let ctx = ContractContext(
            contractID: HardeningAttestationContract.id,
            runID: "run-att",
            sessionID: "sess-att",
            trustTier: .silver,
            securityZone: .restricted,
            budgets: ContractBudgets(),
            executorIdentity: "tester"
        )

        let output = try await HardeningAttestationContract.execute(input: envelope, ctx: ctx)
        XCTAssertThrowsError(try HardeningAttestationContract.validate(output: output))
    }
}
