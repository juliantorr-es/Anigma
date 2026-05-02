//
//  BufferEmbeddingCapability.swift
//  ContractsCore
//
//  Buffer-backed embedding capability for Metal/MPS integration.
//  Following "Swift governs, compute computes": tokenization happens in Swift,
//  embedding computation happens in accelerated backends via this protocol.
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import AnigmaPrimitives
import Foundation

/// Buffer-backed embedding capability for efficient compute backend integration.
/// This protocol separates tokenization (governed Swift) from embedding computation
/// (accelerated backends: CoreML, MPS, Metal).
public protocol BufferEmbeddingCapability: Sendable {
    /// Compute embeddings from token buffers.
    /// - Parameters:
    ///   - modelID: Identifier for the embedding model (e.g., "MiniLM-L6-v2").
    ///   - modelVersion: Optional model version string.
    ///   - tokenBuffers: Array of token buffers to embed.
    ///   - normalize: Whether to L2-normalize output vectors.
    /// - Returns: Array of embedding vectors (Float for GPU efficiency).
    /// - Throws: Errors if computation fails.
    func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        tokenBuffers: [TokenBuffer],
        normalize: Bool
    ) async throws -> [[Float]]

    /// Get embedding dimension for a given model.
    /// - Parameters:
    ///   - modelID: Identifier for the embedding model.
    ///   - modelVersion: Optional model version string.
    /// - Returns: Embedding dimension (vector length).
    /// - Throws: Errors if model is unknown.
    func embeddingDimension(
        modelID: String,
        modelVersion: String?
    ) async throws -> Int

    /// Check if a model is supported by this capability.
    /// - Parameters:
    ///   - modelID: Identifier for the embedding model.
    ///   - modelVersion: Optional model version string.
    /// - Returns: True if the model can be computed.
    func supportsModel(
        modelID: String,
        modelVersion: String?
    ) async -> Bool
}

/// Result of buffer-based embedding computation with provenance.
public struct BufferEmbeddingResult: Sendable, Codable, Equatable {
    /// Model identifier.
    public let modelID: String
    /// Model version string (optional).
    public let modelVersion: String?
    /// Embedding dimension (vector length).
    public let dimension: Int
    /// Embedding vectors (Float for GPU/Neural Engine efficiency).
    public let vectors: [[Float]]
    /// Hashes of input token buffers for provenance.
    public let tokenBufferHashes: [String]
    /// Whether vectors are L2-normalized.
    public let normalized: Bool

    public init(
        modelID: String,
        modelVersion: String?,
        dimension: Int,
        vectors: [[Float]],
        tokenBufferHashes: [String],
        normalized: Bool
    ) {
        self.modelID = modelID
        self.modelVersion = modelVersion
        self.dimension = dimension
        self.vectors = vectors
        self.tokenBufferHashes = tokenBufferHashes
        self.normalized = normalized
    }
}

extension BufferEmbeddingCapability {
    /// Default implementation of supportsModel that checks embedding dimension.
    public func supportsModel(
        modelID: String,
        modelVersion: String?
    ) async -> Bool {
        do {
            _ = try await embeddingDimension(modelID: modelID, modelVersion: modelVersion)
            return true
        } catch {
            return false
    }
}

    /// Compute embeddings and return structured result with provenance.
    public func computeEmbeddingsWithProvenance(
        modelID: String,
        modelVersion: String?,
        tokenBuffers: [TokenBuffer],
        normalize: Bool
    ) async throws -> BufferEmbeddingResult {
        let dimension: Int = try await embeddingDimension(modelID: modelID, modelVersion: modelVersion)
        let vectors: [[Float]] = try await computeEmbeddings(
            modelID: modelID,
            modelVersion: modelVersion,
            tokenBuffers: tokenBuffers,
            normalize: normalize
        )

        // Compute hashes of token buffers for provenance
        let hashes: [String] = tokenBuffers.map { buffer in
            // Simple hash for now; could be enhanced with canonical JSON serialization
            var hasher: Hasher = Hasher()
            hasher.combine(buffer.tokenIds)
            hasher.combine(buffer.attentionMask)
            if let tokenTypeIds = buffer.tokenTypeIds {
                hasher.combine(tokenTypeIds)
            }
            return "\(hasher.finalize())"
        }

        return BufferEmbeddingResult(
            modelID: modelID,
            modelVersion: modelVersion,
            dimension: dimension,
            vectors: vectors,
            tokenBufferHashes: hashes,
            normalized: normalize
        )
    }
}

extension BufferEmbeddingCapability {
    public static var capabilityId: String { "anigma.capability.embedding.buffer" }
}
