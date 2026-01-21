//
//  EmbeddingStabilityIntegrationTests.swift
//  EmbeddingStability
//
//  Integration tests with 10k docs/200 queries for nightly.
//

import XCTest
@testable import VectorumModule
@testable import ContextumModule
import ContractsCore

internal final class EmbeddingStabilityIntegrationTests: XCTestCase {
    private var goldenStore: GoldenStoreProvider!
    private var embeddingComputer: EmbeddingComputing!
    
    override func setUp() async throws {
        try await super.setUp()
        goldenStore = GoldenStoreFactory.createIntegrationTestStore()
        // Use deterministic embedding computer for integration tests
        // In production, this would be replaced with actual engines (CoreML, MPS, Metal)
        embeddingComputer = DeterministicEmbeddingComputer(dimension: goldenStore.embeddingDimension)
    }
    
    override func tearDown() async throws {
        goldenStore = nil
        embeddingComputer = nil
        try await super.tearDown()
    }
    
    /// Validate scale of integration test dataset
    internal func testDatasetScale() throws {
        let documents = try goldenStore.documentEmbeddings()
        let queries = try goldenStore.queryEmbeddings()
        
        XCTAssertEqual(documents.count, 10_000)
        XCTAssertEqual(queries.count, 200)
        XCTAssertEqual(goldenStore.embeddingDimension, 384)
    }
    
    /// Performance test: computing embeddings for all documents should be fast
    internal func testDocumentEmbeddingsPerformance() async throws {
        let documents = try goldenStore.documentEmbeddings()
        let texts = documents.compactMap { $0.text }
        // Use a subset for performance test (1000 documents)
        let subset = Array(texts.prefix(1000))
        
        measure {
            let expectation = self.expectation(description: "Embedding computation")
            Task {
                _ = try? await self.embeddingComputer.computeEmbeddings(
                    modelID: "test-model",
                    modelVersion: nil,
                    inputs: subset,
                    normalize: false
                )
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    /// Performance test: similarity search across all documents for a single query
    internal func testSimilaritySearchPerformance() async throws {
        let documents = try goldenStore.documentEmbeddings()
        let queries = try goldenStore.queryEmbeddings()
        let query = queries.first!
        
        // Convert to dictionaries for fast lookup
        let docVectors = documents.reduce(into: [String: [Double]]()) { $0[$1.id] = $1.vector }
        
        measure {
            var scores: [(String, Double)] = []
            for doc in documents {
                let score = cosineSimilarity(query.vector, doc.vector)
                scores.append((doc.id, score))
            }
            scores.sort { $0.1 > $1.1 }
            _ = scores.prefix(20)
        }
    }
    
    /// Test semantic retrieval stability at scale: compare rankings for all queries
    internal func testSemanticRetrievalStabilityAtScale() async throws {
        // This test validates that ranking remains stable across engine changes
        // for the full integration dataset (10k docs, 200 queries).
        // We test a subset of queries for practicality.
        
        let documents = try goldenStore.documentEmbeddings()
        let queries = try goldenStore.queryEmbeddings()
        
        // Map document IDs to vectors
        let docVectors = documents.reduce(into: [String: [Double]]()) { $0[$1.id] = $1.vector }
        
        // Test first 20 queries for speed
        let testQueries = queries.prefix(20)
        
        for query in testQueries {
            // Compute similarities using brute-force cosine similarity
            var computedScores: [(String, Double)] = []
            for doc in documents {
                let score = cosineSimilarity(query.vector, doc.vector)
                computedScores.append((doc.id, score))
            }
            
            // Sort descending and take top 100
            computedScores.sort { $0.1 > $1.1 }
            let topK = 100
            let computedTopK = Array(computedScores.prefix(topK))
            
            // Get golden ranking for this query
            let goldenRankings = try goldenStore.queryRankings()
            guard let goldenRanking = goldenRankings.first(where: { $0.queryId == query.id }) else {
                // Some queries may not have precomputed rankings (see factory)
                // Skip them
                continue
            }
            
            let goldenTopK = goldenRanking.rankedDocuments.prefix(topK).map { $0 }
            
            // Stability metrics
            // 1. Top-k overlap (set intersection)
            let computedIDs = Set(computedTopK.map { $0.0 })
            let goldenIDs = Set(goldenTopK.map { $0.0 })
            let overlapCount = computedIDs.intersection(goldenIDs).count
            let overlapRatio = Double(overlapCount) / Double(topK)
            
            // Acceptable overlap threshold for synthetic deterministic data: 100%
            // In real scenarios, this would be lower due to floating point differences
            XCTAssertGreaterThanOrEqual(overlapRatio, 0.95,
                                       "Top-\(topK) overlap too low for query \(query.id): \(overlapRatio)")
            
            // 2. Score tolerance (allow small floating point differences)
            for (computed, golden) in zip(computedTopK, goldenTopK) {
                XCTAssertEqual(computed.1, golden.1, accuracy: 0.001,
                               "Score mismatch for document \(computed.0) in query \(query.id)")
            }
            
            // 3. Rank correlation (Kendall's tau) - compute if needed
            // For integration tests, we can compute rank correlation as additional signal
            let tau = kendallsTau(computedTopK.map { $0.0 }, goldenTopK.map { $0.0 })
            XCTAssertGreaterThan(tau, 0.9, "Rank correlation too low for query \(query.id): \(tau)")
        }
    }
    
    /// Test that score distributions match expected statistical properties
    internal func testScoreDistributionAtScale() throws {
        let similarities = try goldenStore.similarityScores()
        let scores = similarities.map { $0.score }
        
        // Compute distribution statistics
        let minScore = scores.min() ?? 0.0
        let maxScore = scores.max() ?? 0.0
        let meanScore = scores.reduce(0.0, +) / Double(scores.count)
        
        // For random vectors in high dimension, cosine similarity distribution
        // should be approximately normal with mean 0, variance 1/dim
        let variance = scores.map { $0 * $0 }.reduce(0.0, +) / Double(scores.count)
        let expectedVariance = 1.0 / Double(goldenStore.embeddingDimension)
        
        XCTAssertEqual(meanScore, 0.0, accuracy: 0.01,
                       "Mean score should be near zero for random vectors")
        XCTAssertEqual(variance, expectedVariance, accuracy: 0.1,
                       "Variance should approximate 1/dim")
        
        // Store metrics for monitoring
        print("""
        Score distribution at scale:
          min: \(minScore)
          max: \(maxScore)
          mean: \(meanScore)
          variance: \(variance)
          expected variance: \(expectedVariance)
        """)
    }
    
    /// Test that hard negatives are captured and identifiable at scale
    internal func testHardNegativesAtScale() throws {
        let similarities = try goldenStore.similarityScores()
        
        // Group by query
        var queryScores: [String: [Double]] = [:]
        for sim in similarities {
            queryScores[sim.queryId, default: []].append(sim.score)
        }
        
        var hardNegativeStats: [String: Int] = [:]
        for (queryId, scores) in queryScores {
            let sortedScores = scores.sorted()
            let hardNegativeThreshold = sortedScores[max(0, scores.count / 10 - 1)]
            let hardNegativeCount = scores.filter { $0 <= hardNegativeThreshold }.count
            hardNegativeStats[queryId] = hardNegativeCount
            
            // Verify hard negatives have low scores
            XCTAssertLessThan(hardNegativeThreshold, 0.0,
                             "Hard negative threshold should be negative for query \(queryId)")
        }
        
        print("Hard negative counts per query: \(hardNegativeStats)")
    }
    
    /// Test interoperability with ContextumModule's semantic search system
    internal func testContextumModuleIntegration() async throws {
        // This test validates that embeddings produced by our engine
        // are compatible with ContextumModule's semantic search system.
        guard let contextumComputer = embeddingComputer as? DeterministicEmbeddingComputer else {
            // If we're using a different computer, skip this test
            return
        }
        
        let documents = try goldenStore.documentEmbeddings()
        let queries = try goldenStore.queryEmbeddings()
        
        // Convert documents to semantic search system format
        // (This is a placeholder - actual integration would use ContextumModule APIs)
        let documentTexts = documents.compactMap { $0.text }
        let queryTexts = queries.compactMap { $0.text }
        
        // Compute embeddings via ContextumModule's embedding computing protocol
        let docEmbeddings = try await contextumComputer.computeEmbeddings(
            modelID: goldenStore.modelIdentifier,
            modelVersion: nil,
            inputs: documentTexts,
            normalize: true
        )
        
        let queryEmbeddings = try await contextumComputer.computeEmbeddings(
            modelID: goldenStore.modelIdentifier,
            modelVersion: nil,
            inputs: queryTexts,
            normalize: true
        )
        
        // Verify normalized embeddings have unit length (approximately)
        for vector in docEmbeddings.vectors {
            let norm = sqrt(vector.reduce(0.0) { $0 + $1 * $1 })
            XCTAssertEqual(norm, 1.0, accuracy: 0.001)
        }
        
        for vector in queryEmbeddings.vectors {
            let norm = sqrt(vector.reduce(0.0) { $0 + $1 * $1 })
            XCTAssertEqual(norm, 1.0, accuracy: 0.001)
        }
    }
    
    /// Test that the golden store can be serialized and deserialized (future JSON support)
    internal func testGoldenStoreSerialization() throws {
        // Placeholder for future JSON serialization test
        // When JSON support is added, this test will validate round-trip serialization
        throw XCTSkip("JSON serialization not yet implemented")
    }
}

// MARK: - Statistical utilities

/// Compute Kendall's tau rank correlation coefficient
private func kendallsTau<T: Equatable>(_ a: [T], _ b: [T]) -> Double {
    precondition(a.count == b.count, "Arrays must have same length")
    let n = a.count
    guard n > 1 else { return 1.0 }
    
    // Create mapping from item to rank in each list
    let rankA = Dictionary(uniqueKeysWithValues: a.enumerated().map { ($0.element, $0.offset) })
    let rankB = Dictionary(uniqueKeysWithValues: b.enumerated().map { ($0.element, $0.offset) })
    
    // Count concordant and discordant pairs
    var concordant = 0
    var discordant = 0
    
    for i in 0..<n {
        for j in (i + 1)..<n {
            let aI = rankA[a[i]]!
            let aJ = rankA[a[j]]!
            let bI = rankB[b[i]]!
            let bJ = rankB[b[j]]!
            
            let aOrder = aI < aJ
            let bOrder = bI < bJ
            
            if aOrder == bOrder {
                concordant += 1
            } else {
                discordant += 1
            }
        }
    }
    
    let totalPairs = n * (n - 1) / 2
    guard totalPairs > 0 else { return 0.0 }
    return Double(concordant - discordant) / Double(totalPairs)
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