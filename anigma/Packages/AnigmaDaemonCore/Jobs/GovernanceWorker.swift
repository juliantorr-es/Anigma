//
//  GovernanceWorker.swift
//  AnigmaDaemonCore
//
//  Worker for evaluating governance policies on project tasks.
//

import Foundation
import AnigmaCore
import ContractsCore

/// Configuration for governance evaluation job.
public struct GovernanceConfig: Codable, Sendable {
    public let repoRoot: String
    
    public init(repoRoot: String) {
        self.repoRoot = repoRoot
    }
}

/// Worker that evaluates project governance.
public struct GovernanceWorker: JobWorker {
    public static let kind = "project.governance"
    
    public init() {}
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let govConfig = try JSONDecoder().decode(GovernanceConfig.self, from: config)
        
        // 2. Logic placeholder for CI gates
        // Note: This surface is intentionally fail-closed until evaluation integration lands.
        // STUB_TRACK: daemon-governance-evaluation – Governance evaluation not implemented
        logWarning("STUB INVOKED: GovernanceWorker.executeGovernanceJob()", category: "GovernanceWorker")
        logWarning("Governance evaluation unavailable - failing closed", category: "GovernanceWorker")
        throw WorkerError.executionFailed(
            "Governance evaluation unavailable for repoRoot=\(govConfig.repoRoot); disposition=fail_closed"
        )
    }
}
