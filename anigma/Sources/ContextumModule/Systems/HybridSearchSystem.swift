import Foundation
import CryptoKit

extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

public actor HybridSearchSystem {
    private let database: ContextumDatabase
    private let semanticSearch: SemanticSearchSystem
    private var rankFusionCapsule: RankFusionCapsuleWrapper?

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
            runId: String
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

    public func search(_ request: SearchRequest) async throws -> SearchResult {
        let startTime = Date()
        let queryHash = SHA256.hash(data: Data(request.query.utf8)).hexString
        let spatialFilter = extractSpatialFilter(from: request.filters)

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
                    boundingBox: spatialFilter.boundingBox,
                    limit: request.limit
                )
            } else {
                chunkIds = try await database.searchFullText(query: request.query, limit: request.limit)
            }
            chunks = try await database.getChunkContent(chunkIds: chunkIds)

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
            let chunkIdMap = try await database.getChunkHashToIdMap(chunkHashes: chunkHashes)
            var chunkIds = chunkHashes.compactMap { chunkIdMap[$0] }
            
            // Apply spatial filter if present
            if let spatialFilter = spatialFilter {
                chunkIds = try await database.filterChunksBySpatial(
                    chunkIds: chunkIds,
                    pageIndex: spatialFilter.pageIndex,
                    boundingBox: spatialFilter.boundingBox
                )
            }
            
            // Create mapping from chunkId to similarity
            var chunkIdToSimilarity: [String: Float] = [:]
            for result in results {
                if let chunkId = chunkIdMap[result.chunkHash] {
                    chunkIdToSimilarity[chunkId] = result.similarity
                }
            }
            
            chunks = try await database.getChunkContent(chunkIds: chunkIds)
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
                chunks = try await fallbackToFullText(request: request)
                break
            }

            // Run both searches
            let ftsChunkIds: [String]
            if let spatialFilter = spatialFilter {
                ftsChunkIds = try await database.searchFullTextWithSpatial(
                    query: request.query,
                    pageIndex: spatialFilter.pageIndex,
                    boundingBox: spatialFilter.boundingBox,
                    limit: request.limit * 2
                )
            } else {
                ftsChunkIds = try await database.searchFullText(query: request.query, limit: request.limit * 2)
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
            let semanticChunkMap = try await database.getChunkHashToIdMap(chunkHashes: semanticChunkHashes)
            var semanticChunkIds = semanticChunkHashes.compactMap { semanticChunkMap[$0] }
            
            // Apply spatial filter to semantic results
            if let spatialFilter = spatialFilter {
                semanticChunkIds = try await database.filterChunksBySpatial(
                    chunkIds: semanticChunkIds,
                    pageIndex: spatialFilter.pageIndex,
                    boundingBox: spatialFilter.boundingBox
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

            chunks = try await database.getChunkContent(chunkIds: topChunkIds)
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
                boundingBox: spatialFilter?.boundingBox,
                limit: request.limit
            )
            // Get content for scored chunks
            let chunkIds = scoredChunks.map { $0.chunkId }
            let chunkContents = try await database.getChunkContent(chunkIds: chunkIds)
            
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

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

        // Record search telemetry with provenance
        let diagnosticPayload: [String: String] = [
            "query_hash": queryHash,
            "mode": request.mode.rawValue,
            "fts_results": String(ftsRanks.count),
            "semantic_results": String(semanticRanks.count),
            "final_results": String(chunks.count),
            "embedding_model_id": request.embeddingModelId ?? "none",
            "embedding_model_hash": request.embeddingModelHash ?? "none"
        ]

        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .search,
            jobId: request.workflowId,
            runId: request.runId,
            durationMs: durationMs,
            outcome: .success,
            diagnosticPayload: diagnosticPayload
        )
        try await database.insertEvent(event)

        return SearchResult(chunks: chunks, totalResults: chunks.count)
    }

    private func fallbackToFullText(request: SearchRequest) async throws -> [SearchResultChunk] {
        let spatialFilter = extractSpatialFilter(from: request.filters)
        let chunkIds: [String]
        if let spatialFilter = spatialFilter {
            chunkIds = try await database.searchFullTextWithSpatial(
                query: request.query,
                pageIndex: spatialFilter.pageIndex,
                boundingBox: spatialFilter.boundingBox,
                limit: request.limit
            )
        } else {
            chunkIds = try await database.searchFullText(query: request.query, limit: request.limit)
        }
        return try await database.getChunkContent(chunkIds: chunkIds)
    }

    private func getOrCreateCapsule() async throws -> RankFusionCapsuleWrapper {
        if let capsule = rankFusionCapsule {
            return capsule
        }
        let capsule = try RankFusionCapsuleWrapper()
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
}
