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
                 chunkingConfig = .default
             }
        } else {
            chunkingConfig = .default
        }

        let wrapper = try TextChunkingCapsuleWrapper(config: chunkingConfig)
        try wrapper.processBytes(payload)
        try wrapper.finalize()
        
        let chunks = try wrapper.extractChunks(from: payload)
        
        return chunks.enumerated().map { index, chunkData in
            JobOutputPayload(
                data: chunkData,
                mediaType: "text/plain", // Assuming input is text, chunks are text
                kind: "chunk"
            )
        }
    }
}

// Helper to make TextChunkingConfig Codable for job config
extension TextChunkingConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case targetChunkSize
        case minChunkSize
        case maxChunkSize
        case windowSize
        case polynomial
        case determinismTier
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let target = try container.decode(Int.self, forKey: .targetChunkSize)
        let min = try container.decode(Int.self, forKey: .minChunkSize)
        let max = try container.decode(Int.self, forKey: .maxChunkSize)
        let window = try container.decode(Int.self, forKey: .windowSize)
        let poly = try container.decode(UInt64.self, forKey: .polynomial)
        let tier = try container.decode(UInt32.self, forKey: .determinismTier)
        
        self.init(
            targetChunkSize: target,
            minChunkSize: min,
            maxChunkSize: max,
            windowSize: window,
            polynomial: poly,
            determinismTier: tier
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(targetChunkSize, forKey: .targetChunkSize)
        try container.encode(minChunkSize, forKey: .minChunkSize)
        try container.encode(maxChunkSize, forKey: .maxChunkSize)
        try container.encode(windowSize, forKey: .windowSize)
        try container.encode(polynomial, forKey: .polynomial)
        try container.encode(determinismTier, forKey: .determinismTier)
    }
}
