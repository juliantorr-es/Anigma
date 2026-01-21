//
//  MetaPuzzles.swift
//  AnigmaCore
//
//  Meta-puzzles for self-testing the reasoning kernel.
//  The gremlin proves it's still sane by solving known puzzles.
//
//  Meta-puzzles are:
//  - Small puzzles with known outcomes
//  - Used to detect model drift or reliability problems
//  - Run periodically as runtime health checks
//

import Foundation
import ContractsCore

// MARK: - Meta-Puzzle Definition

/// A meta-puzzle with known expected outcome.
public struct MetaPuzzle: Sendable, Identifiable {
    /// Unique identifier.
    public let id: UUID

    /// Name of this meta-puzzle.
    public let name: String

    /// Category of the test.
    public let category: MetaPuzzleCategory

    /// The puzzle to solve.
    public let puzzle: ReasoningPuzzle

    /// Expected outcome.
    public let expectedOutcome: ReasoningOutcome

    /// Expected path (if applicable).
    public let expectedPath: [String]?

    /// Expected constraints to be violated (if applicable).
    public let expectedViolations: [String]?

    /// Maximum allowed duration (ms) before considered slow.
    public let maxDurationMs: Int

    /// Description of what this tests.
    public let description: String

    public init(
        id: UUID = UUID(),
        name: String,
        category: MetaPuzzleCategory,
        puzzle: ReasoningPuzzle,
        expectedOutcome: ReasoningOutcome,
        expectedPath: [String]? = nil,
        expectedViolations: [String]? = nil,
        maxDurationMs: Int = 1000,
        description: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.puzzle = puzzle
        self.expectedOutcome = expectedOutcome
        self.expectedPath = expectedPath
        self.expectedViolations = expectedViolations
        self.maxDurationMs = maxDurationMs
        self.description = description
    }
}

/// Categories of meta-puzzles.
public enum MetaPuzzleCategory: String, Sendable, Codable, CaseIterable {
    /// Puzzles where invariants are unbreakable.
    case provablyUnbreakable = "provably_unbreakable"

    /// Puzzles with simple, known counterexamples.
    case knownCounterexample = "known_counterexample"

    /// Puzzles that are unsatisfiable.
    case unsatisfiable = "unsatisfiable"

    /// Puzzles designed to expose looping behavior.
    case loopDetection = "loop_detection"

    /// Puzzles designed to test search efficiency.
    case searchEfficiency = "search_efficiency"

    /// Puzzles that test edge case handling.
    case edgeCases = "edge_cases"
}

// MARK: - Meta-Puzzle Result

/// Result from running a meta-puzzle.
public struct MetaPuzzleResult: Sendable {
    /// The meta-puzzle that was run.
    public let metaPuzzleId: UUID

    /// The actual result from the kernel.
    public let actualResult: ReasoningResult

    /// Whether the outcome matched expectation.
    public let outcomeMatched: Bool

    /// Whether the path matched (if applicable).
    public let pathMatched: Bool?

    /// Whether violations matched (if applicable).
    public let violationsMatched: Bool?

    /// Whether timing was acceptable.
    public let timingAcceptable: Bool

    /// Overall pass/fail.
    public var passed: Bool {
        outcomeMatched && (pathMatched ?? true) && (violationsMatched ?? true)
    }

    /// Failure reason (if failed).
    public let failureReason: String?

    public init(
        metaPuzzleId: UUID,
        actualResult: ReasoningResult,
        outcomeMatched: Bool,
        pathMatched: Bool? = nil,
        violationsMatched: Bool? = nil,
        timingAcceptable: Bool,
        failureReason: String? = nil
    ) {
        self.metaPuzzleId = metaPuzzleId
        self.actualResult = actualResult
        self.outcomeMatched = outcomeMatched
        self.pathMatched = pathMatched
        self.violationsMatched = violationsMatched
        self.timingAcceptable = timingAcceptable
        self.failureReason = failureReason
    }
}

// MARK: - Standard Meta-Puzzles

/// Library of standard meta-puzzles for kernel validation.
public struct StandardMetaPuzzles {

    /// All standard meta-puzzles.
    public static let all: [MetaPuzzle] = [
        // Category: Provably Unbreakable
        triviallyUnbreakable(),
        isolatedStates(),
        strongInvariant(),

        // Category: Known Counterexample
        trivialViolation(),
        twoStepViolation(),
        hiddenViolation(),

        // Category: Unsatisfiable
        impossibleGoal(),
        noTransitions(),
        conflictingPreconditions(),

        // Category: Loop Detection
        simpleLoop(),

        // Category: Edge Cases
        emptyState(),
        singleTransition()
    ]

    /// Gets puzzles by category.
    public static func byCategory(_ category: MetaPuzzleCategory) -> [MetaPuzzle] {
        all.filter { $0.category == category }
    }

    /// Gets a random subset for quick health check.
    public static func randomSubset(count: Int) -> [MetaPuzzle] {
        Array(all.shuffled().prefix(count))
    }

    // MARK: - Provably Unbreakable

    /// A puzzle where no sequence can violate the constraint.
    public static func triviallyUnbreakable() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["x": .integer(0), "invariant_holds": .boolean(true)]
        )

        // Use transitions that don't create infinite states
        let transitions = [
            AbstractTransition(
                transitionId: "toggle_x",
                name: "Toggle x between 0 and 1",
                preconditions: [
                    AbstractCondition(symbol: "x", operator_: .equals, value: .integer(0))
                ],
                effects: [
                    AbstractEffect(symbol: "x", effectType: .set, value: .integer(1))
                ]
            ),
            AbstractTransition(
                transitionId: "toggle_x_back",
                name: "Toggle x back to 0",
                preconditions: [
                    AbstractCondition(symbol: "x", operator_: .equals, value: .integer(1))
                ],
                effects: [
                    AbstractEffect(symbol: "x", effectType: .set, value: .integer(0))
                ]
            )
        ]

        // Constraint: invariant_holds must stay true (and nothing can change it)
        let constraints = [
            AbstractConstraint(
                constraintId: "invariant",
                name: "Invariant must hold",
                condition: AbstractCondition(symbol: "invariant_holds", operator_: .equals, value: .boolean(true)),
                severity: .violation
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .invariantCheck,
            domain: .compliance,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .proveInvariant(),
            maxSteps: 20
        )

        return MetaPuzzle(
            name: "Trivially Unbreakable",
            category: .provablyUnbreakable,
            puzzle: puzzle,
            expectedOutcome: .provedInvariant,
            description: "No transition can violate the invariant because nothing modifies invariant_holds."
        )
    }

    /// A puzzle with isolated states that cannot reach violation.
    public static func isolatedStates() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["region": .category("safe"), "danger_accessed": .boolean(false)]
        )

        let transitions = [
            AbstractTransition(
                transitionId: "move_in_safe",
                name: "Move within safe region",
                preconditions: [
                    AbstractCondition(symbol: "region", operator_: .equals, value: .category("safe"))
                ],
                effects: []  // No state change
            )
        ]

        let constraints = [
            AbstractConstraint(
                constraintId: "no_danger",
                name: "Cannot access danger",
                condition: AbstractCondition(symbol: "danger_accessed", operator_: .equals, value: .boolean(false)),
                severity: .violation
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .verifyCompliance,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .proveInvariant(),
            maxSteps: 10
        )

        return MetaPuzzle(
            name: "Isolated States",
            category: .provablyUnbreakable,
            puzzle: puzzle,
            expectedOutcome: .provedInvariant,
            description: "The danger region is unreachable from the safe region."
        )
    }

    /// A puzzle with a strong invariant that all transitions preserve.
    public static func strongInvariant() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["a": .integer(5), "b": .integer(5)]
        )

        // All transitions preserve a + b = 10
        let transitions = [
            AbstractTransition(
                transitionId: "transfer_a_to_b",
                name: "Transfer from A to B",
                preconditions: [
                    AbstractCondition(symbol: "a", operator_: .greaterThan, value: .integer(0))
                ],
                effects: [
                    AbstractEffect(symbol: "a", effectType: .decrement, value: .integer(1)),
                    AbstractEffect(symbol: "b", effectType: .increment, value: .integer(1))
                ]
            ),
            AbstractTransition(
                transitionId: "transfer_b_to_a",
                name: "Transfer from B to A",
                preconditions: [
                    AbstractCondition(symbol: "b", operator_: .greaterThan, value: .integer(0))
                ],
                effects: [
                    AbstractEffect(symbol: "b", effectType: .decrement, value: .integer(1)),
                    AbstractEffect(symbol: "a", effectType: .increment, value: .integer(1))
                ]
            )
        ]

        // Note: This constraint checks that a <= 10, which is always true if starting at a=5, b=5
        // and only transferring between them
        let constraints = [
            AbstractConstraint(
                constraintId: "bounded_a",
                name: "A must stay bounded",
                condition: AbstractCondition(symbol: "a", operator_: .lessThan, value: .integer(11)),
                severity: .violation
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .verifyCompliance,
            domain: .compliance,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .proveInvariant(),
            maxSteps: 50
        )

        return MetaPuzzle(
            name: "Strong Invariant",
            category: .provablyUnbreakable,
            puzzle: puzzle,
            expectedOutcome: .provedInvariant,
            description: "All transitions preserve the conservation law, so a never exceeds 10."
        )
    }

    // MARK: - Known Counterexample

    /// A puzzle with an immediate, obvious violation.
    public static func trivialViolation() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["locked": .boolean(false)]
        )

        let transitions = [
            AbstractTransition(
                transitionId: "unlock",
                name: "Unlock (violation)",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "unlocked", effectType: .set, value: .boolean(true))
                ]
            )
        ]

        let constraints = [
            AbstractConstraint(
                constraintId: "stay_locked",
                name: "Must stay locked",
                condition: AbstractCondition(symbol: "unlocked", operator_: .isNil, value: .boolean(true)),
                severity: .violation
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .accessControl,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(["stay_locked"]),
            maxSteps: 5
        )

        return MetaPuzzle(
            name: "Trivial Violation",
            category: .knownCounterexample,
            puzzle: puzzle,
            expectedOutcome: .foundViolation,
            expectedPath: ["unlock"],
            expectedViolations: ["stay_locked"],
            description: "A single transition immediately violates the constraint."
        )
    }

    /// A puzzle requiring exactly two steps to violate.
    public static func twoStepViolation() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["step": .integer(0)]
        )

        let transitions = [
            AbstractTransition(
                transitionId: "step1",
                name: "First step",
                preconditions: [
                    AbstractCondition(symbol: "step", operator_: .equals, value: .integer(0))
                ],
                effects: [
                    AbstractEffect(symbol: "step", effectType: .set, value: .integer(1))
                ]
            ),
            AbstractTransition(
                transitionId: "step2",
                name: "Second step (violation)",
                preconditions: [
                    AbstractCondition(symbol: "step", operator_: .equals, value: .integer(1))
                ],
                effects: [
                    AbstractEffect(symbol: "step", effectType: .set, value: .integer(2)),
                    AbstractEffect(symbol: "violated", effectType: .set, value: .boolean(true))
                ]
            )
        ]

        let constraints = [
            AbstractConstraint(
                constraintId: "no_step2",
                name: "Cannot reach step 2",
                condition: AbstractCondition(symbol: "step", operator_: .lessThan, value: .integer(2)),
                severity: .violation
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .compliance,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(["no_step2"]),
            maxSteps: 10
        )

        return MetaPuzzle(
            name: "Two-Step Violation",
            category: .knownCounterexample,
            puzzle: puzzle,
            expectedOutcome: .foundViolation,
            expectedPath: ["step1", "step2"],
            description: "Requires exactly two transitions to reach the violation."
        )
    }

    /// A puzzle with a non-obvious violation path.
    public static func hiddenViolation() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["x": .integer(0), "y": .integer(0), "z": .integer(0)]
        )

        let transitions = [
            AbstractTransition(
                transitionId: "inc_x",
                name: "Increment X",
                preconditions: [],
                effects: [AbstractEffect(symbol: "x", effectType: .increment, value: .integer(1))]
            ),
            AbstractTransition(
                transitionId: "inc_y",
                name: "Increment Y",
                preconditions: [
                    AbstractCondition(symbol: "x", operator_: .greaterThan, value: .integer(1))
                ],
                effects: [AbstractEffect(symbol: "y", effectType: .increment, value: .integer(1))]
            ),
            AbstractTransition(
                transitionId: "inc_z",
                name: "Increment Z",
                preconditions: [
                    AbstractCondition(symbol: "y", operator_: .greaterThan, value: .integer(0))
                ],
                effects: [AbstractEffect(symbol: "z", effectType: .increment, value: .integer(1))]
            )
        ]

        let constraints = [
            AbstractConstraint(
                constraintId: "z_stays_zero",
                name: "Z must stay zero",
                condition: AbstractCondition(symbol: "z", operator_: .equals, value: .integer(0)),
                severity: .violation
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .workflowStates,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(["z_stays_zero"]),
            maxSteps: 20
        )

        return MetaPuzzle(
            name: "Hidden Violation",
            category: .knownCounterexample,
            puzzle: puzzle,
            expectedOutcome: .foundViolation,
            description: "Requires a specific sequence (inc_x, inc_x, inc_y, inc_z) to violate."
        )
    }

    // MARK: - Unsatisfiable

    /// A puzzle with an impossible goal state.
    public static func impossibleGoal() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["value": .integer(0)]
        )

        // Can only increment, never reach -1
        let transitions = [
            AbstractTransition(
                transitionId: "increment",
                name: "Increment",
                preconditions: [],
                effects: [AbstractEffect(symbol: "value", effectType: .increment, value: .integer(1))]
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .compliance,
            initialState: initialState,
            transitions: transitions,
            constraints: [],
            goal: .reach([
                AbstractCondition(symbol: "value", operator_: .lessThan, value: .integer(0))
            ]),
            maxSteps: 10
        )

        return MetaPuzzle(
            name: "Impossible Goal",
            category: .unsatisfiable,
            puzzle: puzzle,
            expectedOutcome: .notFound,
            description: "The goal (value < 0) is unreachable since we can only increment."
        )
    }

    /// A puzzle with no available transitions.
    public static func noTransitions() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["stuck": .boolean(true)]
        )

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .compliance,
            initialState: initialState,
            transitions: [],
            constraints: [
                AbstractConstraint(
                    constraintId: "must_move",
                    name: "Must be able to move",
                    condition: AbstractCondition(symbol: "moved", operator_: .equals, value: .boolean(true)),
                    severity: .violation
                )
            ],
            goal: .violate(["must_move"]),
            maxSteps: 5
        )

        return MetaPuzzle(
            name: "No Transitions",
            category: .unsatisfiable,
            puzzle: puzzle,
            expectedOutcome: .notFound,
            description: "With no transitions, no violation can occur."
        )
    }

    /// A puzzle where preconditions can never be satisfied.
    public static func conflictingPreconditions() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["a": .boolean(true), "b": .boolean(false)]
        )

        let transitions = [
            AbstractTransition(
                transitionId: "impossible",
                name: "Impossible transition",
                preconditions: [
                    AbstractCondition(symbol: "a", operator_: .equals, value: .boolean(true)),
                    AbstractCondition(symbol: "a", operator_: .equals, value: .boolean(false))
                ],
                effects: [
                    AbstractEffect(symbol: "violated", effectType: .set, value: .boolean(true))
                ]
            )
        ]

        let constraints = [
            AbstractConstraint(
                constraintId: "no_violation",
                name: "No violation",
                condition: AbstractCondition(symbol: "violated", operator_: .isNil, value: .boolean(true)),
                severity: .violation
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .compliance,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(["no_violation"]),
            maxSteps: 5
        )

        return MetaPuzzle(
            name: "Conflicting Preconditions",
            category: .unsatisfiable,
            puzzle: puzzle,
            expectedOutcome: .notFound,
            description: "The only transition has contradictory preconditions."
        )
    }

    // MARK: - Loop Detection

    /// A puzzle that could loop forever without proper detection.
    public static func simpleLoop() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["counter": .integer(0), "max": .integer(5)]
        )

        let transitions = [
            AbstractTransition(
                transitionId: "loop",
                name: "Loop increment",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "counter", effectType: .increment, value: .integer(1))
                ]
            )
        ]

        let constraints = [
            AbstractConstraint(
                constraintId: "bounded",
                name: "Counter must stay bounded",
                condition: AbstractCondition(symbol: "counter", operator_: .lessThan, value: .integer(10)),
                severity: .violation
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .findViolation,
            domain: .automationRules,
            initialState: initialState,
            transitions: transitions,
            constraints: constraints,
            goal: .violate(["bounded"]),
            maxSteps: 15
        )

        return MetaPuzzle(
            name: "Simple Loop",
            category: .loopDetection,
            puzzle: puzzle,
            expectedOutcome: .foundViolation,
            description: "The kernel must handle repeated states and find the violation at counter=10."
        )
    }

    // MARK: - Edge Cases

    /// A puzzle with completely empty initial state.
    public static func emptyState() -> MetaPuzzle {
        let initialState = AbstractState.empty

        let transitions = [
            AbstractTransition(
                transitionId: "create",
                name: "Create value",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "exists", effectType: .set, value: .boolean(true))
                ]
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .dataLifecycle,
            initialState: initialState,
            transitions: transitions,
            constraints: [],
            goal: .reach([
                AbstractCondition(symbol: "exists", operator_: .equals, value: .boolean(true))
            ]),
            maxSteps: 5
        )

        return MetaPuzzle(
            name: "Empty State",
            category: .edgeCases,
            puzzle: puzzle,
            expectedOutcome: .foundPath,
            expectedPath: ["create"],
            description: "Tests handling of empty initial state."
        )
    }

    /// A puzzle with exactly one transition.
    public static func singleTransition() -> MetaPuzzle {
        let initialState = AbstractState(
            symbols: ["done": .boolean(false)]
        )

        let transitions = [
            AbstractTransition(
                transitionId: "finish",
                name: "Finish",
                preconditions: [],
                effects: [
                    AbstractEffect(symbol: "done", effectType: .set, value: .boolean(true))
                ]
            )
        ]

        let puzzle = ReasoningPuzzle(
            puzzleType: .findPath,
            domain: .workflowStates,
            initialState: initialState,
            transitions: transitions,
            constraints: [],
            goal: .reach([
                AbstractCondition(symbol: "done", operator_: .equals, value: .boolean(true))
            ]),
            maxSteps: 5
        )

        return MetaPuzzle(
            name: "Single Transition",
            category: .edgeCases,
            puzzle: puzzle,
            expectedOutcome: .foundPath,
            expectedPath: ["finish"],
            description: "Minimal puzzle with just one transition."
        )
    }
}

// MARK: - Meta-Puzzle Runner

/// Runs meta-puzzles to validate kernel sanity.
public actor MetaPuzzleRunner {
    /// The kernel to test.
    private let kernel: RecursiveReasoner

    /// Run history.
    private var runHistory: [MetaPuzzleRunRecord] = []

    /// Audit log.
    private var auditLog: (any AuditLogging)?

    public init(config: ReasonerConfig = ReasonerConfig()) {
        self.kernel = RecursiveReasoner(config: config)
    }

    /// Configures the runner.
    public func configure(auditLog: any AuditLogging) async {
        self.auditLog = auditLog
        await kernel.setAuditLog(auditLog)
    }

    /// Runs a single meta-puzzle and validates the result.
    public func run(_ metaPuzzle: MetaPuzzle) async -> MetaPuzzleResult {
        let startTime = Date()

        do {
            let result = try await kernel.solve(metaPuzzle.puzzle)

            let outcomeMatched = result.outcome == metaPuzzle.expectedOutcome

            var pathMatched: Bool?
            if let expectedPath = metaPuzzle.expectedPath {
                pathMatched = result.transitionSequence == expectedPath
            }

            var violationsMatched: Bool?
            if let expectedViolations = metaPuzzle.expectedViolations {
                violationsMatched = Set(result.violatedConstraints) == Set(expectedViolations)
            }

            let timingAcceptable = result.durationMs <= metaPuzzle.maxDurationMs

            var failureReason: String?
            if !outcomeMatched {
                failureReason = "Expected \(metaPuzzle.expectedOutcome.rawValue), got \(result.outcome.rawValue)"
            } else if pathMatched == false {
                failureReason = "Path mismatch: expected \(metaPuzzle.expectedPath ?? []), got \(result.transitionSequence)"
            } else if violationsMatched == false {
                failureReason = "Violations mismatch: expected \(metaPuzzle.expectedViolations ?? []), got \(result.violatedConstraints)"
            }

            let metaResult = MetaPuzzleResult(
                metaPuzzleId: metaPuzzle.id,
                actualResult: result,
                outcomeMatched: outcomeMatched,
                pathMatched: pathMatched,
                violationsMatched: violationsMatched,
                timingAcceptable: timingAcceptable,
                failureReason: failureReason
            )

            // Record history
            recordRun(metaPuzzle: metaPuzzle, result: metaResult, startTime: startTime)

            return metaResult

        } catch {
            let errorResult = ReasoningResult(
                puzzleId: metaPuzzle.puzzle.puzzleId,
                outcome: .error,
                explanation: error.localizedDescription
            )

            let metaResult = MetaPuzzleResult(
                metaPuzzleId: metaPuzzle.id,
                actualResult: errorResult,
                outcomeMatched: false,
                timingAcceptable: false,
                failureReason: "Kernel error: \(error.localizedDescription)"
            )

            recordRun(metaPuzzle: metaPuzzle, result: metaResult, startTime: startTime)

            return metaResult
        }
    }

    /// Runs all standard meta-puzzles.
    public func runAll() async -> MetaPuzzleSuiteResult {
        var results: [MetaPuzzleResult] = []

        for metaPuzzle in StandardMetaPuzzles.all {
            let result = await run(metaPuzzle)
            results.append(result)
        }

        return MetaPuzzleSuiteResult(
            runAt: Date(),
            results: results,
            totalPassed: results.filter { $0.passed }.count,
            totalFailed: results.filter { !$0.passed }.count
        )
    }

    /// Runs a random subset for quick health check.
    public func runHealthCheck(count: Int = 5) async -> MetaPuzzleSuiteResult {
        let subset = StandardMetaPuzzles.randomSubset(count: count)
        var results: [MetaPuzzleResult] = []

        for metaPuzzle in subset {
            let result = await run(metaPuzzle)
            results.append(result)
        }

        return MetaPuzzleSuiteResult(
            runAt: Date(),
            results: results,
            totalPassed: results.filter { $0.passed }.count,
            totalFailed: results.filter { !$0.passed }.count
        )
    }

    /// Gets recent run history.
    public func getRecentHistory(limit: Int = 100) -> [MetaPuzzleRunRecord] {
        Array(runHistory.suffix(limit))
    }

    /// Gets pass rate for a specific meta-puzzle.
    public func getPassRate(for metaPuzzleId: UUID) -> Double? {
        let runs = runHistory.filter { $0.metaPuzzleId == metaPuzzleId }
        guard !runs.isEmpty else { return nil }
        let passed = runs.filter { $0.passed }.count
        return Double(passed) / Double(runs.count)
    }

    // MARK: - Private

    private func recordRun(metaPuzzle: MetaPuzzle, result: MetaPuzzleResult, startTime: Date) {
        let record = MetaPuzzleRunRecord(
            runAt: startTime,
            metaPuzzleId: metaPuzzle.id,
            metaPuzzleName: metaPuzzle.name,
            category: metaPuzzle.category,
            passed: result.passed,
            durationMs: result.actualResult.durationMs,
            failureReason: result.failureReason
        )

        runHistory.append(record)

        // Keep history bounded
        if runHistory.count > 10000 {
            runHistory.removeFirst(runHistory.count - 10000)
        }

        // Log failures to audit
        if !result.passed {
            Task {
                try? await auditLog?.recordEvent(
                    id: UUID(),
                    type: ContractsCore.AuditEventType.custom,
                    principal: "meta_puzzle_runner",
                    module: "MetaPuzzleRunner",
                    description: "Meta-puzzle failed: \(metaPuzzle.name) - \(result.failureReason ?? "unknown")",
                    metadata: [
                        "meta_puzzle_id": metaPuzzle.id.uuidString,
                        "category": metaPuzzle.category.rawValue,
                        "expected_outcome": metaPuzzle.expectedOutcome.rawValue,
                        "actual_outcome": result.actualResult.outcome.rawValue,
                        "original_event_type": "systemError"
                    ]
                )
            }
        }
    }
}

/// Record of a meta-puzzle run.
public struct MetaPuzzleRunRecord: Sendable {
    public let runAt: Date
    public let metaPuzzleId: UUID
    public let metaPuzzleName: String
    public let category: MetaPuzzleCategory
    public let passed: Bool
    public let durationMs: Int
    public let failureReason: String?
}

/// Result from running a suite of meta-puzzles.
public struct MetaPuzzleSuiteResult: Sendable {
    public let runAt: Date
    public let results: [MetaPuzzleResult]
    public let totalPassed: Int
    public let totalFailed: Int

    public var passRate: Double {
        guard !results.isEmpty else { return 0 }
        return Double(totalPassed) / Double(results.count)
    }

    public var allPassed: Bool {
        totalFailed == 0
    }
}
