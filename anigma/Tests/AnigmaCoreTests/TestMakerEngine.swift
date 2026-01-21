//
//  TestMakerEngine.swift
//  AnigmaCoreTests
//
//  Deterministic integration coverage for MakerEngine enhancements.
//

import Foundation
import XCTest
@testable import AnigmaCore
import ContractsCore

final class TestMakerEngine: XCTestCase {
    func testSizeCapQuarantineEmitsReceipt() async throws {
        let runId = "run-sizecap-\(UUID().uuidString)"
        let stepId = StepId("step-sizecap")
        let receipts = makeReceiptPersister()

        let auditLog = TestAuditLog()
        let evidenceRecorder = TestEvidenceRecorder()
        let quarantineManager = TestQuarantineManager()
        let config = MakerEngineConfig(
            enhancementsEnabled: true,
            enhancementLimits: MakerResourceLimits(maxBytes: 10, maxLines: 1, maxDurationSeconds: 1.0),
            enhancementReceiptPersister: receipts.persister,
            enhancementCodeVersion: "test",
            enhancementDeterminismCheckEnabled: false
        )

        let engine = MakerEngine(
            policyEngine: PolicyEnforcementEngine(),
            auditLog: auditLog,
            evidenceRecorder: evidenceRecorder,
            candidateGenerators: [],
            stepExecutors: [],
            quarantineManager: quarantineManager,
            config: config,
            enhancementLayer: .fallback()
        )

        let oversized = String(repeating: "x", count: 100)
        let input = makeStepInput(stepId: stepId, runId: runId, metadata: ["payload": oversized])

        let output = try await engine.executeStep(input)
        XCTAssertEqual(output.status, .quarantined)

        let quarantineRecords = await quarantineManager.records()
        XCTAssertTrue(quarantineRecords.contains { $0.reason == "resource_limit" })

        let receiptPath = receipts.runDirectory(runId: runId).appendingPathComponent("\(stepId.value).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: receiptPath.path))

        let receiptData = try Data(contentsOf: receiptPath)
        let receipt = try JSONDecoder().decode(MakerReceipt.self, from: receiptData)
        XCTAssertTrue(receipt.core.resourceLimitExceeded)
        XCTAssertEqual(receipt.core.quarantineDecision, "resource_limit")
    }

    func testDeterminismDivergenceQuarantinesAndPersistsReceipt() async throws {
        let runId = "run-determinism-\(UUID().uuidString)"
        let stepId = StepId("step-determinism")
        let receipts = makeReceiptPersister()

        let auditLog = TestAuditLog()
        let evidenceRecorder = TestEvidenceRecorder()
        let quarantineManager = TestQuarantineManager()
        let generator = StaticCandidateGenerator(candidates: [makeCandidate(stepId: stepId)])
        let executor = FlippingExecutor()
        let config = MakerEngineConfig(
            enhancementsEnabled: true,
            enhancementReceiptPersister: receipts.persister,
            enhancementCodeVersion: "test",
            enhancementDeterminismCheckEnabled: true
        )

        let engine = MakerEngine(
            policyEngine: PolicyEnforcementEngine(),
            auditLog: auditLog,
            evidenceRecorder: evidenceRecorder,
            candidateGenerators: [generator],
            stepExecutors: [executor],
            quarantineManager: quarantineManager,
            config: config,
            enhancementLayer: .fallback()
        )

        let input = makeStepInput(stepId: stepId, runId: runId, metadata: ["note": "determinism"])
        let output = try await engine.executeStep(input)
        XCTAssertEqual(output.status, .completed)

        let quarantineRecords = await quarantineManager.records()
        XCTAssertTrue(quarantineRecords.contains { $0.reason.contains("Determinism check failed") })

        let divergencePath = receipts.runDirectory(runId: runId)
            .appendingPathComponent("\(stepId.value)-determinism-check.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: divergencePath.path))
    }

    func testPerAdapterReceiptEmission() async throws {
        let runId = "run-adapters-\(UUID().uuidString)"
        let stepId = StepId("step-adapters")
        let receipts = makeReceiptPersister()

        let auditLog = TestAuditLog()
        let evidenceRecorder = TestEvidenceRecorder()
        let quarantineManager = TestQuarantineManager()
        let generator = StaticCandidateGenerator(candidates: [makeCandidate(stepId: stepId)])
        let executor = SimpleExecutor()
        let config = MakerEngineConfig(
            enhancementsEnabled: true,
            enhancementReceiptPersister: receipts.persister,
            enhancementCodeVersion: "test",
            enhancementDeterminismCheckEnabled: false
        )

        let engine = MakerEngine(
            policyEngine: PolicyEnforcementEngine(),
            auditLog: auditLog,
            evidenceRecorder: evidenceRecorder,
            candidateGenerators: [generator],
            stepExecutors: [executor],
            quarantineManager: quarantineManager,
            config: config,
            enhancementLayer: .fallback()
        )

        let input = makeStepInput(stepId: stepId, runId: runId, metadata: ["regexPattern": "test"])
        let output = try await engine.executeStep(input)
        XCTAssertEqual(output.status, .completed)

        let runDir = receipts.runDirectory(runId: runId)
        let diffPath = runDir.appendingPathComponent("\(stepId.value)-diff.json")
        let parsePath = runDir.appendingPathComponent("\(stepId.value)-parse.json")
        let regexPath = runDir.appendingPathComponent("\(stepId.value)-regex.json")
        let policyPath = runDir.appendingPathComponent("\(stepId.value)-policy.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: diffPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: parsePath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: regexPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: policyPath.path))

        let diffData = try Data(contentsOf: diffPath)
        let diffReceipt = try JSONDecoder().decode(MakerReceipt.self, from: diffData)
        XCTAssertEqual(diffReceipt.core.adapterIdentifiers[MakerAdapterIdentity.diffId], MakerAdapterIdentity.fallbackVersion)
    }
}

private struct ReceiptPaths {
    let persister: FileMakerReceiptPersister
    let receiptsRoot: URL

    func runDirectory(runId: String) -> URL {
        receiptsRoot.appendingPathComponent(runId, isDirectory: true)
    }
}

private func makeReceiptPersister() -> ReceiptPaths {
    let baseDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let receiptsRoot = baseDir.appendingPathComponent("receipts", isDirectory: true)
    let ledgerPath = baseDir.appendingPathComponent("ledger.jsonl", isDirectory: false)
    let persister = FileMakerReceiptPersister(
        receiptsRoot: receiptsRoot.path,
        ledgerPath: ledgerPath.path
    )
    return ReceiptPaths(persister: persister, receiptsRoot: receiptsRoot)
}

private func makeStepInput(stepId: StepId, runId: String, metadata: [String: String]) -> StepInput {
    StepInput(
        stepId: stepId,
        stateSlice: StateSlice(entities: [], relations: [], metadata: metadata),
        context: StepContext(
            workflowId: "workflow-\(runId)",
            sessionId: runId,
            trustTier: .gold,
            allowedCapabilities: [],
            securityZone: .sandbox
        ),
        constraints: []
    )
}

private func makeCandidate(stepId: StepId) -> StepCandidate {
    StepCandidate(
        id: CandidateId("candidate-\(stepId.value)"),
        stepId: stepId,
        action: CandidateAction(
            type: .analyze,
            parameters: ["subject": "candidate"]
        ),
        confidence: 0.9,
        reasoning: "Deterministic candidate reasoning.",
        estimatedImpact: ImpactEstimate(
            riskLevel: .low,
            changesEstimated: 0,
            resourcesRequired: ResourceEstimate(),
            rollbackComplexity: .trivial
        ),
        policyFlags: []
    )
}

private struct StaticCandidateGenerator: CandidateGenerator {
    let candidates: [StepCandidate]

    func generateCandidates(for input: StepInput) async throws -> [StepCandidate] {
        candidates
    }
}

private final class SimpleExecutor: StepExecutor, @unchecked Sendable {
    func canExecute(_ actionType: ActionType) -> Bool {
        true
    }

    func execute(_ action: CandidateAction, with input: StepInput) async throws -> StepOutput {
        StepOutput(
            stepId: input.stepId,
            stateDelta: StateDelta(),
            metrics: StepMetrics(duration: 0, memoryUsed: 0),
            status: .completed
        )
    }
}

private final class FlippingExecutor: StepExecutor, @unchecked Sendable {
    private var callCount = 0

    func canExecute(_ actionType: ActionType) -> Bool {
        true
    }

    func execute(_ action: CandidateAction, with input: StepInput) async throws -> StepOutput {
        callCount += 1
        let entity = StateEntity(
            id: "entity-\(callCount)",
            type: "test",
            attributes: ["count": "\(callCount)"]
        )
        let delta = StateDelta(
            addedEntities: [entity],
            modifiedEntities: [],
            deletedEntities: [],
            addedRelations: [],
            deletedRelations: []
        )
        return StepOutput(
            stepId: input.stepId,
            stateDelta: delta,
            metrics: StepMetrics(duration: 0, memoryUsed: 0),
            status: .completed
        )
    }
}

private final actor TestAuditLog: AuditLogging {
    private(set) var descriptions: [String] = []

    func recordEvent(
        id: UUID,
        type: AuditEventType,
        principal: String?,
        module: String?,
        description: String,
        metadata: [String: String]
    ) async throws {
        descriptions.append(description)
    }
}

private final actor TestEvidenceRecorder: EvidenceRecording {
    private(set) var heads: [EvidenceHead] = []

    func recordEvidence(head: EvidenceHead, content: Data) async throws {
        heads.append(head)
    }

    func recordStateDelta(sessionId: String, delta: StateDelta, timestamp: Date) async throws {}
}

private final actor TestQuarantineManager: QuarantineManager {
    struct Record: Sendable {
        let stepId: StepId
        let reason: String
        let duration: TimeInterval
    }

    private var recordsStorage: [Record] = []

    func checkQuarantine(stepId: StepId, sessionId: String, trustTier: TrustTier) async -> QuarantineAction? {
        nil
    }

    func quarantineStep(stepId: StepId, reason: String, duration: TimeInterval) async {
        recordsStorage.append(Record(stepId: stepId, reason: reason, duration: duration))
    }

    func records() async -> [Record] {
        recordsStorage
    }
}
