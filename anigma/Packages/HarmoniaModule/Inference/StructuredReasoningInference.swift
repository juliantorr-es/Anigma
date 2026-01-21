//
//  StructuredReasoningInference.swift
//  HarmoniaModule
//
//  Extends the Inference Plane to support structured reasoning tasks.
//  Enables TRM-style models to be used alongside LLMs for constraint solving.
//

import Foundation
import AnigmaCore

// MARK: - Structured Reasoning Task Types

/// Extended task kinds for structured reasoning.
public enum StructuredTaskKind: String, Sendable, Codable {
    /// Grid transformation (ARC-style)
    case gridReasoning

    /// Constraint satisfaction problems
    case constraintSolving

    /// Scheduling and assignment
    case scheduling

    /// Policy compliance checking
    case policyCheck

    /// Workflow validation
    case workflowValidation

    /// DSPS accommodation analysis
    case dspsAnalysis

    /// Academic record integrity check
    case transcriptumCheck
}

/// Input for structured reasoning tasks.
public struct StructuredReasoningInput: Sendable {
    public let taskKind: StructuredTaskKind
    public let puzzle: ReasoningPuzzle?
    public let subproblem: StructuredSubproblem?
    public let metadata: [String: String]

    public init(
        taskKind: StructuredTaskKind,
        puzzle: ReasoningPuzzle? = nil,
        subproblem: StructuredSubproblem? = nil,
        metadata: [String: String] = [:]
    ) {
        self.taskKind = taskKind
        self.puzzle = puzzle
        self.subproblem = subproblem
        self.metadata = metadata
    }

    /// Creates a DSPS workflow analysis input using the existing puzzle builder.
    public static func dspsWorkflow(
        cases: [(symbol: String, studentSymbol: String, termSymbol: String, hasDocumentation: Bool)],
        accommodations: [(caseSymbol: String, accommodationType: String, isApproved: Bool)],
        letters: [(caseSymbol: String, letterSymbol: String, isDelivered: Bool)]
    ) -> StructuredReasoningInput {
        let puzzle = DSPSPuzzleBuilder.buildAccommodationCasePuzzle(
            cases: cases,
            accommodations: accommodations,
            letters: letters
        )

        return StructuredReasoningInput(
            taskKind: .dspsAnalysis,
            puzzle: puzzle,
            metadata: [
                "case_count": String(cases.count),
                "accommodation_count": String(accommodations.count)
            ]
        )
    }

    /// Creates a Transcriptum integrity check input using the existing puzzle builder.
    public static func transcriptumIntegrity(
        students: [(symbol: String, programSymbol: String, completedUnits: Int, gpa: Double)],
        programs: [(symbol: String, requiredUnits: Int, minGPA: Double)],
        degreeAwards: [(studentSymbol: String, programSymbol: String, isAwarded: Bool)]
    ) -> StructuredReasoningInput {
        let puzzle = TranscriptumPuzzleBuilder.buildDegreeAwardPuzzle(
            students: students,
            programs: programs,
            degreeAwards: degreeAwards
        )

        return StructuredReasoningInput(
            taskKind: .transcriptumCheck,
            puzzle: puzzle,
            metadata: [
                "student_count": String(students.count),
                "program_count": String(programs.count)
            ]
        )
    }

    /// Creates an alt-media workflow analysis input.
    public static func altMediaWorkflow(
        requests: [(symbol: String, caseSymbol: String, format: String, priority: Int)],
        slaHours: Int
    ) -> StructuredReasoningInput {
        let puzzle = DSPSPuzzleBuilder.buildAltMediaWorkflowPuzzle(
            requests: requests,
            slaHours: slaHours
        )

        return StructuredReasoningInput(
            taskKind: .dspsAnalysis,
            puzzle: puzzle,
            metadata: [
                "request_count": String(requests.count),
                "sla_hours": String(slaHours)
            ]
        )
    }
}

/// Result from structured reasoning.
public struct StructuredReasoningResult: Sendable {
    public let taskId: String
    public let taskKind: StructuredTaskKind
    public let success: Bool
    public let twoTierResult: TwoTierResult?
    public let violations: [String]
    public let recommendations: [String]
    public let confidence: Double
    public let explanation: String
    public let latency: Duration

    public init(
        taskId: String,
        taskKind: StructuredTaskKind,
        success: Bool,
        twoTierResult: TwoTierResult? = nil,
        violations: [String] = [],
        recommendations: [String] = [],
        confidence: Double = 0.0,
        explanation: String = "",
        latency: Duration = .zero
    ) {
        self.taskId = taskId
        self.taskKind = taskKind
        self.success = success
        self.twoTierResult = twoTierResult
        self.violations = violations
        self.recommendations = recommendations
        self.confidence = confidence
        self.explanation = explanation
        self.latency = latency
    }
}

// MARK: - Structured Reasoning Model

/// A model descriptor for structured reasoning (non-LLM).
public struct StructuredReasoningModel: Sendable {
    public let id: String
    public let name: String
    public let supportedTasks: Set<StructuredTaskKind>
    public let tier: ReasoningTier
    public let config: TRMConfig

    public init(
        id: String,
        name: String,
        supportedTasks: Set<StructuredTaskKind>,
        tier: ReasoningTier = .neural,
        config: TRMConfig = TRMConfig()
    ) {
        self.id = id
        self.name = name
        self.supportedTasks = supportedTasks
        self.tier = tier
        self.config = config
    }

    /// Default DSPS reasoning model.
    public static let dspsReasoner = StructuredReasoningModel(
        id: "dsps-reasoner-v1",
        name: "DSPS Workflow Reasoner",
        supportedTasks: [.dspsAnalysis, .workflowValidation, .policyCheck],
        tier: .hybrid
    )

    /// Default Transcriptum reasoning model.
    public static let transcriptumReasoner = StructuredReasoningModel(
        id: "transcriptum-reasoner-v1",
        name: "Academic Records Reasoner",
        supportedTasks: [.transcriptumCheck, .policyCheck],
        tier: .symbolic
    )

    /// Default constraint solver.
    public static let constraintSolver = StructuredReasoningModel(
        id: "constraint-solver-v1",
        name: "General Constraint Solver",
        supportedTasks: [.constraintSolving, .scheduling],
        tier: .neural,
        config: TRMConfig(scratchpadSize: 512, canvasSize: 512, slowUpdateInterval: 3)
    )
}

// MARK: - Structured Reasoning Registry

/// Registry for structured reasoning models.
public actor StructuredReasoningRegistry {
    private var models: [String: StructuredReasoningModel] = [:]
    private var taskToModel: [StructuredTaskKind: String] = [:]

    public init() {
        // Register default models in actor-isolated context
        models[StructuredReasoningModel.dspsReasoner.id] = .dspsReasoner
        models[StructuredReasoningModel.transcriptumReasoner.id] = .transcriptumReasoner
        models[StructuredReasoningModel.constraintSolver.id] = .constraintSolver

        for task in StructuredReasoningModel.dspsReasoner.supportedTasks {
            taskToModel[task] = StructuredReasoningModel.dspsReasoner.id
        }
        for task in StructuredReasoningModel.transcriptumReasoner.supportedTasks {
            if taskToModel[task] == nil {
                taskToModel[task] = StructuredReasoningModel.transcriptumReasoner.id
            }
        }
        for task in StructuredReasoningModel.constraintSolver.supportedTasks {
            if taskToModel[task] == nil {
                taskToModel[task] = StructuredReasoningModel.constraintSolver.id
            }
        }
    }

    /// Registers a structured reasoning model.
    public func register(_ model: StructuredReasoningModel) {
        models[model.id] = model
        for task in model.supportedTasks {
            if taskToModel[task] == nil {
                taskToModel[task] = model.id
            }
        }
    }

    /// Finds a model for a task kind.
    public func findModel(for taskKind: StructuredTaskKind) -> StructuredReasoningModel? {
        guard let modelId = taskToModel[taskKind] else { return nil }
        return models[modelId]
    }

    /// Gets all registered models.
    public func allModels() -> [StructuredReasoningModel] {
        Array(models.values)
    }
}

// MARK: - Structured Reasoning Service

/// Service for executing structured reasoning tasks.
public actor StructuredReasoningService {
    private let registry: StructuredReasoningRegistry
    private let twoTierOrchestrator: TwoTierReasoningOrchestrator
    private var auditLog: AuditLog?

    // Statistics
    private var tasksExecuted: Int = 0
    private var violationsFound: Int = 0
    private var averageLatency: Double = 0

    public init(
        registry: StructuredReasoningRegistry,
        twoTierOrchestrator: TwoTierReasoningOrchestrator
    ) {
        self.registry = registry
        self.twoTierOrchestrator = twoTierOrchestrator
    }

    public func setAuditLog(_ log: AuditLog) {
        self.auditLog = log
    }

    /// Executes a structured reasoning task.
    public func execute(
        _ input: StructuredReasoningInput,
        context: InferenceContext
    ) async throws -> StructuredReasoningResult {
        let startTime = Date()
        let taskId = UUID().uuidString

        // Find appropriate model
        guard let model = await registry.findModel(for: input.taskKind) else {
            throw StructuredReasoningError.noModelForTask(input.taskKind)
        }

        // Log execution start
        try? await auditLog?.record(
            eventType: .automationTriggered,
            principal: context.principalId,
            module: "reasoning.structured",
            description: "Structured reasoning: \(input.taskKind.rawValue)",
            metadata: [
                "task_id": taskId,
                "task_kind": input.taskKind.rawValue,
                "model_id": model.id,
                "tenant_id": context.tenantId
            ]
        )

        // Execute based on model tier
        var result: TwoTierResult?
        var violations: [String] = []
        var recommendations: [String] = []

        if let puzzle = input.puzzle {
            result = try await twoTierOrchestrator.solve(puzzle)

            // Extract violations from result
            if let symbolicResult = result?.symbolicResult {
                violations = symbolicResult.violatedConstraints

                // Generate recommendations based on violations
                for violation in violations {
                    recommendations.append("Review and fix constraint: \(violation)")
                }
            }
        }

        let latency = Duration.seconds(Date().timeIntervalSince(startTime))

        // Update statistics
        tasksExecuted += 1
        violationsFound += violations.count
        averageLatency = (averageLatency * Double(tasksExecuted - 1) + latency.seconds) / Double(tasksExecuted)

        let success = violations.isEmpty
        let confidence = result?.confidence ?? 0.0

        let explanation = buildExplanation(
            taskKind: input.taskKind,
            result: result,
            violations: violations
        )

        // Log execution complete
        try? await auditLog?.record(
            eventType: .automationExecuted,
            principal: context.principalId,
            module: "reasoning.structured",
            description: "Structured reasoning complete: \(success ? "passed" : "violations found")",
            metadata: [
                "task_id": taskId,
                "success": String(success),
                "violations_count": String(violations.count),
                "confidence": String(format: "%.2f", confidence)
            ]
        )

        return StructuredReasoningResult(
            taskId: taskId,
            taskKind: input.taskKind,
            success: success,
            twoTierResult: result,
            violations: violations,
            recommendations: recommendations,
            confidence: confidence,
            explanation: explanation,
            latency: latency
        )
    }

    /// Builds an explanation for the result.
    private func buildExplanation(
        taskKind: StructuredTaskKind,
        result: TwoTierResult?,
        violations: [String]
    ) -> String {
        var parts: [String] = []

        parts.append("Task: \(taskKind.rawValue)")

        if let result = result {
            parts.append("Tier used: \(result.tier.rawValue)")
            parts.append("Confidence: \(String(format: "%.1f%%", result.confidence * 100))")
        }

        if violations.isEmpty {
            parts.append("Status: All checks passed")
        } else {
            parts.append("Status: \(violations.count) violation(s) found")
            for v in violations.prefix(3) {
                parts.append("  - \(v)")
            }
            if violations.count > 3 {
                parts.append("  ... and \(violations.count - 3) more")
            }
        }

        return parts.joined(separator: "\n")
    }

    /// Gets service statistics.
    public func getStatistics() -> StructuredReasoningStatistics {
        StructuredReasoningStatistics(
            tasksExecuted: tasksExecuted,
            violationsFound: violationsFound,
            averageLatencySeconds: averageLatency
        )
    }
}

/// Statistics for structured reasoning service.
public struct StructuredReasoningStatistics: Sendable {
    public let tasksExecuted: Int
    public let violationsFound: Int
    public let averageLatencySeconds: Double
}

/// Errors from structured reasoning.
public enum StructuredReasoningError: Error, LocalizedError, Sendable {
    case noModelForTask(StructuredTaskKind)
    case invalidInput(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noModelForTask(let kind):
            return "No model registered for task kind: \(kind.rawValue)"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}

// MARK: - Duration Extension

extension Duration {
    var seconds: Double {
        let (seconds, attoseconds) = self.components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
