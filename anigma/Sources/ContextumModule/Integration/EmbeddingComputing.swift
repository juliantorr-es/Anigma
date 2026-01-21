//
//  EmbeddingComputing.swift
//  ContextumModule
//
//  Protocol for computing embeddings via governed ML execution.
//

import Foundation
import ContractsCore

/// Protocol for computing embeddings through governed ML execution
public protocol EmbeddingComputing: Sendable {
    /// Compute embeddings for a batch of texts
    func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> EmbeddingComputeResult
}

/// Result from embedding computation
public struct EmbeddingComputeResult: Sendable {
    public let vectors: [[Double]]
    public let dimension: Int
    public let inputHashes: [String]

    public init(vectors: [[Double]], dimension: Int, inputHashes: [String]) {
        self.vectors = vectors
        self.dimension = dimension
        self.inputHashes = inputHashes
    }
}

/// Protocol for model registry access
public protocol ModelRegistryProtocol: Sendable {
    /// Find model by ID
    func find(id: String) async throws -> ModelRegistryEntry?

    /// Record usage of a model
    func recordUsage(_ id: String) async throws
}

/// Model registry entry wrapping ModelSpec
public struct ModelRegistryEntry: Sendable {
    public let id: String
    public let spec: ContractsCore.ModelSpec

    public init(id: String, spec: ContractsCore.ModelSpec) {
        self.id = id
        self.spec = spec
    }
}
