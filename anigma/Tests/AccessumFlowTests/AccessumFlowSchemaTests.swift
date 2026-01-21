//
//  AccessumFlowSchemaTests.swift
//  AccessumFlowTests
//
//  Unit tests for AccessumFlowTests.
//

import Foundation
import XCTest

@testable import AccessumFlow
import DatabaseCore
import AnigmaPrimitives
// Merged: HarmoniaSpine -> HarmoniaModule/Spine

final class AccessumFlowSchemaTests: XCTestCase {
    func testStepMetadataColumnsRoundTrip() async throws {
        let tempDir = try prepareTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("accessum.sqlite")
        let store = AccessumRunStore(dbURL: dbURL)
        try await store.prepare()

        let runId = UUID().uuidString
        try await store.startRun(record: makeRunRecord(runId: runId))

        let step = makeStep(
            rewritePath: "ast",
            verifyStatus: "passed",
            rollbackStatus: "not_needed",
            rollbackReason: nil,
            ruleId: "ast.add_sendable",
            diffArtifactPath: "/tmp/diff.txt",
            backupPath: "/tmp/backup.anigma",
            startedAt: "2025-01-01T00:00:00Z",
            finishedAt: "2025-01-01T00:00:05Z"
        )

        let trace = makeTrace(runId: runId, steps: [step])
        let metrics = AccessumMetrics(totalDurationMs: 42, stepCount: 1)
        try await store.completeRun(
            runId: runId,
            trace: trace,
            traceData: try JSONEncoder().encode(trace),
            tracePath: tempDir.appendingPathComponent("trace.json").path,
            steps: [step],
            metrics: metrics
        )

        let db = DatabaseActor(dbPath: dbURL.path)
        try await db.open()
        let rows = try await db.query("SELECT * FROM steps WHERE runId = ?", parameters: [.text(runId)])
        XCTAssertEqual(rows.count, 1)
        let row = rows[0]
        XCTAssertEqual(row.string(for: "rewrite_path"), step.rewritePath)
        XCTAssertEqual(row.string(for: "verify_status"), step.verifyStatus)
        XCTAssertEqual(row.string(for: "rollback_status"), step.rollbackStatus)
        XCTAssertEqual(row.string(for: "rule_id"), step.ruleId)
        XCTAssertEqual(row.string(for: "diff_artifact_path"), step.diffArtifactPath)
        XCTAssertEqual(row.string(for: "backup_path"), step.backupPath)
        XCTAssertEqual(row.string(for: "started_at"), step.startedAt)
        XCTAssertEqual(row.string(for: "finished_at"), step.finishedAt)
    }

    func testStepDefaultsWhenMetadataMissing() async throws {
        let tempDir = try prepareTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("accessum.sqlite")
        let store = AccessumRunStore(dbURL: dbURL)
        try await store.prepare()

        let runId = UUID().uuidString
        try await store.startRun(record: makeRunRecord(runId: runId))

        let step = makeStep()
        let trace = makeTrace(runId: runId, steps: [step])
        let metrics = AccessumMetrics(totalDurationMs: 7, stepCount: 1)
        try await store.completeRun(
            runId: runId,
            trace: trace,
            traceData: try JSONEncoder().encode(trace),
            tracePath: tempDir.appendingPathComponent("trace.json").path,
            steps: [step],
            metrics: metrics
        )

        let db = DatabaseActor(dbPath: dbURL.path)
        try await db.open()
        let rows = try await db.query("SELECT * FROM steps WHERE runId = ?", parameters: [.text(runId)])
        XCTAssertEqual(rows.count, 1)
        let row = rows[0]
        XCTAssertEqual(row.string(for: "rewrite_path"), "none")
        XCTAssertEqual(row.string(for: "verify_status"), "not_run")
        XCTAssertEqual(row.string(for: "rollback_status"), "not_needed")
        XCTAssertNil(row.string(for: "rollback_reason"))
        XCTAssertNil(row.string(for: "rule_id"))
        XCTAssertNil(row.string(for: "diff_artifact_path"))
        XCTAssertNil(row.string(for: "backup_path"))
    }

    func testAdminPayloadIncludesMigrationTrace() async throws {
        let tempDir = try prepareTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("trace.sqlite").path
        let sink = SQLiteMigrationTraceSink(dbPath: dbPath)
        let outcome = MigrationStepOutcome(
            taskId: "admin-task",
            rewritePath: "regex",
            ruleId: "rule-1",
            verifyStatus: "not_run",
            rollbackStatus: "not_needed",
            detail: "detail"
        )
        sink.record(outcome)
        try await sink.waitUntilReady()
        try await Task.sleep(nanoseconds: 100_000_000)

        let reporter = MigrationTraceReporter(dbPath: dbPath)
        let record = try await reporter.fetchLatest(taskId: outcome.taskId)
        XCTAssertNotNil(record)
        let payload = AccessumAdminPayload(
            summary: AccessumAdminSummary(
                totalRuns: 0,
                countsByStatus: [:],
                stuckThresholdMinutes: 0,
                stuckRuns: []
            ),
            basePath: tempDir.path,
            migrationTrace: record
        )
        let envelope = AccessumAdminEnvelope(
            contractVersion: AccessumFlow.contractVersion,
            status: "ok",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            command: "accessum flow admin",
            payload: payload,
            governanceTrace: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(envelope)
        guard let json = String(data: data, encoding: .utf8) else {
            fatalError("Failed to unwrap json")
        }
        XCTAssertTrue(json.contains("\"rewrite_path\""))
        XCTAssertTrue(json.contains("\"verify_status\""))
        XCTAssertTrue(json.contains("\"rollback_status\""))
        XCTAssertTrue(json.contains("\"migration_trace\""))
        XCTAssertTrue(json.contains("\"task_id\""))

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(AccessumAdminEnvelope.self, from: data)
        XCTAssertEqual(decoded.payload.migrationTrace, record)

        try FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Helpers

    private func prepareTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func makeRunRecord(runId: String) -> AccessumRunRecord {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return AccessumRunRecord(
            runId: runId,
            status: "running",
            contractVersion: AccessumFlow.contractVersion,
            timestamp: timestamp,
            specRef: "fixture",
            specPath: "/tmp/spec.json",
            artifactDir: "/tmp/artifacts",
            inputHash: "abcd",
            specDataHash: "efgh",
            outlineumInputHash: "ijkl",
            pipelineVersions: ["diaplasion": "1.0", "outlineum": "1.0"],
            replayCommand: "accessum-flow --replay \(runId)"
        )
    }

    private func makeStep(
        rewritePath: String = "none",
        verifyStatus: String = "not_run",
        rollbackStatus: String = "not_needed",
        rollbackReason: String? = nil,
        ruleId: String? = nil,
        diffArtifactPath: String? = nil,
        backupPath: String? = nil,
        startedAt: String? = nil,
        finishedAt: String? = nil
    ) -> AccessumStep {
        AccessumStep(
            name: "test-step",
            command: "test",
            status: "ok",
            exitCode: 0,
            durationMs: 1,
            artifacts: [:],
            hashes: [:],
            detail: "detail",
            rewritePath: rewritePath,
            verifyStatus: verifyStatus,
            rollbackStatus: rollbackStatus,
            rollbackReason: rollbackReason,
            ruleId: ruleId,
            diffArtifactPath: diffArtifactPath,
            backupPath: backupPath,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }

    private func makeTrace(runId: String, steps: [AccessumStep]) -> AccessumTrace {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return AccessumTrace(
            contractVersion: AccessumFlow.contractVersion,
            status: "ok",
            timestamp: timestamp,
            command: "test",
            payload: AccessumPayload(
                runId: runId,
                specRef: "fixture",
                specPath: "/tmp/spec.json",
                artifactDir: "/tmp/artifacts",
                inputs: AccessumInputs(
                    inputHash: "hash",
                    specDataHash: "spec",
                    files: []
                ),
                steps: steps,
                replay: AccessumReplay(supported: false, command: "")
            ),
            governanceTrace: [],
            metrics: AccessumMetrics(totalDurationMs: 1, stepCount: steps.count)
        )
    }
}
