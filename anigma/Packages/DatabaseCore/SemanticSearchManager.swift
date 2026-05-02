//
//  SemanticSearchManager.swift
//  DatabaseCore
//
//  Semantic search manager for ledger content with vector-backed storage.
//

import Foundation

/// Search backend selection.
public enum SemanticSearchBackend: Sendable {
    case rowStoreFallback
    case postgresPgvector
}

/// Semantic search manager for ledger content with evidence recording.
public actor SemanticSearchManager {
    private let db: any DatabaseExecutor
    private let config: SearchConfig
    private let backend: SemanticSearchBackend

    public init(
        database: any DatabaseExecutor,
        config: SearchConfig = .default,
        backend: SemanticSearchBackend? = nil
    ) {
        self.db = database
        self.config = config

        if let backend {
            self.backend = backend
        } else if database is DatabaseActor {
            self.backend = .rowStoreFallback
        } else {
            self.backend = .postgresPgvector
        }
    }

    /// Initialize semantic search schema and indexes.
    public func initialize() async throws {
        switch backend {
        case .rowStoreFallback:
            try await initializeRowStoreSchema()
        case .postgresPgvector:
            try await initializePostgresSchema()
        }
    }

    /// Index content from a ledger event for semantic search.
    public func indexEvent(
        segmentId: String,
        eventId: String,
        contentHash: String,
        textContent: String
    ) async throws {
        let indexId = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let embedding = generateEmbedding(for: textContent)

        switch backend {
        case .rowStoreFallback:
            try await db.executeAsync("""
                INSERT OR REPLACE INTO search_index (
                    index_id, segment_id, event_id, content_hash, text_content,
                    embedding, embedding_model, indexed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                .text(indexId),
                .text(segmentId),
                .text(eventId),
                .text(contentHash),
                .text(textContent),
                .blob(encodeVectorData(embedding)),
                .text(config.embeddingModel),
                .double(now)
            ])

        case .postgresPgvector:
            try await db.executeAsync("""
                INSERT INTO search_index (
                    index_id, segment_id, event_id, content_hash, text_content,
                    embedding, embedding_model, indexed_at
                ) VALUES (
                    \(sqlLiteral(indexId)),
                    \(sqlLiteral(segmentId)),
                    \(sqlLiteral(eventId)),
                    \(sqlLiteral(contentHash)),
                    \(sqlLiteral(textContent)),
                    '\(sqlVectorLiteral(embedding))'::vector,
                    \(sqlLiteral(config.embeddingModel)),
                    \(sqlLiteral(now))
                )
                ON CONFLICT (segment_id, event_id)
                DO UPDATE SET
                    content_hash = EXCLUDED.content_hash,
                    text_content = EXCLUDED.text_content,
                    embedding = EXCLUDED.embedding,
                    embedding_model = EXCLUDED.embedding_model,
                    indexed_at = EXCLUDED.indexed_at
            """)
        }
    }

    /// Execute a semantic search query.
    public func search(
        query: String,
        userId: String? = nil,
        sessionId: String? = nil,
        filters: SearchFilters? = nil,
        limit: Int = 100
    ) async throws -> SearchResult {
        let queryId = UUID().uuidString
        let timestamp = Date()
        let startTime = Date()
        let queryEmbedding = generateEmbedding(for: query)
        let queryHash = hashContent(query)
        let effectiveLimit = max(1, limit)
        let candidateLimit = max(effectiveLimit * 4, config.indexBatchSize)
        let filtersJson = encodeFilters(filters)

        try await recordSearchQuery(
            queryId: queryId,
            query: query,
            queryHash: queryHash,
            queryEmbedding: queryEmbedding,
            timestamp: timestamp,
            userId: userId,
            sessionId: sessionId,
            filtersJson: filtersJson
        )

        let candidates = try await fetchCandidates(
            queryEmbedding: queryEmbedding,
            candidateLimit: candidateLimit
        )

        var results = candidates.compactMap { candidate -> SearchResultItem? in
            let relevanceScore = candidate.relevanceScore
            let threshold = filters?.minRelevance ?? config.minRelevanceThreshold
            guard relevanceScore >= threshold else { return nil }
            return SearchResultItem(
                segmentId: candidate.segmentId,
                eventId: candidate.eventId,
                contentHash: candidate.contentHash,
                textContent: candidate.textContent,
                relevanceScore: relevanceScore
            )
        }

        results.sort { $0.relevanceScore > $1.relevanceScore }
        results = Array(results.prefix(effectiveLimit))

        try await recordSearchResults(queryId: queryId, results: results)

        let executionTime = Int(Date().timeIntervalSince(startTime) * 1000)
        try await updateSearchQuery(
            queryId: queryId,
            resultCount: results.count,
            executionTimeMs: executionTime
        )

        return SearchResult(
            queryId: queryId,
            query: query,
            timestamp: timestamp,
            results: results,
            executionTimeMs: executionTime,
            totalCount: results.count
        )
    }

    /// Get search history for auditing.
    public func getSearchHistory(
        userId: String? = nil,
        limit: Int = 100
    ) async throws -> [SearchQueryRecord] {
        let rows: [DatabaseRow]

        switch backend {
        case .rowStoreFallback:
            var query = """
                SELECT query_id, query_text, timestamp, user_id, result_count, execution_time_ms
                FROM search_queries
                WHERE 1=1
            """
            var parameters: [DatabaseParameter] = []

            if let userId = userId {
                query += " AND user_id = ?"
                parameters.append(.text(userId))
            }

            query += " ORDER BY timestamp DESC LIMIT ?"
            parameters.append(.int(limit))

            rows = try await db.query(query, parameters: parameters)

        case .postgresPgvector:
            var query = """
                SELECT query_id, query_text, timestamp, user_id, result_count, execution_time_ms
                FROM search_queries
                WHERE 1=1
            """

            if let userId = userId {
                query += " AND user_id = \(sqlLiteral(userId))"
            }

            query += " ORDER BY timestamp DESC LIMIT \(sqlLiteral(limit))"
            rows = try await db.query(query)
        }

        return rows.compactMap { row in
            guard let queryId = row.string(for: "query_id"),
                  let queryText = row.string(for: "query_text"),
                  let timestamp = row.double(for: "timestamp") else {
                return nil
            }

            return SearchQueryRecord(
                queryId: queryId,
                queryText: queryText,
                timestamp: Date(timeIntervalSince1970: timestamp),
                userId: row.string(for: "user_id"),
                resultCount: row.int(for: "result_count") ?? 0,
                executionTimeMs: row.int(for: "execution_time_ms") ?? 0
            )
        }
    }

    /// Get search statistics for analytics.
    public func getSearchStats() async throws -> SearchStatistics {
        let totalQueries = try await db.query("""
            SELECT COUNT(*) as count FROM search_queries
        """)
        let totalCount = totalQueries.first?.int(for: "count") ?? 0

        let avgTime = try await db.query("""
            SELECT AVG(execution_time_ms) as avg_time FROM search_queries
        """)
        let avgExecutionTime = avgTime.first?.double(for: "avg_time") ?? 0.0

        let indexedEvents = try await db.query("""
            SELECT COUNT(DISTINCT event_id) as count FROM search_index
        """)
        let indexedCount = indexedEvents.first?.int(for: "count") ?? 0

        return SearchStatistics(
            totalQueries: totalCount,
            avgExecutionTimeMs: avgExecutionTime,
            indexedEvents: indexedCount
        )
    }

    /// Clear search history older than specified days.
    public func clearOldSearchHistory(olderThanDays: Int) async throws -> Int {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(olderThanDays * 86400))

        switch backend {
        case .rowStoreFallback:
            try await db.executeAsync("""
                DELETE FROM search_results
                WHERE query_id IN (
                    SELECT query_id FROM search_queries
                    WHERE timestamp < ?
                )
            """, parameters: [.double(cutoffDate.timeIntervalSince1970)])

            return try await db.executeAsync("""
                DELETE FROM search_queries
                WHERE timestamp < ?
            """, parameters: [.double(cutoffDate.timeIntervalSince1970)])

        case .postgresPgvector:
            let cutoff = sqlLiteral(cutoffDate.timeIntervalSince1970)
            try await db.executeAsync("""
                DELETE FROM search_results
                WHERE query_id IN (
                    SELECT query_id FROM search_queries
                    WHERE timestamp < \(cutoff)
                )
            """)

            return try await db.executeAsync("""
                DELETE FROM search_queries
                WHERE timestamp < \(cutoff)
            """)
        }
    }

    // MARK: - Schema

    private func initializeRowStoreSchema() async throws {
        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS search_index (
                index_id TEXT PRIMARY KEY,
                segment_id TEXT NOT NULL,
                event_id TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                text_content TEXT,
                embedding BLOB NOT NULL,
                embedding_model TEXT NOT NULL,
                indexed_at REAL NOT NULL,
                UNIQUE(segment_id, event_id)
            )
        """)

        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS search_queries (
                query_id TEXT PRIMARY KEY,
                query_text TEXT NOT NULL,
                query_hash TEXT NOT NULL,
                query_vector BLOB NOT NULL,
                timestamp REAL NOT NULL,
                user_id TEXT,
                session_id TEXT,
                result_count INTEGER,
                execution_time_ms INTEGER,
                filters_applied TEXT
            )
        """)

        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS search_results (
                result_id TEXT PRIMARY KEY,
                query_id TEXT NOT NULL,
                segment_id TEXT NOT NULL,
                event_id TEXT NOT NULL,
                relevance_score REAL,
                rank INTEGER,
                recorded_at REAL NOT NULL,
                FOREIGN KEY(query_id) REFERENCES search_queries(query_id)
            )
        """)

        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_search_content_hash ON search_index(content_hash)")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_search_segment ON search_index(segment_id)")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_search_queries_timestamp ON search_queries(timestamp)")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_search_results_query ON search_results(query_id)")
    }

    private func initializePostgresSchema() async throws {
        try await db.executeAsync("CREATE EXTENSION IF NOT EXISTS vector")

        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS search_index (
                index_id UUID PRIMARY KEY,
                segment_id TEXT NOT NULL,
                event_id TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                text_content TEXT,
                embedding vector(\(config.embeddingDimensions)) NOT NULL,
                embedding_model TEXT NOT NULL,
                indexed_at DOUBLE PRECISION NOT NULL,
                UNIQUE(segment_id, event_id)
            )
        """)

        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS search_queries (
                query_id UUID PRIMARY KEY,
                query_text TEXT NOT NULL,
                query_hash TEXT NOT NULL,
                query_vector vector(\(config.embeddingDimensions)) NOT NULL,
                timestamp DOUBLE PRECISION NOT NULL,
                user_id TEXT,
                session_id TEXT,
                result_count INTEGER,
                execution_time_ms INTEGER,
                filters_applied JSONB
            )
        """)

        try await db.executeAsync("""
            CREATE TABLE IF NOT EXISTS search_results (
                result_id UUID PRIMARY KEY,
                query_id UUID NOT NULL REFERENCES search_queries(query_id) ON DELETE CASCADE,
                segment_id TEXT NOT NULL,
                event_id TEXT NOT NULL,
                relevance_score DOUBLE PRECISION,
                rank INTEGER,
                recorded_at DOUBLE PRECISION NOT NULL
            )
        """)

        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_search_content_hash ON search_index(content_hash)")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_search_segment ON search_index(segment_id)")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_search_queries_timestamp ON search_queries(timestamp)")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_search_results_query ON search_results(query_id)")
        try await db.executeAsync("""
            CREATE INDEX IF NOT EXISTS idx_search_embedding_cosine
            ON search_index
            USING hnsw (embedding vector_cosine_ops)
        """)
    }

    // MARK: - Query Path

    private func fetchCandidates(
        queryEmbedding: [Float],
        candidateLimit: Int
    ) async throws -> [IndexedSearchCandidate] {
        switch backend {
        case .rowStoreFallback:
            let rows = try await db.query("""
                SELECT index_id, segment_id, event_id, content_hash, text_content, embedding
                FROM search_index
                ORDER BY indexed_at DESC
                LIMIT ?
            """, parameters: [.int(candidateLimit)])

            return rows.compactMap { row in
                guard let segmentId = row.string(for: "segment_id"),
                      let eventId = row.string(for: "event_id"),
                      let contentHash = row.string(for: "content_hash"),
                      let textContent = row.string(for: "text_content"),
                      let embeddingData = row.data(for: "embedding"),
                      let candidateEmbedding = decodeVectorData(embeddingData) else {
                    return nil
                }

                let relevance = combinedRelevance(
                    queryEmbedding: queryEmbedding,
                    candidateEmbedding: candidateEmbedding
                )

                return IndexedSearchCandidate(
                    segmentId: segmentId,
                    eventId: eventId,
                    contentHash: contentHash,
                    textContent: textContent,
                    relevanceScore: relevance
                )
            }

        case .postgresPgvector:
            let queryLiteral = "'\(sqlVectorLiteral(queryEmbedding))'"
            let rows = try await db.query("""
                SELECT index_id, segment_id, event_id, content_hash, text_content,
                       1.0 - (embedding <=> \(queryLiteral)::vector) AS relevance_score
                FROM search_index
                ORDER BY embedding <=> \(queryLiteral)::vector
                LIMIT \(candidateLimit)
            """)

            return rows.compactMap { row in
                guard let segmentId = row.string(for: "segment_id"),
                      let eventId = row.string(for: "event_id"),
                      let contentHash = row.string(for: "content_hash"),
                      let textContent = row.string(for: "text_content") else {
                    return nil
                }

                return IndexedSearchCandidate(
                    segmentId: segmentId,
                    eventId: eventId,
                    contentHash: contentHash,
                    textContent: textContent,
                    relevanceScore: max(0, min(1, row.double(for: "relevance_score") ?? 0))
                )
            }
        }
    }

    private func recordSearchQuery(
        queryId: String,
        query: String,
        queryHash: String,
        queryEmbedding: [Float],
        timestamp: Date,
        userId: String?,
        sessionId: String?,
        filtersJson: String?
    ) async throws {
        switch backend {
        case .rowStoreFallback:
            try await db.executeAsync("""
                INSERT INTO search_queries (
                    query_id, query_text, query_hash, query_vector,
                    timestamp, user_id, session_id, filters_applied
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                .text(queryId),
                .text(query),
                .text(queryHash),
                .blob(encodeVectorData(queryEmbedding)),
                .double(timestamp.timeIntervalSince1970),
                userId.map(DatabaseParameter.text) ?? .null,
                sessionId.map(DatabaseParameter.text) ?? .null,
                filtersJson.map(DatabaseParameter.text) ?? .null
            ])

        case .postgresPgvector:
            try await db.executeAsync("""
                INSERT INTO search_queries (
                    query_id, query_text, query_hash, query_vector,
                    timestamp, user_id, session_id, filters_applied
                ) VALUES (
                    \(sqlLiteral(queryId)),
                    \(sqlLiteral(query)),
                    \(sqlLiteral(queryHash)),
                    '\(sqlVectorLiteral(queryEmbedding))'::vector,
                    \(sqlLiteral(timestamp.timeIntervalSince1970)),
                    \(sqlNullableLiteral(userId)),
                    \(sqlNullableLiteral(sessionId)),
                    \(sqlNullableLiteral(filtersJson))
                )
            """)
        }
    }

    private func recordSearchResults(queryId: String, results: [SearchResultItem]) async throws {
        for (rank, result) in results.enumerated() {
            let resultId = UUID().uuidString
            switch backend {
            case .rowStoreFallback:
                try await db.executeAsync("""
                    INSERT INTO search_results (
                        result_id, query_id, segment_id, event_id,
                        relevance_score, rank, recorded_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """, parameters: [
                    .text(resultId),
                    .text(queryId),
                    .text(result.segmentId),
                    .text(result.eventId),
                    .double(result.relevanceScore),
                    .int(rank),
                    .double(Date().timeIntervalSince1970)
                ])

            case .postgresPgvector:
                try await db.executeAsync("""
                    INSERT INTO search_results (
                        result_id, query_id, segment_id, event_id,
                        relevance_score, rank, recorded_at
                    ) VALUES (
                        \(sqlLiteral(resultId)),
                        \(sqlLiteral(queryId)),
                        \(sqlLiteral(result.segmentId)),
                        \(sqlLiteral(result.eventId)),
                        \(sqlLiteral(result.relevanceScore)),
                        \(sqlLiteral(rank)),
                        \(sqlLiteral(Date().timeIntervalSince1970))
                    )
                """)
            }
        }
    }

    private func updateSearchQuery(
        queryId: String,
        resultCount: Int,
        executionTimeMs: Int
    ) async throws {
        switch backend {
        case .rowStoreFallback:
            try await db.executeAsync("""
                UPDATE search_queries
                SET result_count = ?, execution_time_ms = ?
                WHERE query_id = ?
            """, parameters: [
                .int(resultCount),
                .int(executionTimeMs),
                .text(queryId)
            ])

        case .postgresPgvector:
            try await db.executeAsync("""
                UPDATE search_queries
                SET result_count = \(sqlLiteral(resultCount)),
                    execution_time_ms = \(sqlLiteral(executionTimeMs))
                WHERE query_id = \(sqlLiteral(queryId))
            """)
        }
    }

    // MARK: - Vector Helpers

    /// Generate a stable embedding for content.
    private func generateEmbedding(for text: String) -> [Float] {
        let dimension = max(1, config.embeddingDimensions)
        var vector = Array(repeating: Float(0), count: dimension)
        let tokens = tokenize(text)

        guard !tokens.isEmpty else {
            return vector
        }

        for token in tokens {
            let hash = stableTokenHash(token)
            let primaryIndex = hash % dimension
            vector[primaryIndex] += 1

            let secondaryIndex = (hash >> 11) % dimension
            vector[secondaryIndex] += 0.5
        }

        normalize(&vector)
        return vector
    }

    private func combinedRelevance(
        queryEmbedding: [Float],
        candidateEmbedding: [Float]
    ) -> Double {
        return max(0, cosineSimilarity(queryEmbedding, candidateEmbedding))
    }

    private func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Double {
        let count = min(lhs.count, rhs.count)
        guard count > 0 else { return 0 }

        var dot: Double = 0
        var lhsMagnitude: Double = 0
        var rhsMagnitude: Double = 0

        for index in 0..<count {
            let left = Double(lhs[index])
            let right = Double(rhs[index])
            dot += left * right
            lhsMagnitude += left * left
            rhsMagnitude += right * right
        }

        let denominator = sqrt(lhsMagnitude) * sqrt(rhsMagnitude)
        guard denominator > 0 else { return 0 }
        return dot / denominator
    }

    private func normalize(_ vector: inout [Float]) {
        let magnitude = sqrt(vector.reduce(0.0) { $0 + Double($1 * $1) })
        guard magnitude > 0 else { return }
        let scale = Float(1.0 / magnitude)
        for index in vector.indices {
            vector[index] *= scale
        }
    }

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func stableTokenHash(_ token: String) -> Int {
        var hash = 5381
        for byte in token.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return Swift.abs(hash)
    }

    private func encodeVectorData(_ vector: [Float]) -> Data {
        var data = Data()
        data.reserveCapacity(vector.count * MemoryLayout<Float32>.size)

        for value in vector {
            var bits = value.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { rawBuffer in
                data.append(contentsOf: rawBuffer)
            }
        }

        return data
    }

    private func decodeVectorData(_ data: Data) -> [Float]? {
        let elementSize = MemoryLayout<UInt32>.size
        guard data.count % elementSize == 0 else { return nil }

        var vector: [Float] = []
        vector.reserveCapacity(data.count / elementSize)

        for offset in stride(from: 0, to: data.count, by: elementSize) {
            var word: UInt32 = 0
            _ = withUnsafeMutableBytes(of: &word) { buffer in
                data.copyBytes(to: buffer, from: offset..<(offset + elementSize))
            }
            vector.append(Float(bitPattern: UInt32(littleEndian: word)))
        }

        return vector
    }

    // MARK: - SQL Helpers

    private func sqlLiteral(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }

    private func sqlLiteral(_ value: Int) -> String {
        String(value)
    }

    private func sqlLiteral(_ value: Double) -> String {
        String(format: "%.12f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func sqlNullableLiteral(_ value: String?) -> String {
        value.map(sqlLiteral) ?? "NULL"
    }

    private func sqlVectorLiteral(_ vector: [Float]) -> String {
        let body = vector.map { String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), $0) }
            .joined(separator: ",")
        return "[\(body)]"
    }

    private func encodeFilters(_ filters: SearchFilters?) -> String? {
        guard let filters else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(filters) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Hash content for deduplication and matching.
    private func hashContent(_ content: String) -> String {
        var hash = 0
        for char in content.utf8 {
            hash = hash &* 31 &+ Int(char)
        }
        return String(format: "%016x", Swift.abs(hash))
    }
}

// MARK: - Configuration and Data Types

/// Search configuration.
public struct SearchConfig: Sendable {
    public let embeddingModel: String
    public let embeddingDimensions: Int
    public let minRelevanceThreshold: Double
    public let maxQueryCacheSize: Int
    public let indexBatchSize: Int

    public static let `default` = SearchConfig(
        embeddingModel: "text-embedding-default",
        embeddingDimensions: 256,
        minRelevanceThreshold: 0.1,
        maxQueryCacheSize: 1000,
        indexBatchSize: 100
    )

    public init(
        embeddingModel: String = "text-embedding-default",
        embeddingDimensions: Int = 256,
        minRelevanceThreshold: Double = 0.1,
        maxQueryCacheSize: Int = 1000,
        indexBatchSize: Int = 100
    ) {
        self.embeddingModel = embeddingModel
        self.embeddingDimensions = embeddingDimensions
        self.minRelevanceThreshold = minRelevanceThreshold
        self.maxQueryCacheSize = maxQueryCacheSize
        self.indexBatchSize = indexBatchSize
    }
}

/// Search filters.
public struct SearchFilters: Sendable, Codable {
    public let eventTypes: [String]?
    public let agentIds: [String]?
    public let dateRange: DateRange?
    public let minRelevance: Double?

    public init(
        eventTypes: [String]? = nil,
        agentIds: [String]? = nil,
        dateRange: DateRange? = nil,
        minRelevance: Double? = nil
    ) {
        self.eventTypes = eventTypes
        self.agentIds = agentIds
        self.dateRange = dateRange
        self.minRelevance = minRelevance
    }
}

/// Date range for filtering.
public struct DateRange: Sendable, Codable {
    public let from: Date
    public let to: Date

    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }
}

/// Search result item.
public struct SearchResultItem: Sendable, Codable {
    public let segmentId: String
    public let eventId: String
    public let contentHash: String
    public let textContent: String
    public let relevanceScore: Double
}

/// Complete search result.
public struct SearchResult: Sendable, Codable {
    public let queryId: String
    public let query: String
    public let timestamp: Date
    public let results: [SearchResultItem]
    public let executionTimeMs: Int
    public let totalCount: Int
}

/// Search query record for auditing.
public struct SearchQueryRecord: Sendable, Codable {
    public let queryId: String
    public let queryText: String
    public let timestamp: Date
    public let userId: String?
    public let resultCount: Int
    public let executionTimeMs: Int
}

/// Search statistics.
public struct SearchStatistics: Sendable, Codable {
    public let totalQueries: Int
    public let avgExecutionTimeMs: Double
    public let indexedEvents: Int
}

private struct IndexedSearchCandidate: Sendable {
    let segmentId: String
    let eventId: String
    let contentHash: String
    let textContent: String
    let relevanceScore: Double
}
