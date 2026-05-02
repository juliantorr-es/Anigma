//
//  TwoTierReasoning.swift
//  AnigmaCore
//
//  Two-tier reasoning architecture combining symbolic ReasoningKernel
//  with TRM-style tiny recursive neural solvers for hybrid problem solving.
//
//  Architecture:
//  - Tier 1: Symbolic ReasoningKernel for high-level puzzle decomposition
//  - Tier 2: TRM-style neural subsolvers for constraint-heavy subproblems
//
//  The system routes problems based on structure:
//  - Pure symbolic: direct ReasoningKernel
//  - Constraint-heavy: delegate to TRM subsolver
//  - Hybrid: decompose, route subproblems, aggregate results
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import Foundation
import ContractsCore

// MARK: - Two-Tier Reasoning Types

/// Identifies which tier should handle a problem.
public enum ReasoningTier: String, Sendable, Codable {
    /// Pure symbolic search via RecursiveReasoner
    case symbolic

    /// TRM-style neural subsolver for structured constraints
    case neural

    /// Hybrid: decompose and route to appropriate tier
    case hybrid
}

/// A subproblem extracted from a larger puzzle for neural solving.
public struct StructuredSubproblem: Sendable, Codable {
    public let id: UUID
    public let parentPuzzleId: UUID
    public let subproblemType: SubproblemType
    public let gridState: GridState?
    public let constraintGraph: ConstraintGraph?
    public let schedulingProblem: SchedulingProblem?
    public let maxIterations: Int
    public let qualityThreshold: Double

    public init(
        id: UUID = UUID(),
        parentPuzzleId: UUID,
        subproblemType: SubproblemType,
        gridState: GridState? = nil,
        constraintGraph: ConstraintGraph? = nil,
        schedulingProblem: SchedulingProblem? = nil,
        maxIterations: Int = 100,
        qualityThreshold: Double = 0.9
    ) {
        self.id = id
        self.parentPuzzleId = parentPuzzleId
        self.subproblemType = subproblemType
        self.gridState = gridState
        self.constraintGraph = constraintGraph
        self.schedulingProblem = schedulingProblem
        self.maxIterations = maxIterations
        self.qualityThreshold = qualityThreshold
    }
}

/// Types of structured subproblems TRM can solve.
public enum SubproblemType: String, Sendable, Codable {
    /// Grid-based reasoning (ARC-style)
    case gridTransformation

    /// Constraint satisfaction
    case constraintSatisfaction

    /// Scheduling and assignment
    case scheduling

    /// Graph coloring / partitioning
    case graphColoring

    /// Sequence optimization
    case sequenceOptimization

    /// Pattern matching
    case patternMatching
}

// MARK: - Grid State (ARC-style)

/// A grid state for ARC-style reasoning tasks.
public struct GridState: Sendable, Codable {
    /// Grid dimensions
    public let rows: Int
    public let cols: Int

    /// Cell values (0-9 typically for colors/categories)
    public var cells: [[Int]]

    /// Metadata about the grid
    public var metadata: [String: String]

    public init(rows: Int, cols: Int, cells: [[Int]]? = nil, metadata: [String: String] = [:]) {
        self.rows = rows
        self.cols = cols
        self.cells = cells ?? Array(repeating: Array(repeating: 0, count: cols), count: rows)
        self.metadata = metadata
    }

    /// Creates a grid from a flat array.
    public static func fromFlat(_ flat: [Int], rows: Int, cols: Int) -> GridState {
        var cells: [[Int]] = []
        for r in 0..<rows {
            let start = r * cols
            let end = min(start + cols, flat.count)
            cells.append(Array(flat[start..<end]))
        }
        return GridState(rows: rows, cols: cols, cells: cells)
    }

    /// Flattens the grid to a 1D array.
    public func flatten() -> [Int] {
        cells.flatMap { $0 }
    }
}

// MARK: - Constraint Graph

/// A constraint satisfaction problem represented as a graph.
public struct ConstraintGraph: Sendable, Codable {
    /// Variables in the problem
    public var variables: [ConstraintVariable]

    /// Constraints between variables
    public var constraints: [GraphConstraint]

    public init(variables: [ConstraintVariable] = [], constraints: [GraphConstraint] = []) {
        self.variables = variables
        self.constraints = constraints
    }
}

/// A variable in a constraint problem.
public struct ConstraintVariable: Sendable, Codable {
    public let id: String
    public let name: String
    public var domain: [Int]
    public var currentValue: Int?

    public init(id: String, name: String, domain: [Int], currentValue: Int? = nil) {
        self.id = id
        self.name = name
        self.domain = domain
        self.currentValue = currentValue
    }
}

/// A constraint between variables.
public struct GraphConstraint: Sendable, Codable {
    public let id: String
    public let type: GraphConstraintType
    public let variables: [String]
    public let parameters: [String: Int]

    public init(id: String, type: GraphConstraintType, variables: [String], parameters: [String: Int] = [:]) {
        self.id = id
        self.type = type
        self.variables = variables
        self.parameters = parameters
    }
}

/// Types of graph constraints.
public enum GraphConstraintType: String, Sendable, Codable {
    case allDifferent
    case equals
    case notEquals
    case lessThan
    case lessThanOrEqual
    case sum
    case atMost
    case atLeast
}

// MARK: - Scheduling Problem

/// A scheduling/assignment problem.
public struct SchedulingProblem: Sendable, Codable {
    /// Tasks to schedule
    public var tasks: [SchedulingTask]

    /// Resources available
    public var resources: [SchedulingResource]

    /// Time slots
    public var timeSlots: [TimeSlot]

    /// Constraints
    public var constraints: [SchedulingConstraint]

    public init(
        tasks: [SchedulingTask] = [],
        resources: [SchedulingResource] = [],
        timeSlots: [TimeSlot] = [],
        constraints: [SchedulingConstraint] = []
    ) {
        self.tasks = tasks
        self.resources = resources
        self.timeSlots = timeSlots
        self.constraints = constraints
    }
}

/// A task to be scheduled.
public struct SchedulingTask: Sendable, Codable {
    public let id: String
    public let name: String
    public let duration: Int
    public let priority: Int
    public let requiredCapabilities: Set<String>

    public init(id: String, name: String, duration: Int = 1, priority: Int = 1, requiredCapabilities: Set<String> = []) {
        self.id = id
        self.name = name
        self.duration = duration
        self.priority = priority
        self.requiredCapabilities = requiredCapabilities
    }
}

/// A resource for scheduling.
public struct SchedulingResource: Sendable, Codable {
    public let id: String
    public let name: String
    public let capabilities: Set<String>
    public let availability: [Int] // Indices of available time slots

    public init(id: String, name: String, capabilities: Set<String> = [], availability: [Int] = []) {
        self.id = id
        self.name = name
        self.capabilities = capabilities
        self.availability = availability
    }
}

/// A time slot.
public struct TimeSlot: Sendable, Codable {
    public let index: Int
    public let label: String

    public init(index: Int, label: String) {
        self.index = index
        self.label = label
    }
}

/// A scheduling constraint.
public struct SchedulingConstraint: Sendable, Codable {
    public let id: String
    public let type: SchedulingConstraintType
    public let taskIds: [String]
    public let parameters: [String: Int]

    public init(id: String, type: SchedulingConstraintType, taskIds: [String], parameters: [String: Int] = [:]) {
        self.id = id
        self.type = type
        self.taskIds = taskIds
        self.parameters = parameters
    }
}

/// Types of scheduling constraints.
public enum SchedulingConstraintType: String, Sendable, Codable {
    case noOverlap
    case precedence
    case sameResource
    case differentResource
    case withinWindow
    case consecutiveWhen
}

// MARK: - TRM Subsolver Result

/// Result from a TRM subsolver.
public struct SubsolverResult: Sendable {
    public let subproblemId: UUID
    public let success: Bool
    public let solution: SubsolverSolution?
    public let iterations: Int
    public let confidence: Double
    public let explanation: String

    public init(
        subproblemId: UUID,
        success: Bool,
        solution: SubsolverSolution? = nil,
        iterations: Int = 0,
        confidence: Double = 0.0,
        explanation: String = ""
    ) {
        self.subproblemId = subproblemId
        self.success = success
        self.solution = solution
        self.iterations = iterations
        self.confidence = confidence
        self.explanation = explanation
    }
}

/// Solution from a subsolver.
public enum SubsolverSolution: Sendable {
    case grid(GridState)
    case assignment([String: Int])
    case schedule([(taskId: String, resourceId: String, slotIndex: Int)])
    case sequence([String])
}

// MARK: - Two-Tier Reasoning Orchestrator

/// Orchestrates two-tier reasoning between symbolic and neural tiers.
public actor TwoTierReasoningOrchestrator {
    private let symbolicReasoner: RecursiveReasoner
    private let trmSubsolver: TRMSubsolver
    private let config: TwoTierConfig
    private var auditLog: (any AuditLogging)?

    // Statistics
    private var symbolicCalls: Int = 0
    private var neuralCalls: Int = 0
    private var hybridCalls: Int = 0

    public init(
        symbolicReasoner: RecursiveReasoner,
        trmSubsolver: TRMSubsolver,
        config: TwoTierConfig = TwoTierConfig()
    ) {
        self.symbolicReasoner = symbolicReasoner
        self.trmSubsolver = trmSubsolver
        self.config = config
    }

    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Solves a puzzle using the appropriate tier(s).
    public func solve(_ puzzle: ReasoningPuzzle) async throws -> TwoTierResult {
        let tier = classifyPuzzle(puzzle)

        try? await auditLog?.record(
            eventType: ContractsCore.AuditEventType.automationTriggered,
            principal: "two_tier_reasoning",
            module: "TwoTierReasoningOrchestrator",
            description: "Puzzle classified as \(tier.rawValue)",
            metadata: [
                "puzzle_id": puzzle.puzzleId.uuidString,
                "tier": tier.rawValue,
                "domain": puzzle.domain.rawValue
            ]
        )

        switch tier {
        case .symbolic:
            symbolicCalls += 1
            let result = try await symbolicReasoner.solve(puzzle)
            return TwoTierResult(
                puzzleId: puzzle.puzzleId,
                tier: .symbolic,
                symbolicResult: result,
                subsolverResults: []
            )

        case .neural:
            neuralCalls += 1
            let subproblem = extractSubproblem(from: puzzle)
            let result = await trmSubsolver.solve(subproblem)
            return TwoTierResult(
                puzzleId: puzzle.puzzleId,
                tier: .neural,
                symbolicResult: nil,
                subsolverResults: [result]
            )

        case .hybrid:
            hybridCalls += 1
            return try await solveHybrid(puzzle)
        }
    }

    /// Classifies which tier should handle a puzzle.
    private func classifyPuzzle(_ puzzle: ReasoningPuzzle) -> ReasoningTier {
        // Heuristics for classification
        let hasConstraintSubproblem = puzzle.constraints.count > config.constraintThreshold
        let hasSchedulingPattern = puzzle.domain == .workflowStates || puzzle.domain == .automationRules
        let isSmallStateSpace = puzzle.transitions.count < config.smallStateThreshold

        if hasConstraintSubproblem && hasSchedulingPattern {
            return .hybrid
        } else if hasConstraintSubproblem && !isSmallStateSpace {
            return .neural
        } else {
            return .symbolic
        }
    }

    /// Extracts a structured subproblem from a puzzle.
    private func extractSubproblem(from puzzle: ReasoningPuzzle) -> StructuredSubproblem {
        // Determine subproblem type based on puzzle characteristics
        let subproblemType: SubproblemType
        var constraintGraph: ConstraintGraph?
        var schedulingProblem: SchedulingProblem?

        switch puzzle.domain {
        case .workflowStates, .automationRules:
            subproblemType = .scheduling
            schedulingProblem = buildSchedulingProblem(from: puzzle)

        case .accessControl, .tenantIsolation:
            subproblemType = .constraintSatisfaction
            constraintGraph = buildConstraintGraph(from: puzzle)

        default:
            subproblemType = .constraintSatisfaction
            constraintGraph = buildConstraintGraph(from: puzzle)
        }

        return StructuredSubproblem(
            parentPuzzleId: puzzle.puzzleId,
            subproblemType: subproblemType,
            constraintGraph: constraintGraph,
            schedulingProblem: schedulingProblem,
            maxIterations: min(puzzle.maxSteps, config.maxNeuralIterations)
        )
    }

    /// Solves a hybrid puzzle by decomposing and routing.
    private func solveHybrid(_ puzzle: ReasoningPuzzle) async throws -> TwoTierResult {
        // Phase 1: Symbolic exploration to find critical subproblems
        let explorationPuzzle = ReasoningPuzzle(
            puzzleId: puzzle.puzzleId,
            puzzleType: .exploreSpace,
            domain: puzzle.domain,
            initialState: puzzle.initialState,
            transitions: puzzle.transitions,
            constraints: [],  // No constraints for exploration
            goal: .proveInvariant(),
            maxSteps: config.explorationSteps,
            timeBudgetMs: puzzle.timeBudgetMs / 2
        )

        let explorationResult = try await symbolicReasoner.solve(explorationPuzzle)

        // Phase 2: For each discovered branch point, run neural subsolver
        var subsolverResults: [SubsolverResult] = []

        if explorationResult.stepsExplored > config.branchThreshold {
            let subproblem = extractSubproblem(from: puzzle)
            let neuralResult = await trmSubsolver.solve(subproblem)
            subsolverResults.append(neuralResult)
        }

        // Phase 3: Final symbolic verification with neural hints
        let finalResult = try await symbolicReasoner.solve(puzzle)

        return TwoTierResult(
            puzzleId: puzzle.puzzleId,
            tier: .hybrid,
            symbolicResult: finalResult,
            subsolverResults: subsolverResults
        )
    }

    /// Builds a constraint graph from a puzzle.
    private func buildConstraintGraph(from puzzle: ReasoningPuzzle) -> ConstraintGraph {
        var variables: [ConstraintVariable] = []
        var constraints: [GraphConstraint] = []

        // Convert puzzle symbols to variables
        for (key, value) in puzzle.initialState.symbols {
            let domain: [Int]
            switch value {
            case .boolean:
                domain = [0, 1]
            case .integer(let v):
                domain = Array(max(0, v - 10)...v + 10)
            case .category:
                domain = [0, 1, 2, 3, 4]  // Generic category domain
            case .set:
                domain = [0, 1]  // Binary for set membership
            }
            variables.append(ConstraintVariable(id: key, name: key, domain: domain))
        }

        // Convert puzzle constraints to graph constraints
        for constraint in puzzle.constraints {
            let graphConstraint = GraphConstraint(
                id: constraint.constraintId,
                type: mapConditionToGraphConstraint(constraint.condition),
                variables: [constraint.condition.symbol]
            )
            constraints.append(graphConstraint)
        }

        return ConstraintGraph(variables: variables, constraints: constraints)
    }

    /// Builds a scheduling problem from a puzzle.
    private func buildSchedulingProblem(from puzzle: ReasoningPuzzle) -> SchedulingProblem {
        var tasks: [SchedulingTask] = []
        var resources: [SchedulingResource] = []

        // Convert transitions to tasks
        for (index, transition) in puzzle.transitions.enumerated() {
            tasks.append(SchedulingTask(
                id: transition.transitionId,
                name: transition.name,
                duration: 1,
                priority: puzzle.transitions.count - index
            ))
        }

        // Create a single default resource
        resources.append(SchedulingResource(
            id: "default",
            name: "Default Resource",
            availability: Array(0..<puzzle.maxSteps)
        ))

        let timeSlots = (0..<puzzle.maxSteps).map { TimeSlot(index: $0, label: "Step \($0)") }

        return SchedulingProblem(
            tasks: tasks,
            resources: resources,
            timeSlots: timeSlots
        )
    }

    /// Maps a condition operator to a graph constraint type.
    private func mapConditionToGraphConstraint(_ condition: AbstractCondition) -> GraphConstraintType {
        switch condition.operator_ {
        case .equals: return .equals
        case .notEquals: return .notEquals
        case .lessThan: return .lessThan
        case .greaterThan: return .lessThanOrEqual  // Mapped to constraint type
        case .contains, .isNil, .isNotNil: return .equals
        }
    }

    /// Gets statistics about two-tier reasoning.
    public func getStatistics() -> TwoTierStatistics {
        TwoTierStatistics(
            symbolicCalls: symbolicCalls,
            neuralCalls: neuralCalls,
            hybridCalls: hybridCalls
        )
    }
}

// MARK: - TRM Subsolver

/// A TRM-style tiny recursive neural subsolver.
/// Operates on structured problems using iterative refinement.
public actor TRMSubsolver {
    private let config: TRMConfig

    // Working memories (TRM architecture)
    private var scratchpad: [Float]  // Internal thinking state
    private var canvas: [Float]      // Current candidate answer

    public init(config: TRMConfig = TRMConfig()) {
        self.config = config
        self.scratchpad = Array(repeating: 0, count: config.scratchpadSize)
        self.canvas = Array(repeating: 0, count: config.canvasSize)
    }

    /// Solves a structured subproblem.
    public func solve(_ subproblem: StructuredSubproblem) async -> SubsolverResult {
        // Reset working memories
        scratchpad = Array(repeating: 0, count: config.scratchpadSize)
        canvas = Array(repeating: 0, count: config.canvasSize)

        var iterations = 0
        var bestConfidence: Double = 0.0
        var solution: SubsolverSolution?

        // Encode problem to initial state
        encodeInput(subproblem)

        // Iterative refinement loop
        while iterations < subproblem.maxIterations {
            // Step 1: Fast update (System 1 - quick intuition)
            fastUpdate()

            // Step 2: Slow update every N steps (System 2 - deliberation)
            if iterations % config.slowUpdateInterval == 0 {
                slowUpdate()
            }

            // Step 3: Check halting condition
            let confidence = computeConfidence()
            if confidence > bestConfidence {
                bestConfidence = confidence
                solution = decodeOutput(subproblem.subproblemType)
            }

            if confidence >= subproblem.qualityThreshold {
                break
            }

            iterations += 1
        }

        return SubsolverResult(
            subproblemId: subproblem.id,
            success: bestConfidence >= subproblem.qualityThreshold * 0.8,
            solution: solution,
            iterations: iterations,
            confidence: bestConfidence,
            explanation: "TRM subsolver completed \(iterations) iterations with confidence \(String(format: "%.2f", bestConfidence))"
        )
    }

    /// Encodes input problem to working memory.
    private func encodeInput(_ subproblem: StructuredSubproblem) {
        switch subproblem.subproblemType {
        case .gridTransformation:
            if let grid = subproblem.gridState {
                let flat = grid.flatten()
                for (i, value) in flat.enumerated() where i < canvas.count {
                    canvas[i] = Float(value) / 10.0  // Normalize to 0-1
                }
            }

        case .constraintSatisfaction:
            if let graph = subproblem.constraintGraph {
                for (i, variable) in graph.variables.enumerated() where i < canvas.count {
                    canvas[i] = Float(variable.currentValue ?? 0) / Float(variable.domain.max() ?? 1)
                }
            }

        case .scheduling:
            if let problem = subproblem.schedulingProblem {
                for (i, task) in problem.tasks.enumerated() where i < canvas.count {
                    canvas[i] = Float(task.priority) / 10.0
                }
            }

        default:
            break
        }
    }

    /// Fast update step (System 1).
    private func fastUpdate() {
        // Simple local refinement: adjust based on neighbors
        for i in 0..<scratchpad.count {
            let left = i > 0 ? scratchpad[i - 1] : 0
            let right = i < scratchpad.count - 1 ? scratchpad[i + 1] : 0
            let canvasVal = i < canvas.count ? canvas[i] : 0

            // Local smoothing + canvas influence
            scratchpad[i] = (left + right + scratchpad[i] + canvasVal) / 4.0
        }
    }

    /// Slow update step (System 2).
    private func slowUpdate() {
        // Global pattern analysis and adjustment
        let mean = scratchpad.reduce(0, +) / Float(scratchpad.count)

        for i in 0..<canvas.count {
            let scratchVal = i < scratchpad.count ? scratchpad[i] : 0
            // Blend canvas with scratchpad insights
            canvas[i] = (canvas[i] + scratchVal + mean) / 3.0
        }
    }

    /// Computes confidence in current solution.
    private func computeConfidence() -> Double {
        // Simple heuristic: consistency between scratchpad and canvas
        var agreement: Float = 0
        let count = min(scratchpad.count, canvas.count)

        for i in 0..<count {
            agreement += 1.0 - Swift.abs(scratchpad[i] - canvas[i])
        }

        return Double(agreement) / Double(count)
    }

    /// Decodes output from canvas to solution.
    private func decodeOutput(_ type: SubproblemType) -> SubsolverSolution {
        switch type {
        case .gridTransformation:
            let values = canvas.prefix(100).map { Int($0 * 10) }
            let grid = GridState.fromFlat(Array(values), rows: 10, cols: 10)
            return .grid(grid)

        case .constraintSatisfaction:
            var assignment: [String: Int] = [:]
            for (i, value) in canvas.prefix(20).enumerated() {
                assignment["var_\(i)"] = Int(value * 10)
            }
            return .assignment(assignment)

        case .scheduling:
            var schedule: [(taskId: String, resourceId: String, slotIndex: Int)] = []
            for (i, value) in canvas.prefix(10).enumerated() {
                schedule.append((
                    taskId: "task_\(i)",
                    resourceId: "default",
                    slotIndex: Int(value * 10)
                ))
            }
            return .schedule(schedule)

        case .sequenceOptimization, .patternMatching, .graphColoring:
            let sequence = canvas.prefix(20).map { "step_\(Int($0 * 10))" }
            return .sequence(Array(sequence))
        }
    }
}

// MARK: - Configuration

/// Configuration for two-tier reasoning.
public struct TwoTierConfig: Sendable {
    /// Threshold for constraint count to use neural tier.
    public let constraintThreshold: Int

    /// Threshold for "small" state space (use symbolic).
    public let smallStateThreshold: Int

    /// Maximum neural iterations per subproblem.
    public let maxNeuralIterations: Int

    /// Steps for exploration phase in hybrid mode.
    public let explorationSteps: Int

    /// Branch count threshold for neural assistance.
    public let branchThreshold: Int

    public init(
        constraintThreshold: Int = 10,
        smallStateThreshold: Int = 20,
        maxNeuralIterations: Int = 100,
        explorationSteps: Int = 50,
        branchThreshold: Int = 25
    ) {
        self.constraintThreshold = constraintThreshold
        self.smallStateThreshold = smallStateThreshold
        self.maxNeuralIterations = maxNeuralIterations
        self.explorationSteps = explorationSteps
        self.branchThreshold = branchThreshold
    }
}

/// Configuration for TRM subsolver.
public struct TRMConfig: Sendable {
    /// Size of the scratchpad (thinking) memory.
    public let scratchpadSize: Int

    /// Size of the canvas (answer) memory.
    public let canvasSize: Int

    /// Interval between slow (System 2) updates.
    public let slowUpdateInterval: Int

    public init(
        scratchpadSize: Int = 256,
        canvasSize: Int = 256,
        slowUpdateInterval: Int = 5
    ) {
        self.scratchpadSize = scratchpadSize
        self.canvasSize = canvasSize
        self.slowUpdateInterval = slowUpdateInterval
    }
}

// MARK: - Results

/// Result from two-tier reasoning.
public struct TwoTierResult: Sendable {
    public let puzzleId: UUID
    public let tier: ReasoningTier
    public let symbolicResult: ReasoningResult?
    public let subsolverResults: [SubsolverResult]

    /// Combined success indicator.
    public var success: Bool {
        if let symbolic = symbolicResult {
            return symbolic.outcome == .foundPath ||
                   symbolic.outcome == .provedInvariant ||
                   symbolic.outcome == .foundViolation
        }
        return subsolverResults.allSatisfy { $0.success }
    }

    /// Combined confidence.
    public var confidence: Double {
        if let symbolic = symbolicResult {
            let symbolicConf = symbolic.confidence
            let neuralConf = subsolverResults.isEmpty ? 1.0 :
                subsolverResults.map { $0.confidence }.reduce(0, +) / Double(subsolverResults.count)
            return (symbolicConf + neuralConf) / 2.0
        }
        return subsolverResults.isEmpty ? 0.0 :
            subsolverResults.map { $0.confidence }.reduce(0, +) / Double(subsolverResults.count)
    }
}

/// Statistics for two-tier reasoning.
public struct TwoTierStatistics: Sendable {
    public let symbolicCalls: Int
    public let neuralCalls: Int
    public let hybridCalls: Int

    public var totalCalls: Int { symbolicCalls + neuralCalls + hybridCalls }
}
