//
//  MemoryTypes.swift
//  AnigmaFoundation
//
//  Core memory storage types and protocols moved from HarmoniaCore to resolve
//  layering issues and allow Tier 2 adapters to implement them.
//

import Foundation
import AnigmaPrimitives
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts

// MARK: - Memory Storage Protocols

/// Protocol for memory storage operations.
/// Implementations are provided by runtime adapters that enforce governance.
public protocol MemoryStore: Actor {
    /// Store a memory record.
    /// - Returns: Unique identifier for the stored record
    func store(content: String, metadata: [String: String], embedding: [Float]?) async throws -> String

    /// Retrieve memory records matching criteria.
    func retrieve(sessionId: String?, tenantId: String?, limit: Int) async throws -> [StoredMemoryRecord]

    /// Perform vector similarity search scoped to a project.
    /// - Parameters:
    ///   - embedding: Query embedding vector
    ///   - projectId: Project scope for search
    ///   - limit: Maximum number of results
    ///   - threshold: Minimum similarity score (0.0 to 1.0), optional
    ///   - scanLimit: Maximum number of rows to scan (O(n) safety limit), optional
    /// - Returns: Results sorted by similarity descending, then id ascending (stable tie-break)
    /// - Throws: MemoryStoreError.embeddingDimensionMismatch if stored embeddings have different dimensions
    func searchSimilar(embedding: [Float], embeddingModel: String?, projectId: String, limit: Int, threshold: Float?, scanLimit: Int?) async throws -> [SimilarMemoryResult]
}

/// A stored memory record returned from retrieval operations.
public struct StoredMemoryRecord: Sendable, Codable {
    public let id: String
    public let content: String
    public let metadata: [String: String]
    public let embedding: [Float]?
    public let embeddingModel: String?
    public let createdAt: Date

    public init(id: String, content: String, metadata: [String: String], embedding: [Float]?, embeddingModel: String? = nil, createdAt: Date) {
        self.id = id
        self.content = content
        self.metadata = metadata
        self.embedding = embedding
        self.embeddingModel = embeddingModel
        self.createdAt = createdAt
    }
}

/// Result from vector similarity search.
public struct SimilarMemoryResult: Sendable, Codable {
    public let record: StoredMemoryRecord
    public let similarity: Float
    public let rank: Int

    // Provenance Metadata
    public let vectorRank: Int?
    public let ftsRank: Float?
    public let rrfScore: Float?
    public let tags: Set<String>

    public init(
        record: StoredMemoryRecord,
        similarity: Float,
        rank: Int,
        vectorRank: Int? = nil,
        ftsRank: Float? = nil,
        rrfScore: Float? = nil,
        tags: Set<String> = []
    ) {
        self.record = record
        self.similarity = similarity
        self.rank = rank
        self.vectorRank = vectorRank
        self.ftsRank = ftsRank
        self.rrfScore = rrfScore
        self.tags = tags
    }
}

// MARK: - Memory Store Errors

/// Errors related to memory storage operations.
public enum MemoryStoreError: Error, LocalizedError, Sendable {
    case storageFailure(String)
    case notFound(String)
    case embeddingDimensionMismatch(String)
    case embeddingModelMismatch(String)
    case unauthorized(String)
    case invalidArgument(String)
    case invalidConfiguration(String)
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .storageFailure(let msg): return "Storage Failure: \(msg)"
        case .notFound(let msg): return "Not Found: \(msg)"
        case .embeddingDimensionMismatch(let msg): return "Embedding Dimension Mismatch: \(msg)"
        case .embeddingModelMismatch(let msg): return "Embedding Model Mismatch: \(msg)"
        case .unauthorized(let msg): return "Unauthorized: \(msg)"
        case .invalidArgument(let msg): return "Invalid Argument: \(msg)"
        case .invalidConfiguration(let msg): return "Invalid Configuration: \(msg)"
        case .notImplemented(let msg): return "Not Implemented: \(msg)"
        }
    }
}

/// Compatibility alias for legacy Harmonia code.
public typealias HarmoniaError = MemoryStoreError

// MARK: - Data Quality Conformance

extension StoredMemoryRecord: DataQualityInspectable {
    public var dataProductKind: DataProductKind { .memory }

    public var dataProductIdentifier: String { id }

    public var dataProductCreatedAt: Date { createdAt }

    public var dataProductUpdatedAt: Date? { nil }

    public var dataProductLineage: DataProductLineage? {
        guard let source = metadata["source"] ?? metadata["sourceId"] ?? metadata["memoryType"] else {
            return nil
        }

        return DataProductLineage(
            sourceArtifactID: source,
            sourceArtifactHash: metadata["sourceHash"] ?? metadata["artifactHash"] ?? metadata["contentHash"],
            transformName: "memory-store",
            transformVersion: metadata["memoryType"] ?? metadata["contentType"],
            modelVersion: embeddingModel ?? metadata["embeddingModel"],
            toolVersion: nil,
            derivedRecordID: id,
            createdAt: createdAt
        )
    }

    public var dataProductPayloadReferences: [String] {
        [
            metadata["source"],
            metadata["sourceId"],
            metadata["projectId"],
            metadata["sessionId"],
            metadata["sourceHash"]
        ].compactMap { $0 }
    }

    public var dataProductSummaryFingerprint: String? {
        content
    }

    public var dataProductEmbeddingModel: String? {
        embeddingModel
    }

    public var dataProductEmbeddingGeneratedAt: Date? {
        embedding == nil ? nil : createdAt
    }

    public var dataProductSourceFidelity: Double? { nil }

    public var dataProductHandoffState: String? { nil }
}
