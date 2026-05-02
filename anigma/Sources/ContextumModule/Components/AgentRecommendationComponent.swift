import Foundation

/// Explainable agent recommendation with provenance.
/// Phase 5: Recommendations are governed outputs with auditable explanations.
public struct AgentRecommendationComponent: Codable, Hashable, Sendable {
    public let recommendationID: UUID
    public let taxonomy: String
    public let repoSizeBand: String?
    public let requiredTools: Set<String>
    public let trustTier: String?
    public let scores: [AgentScore]
    public let explanation: Explanation
    public let generatedAt: Date

    public struct AgentScore: Codable, Hashable, Sendable {
        public let agentID: String
        public let score: Double
        public let rank: Int
    }

    public struct Explanation: Codable, Hashable, Sendable {
        public let sampleSize: Int
        public let successRates: [String: Double]
        public let failureCodePenalties: [String: [String: Int]]
        public let latencyP95: [String: Double]
        public let recencyWeightDays: Int
        public let hardExclusions: [String: String]

        public init(
            sampleSize: Int,
            successRates: [String: Double],
            failureCodePenalties: [String: [String: Int]],
            latencyP95: [String: Double],
            recencyWeightDays: Int,
            hardExclusions: [String: String]
        ) {
            self.sampleSize = sampleSize
            self.successRates = successRates
            self.failureCodePenalties = failureCodePenalties
            self.latencyP95 = latencyP95
            self.recencyWeightDays = recencyWeightDays
            self.hardExclusions = hardExclusions
        }
    }

    public init(
        recommendationID: UUID = UUID(),
        taxonomy: String,
        repoSizeBand: String? = nil,
        requiredTools: Set<String> = [],
        trustTier: String? = nil,
        scores: [AgentScore],
        explanation: Explanation,
        generatedAt: Date = Date()
    ) {
        self.recommendationID = recommendationID
        self.taxonomy = taxonomy
        self.repoSizeBand = repoSizeBand
        self.requiredTools = requiredTools
        self.trustTier = trustTier
        self.scores = scores
        self.explanation = explanation
        self.generatedAt = generatedAt
    }
}
