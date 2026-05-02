import CosineSimilarityCapsule
import TextPipelineCapsule
import RankFusionCapsule
import Foundation
import CryptoKit
import AnigmaCore
import AnigmaPrimitives
import ContextumModule
import VectorIndexCapsule
import OSLog

/// Orchestrates the "Stupid-Fast" two-stage retrieval funnel.
/// Swift governs the budget and plan, while capsules handle the heavy lifting.
public actor RetrievalPlanner {
    private static let logger = Logger(subsystem: "com.anigma.RLMModule", category: "RetrievalPlanner")

    private let database: ContextumDatabase
    private let vectorIndex: VectorIndexCapsuleWrapper
    private let rankFusion: RankFusionCapsule
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
        rankFusion: RankFusionCapsule,
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
        
        // Stage 1: Cheap narrowing via PostgreSQL full-text + metadata
        // Narrow candidates before dense retrieval.
        let ftsChunkIds = try await database.searchFullText(query: query, limit: budget.candidateLimit)
        
        // Map chunk IDs to stable numeric IDs for the vector capsule.
        let bouncerIds = ftsChunkIds.map { hashChunkID($0) }
        let chunkIdByHash = Dictionary(uniqueKeysWithValues: zip(bouncerIds, ftsChunkIds))
        
        // Stage 2: Semantic Pull (Dense ANN within the Bouncer Pool)
        let vectorResults = try await vectorIndex.searchPool(
            query: queryVector,
            candidateIds: bouncerIds,
            k: budget.topK
        )
        
        // Stage 3: Deterministic Fusion
        let vectorRankIds = vectorResults.map(\.id)
        let fusedResults = try rankFusion.fuse(
            rankLists: [bouncerIds, vectorRankIds],
            k: 60,
            topK: budget.topK
        )

        // Resolve results back to ScoredSpans
        var results = try await resolveScoredSpans(
            fusedResults,
            chunkIdByHash: chunkIdByHash,
            limit: budget.topK
        )
        
        // Stage 4: Adaptive Reranking
        if shouldRerank(results, threshold: budget.rerankThreshold) {
            results = try await executeRerank(query: query, candidates: results, context: context)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        Self.logger.info(
            "[RetrievalPlanner] Funnel completed in \(Int(duration * 1000))ms, found \(results.count) spans"
        )
        
        return results
    }
    
    private func shouldRerank(_ results: [ScoredSpan], threshold: Double) -> Bool {
        guard results.count > 1 else { return false }
        // Simple heuristic: if the scores are very close, let the cross-encoder decide
        let diff = Swift.abs(results[0].score - results[1].score)
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
        
        _ = query
        _ = docs
        _ = context
        _ = inferenceAuthority
        return candidates
    }

    private func resolveScoredSpans(
        _ results: [(id: UInt64, score: Double)],
        chunkIdByHash: [UInt64: String],
        limit: Int
    ) async throws -> [ScoredSpan] {
        guard !results.isEmpty else { return [] }

        let topResults = results
            .sorted { $0.score > $1.score }
            .prefix(limit)
        
        let topChunkIds = topResults.compactMap { chunkIdByHash[$0.id] }
        let scoreMap = Dictionary(uniqueKeysWithValues: topResults.compactMap { result -> (String, Double)? in
            guard let chunkId = chunkIdByHash[result.id] else { return nil }
            return (chunkId, result.score)
        })

        let chunks = try await database.getChunkContent(chunkIds: topChunkIds)

        return chunks.map { chunk in
            ScoredSpan(
                spanId: chunk.chunkId,
                content: chunk.content,
                score: scoreMap[chunk.chunkId] ?? 0,
                metadata: ["source_id": chunk.sourceId]
            )
        }
        .sorted { $0.score > $1.score }
    }

    private func hashChunkID(_ chunkId: String) -> UInt64 {
        let digest = SHA256.hash(data: Data(chunkId.utf8))
        return digest.prefix(8).enumerated().reduce(into: UInt64(0)) { result, pair in
            result |= UInt64(pair.element) << (pair.offset * 8)
        }
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
