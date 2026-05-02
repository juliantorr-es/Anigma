//
//  TextChunkingWorker.swift
//  AnigmaDaemonCore
//
//  Worker for the TextChunkingCapsule.
//

import AnigmaPrimitives
import Foundation
import TextChunkingCapsule

public struct TextChunkingWorker: JobWorker {
    public static let kind = "capsule.text_chunking"

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

        // Decode config or use default
        let chunkingConfig: TextChunkingConfig
        if !config.isEmpty {
            // Assuming config is JSON encoded TextChunkingConfig
             if let decoded = try? JSONDecoder().decode(TextChunkingConfig.self, from: config) {
                  chunkingConfig = decoded
              } else {
                  chunkingConfig = TextChunkingConfig()
              }
        } else {
            chunkingConfig = TextChunkingConfig()
        }

        let wrapper = try TextChunkingCapsuleWrapper(config: chunkingConfig)
        try wrapper.processBytes(payload)
        try wrapper.finalize()
        
        let chunks = try await wrapper.extractChunks(from: payload)
        
        return chunks.enumerated().map { index, chunkData in
            JobOutputPayload(
                data: chunkData,
                mediaType: "text/plain", // Assuming input is text, chunks are text
                kind: "chunk"
            )
        }
    }
}
