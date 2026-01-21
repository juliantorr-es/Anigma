//
//  CLIHybridRetrieval.swift
//  AnigmaCLIDatabase
//
//  Hybrid retrieval implementation combining FTS5 lexical search with optional vector search.
//  Falls back gracefully to lexical-only when vector extension is unavailable.
//

import Foundation

/// Hybrid retrieval query engine for anigma-cli.
public actor CLIHybridRetrieval {
    private let db: CLIDatabaseActor

    public init(database: CLIDatabaseActor) {
        self.db = database
    }

    /// Perform hybrid search combining lexical and vector retrieval.
    public func search(_ request: CLIRetrievalRequest) async throws -> [CLIRetrievalHit] {
        guard request.limit > 0, request.limit <= 200 else {
            throw CLIRetrievalError.invalidLimit
        }

        let vectorAvailable = await db.isVectorAvailable()

        switch request.mode {
        case .lexical:
            return try await lexicalSearch(request)

        case .vector:
            guard vectorAvailable else {
                throw CLIRetrievalError.vectorUnavailable
            }
            return try await vectorSearch(request)

        case .hybrid:
            if vectorAvailable {
                return try await hybridSearch(request)
            } else {
                // Fall back to lexical-only
                logWarning("Vector extension unavailable, falling back to lexical search")
                return try await lexicalSearch(request)
            }
        }
    }

    // MARK: - Lexical Search (FTS5)

    private func lexicalSearch(_ request: CLIRetrievalRequest) async throws -> [CLIRetrievalHit] {
        let sql = """
            SELECT
                c.chunk_id,
                c.document_path,
                c.section_title,
                c.chunk_hash,
                bm25(document_chunks_fts) AS score
            FROM document_chunks_fts
            JOIN document_chunks c ON c.rowid = document_chunks_fts.rowid
            WHERE document_chunks_fts MATCH ?
              AND (? IS NULL OR c.document_path LIKE (? || '%'))
            ORDER BY score ASC, c.chunk_id ASC
            LIMIT ?
            """

        let params: [CLIParameter] = [
            .text(request.query),
            .text(request.pathPrefix ?? ""),
            .text(request.pathPrefix ?? ""),
            .int(request.limit)
        ]

        let rows = try await db.query(sql, parameters: params)

        return rows.compactMap { row in
            guard let chunkID = row["chunk_id"]?.asString,
                  let path = row["document_path"]?.asString,
                  let section = row["section_title"]?.asString,
                  let hash = row["chunk_hash"]?.asString,
                  let score = row["score"]?.asDouble else {
                return nil
            }

            return CLIRetrievalHit(
                chunkID: chunkID,
                sourcePath: path,
                sectionTitle: section,
                contentHash: hash,
                score: score,
                source: .lexical
            )
        }
    }

    // MARK: - Vector Search

    private func vectorSearch(_ request: CLIRetrievalRequest) async throws -> [CLIRetrievalHit] {
        guard let modelID = request.modelID else {
            throw CLIRetrievalError.missingModelID
        }

        guard let queryVector = request.queryVector else {
            throw CLIRetrievalError.missingQueryVector
        }

        // Brute-force vector search (deterministic and correct)
        let sql = """
            SELECT
                c.chunk_id,
                c.document_path,
                c.section_title,
                c.chunk_hash,
                e.dimension_count,
                e.vector
            FROM embeddings e
            JOIN document_chunks c ON c.chunk_id = e.chunk_id
            WHERE e.model_id = ?
              AND (? IS NULL OR c.document_path LIKE (? || '%'))
            """

        let params: [CLIParameter] = [
            .text(modelID),
            .text(request.pathPrefix ?? ""),
            .text(request.pathPrefix ?? "")
        ]

        let rows = try await db.query(sql, parameters: params)

        var scored: [CLIRetrievalHit] = []

        for row in rows {
            guard let chunkID = row["chunk_id"]?.asString,
                  let path = row["document_path"]?.asString,
                  let section = row["section_title"]?.asString,
                  let hash = row["chunk_hash"]?.asString,
                  let dims = row["dimension_count"]?.asInt,
                  let vectorData = row["vector"]?.asData else {
                continue
            }

            let vector = decodeFloat32Vector(vectorData, dims: dims)
            guard vector.count == queryVector.count else { continue }

            let score = cosineDistance(queryVector, vector)

            scored.append(CLIRetrievalHit(
                chunkID: chunkID,
                sourcePath: path,
                sectionTitle: section,
                contentHash: hash,
                score: score,
                source: .vector
            ))
        }

        // Sort by score (lower is better)
        scored.sort {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.chunkID < $1.chunkID
        }

        // Limit results
        if scored.count > request.limit {
            scored = Array(scored.prefix(request.limit))
        }

        return scored
    }

    // MARK: - Hybrid Search

    private func hybridSearch(_ request: CLIRetrievalRequest) async throws -> [CLIRetrievalHit] {
        // Get lexical candidates
        var lexicalRequest = request
        lexicalRequest.mode = .lexical
        let lexicalHits = try await lexicalSearch(lexicalRequest)

        // Get vector candidates if we have a query vector
        var vectorHits: [CLIRetrievalHit] = []
        if request.queryVector != nil, request.modelID != nil {
            var vectorRequest = request
            vectorRequest.mode = .vector
            vectorHits = try await vectorSearch(vectorRequest)
        }

        // Merge results
        return mergeDeterministic(lexical: lexicalHits, vector: vectorHits, limit: request.limit)
    }

    private func mergeDeterministic(
        lexical: [CLIRetrievalHit],
        vector: [CLIRetrievalHit],
        limit: Int
    ) -> [CLIRetrievalHit] {
        var merged: [String: CLIRetrievalHit] = [:]

        // Add lexical hits
        for hit in lexical {
            merged[hit.chunkID] = hit
        }

        // Merge vector hits (keep best score)
        for hit in vector {
            if let existing = merged[hit.chunkID] {
                let bestScore = min(existing.score, hit.score)
                merged[hit.chunkID] = CLIRetrievalHit(
                    chunkID: hit.chunkID,
                    sourcePath: hit.sourcePath,
                    sectionTitle: hit.sectionTitle,
                    contentHash: hit.contentHash,
                    score: bestScore,
                    source: .hybrid
                )
            } else {
                merged[hit.chunkID] = hit
            }
        }

        // Sort and limit
        var results = Array(merged.values)
        results.sort {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.chunkID < $1.chunkID
        }

        if results.count > limit {
            results = Array(results.prefix(limit))
        }

        return results
    }

    // MARK: - Vector Utilities

    private func decodeFloat32Vector(_ data: Data, dims: Int) -> [Float] {
        let count = min(dims, data.count / MemoryLayout<Float>.size)
        return data.withUnsafeBytes { raw in
            let buf = raw.bindMemory(to: Float.self)
            return Array(buf.prefix(count))
        }
    }

    private func cosineDistance(_ a: [Float], _ b: [Float]) -> Double {
        var dot: Double = 0
        var na: Double = 0
        var nb: Double = 0

        for i in 0..<a.count {
            let x = Double(a[i])
            let y = Double(b[i])
            dot += x * y
            na += x * x
            nb += y * y
        }

        if na == 0 || nb == 0 { return 1.0 }
        let cos = dot / (sqrt(na) * sqrt(nb))

        // Convert similarity to distance (lower is better)
        return 1.0 - cos
    }

    private func logWarning(_ message: String) {
        fputs("[CLIHybridRetrieval] WARNING: \(message)\n", stderr)
    }
}

// MARK: - Request/Response Types

public struct CLIRetrievalRequest: Sendable {
    public var query: String
    public var mode: CLIRetrievalMode
    public var limit: Int
    public var pathPrefix: String?
    public var modelID: String?
    public var queryVector: [Float]?

    public init(
        query: String,
        mode: CLIRetrievalMode = .hybrid,
        limit: Int = 20,
        pathPrefix: String? = nil,
        modelID: String? = nil,
        queryVector: [Float]? = nil
    ) {
        self.query = query
        self.mode = mode
        self.limit = limit
        self.pathPrefix = pathPrefix
        self.modelID = modelID
        self.queryVector = queryVector
    }
}

public enum CLIRetrievalMode: String, Sendable {
    case lexical
    case vector
    case hybrid
}

public enum CLIRetrievalSource: String, Sendable {
    case lexical
    case vector
    case hybrid
}

public struct CLIRetrievalHit: Sendable, Equatable {
    public let chunkID: String
    public let sourcePath: String
    public let sectionTitle: String
    public let contentHash: String
    public let score: Double
    public let source: CLIRetrievalSource

    public init(
        chunkID: String,
        sourcePath: String,
        sectionTitle: String,
        contentHash: String,
        score: Double,
        source: CLIRetrievalSource
    ) {
        self.chunkID = chunkID
        self.sourcePath = sourcePath
        self.sectionTitle = sectionTitle
        self.contentHash = contentHash
        self.score = score
        self.source = source
    }
}

public enum CLIRetrievalError: Error, Sendable {
    case invalidLimit
    case missingModelID
    case missingQueryVector
    case vectorUnavailable
}
