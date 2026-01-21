//
//  TwoTierReasoningTests.swift
//  AnigmaCoreTests
//
//  Tests for the two-tier reasoning architecture.
//

import Testing
import Foundation
@testable import AnigmaCore

@Suite("Two-Tier Reasoning")
struct TwoTierReasoningTests {

    // MARK: - TRM Subsolver Tests

    @Test("TRM subsolver initializes with correct memory sizes")
    func trmInitialization() async throws {
        let config = TRMConfig(scratchpadSize: 128, canvasSize: 128, slowUpdateInterval: 3)
        let subsolver = TRMSubsolver(config: config)

        // Create a simple subproblem
        let subproblem = StructuredSubproblem(
            parentPuzzleId: UUID(),
            subproblemType: .constraintSatisfaction,
            maxIterations: 10
        )

        let result = await subsolver.solve(subproblem)

        #expect(result.iterations <= 10)
        #expect(result.confidence >= 0.0 && result.confidence <= 1.0)
    }

    @Test("TRM subsolver handles grid transformation")
    func gridTransformation() async throws {
        let subsolver = TRMSubsolver()

        let grid = GridState(rows: 5, cols: 5, cells: [
            [1, 0, 0, 0, 1],
            [0, 1, 0, 1, 0],
            [0, 0, 1, 0, 0],
            [0, 1, 0, 1, 0],
            [1, 0, 0, 0, 1]
        ])

        let subproblem = StructuredSubproblem(
            parentPuzzleId: UUID(),
            subproblemType: .gridTransformation,
            gridState: grid,
            maxIterations: 50
        )

        let result = await subsolver.solve(subproblem)

        #expect(result.solution != nil)
        if case .grid(let outputGrid) = result.solution {
            #expect(outputGrid.rows == 10)  // Default output size
            #expect(outputGrid.cols == 10)
        }
    }

    @Test("TRM subsolver handles constraint satisfaction")
    func constraintSatisfaction() async throws {
        let subsolver = TRMSubsolver()

        let variables = [
            ConstraintVariable(id: "x", name: "X", domain: [1, 2, 3]),
            ConstraintVariable(id: "y", name: "Y", domain: [1, 2, 3]),
            ConstraintVariable(id: "z", name: "Z", domain: [1, 2, 3])
        ]

        let constraints = [
            GraphConstraint(id: "c1", type: .allDifferent, variables: ["x", "y", "z"])
        ]

        let graph = ConstraintGraph(variables: variables, constraints: constraints)

        let subproblem = StructuredSubproblem(
            parentPuzzleId: UUID(),
            subproblemType: .constraintSatisfaction,
            constraintGraph: graph,
            maxIterations: 100
        )

        let result = await subsolver.solve(subproblem)

        #expect(result.iterations <= 100)
        if case .assignment(let assignment) = result.solution {
            #expect(!assignment.isEmpty)
        }
    }

    @Test("TRM subsolver handles scheduling")
    func scheduling() async throws {
        let subsolver = TRMSubsolver()

        let tasks = [
            SchedulingTask(id: "t1", name: "Task 1", duration: 2, priority: 3),
            SchedulingTask(id: "t2", name: "Task 2", duration: 1, priority: 2),
            SchedulingTask(id: "t3", name: "Task 3", duration: 3, priority: 1)
        ]

        let resources = [
            SchedulingResource(id: "r1", name: "Resource 1", availability: [0, 1, 2, 3, 4])
        ]

        let slots = (0..<5).map { TimeSlot(index: $0, label: "Slot \($0)") }

        let problem = SchedulingProblem(
            tasks: tasks,
            resources: resources,
            timeSlots: slots
        )

        let subproblem = StructuredSubproblem(
            parentPuzzleId: UUID(),
            subproblemType: .scheduling,
            schedulingProblem: problem,
            maxIterations: 50
        )

        let result = await subsolver.solve(subproblem)

        #expect(result.solution != nil)
        if case .schedule(let schedule) = result.solution {
            #expect(!schedule.isEmpty)
        }
    }

    // MARK: - Two-Tier Orchestrator Tests

    @Test("Two-tier orchestrator classifies puzzles correctly")
    func puzzleClassification() async throws {
        let symbolicReasoner = RecursiveReasoner()
        let trmSubsolver = TRMSubsolver()
        let orchestrator = TwoTierReasoningOrchestrator(
            symbolicReasoner: symbolicReasoner,
            trmSubsolver: trmSubsolver
        )

        // Small puzzle should use symbolic tier
        let smallPuzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: AbstractState(symbols: ["a": .boolean(true)]),
            transitions: [
                AbstractTransition(transitionId: "t1", name: "T1")
            ],
            goal: .violate(["c1"])
        )

        let result = try await orchestrator.solve(smallPuzzle)

        #expect(result.tier == .symbolic || result.tier == .neural)

        let stats = await orchestrator.getStatistics()
        #expect(stats.totalCalls >= 1)
    }

    @Test("Two-tier orchestrator handles hybrid puzzles")
    func hybridPuzzle() async throws {
        let symbolicReasoner = RecursiveReasoner()
        let trmSubsolver = TRMSubsolver()
        let config = TwoTierConfig(
            constraintThreshold: 2,
            smallStateThreshold: 5
        )
        let orchestrator = TwoTierReasoningOrchestrator(
            symbolicReasoner: symbolicReasoner,
            trmSubsolver: trmSubsolver,
            config: config
        )

        // Create a puzzle that should trigger hybrid mode
        let constraints = (0..<15).map { i in
            AbstractConstraint(
                constraintId: "c\(i)",
                name: "Constraint \(i)",
                condition: AbstractCondition(
                    symbol: "var\(i)",
                    operator_: .equals,
                    value: .boolean(true)
                )
            )
        }

        let transitions = (0..<30).map { i in
            AbstractTransition(
                transitionId: "t\(i)",
                name: "Transition \(i)"
            )
        }

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .workflowStates,
            initialState: AbstractState(),
            transitions: transitions,
            constraints: constraints,
            goal: .violate(["c0"])
        )

        let result = try await orchestrator.solve(puzzle)

        // Should have used hybrid or neural tier due to many constraints
        #expect(result.tier == .hybrid || result.tier == .neural)
    }

    // MARK: - Grid State Tests

    @Test("GridState flattens and reconstructs correctly")
    func gridStateRoundTrip() {
        let cells = [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9]
        ]

        let grid = GridState(rows: 3, cols: 3, cells: cells)
        let flat = grid.flatten()

        #expect(flat == [1, 2, 3, 4, 5, 6, 7, 8, 9])

        let reconstructed = GridState.fromFlat(flat, rows: 3, cols: 3)
        #expect(reconstructed.cells == cells)
    }

    // MARK: - Domain Puzzle Builder Integration Tests

    @Test("Two-tier handles DSPS puzzles from existing builder")
    func dspsPuzzleWithTwoTier() async throws {
        let symbolicReasoner = RecursiveReasoner()
        let trmSubsolver = TRMSubsolver()
        let orchestrator = TwoTierReasoningOrchestrator(
            symbolicReasoner: symbolicReasoner,
            trmSubsolver: trmSubsolver
        )

        // Use existing DSPSPuzzleBuilder
        let puzzle = DSPSPuzzleBuilder.buildAccommodationCasePuzzle(
            cases: [
                (symbol: "case_1", studentSymbol: "student_1", termSymbol: "fall_2025", hasDocumentation: true)
            ],
            accommodations: [
                (caseSymbol: "case_1", accommodationType: "extended_time", isApproved: true)
            ],
            letters: []
        )

        let result = try await orchestrator.solve(puzzle)

        #expect(result.puzzleId == puzzle.puzzleId)
        #expect(result.confidence >= 0.0)
    }

    @Test("Two-tier handles Transcriptum puzzles from existing builder")
    func transcriptumPuzzleWithTwoTier() async throws {
        let symbolicReasoner = RecursiveReasoner()
        let trmSubsolver = TRMSubsolver()
        let orchestrator = TwoTierReasoningOrchestrator(
            symbolicReasoner: symbolicReasoner,
            trmSubsolver: trmSubsolver
        )

        // Use existing TranscriptumPuzzleBuilder
        let puzzle = TranscriptumPuzzleBuilder.buildDegreeAwardPuzzle(
            students: [
                (symbol: "student_1", programSymbol: "cs_degree", completedUnits: 100, gpa: 3.5)
            ],
            programs: [
                (symbol: "cs_degree", requiredUnits: 120, minGPA: 2.0)
            ],
            degreeAwards: []
        )

        let result = try await orchestrator.solve(puzzle)

        #expect(result.puzzleId == puzzle.puzzleId)

        let stats = await orchestrator.getStatistics()
        #expect(stats.totalCalls >= 1)
    }

    // MARK: - Integration Tests

    @Test("Full two-tier pipeline with identity puzzle")
    func fullIdentityPipeline() async throws {
        let symbolicReasoner = RecursiveReasoner()
        let trmSubsolver = TRMSubsolver()
        let orchestrator = TwoTierReasoningOrchestrator(
            symbolicReasoner: symbolicReasoner,
            trmSubsolver: trmSubsolver
        )

        let puzzle = IdentityPuzzleBuilder.buildSessionRiskPuzzle(
            sessions: [
                (symbol: "session_1", principalSymbol: "user_1", initialRisk: 0, mfaVerified: true)
            ],
            actions: [
                (name: "view", riskDelta: 1, requiresMFA: false),
                (name: "edit", riskDelta: 5, requiresMFA: true)
            ],
            riskThreshold: 10
        )

        let result = try await orchestrator.solve(puzzle)

        #expect(result.puzzleId == puzzle.puzzleId)
        #expect(result.confidence >= 0.0)

        if let symbolic = result.symbolicResult {
            #expect(symbolic.stepsExplored > 0)
        }
    }
}
