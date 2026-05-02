//
//  ExplainableAI.swift
//  AnigmaCore
//
//  Explainable AI (XAI) infrastructure for the Anigma platform.
//  Provides human-readable justifications for AI/ML decisions.
//
//  This addresses the "systemic black box risk" by ensuring all
//  anomaly detection and policy enforcement decisions are auditable.
//
//  Design principles:
//  - Every AI decision must have an explanation
//  - Explanations must be human-readable
//  - Contributing factors must be enumerable
//  - Confidence levels must be explicit
//

import AnigmaFoundation
import AnigmaPrimitives
import GovernanceCore
import Foundation
import GovernanceContracts

// MARK: - Explanation Types

/// Types of AI/ML decisions that require explanation.
public enum DecisionType: String, Sendable, Codable {
    /// Anomaly detection decision.
    case anomalyDetection = "ANOMALY_DETECTION"

    /// Policy enforcement decision.
    case policyEnforcement = "POLICY_ENFORCEMENT"

    /// Access control decision.
    case accessControl = "ACCESS_CONTROL"

    /// Content classification decision.
    case contentClassification = "CONTENT_CLASSIFICATION"

    /// Risk assessment decision.
    case riskAssessment = "RISK_ASSESSMENT"

    /// Behavioral analysis decision.
    case behavioralAnalysis = "BEHAVIORAL_ANALYSIS"

    /// Threat detection decision.
    case threatDetection = "THREAT_DETECTION"
}

// MARK: - Contributing Factor

/// A factor that contributed to an AI decision.
public struct ContributingFactor: Sendable, Codable, Identifiable {
    public let id: UUID

    /// Human-readable name of the factor.
    public let name: String

    /// Description of what this factor represents.
    public let description: String

    /// The weight or importance of this factor (0.0 - 1.0).
    public let weight: Double

    /// The observed value for this factor.
    public let observedValue: String

    /// The expected or baseline value for comparison.
    public let baselineValue: String?

    /// Direction of influence: positive (increases score) or negative (decreases).
    public let influence: FactorInfluence

    /// Optional category for grouping factors.
    public let category: String?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        weight: Double,
        observedValue: String,
        baselineValue: String? = nil,
        influence: FactorInfluence,
        category: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.weight = min(1.0, max(0.0, weight))
        self.observedValue = observedValue
        self.baselineValue = baselineValue
        self.influence = influence
        self.category = category
    }
}

/// Direction of a factor's influence on the decision.
public enum FactorInfluence: String, Sendable, Codable {
    /// Factor increases the score/confidence.
    case positive

    /// Factor decreases the score/confidence.
    case negative

    /// Factor is neutral or informational.
    case neutral
}

// MARK: - AI Decision Explanation

/// A complete explanation of an AI/ML decision.
public struct AIDecisionExplanation: Sendable, Codable, Identifiable {
    public let id: UUID

    /// Type of decision being explained.
    public let decisionType: DecisionType

    /// The decision outcome (e.g., "ALLOW", "BLOCK", "ANOMALY_DETECTED").
    public let outcome: String

    /// Overall confidence level (0.0 - 1.0).
    public let confidence: Double

    /// Human-readable summary of the decision.
    public let summary: String

    /// Detailed explanation suitable for SOC analysts.
    public let detailedExplanation: String

    /// Contributing factors with their weights.
    public let contributingFactors: [ContributingFactor]

    /// Alternative outcomes that were considered.
    public let alternativesConsidered: [AlternativeOutcome]

    /// The model or algorithm that made the decision.
    public let modelIdentifier: String

    /// Version of the model.
    public let modelVersion: String

    /// Timestamp of the decision.
    public let timestamp: Date

    /// Context in which the decision was made.
    public let context: [String: String]

    /// Recommendations for human review.
    public let reviewRecommendations: [String]

    public init(
        id: UUID = UUID(),
        decisionType: DecisionType,
        outcome: String,
        confidence: Double,
        summary: String,
        detailedExplanation: String,
        contributingFactors: [ContributingFactor],
        alternativesConsidered: [AlternativeOutcome] = [],
        modelIdentifier: String,
        modelVersion: String,
        timestamp: Date = Date(),
        context: [String: String] = [:],
        reviewRecommendations: [String] = []
    ) {
        self.id = id
        self.decisionType = decisionType
        self.outcome = outcome
        self.confidence = min(1.0, max(0.0, confidence))
        self.summary = summary
        self.detailedExplanation = detailedExplanation
        self.contributingFactors = contributingFactors
        self.alternativesConsidered = alternativesConsidered
        self.modelIdentifier = modelIdentifier
        self.modelVersion = modelVersion
        self.timestamp = timestamp
        self.context = context
        self.reviewRecommendations = reviewRecommendations
    }

    /// Gets the top N contributing factors by weight.
    public func topFactors(_ n: Int) -> [ContributingFactor] {
        Array(contributingFactors.sorted { $0.weight > $1.weight }.prefix(n))
    }

    /// Gets factors that increased the score.
    public var positiveFactors: [ContributingFactor] {
        contributingFactors.filter { $0.influence == .positive }
    }

    /// Gets factors that decreased the score.
    public var negativeFactors: [ContributingFactor] {
        contributingFactors.filter { $0.influence == .negative }
    }

    /// Generates a human-readable report.
    public func generateReport() -> String {
        var report = """
        ═══════════════════════════════════════════════════════════════
        AI DECISION EXPLANATION REPORT
        ═══════════════════════════════════════════════════════════════

        Decision ID: \(id)
        Type: \(decisionType.rawValue)
        Timestamp: \(timestamp.ISO8601Format())

        OUTCOME: \(outcome)
        Confidence: \(String(format: "%.1f%%", confidence * 100))

        ───────────────────────────────────────────────────────────────
        SUMMARY
        ───────────────────────────────────────────────────────────────
        \(summary)

        ───────────────────────────────────────────────────────────────
        DETAILED EXPLANATION
        ───────────────────────────────────────────────────────────────
        \(detailedExplanation)

        ───────────────────────────────────────────────────────────────
        CONTRIBUTING FACTORS (Top 5)
        ───────────────────────────────────────────────────────────────
        """

        for (index, factor) in topFactors(5).enumerated() {
            let influenceSymbol = switch factor.influence {
            case .positive: "↑"
            case .negative: "↓"
            case .neutral: "→"
            }

            report += """

            \(index + 1). \(factor.name) [\(influenceSymbol) \(String(format: "%.1f%%", factor.weight * 100))]
               \(factor.description)
               Observed: \(factor.observedValue)
               Baseline: \(factor.baselineValue ?? "N/A")
            """
        }

        if !alternativesConsidered.isEmpty {
            report += """


            ───────────────────────────────────────────────────────────────
            ALTERNATIVES CONSIDERED
            ───────────────────────────────────────────────────────────────
            """

            for alt in alternativesConsidered {
                report += """

                • \(alt.outcome) (confidence: \(String(format: "%.1f%%", alt.confidence * 100)))
                  Reason not selected: \(alt.reasonNotSelected)
                """
            }
        }

        if !reviewRecommendations.isEmpty {
            report += """


            ───────────────────────────────────────────────────────────────
            REVIEW RECOMMENDATIONS
            ───────────────────────────────────────────────────────────────
            """

            for rec in reviewRecommendations {
                report += "\n• \(rec)"
            }
        }

        report += """


        ───────────────────────────────────────────────────────────────
        MODEL INFORMATION
        ───────────────────────────────────────────────────────────────
        Model: \(modelIdentifier)
        Version: \(modelVersion)

        ═══════════════════════════════════════════════════════════════
        """

        return report
    }
}

/// An alternative outcome that was considered but not selected.
public struct AlternativeOutcome: Sendable, Codable {
    /// The alternative outcome.
    public let outcome: String

    /// Confidence for this alternative.
    public let confidence: Double

    /// Why this alternative was not selected.
    public let reasonNotSelected: String

    public init(outcome: String, confidence: Double, reasonNotSelected: String) {
        self.outcome = outcome
        self.confidence = confidence
        self.reasonNotSelected = reasonNotSelected
    }
}

// MARK: - Explainable Decision Provider

/// Protocol for AI/ML systems that provide explanations.
public protocol ExplainableDecisionProvider: Sendable {
    /// The identifier for this model/system.
    var modelIdentifier: String { get }

    /// The version of this model/system.
    var modelVersion: String { get }

    /// Generates an explanation for a decision.
    func explain(
        decisionType: DecisionType,
        outcome: String,
        confidence: Double,
        inputData: [String: Any]
    ) async -> AIDecisionExplanation
}

// MARK: - XAI Registry

/// Central registry for explainable AI decisions.
public actor XAIRegistry {
    private var explanations: [UUID: AIDecisionExplanation] = [:]
    private var auditLog: (any AuditLogging)?
    private let maxStoredExplanations: Int

    public init(maxStoredExplanations: Int = 10000) {
        self.maxStoredExplanations = maxStoredExplanations
    }

    /// Sets the audit log for XAI events.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Records an AI decision explanation.
    public func record(_ explanation: AIDecisionExplanation) async {
        // Evict oldest if at capacity
        if explanations.count >= maxStoredExplanations {
            let oldest = explanations.values.min { $0.timestamp < $1.timestamp }
            if let oldest = oldest {
                explanations.removeValue(forKey: oldest.id)
            }
        }

        explanations[explanation.id] = explanation

        // Log to audit trail
        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: AuditEventType.policyEvaluated,
                principal: "explainable_ai",
                module: "ExplainableAI",
                description: "AI decision: \(explanation.decisionType.rawValue) -> \(explanation.outcome)",
                metadata: [
                    "decision_id": explanation.id.uuidString,
                    "model": explanation.modelIdentifier,
                    "confidence": String(format: "%.2f", explanation.confidence),
                    "factor_count": String(explanation.contributingFactors.count)
                ]
            )
        }
    }

    /// Retrieves an explanation by ID.
    public func getExplanation(id: UUID) -> AIDecisionExplanation? {
        explanations[id]
    }

    /// Query explanations with filters.
    public struct QueryConfiguration: Sendable {
        let decisionType: DecisionType?
        let outcome: String?
        let minConfidence: Double?
        let maxConfidence: Double?
        let since: Date?
        let until: Date?
        let limit: Int
        
        public init(
            decisionType: DecisionType? = nil,
            outcome: String? = nil,
            minConfidence: Double? = nil,
            maxConfidence: Double? = nil,
            since: Date? = nil,
            until: Date? = nil,
            limit: Int = 100
        ) {
            self.decisionType = decisionType
            self.outcome = outcome
            self.minConfidence = minConfidence
            self.maxConfidence = maxConfidence
            self.since = since
            self.until = until
            self.limit = limit
        }
    }

    /// Query explanations based on configuration.
    public func query(_ configuration: QueryConfiguration) -> [AIDecisionExplanation] {
        var results = Array(explanations.values)
        
        if let decisionType = configuration.decisionType {
            results = results.filter { $0.decisionType == decisionType }
        }
        
        if let outcome = configuration.outcome {
            results = results.filter { $0.outcome == outcome }
        }
        
        if let minConf = configuration.minConfidence {
            results = results.filter { $0.confidence >= minConf }
        }

        if let maxConf = configuration.maxConfidence {
            results = results.filter { $0.confidence <= maxConf }
        }

        if let since = configuration.since {
            results = results.filter { $0.timestamp >= since }
        }

        if let until = configuration.until {
            results = results.filter { $0.timestamp <= until }
        }

        // Sort by timestamp descending and limit
        return Array(results.sorted { $0.timestamp > $1.timestamp }.prefix(configuration.limit))
    }

    /// Gets statistics about recorded decisions.
    public func statistics() -> XAIStatistics {
        let all = Array(explanations.values)

        var byType: [DecisionType: Int] = [:]
        var byOutcome: [String: Int] = [:]
        var totalConfidence: Double = 0

        for exp in all {
            byType[exp.decisionType, default: 0] += 1
            byOutcome[exp.outcome, default: 0] += 1
            totalConfidence += exp.confidence
        }

        return XAIStatistics(
            totalDecisions: all.count,
            decisionsByType: byType,
            decisionsByOutcome: byOutcome,
            averageConfidence: all.isEmpty ? 0 : totalConfidence / Double(all.count),
            averageFactorCount: all.isEmpty ? 0 : Double(all.map { $0.contributingFactors.count }.reduce(0, +)) / Double(all.count)
        )
    }
}

/// Statistics about XAI decisions.
public struct XAIStatistics: Sendable {
    public let totalDecisions: Int
    public let decisionsByType: [DecisionType: Int]
    public let decisionsByOutcome: [String: Int]
    public let averageConfidence: Double
    public let averageFactorCount: Double
}

// MARK: - LIME-Style Local Explanation

/// Simple LIME-style local explanation generator.
/// Provides feature importance through local linear approximation.
public struct LocalExplanationGenerator: Sendable {
    public let modelIdentifier: String
    public let modelVersion: String

    public init(modelIdentifier: String, modelVersion: String) {
        self.modelIdentifier = modelIdentifier
        self.modelVersion = modelVersion
    }

    /// Generates a local explanation for a decision based on feature contributions.
    public func generateExplanation(
        decisionType: DecisionType,
        outcome: String,
        confidence: Double,
        features: [FeatureContribution],
        context: [String: String] = [:]
    ) -> AIDecisionExplanation {
        // Convert features to contributing factors
        let factors = features.map { feature in
            ContributingFactor(
                name: feature.name,
                description: feature.description,
                weight: Swift.abs(feature.contribution),
                observedValue: feature.value,
                baselineValue: feature.baseline,
                influence: feature.contribution >= 0 ? .positive : .negative,
                category: feature.category
            )
        }

        // Sort by absolute contribution
        let sortedFactors = factors.sorted { $0.weight > $1.weight }

        // Generate summary from top factors
        let topPositive = sortedFactors.filter { $0.influence == .positive }.prefix(2)
        let topNegative = sortedFactors.filter { $0.influence == .negative }.prefix(2)

        var summaryParts: [String] = []
        if !topPositive.isEmpty {
            summaryParts.append("Key positive factors: \(topPositive.map { $0.name }.joined(separator: ", "))")
        }
        if !topNegative.isEmpty {
            summaryParts.append("Key negative factors: \(topNegative.map { $0.name }.joined(separator: ", "))")
        }

        let summary = summaryParts.isEmpty
            ? "Decision based on \(factors.count) analyzed features."
            : summaryParts.joined(separator: ". ")

        // Generate detailed explanation
        let detailed = """
        The model analyzed \(factors.count) features to reach the decision '\(outcome)' \
        with \(String(format: "%.1f%%", confidence * 100)) confidence. \
        The most influential factors were: \
        \(sortedFactors.prefix(3).map { "\($0.name) (\(String(format: "%.1f%%", $0.weight * 100)))" }.joined(separator: ", ")).
        """

        // Generate review recommendations
        var recommendations: [String] = []
        if confidence < 0.7 {
            recommendations.append("Low confidence decision - recommend manual review")
        }
        if factors.count < 3 {
            recommendations.append("Limited feature data - consider additional context")
        }
        let conflictingFactors = factors.filter { $0.weight > 0.3 && $0.influence == .negative }
        if !conflictingFactors.isEmpty {
            recommendations.append("Significant negative factors present - verify decision aligns with policy")
        }

        return AIDecisionExplanation(
            decisionType: decisionType,
            outcome: outcome,
            confidence: confidence,
            summary: summary,
            detailedExplanation: detailed,
            contributingFactors: sortedFactors,
            modelIdentifier: modelIdentifier,
            modelVersion: modelVersion,
            context: context,
            reviewRecommendations: recommendations
        )
    }
}

/// A feature's contribution to a decision.
public struct FeatureContribution: Sendable {
    public let name: String
    public let description: String
    public let value: String
    public let baseline: String?
    public let contribution: Double  // Can be negative
    public let category: String?

    public init(
        name: String,
        description: String,
        value: String,
        baseline: String? = nil,
        contribution: Double,
        category: String? = nil
    ) {
        self.name = name
        self.description = description
        self.value = value
        self.baseline = baseline
        self.contribution = contribution
        self.category = category
    }
}
