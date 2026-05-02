//
//  AccessumWorker.swift
//  AnigmaDaemonCore
//
//  Worker for orchestrating Accessum flows (Diaplasion + Outlineum + Harmonia).
//

import Foundation
import AnigmaCore
import ContractsCore
import DiaplasionModule
import OutlineumModule
import HarmoniaV2Surface

/// Configuration for Accessum flow job.
public struct AccessumConfig: Codable, Sendable {
    public let specPath: String?
    public let repoRoot: String
    
    public init(repoRoot: String, specPath: String? = nil) {
        self.repoRoot = repoRoot
        self.specPath = specPath
    }
}

/// Worker that executes Accessum flows.
public struct AccessumWorker: JobWorker {
    public static let kind = "accessum.flow"
    
    public init() {}
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let flowConfig = try JSONDecoder().decode(AccessumConfig.self, from: config)
        
        // 2. Logic adapted from AccessumFlow/main.swift
        // Note: This surface is intentionally fail-closed until orchestration is integrated.
        // STUB_TRACK: daemon-accessum-orchestration – Accessum flow orchestration not implemented
        logWarning("STUB INVOKED: AccessumWorker.executeAccessumFlow()", category: "AccessumWorker")
        logWarning("Accessum flow orchestration unavailable - failing closed", category: "AccessumWorker")
        throw WorkerError.executionFailed(
            "Accessum orchestration unavailable for repoRoot=\(flowConfig.repoRoot); disposition=fail_closed"
        )
    }
}
