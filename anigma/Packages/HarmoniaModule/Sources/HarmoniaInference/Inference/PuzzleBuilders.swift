//
//  PuzzleBuilders.swift
//  HarmoniaModule
//
//  Builders for structured reasoning puzzles.
//

import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import Foundation
import AnigmaCore

private func makeStructuredPuzzle(
    description: String,
    constraints: [String],
    metadata: [String: String]
) -> ReasoningPuzzle {
    let abstractConstraints = constraints.enumerated().map { index, constraint in
        AbstractConstraint(
            constraintId: "constraint_\(index)",
            name: constraint,
            condition: AbstractCondition(
                symbol: "constraint.\(index).satisfied",
                operator_: .equals,
                value: .boolean(true)
            ),
            severity: .violation
        )
    }

    return ReasoningPuzzle(
        puzzleType: .verifyCompliance,
        domain: .automationRules,
        initialState: .empty,
        transitions: [],
        constraints: abstractConstraints,
        goal: .proveInvariant(),
        metadata: metadata.merging(["description": description]) { current, _ in current }
    )
}

// MARK: - DSPS Puzzle Builder

/// Builder for DSPS (Disability Services) reasoning puzzles.
public struct DSPSPuzzleBuilder {
    /// Builds an accommodation case puzzle.
    public static func buildAccommodationCasePuzzle(
        cases: [(symbol: String, studentSymbol: String, termSymbol: String, hasDocumentation: Bool)],
        accommodations: [(caseSymbol: String, accommodationType: String, isApproved: Bool)],
        letters: [(caseSymbol: String, letterSymbol: String, isDelivered: Bool)]
    ) -> ReasoningPuzzle {
        makeStructuredPuzzle(
            description: "DSPS accommodation case analysis",
            constraints: [
                "Each case must have documentation",
                "All accommodations must be approved before letters sent",
                "Letters must be delivered within SLA"
            ],
            metadata: [
                "case_count": String(cases.count),
                "accommodation_count": String(accommodations.count),
                "letter_count": String(letters.count)
            ]
        )
    }
    
    /// Builds an alt-media workflow puzzle.
    public static func buildAltMediaWorkflowPuzzle(
        requests: [(symbol: String, caseSymbol: String, format: String, priority: Int)],
        slaHours: Int
    ) -> ReasoningPuzzle {
        makeStructuredPuzzle(
            description: "Alt-media workflow analysis",
            constraints: [
                "High priority requests must be processed within \(slaHours) hours",
                "Format conversions must maintain quality",
                "All requests must have valid case references"
            ],
            metadata: [
                "request_count": String(requests.count),
                "sla_hours": String(slaHours)
            ]
        )
    }
}

// MARK: - Transcriptum Puzzle Builder

/// Builder for Transcriptum (degree award) reasoning puzzles.
public struct TranscriptumPuzzleBuilder {
    /// Builds a degree award puzzle.
    public static func buildDegreeAwardPuzzle(
        students: [(symbol: String, programSymbol: String, completedUnits: Int, gpa: Double)],
        programs: [(symbol: String, requiredUnits: Int, minGPA: Double)],
        degreeAwards: [(studentSymbol: String, programSymbol: String, isAwarded: Bool)]
    ) -> ReasoningPuzzle {
        makeStructuredPuzzle(
            description: "Degree award integrity check",
            constraints: [
                "Student must have completed all required units",
                "Student GPA must meet program minimum",
                "Degree award must match completed program"
            ],
            metadata: [
                "student_count": String(students.count),
                "program_count": String(programs.count),
                "award_count": String(degreeAwards.count)
            ]
        )
    }
}
