import AnigmaPrimitives

import AnigmaPrimitives

//
//  OutlineQAComponent.swift
//  OutlineumModule
//
//  Ported from: Outlineum/backend/outlineum/ecs/components/qa_components.py
//
//  Quality assurance scores and decisions for generated outlines.
//

import AnigmaCore
import Foundation

/// QA scores and decisions specific to outline generation.
///
/// This extends the generic QAComponent concept with outline-specific
/// metrics like line clarity, noise level, and age-appropriateness.
public struct OutlineQAComponent: Component, Codable {
    // MARK: - Outline Quality Scores

    /// Scores for outline quality metrics (0.0 to 1.0).
    /// Keys: "clarity", "noise", "edge_continuity", "detail_level"
    public var outlineScores: [String: Double]

    /// Scores for layout/composition metrics.
    /// Keys: "balance", "whitespace", "focal_point"
    public var layoutScores: [String: Double]

    // MARK: - Decision Flags

    /// Boolean flags for QA decisions.
    /// Keys: "approved_for_kids", "approved_for_adults", "needs_manual_review"
    public var decisionFlags: [String: Bool]

    /// Overall pass/fail determination.
    public var overallPass: Bool

    // MARK: - Audit Trail

    /// When QA was performed.
    public var checkedAt: Date?

    /// What performed the QA (model name, version, or "manual").
    public var checkedBy: String?

    /// Notes from QA process.
    public var notes: [String]

    public init(
        outlineScores: [String: Double] = [:],
        layoutScores: [String: Double] = [:],
        decisionFlags: [String: Bool] = [:],
        overallPass: Bool = false,
        checkedAt: Date? = nil,
        checkedBy: String? = nil,
        notes: [String] = []
    ) {
        self.outlineScores = outlineScores
        self.layoutScores = layoutScores
        self.decisionFlags = decisionFlags
        self.overallPass = overallPass
        self.checkedAt = checkedAt
        self.checkedBy = checkedBy
        self.notes = notes
    }

    /// Whether approved for kids content.
    public var approvedForKids: Bool {
        decisionFlags["approved_for_kids"] ?? false
    }

    /// Whether approved for adult content.
    public var approvedForAdults: Bool {
        decisionFlags["approved_for_adults"] ?? false
    }

    /// Whether manual review is required.
    public var needsManualReview: Bool {
        decisionFlags["needs_manual_review"] ?? false
    }

    /// Average outline quality score.
    public var averageOutlineScore: Double? {
        guard !outlineScores.isEmpty else { return nil }
        return outlineScores.values.reduce(0, +) / Double(outlineScores.count)
    }
}
