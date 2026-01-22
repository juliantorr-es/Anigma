//
//  SemanticChunkingWorker.swift
//  AnigmaDaemonCore
//
//  Worker for semantic code chunking using Tree-sitter.
//

import AnigmaPrimitives
import AnigmaCore
import Foundation
import SwiftTreeSitter

public struct SemanticChunkingWorker: JobWorker {
    public static let kind = "code.semantic_chunking"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        guard let input = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let payload = vaultData[input.hash] else {
            throw WorkerError.missingInputData(hash: input.hash)
        }
        guard let sourceCode = String(data: payload, encoding: .utf8) else {
            throw WorkerError.executionFailed("Input artifact is not valid UTF-8 text")
        }

        // Decode config
        let chunkingConfig: SemanticChunkingConfig
        if !config.isEmpty {
             if let decoded = try? JSONDecoder().decode(SemanticChunkingConfig.self, from: config) {
                 chunkingConfig = decoded
             } else {
                 chunkingConfig = .default
             }
        } else {
            chunkingConfig = .default
        }
        
        // Use shared CodeChunker
        let chunks = CodeChunker.heuristicChunking(sourceCode: sourceCode, config: chunkingConfig)
        
        return chunks.enumerated().map { index, chunk in
            let chunkData = chunk.content.data(using: .utf8) ?? Data()
            return JobOutputPayload(
                data: chunkData,
                mediaType: "text/plain",
                kind: "chunk.semantic"
            )
        }
    }
}
