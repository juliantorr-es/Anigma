//
//  EmbeddingIntegration.swift
//  HarmoniaModule
//
//  Vector similarity search with hybrid keyword+semantic matching and result fusion.
//

import Foundation
import HarmoniaCore
import InferenceCore
import AnigmaPrimitives
import AnigmaCore
import DatabaseCore
@preconcurrency import Foundation

/// Embedding model interface
public protocol SearchEmbeddingModel: Sendable {
    func generateEmbedding(for text: String) async throws -> [Float]
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double
}

/// Vector search result
public struct EmbeddingVectorSearchResult: Sendable, Codable {
    /// Content identifier
    public let contentId: String

    /// Content preview
    public let preview: String

    /// Vector similarity score
    public let vectorSimilarity: Double

    /// Combined relevance score
    public let combinedScore: Double

    public init(
        contentId: String,
        preview: String,
        vectorSimilarity: Double,
        combinedScore: Double
    ) {
        self.contentId = contentId
        self.preview = preview
        self.vectorSimilarity = vectorSimilarity
        self.combinedScore = combinedScore
    }
}

/// Hybrid search result
public struct HybridSearchResult: Sendable, Codable {
    /// Keyword matching score
    public let keywordScore: Double

    /// Vector similarity score
    public let vectorScore: Double

    /// Combined score (fusion)
    public let combinedScore: Double

    /// Ranking position
    public let rank: Int

    /// Result content
    public let contentId: String
    public let preview: String

    public init(
        keywordScore: Double,
        vectorScore: Double,
        combinedScore: Double,
        rank: Int,
        contentId: String,
        preview: String
    ) {
        self.keywordScore = keywordScore
        self.vectorScore = vectorScore
        self.combinedScore = combinedScore
        self.rank = rank
        self.contentId = contentId
        self.preview = preview
    }
}

/// Embedding with metadata
public struct ContentEmbedding: Sendable, Codable {
    public let contentId: String
    public let embedding: [Float]
    public let createdAt: Date
    public let embeddingModel: String
    public let contentHash: String

    public init(
        contentId: String,
        embedding: [Float],
        createdAt: Date,
        embeddingModel: String,
        contentHash: String
    ) {
        self.contentId = contentId
        self.embedding = embedding
        self.createdAt = createdAt
        self.embeddingModel = embeddingModel
        self.contentHash = contentHash
    }
}

/// Hybrid keyword + semantic search
public actor EmbeddingIntegration {
    private let dbActor: (any DatabaseAuthority)?
    private let embeddingModel: SearchEmbeddingModel?
    private var schemaInitialized = false

    public init(
        dbActor: (any DatabaseAuthority)? = nil,
        embeddingModel: SearchEmbeddingModel? = nil
    ) {
        self.dbActor = dbActor
        self.embeddingModel = embeddingModel
    }

    /// Store embedding for content
    public func storeEmbedding(
        contentId: String,
        content: String,
        modelName: String = "default"
    ) async throws {
        try await ensureSchema()
        guard let model = embeddingModel, let db = dbActor else { return }

        let embedding = try await model.generateEmbedding(for: content)
        let contentHash = computeHash(content)
        let timestamp = Int(Date().timeIntervalSince1970)

        let embeddingData = try JSONSerialization.data(withJSONObject: embedding)
        let embeddingJson = String(data: embeddingData, encoding: .utf8) ?? "[]"

        try await db.execute(
            """
            INSERT OR REPLACE INTO content_embeddings (id, content_id, embedding, created_at, model, content_hash)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                DatabaseCore.DatabaseParameter.text(UUID().uuidString),
                DatabaseCore.DatabaseParameter.text(contentId),
                DatabaseCore.DatabaseParameter.text(embeddingJson),
                DatabaseCore.DatabaseParameter.int(timestamp),
                DatabaseCore.DatabaseParameter.text(modelName),
                DatabaseCore.DatabaseParameter.text(contentHash)
            ]
        )
    }

    /// Vector similarity search
    public func vectorSearch(
        query: String,
        limit: Int = 20
    ) async throws -> [EmbeddingVectorSearchResult] {
        try await ensureSchema()
        guard let model = embeddingModel, let db = dbActor else { return [] }

        let queryEmbedding = try await model.generateEmbedding(for: query)

        let rows = try await db.query(
            """
            SELECT id, content_id, embedding FROM content_embeddings LIMIT ?
            """,
            parameters: [DatabaseCore.DatabaseParameter.int(limit * 5)]  // Get more to filter
        )

        var results: [(id: String, similarity: Double)] = []

        for row in rows {
            guard let contentId = row.string(for: "content_id"),
                  let embeddingJson = row.string(for: "embedding") else {
                continue
            }

            if let embeddingData = embeddingJson.data(using: .utf8),
               let embeddingArray = try? JSONSerialization.jsonObject(with: embeddingData) as? [NSNumber] {
                let embedding = embeddingArray.map { Float($0.doubleValue) }
                let similarity = model.cosineSimilarity(queryEmbedding, embedding)
                results.append((id: contentId, similarity: similarity))
            }
        }

        // Sort by similarity and create results
        results.sort { $0.similarity > $1.similarity }

        return results.prefix(limit).enumerated().map { _, result in
            EmbeddingVectorSearchResult(
                contentId: result.id,
                preview: "Content ID: \(result.id)",
                vectorSimilarity: result.similarity,
                combinedScore: result.similarity
            )
        }
    }

    /// Hybrid keyword + vector search
    public func hybridSearch(
        query: String,
        keywordResults: [String],  // Content IDs from keyword search
        limit: Int = 20
    ) async throws -> [HybridSearchResult] {
        try await ensureSchema()
        guard let model = embeddingModel else {
            // Fallback to keyword-only results
            return keywordResults.prefix(limit).enumerated().map { index, contentId in
                HybridSearchResult(
                    keywordScore: 1.0,
                    vectorScore: 0.0,
                    combinedScore: 1.0,
                    rank: index + 1,
                    contentId: contentId,
                    preview: "Content ID: \(contentId)"
                )
            }
        }

        // Get embeddings for keyword results
        let queryEmbedding = try await model.generateEmbedding(for: query)
        var hybridResults: [HybridSearchResult] = []

        guard let db = dbActor else { return [] }

        for contentId in keywordResults {
            let rows = try await db.query(
                """
                SELECT embedding FROM content_embeddings WHERE content_id = ? LIMIT 1
                """,
                parameters: [DatabaseCore.DatabaseParameter.text(contentId)]
            )

            if let row = rows.first,
               let embeddingJson = row.string(for: "embedding"),
               let embeddingData = embeddingJson.data(using: .utf8),
               let embeddingArray = try? JSONSerialization.jsonObject(with: embeddingData) as? [NSNumber] {
                let embedding = embeddingArray.map { Float($0.doubleValue) }
                let vectorScore = model.cosineSimilarity(queryEmbedding, embedding)
                let keywordScore = 1.0  // Already keyword-matched
                let combinedScore = (keywordScore * 0.4) + (vectorScore * 0.6)

                hybridResults.append(HybridSearchResult(
                    keywordScore: keywordScore,
                    vectorScore: vectorScore,
                    combinedScore: combinedScore,
                    rank: hybridResults.count + 1,
                    contentId: contentId,
                    preview: "Content ID: \(contentId)"
                ))
            }
        }

        // Sort by combined score
        hybridResults.sort { $0.combinedScore > $1.combinedScore }

        // Update ranks
        return hybridResults.prefix(limit).enumerated().map { index, result in
            HybridSearchResult(
                keywordScore: result.keywordScore,
                vectorScore: result.vectorScore,
                combinedScore: result.combinedScore,
                rank: index + 1,
                contentId: result.contentId,
                preview: result.preview
            )
        }
    }

    /// Update embeddings for changed content
    public func updateEmbedding(
        contentId: String,
        newContent: String
    ) async throws {
        try await ensureSchema()
        guard let db = dbActor else { return }

        // Delete old embedding
        try await db.execute(
            """
            DELETE FROM content_embeddings WHERE content_id = ?
            """,
            parameters: [DatabaseCore.DatabaseParameter.text(contentId)]
        )

        // Store new embedding
        try await storeEmbedding(contentId: contentId, content: newContent)
    }

    /// Get embedding statistics
    public func getEmbeddingStats() async throws -> EmbeddingStats {
        try await ensureSchema()
        guard let db = dbActor else {
            return EmbeddingStats(
                totalEmbeddings: 0,
                modelDistribution: [:],
                averageEmbeddingSize: 0,
                oldestEmbedding: nil,
                newestEmbedding: nil
            )
        }

        let rows = try await db.query(
            """
            SELECT COUNT(*) as count, model, MIN(created_at) as oldest, MAX(created_at) as newest
            FROM content_embeddings
            GROUP BY model
            """
        )

        var totalCount = 0
        var modelDist: [String: Int] = [:]
        var oldest: Date?
        var newest: Date?

        for row in rows {
            if let count = row.int(for: "count"),
               let model = row.string(for: "model") {
                modelDist[model] = count
                totalCount += count

                if let oldestInt = row.int(for: "oldest") {
                    let date = Date(timeIntervalSince1970: TimeInterval(oldestInt))
                    if oldest == nil || date < oldest! {
                        oldest = date
                    }
                }

                if let newestInt = row.int(for: "newest") {
                    let date = Date(timeIntervalSince1970: TimeInterval(newestInt))
                    if newest == nil || date > newest! {
                        newest = date
                    }
                }
            }
        }

        return EmbeddingStats(
            totalEmbeddings: totalCount,
            modelDistribution: modelDist,
            averageEmbeddingSize: 384,  // Typical embedding size
            oldestEmbedding: oldest,
            newestEmbedding: newest
        )
    }

    /// Compute simple hash
    private func computeHash(_ content: String) -> String {
        let bytes = content.utf8.map { UInt8($0) }
        var hash: UInt32 = 5381
        for byte in bytes {
            hash = ((hash << 5) &+ hash) &+ UInt32(byte)
        }
        return String(format: "%08x", hash)
    }

    private func ensureSchema() async throws {
        guard let db = dbActor else { return }
        if !schemaInitialized {
            try await SearchSchema.apply(using: db)
            schemaInitialized = true
        }
    }
}

/// Embedding statistics
public struct EmbeddingStats: Sendable, Codable {
    public let totalEmbeddings: Int
    public let modelDistribution: [String: Int]
    public let averageEmbeddingSize: Int
    public let oldestEmbedding: Date?
    public let newestEmbedding: Date?

    public init(
        totalEmbeddings: Int,
        modelDistribution: [String: Int],
        averageEmbeddingSize: Int,
        oldestEmbedding: Date?,
        newestEmbedding: Date?
    ) {
        self.totalEmbeddings = totalEmbeddings
        self.modelDistribution = modelDistribution
        self.averageEmbeddingSize = averageEmbeddingSize
        self.oldestEmbedding = oldestEmbedding
        self.newestEmbedding = newestEmbedding
    }
}

/// Placeholder embedding model for testing
public struct DefaultEmbeddingModel: SearchEmbeddingModel {
    public init() {}

    public func generateEmbedding(for text: String) async throws -> [Float] {
        // Placeholder: generate deterministic embedding based on text
        let hash = text.utf8.reduce(0) { ($0 << 5) &+ $0 &+ UInt32($1) }
        var embedding: [Float] = []
        var seed = hash
        for _ in 0..<384 {
            seed = (seed &* 1103515245) &+ 12345
            embedding.append(Float(Int32(bitPattern: (seed >> 16) & 0x7fff)) / 32768.0)
        }
        return embedding
    }

    public func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        guard normA > 0 && normB > 0 else { return 0 }

        let denominator = sqrt(normA) * sqrt(normB)
        return Double(dotProduct / denominator)
    }
}
