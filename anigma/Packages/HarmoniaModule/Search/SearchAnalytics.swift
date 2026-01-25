//
//  SearchAnalytics.swift
//  HarmoniaModule
//
//  Search pattern tracking, content gap identification, and performance metrics.
//

import AnigmaPrimitives
import DatabaseCore
@preconcurrency import Foundation

/// Search analytics metrics
public struct SearchAnalyticsMetrics: Sendable, Codable {
    /// Total queries in period
    public let totalQueries: Int

    /// Unique users
    public let uniqueUsers: Int

    /// Average results per query
    public let averageResultsPerQuery: Double

    /// Click-through rate
    public let clickThroughRate: Double

    /// Average ranking of clicked result
    public let averageClickedRank: Double

    /// Content gap areas (queries with no results)
    public let contentGaps: [ContentGap]

    /// Most common queries
    public let mostCommonQueries: [QueryFrequency]

    /// Performance metrics
    public let queryLatencyMs: Double

    /// Coverage metric (0-1)
    public let contentCoverage: Double

    public init(
        totalQueries: Int,
        uniqueUsers: Int,
        averageResultsPerQuery: Double,
        clickThroughRate: Double,
        averageClickedRank: Double,
        contentGaps: [ContentGap],
        mostCommonQueries: [QueryFrequency],
        queryLatencyMs: Double,
        contentCoverage: Double
    ) {
        self.totalQueries = totalQueries
        self.uniqueUsers = uniqueUsers
        self.averageResultsPerQuery = averageResultsPerQuery
        self.clickThroughRate = clickThroughRate
        self.averageClickedRank = averageClickedRank
        self.contentGaps = contentGaps
        self.mostCommonQueries = mostCommonQueries
        self.queryLatencyMs = queryLatencyMs
        self.contentCoverage = contentCoverage
    }
}

/// Content gap (underserved area)
public struct ContentGap: Sendable, Codable {
    /// Query that had no results
    public let query: String

    /// Number of times requested
    public let requestCount: Int

    /// Last time this gap was discovered
    public let lastRequested: Date

    /// Suggested action
    public let suggestion: String

    public init(
        query: String,
        requestCount: Int,
        lastRequested: Date,
        suggestion: String
    ) {
        self.query = query
        self.requestCount = requestCount
        self.lastRequested = lastRequested
        self.suggestion = suggestion
    }
}

/// Query frequency
public struct QueryFrequency: Sendable, Codable {
    public let query: String
    public let count: Int
    public let lastQueried: Date

    public init(
        query: String,
        count: Int,
        lastQueried: Date
    ) {
        self.query = query
        self.count = count
        self.lastQueried = lastQueried
    }
}

/// Search session metrics
public struct SessionMetrics: Sendable, Codable {
    public let sessionId: String
    public let userId: String
    public let startTime: Date
    public var endTime: Date?
    public let queriesPerformed: Int
    public let resultClicks: Int
    public let sessionsInactiveMinutes: Int

    public init(
        sessionId: String,
        userId: String,
        startTime: Date,
        endTime: Date? = nil,
        queriesPerformed: Int,
        resultClicks: Int,
        sessionsInactiveMinutes: Int
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.startTime = startTime
        self.endTime = endTime
        self.queriesPerformed = queriesPerformed
        self.resultClicks = resultClicks
        self.sessionsInactiveMinutes = sessionsInactiveMinutes
    }
}

/// Search analytics and metrics tracking
public actor SearchAnalytics {
    private let dbActor: DatabaseActor?
    private var schemaInitialized = false

    public init(dbActor: DatabaseActor? = nil) {
        self.dbActor = dbActor
    }

    /// Record a search query
    public func recordQuery(
        query: String,
        userId: String,
        resultCount: Int
    ) async throws -> String {
        try await ensureSchema()
        guard let db = dbActor else {
            return UUID().uuidString
        }

        let queryId = UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)

        try await db.execute(
            """
            INSERT INTO search_queries (id, query, user_id, result_count, query_timestamp)
            VALUES (?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(queryId),
                .text(query),
                .text(userId),
                .int(resultCount),
                .int(timestamp)
            ]
        )

        return queryId
    }

    /// Record a result click
    public func recordClick(
        queryId: String,
        resultId: String,
        resultRank: Int
    ) async throws {
        try await ensureSchema()
        guard let db = dbActor else { return }

        let timestamp = Int(Date().timeIntervalSince1970)

        try await db.execute(
            """
            INSERT INTO search_clicks (id, query_id, result_id, result_rank, clicked_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(UUID().uuidString),
                .text(queryId),
                .text(resultId),
                .int(resultRank),
                .int(timestamp)
            ]
        )
    }

    /// Get search analytics
    public func getAnalytics(
        windowDays: Int = 30
    ) async throws -> SearchAnalyticsMetrics {
        try await ensureSchema()
        guard let db = dbActor else {
            return SearchAnalyticsMetrics(
                totalQueries: 0,
                uniqueUsers: 0,
                averageResultsPerQuery: 0,
                clickThroughRate: 0,
                averageClickedRank: 0,
                contentGaps: [],
                mostCommonQueries: [],
                queryLatencyMs: 0,
                contentCoverage: 0
            )
        }

        let cutoff = Int(Date().timeIntervalSince1970) - (windowDays * 86400)

        // Total queries and unique users
        let queryRows = try await db.executeQuery(
            """
            SELECT COUNT(*) as total, COUNT(DISTINCT user_id) as users, AVG(result_count) as avg_results
            FROM search_queries
            WHERE query_timestamp > ?
            """,
            parameters: [.int(cutoff)]
        )

        var totalQueries = 0
        var uniqueUsers = 0
        var avgResults = 0.0

        if let row = queryRows.first {
            totalQueries = row.int(for: "total") ?? 0
            uniqueUsers = row.int(for: "users") ?? 0
            avgResults = row.double(for: "avg_results") ?? 0.0
        }

        // Click-through metrics
        let clickRows = try await db.executeQuery(
            """
            SELECT COUNT(*) as clicks, AVG(result_rank) as avg_rank
            FROM search_clicks
            WHERE clicked_at > (strftime('%s', 'now') - ?)
            """,
            parameters: [.int(windowDays * 86400)]
        )

        var ctrRate = 0.0
        var avgClickedRank = 0.0

        if let row = clickRows.first,
           let clicks = row.int(for: "clicks") {
            ctrRate = totalQueries > 0 ? Double(clicks) / Double(totalQueries) : 0.0
            avgClickedRank = row.double(for: "avg_rank") ?? 0.0
        }

        // Content gaps (queries with no results)
        let gapRows = try await db.executeQuery(
            """
            SELECT query, COUNT(*) as count, MAX(query_timestamp) as last_time
            FROM search_queries
            WHERE result_count = 0 AND query_timestamp > ?
            GROUP BY query
            ORDER BY count DESC
            LIMIT 20
            """,
            parameters: [.int(cutoff)]
        )

        var gaps: [ContentGap] = []
        for row in gapRows {
            guard let query = row.string(for: "query"),
                  let count = row.int(for: "count") else {
                continue
            }

            let lastTimestamp = row.int(for: "last_time") ?? Int(Date().timeIntervalSince1970)

            gaps.append(ContentGap(
                query: query,
                requestCount: count,
                lastRequested: Date(timeIntervalSince1970: TimeInterval(lastTimestamp)),
                suggestion: "Create or document content for: \(query)"
            ))
        }

        // Most common queries
        let frequencyRows = try await db.executeQuery(
            """
            SELECT query, COUNT(*) as count, MAX(query_timestamp) as last_time
            FROM search_queries
            WHERE query_timestamp > ?
            GROUP BY query
            ORDER BY count DESC
            LIMIT 20
            """,
            parameters: [.int(cutoff)]
        )

        var mostCommon: [QueryFrequency] = []
        for row in frequencyRows {
            guard let query = row.string(for: "query"),
                  let count = row.int(for: "count") else {
                continue
            }

            let lastTimestamp = row.int(for: "last_time") ?? Int(Date().timeIntervalSince1970)

            mostCommon.append(QueryFrequency(
                query: query,
                count: count,
                lastQueried: Date(timeIntervalSince1970: TimeInterval(lastTimestamp))
            ))
        }

        // Content coverage calculation
        let totalGaps = gaps.count
        let contentCoverage = max(0, 1.0 - (Double(totalGaps) / Double(totalQueries + 1)))

        return SearchAnalyticsMetrics(
            totalQueries: totalQueries,
            uniqueUsers: uniqueUsers,
            averageResultsPerQuery: avgResults,
            clickThroughRate: ctrRate,
            averageClickedRank: avgClickedRank,
            contentGaps: gaps,
            mostCommonQueries: mostCommon,
            queryLatencyMs: 100.0,  // Placeholder
            contentCoverage: contentCoverage
        )
    }

    /// Get session metrics
    public func getSessionMetrics(sessionId: String) async throws -> SessionMetrics? {
        try await ensureSchema()
        guard let db = dbActor else { return nil }

        let rows = try await db.executeQuery(
            """
            SELECT
                s.id, s.user_id, s.started_at, COUNT(DISTINCT sq.id) as queries,
                COUNT(DISTINCT sc.id) as clicks
            FROM search_sessions s
            LEFT JOIN search_queries sq ON s.id = sq.session_id
            LEFT JOIN search_clicks sc ON sq.id = sc.query_id
            WHERE s.id = ?
            GROUP BY s.id
            """,
            parameters: [.text(sessionId)]
        )

        guard let row = rows.first,
              let userId = row.string(for: "user_id"),
              let startedAtInt = row.int(for: "started_at") else {
            return nil
        }

        let querieCount = row.int(for: "queries") ?? 0
        let clicksCount = row.int(for: "clicks") ?? 0

        return SessionMetrics(
            sessionId: sessionId,
            userId: userId,
            startTime: Date(timeIntervalSince1970: TimeInterval(startedAtInt)),
            queriesPerformed: querieCount,
            resultClicks: clicksCount,
            sessionsInactiveMinutes: 0
        )
    }

    /// Identify trending queries
    public func getTrendingQueries(
        limit: Int = 10
    ) async throws -> [QueryFrequency] {
        try await ensureSchema()
        guard let db = dbActor else { return [] }

        // Queries from last 7 days that are increasing
        let rows = try await db.executeQuery(
            """
            SELECT query, COUNT(*) as count, MAX(query_timestamp) as last_time
            FROM search_queries
            WHERE query_timestamp > strftime('%s', 'now') - (7 * 86400)
            GROUP BY query
            HAVING count > 3
            ORDER BY count DESC
            LIMIT ?
            """,
            parameters: [.int(limit)]
        )

        var trending: [QueryFrequency] = []

        for row in rows {
            guard let query = row.string(for: "query"),
                  let count = row.int(for: "count") else {
                continue
            }

            let lastTimestamp = row.int(for: "last_time") ?? Int(Date().timeIntervalSince1970)

            trending.append(QueryFrequency(
                query: query,
                count: count,
                lastQueried: Date(timeIntervalSince1970: TimeInterval(lastTimestamp))
            ))
        }

        return trending
    }

    /// Get no-result queries (content gaps)
    public func getNoResultQueries(
        limit: Int = 20
    ) async throws -> [String] {
        try await ensureSchema()
        guard let db = dbActor else { return [] }

        let rows = try await db.executeQuery(
            """
            SELECT DISTINCT query FROM search_queries WHERE result_count = 0 LIMIT ?
            """,
            parameters: [.int(limit)]
        )

        var queries: [String] = []

        for row in rows {
            if let query = row.string(for: "query") {
                queries.append(query)
            }
        }

        return queries
    }

    private func ensureSchema() async throws {
        guard let db = dbActor else { return }
        if !schemaInitialized {
            try await SearchSchema.apply(using: db)
            schemaInitialized = true
        }
    }
}
