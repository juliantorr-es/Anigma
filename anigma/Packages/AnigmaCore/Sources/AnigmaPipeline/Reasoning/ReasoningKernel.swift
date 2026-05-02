//
//  ReasoningKernel.swift
//  AnigmaCore
//
//  Tiny Recursive Model (TRM) reasoning kernel for Anigma.
//  A sandboxed, constrained reasoning engine for edge-case discovery,
//  compliance probing, security testing, and adversarial analysis.
//
//  Design principles:
//  - TRM NEVER sees real data - only anonymized, abstract puzzles
//  - TRM NEVER writes to ECS - only returns candidate sequences
//  - TRM is treated as untrusted compute with strict containment
//  - All outputs go through governance before affecting state
//  - Model integrity is verified continuously
//
//  Security model:
//  - Process isolation (conceptual, enforced at deployment)
//  - Input abstraction (real data → anonymous symbols)
//  - Output sanitization (sequences → ProbeResults/TestCases)
//  - Rate limiting and resource caps
//  - Full audit trail
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import Foundation
import ContractsCore

// MARK: - Puzzle Representation

/// An abstract puzzle for the reasoning kernel.
/// Contains no real data, only anonymous symbols and structures.
public struct ReasoningPuzzle: Sendable, Codable {
    /// Unique puzzle identifier.
    public let puzzleId: UUID

    /// Type of puzzle.
    public let puzzleType: PuzzleType

    /// Domain this puzzle relates to.
    public let domain: ReasoningDomain

    /// State representation (anonymized).
    public let initialState: AbstractState

    /// Available transitions/actions.
    public let transitions: [AbstractTransition]

    /// Constraints that must hold.
    public let constraints: [AbstractConstraint]

    /// Goal condition to search for.
    public let goal: PuzzleGoal

    /// Maximum steps to explore.
    public let maxSteps: Int

    /// Maximum time budget in milliseconds.
    public let timeBudgetMs: Int

    /// Metadata (no sensitive info).
    public let metadata: [String: String]

    public init(
        puzzleId: UUID = UUID(),
        puzzleType: PuzzleType,
        domain: ReasoningDomain,
        initialState: AbstractState,
        transitions: [AbstractTransition],
        constraints: [AbstractConstraint] = [],
        goal: PuzzleGoal,
        maxSteps: Int = 100,
        timeBudgetMs: Int = 5000,
        metadata: [String: String] = [:]
    ) {
        self.puzzleId = puzzleId
        self.puzzleType = puzzleType
        self.domain = domain
        self.initialState = initialState
        self.transitions = transitions
        self.constraints = constraints
        self.goal = goal
        self.maxSteps = maxSteps
        self.timeBudgetMs = timeBudgetMs
        self.metadata = metadata
    }
}

/// Types of puzzles the kernel can solve.
public enum PuzzleType: String, Sendable, Codable {
    /// Find a path that violates a control/constraint.
    case findViolation = "find_violation"

    /// Verify no violation path exists.
    case verifyCompliance = "verify_compliance"

    /// Find optimal sequence to reach goal.
    case findPath = "find_path"

    /// Explore state space for anomalies.
    case exploreSpace = "explore_space"

    /// Check if system can reach bad state.
    case reachabilityAnalysis = "reachability_analysis"

    /// Test invariant preservation.
    case invariantCheck = "invariant_check"
}

/// Domains the kernel can reason about.
public enum ReasoningDomain: String, Sendable, Codable {
    /// Access control and identity.
    case accessControl = "access_control"

    /// Tenant isolation.
    case tenantIsolation = "tenant_isolation"

    /// Audit integrity.
    case auditIntegrity = "audit_integrity"

    /// Update/migration sequences.
    case updateSequence = "update_sequence"

    /// Automation rule interactions.
    case automationRules = "automation_rules"

    /// Workflow state transitions.
    case workflowStates = "workflow_states"

    /// Data lifecycle.
    case dataLifecycle = "data_lifecycle"

    /// General compliance.
    case compliance = "compliance"
}

/// Abstract state representation (no real data).
public struct AbstractState: Sendable, Codable {
    /// State vector as key-value pairs of symbols.
    public var symbols: [String: SymbolValue]

    /// Set memberships.
    public var sets: [String: Set<String>]

    /// Graph edges (for relationship reasoning).
    public var edges: [AbstractEdge]

    public init(
        symbols: [String: SymbolValue] = [:],
        sets: [String: Set<String>] = [:],
        edges: [AbstractEdge] = []
    ) {
        self.symbols = symbols
        self.sets = sets
        self.edges = edges
    }

    /// Creates an empty state.
    public static let empty = AbstractState()
}

/// Symbol value types.
public enum SymbolValue: Sendable, Codable, Equatable {
    case boolean(Bool)
    case integer(Int)
    case category(String)
    case set(Set<String>)

    public var asBool: Bool? {
        if case .boolean(let v) = self { return v }
        return nil
    }

    public var asInt: Int? {
        if case .integer(let v) = self { return v }
        return nil
    }
}

/// Abstract edge for graph representation.
public struct AbstractEdge: Sendable, Codable, Equatable {
    public let source: String
    public let target: String
    public let edgeType: String

    public init(source: String, target: String, edgeType: String) {
        self.source = source
        self.target = target
        self.edgeType = edgeType
    }
}

/// Abstract transition/action.
public struct AbstractTransition: Sendable, Codable {
    /// Transition identifier.
    public let transitionId: String

    /// Human-readable name.
    public let name: String

    /// Preconditions for this transition.
    public let preconditions: [AbstractCondition]

    /// Effects of applying this transition.
    public let effects: [AbstractEffect]

    /// Cost/weight of this transition.
    public let cost: Double

    public init(
        transitionId: String,
        name: String,
        preconditions: [AbstractCondition] = [],
        effects: [AbstractEffect] = [],
        cost: Double = 1.0
    ) {
        self.transitionId = transitionId
        self.name = name
        self.preconditions = preconditions
        self.effects = effects
        self.cost = cost
    }
}

/// Abstract condition.
public struct AbstractCondition: Sendable, Codable {
    public let symbol: String
    public let operator_: ConditionOp
    public let value: SymbolValue

    public init(symbol: String, operator_: ConditionOp, value: SymbolValue) {
        self.symbol = symbol
        self.operator_ = operator_
        self.value = value
    }

    /// Evaluates condition against state.
    public func evaluate(in state: AbstractState) -> Bool {
        guard let stateValue = state.symbols[symbol] else {
            return operator_ == .isNil
        }

        switch operator_ {
        case .equals:
            return stateValue == value
        case .notEquals:
            return stateValue != value
        case .greaterThan:
            if case .integer(let sv) = stateValue, case .integer(let v) = value {
                return sv > v
            }
            return false
        case .lessThan:
            if case .integer(let sv) = stateValue, case .integer(let v) = value {
                return sv < v
            }
            return false
        case .contains:
            if case .set(let sv) = stateValue, case .category(let v) = value {
                return sv.contains(v)
            }
            return false
        case .isNil:
            return false // We have a value, so not nil
        case .isNotNil:
            return true
        }
    }
}

/// Condition operators.
public enum ConditionOp: String, Sendable, Codable {
    case equals = "eq"
    case notEquals = "neq"
    case greaterThan = "gt"
    case lessThan = "lt"
    case contains = "contains"
    case isNil = "is_nil"
    case isNotNil = "is_not_nil"
}

/// Abstract effect of a transition.
public struct AbstractEffect: Sendable, Codable {
    public let symbol: String
    public let effectType: EffectType
    public let value: SymbolValue?

    public init(symbol: String, effectType: EffectType, value: SymbolValue? = nil) {
        self.symbol = symbol
        self.effectType = effectType
        self.value = value
    }

    /// Applies effect to state.
    public func apply(to state: inout AbstractState) {
        switch effectType {
        case .set:
            if let v = value {
                state.symbols[symbol] = v
            }
        case .increment:
            if case .integer(let current)? = state.symbols[symbol],
               case .integer(let delta)? = value {
                state.symbols[symbol] = .integer(current + delta)
            }
        case .decrement:
            if case .integer(let current)? = state.symbols[symbol],
               case .integer(let delta)? = value {
                state.symbols[symbol] = .integer(current - delta)
            }
        case .addToSet:
            if case .category(let v)? = value {
                var current = state.sets[symbol] ?? []
                current.insert(v)
                state.sets[symbol] = current
            }
        case .removeFromSet:
            if case .category(let v)? = value {
                state.sets[symbol]?.remove(v)
            }
        case .clear:
            state.symbols.removeValue(forKey: symbol)
        }
    }
}

/// Effect types.
public enum EffectType: String, Sendable, Codable {
    case set = "set"
    case increment = "increment"
    case decrement = "decrement"
    case addToSet = "add_to_set"
    case removeFromSet = "remove_from_set"
    case clear = "clear"
}

/// Abstract constraint that must hold.
public struct AbstractConstraint: Sendable, Codable {
    public let constraintId: String
    public let name: String
    public let condition: AbstractCondition
    public let severity: ConstraintSeverity

    public init(
        constraintId: String,
        name: String,
        condition: AbstractCondition,
        severity: ConstraintSeverity = .violation
    ) {
        self.constraintId = constraintId
        self.name = name
        self.condition = condition
        self.severity = severity
    }

    /// Checks if constraint is satisfied.
    public func isSatisfied(in state: AbstractState) -> Bool {
        condition.evaluate(in: state)
    }
}

/// Constraint severity levels.
public enum ConstraintSeverity: String, Sendable, Codable {
    /// Warning only.
    case warning = "warning"
    /// Violation of a control.
    case violation = "violation"
    /// Critical security violation.
    case critical = "critical"
}

/// Goal condition for puzzle solving.
public struct PuzzleGoal: Sendable, Codable {
    /// Goal type.
    public let goalType: GoalType

    /// Conditions that define the goal.
    public let conditions: [AbstractCondition]

    /// Constraints to violate (for findViolation puzzles).
    public let targetConstraints: [String]

    public init(
        goalType: GoalType,
        conditions: [AbstractCondition] = [],
        targetConstraints: [String] = []
    ) {
        self.goalType = goalType
        self.conditions = conditions
        self.targetConstraints = targetConstraints
    }

    /// Goal: reach a state matching all conditions.
    public static func reach(_ conditions: [AbstractCondition]) -> PuzzleGoal {
        PuzzleGoal(goalType: .reachState, conditions: conditions)
    }

    /// Goal: find a path that violates specified constraints.
    public static func violate(_ constraintIds: [String]) -> PuzzleGoal {
        PuzzleGoal(goalType: .violateConstraint, targetConstraints: constraintIds)
    }

    /// Goal: prove no constraint can be violated.
    public static func proveInvariant() -> PuzzleGoal {
        PuzzleGoal(goalType: .proveInvariant)
    }
}

/// Goal types.
public enum GoalType: String, Sendable, Codable {
    /// Reach a specific state.
    case reachState = "reach_state"

    /// Find violation path.
    case violateConstraint = "violate_constraint"

    /// Prove invariant holds.
    case proveInvariant = "prove_invariant"

    /// Explore and report.
    case explore = "explore"
}

// MARK: - Reasoning Result

/// Result from the reasoning kernel.
public struct ReasoningResult: Sendable {
    /// The puzzle that was solved.
    public let puzzleId: UUID

    /// Outcome of the reasoning.
    public let outcome: ReasoningOutcome

    /// Sequence of transitions that led to the result.
    public let transitionSequence: [String]

    /// Final state reached.
    public let finalState: AbstractState?

    /// Constraints violated (if any).
    public let violatedConstraints: [String]

    /// Confidence score (0-1).
    public let confidence: Double

    /// Steps explored.
    public let stepsExplored: Int

    /// Time taken in milliseconds.
    public let durationMs: Int

    /// Explanation of the result.
    public let explanation: String

    /// Whether this was truncated due to limits.
    public let truncated: Bool

    public init(
        puzzleId: UUID,
        outcome: ReasoningOutcome,
        transitionSequence: [String] = [],
        finalState: AbstractState? = nil,
        violatedConstraints: [String] = [],
        confidence: Double = 0.0,
        stepsExplored: Int = 0,
        durationMs: Int = 0,
        explanation: String = "",
        truncated: Bool = false
    ) {
        self.puzzleId = puzzleId
        self.outcome = outcome
        self.transitionSequence = transitionSequence
        self.finalState = finalState
        self.violatedConstraints = violatedConstraints
        self.confidence = confidence
        self.stepsExplored = stepsExplored
        self.durationMs = durationMs
        self.explanation = explanation
        self.truncated = truncated
    }
}

/// Outcomes of reasoning.
public enum ReasoningOutcome: String, Sendable, Codable {
    /// Found a path to the goal.
    case foundPath = "found_path"

    /// Found a violation.
    case foundViolation = "found_violation"

    /// No path/violation found within budget.
    case notFound = "not_found"

    /// Proved invariant holds.
    case provedInvariant = "proved_invariant"

    /// Exploration completed.
    case explorationComplete = "exploration_complete"

    /// Timed out.
    case timeout = "timeout"

    /// Error during reasoning.
    case error = "error"
}

// MARK: - Recursive Reasoner Actor

/// The sandboxed recursive reasoning kernel.
/// This actor NEVER sees real data and NEVER writes to ECS.
public actor RecursiveReasoner {
    /// Configuration for the reasoner.
    private let config: ReasonerConfig

    /// Audit log for recording all activity.
    private var auditLog: (any AuditLogging)?

    /// Metal-backed lane for prioritizing transition expansion.
    private let transitionLane = ReasoningTransitionLane()

    /// Total puzzles solved.
    private var totalPuzzlesSolved: Int = 0

    /// Total violations found.
    private var totalViolationsFound: Int = 0

    /// Rate limiter.
    private var recentCalls: [Date] = []

    /// Maximum calls per minute.
    private let maxCallsPerMinute: Int = 60

    public init(config: ReasonerConfig = ReasonerConfig()) {
        self.config = config
    }

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Solves a puzzle using recursive search.
    /// This is the main entry point.
    public func solve(_ puzzle: ReasoningPuzzle) async throws -> ReasoningResult {
        // Rate limiting
        try await checkRateLimit()

        // Validate puzzle size
        guard puzzle.transitions.count <= config.maxTransitions else {
            throw ReasoningError.puzzleTooLarge(
                actual: puzzle.transitions.count,
                max: config.maxTransitions
            )
        }

        guard puzzle.maxSteps <= config.maxStepsAllowed else {
            throw ReasoningError.budgetExceeded(
                requested: puzzle.maxSteps,
                max: config.maxStepsAllowed
            )
        }

        let startTime = Date()
        let deadline = startTime.addingTimeInterval(Double(min(puzzle.timeBudgetMs, config.maxTimeMs)) / 1000.0)

        // Log the attempt
        if let log = auditLog {
            try? await log.record(
                eventType: .automationTriggered,
                principal: "reasoning_kernel",
                module: "RecursiveReasoner",
                description: "Puzzle solving started: \(puzzle.puzzleType.rawValue) in \(puzzle.domain.rawValue)",
                metadata: [
                    "puzzle_id": puzzle.puzzleId.uuidString,
                    "puzzle_type": puzzle.puzzleType.rawValue,
                    "domain": puzzle.domain.rawValue
                ]
            )
        }

        // Solve based on puzzle type
        let result: ReasoningResult

        switch puzzle.puzzleType {
        case .findViolation:
            result = await searchForViolation(puzzle, deadline: deadline, startTime: startTime)
        case .verifyCompliance:
            result = await verifyNoViolation(puzzle, deadline: deadline, startTime: startTime)
        case .findPath:
            result = await searchForPath(puzzle, deadline: deadline, startTime: startTime)
        case .exploreSpace:
            result = await exploreStateSpace(puzzle, deadline: deadline, startTime: startTime)
        case .reachabilityAnalysis:
            result = await analyzeReachability(puzzle, deadline: deadline, startTime: startTime)
        case .invariantCheck:
            result = await checkInvariant(puzzle, deadline: deadline, startTime: startTime)
        }

        // Update stats
        totalPuzzlesSolved += 1
        if result.outcome == .foundViolation {
            totalViolationsFound += 1
        }

        // Log result
        if let log = auditLog {
            try? await log.record(
                eventType: .automationExecuted,
                principal: "reasoning_kernel",
                module: "RecursiveReasoner",
                description: "Puzzle solved: \(result.outcome.rawValue)",
                metadata: [
                    "puzzle_id": puzzle.puzzleId.uuidString,
                    "outcome": result.outcome.rawValue,
                    "steps_explored": String(result.stepsExplored),
                    "duration_ms": String(result.durationMs)
                ]
            )
        }

        return result
    }

    /// Gets statistics about the reasoner.
    public func getStatistics() -> ReasonerStatistics {
        ReasonerStatistics(
            totalPuzzlesSolved: totalPuzzlesSolved,
            totalViolationsFound: totalViolationsFound,
            config: config
        )
    }

    // MARK: - Private Search Methods

    private func searchForViolation(
        _ puzzle: ReasoningPuzzle,
        deadline: Date,
        startTime: Date
    ) async -> ReasoningResult {
        var frontier: [(state: AbstractState, path: [String])] = [(puzzle.initialState, [])]
        var visited: Set<String> = []
        var stepsExplored = 0

        while !frontier.isEmpty && Date() < deadline {
            guard stepsExplored < puzzle.maxSteps else {
                return makeResult(
                    puzzle: puzzle,
                    outcome: .notFound,
                    path: [],
                    stepsExplored: stepsExplored,
                    startTime: startTime,
                    explanation: "Step limit reached without finding violation",
                    truncated: true
                )
            }

            let (currentState, path) = frontier.removeFirst()
            let stateKey = stateHash(currentState)

            if visited.contains(stateKey) { continue }
            visited.insert(stateKey)
            stepsExplored += 1

            // Check if any target constraint is violated
            for constraintId in puzzle.goal.targetConstraints {
                if let constraint = puzzle.constraints.first(where: { $0.constraintId == constraintId }) {
                    if !constraint.isSatisfied(in: currentState) {
                        return makeResult(
                            puzzle: puzzle,
                            outcome: .foundViolation,
                            path: path,
                            finalState: currentState,
                            violatedConstraints: [constraintId],
                            confidence: 1.0,
                            stepsExplored: stepsExplored,
                            startTime: startTime,
                            explanation: "Found violation of constraint '\(constraint.name)' via path: \(path.joined(separator: " → "))"
                        )
                    }
                }
            }

            // Expand frontier
            for transition in await orderedTransitions(for: puzzle, state: currentState) {
                if canApply(transition, to: currentState) {
                    var newState = currentState
                    apply(transition, to: &newState)
                    let newPath = path + [transition.transitionId]
                    frontier.append((newState, newPath))
                }
            }
        }

        if Date() >= deadline {
            return makeResult(
                puzzle: puzzle,
                outcome: .timeout,
                stepsExplored: stepsExplored,
                startTime: startTime,
                explanation: "Time limit reached",
                truncated: true
            )
        }

        return makeResult(
            puzzle: puzzle,
            outcome: .notFound,
            stepsExplored: stepsExplored,
            startTime: startTime,
            explanation: "Exhaustive search found no violation path"
        )
    }

    private func verifyNoViolation(
        _ puzzle: ReasoningPuzzle,
        deadline: Date,
        startTime: Date
    ) async -> ReasoningResult {
        // Try to find a violation; if none found, we've "proved" compliance
        let violationResult = await searchForViolation(puzzle, deadline: deadline, startTime: startTime)

        if violationResult.outcome == .foundViolation {
            return violationResult
        } else if violationResult.outcome == .notFound && !violationResult.truncated {
            return makeResult(
                puzzle: puzzle,
                outcome: .provedInvariant,
                stepsExplored: violationResult.stepsExplored,
                startTime: startTime,
                explanation: "No violation path found in exhaustive search"
            )
        } else {
            return violationResult
        }
    }

    private func searchForPath(
        _ puzzle: ReasoningPuzzle,
        deadline: Date,
        startTime: Date
    ) async -> ReasoningResult {
        var frontier: [(state: AbstractState, path: [String], cost: Double)] = [(puzzle.initialState, [], 0)]
        var visited: Set<String> = []
        var stepsExplored = 0

        while !frontier.isEmpty && Date() < deadline {
            guard stepsExplored < puzzle.maxSteps else {
                return makeResult(
                    puzzle: puzzle,
                    outcome: .notFound,
                    stepsExplored: stepsExplored,
                    startTime: startTime,
                    truncated: true
                )
            }

            // Sort by cost (simple best-first)
            frontier.sort { $0.cost < $1.cost }
            let (currentState, path, _) = frontier.removeFirst()
            let stateKey = stateHash(currentState)

            if visited.contains(stateKey) { continue }
            visited.insert(stateKey)
            stepsExplored += 1

            // Check if goal is reached
            if goalReached(puzzle.goal, in: currentState) {
                return makeResult(
                    puzzle: puzzle,
                    outcome: .foundPath,
                    path: path,
                    finalState: currentState,
                    confidence: 1.0,
                    stepsExplored: stepsExplored,
                    startTime: startTime,
                    explanation: "Found path to goal: \(path.joined(separator: " → "))"
                )
            }

            // Expand
            for transition in await orderedTransitions(for: puzzle, state: currentState) {
                if canApply(transition, to: currentState) {
                    var newState = currentState
                    apply(transition, to: &newState)
                    let newPath = path + [transition.transitionId]
                    let newCost = !path.isEmpty ? Double(path.count) + transition.cost : transition.cost
                    frontier.append((newState, newPath, newCost))
                }
            }
        }

        return makeResult(
            puzzle: puzzle,
            outcome: Date() >= deadline ? .timeout : .notFound,
            stepsExplored: stepsExplored,
            startTime: startTime,
            truncated: Date() >= deadline
        )
    }

    private func exploreStateSpace(
        _ puzzle: ReasoningPuzzle,
        deadline: Date,
        startTime: Date
    ) async -> ReasoningResult {
        var frontier: [(state: AbstractState, path: [String])] = [(puzzle.initialState, [])]
        var visited: Set<String> = []
        var stepsExplored = 0
        var violationsFound: [String] = []

        while !frontier.isEmpty && Date() < deadline && stepsExplored < puzzle.maxSteps {
            let (currentState, path) = frontier.removeFirst()
            let stateKey = stateHash(currentState)

            if visited.contains(stateKey) { continue }
            visited.insert(stateKey)
            stepsExplored += 1

            // Check all constraints
            for constraint in puzzle.constraints {
                if !constraint.isSatisfied(in: currentState) && !violationsFound.contains(constraint.constraintId) {
                    violationsFound.append(constraint.constraintId)
                }
            }

            // Expand
            for transition in await orderedTransitions(for: puzzle, state: currentState) {
                if canApply(transition, to: currentState) {
                    var newState = currentState
                    apply(transition, to: &newState)
                    frontier.append((newState, path + [transition.transitionId]))
                }
            }
        }

        return makeResult(
            puzzle: puzzle,
            outcome: .explorationComplete,
            violatedConstraints: violationsFound,
            stepsExplored: stepsExplored,
            startTime: startTime,
            explanation: "Explored \(visited.count) states, found \(violationsFound.count) potential violations",
            truncated: Date() >= deadline || stepsExplored >= puzzle.maxSteps
        )
    }

    private func analyzeReachability(
        _ puzzle: ReasoningPuzzle,
        deadline: Date,
        startTime: Date
    ) async -> ReasoningResult {
        // Same as searchForPath but reports reachability
        await searchForPath(puzzle, deadline: deadline, startTime: startTime)
    }

    private func checkInvariant(
        _ puzzle: ReasoningPuzzle,
        deadline: Date,
        startTime: Date
    ) async -> ReasoningResult {
        // Explore and verify all constraints hold everywhere
        var frontier: [(state: AbstractState, path: [String])] = [(puzzle.initialState, [])]
        var visited: Set<String> = []
        var stepsExplored = 0

        while !frontier.isEmpty && Date() < deadline && stepsExplored < puzzle.maxSteps {
            let (currentState, path) = frontier.removeFirst()
            let stateKey = stateHash(currentState)

            if visited.contains(stateKey) { continue }
            visited.insert(stateKey)
            stepsExplored += 1

            // Check all constraints
            for constraint in puzzle.constraints {
                if !constraint.isSatisfied(in: currentState) {
                    return makeResult(
                        puzzle: puzzle,
                        outcome: .foundViolation,
                        path: path,
                        finalState: currentState,
                        violatedConstraints: [constraint.constraintId],
                        stepsExplored: stepsExplored,
                        startTime: startTime,
                        explanation: "Invariant '\(constraint.name)' violated via: \(path.joined(separator: " → "))"
                    )
                }
            }

            // Expand
            for transition in await orderedTransitions(for: puzzle, state: currentState) {
                if canApply(transition, to: currentState) {
                    var newState = currentState
                    apply(transition, to: &newState)
                    frontier.append((newState, path + [transition.transitionId]))
                }
            }
        }

        let exhaustive = frontier.isEmpty && Date() < deadline
        return makeResult(
            puzzle: puzzle,
            outcome: exhaustive ? .provedInvariant : .notFound,
            stepsExplored: stepsExplored,
            startTime: startTime,
            explanation: exhaustive ? "All reachable states satisfy invariants" : "Partial exploration, invariant may hold",
            truncated: !exhaustive
        )
    }

    // MARK: - Helper Methods

    private func canApply(_ transition: AbstractTransition, to state: AbstractState) -> Bool {
        transition.preconditions.allSatisfy { $0.evaluate(in: state) }
    }

    private func orderedTransitions(for puzzle: ReasoningPuzzle, state: AbstractState) async -> [AbstractTransition] {
        await transitionLane.orderedTransitions(for: puzzle, state: state)
    }

    private func apply(_ transition: AbstractTransition, to state: inout AbstractState) {
        for effect in transition.effects {
            effect.apply(to: &state)
        }
    }

    private func goalReached(_ goal: PuzzleGoal, in state: AbstractState) -> Bool {
        switch goal.goalType {
        case .reachState:
            return goal.conditions.allSatisfy { $0.evaluate(in: state) }
        case .violateConstraint:
            return false // Handled separately
        case .proveInvariant, .explore:
            return false // Not a reachable goal
        }
    }

    private func makeResult(
        puzzle: ReasoningPuzzle,
        outcome: ReasoningOutcome,
        path: [String] = [],
        finalState: AbstractState? = nil,
        violatedConstraints: [String] = [],
        confidence: Double = 0.0,
        stepsExplored: Int,
        startTime: Date,
        explanation: String = "",
        truncated: Bool = false
    ) -> ReasoningResult {
        let duration = Int(Date().timeIntervalSince(startTime) * 1000)
        return ReasoningResult(
            puzzleId: puzzle.puzzleId,
            outcome: outcome,
            transitionSequence: path,
            finalState: finalState,
            violatedConstraints: violatedConstraints,
            confidence: confidence,
            stepsExplored: stepsExplored,
            durationMs: duration,
            explanation: explanation,
            truncated: truncated
        )
    }

    private func stateHash(_ state: AbstractState) -> String {
        // Simple hash for deduplication
        var hasher = Hasher()
        for (key, value) in state.symbols.sorted(by: { $0.key < $1.key }) {
            hasher.combine(key)
            switch value {
            case .boolean(let v): hasher.combine(v)
            case .integer(let v): hasher.combine(v)
            case .category(let v): hasher.combine(v)
            case .set(let v): hasher.combine(v.sorted())
            }
        }
        for (key, set) in state.sets.sorted(by: { $0.key < $1.key }) {
            hasher.combine(key)
            hasher.combine(set.sorted())
        }
        for edge in state.edges.sorted(by: { $0.source < $1.source }) {
            hasher.combine(edge.source)
            hasher.combine(edge.target)
            hasher.combine(edge.edgeType)
        }
        return "\(hasher.finalize())"
    }



    private func checkRateLimit() async throws {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        recentCalls = recentCalls.filter { $0 > oneMinuteAgo }

        if recentCalls.count >= maxCallsPerMinute {
            throw ReasoningError.rateLimited(callsPerMinute: maxCallsPerMinute)
        }

        recentCalls.append(now)
    }
}

/// Configuration for the reasoner.
public struct ReasonerConfig: Sendable {
    /// Maximum transitions in a puzzle.
    public let maxTransitions: Int

    /// Maximum steps allowed per puzzle.
    public let maxStepsAllowed: Int

    /// Maximum time in milliseconds.
    public let maxTimeMs: Int

    /// Maximum state vector size.
    public let maxStateSize: Int

    public init(
        maxTransitions: Int = 100,
        maxStepsAllowed: Int = 10000,
        maxTimeMs: Int = 30000,
        maxStateSize: Int = 1000
    ) {
        self.maxTransitions = maxTransitions
        self.maxStepsAllowed = maxStepsAllowed
        self.maxTimeMs = maxTimeMs
        self.maxStateSize = maxStateSize
    }
}

/// Statistics about the reasoner.
public struct ReasonerStatistics: Sendable {
    public let totalPuzzlesSolved: Int
    public let totalViolationsFound: Int
    public let config: ReasonerConfig
}

/// Errors from the reasoning kernel.
public enum ReasoningError: Error, LocalizedError, Sendable {
    case puzzleTooLarge(actual: Int, max: Int)
    case budgetExceeded(requested: Int, max: Int)
    case rateLimited(callsPerMinute: Int)
    case invalidPuzzle(reason: String)
    case kernelUnavailable

    public var errorDescription: String? {
        switch self {
        case .puzzleTooLarge(let actual, let max):
            return "Puzzle too large: \(actual) transitions (max: \(max))"
        case .budgetExceeded(let requested, let max):
            return "Budget exceeded: \(requested) steps requested (max: \(max))"
        case .rateLimited(let rate):
            return "Rate limited: max \(rate) calls per minute"
        case .invalidPuzzle(let reason):
            return "Invalid puzzle: \(reason)"
        case .kernelUnavailable:
            return "Reasoning kernel is unavailable"
        }
    }
}
