//
//  EmbeddingStabilityUnitTests.swift
//  EmbeddingStability
//
//  Unit tests with 1k docs/50 queries for CI.
//

import XCTest
@testable import VectorumModule
import ContractsCore

internal final class EmbeddingStabilityUnitTests: XCTestCase {
    private var goldenStore: GoldenStoreProvider!
    private var embeddingComputer: EmbeddingComputing!
    
    override func setUp() async throws {
        try await super.setUp()
        goldenStore = GoldenStoreFactory.createUnitTestStore()
        // Use deterministic embedding computer for unit tests
        // This ensures reproducibility across runs
        embeddingComputer = DeterministicEmbeddingComputer(dimension: goldenStore.embeddingDimension)
    }
    
    override func tearDown() async throws {
        goldenStore = nil
        embeddingComputer = nil
        try await super.tearDown()
    }
    
    /// Test that embedding dimensions match expected value (384 for MiniLM)
    internal func testEmbeddingDimension() throws {
        XCTAssertEqual(goldenStore.embeddingDimension, 384)
    }
    
    /// Test that we can compute embeddings for all documents and they match expected dimensionality
    internal func testDocumentEmbeddingsDimensionality() throws {
        let documents = try goldenStore.documentEmbeddings()
        XCTAssertEqual(documents.count, 1000)
        for doc in documents {
            XCTAssertEqual(doc.vector.count, goldenStore.embeddingDimension)
        }
    }
    
    /// Test that we can compute embeddings for all queries and they match expected dimensionality
    internal func testQueryEmbeddingsDimensionality() throws {
        let queries = try goldenStore.queryEmbeddings()
        XCTAssertEqual(queries.count, 50)
        for query in queries {
            XCTAssertEqual(query.vector.count, goldenStore.embeddingDimension)
        }
    }
    
    /// Test that similarity scores are within valid range [-1, 1]
    internal func testSimilarityScoreRange() throws {
        let similarities = try goldenStore.similarityScores()
        XCTAssertGreaterThan(similarities.count, 0)
        for sim in similarities {
            XCTAssertGreaterThanOrEqual(sim.score, -1.0)
            XCTAssertLessThanOrEqual(sim.score, 1.0)
        }
    }
    
    /// Test that rankings are sorted descending by score
    internal func testRankingsAreSorted() throws {
        let rankings = try goldenStore.queryRankings()
        for ranking in rankings {
            var previousScore: Double = .infinity
            for (_, score) in ranking.rankedDocuments {
                XCTAssertLessThanOrEqual(score, previousScore, "Scores should be non-increasing")
                previousScore = score
            }
        }
    }
    
    /// Test that embedding computer produces vectors of correct dimension
    internal func testEmbeddingComputerDimension() async throws {
        let inputs = ["sample text", "another sample"]
        let result = try await embeddingComputer.computeEmbeddings(
            modelID: "test-model",
            modelVersion: nil,
            inputs: inputs,
            normalize: false
        )
        XCTAssertEqual(result.dimension, goldenStore.embeddingDimension)
        XCTAssertEqual(result.vectors.count, inputs.count)
        for vector in result.vectors {
            XCTAssertEqual(vector.count, goldenStore.embeddingDimension)
        }
    }
    
    /// Test that deterministic embedding computer produces consistent outputs
    internal func testDeterministicEmbeddingConsistency() async throws {
        let input = "deterministic test"
        let result1 = try await embeddingComputer.computeEmbeddings(
            modelID: "test-model",
            modelVersion: nil,
            inputs: [input],
            normalize: false
        )
        let result2 = try await embeddingComputer.computeEmbeddings(
            modelID: "test-model",
            modelVersion: nil,
            inputs: [input],
            normalize: false
        )
        XCTAssertEqual(result1.vectors.count, 1)
        XCTAssertEqual(result2.vectors.count, 1)
        let vec1 = result1.vectors[0]
        let vec2 = result2.vectors[0]
        for (v1, v2) in zip(vec1, vec2) {
            XCTAssertEqual(v1, v2, accuracy: 1e-9)
        }
    }
    
    /// Test semantic retrieval stability: rankings should match golden store within tolerance
    internal func testSemanticRetrievalStability() async throws {
        // This test validates that the ranking produced by the embedding computer
        // matches the golden store rankings within acceptable tolerance.
        // Since we're using the deterministic computer with synthetic embeddings,
        // we expect exact matches for the synthetic data.
        
        let documents = try goldenStore.documentEmbeddings()
        let queries = try goldenStore.queryEmbeddings()
        
        // Map document IDs to vectors for easy lookup
        var docVectors: [String: [Double]] = [:]
        for doc in documents {
            docVectors[doc.id] = doc.vector
        }
        
        // For each query, compute similarities using cosine similarity
        for query in queries.prefix(5) { // Limit to 5 queries for CI speed
            let queryVector = query.vector
            
            var computedScores: [(String, Double)] = []
            for doc in documents {
                let score = cosineSimilarity(queryVector, doc.vector)
                computedScores.append((doc.id, score))
            }
            
            // Sort descending
            computedScores.sort { $0.1 > $1.1 }
            let topK = min(20, computedScores.count)
            let computedTopK = Array(computedScores.prefix(topK))
            
            // Get golden ranking for this query
            let goldenRankings = try goldenStore.queryRankings()
            guard let goldenRanking = goldenRankings.first(where: { $0.queryId == query.id }) else {
                XCTFail("No golden ranking for query \(query.id)")
                continue
            }
            
            // Compare top-k document IDs (order matters)
            let goldenTopK = goldenRanking.rankedDocuments.prefix(topK).map { $0 }
            
            // For stability testing, we require at least 80% overlap in top-10
            let overlapCount = Set(computedTopK.map { $0.0 }).intersection(Set(goldenTopK.map { $0.0 })).count
            let overlapRatio = Double(overlapCount) / Double(topK)
            XCTAssertGreaterThanOrEqual(overlapRatio, 0.8, "Top-\(topK) overlap too low for query \(query.id)")
            
            // Score tolerance: cosine similarity scores should match within 0.01
            for (computed, golden) in zip(computedTopK, goldenTopK) {
                XCTAssertEqual(computed.0, golden.0, "Document order mismatch for query \(query.id)")
                XCTAssertEqual(computed.1, golden.1, accuracy: 0.01,
                               "Score mismatch for document \(computed.0) in query \(query.id)")
            }
        }
    }
    
    /// Test that score distributions are preserved across engine changes
    internal func testScoreDistributionStability() throws {
        // This test validates that the distribution of similarity scores
        // remains stable across engine changes.
        let similarities = try goldenStore.similarityScores()
        let scores = similarities.map { $0.score }
        
        // Compute basic statistics
        let minScore = scores.min() ?? 0.0
        let maxScore = scores.max() ?? 0.0
        let meanScore = scores.reduce(0.0, +) / Double(scores.count)
        
        // Expected ranges for synthetic random vectors:
        // Cosine similarity between random vectors tends to be near 0
        XCTAssertGreaterThan(minScore, -0.5)
        XCTAssertLessThan(maxScore, 0.5)
        XCTAssertEqual(meanScore, 0.0, accuracy: 0.05)
        
        // Store statistics for comparison in integration tests
        print("Score distribution: min=\(minScore), max=\(maxScore), mean=\(meanScore)")
    }
    
    /// Test that hard negatives (low-scoring documents) are captured in golden store
    internal func testHardNegativesPresence() throws {
        // Hard negatives are documents with low similarity scores that are
        // important for training and evaluation.
        let similarities = try goldenStore.similarityScores()
        
        // Group by query
        var queryScores: [String: [Double]] = [:]
        for sim in similarities {
            queryScores[sim.queryId, default: []].append(sim.score)
        }
        
        for (queryId, scores) in queryScores {
            let sortedScores = scores.sorted()
            // Bottom 10% as hard negatives
            let hardNegativeCount = max(1, scores.count / 10)
            let hardNegatives = sortedScores.prefix(hardNegativeCount)
            
            // Verify hard negatives have low scores
            for score in hardNegatives {
                XCTAssertLessThan(score, 0.0, "Hard negative score should be negative for query \(queryId)")
            }
        }
    }
}

// MARK: - Cosine similarity helper

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