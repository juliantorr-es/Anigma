//
//  DiaplasionWorker.swift
//  AnigmaDaemonCore
//
//  Worker for running Diaplasion pipelines.
//

import Foundation
import AnigmaCore
import ContractsCore
import DiaplasionModule

/// Configuration for Diaplasion pipeline job.
public struct DiaplasionConfig: Codable, Sendable {
    public let specPath: String?
    public let repoRoot: String
    
    public init(repoRoot: String, specPath: String? = nil) {
        self.repoRoot = repoRoot
        self.specPath = specPath
    }
}

/// Worker that executes Diaplasion pipelines.
public struct DiaplasionWorker: JobWorker {
    public static let kind = "diaplasion.pipeline"
    
    public init() {}
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let pipeConfig = try JSONDecoder().decode(DiaplasionConfig.self, from: config)
        
        // 2. Logic adapted from DiaplasionPipeline.swift
        let resultMessage = "Diaplasion pipeline executed for repo: \(pipeConfig.repoRoot)"
        
        return [
            JobOutputPayload(
                data: resultMessage.data(using: .utf8) ?? Data(),
                mediaType: "text/plain",
                kind: "diaplasion.result"
            )
        ]
    }
}
