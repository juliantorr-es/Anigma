//
//  MigrationTraceSink.swift
//  AnigmaPrimitives
//
//  [Brief description of file purpose]
//

import Foundation

/// Represents the outcome of a migration step rewrite for tracing.
public struct MigrationStepOutcome: Sendable {
    public let taskId: String
    public let rewritePath: String
    public let ruleId: String?
    public let verifyStatus: String
    public let rollbackStatus: String
    public let rollbackReason: String?
    public let backupPath: String?
    public let diffArtifactPath: String?
    public let detail: String?
    public let circuitState: String?

    public init(
        taskId: String,
        rewritePath: String,
        ruleId: String? = nil,
        verifyStatus: String = "not_run",
        rollbackStatus: String = "not_needed",
        rollbackReason: String? = nil,
        backupPath: String? = nil,
        diffArtifactPath: String? = nil,
        detail: String? = nil,
        circuitState: String? = nil
    ) {
        self.taskId = taskId
        self.rewritePath = rewritePath
        self.ruleId = ruleId
        self.verifyStatus = verifyStatus
        self.rollbackStatus = rollbackStatus
        self.rollbackReason = rollbackReason
        self.backupPath = backupPath
        self.diffArtifactPath = diffArtifactPath
        self.detail = detail
        self.circuitState = circuitState
    }
}

/// Sink that consumes migration rewrite outcomes.
public protocol MigrationTraceSink: Sendable {
    func record(_ outcome: MigrationStepOutcome)

    /// Whether trace recording is enabled (true for persistent sink, false for Noop)
    var isEnabled: Bool { get }

    /// Database path if using a persistent sink, nil otherwise
    var dbPath: String? { get }
}

/// A no-op sink useful for tests or contexts without tracing.
public struct NoopMigrationTraceSink: MigrationTraceSink {
    public init() {}

    public let isEnabled: Bool = false
    public let dbPath: String? = nil

    public func record(_ outcome: MigrationStepOutcome) {
        // intentionally no-op
    }
}
