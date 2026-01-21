//
//  SemanticSearchManager.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Semantic search manager for ledger content with evidence recording.
public actor SemanticSearchManager {
    private let db: DatabaseActor
    private let config: SearchConfig

    public init(database: DatabaseActor, config: SearchConfig = .default) {
        self.db = database
        self.config = config
    }

    /// Initialize semantic search schema and indexes.
    public func initialize() async throws {
        // Create search index table
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS search_index (
                index_id TEXT PRIMARY KEY,
                segment_id TEXT NOT NULL,
                event_id TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                text_content TEXT,
                embedding BLOB,
                embedding_model TEXT,
                indexed_at REAL NOT NULL,
                UNIQUE(segment_id, event_id)
            )
        """)

        // Create search queries audit table
        try await db.execute("""
            CREATE TABLE IF NOT EXISTS search_queries (
                query_id TEXT PRIMARY KEY,
                query_text TEXT NOT NULL,
                query_hash TEXT NOT NULL,
                query_vector BLOB,
                timestamp REAL NOT NULL,
                user_id TEXT,
                session_id TEXT,
                result_count INTEGER,
                execution_time_ms INTEGER,
                filters_applied TEXT
            )
        """)

        // Create search results audit table
        try await db.execute("""
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

        // Create indexes for performance
        try await db.execute("CREATE INDEX IF NOT EXISTS idx_search_content_hash ON search_index(content_hash)")
        try await db.execute("CREATE INDEX IF NOT EXISTS idx_search_segment ON search_index(segment_id)")
        try await db.execute("CREATE INDEX IF NOT EXISTS idx_search_queries_timestamp ON search_queries(timestamp)")
        try await db.execute("CREATE INDEX IF NOT EXISTS idx_search_results_query ON search_results(query_id)")
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

        // Generate embedding using simple hash-based approach (fallback for demo)
        let embedding = try generateEmbedding(for: textContent)

        try await db.execute("""
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
            .blob(embedding),
            .text(config.embeddingModel),
            .double(now)
        ])
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
        let now = Date()
        let startTime = Date()

        // Generate query embedding
        let queryEmbedding = try generateEmbedding(for: query)
        let queryHash = hashContent(query)

        // Record the search query
        let filtersJson = filters.flatMap { try? JSONEncoder().encode($0).base64EncodedString() }

        try await db.execute("""
            INSERT INTO search_queries (
                query_id, query_text, query_hash, query_vector,
                timestamp, user_id, session_id, filters_applied
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            .text(queryId),
            .text(query),
            .text(queryHash),
            .blob(queryEmbedding),
            .double(now.timeIntervalSince1970),
            .text(userId ?? ""),
            .text(sessionId ?? ""),
            .text(filtersJson ?? "")
        ])

        // Execute semantic search
        var results: [SearchResultItem] = []

        // Get all indexed events from all segments
        let indexedRows = try await db.query("""
            SELECT index_id, segment_id, event_id, content_hash, text_content, embedding
            FROM search_index
            ORDER BY indexed_at DESC
            LIMIT ?
        """, parameters: [.int(limit * 2)])

        // Calculate relevance scores
        for row in indexedRows {
            guard let segmentId = row.string(for: "segment_id"),
                  let eventId = row.string(for: "event_id"),
                  let contentHash = row.string(for: "content_hash"),
                  let textContent = row.string(for: "text_content"),
                  let _ = row.data(for: "embedding") else {
                continue
            }

            // Calculate similarity score (simple text matching for demo)
            let relevanceScore = calculateRelevance(query: query, text: textContent)

            if relevanceScore > config.minRelevanceThreshold {
                results.append(SearchResultItem(
                    segmentId: segmentId,
                    eventId: eventId,
                    contentHash: contentHash,
                    textContent: textContent,
                    relevanceScore: relevanceScore
                ))
            }
        }

        // Sort by relevance
        results.sort { $0.relevanceScore > $1.relevanceScore }
        results = Array(results.prefix(limit))

        // Record results
        for (rank, result) in results.enumerated() {
            let resultId = UUID().uuidString
            try await db.execute("""
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
        }

        // Update query with result count and execution time
        let executionTime = Int(Date().timeIntervalSince(startTime) * 1000)
        try await db.execute("""
            UPDATE search_queries
            SET result_count = ?, execution_time_ms = ?
            WHERE query_id = ?
        """, parameters: [
            .int(results.count),
            .int(executionTime),
            .text(queryId)
        ])

        return SearchResult(
            queryId: queryId,
            query: query,
            timestamp: now,
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

        let rows = try await db.query(query, parameters: parameters)

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

        // Delete old search results
        try await db.execute("""
            DELETE FROM search_results
            WHERE query_id IN (
                SELECT query_id FROM search_queries
                WHERE timestamp < ?
            )
        """, parameters: [.double(cutoffDate.timeIntervalSince1970)])

        // Delete old search queries
        let result = try await db.execute("""
            DELETE FROM search_queries
            WHERE timestamp < ?
        """, parameters: [.double(cutoffDate.timeIntervalSince1970)])

        return result
    }

    // MARK: - Private Helpers

    /// Generate embedding for content (simplified for demo).
    private func generateEmbedding(for text: String) throws -> Data {
        // Simplified embedding: hash-based representation
        // In production, would use actual ML models
        let hash = hashContent(text)
        return hash.data(using: .utf8) ?? Data()
    }

    /// Calculate relevance score between query and text.
    private func calculateRelevance(query: String, text: String) -> Double {
        let queryLower = query.lowercased()
        let textLower = text.lowercased()

        // Simple token-based relevance scoring
        let queryTokens = Set(queryLower.split(separator: " ").map(String.init))
        let textTokens = Set(textLower.split(separator: " ").map(String.init))

        let intersection = queryTokens.intersection(textTokens).count
        let union = queryTokens.union(textTokens).count

        let jaccardSimilarity = union > 0 ? Double(intersection) / Double(union) : 0.0

        // Boost score if query appears as substring
        if textLower.contains(queryLower) {
            return min(1.0, jaccardSimilarity + 0.5)
        }

        return jaccardSimilarity
    }

    /// Hash content for deduplication and matching.
    private func hashContent(_ content: String) -> String {
        // Simple hash for demo; production would use proper crypto
        var hash = 0
        for char in content.utf8 {
            hash = hash &* 31 &+ Int(char)
        }
        return String(format: "%016x", abs(hash))
    }
}

// MARK: - Configuration and Data Types

/// Search configuration.
public struct SearchConfig: Sendable {
    public let embeddingModel: String
    public let minRelevanceThreshold: Double
    public let maxQueryCacheSize: Int
    public let indexBatchSize: Int

    public static let `default` = SearchConfig(
        embeddingModel: "text-embedding-default",
        minRelevanceThreshold: 0.1,
        maxQueryCacheSize: 1000,
        indexBatchSize: 100
    )

    public init(
        embeddingModel: String = "text-embedding-default",
        minRelevanceThreshold: Double = 0.1,
        maxQueryCacheSize: Int = 1000,
        indexBatchSize: Int = 100
    ) {
        self.embeddingModel = embeddingModel
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
