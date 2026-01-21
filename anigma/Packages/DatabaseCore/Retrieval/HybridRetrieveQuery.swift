//
//  HybridRetrieveQuery.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

// Assumes DatabaseActor (or equivalent) exists with:
//   func query(_ sql: String, _ params: [DatabaseParameter]) async throws -> [[String: DatabaseValue]]
// Adjust the call site if your DB abstraction differs; the SQL and decoding are the point.

public protocol EmbeddingQueryProvider: Sendable {
    func embeddingVector(for query: String, modelID: String) async throws -> [Float]
}

public struct HybridRetrieveQuery: Sendable {
    private let db: DatabaseActor
    private let embedder: EmbeddingQueryProvider?

    public init(db: DatabaseActor, embedder: EmbeddingQueryProvider?) {
        self.db = db
        self.embedder = embedder
    }

    public func run(_ request: RetrievalRequest) async throws -> [RetrievalHit] {
        guard request.limit > 0 && request.limit <= 200 else { throw RetrievalError.invalidLimit }

        var hits: [RetrievalHit] = []

        switch request.mode {
        case .lexical:
            hits = try await lexical(request)
        case .vector:
            hits = try await vector(request)
        case .hybrid:
            let a = try await lexical(request)
            let b = try await vector(request)
            hits = mergeDeterministic(fts: a, vec: b, limit: request.limit)
        }

        return hits
    }

    private func lexical(_ request: RetrievalRequest) async throws -> [RetrievalHit] {
        // Rank uses bm25; deterministic tie-breaks by chunk_id.
        let sql =
        """
        SELECT c.chunk_id, c.document_path as source_path, c.section_title, c.chunk_hash as content_hash_sha256,
               bm25(document_chunks_fts) AS score
        FROM document_chunks_fts
        JOIN document_chunks c ON c.rowid = document_chunks_fts.rowid
        WHERE document_chunks_fts MATCH ?
          AND (? IS NULL OR c.document_path LIKE (? || '%'))
        ORDER BY score ASC, c.chunk_id ASC
        LIMIT ?
        """

        let params: [DatabaseParameter] = [
            dbp(request.query),
            dbp(request.pathPrefix),
            dbp(request.pathPrefix),
            dbp(request.limit)
        ]

        let rows = try await db.query(sql, parameters: params)
        return rows.compactMap { row in
            guard
                let chunkID = row["chunk_id"]?.asString,
                let path = row["source_path"]?.asString,
                let section = row["section_title"]?.asString,
                let hash = row["content_hash_sha256"]?.asString,
                let score = row["score"]?.asDouble
            else { return nil }
            return RetrievalHit(
                chunkID: chunkID,
                sourcePath: path,
                sectionTitle: section,
                contentHashSHA256: hash,
                score: score,
                source: .fts
            )
        }
    }

    private func vector(_ request: RetrievalRequest) async throws -> [RetrievalHit] {
        guard let modelID = request.modelID else { throw RetrievalError.missingModelID }
        guard let embedder else { throw RetrievalError.missingEmbeddingQueryVector }

        let q = try await embedder.embeddingVector(for: request.query, modelID: modelID)

        // Pull candidate vectors. Start brute-force with optional path prefix filter.
        // This keeps correctness/governance first and avoids a heavy index dependency.
        let sql =
        """
        SELECT c.chunk_id, c.document_path as source_path, c.section_title, c.chunk_hash as content_hash_sha256,
               e.dimension_count as dims, e.vector as vector_f32
        FROM embeddings e
        JOIN document_chunks c ON c.chunk_id = e.chunk_id
        WHERE e.model_id = ?
          AND (? IS NULL OR c.document_path LIKE (? || '%'))
        """
        let params: [DatabaseParameter] = [dbp(modelID), dbp(request.pathPrefix), dbp(request.pathPrefix)]
        let rows = try await db.query(sql, parameters: params)

        var scored: [RetrievalHit] = []
        scored.reserveCapacity(min(rows.count, request.limit))

        for row in rows {
            guard
                let chunkID = row["chunk_id"]?.asString,
                let path = row["source_path"]?.asString,
                let section = row["section_title"]?.asString,
                let hash = row["content_hash_sha256"]?.asString,
                let dims = row["dims"]?.asInt,
                let blob = row["vector_f32"]?.asData
            else { continue }

            let v = decodeFloat32Vector(blob, dims: dims)
            guard v.count == q.count else { continue }
            let score = cosineDistance(q, v) // lower is better, like bm25 ASC

            scored.append(RetrievalHit(
                chunkID: chunkID,
                sourcePath: path,
                sectionTitle: section,
                contentHashSHA256: hash,
                score: score,
                source: .embedding
            ))
        }

        scored.sort {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.chunkID < $1.chunkID
        }

        if scored.count > request.limit { scored.removeSubrange(request.limit..<scored.count) }
        return scored
    }

    private func mergeDeterministic(fts: [RetrievalHit], vec: [RetrievalHit], limit: Int) -> [RetrievalHit] {
        var merged: [String: RetrievalHit] = [:]

        for h in fts {
            merged[h.chunkID] = h
        }
        for h in vec {
            if let existing = merged[h.chunkID] {
                // Deterministic merge: keep best (lower score), mark as merged.
                let keep = (h.score < existing.score) ? h : existing
                merged[h.chunkID] = RetrievalHit(
                    chunkID: keep.chunkID,
                    sourcePath: keep.sourcePath,
                    sectionTitle: keep.sectionTitle,
                    contentHashSHA256: keep.contentHashSHA256,
                    score: min(existing.score, h.score),
                    source: .merged
                )
            } else {
                merged[h.chunkID] = h
            }
        }

        var out = Array(merged.values)
        out.sort {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.chunkID < $1.chunkID
        }
        if out.count > limit { out.removeSubrange(limit..<out.count) }
        return out
    }
}

@inline(__always)
private func decodeFloat32Vector(_ data: Data, dims: Int) -> [Float] {
    let count = min(dims, data.count / MemoryLayout<Float>.size)
    return data.withUnsafeBytes { raw in
        let buf = raw.bindMemory(to: Float.self)
        return Array(buf.prefix(count))
    }
}

@inline(__always)
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
    // Convert similarity to distance (lower is better).
    return 1.0 - cos
}
