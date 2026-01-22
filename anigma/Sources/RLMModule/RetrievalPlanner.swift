import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContextumModule
import VectorIndexCapsule

/// Orchestrates the "Stupid-Fast" two-stage retrieval funnel.
/// Swift governs the budget and plan, while capsules handle the heavy lifting.
public actor RetrievalPlanner {
    private let database: ContextumDatabase
    private let vectorIndex: VectorIndexCapsuleWrapper
    private let rankFusion: RankFusionCapsuleWrapper
    private let inferenceAuthority: any InferenceAuthority
    
    public struct RetrievalBudget: Sendable {
        public var timeBudgetMs: Int = 200
        public var candidateLimit: Int = 500
        public var rerankThreshold: Double = 0.05 // Δ between top scores
        public var topK: Int = 50
        
        public static let `default` = RetrievalBudget()
    }
    
    public init(
        database: ContextumDatabase,
        vectorIndex: VectorIndexCapsuleWrapper,
        rankFusion: RankFusionCapsuleWrapper,
        inferenceAuthority: any InferenceAuthority
    ) {
        self.database = database
        self.vectorIndex = vectorIndex
        self.rankFusion = rankFusion
        self.inferenceAuthority = inferenceAuthority
    }
    
    /// Execute the high-performance retrieval funnel.
    public func retrieve(
        query: String,
        queryVector: [Float],
        budget: RetrievalBudget = .default,
        context: ExecutionContext
    ) async throws -> [ScoredSpan] {
        let startTime = Date()
        
        // Stage 1: Cheap Narrowing (SQLite FTS5 + Metadata)
        // We use FTS to get a "Bouncer Pool"
        let ftsChunkIds = try await database.searchFullText(query: query, limit: budget.candidateLimit)
        
        // Map chunk IDs to internal numeric IDs for the vector capsule
        let bouncerIds = ftsChunkIds.compactMap { id -> UInt64? in
            // Use a stable numeric hash of the chunk ID
            return UInt64(truncatingIfNeeded: id.hashValue)
        }
        
        // Stage 2: Semantic Pull (Dense ANN within the Bouncer Pool)
        let vectorResults = try await vectorIndex.searchPool(
            query: queryVector,
            candidateIds: bouncerIds,
            k: budget.topK
        )
        
        // Stage 3: Deterministic Fusion
        // Prepare rank lists for RankFusionCapsule
        let denseScores = vectorResults.reduce(into: [String: Double]()) { $0[String($1.id)] = Double($1.distance) }
        let sparseRanks = Dictionary(uniqueKeysWithValues: ftsChunkIds.enumerated().map { (index, id) in (String(UInt64(truncatingIfNeeded: id.hashValue)), index) })
        
        let fusedScores = try await rankFusion.fuseHybrid(
            denseResults: denseScores,
            sparseResults: sparseRanks
        )
        
        // Resolve results back to ScoredSpans
        var results = try await resolveScoredSpans(fusedScores, limit: budget.topK)
        
        // Stage 4: Adaptive Reranking
        if shouldRerank(results, threshold: budget.rerankThreshold) {
            results = try await executeRerank(query: query, candidates: results, context: context)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        print("[RetrievalPlanner] Funnel completed in \(Int(duration * 1000))ms, found \(results.count) spans")
        
        return results
    }
    
    private func shouldRerank(_ results: [ScoredSpan], threshold: Double) -> Bool {
        guard results.count > 1 else { return false }
        // Simple heuristic: if the scores are very close, let the cross-encoder decide
        let diff = abs(results[0].score - results[1].score)
        return diff < threshold
    }
    
    private func executeRerank(
        query: String,
        candidates: [ScoredSpan],
        context: ExecutionContext
    ) async throws -> [ScoredSpan] {
        // Only rerank top 10 to keep it fast
        let limit = min(candidates.count, 10)
        let toRerank = Array(candidates.prefix(limit))
        let docs = toRerank.map { $0.content }
        
        let request = RerankRequest(
            query: query,
            documents: docs,
            topK: limit
        )
        
        let response = try await inferenceAuthority.rerank(request, priority: .ui, context: context)
        
        var rerankedResults = candidates
        for res in response.results {
            if res.index < rerankedResults.count {
                // Blend scores (placeholder logic)
                let original = rerankedResults[res.index]
                rerankedResults[res.index] = ScoredSpan(
                    spanId: original.spanId,
                    content: original.content,
                    score: res.score, // Use reranker score
                    metadata: original.metadata
                )
            }
        }
        
        return rerankedResults.sorted { $0.score > $1.score }
    }
    
    private func resolveScoredSpans(_ scores: [String: Double], limit: Int) async throws -> [ScoredSpan] {
        // In a real system, we'd query the database to get the content and metadata for these IDs
        // Mapping back from numeric hash is lossy, so we should maintain a proper mapping table
        return []
    }
}

public struct ScoredSpan: Sendable {
    public let spanId: String
    public let content: String
    public let score: Double
    public let metadata: [String: String]
    
    public init(spanId: String, content: String, score: Double, metadata: [String: String]) {
        self.spanId = spanId
        self.content = content
        self.score = score
        self.metadata = metadata
    }
}
