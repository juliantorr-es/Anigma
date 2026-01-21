//
//  HarmoniaReasoningService.swift
//  HarmoniaModule
//
//  Harmonia-specific reasoning service.
//  Integrates the reasoning kernel into Harmonia's development workflows.
//
//  This is the "safety brain" for Harmonia - every structural change,
//  automation, refactor, and cluster operation goes through here first.
//

import Foundation
import AnigmaCore
import ContractsCore

// MARK: - Harmonia Reasoning Result

/// Result from a Harmonia-specific reasoning analysis.
public struct HarmoniaReasoningResult: Sendable {
    /// The underlying reasoning result.
    public let baseResult: ReasoningResult

    /// Harmonia-specific domain.
    public let harmoniaDomain: HarmoniaReasoningDomain

    /// Human-readable diagnosis.
    public let diagnosis: String

    /// Recommended actions.
    public let recommendations: [HarmoniaRecommendation]

    /// Whether this blocks the operation.
    public let isBlocking: Bool

    /// Risk level for the analyzed operation.
    public let riskLevel: OperationRiskLevel

    public enum OperationRiskLevel: String, Sendable {
        case safe = "safe"
        case low = "low"
        case moderate = "moderate"
        case high = "high"
        case critical = "critical"
    }

    public init(
        baseResult: ReasoningResult,
        harmoniaDomain: HarmoniaReasoningDomain,
        diagnosis: String,
        recommendations: [HarmoniaRecommendation],
        isBlocking: Bool,
        riskLevel: OperationRiskLevel
    ) {
        self.baseResult = baseResult
        self.harmoniaDomain = harmoniaDomain
        self.diagnosis = diagnosis
        self.recommendations = recommendations
        self.isBlocking = isBlocking
        self.riskLevel = riskLevel
    }
}

/// A recommendation from Harmonia reasoning.
public struct HarmoniaRecommendation: Sendable {
    public let recommendationId: String
    public let category: RecommendationCategory
    public let description: String
    public let priority: RecommendationPriority
    public let suggestedFix: String?

    public enum RecommendationCategory: String, Sendable {
        case architecture = "architecture"
        case security = "security"
        case workflow = "workflow"
        case refactoring = "refactoring"
        case cluster = "cluster"
        case testing = "testing"
    }

    public enum RecommendationPriority: String, Sendable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }

    public init(
        recommendationId: String,
        category: RecommendationCategory,
        description: String,
        priority: RecommendationPriority,
        suggestedFix: String? = nil
    ) {
        self.recommendationId = recommendationId
        self.category = category
        self.description = description
        self.priority = priority
        self.suggestedFix = suggestedFix
    }
}

// MARK: - Harmonia Reasoning Service

/// Service for Harmonia-specific reasoning operations.
/// Acts as the "preflight brain" for all structural changes.
public actor HarmoniaReasoningService {
    /// The underlying reasoning orchestrator.
    private let orchestrator: ReasoningOrchestrator

    /// Audit log for reasoning operations.
    private var auditLog: AuditLog?

    /// State abstractor for anonymizing inputs.
    private let abstractor = StateAbstractor()

    /// Analysis history.
    private var analysisHistory: [AnalysisHistoryEntry] = []

    /// Configuration.
    private var config: HarmoniaReasoningConfig

    public init(orchestrator: ReasoningOrchestrator, config: HarmoniaReasoningConfig = .default) {
        self.orchestrator = orchestrator
        self.config = config
    }

    /// Configures the service with dependencies.
    public func configure(auditLog: AuditLog) async {
        self.auditLog = auditLog
        await orchestrator.configure(auditLog: auditLog)
    }

    // MARK: - Module Integration Analysis

    /// Analyzes a new module integration for architecture violations.
    public func analyzeModuleIntegration(
        newModule: String,
        existingModules: [String],
        proposedDependencies: [ModuleIntegrationPuzzleBuilder.ModuleDependency],
        architectureRules: [ModuleIntegrationPuzzleBuilder.ArchitectureRule]
    ) async throws -> HarmoniaReasoningResult {

        let allModules = existingModules + [newModule]

        let puzzle = ModuleIntegrationPuzzleBuilder.buildBoundaryViolationPuzzle(
            modules: allModules,
            dependencies: proposedDependencies,
            rules: architectureRules
        )

        let result = try await orchestrator.dispatch(puzzle)

        // Record history
        recordAnalysis(domain: .moduleIntegration, outcome: result.outcome)

        // Build Harmonia result
        return buildHarmoniaResult(
            baseResult: result,
            domain: .moduleIntegration,
            context: "Module integration: \(newModule)"
        )
    }

    /// Verifies that all World access goes through SecuredWorld.
    public func verifySecuredWorldEnforcement(
        modules: [String],
        worldAccessPoints: [(module: String, accessType: String, goesThrough: String?)]
    ) async throws -> HarmoniaReasoningResult {

        let puzzle = ModuleIntegrationPuzzleBuilder.buildSecuredWorldEnforcementPuzzle(
            modules: modules,
            worldAccessPoints: worldAccessPoints
        )

        let result = try await orchestrator.dispatch(puzzle)

        recordAnalysis(domain: .architectureBoundary, outcome: result.outcome)

        return buildHarmoniaResult(
            baseResult: result,
            domain: .architectureBoundary,
            context: "SecuredWorld enforcement check"
        )
    }

    // MARK: - Workflow Safety Analysis

    /// Analyzes a workflow for dangerous command sequences.
    public func analyzeWorkflowSafety(
        workflowId: String,
        steps: [WorkflowSafetyPuzzleBuilder.WorkflowStep],
        constraints: [WorkflowSafetyPuzzleBuilder.SafetyConstraint],
        workspaceRoot: String
    ) async throws -> HarmoniaReasoningResult {

        let puzzle = WorkflowSafetyPuzzleBuilder.buildDangerousSequencePuzzle(
            steps: steps,
            constraints: constraints,
            workspaceRoot: workspaceRoot
        )

        let result = try await orchestrator.dispatch(puzzle)

        recordAnalysis(domain: .workflowSafety, outcome: result.outcome)

        return buildHarmoniaResult(
            baseResult: result,
            domain: .workflowSafety,
            context: "Workflow safety: \(workflowId)"
        )
    }

    /// Detects potential infinite loops in macro definitions.
    public func detectMacroLoops(
        macros: [(id: String, triggers: [String], actions: [String])]
    ) async throws -> HarmoniaReasoningResult {

        let puzzle = WorkflowSafetyPuzzleBuilder.buildMacroLoopDetectionPuzzle(macros: macros)

        let result = try await orchestrator.dispatch(puzzle)

        recordAnalysis(domain: .workflowSafety, outcome: result.outcome)

        return buildHarmoniaResult(
            baseResult: result,
            domain: .workflowSafety,
            context: "Macro loop detection"
        )
    }

    // MARK: - Refactoring Analysis

    /// Analyzes a refactoring plan for safety.
    public func analyzeRefactoringSafety(
        operations: [RefactorSafetyPuzzleBuilder.RefactorOperation],
        invariants: [RefactorSafetyPuzzleBuilder.RefactorInvariant],
        dependencyGraph: [(from: String, to: String)]
    ) async throws -> HarmoniaReasoningResult {

        let puzzle = RefactorSafetyPuzzleBuilder.buildRefactorSafetyPuzzle(
            operations: operations,
            invariants: invariants,
            dependencyGraph: dependencyGraph
        )

        let result = try await orchestrator.dispatch(puzzle)

        recordAnalysis(domain: .refactorSafety, outcome: result.outcome)

        return buildHarmoniaResult(
            baseResult: result,
            domain: .refactorSafety,
            context: "Refactoring safety analysis"
        )
    }

    // MARK: - Cluster Orchestration Analysis

    /// Analyzes cluster scheduling for data residency violations.
    public func analyzeClusterScheduling(
        nodes: [ClusterOrchestrationPuzzleBuilder.ClusterNode],
        workloads: [ClusterOrchestrationPuzzleBuilder.Workload],
        residencyRules: [(sensitivity: String, allowedResidencies: Set<String>)]
    ) async throws -> HarmoniaReasoningResult {

        let puzzle = ClusterOrchestrationPuzzleBuilder.buildDataResidencyPuzzle(
            nodes: nodes,
            workloads: workloads,
            residencyRules: residencyRules
        )

        let result = try await orchestrator.dispatch(puzzle)

        recordAnalysis(domain: .clusterOrchestration, outcome: result.outcome)

        return buildHarmoniaResult(
            baseResult: result,
            domain: .clusterOrchestration,
            context: "Cluster scheduling analysis"
        )
    }

    // MARK: - Ensemble Analysis

    /// Runs an ensemble analysis for high-risk operations.
    public func analyzeWithEnsemble(
        puzzle: ReasoningPuzzle,
        domain: HarmoniaReasoningDomain
    ) async throws -> HarmoniaReasoningResult {

        let ensembleResult = try await orchestrator.analyzeWithEnsemble(puzzle)

        // Convert ensemble result to base result for Harmonia wrapper
        let baseResult = ReasoningResult(
            puzzleId: ensembleResult.puzzleId,
            outcome: ensembleResult.consensusOutcome ?? .notFound,
            transitionSequence: ensembleResult.allViolationPaths.first ?? [],
            finalState: nil,
            violatedConstraints: [],
            confidence: ensembleResult.combinedConfidence,
            stepsExplored: 0,
            durationMs: 0,
            explanation: "Ensemble analysis with \(ensembleResult.kernelResults.count) kernels",
            truncated: false
        )

        recordAnalysis(domain: domain, outcome: baseResult.outcome)

        var harmoniaResult = buildHarmoniaResult(
            baseResult: baseResult,
            domain: domain,
            context: "Ensemble analysis"
        )

        // Add ensemble-specific recommendations if there was disagreement
        if ensembleResult.hasDisagreement {
            var recommendations = harmoniaResult.recommendations
            recommendations.append(HarmoniaRecommendation(
                recommendationId: "ensemble_disagreement",
                category: .testing,
                description: "Reasoning kernels disagreed on this puzzle. Manual review recommended.",
                priority: .high,
                suggestedFix: "Review the conflicting violation paths and add explicit test cases."
            ))

            harmoniaResult = HarmoniaReasoningResult(
                baseResult: harmoniaResult.baseResult,
                harmoniaDomain: harmoniaResult.harmoniaDomain,
                diagnosis: harmoniaResult.diagnosis + " [ENSEMBLE DISAGREEMENT]",
                recommendations: recommendations,
                isBlocking: true,  // Disagreement always blocks
                riskLevel: .high
            )
        }

        return harmoniaResult
    }

    // MARK: - Statistics

    /// Gets analysis statistics.
    public func getStatistics() async -> HarmoniaReasoningStatistics {
        let orchestratorStats = await orchestrator.getStatistics()

        var domainCounts: [HarmoniaReasoningDomain: Int] = [:]
        var violationCounts: [HarmoniaReasoningDomain: Int] = [:]

        for entry in analysisHistory {
            domainCounts[entry.domain, default: 0] += 1
            if entry.outcome == .foundViolation {
                violationCounts[entry.domain, default: 0] += 1
            }
        }

        return HarmoniaReasoningStatistics(
            totalAnalyses: analysisHistory.count,
            analysesByDomain: domainCounts,
            violationsByDomain: violationCounts,
            orchestratorStatistics: orchestratorStats
        )
    }

    // MARK: - Private Helpers

    private func buildHarmoniaResult(
        baseResult: ReasoningResult,
        domain: HarmoniaReasoningDomain,
        context: String
    ) -> HarmoniaReasoningResult {

        let diagnosis: String
        let isBlocking: Bool
        let riskLevel: HarmoniaReasoningResult.OperationRiskLevel
        var recommendations: [HarmoniaRecommendation] = []

        switch baseResult.outcome {
        case .foundViolation:
            diagnosis = "\(context): Found \(baseResult.violatedConstraints.count) violation(s). Path: \(baseResult.transitionSequence.joined(separator: " → "))"
            isBlocking = config.blockOnViolation
            riskLevel = .critical

            // Generate recommendations based on violated constraints
            for (index, constraint) in baseResult.violatedConstraints.enumerated() {
                recommendations.append(HarmoniaRecommendation(
                    recommendationId: "fix_violation_\(index)",
                    category: categoryForDomain(domain),
                    description: "Fix constraint violation: \(constraint)",
                    priority: .critical,
                    suggestedFix: nil
                ))
            }

        case .provedInvariant:
            diagnosis = "\(context): All invariants verified. Operation is safe."
            isBlocking = false
            riskLevel = .safe

        case .foundPath:
            diagnosis = "\(context): Found path to goal. Path: \(baseResult.transitionSequence.joined(separator: " → "))"
            isBlocking = false
            riskLevel = .safe

        case .explorationComplete:
            diagnosis = "\(context): Exploration completed exhaustively. No issues found."
            isBlocking = false
            riskLevel = .safe

        case .notFound:
            diagnosis = "\(context): No violations found within search budget. Confidence: \(Int(baseResult.confidence * 100))%"
            isBlocking = false
            riskLevel = baseResult.confidence > 0.8 ? .low : .moderate

            if baseResult.confidence < 0.8 {
                recommendations.append(HarmoniaRecommendation(
                    recommendationId: "increase_budget",
                    category: .testing,
                    description: "Search confidence is below 80%. Consider increasing analysis budget.",
                    priority: .medium,
                    suggestedFix: "Run ensemble analysis or increase step budget."
                ))
            }

        case .timeout:
            diagnosis = "\(context): Analysis timed out. Results may be incomplete."
            isBlocking = config.blockOnTimeout
            riskLevel = .moderate

            recommendations.append(HarmoniaRecommendation(
                recommendationId: "timeout_warning",
                category: .testing,
                description: "Analysis timed out before completion.",
                priority: .medium,
                suggestedFix: "Simplify the operation or increase timeout."
            ))

        case .error:
            diagnosis = "\(context): Analysis error. Manual review required."
            isBlocking = config.blockOnError
            riskLevel = .high

            recommendations.append(HarmoniaRecommendation(
                recommendationId: "error_review",
                category: .testing,
                description: "Reasoning analysis encountered an error.",
                priority: .high,
                suggestedFix: "Review error logs and retry analysis."
            ))
        }

        return HarmoniaReasoningResult(
            baseResult: baseResult,
            harmoniaDomain: domain,
            diagnosis: diagnosis,
            recommendations: recommendations,
            isBlocking: isBlocking,
            riskLevel: riskLevel
        )
    }

    private func categoryForDomain(_ domain: HarmoniaReasoningDomain) -> HarmoniaRecommendation.RecommendationCategory {
        switch domain {
        case .moduleIntegration, .architectureBoundary:
            return .architecture
        case .workflowSafety:
            return .workflow
        case .refactorSafety:
            return .refactoring
        case .clusterOrchestration:
            return .cluster
        }
    }

    private func recordAnalysis(domain: HarmoniaReasoningDomain, outcome: ReasoningOutcome) {
        let entry = AnalysisHistoryEntry(
            timestamp: Date(),
            domain: domain,
            outcome: outcome
        )
        analysisHistory.append(entry)

        // Keep only recent history
        if analysisHistory.count > 1000 {
            analysisHistory.removeFirst(analysisHistory.count - 1000)
        }
    }
}

// MARK: - Supporting Types

/// Configuration for Harmonia reasoning.
public struct HarmoniaReasoningConfig: Sendable {
    public let blockOnViolation: Bool
    public let blockOnTimeout: Bool
    public let blockOnError: Bool
    public let ensembleThreshold: Double

    public static let `default` = HarmoniaReasoningConfig(
        blockOnViolation: true,
        blockOnTimeout: false,
        blockOnError: true,
        ensembleThreshold: 0.8
    )

    public init(
        blockOnViolation: Bool,
        blockOnTimeout: Bool = false,
        blockOnError: Bool = true,
        ensembleThreshold: Double
    ) {
        self.blockOnViolation = blockOnViolation
        self.blockOnTimeout = blockOnTimeout
        self.blockOnError = blockOnError
        self.ensembleThreshold = ensembleThreshold
    }
}

/// Entry in analysis history.
private struct AnalysisHistoryEntry {
    let timestamp: Date
    let domain: HarmoniaReasoningDomain
    let outcome: ReasoningOutcome
}

/// Statistics for Harmonia reasoning.
public struct HarmoniaReasoningStatistics: Sendable {
    public let totalAnalyses: Int
    public let analysesByDomain: [HarmoniaReasoningDomain: Int]
    public let violationsByDomain: [HarmoniaReasoningDomain: Int]
    public let orchestratorStatistics: OrchestratorStatistics
}
