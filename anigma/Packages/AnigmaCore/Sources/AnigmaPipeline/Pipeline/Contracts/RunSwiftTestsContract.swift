//
//  RunSwiftTestsContract.swift
//  AnigmaCore
//
//  Contract definition for RunSwiftTestsContract in AnigmaCore.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import FoundationContracts
import EvidenceContracts
import Foundation

/// Input describing a governed Swift test execution.
public struct TestRunInput: Codable, Sendable {
    public let packagePath: String
    public let testTargets: [String]
    public let filter: String?
    public let environment: [String: String]
    public let commitHash: String
    public let isDirty: Bool

    public init(
        packagePath: String,
        testTargets: [String],
        filter: String? = nil,
        environment: [String: String] = [:],
        commitHash: String,
        isDirty: Bool
    ) {
        self.packagePath = packagePath
        self.testTargets = testTargets
        self.filter = filter
        self.environment = environment
        self.commitHash = commitHash
        self.isDirty = isDirty
    }
}

/// Output from a governed Swift test execution.
public struct TestRunResult: Codable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let durationMs: Int64
    public let commitHash: String
    public let isDirty: Bool

    public init(exitCode: Int32, stdout: String, stderr: String, durationMs: Int64, commitHash: String, isDirty: Bool) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.durationMs = durationMs
        self.commitHash = commitHash
        self.isDirty = isDirty
    }
}

/// Contract that executes Swift tests via a governed test runner.
public enum RunSwiftTestsContract: ContractSpec {
    public static let id = ContractID(name: "pipeline.test.swift", major: 1, minor: 0, schemaHash: "v1.0")
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1

    public static func validate(output: ArtifactEnvelope<TestRunResult>) throws {
        guard !output.payload.stdout.isEmpty || !output.payload.stderr.isEmpty else {
            throw ContractValidationError.missingField(
                code: "test.output.empty",
                message: "Test output is empty"
            )
        }
        guard !output.payload.commitHash.isEmpty else {
            throw ContractValidationError.missingField(
                code: "test.commit.empty",
                message: "Commit hash is required for test attestation"
            )
        }
        guard output.payload.exitCode == 0 else {
            throw ContractValidationError.invalidSchema(
                code: "test.exit_code",
                message: "Test run exited with code \(output.payload.exitCode)"
            )
        }
    }

    public static func execute(
        input: ArtifactEnvelope<TestRunInput>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<TestRunResult> {
        guard let runner = ctx.testRunner else {
            throw ContractExecutionError.deniedToolAccess(
                code: "test.runner.unavailable",
                message: "No governed test runner provided"
            )
        }

        let request = TestCommandRequest(
            packagePath: input.payload.packagePath,
            testTargets: input.payload.testTargets,
            filter: input.payload.filter,
            environment: input.payload.environment
        )
        let result = try await runner.runTests(request)

        if !result.commitHash.isEmpty && result.commitHash != input.payload.commitHash {
            throw ContractExecutionError.underlying(
                code: "test.commit.mismatch",
                message: "Test runner commit \(result.commitHash) != input commit \(input.payload.commitHash)"
            )
        }
        let resolvedCommit = result.commitHash.isEmpty ? input.payload.commitHash : result.commitHash
        let resolvedDirty = result.commitHash.isEmpty ? input.payload.isDirty : result.isDirty

        let metrics = ExecutionMetrics(
            wallTimeMs: result.durationMs,
            toolCallCount: 1,
            retryCount: 0,
            executor: ctx.executorIdentity,
            cacheHit: false
        )

        let receipt = ContractReceipt.placeholder(
            contractID: Self.id,
            runID: ctx.runID,
            sessionID: ctx.sessionID,
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: metrics
        )

        let output = TestRunResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            durationMs: result.durationMs,
            commitHash: resolvedCommit,
            isDirty: resolvedDirty
        )

        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: output,
            evidenceRefs: [],
            metrics: metrics,
            receipt: receipt
        )
    }
}
