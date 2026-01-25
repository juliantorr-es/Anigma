//
//  ResultRanker.swift
//  HarmoniaModule
//
//  Multi-factor result ranking with user preference learning and temporal boosting.
//

import AnigmaPrimitives
import DatabaseCore
@preconcurrency import Foundation

/// Ranked search result
public struct RankedResult: Sendable, Codable {
    /// Result identifier
    public let resultId: String

    /// Result description
    public let description: String

    /// Overall relevance score (0-1)
    public let overallScore: Double

    /// Component scores
    public let keywordScore: Double
    public let semanticScore: Double
    public let recencyScore: Double
    public let popularityScore: Double
    public let userPreferenceScore: Double

    /// Ranking position
    public let rankingPosition: Int

    /// Why this result was ranked here
    public let rankingReason: String

    public init(
        resultId: String,
        description: String,
        overallScore: Double,
        keywordScore: Double,
        semanticScore: Double,
        recencyScore: Double,
        popularityScore: Double,
        userPreferenceScore: Double,
        rankingPosition: Int,
        rankingReason: String
    ) {
        self.resultId = resultId
        self.description = description
        self.overallScore = overallScore
        self.keywordScore = keywordScore
        self.semanticScore = semanticScore
        self.recencyScore = recencyScore
        self.popularityScore = popularityScore
        self.userPreferenceScore = userPreferenceScore
        self.rankingPosition = rankingPosition
        self.rankingReason = rankingReason
    }
}

/// User preference record
public struct UserPreference: Sendable, Codable {
    public let userId: String
    public let resultId: String
    public let query: String
    public let useful: Bool
    public let feedback: String?
    public let recordedAt: Date

    public init(
        userId: String,
        resultId: String,
        query: String,
        useful: Bool,
        feedback: String?,
        recordedAt: Date
    ) {
        self.userId = userId
        self.resultId = resultId
        self.query = query
        self.useful = useful
        self.feedback = feedback
        self.recordedAt = recordedAt
    }
}

/// Ranking configuration
public struct RankingConfig: Sendable, Codable {
    /// Weight of keyword matching (0-1)
    public let keywordWeight: Double
    /// Weight of semantic similarity (0-1)
    public let semanticWeight: Double
    /// Weight of recency (0-1)
    public let recencyWeight: Double
    /// Weight of popularity (0-1)
    public let popularityWeight: Double
    /// Weight of user preferences (0-1)
    public let preferenceWeight: Double
    /// Days to consider "recent"
    public let recencyDays: Int
    /// Whether to boost personalized results
    public let personalizedBoosting: Bool

    public init(
        keywordWeight: Double = 0.3,
        semanticWeight: Double = 0.25,
        recencyWeight: Double = 0.2,
        popularityWeight: Double = 0.15,
        preferenceWeight: Double = 0.1,
        recencyDays: Int = 30,
        personalizedBoosting: Bool = true
    ) {
        self.keywordWeight = keywordWeight
        self.semanticWeight = semanticWeight
        self.recencyWeight = recencyWeight
        self.popularityWeight = popularityWeight
        self.preferenceWeight = preferenceWeight
        self.recencyDays = recencyDays
        self.personalizedBoosting = personalizedBoosting
    }
}

/// Multi-factor result ranking
public actor ResultRanker {
    private let dbActor: DatabaseActor?
    private let config: RankingConfig
    private var schemaInitialized = false

    public init(
        dbActor: DatabaseActor? = nil,
        config: RankingConfig = RankingConfig()
    ) {
        self.dbActor = dbActor
        self.config = config
    }

    /// Rank search results by multiple factors
    public func rankResults(
        results: [SearchResultInput],
        query: String,
        userId: String?
    ) async throws -> [RankedResult] {
        try await ensureSchema()
        var rankedResults: [RankedResult] = []

        for (index, result) in results.enumerated() {
            let keywordScore = computeKeywordScore(result.text, query: query)
            let semanticScore = result.semanticScore ?? 0.0
            let recencyScore = await computeRecencyScore(result.createdAt)
            let popularityScore = await computePopularityScore(result.resultId)
            let preferenceScore = userId != nil ? await computePreferenceScore(result.resultId, userId: userId!) : 0.0

            let overallScore = computeOverallScore(
                keyword: keywordScore,
                semantic: semanticScore,
                recency: recencyScore,
                popularity: popularityScore,
                preference: preferenceScore
            )

            let reason = generateRankingReason(
                keywordScore: keywordScore,
                semanticScore: semanticScore,
                recencyScore: recencyScore,
                popularityScore: popularityScore,
                preferenceScore: preferenceScore
            )

            rankedResults.append(RankedResult(
                resultId: result.resultId,
                description: result.text,
                overallScore: overallScore,
                keywordScore: keywordScore,
                semanticScore: semanticScore,
                recencyScore: recencyScore,
                popularityScore: popularityScore,
                userPreferenceScore: preferenceScore,
                rankingPosition: index + 1,
                rankingReason: reason
            ))
        }

        // Sort by overall score
        rankedResults.sort { $0.overallScore > $1.overallScore }

        // Update ranking positions
        return rankedResults.enumerated().map { index, result in
            RankedResult(
                resultId: result.resultId,
                description: result.description,
                overallScore: result.overallScore,
                keywordScore: result.keywordScore,
                semanticScore: result.semanticScore,
                recencyScore: result.recencyScore,
                popularityScore: result.popularityScore,
                userPreferenceScore: result.userPreferenceScore,
                rankingPosition: index + 1,
                rankingReason: result.rankingReason
            )
        }
    }

    /// Record user feedback
    public func recordFeedback(
        userId: String,
        resultId: String,
        query: String,
        useful: Bool,
        feedback: String? = nil
    ) async throws {
        try await ensureSchema()
        guard let db = dbActor else { return }

        let timestamp = Int(Date().timeIntervalSince1970)

        try await db.execute(
            """
            INSERT INTO search_feedback (id, user_id, result_id, query, useful, feedback, recorded_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(UUID().uuidString),
                .text(userId),
                .text(resultId),
                .text(query),
                .int(useful ? 1 : 0),
                .text(feedback ?? ""),
                .int(timestamp)
            ]
        )
    }

    /// Get learned user preferences
    public func getUserPreferences(userId: String) async throws -> [UserPreference] {
        try await ensureSchema()
        guard let db = dbActor else { return [] }

        let rows = try await db.executeQuery(
            """
            SELECT * FROM search_feedback WHERE user_id = ? ORDER BY recorded_at DESC LIMIT 100
            """,
            parameters: [.text(userId)]
        )

        var preferences: [UserPreference] = []

        for row in rows {
            guard let resultId = row.string(for: "result_id"),
                  let query = row.string(for: "query"),
                  let usefulInt = row.int(for: "useful"),
                  let timestampInt = row.int(for: "recorded_at") else {
                continue
            }

            preferences.append(UserPreference(
                userId: userId,
                resultId: resultId,
                query: query,
                useful: usefulInt != 0,
                feedback: row.string(for: "feedback"),
                recordedAt: Date(timeIntervalSince1970: TimeInterval(timestampInt))
            ))
        }

        return preferences
    }

    /// Compute keyword matching score
    private func computeKeywordScore(_ text: String, query: String) -> Double {
        let textLower = text.lowercased()
        let queryTerms = query.lowercased().split(separator: " ")

        if queryTerms.isEmpty { return 0.0 }

        var matches = 0
        for term in queryTerms {
            if textLower.contains(String(term)) {
                matches += 1
            }
        }

        return Double(matches) / Double(queryTerms.count)
    }

    /// Compute recency score based on age
    private func computeRecencyScore(_ createdAt: Date) async -> Double {
        let ageInDays = Date().timeIntervalSince(createdAt) / 86400.0
        let recencyDaysDouble = Double(config.recencyDays)

        if ageInDays <= recencyDaysDouble {
            return 1.0 - (ageInDays / recencyDaysDouble) * 0.5
        } else {
            return max(0.0, 0.5 - (ageInDays - recencyDaysDouble) / (recencyDaysDouble * 3))
        }
    }

    /// Compute popularity score from view/usage counts
    private func computePopularityScore(_ resultId: String) async -> Double {
        guard let db = dbActor else { return 0.0 }

        let rows = try? await db.executeQuery(
            """
            SELECT COUNT(*) as count FROM search_feedback WHERE result_id = ? AND useful = 1
            """,
            parameters: [.text(resultId)]
        )

        if let row = rows?.first,
           let count = row.int(for: "count") {
            // Cap at 100 to avoid extreme scores
            return min(1.0, Double(count) / 100.0)
        }

        return 0.0
    }

    /// Compute preference score based on user history
    private func computePreferenceScore(_ resultId: String, userId: String) async -> Double {
        guard let db = dbActor else { return 0.0 }

        let rows = try? await db.executeQuery(
            """
            SELECT COUNT(*) as count, SUM(CASE WHEN useful = 1 THEN 1 ELSE 0 END) as useful_count
            FROM search_feedback
            WHERE result_id = ? AND user_id = ?
            """,
            parameters: [.text(resultId), .text(userId)]
        )

        if let row = rows?.first,
           let count = row.int(for: "count"),
           let usefulCount = row.int(for: "useful_count") {
            if count > 0 {
                return Double(usefulCount) / Double(count)
            }
        }

        return 0.0
    }

    /// Compute overall ranking score
    private func computeOverallScore(
        keyword: Double,
        semantic: Double,
        recency: Double,
        popularity: Double,
        preference: Double
    ) -> Double {
        return (keyword * config.keywordWeight) +
               (semantic * config.semanticWeight) +
               (recency * config.recencyWeight) +
               (popularity * config.popularityWeight) +
               (preference * config.preferenceWeight)
    }

    /// Generate human-readable ranking reason
    private func generateRankingReason(
        keywordScore: Double,
        semanticScore: Double,
        recencyScore: Double,
        popularityScore: Double,
        preferenceScore: Double
    ) -> String {
        var reasons: [String] = []

        if keywordScore > 0.7 {
            reasons.append("strong keyword match")
        }
        if semanticScore > 0.7 {
            reasons.append("semantically relevant")
        }
        if recencyScore > 0.7 {
            reasons.append("recently updated")
        }
        if popularityScore > 0.7 {
            reasons.append("widely used")
        }
        if preferenceScore > 0.5 {
            reasons.append("matches your preferences")
        }

        return reasons.isEmpty ? "matched search criteria" : reasons.joined(separator: ", ")
    }

    private func ensureSchema() async throws {
        guard let db = dbActor else { return }
        if !schemaInitialized {
            try await SearchSchema.apply(using: db)
            schemaInitialized = true
        }
    }
}

/// Input for ranking
public struct SearchResultInput: Sendable, Codable {
    public let resultId: String
    public let text: String
    public let createdAt: Date
    public let semanticScore: Double?

    public init(
        resultId: String,
        text: String,
        createdAt: Date,
        semanticScore: Double? = nil
    ) {
        self.resultId = resultId
        self.text = text
        self.createdAt = createdAt
        self.semanticScore = semanticScore
    }
}
