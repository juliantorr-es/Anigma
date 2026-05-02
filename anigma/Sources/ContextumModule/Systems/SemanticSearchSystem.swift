import Foundation
import CapsuleCore
import DatabaseCore
import AnigmaNativeShims

public struct SemanticSearchSystem: Sendable {
    public struct SearchRequest: Codable, Sendable {
        public let queryText: String
        public let queryEmbedding: [Float]
        public let embeddingModelId: String
        public let embeddingModelHash: String
        public let limit: Int
        public let minSimilarity: Float
        public let workflowId: String
        public let runId: String

        public init(
            queryText: String,
            queryEmbedding: [Float],
            embeddingModelId: String,
            embeddingModelHash: String,
            limit: Int = 20,
            minSimilarity: Float = 0.5,
            workflowId: String,
            runId: String
        ) {
            self.queryText = queryText
            self.queryEmbedding = queryEmbedding
            self.embeddingModelId = embeddingModelId
            self.embeddingModelHash = embeddingModelHash
            self.limit = limit
            self.minSimilarity = minSimilarity
            self.workflowId = workflowId
            self.runId = runId
        }
    }

    public struct SearchResult: Codable, Sendable {
        public let chunkHash: String
        public let similarity: Float
        public let embeddingId: String

        public init(chunkHash: String, similarity: Float, embeddingId: String) {
            self.chunkHash = chunkHash
            self.similarity = similarity
            self.embeddingId = embeddingId
        }
    }

    public init() {}

    public func search(
        request: SearchRequest,
        database: ContextumDatabase
    ) async throws -> [SearchResult] {
        // Try to use pgvector directly for performance
        if await database.isVectorAvailable() {
            let vectorString = "[\(request.queryEmbedding.map { String($0) }.joined(separator: ","))]"
            let rows = try await database.dbActor.query(
                """
                SELECT chunk_hash, (1 - (vector <=> ?::vector)) as similarity, embedding_id
                FROM contextum_embeddings
                WHERE model_hash = ?
                  AND (1 - (vector <=> ?::vector)) >= ?
                ORDER BY vector <=> ?::vector ASC
                LIMIT ?;
                """,
                parameters: [
                    .text(vectorString),
                    .text(request.embeddingModelHash),
                    .text(vectorString),
                    .double(Double(request.minSimilarity)),
                    .text(vectorString),
                    .int(request.limit)
                ]
            )
            
            return rows.compactMap { row in
                guard let chunkHash = row.string(for: "chunk_hash"),
                      let similarity = row.double(for: "similarity"),
                      let embeddingId = row.string(for: "embedding_id") else {
                    return nil
                }
                return SearchResult(
                    chunkHash: chunkHash,
                    similarity: Float(similarity),
                    embeddingId: embeddingId
                )
            }
        }

        // Fallback to legacy in-app computation
        // Bounded scan: hard cap on rows scanned
        let maxScan = 10000

        let candidates = try await database.getEmbeddingsForModel(
            modelHash: request.embeddingModelHash,
            limit: maxScan
        )

        guard !candidates.isEmpty else { return [] }

        // Nested function for manual fallback computation
        func fallbackManual(
            candidates: [ContextumDatabase.EmbeddingCandidate],
            request: SearchRequest,
            scored: inout [(chunkHash: String, similarity: Float, embeddingId: String)]
        ) {
            for candidate in candidates {
                let similarity = cosineSimilarity(
                    a: request.queryEmbedding,
                    b: candidate.vector
                )
                if similarity >= request.minSimilarity {
                    scored.append((
                        chunkHash: candidate.chunkHash,
                        similarity: similarity,
                        embeddingId: candidate.embeddingId
                    ))
                }
            }
        }

        var scored: [(chunkHash: String, similarity: Float, embeddingId: String)] = []

        // Try to use cosine similarity capsule for SIMD acceleration
        if let capsule = ContextumCosineSimilarityCapsuleWrapper.shared {
            let query = request.queryEmbedding
            let candidateVectors = candidates.map { $0.vector }
            do {
                let (similarities, _) = try await capsule.computeBatchThreshold(
                    query: query,
                    candidates: candidateVectors,
                    minSimilarity: request.minSimilarity,
                    simd: ANIGMA_COSINE_SIMD_AUTO
                )
                // Process results
                for (index, candidate) in candidates.enumerated() {
                    let similarity = similarities[index]
                    // Similarities below threshold are set to -2.0
                    if similarity >= request.minSimilarity {
                        scored.append((
                            chunkHash: candidate.chunkHash,
                            similarity: similarity,
                            embeddingId: candidate.embeddingId
                        ))
                    }
                }
            } catch {
                // Fall back to manual computation
                fallbackManual(candidates: candidates, request: request, scored: &scored)
            }
        } else {
            // Capsule not available, use manual computation
            fallbackManual(candidates: candidates, request: request, scored: &scored)
        }

        scored.sort { $0.similarity > $1.similarity }

        return scored.prefix(request.limit).map {
            SearchResult(
                chunkHash: $0.chunkHash,
                similarity: $0.similarity,
                embeddingId: $0.embeddingId
            )
        }
    }

    private func cosineSimilarity(a: [Float], b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }

        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let magnitude = sqrt(normA) * sqrt(normB)
        guard magnitude > 0 else { return 0.0 }

        return dotProduct / magnitude
    }
}

extension ContextumDatabase {
    public struct EmbeddingCandidate: Sendable {
        public let embeddingId: String
        public let chunkHash: String
        public let vector: [Float]
        
        public init(embeddingId: String, chunkHash: String, vector: [Float]) {
            self.embeddingId = embeddingId
            self.chunkHash = chunkHash
            self.vector = vector
        }
    }

    public func getEmbeddingsForModel(
        modelHash: String,
        limit: Int
    ) async throws -> [EmbeddingCandidate] {
        let rows = try await dbActor.query(
            """
            SELECT embedding_id, chunk_hash, vector_blob, vector_dimensions
            FROM contextum_embeddings
            WHERE model_hash = ?
            ORDER BY timestamp DESC
            LIMIT ?;
            """,
            parameters: [.text(modelHash), .int(limit)]
        )
        
        var candidates: [EmbeddingCandidate] = []
        
        for row in rows {
            guard let embeddingId = row.string(for: "embedding_id"),
                  let chunkHash = row.string(for: "chunk_hash"),
                  let vectorData = row.data(for: "vector_blob"),
                  let dimensions = row.int(for: "vector_dimensions") else {
                continue
            }
            
            // Deserialize vector blob (stored as array of Float32)
            let vector = vectorData.withUnsafeBytes { buffer -> [Float] in
                let floatBuffer = buffer.bindMemory(to: Float32.self)
                return floatBuffer.map { Float($0) }
            }
            
            // Validate dimensions match
            if vector.count != dimensions {
                continue
            }
            
            candidates.append(EmbeddingCandidate(
                embeddingId: embeddingId,
                chunkHash: chunkHash,
                vector: vector
            ))
        }
        
        return candidates
    }
}
