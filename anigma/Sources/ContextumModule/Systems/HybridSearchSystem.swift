import Foundation
import AnigmaPrimitives
import CryptoKit
import OSLog

extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

public actor HybridSearchSystem {
    private static let logger = Logger(
        subsystem: "com.anigma.ContextumModule",
        category: "HybridSearchSystem"
    )
    private let database: ContextumDatabase
    private let semanticSearch: SemanticSearchSystem
    private var rankFusionCapsule: ContextumRankFusionCapsuleWrapper?

    public init(database: ContextumDatabase) {
        self.database = database
        self.semanticSearch = SemanticSearchSystem()
    }

    private enum SpatialOperation: String {
        case intersect    // Chunk bbox intersects query bbox (default)
        case contain      // Chunk bbox fully contains query bbox
        case within       // Chunk bbox is fully within query bbox
        case near         // Chunk centroid within distance of query point
    }
    
    private struct SpatialFilter {
        let pageIndices: [Int]?
        let boundingBox: (left: Double, top: Double, right: Double, bottom: Double)?
        let operation: SpatialOperation
        let distance: Double?  // For near operation
        
        init(pageIndices: [Int]? = nil, boundingBox: (left: Double, top: Double, right: Double, bottom: Double)? = nil, operation: SpatialOperation = .intersect, distance: Double? = nil) {
            self.pageIndices = pageIndices
            self.boundingBox = boundingBox
            self.operation = operation
            self.distance = distance
        }
        
        // Backward compatibility
        var pageIndex: Int? {
            pageIndices?.first
        }

        var contextumBoundingBox: BoundingBox? {
            guard let boundingBox else { return nil }
            return BoundingBox(
                left: boundingBox.left,
                top: boundingBox.top,
                right: boundingBox.right,
                bottom: boundingBox.bottom
            )
        }
    }

    private func extractSpatialFilter(from filters: [String: String]) -> SpatialFilter? {
        var pageIndices: [Int]?
        var bboxLeft: Double?
        var bboxTop: Double?
        var bboxRight: Double?
        var bboxBottom: Double?
        var operation: SpatialOperation = .intersect
        var distance: Double?

        for (key, value) in filters {
            switch key {
            case "page_index":
                if let pageIndex = Int(value) {
                    pageIndices = [pageIndex]
                }
            case "page_indices":
                let indices = value.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                if !indices.isEmpty {
                    pageIndices = indices
                }
            case "bbox_left":
                bboxLeft = Double(value)
            case "bbox_top":
                bboxTop = Double(value)
            case "bbox_right":
                bboxRight = Double(value)
            case "bbox_bottom":
                bboxBottom = Double(value)
            case "operation":
                operation = SpatialOperation(rawValue: value) ?? .intersect
            case "distance":
                distance = Double(value)
            default:
                continue
            }
        }

        // Only create bounding box if all four values are provided
        let boundingBox: (left: Double, top: Double, right: Double, bottom: Double)?
        if let left = bboxLeft, let top = bboxTop, let right = bboxRight, let bottom = bboxBottom {
            boundingBox = (left: left, top: top, right: right, bottom: bottom)
        } else {
            boundingBox = nil
        }

        if pageIndices != nil || boundingBox != nil {
            return SpatialFilter(
                pageIndices: pageIndices,
                boundingBox: boundingBox,
                operation: operation,
                distance: distance
            )
        }
        return nil
    }

    private func extractSourceSelection(from filters: [String: String]) -> SourceSelectionPolicy {
        func bool(_ key: String, default defaultValue: Bool) -> Bool {
            guard let raw = filters[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                return defaultValue
            }
            return ["1", "true", "yes", "on"].contains(raw)
        }

        return SourceSelectionPolicy(
            includeStale: bool("include_stale", default: false),
            includeSuperseded: bool("include_superseded", default: false),
            includeConflicted: bool("include_conflicted", default: true)
        )
    }

    public struct SearchRequest: Codable, Sendable {
        public let query: String
        public let mode: SearchMode
        public let limit: Int
        public let filters: [String: String]
        public let embeddingModelId: String?
        public let embeddingModelHash: String?
        public let queryEmbedding: [Float]?
        public let workflowId: String
        public let runId: String
        public let retrievalQualityContract: RetrievalQualityContract?

        public enum SearchMode: String, Codable, Sendable {
            case fullText
            case semantic
            case hybrid
            case spatial
        }

        public init(
            query: String,
            mode: SearchMode = .fullText,
            limit: Int = 20,
            filters: [String: String] = [:],
            embeddingModelId: String? = nil,
            embeddingModelHash: String? = nil,
            queryEmbedding: [Float]? = nil,
            workflowId: String,
            runId: String,
            retrievalQualityContract: RetrievalQualityContract? = nil
        ) {
            self.query = query
            self.mode = mode
            self.limit = limit
            self.filters = filters
            self.embeddingModelId = embeddingModelId
            self.embeddingModelHash = embeddingModelHash
            self.queryEmbedding = queryEmbedding
            self.workflowId = workflowId
            self.runId = runId
            self.retrievalQualityContract = retrievalQualityContract
        }
    }

    /// Retrieval quality contract defining freshness, source, confidence, and context-budgeting requirements
    public struct RetrievalQualityContract: Codable, Sendable {
        public let freshnessPolicy: FreshnessPolicy
        public let sourceTrustPolicy: SourceTrustPolicy
        public let profileMemoryPolicy: ProfileMemoryPolicy
        public let abstentionPolicy: AbstentionPolicy
        public let rankingWeights: RankingWeights
        public let contextBudgetPolicy: ContextBudgetPolicy

        public init(
            freshnessPolicy: FreshnessPolicy = .default,
            sourceTrustPolicy: SourceTrustPolicy = .default,
            profileMemoryPolicy: ProfileMemoryPolicy = .default,
            abstentionPolicy: AbstentionPolicy = .default,
            rankingWeights: RankingWeights = .default,
            contextBudgetPolicy: ContextBudgetPolicy = .default
        ) {
            self.freshnessPolicy = freshnessPolicy
            self.sourceTrustPolicy = sourceTrustPolicy
            self.profileMemoryPolicy = profileMemoryPolicy
            self.abstentionPolicy = abstentionPolicy
            self.rankingWeights = rankingWeights
            self.contextBudgetPolicy = contextBudgetPolicy
        }
    }

    /// Freshness policy for retrieval
    public struct FreshnessPolicy: Codable, Sendable {
        public let maxAgeDays: Int?
        public let preferRecent: Bool
        public let recentBoostFactor: Double

        public static let `default` = FreshnessPolicy(
            maxAgeDays: 30,
            preferRecent: true,
            recentBoostFactor: 1.5
        )
    }

    /// Source trust policy for retrieval
    public struct SourceTrustPolicy: Codable, Sendable {
        public let trustedSourceTypes: [String]
        public let trustedSourceIds: [String]
        public let trustBoostFactor: Double
        public let untrustedPenaltyFactor: Double

        public static let `default` = SourceTrustPolicy(
            trustedSourceTypes: [],
            trustedSourceIds: [],
            trustBoostFactor: 2.0,
            untrustedPenaltyFactor: 0.5
        )
    }

    /// Profile memory policy for retrieval
    public struct ProfileMemoryPolicy: Codable, Sendable {
        public let includeProfileMemory: Bool
        public let profileMemoryBoostFactor: Double
        public let minProfileMemoryConfidence: Double

        public static let `default` = ProfileMemoryPolicy(
            includeProfileMemory: true,
            profileMemoryBoostFactor: 1.8,
            minProfileMemoryConfidence: 0.6
        )
    }

    /// Abstention policy for retrieval
    public struct AbstentionPolicy: Codable, Sendable {
        public let abstainOnStaleEvidence: Bool
        public let abstainOnLowConfidence: Bool
        public let minConfidenceThreshold: Double
        public let abstentionExplanationRequired: Bool

        public static let `default` = AbstentionPolicy(
            abstainOnStaleEvidence: true,
            abstainOnLowConfidence: true,
            minConfidenceThreshold: 0.4,
            abstentionExplanationRequired: true
        )
    }

    /// Ranking weights for multi-factor scoring
    public struct RankingWeights: Codable, Sendable {
        public let semanticWeight: Double
        public let lexicalWeight: Double
        public let freshnessWeight: Double
        public let sourceTrustWeight: Double
        public let profileMemoryWeight: Double

        public static let `default` = RankingWeights(
            semanticWeight: 0.4,
            lexicalWeight: 0.3,
            freshnessWeight: 0.15,
            sourceTrustWeight: 0.1,
            profileMemoryWeight: 0.05
        )
    }

    /// Context budget policy for retrieval
    public struct ContextBudgetPolicy: Codable, Sendable {
        public let maxTokenBudget: Int
        public let minRelevantTokens: Int
        public let tokenBudgetEnforcement: TokenBudgetEnforcement
        public let salienceThreshold: Double

        public static let `default` = ContextBudgetPolicy(
            maxTokenBudget: 4096,
            minRelevantTokens: 512,
            tokenBudgetEnforcement: .strict,
            salienceThreshold: 0.7
        )
    }

    /// Token budget enforcement mode
    public enum TokenBudgetEnforcement: String, Codable, Sendable {
        case strict   // Strictly enforce budget, truncate if needed
        case relaxed  // Allow slight overflow with warnings
        case adaptive // Dynamically adjust based on content importance
    }

    /// Enhanced search result with source metadata and quality indicators
    public struct EnhancedSearchResult: Codable, Sendable {
        public let chunks: [EnhancedSearchResultChunk]
        public let totalResults: Int
        public let retrievalQuality: RetrievalQualityAssessment
        public let abstentionReason: String?

        public init(
            chunks: [EnhancedSearchResultChunk],
            totalResults: Int,
            retrievalQuality: RetrievalQualityAssessment,
            abstentionReason: String? = nil
        ) {
            self.chunks = chunks
            self.totalResults = totalResults
            self.retrievalQuality = retrievalQuality
            self.abstentionReason = abstentionReason
        }
    }

    /// Enhanced search result chunk with source metadata
    public struct EnhancedSearchResultChunk: Codable, Sendable {
        public let chunkId: String
        public let content: String
        public let sourceId: String
        public let sourceMetadata: SourceMetadata
        public let score: Double?
        public let confidence: Double
        public let freshnessScore: Double
        public let sourceTrustScore: Double
        public let isStale: Bool
        public let hasConflicts: Bool

        public init(
            chunkId: String,
            content: String,
            sourceId: String,
            sourceMetadata: SourceMetadata,
            score: Double? = nil,
            confidence: Double,
            freshnessScore: Double,
            sourceTrustScore: Double,
            isStale: Bool,
            hasConflicts: Bool
        ) {
            self.chunkId = chunkId
            self.content = content
            self.sourceId = sourceId
            self.sourceMetadata = sourceMetadata
            self.score = score
            self.confidence = confidence
            self.freshnessScore = freshnessScore
            self.sourceTrustScore = sourceTrustScore
            self.isStale = isStale
            self.hasConflicts = hasConflicts
        }
    }

    /// Source metadata for retrieval results
    public struct SourceMetadata: Codable, Sendable {
        public let sourceType: String
        public let canonicalRef: String
        public let discoveredAt: Date
        public let lastSeenAt: Date
        public let staleAt: Date?
        public let revision: Int
        public let conflictStatus: String
        public let trustScore: Double

        public init(
            sourceType: String,
            canonicalRef: String,
            discoveredAt: Date,
            lastSeenAt: Date,
            staleAt: Date?,
            revision: Int,
            conflictStatus: String,
            trustScore: Double
        ) {
            self.sourceType = sourceType
            self.canonicalRef = canonicalRef
            self.discoveredAt = discoveredAt
            self.lastSeenAt = lastSeenAt
            self.staleAt = staleAt
            self.revision = revision
            self.conflictStatus = conflictStatus
            self.trustScore = trustScore
        }
    }

    /// Retrieval quality assessment
    public struct RetrievalQualityAssessment: Codable, Sendable {
        public let overallConfidence: Double
        public let freshnessScore: Double
        public let sourceTrustScore: Double
        public let coverageScore: Double
        public let conflictScore: Double
        public let abstentionRisk: Double
        public let precision: Double
        public let recall: Double
        public let f1Score: Double
        public let tokenBudgetCompliance: Double
        public let salienceCoverage: Double

        public init(
            overallConfidence: Double,
            freshnessScore: Double,
            sourceTrustScore: Double,
            coverageScore: Double,
            conflictScore: Double,
            abstentionRisk: Double,
            precision: Double,
            recall: Double,
            f1Score: Double,
            tokenBudgetCompliance: Double,
            salienceCoverage: Double
        ) {
            self.overallConfidence = overallConfidence
            self.freshnessScore = freshnessScore
            self.sourceTrustScore = sourceTrustScore
            self.coverageScore = coverageScore
            self.conflictScore = conflictScore
            self.abstentionRisk = abstentionRisk
            self.precision = precision
            self.recall = recall
            self.f1Score = f1Score
            self.tokenBudgetCompliance = tokenBudgetCompliance
            self.salienceCoverage = salienceCoverage
        }
    }

    public struct SearchResultChunk: Codable, Sendable {
        public let chunkId: String
        public let content: String
        public let sourceId: String
        public let score: Double?

        public init(chunkId: String, content: String, sourceId: String, score: Double? = nil) {
            self.chunkId = chunkId
            self.content = content
            self.sourceId = sourceId
            self.score = score
        }
    }

    public struct SearchResult: Codable, Sendable {
        public let chunks: [SearchResultChunk]
        public let totalResults: Int

        public init(chunks: [SearchResultChunk], totalResults: Int) {
            self.chunks = chunks
            self.totalResults = totalResults
        }
    }

    public func search(_ request: SearchRequest) async throws -> EnhancedSearchResult {
        let startTime = Date()
        let queryHash = BLAKE3Digest.hex(of: request.query)
        let spatialFilter = extractSpatialFilter(from: request.filters)
        let sourceSelection = extractSourceSelection(from: request.filters)
        let qualityContract = request.retrievalQualityContract ?? .init()

        let chunks: [SearchResultChunk]
        var ftsRanks: [String: Int] = [:]
        var semanticRanks: [String: Int] = [:]

        switch request.mode {
        case .fullText:
            let chunkIds: [String]
            if let spatialFilter = spatialFilter {
                chunkIds = try await database.searchFullTextWithSpatial(
                    query: request.query,
                    pageIndex: spatialFilter.pageIndex,
                    boundingBox: spatialFilter.contextumBoundingBox,
                    limit: request.limit,
                    sourceSelection: sourceSelection
                )
            } else {
                chunkIds = try await database.searchFullText(
                    query: request.query,
                    limit: request.limit,
                    sourceSelection: sourceSelection
                )
            }
            chunks = try await database.getChunkContent(chunkIds: chunkIds, sourceSelection: sourceSelection)

        case .semantic:
            guard let embedding = request.queryEmbedding,
                  let modelId = request.embeddingModelId,
                  let modelHash = request.embeddingModelHash else {
                throw ContextumError.invalidModelIdentity(
                    modelID: request.embeddingModelId,
                    modelHash: request.embeddingModelHash,
                    reason: "Missing embedding parameters for semantic search"
                )
            }

            let semanticRequest = SemanticSearchSystem.SearchRequest(
                queryText: request.query,
                queryEmbedding: embedding,
                embeddingModelId: modelId,
                embeddingModelHash: modelHash,
                limit: request.limit,
                workflowId: request.workflowId,
                runId: request.runId
            )

            let results = try await semanticSearch.search(request: semanticRequest, database: database)
            let chunkHashes = results.map { $0.chunkHash }
            let chunkIdMap = try await database.getChunkHashToIdMap(
                chunkHashes: chunkHashes,
                sourceSelection: sourceSelection
            )
            var chunkIds = chunkHashes.compactMap { chunkIdMap[$0] }
            
            // Apply spatial filter if present
            if let spatialFilter = spatialFilter {
                chunkIds = try await database.filterChunksBySpatial(
                    chunkIds: chunkIds,
                    pageIndex: spatialFilter.pageIndex,
                    boundingBox: spatialFilter.contextumBoundingBox,
                    sourceSelection: sourceSelection
                )
            }
            
            // Create mapping from chunkId to similarity
            var chunkIdToSimilarity: [String: Float] = [:]
            for result in results {
                if let chunkId = chunkIdMap[result.chunkHash] {
                    chunkIdToSimilarity[chunkId] = result.similarity
                }
            }
            
            chunks = try await database.getChunkContent(chunkIds: chunkIds, sourceSelection: sourceSelection)
                .map { chunk in
                    let similarity = chunkIdToSimilarity[chunk.chunkId] ?? 0
                    return SearchResultChunk(
                        chunkId: chunk.chunkId,
                        content: chunk.content,
                        sourceId: chunk.sourceId,
                        score: Double(similarity)
                    )
                }

        case .hybrid:
            guard let embedding = request.queryEmbedding,
            let modelId = request.embeddingModelId,
            let modelHash = request.embeddingModelHash else {
                chunks = try await fallbackToFullText(request: request, queryHash: queryHash)
                break
            }

            // Run both searches
            let ftsChunkIds: [String]
            if let spatialFilter = spatialFilter {
                ftsChunkIds = try await database.searchFullTextWithSpatial(
                    query: request.query,
                    pageIndex: spatialFilter.pageIndex,
                    boundingBox: spatialFilter.contextumBoundingBox,
                    limit: request.limit * 2,
                    sourceSelection: sourceSelection
                )
            } else {
                ftsChunkIds = try await database.searchFullText(
                    query: request.query,
                    limit: request.limit * 2,
                    sourceSelection: sourceSelection
                )
            }
            for (index, chunkId) in ftsChunkIds.enumerated() {
                ftsRanks[chunkId] = index
            }

            let semanticRequest = SemanticSearchSystem.SearchRequest(
                queryText: request.query,
                queryEmbedding: embedding,
                embeddingModelId: modelId,
                embeddingModelHash: modelHash,
                limit: request.limit * 2,
                workflowId: request.workflowId,
                runId: request.runId
            )

            let semanticResults = try await semanticSearch.search(request: semanticRequest, database: database)
            let semanticChunkHashes = semanticResults.map { $0.chunkHash }
            let semanticChunkMap = try await database.getChunkHashToIdMap(
                chunkHashes: semanticChunkHashes,
                sourceSelection: sourceSelection
            )
            var semanticChunkIds = semanticChunkHashes.compactMap { semanticChunkMap[$0] }
            
            // Apply spatial filter to semantic results
            if let spatialFilter = spatialFilter {
                semanticChunkIds = try await database.filterChunksBySpatial(
                    chunkIds: semanticChunkIds,
                    pageIndex: spatialFilter.pageIndex,
                    boundingBox: spatialFilter.contextumBoundingBox,
                    sourceSelection: sourceSelection
                )
            }
            
            // Build ranks only for filtered chunk IDs, preserving original order as much as possible
            // We'll rank based on original semantic results order, but only include filtered IDs
            for (index, result) in semanticResults.enumerated() {
                if let chunkId = semanticChunkMap[result.chunkHash],
                   semanticChunkIds.contains(chunkId) {
                    semanticRanks[chunkId] = index
                }
            }

            // RRF merge
            let mergedRanks = try await reciprocalRankFusion(
                ftsRanks: ftsRanks,
                semanticRanks: semanticRanks,
                k: 60
            )

            let topChunkIds = mergedRanks.sorted { $0.value > $1.value }
                .prefix(request.limit)
                .map { $0.key }

            chunks = try await database.getChunkContent(chunkIds: topChunkIds, sourceSelection: sourceSelection)
                .map { chunk in
                    let rrfScore = mergedRanks[chunk.chunkId] ?? 0
                    return SearchResultChunk(
                        chunkId: chunk.chunkId,
                        content: chunk.content,
                        sourceId: chunk.sourceId,
                        score: rrfScore
                    )
                }
                .sorted { ($0.score ?? 0) > ($1.score ?? 0) }

        case .spatial:
            let scoredChunks = try await database.searchSpatialWithScore(
                pageIndex: spatialFilter?.pageIndex,
                boundingBox: spatialFilter?.contextumBoundingBox,
                limit: request.limit,
                sourceSelection: sourceSelection
            )
            // Get content for scored chunks
            let chunkIds = scoredChunks.map { $0.chunkId }
            let chunkContents = try await database.getChunkContent(chunkIds: chunkIds, sourceSelection: sourceSelection)
            
            // Create mapping from chunkId to score
            let scoreMap = Dictionary(uniqueKeysWithValues: scoredChunks.map { ($0.chunkId, $0.score) })
            
            chunks = chunkContents.map { chunk in
                let score = scoreMap[chunk.chunkId] ?? 0
                return HybridSearchSystem.SearchResultChunk(
                    chunkId: chunk.chunkId,
                    content: chunk.content,
                    sourceId: chunk.sourceId,
                    score: score
                )
            }
        }

        // Apply freshness-aware and source-aware ranking
        let enhancedChunks = try await applyQualityContract(
            chunks: chunks,
            qualityContract: qualityContract,
            sourceSelection: sourceSelection
        )

        // Check for abstention conditions
        let (finalChunks, abstentionReason) = checkAbstentionConditions(
            enhancedChunks: enhancedChunks,
            qualityContract: qualityContract
        )

        // Calculate retrieval quality assessment
        let qualityAssessment = calculateRetrievalQualityAssessment(
            chunks: finalChunks,
            qualityContract: qualityContract
        )

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

        // Record search telemetry with provenance
        let diagnosticPayload: [String: String] = [
            "query_hash": queryHash,
            "mode": request.mode.rawValue,
            "fts_results": String(ftsRanks.count),
            "semantic_results": String(semanticRanks.count),
            "final_results": String(finalChunks.count),
            "embedding_model_id": request.embeddingModelId ?? "none",
            "embedding_model_hash": request.embeddingModelHash ?? "none",
            "freshness_score": String(qualityAssessment.freshnessScore),
            "source_trust_score": String(qualityAssessment.sourceTrustScore),
            "abstention_risk": String(qualityAssessment.abstentionRisk),
            "abstained": String(abstentionReason != nil)
        ]

        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .search,
            jobId: request.workflowId,
            runId: request.runId,
            durationMs: durationMs,
            outcome: abstentionReason != nil ? .failure : .success,
            diagnosticPayload: diagnosticPayload
        )
        try await database.insertEvent(event)

        return EnhancedSearchResult(
            chunks: finalChunks,
            totalResults: finalChunks.count,
            retrievalQuality: qualityAssessment,
            abstentionReason: abstentionReason
        )
    }

    private func fallbackToFullText(request: SearchRequest, queryHash: String) async throws -> [SearchResultChunk] {
        let spatialFilter = extractSpatialFilter(from: request.filters)
        let sourceSelection = extractSourceSelection(from: request.filters)
        Self.logger.warning(
            "Falling back from hybrid search to full-text search (query_hash: \(queryHash, privacy: .public), limit: \(request.limit, privacy: .public), has_spatial_filter: \(spatialFilter != nil, privacy: .public))"
        )
        let chunkIds: [String]
        if let spatialFilter = spatialFilter {
            chunkIds = try await database.searchFullTextWithSpatial(
                query: request.query,
                pageIndex: spatialFilter.pageIndex,
                boundingBox: spatialFilter.contextumBoundingBox,
                limit: request.limit,
                sourceSelection: sourceSelection
            )
        } else {
            chunkIds = try await database.searchFullText(
                query: request.query,
                limit: request.limit,
                sourceSelection: sourceSelection
            )
        }
        return try await database.getChunkContent(chunkIds: chunkIds, sourceSelection: sourceSelection)
    }

    private func getOrCreateCapsule() async throws -> ContextumRankFusionCapsuleWrapper {
        if let capsule = rankFusionCapsule {
            return capsule
        }
        let capsule = try ContextumRankFusionCapsuleWrapper()
        rankFusionCapsule = capsule
        return capsule
    }

    private func reciprocalRankFusion(
        ftsRanks: [String: Int],
        semanticRanks: [String: Int],
        k: Int = 60
    ) async throws -> [String: Double] {
        let capsule = try await getOrCreateCapsule()
        
        let rankLists = [
            RankList(ranks: ftsRanks),
            RankList(ranks: semanticRanks)
        ]
        
        return try await capsule.fuse(rankLists: rankLists)
    }

    // MARK: - Freshness-Aware and Source-Aware Retrieval Methods

    private func applyQualityContract(
        chunks: [SearchResultChunk],
        qualityContract: RetrievalQualityContract,
        sourceSelection: SourceSelectionPolicy
    ) async throws -> [EnhancedSearchResultChunk] {
        var enhancedChunks: [EnhancedSearchResultChunk] = []
        
        // Get source metadata for all chunks
        let sourceIds = chunks.map { $0.sourceId }
        let sources = try await database.getContextSources(ids: sourceIds)
        let sourceMap = Dictionary(uniqueKeysWithValues: sources.map { ($0.sourceId, $0) })
        
        // Calculate scores for each chunk
        for chunk in chunks {
            guard let source = sourceMap[chunk.sourceId] else {
                Self.logger.warning("Source not found for chunk \(chunk.chunkId, privacy: .public)")
                continue
            }
            
            // Calculate freshness score
            let freshnessScore = calculateFreshnessScore(
                source: source,
                qualityContract: qualityContract
            )
            
            // Calculate source trust score
            let sourceTrustScore = calculateSourceTrustScore(
                source: source,
                qualityContract: qualityContract
            )
            
            // Determine if source is stale
            let isStale = source.staleAt.map { $0 < Date() } ?? false
            
            // Check for conflicts
            let hasConflicts = source.conflictStatus != .none
            
            // Calculate overall confidence
            let baseConfidence = chunk.score.map { max(0.1, min(1.0, $0)) } ?? 0.5
            let confidence = calculateOverallConfidence(
                baseConfidence: baseConfidence,
                freshnessScore: freshnessScore,
                sourceTrustScore: sourceTrustScore,
                hasConflicts: hasConflicts,
                qualityContract: qualityContract
            )
            
            let sourceMetadata = SourceMetadata(
                sourceType: source.sourceType.rawValue,
                canonicalRef: source.canonicalRef ?? "unknown",
                discoveredAt: source.discoveredAt,
                lastSeenAt: source.lastSeenAt,
                staleAt: source.staleAt,
                revision: source.revision,
                conflictStatus: source.conflictStatus.rawValue,
                trustScore: sourceTrustScore
            )
            
            let enhancedChunk = EnhancedSearchResultChunk(
                chunkId: chunk.chunkId,
                content: chunk.content,
                sourceId: chunk.sourceId,
                sourceMetadata: sourceMetadata,
                score: chunk.score,
                confidence: confidence,
                freshnessScore: freshnessScore,
                sourceTrustScore: sourceTrustScore,
                isStale: isStale,
                hasConflicts: hasConflicts
            )
            
            enhancedChunks.append(enhancedChunk)
        }
        
        // Apply multi-factor ranking
        let rankedChunks = applyMultiFactorRanking(
            chunks: enhancedChunks,
            qualityContract: qualityContract
        )
        
        return rankedChunks
    }
    
    private func calculateFreshnessScore(
        source: ContextSourceComponent,
        qualityContract: RetrievalQualityContract
    ) -> Double {
        // Calculate age in days
        let ageDays = Calendar.current.dateComponents([.day], from: source.lastSeenAt, to: Date()).day ?? 0
        
        // Apply freshness policy
        if let maxAgeDays = qualityContract.freshnessPolicy.maxAgeDays,
           ageDays > maxAgeDays {
            return 0.1 // Very stale
        }
        
        // Recent boost for fresh content
        let recencyFactor = max(0.0, 1.0 - Double(ageDays) / 30.0) // 30 day window
        let recentBoost = qualityContract.freshnessPolicy.preferRecent ? recencyFactor * qualityContract.freshnessPolicy.recentBoostFactor : recencyFactor
        
        return min(1.0, max(0.1, recentBoost))
    }
    
    private func calculateSourceTrustScore(
        source: ContextSourceComponent,
        qualityContract: RetrievalQualityContract
    ) -> Double {
        let trustPolicy = qualityContract.sourceTrustPolicy
        
        // Check if source type is trusted
        let isTrustedType = trustPolicy.trustedSourceTypes.contains(source.sourceType.rawValue)
        
        // Check if source ID is trusted
        let isTrustedId = trustPolicy.trustedSourceIds.contains(source.sourceId)
        
        // Base trust score
        var trustScore: Double
        if isTrustedType || isTrustedId {
            trustScore = trustPolicy.trustBoostFactor
        } else {
            trustScore = 1.0 // Neutral
        }
        
        // Apply conflict penalty
        if source.conflictStatus != .none {
            trustScore *= 0.7 // Reduce trust for conflicted sources
        }
        
        return min(trustScore, 2.0) // Cap at 2.0
    }
    
    private func calculateOverallConfidence(
        baseConfidence: Double,
        freshnessScore: Double,
        sourceTrustScore: Double,
        hasConflicts: Bool,
        qualityContract: RetrievalQualityContract
    ) -> Double {
        let weights = qualityContract.rankingWeights
        
        // Weighted combination of factors
        let semanticContribution = baseConfidence * weights.semanticWeight
        let freshnessContribution = freshnessScore * weights.freshnessWeight
        let trustContribution = sourceTrustScore * weights.sourceTrustWeight
        
        var overallConfidence = semanticContribution + freshnessContribution + trustContribution
        
        // Apply conflict penalty
        if hasConflicts {
            overallConfidence *= 0.8
        }
        
        return max(0.01, min(1.0, overallConfidence))
    }
    
    private func applyMultiFactorRanking(
        chunks: [EnhancedSearchResultChunk],
        qualityContract: RetrievalQualityContract
    ) -> [EnhancedSearchResultChunk] {
        let weights = qualityContract.rankingWeights
        
        // Calculate composite score for each chunk
        let scoredChunks = chunks.map { chunk -> (chunk: EnhancedSearchResultChunk, score: Double) in
            let semanticScore = chunk.score ?? 0.0
            let compositeScore = (
                semanticScore * weights.semanticWeight +
                chunk.freshnessScore * weights.freshnessWeight +
                chunk.sourceTrustScore * weights.sourceTrustWeight
            )
            return (chunk, compositeScore)
        }
        
        // Sort by composite score
        let sortedChunks = scoredChunks.sorted { $0.score > $1.score }
        
        return sortedChunks.map { $0.chunk }
    }
    
    private func checkAbstentionConditions(
        enhancedChunks: [EnhancedSearchResultChunk],
        qualityContract: RetrievalQualityContract
    ) -> ([EnhancedSearchResultChunk], String?) {
        let abstentionPolicy = qualityContract.abstentionPolicy
        
        // Check for empty results
        if enhancedChunks.isEmpty {
            if abstentionPolicy.abstentionExplanationRequired {
                return ([], "No results found for query")
            }
            return ([], nil)
        }
        
        // Check for stale evidence
        if abstentionPolicy.abstainOnStaleEvidence {
            let staleChunks = enhancedChunks.filter { $0.isStale }
            if staleChunks.count == enhancedChunks.count {
                if abstentionPolicy.abstentionExplanationRequired {
                    return ([], "All evidence is stale (older than freshness threshold)")
                }
                return ([], nil)
            }
        }
        
        // Check for low confidence
        if abstentionPolicy.abstainOnLowConfidence {
            let avgConfidence = enhancedChunks.map { $0.confidence }.reduce(0.0, +) / Double(enhancedChunks.count)
            if avgConfidence < abstentionPolicy.minConfidenceThreshold {
                if abstentionPolicy.abstentionExplanationRequired {
                    return ([], String(format: "Average confidence (%.2f) below threshold (%.2f)", avgConfidence, abstentionPolicy.minConfidenceThreshold))
                }
                return ([], nil)
            }
        }
        
        // No abstention needed
        return (enhancedChunks, nil)
    }
    
    private func calculateRetrievalQualityAssessment(
        chunks: [EnhancedSearchResultChunk],
        qualityContract: RetrievalQualityContract
    ) -> RetrievalQualityAssessment {
        // Calculate average scores
        let avgConfidence = chunks.map { $0.confidence }.reduce(0.0, +) / max(1, Double(chunks.count))
        let avgFreshness = chunks.map { $0.freshnessScore }.reduce(0.0, +) / max(1, Double(chunks.count))
        let avgTrust = chunks.map { $0.sourceTrustScore }.reduce(0.0, +) / max(1, Double(chunks.count))
        
        // Calculate coverage score (percentage of non-stale chunks)
        let nonStaleCount = chunks.filter { !$0.isStale }.count
        let coverageScore = chunks.isEmpty ? 0.0 : Double(nonStaleCount) / Double(chunks.count)
        
        // Calculate conflict score (percentage without conflicts)
        let nonConflictedCount = chunks.filter { !$0.hasConflicts }.count
        let conflictScore = chunks.isEmpty ? 1.0 : Double(nonConflictedCount) / Double(chunks.count)
        
        // Calculate precision/recall metrics (simplified approach)
        // For precision: percentage of high-confidence chunks
        let highConfidenceChunks = chunks.filter { $0.confidence >= qualityContract.contextBudgetPolicy.salienceThreshold }
        let precision = chunks.isEmpty ? 0.0 : Double(highConfidenceChunks.count) / Double(chunks.count)
        
        // For recall: percentage of relevant chunks (non-stale, high trust)
        let relevantChunks = chunks.filter { !$0.isStale && $0.sourceTrustScore >= 1.0 }
        let recall = chunks.isEmpty ? 0.0 : Double(relevantChunks.count) / Double(chunks.count)
        
        // Calculate F1 score (harmonic mean of precision and recall)
        let f1Score = (precision + recall) > 0 ? 2 * (precision * recall) / (precision + recall) : 0.0
        
        // Calculate token budget compliance
        let totalTokens = chunks.map { estimateTokenCount($0.content) }.reduce(0, +)
        let budgetCompliance = calculateTokenBudgetCompliance(
            totalTokens: totalTokens,
            policy: qualityContract.contextBudgetPolicy
        )
        
        // Calculate salience coverage
        let salienceCoverage = calculateSalienceCoverage(
            chunks: chunks,
            policy: qualityContract.contextBudgetPolicy
        )
        
        // Calculate abstention risk
        let abstentionPolicy = qualityContract.abstentionPolicy
        var abstentionRisk: Double = 0.0
        
        if abstentionPolicy.abstainOnStaleEvidence {
            let staleRatio = Double(chunks.filter { $0.isStale }.count) / max(1, Double(chunks.count))
            abstentionRisk += staleRatio * 0.5
        }
        
        if abstentionPolicy.abstainOnLowConfidence && avgConfidence < abstentionPolicy.minConfidenceThreshold {
            let confidenceShortfall = max(0.0, abstentionPolicy.minConfidenceThreshold - avgConfidence)
            abstentionRisk += confidenceShortfall * 2.0
        }
        
        // Add token budget violation risk
        if budgetCompliance < 0.8 {
            abstentionRisk += (1.0 - budgetCompliance) * 0.3
        }
        
        return RetrievalQualityAssessment(
            overallConfidence: avgConfidence,
            freshnessScore: avgFreshness,
            sourceTrustScore: avgTrust,
            coverageScore: coverageScore,
            conflictScore: conflictScore,
            abstentionRisk: min(1.0, abstentionRisk),
            precision: precision,
            recall: recall,
            f1Score: f1Score,
            tokenBudgetCompliance: budgetCompliance,
            salienceCoverage: salienceCoverage
        )
    }

    private func estimateTokenCount(_ text: String) -> Int {
        // Simple token estimation: approximately 4 characters per token
        return max(1, text.count / 4)
    }

    private func calculateTokenBudgetCompliance(
        totalTokens: Int,
        policy: ContextBudgetPolicy
    ) -> Double {
        guard policy.maxTokenBudget > 0 else { return 1.0 }
        
        let ratio = Double(totalTokens) / Double(policy.maxTokenBudget)
        
        switch policy.tokenBudgetEnforcement {
        case .strict:
            return ratio <= 1.0 ? 1.0 : max(0.0, 2.0 - ratio)
        case .relaxed:
            return ratio <= 1.2 ? 1.0 : max(0.0, 1.5 - (ratio * 0.5))
        case .adaptive:
            // More lenient for adaptive mode
            return ratio <= 1.5 ? 1.0 : max(0.0, 1.2 - (ratio * 0.2))
        }
    }

    private func calculateSalienceCoverage(
        chunks: [EnhancedSearchResultChunk],
        policy: ContextBudgetPolicy
    ) -> Double {
        if chunks.isEmpty { return 0.0 }
        
        // Calculate total salience score
        let totalSalience = chunks.map { $0.confidence * $0.freshnessScore }.reduce(0.0, +)
        let maxPossibleSalience = Double(chunks.count) * 1.0 // Max confidence * max freshness
        
        // Normalize by token budget
        let totalTokens = chunks.map { estimateTokenCount($0.content) }.reduce(0, +)
        let tokenBudgetFactor = min(1.0, Double(totalTokens) / Double(policy.maxTokenBudget))
        
        // Salience coverage = (actual salience / max possible) * (1 - token overflow penalty)
        let salienceRatio = totalSalience / maxPossibleSalience
        let coverageScore = salienceRatio * (1.0 - max(0.0, tokenBudgetFactor - 1.0))
        
        return max(0.0, min(1.0, coverageScore))
    }
}
