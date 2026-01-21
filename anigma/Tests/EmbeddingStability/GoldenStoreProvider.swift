//
//  GoldenStoreProvider.swift
//  EmbeddingStability
//
//  Provides precomputed embeddings and similarity scores for validation.
//

import Foundation

/// Embedding vector representation
public struct EmbeddingVector: Sendable, Codable {
    public let id: String
    public let vector: [Double]
    public let text: String?
    
    public init(id: String, vector: [Double], text: String? = nil) {
        self.id = id
        self.vector = vector
        self.text = text
    }
}

/// Similarity score between a query and a document
public struct SimilarityScore: Sendable, Codable {
    public let queryId: String
    public let documentId: String
    public let score: Double
    
    public init(queryId: String, documentId: String, score: Double) {
        self.queryId = queryId
        self.documentId = documentId
        self.score = Double(score)
    }
}

/// Ranking result for a query (top-k documents)
public struct QueryRanking: Sendable, Codable {
    public let queryId: String
    public let rankedDocuments: [(documentId: String, score: Double)]
    
    public init(queryId: String, rankedDocuments: [(documentId: String, score: Double)]) {
        self.queryId = queryId
        self.rankedDocuments = rankedDocuments
    }
}

/// Protocol for accessing golden store data
public protocol GoldenStoreProvider {
    /// Returns all document embeddings in the store
    func documentEmbeddings() throws -> [EmbeddingVector]
    
    /// Returns all query embeddings in the store
    func queryEmbeddings() throws -> [EmbeddingVector]
    
    /// Returns precomputed similarity scores for all query-document pairs
    func similarityScores() throws -> [SimilarityScore]
    
    /// Returns precomputed rankings (top-k) for each query
    func queryRankings() throws -> [QueryRanking]
    
    /// Returns the embedding dimension expected by this store
    var embeddingDimension: Int { get }
    
    /// Returns the model identifier used to generate these embeddings
    var modelIdentifier: String { get }
}

/// In-memory implementation of GoldenStoreProvider for testing
public final class InMemoryGoldenStoreProvider: GoldenStoreProvider {
    private let documents: [EmbeddingVector]
    private let queries: [EmbeddingVector]
    private let similarities: [SimilarityScore]
    private let rankings: [QueryRanking]
    private let dimension: Int
    private let modelId: String
    
    public init(
        documents: [EmbeddingVector],
        queries: [EmbeddingVector],
        similarities: [SimilarityScore],
        rankings: [QueryRanking],
        dimension: Int,
        modelId: String
    ) {
        self.documents = documents
        self.queries = queries
        self.similarities = similarities
        self.rankings = rankings
        self.dimension = dimension
        self.modelId = modelId
    }
    
    public func documentEmbeddings() throws -> [EmbeddingVector] {
        documents
    }
    
    public func queryEmbeddings() throws -> [EmbeddingVector] {
        queries
    }
    
    public func similarityScores() throws -> [SimilarityScore] {
        similarities
    }
    
    public func queryRankings() throws -> [QueryRanking] {
        rankings
    }
    
    public var embeddingDimension: Int {
        dimension
    }
    
    public var modelIdentifier: String {
        modelId
    }
}

/// Factory for creating golden store providers with different configurations
public enum GoldenStoreFactory {
    /// Creates a minimal store for unit tests (1k docs, 50 queries) with synthetic data
    public static func createUnitTestStore() -> GoldenStoreProvider {
        // Generate synthetic embeddings using deterministic pseudo-randomness
        let dimension = 384 // MiniLM dimension
        let docCount = 1000
        let queryCount = 50
        
        let documents = (0..<docCount).map { i in
            EmbeddingVector(
                id: "doc_\(i)",
                vector: generateRandomVector(dimension: dimension, seed: UInt64(i)),
                text: "Document content \(i)"
            )
        }
        
        let queries = (0..<queryCount).map { i in
            EmbeddingVector(
                id: "query_\(i)",
                vector: generateRandomVector(dimension: dimension, seed: UInt64(1000 + i)),
                text: "Query text \(i)"
            )
        }
        
        // Compute similarities (brute-force, deterministic)
        var similarities: [SimilarityScore] = []
        var rankings: [QueryRanking] = []
        
        for query in queries {
            var scoredDocs: [(String, Double)] = []
            for doc in documents {
                let score = cosineSimilarity(query.vector, doc.vector)
                similarities.append(SimilarityScore(
                    queryId: query.id,
                    documentId: doc.id,
                    score: score
                ))
                scoredDocs.append((doc.id, score))
            }
            // Sort descending by score
            scoredDocs.sort { $0.1 > $1.1 }
            // Take top 20
            let topK = min(20, scoredDocs.count)
            rankings.append(QueryRanking(
                queryId: query.id,
                rankedDocuments: Array(scoredDocs.prefix(topK))
            ))
        }
        
        return InMemoryGoldenStoreProvider(
            documents: documents,
            queries: queries,
            similarities: similarities,
            rankings: rankings,
            dimension: dimension,
            modelId: "sentence-transformers/all-MiniLM-L6-v2"
        )
    }
    
    /// Creates a comprehensive store for integration tests (10k docs, 200 queries) with synthetic data
    public static func createIntegrationTestStore() -> GoldenStoreProvider {
        // Similar to unit test but larger scale
        let dimension = 384
        let docCount = 10_000
        let queryCount = 200
        
        let documents = (0..<docCount).map { i in
            EmbeddingVector(
                id: "doc_\(i)",
                vector: generateRandomVector(dimension: dimension, seed: UInt64(i)),
                text: "Document content \(i)"
            )
        }
        
        let queries = (0..<queryCount).map { i in
            EmbeddingVector(
                id: "query_\(i)",
                vector: generateRandomVector(dimension: dimension, seed: UInt64(100000 + i)),
                text: "Query text \(i)"
            )
        }
        
        // For integration tests, we might not want to compute all pairwise similarities
        // Instead compute only top-k similarities using approximate method
        // For now, we'll compute a subset to keep memory reasonable
        var similarities: [SimilarityScore] = []
        var rankings: [QueryRanking] = []
        
        for query in queries.prefix(50) { // Limit to 50 queries for similarity storage
            var scoredDocs: [(String, Double)] = []
            for doc in documents.prefix(2000) { // Limit to 2000 docs
                let score = cosineSimilarity(query.vector, doc.vector)
                similarities.append(SimilarityScore(
                    queryId: query.id,
                    documentId: doc.id,
                    score: score
                ))
                scoredDocs.append((doc.id, score))
            }
            scoredDocs.sort { $0.1 > $1.1 }
            let topK = min(20, scoredDocs.count)
            rankings.append(QueryRanking(
                queryId: query.id,
                rankedDocuments: Array(scoredDocs.prefix(topK))
            ))
        }
        
        // Add remaining queries with empty rankings (placeholder)
        for query in queries.dropFirst(50) {
            rankings.append(QueryRanking(
                queryId: query.id,
                rankedDocuments: []
            ))
        }
        
        return InMemoryGoldenStoreProvider(
            documents: documents,
            queries: queries,
            similarities: similarities,
            rankings: rankings,
            dimension: dimension,
            modelId: "sentence-transformers/all-MiniLM-L6-v2"
        )
    }
    
    /// Creates a store from precomputed embeddings stored in JSON files (future extension)
    public static func createFromJSON(
        documentsURL: URL,
        queriesURL: URL,
        similaritiesURL: URL?,
        rankingsURL: URL?,
        dimension: Int,
        modelId: String
    ) throws -> GoldenStoreProvider {
        // Implementation for loading from JSON files
        // Placeholder for future extension
        fatalError("JSON loading not yet implemented")
    }
}

// MARK: - Vector utilities

private func generateRandomVector(dimension: Int, seed: UInt64) -> [Double] {
    var generator = WyRand(seed: seed)
    return (0..<dimension).map { _ in
        // Generate values between -1.0 and 1.0
        Double(generator.next()) / Double(UInt64.max) * 2.0 - 1.0
    }
}

private struct WyRand {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state &+= 0xa0761d6478bd642f
        let mul = state.multipliedFullWidth(by: state ^ 0xe7037ed1a0b428db)
        return mul.high ^ mul.low
    }
}

private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
    precondition(a.count == b.count, "Vectors must have same dimension")
    var dot: Double = 0.0
    var normA: Double = 0.0
    var normB: Double = 0.0
    for i in 0..<a.count {
        dot += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }
    let norm = sqrt(normA) * sqrt(normB)
    guard norm > 0 else { return 0.0 }
    return dot / norm
}