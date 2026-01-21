//
//  EmbeddingComputing.swift
//  ContractsCore
//
//  Contract definition for EmbeddingComputing in ContractsCore.
//

import Foundation

/// Port for embedding computation; implementations live in capability modules.
public protocol EmbeddingComputing: Sendable {
    func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> EmbeddingResult
}

/// Result of an embedding computation.
public struct EmbeddingResult: Sendable, Codable, Equatable {
    public let modelID: String
    public let modelVersion: String?
    public let dimension: Int
    public let vectors: [[Double]]
    public let inputHashes: [String]

    public init(modelID: String, modelVersion: String?, dimension: Int, vectors: [[Double]], inputHashes: [String]) {
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.dimension = dimension
        self.vectors = vectors
        self.inputHashes = inputHashes
    }
}

extension EmbeddingComputing {
    public static var capabilityId: String { "anigma.capability.embedding.compute" }
}
