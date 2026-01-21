//
//  TestExecutionPort.swift
//  ContractsCore
//
//  Contract definition for TestExecutionPort in ContractsCore.
//

import Foundation

/// Narrow port for executing test commands under governance.
public protocol TestCommandRunning: Sendable {
    func runTests(_ request: TestCommandRequest) async throws -> TestCommandResult
}

/// Request describing a test invocation.
public struct TestCommandRequest: Codable, Sendable {
    public let packagePath: String
    public let testTargets: [String]
    public let filter: String?
    public let environment: [String: String]

    public init(
        packagePath: String,
        testTargets: [String],
        filter: String? = nil,
        environment: [String: String] = [:]
    ) {
        self.packagePath = packagePath
        self.testTargets = testTargets
        self.filter = filter
        self.environment = environment
    }
}

/// Result of a governed test run.
public struct TestCommandResult: Codable, Sendable {
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
