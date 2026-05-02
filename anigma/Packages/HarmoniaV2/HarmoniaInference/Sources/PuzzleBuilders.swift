//
//  PuzzleBuilders.swift
//  HarmoniaInference
//
//  Builders for structured reasoning puzzles.
//  Migrated from HarmoniaModule - Pure factory functions with zero side effects.
//

import Foundation
import HarmoniaV2Core

// MARK: - DSPS Puzzle Builder

/// Builder for DSPS (Disability Services) reasoning puzzles.
public struct DSPSPuzzleBuilder {
    
    /// Builds an accommodation case puzzle.
    public static func buildAccommodationCasePuzzle(
        cases: [(symbol: String, studentSymbol: String, termSymbol: String, hasDocumentation: Bool)],
        accommodations: [(caseSymbol: String, accommodationType: String, isApproved: Bool)],
        letters: [(caseSymbol: String, letterSymbol: String, isDelivered: Bool)]
    ) -> ReasoningPuzzle {
        ReasoningPuzzle(
            id: UUID().uuidString,
            description: "DSPS accommodation case analysis",
            constraints: [
                "Each case must have documentation",
                "All accommodations must be approved before letters sent",
                "Letters must be delivered within SLA"
            ],
            metadata: [
                "case_count": String(cases.count),
                "accommodation_count": String(accommodations.count),
                "letter_count": String(letters.count),
                "builder": "DSPSPuzzleBuilder",
                "version": "1.0.0"
            ],
            difficulty: .medium
        )
    }
    
    /// Builds an alt-media workflow puzzle.
    public static func buildAltMediaWorkflowPuzzle(
        requests: [(symbol: String, caseSymbol: String, format: String, priority: Int)],
        slaHours: Int
    ) -> ReasoningPuzzle {
        ReasoningPuzzle(
            id: UUID().uuidString,
            description: "Alt-media workflow analysis",
            constraints: [
                "High priority requests must be processed within \(slaHours) hours",
                "Format conversions must maintain quality",
                "All requests must have valid case references"
            ],
            metadata: [
                "request_count": String(requests.count),
                "sla_hours": String(slaHours),
                "builder": "DSPSPuzzleBuilder",
                "version": "1.0.0"
            ],
            difficulty: .hard
        )
    }
    
    /// Builds a FERPA compliance puzzle.
    public static func buildFERPACompliancePuzzle(
        records: [(symbol: String, studentSymbol: String, accessLevel: String, isEncrypted: Bool)],
        disclosures: [(recordSymbol: String, recipientRole: String, hasConsent: Bool)]
    ) -> ReasoningPuzzle {
        ReasoningPuzzle(
            id: UUID().uuidString,
            description: "FERPA compliance verification",
            constraints: [
                "All student records must be encrypted at rest",
                "Disclosures require explicit consent or legal exception",
                "Access must be logged and auditable"
            ],
            metadata: [
                "record_count": String(records.count),
                "disclosure_count": String(disclosures.count),
                "builder": "DSPSPuzzleBuilder",
                "compliance": "FERPA"
            ],
            difficulty: .expert
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
        ReasoningPuzzle(
            id: UUID().uuidString,
            description: "Degree award integrity check",
            constraints: [
                "Student must have completed all required units",
                "Student GPA must meet program minimum",
                "Degree award must match completed program"
            ],
            metadata: [
                "student_count": String(students.count),
                "program_count": String(programs.count),
                "award_count": String(degreeAwards.count),
                "builder": "TranscriptumPuzzleBuilder",
                "version": "1.0.0"
            ],
            difficulty: .medium
        )
    }
    
    /// Builds a course prerequisite puzzle.
    public static func buildPrerequisitePuzzle(
        courses: [(symbol: String, prerequisites: [String])],
        enrollments: [(studentSymbol: String, courseSymbol: String, term: String)],
        completedCourses: [(studentSymbol: String, courseSymbol: String, grade: String)]
    ) -> ReasoningPuzzle {
        ReasoningPuzzle(
            id: UUID().uuidString,
            description: "Course prerequisite validation",
            constraints: [
                "All prerequisites must be completed with passing grade",
                "Prerequisites must be completed before enrollment",
                "Sequential course dependencies must be enforced"
            ],
            metadata: [
                "course_count": String(courses.count),
                "enrollment_count": String(enrollments.count),
                "completion_count": String(completedCourses.count),
                "builder": "TranscriptumPuzzleBuilder"
            ],
            difficulty: .hard
        )
    }
}

// MARK: - Generic Puzzle Builder

/// Generic builder for custom reasoning puzzles.
public struct GenericPuzzleBuilder {
    
    /// Builds a custom constraint satisfaction puzzle.
    public static func buildConstraintPuzzle(
        description: String,
        constraints: [String],
        metadata: [String: String] = [:],
        difficulty: DifficultyLevel = .medium
    ) -> ReasoningPuzzle {
        var enrichedMetadata = metadata
        enrichedMetadata["builder"] = "GenericPuzzleBuilder"
        enrichedMetadata["version"] = "1.0.0"
        enrichedMetadata["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        return ReasoningPuzzle(
            id: UUID().uuidString,
            description: description,
            constraints: constraints,
            metadata: enrichedMetadata,
            difficulty: difficulty
        )
    }
    
    /// Builds a hierarchical subproblem decomposition.
    public static func buildSubproblemHierarchy(
        rootDescription: String,
        subproblems: [(description: String, dependencies: [String])]
    ) -> (root: ReasoningPuzzle, subproblems: [StructuredSubproblem]) {
        let rootId = UUID().uuidString
        
        let root = ReasoningPuzzle(
            id: rootId,
            description: rootDescription,
            constraints: ["All subproblems must be satisfied"],
            metadata: [
                "subproblem_count": String(subproblems.count),
                "builder": "GenericPuzzleBuilder"
            ],
            difficulty: .hard
        )
        
        let subproblemStructures = subproblems.map { sub in
            StructuredSubproblem(
                id: UUID().uuidString,
                description: sub.description,
                parentId: rootId,
                dependencies: sub.dependencies
            )
        }
        
        return (root, subproblemStructures)
    }
}

// MARK: - Puzzle Validation

/// Pure validation utilities for reasoning puzzles.
public enum PuzzleValidator {
    
    /// Validates that a puzzle is well-formed.
    public static func validate(_ puzzle: ReasoningPuzzle) -> [String] {
        var errors: [String] = []
        
        if puzzle.description.isEmpty {
            errors.append("Puzzle description cannot be empty")
        }
        
        if puzzle.constraints.isEmpty {
            errors.append("Puzzle must have at least one constraint")
        }
        
        if puzzle.constraints.contains(where: { $0.isEmpty }) {
            errors.append("Puzzle constraints cannot be empty strings")
        }
        
        return errors
    }
    
    /// Validates a subproblem hierarchy for circular dependencies.
    public static func validateSubproblemHierarchy(_ subproblems: [StructuredSubproblem]) -> [String] {
        var errors: [String] = []
        let ids = Set(subproblems.map { $0.id })
        
        // Check for invalid dependency references
        for subproblem in subproblems {
            for dependency in subproblem.dependencies {
                if !ids.contains(dependency) {
                    errors.append("Subproblem \(subproblem.id) references unknown dependency \(dependency)")
                }
            }
        }
        
        // Check for circular dependencies (simplified check)
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        
        func hasCycle(_ id: String) -> Bool {
            if recursionStack.contains(id) {
                return true
            }
            if visited.contains(id) {
                return false
            }
            
            visited.insert(id)
            recursionStack.insert(id)
            
            if let subproblem = subproblems.first(where: { $0.id == id }) {
                for dependency in subproblem.dependencies {
                    if hasCycle(dependency) {
                        return true
                    }
                }
            }
            
            recursionStack.remove(id)
            return false
        }
        
        for subproblem in subproblems {
            if hasCycle(subproblem.id) {
                errors.append("Circular dependency detected involving \(subproblem.id)")
            }
        }
        
        return errors
    }
}
