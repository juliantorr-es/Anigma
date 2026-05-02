//
//  ReasoningOrchestrator.swift
//  AnigmaCore
//
//  Multi-gremlin orchestration layer.
//  Dispatches puzzles to specialized sub-kernels and aggregates results.
//
//  Architecture:
//  - ReasoningOrchestrator: Top-level coordinator
//  - SpecializedKernel: Domain-specific puzzle solvers
//  - EnsembleAnalysis: Multi-kernel agreement checking
//
//  This is the "bonkers" tier: a committee of disagreeing puzzle solvers.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import Foundation
import ContractsCore

// MARK: - Specialized Kernel Types

/// Types of specialized reasoning kernels.
public enum SpecializedKernelType: String, Sendable, Codable, CaseIterable {
    /// Tuned for access control and identity puzzles.
    case controlAttacker = "control_attacker"

    /// Tuned for DSPS/Transcriptum workflow state machines.
    case workflowKnotFinder = "workflow_knot_finder"

    /// Tuned for migration and update sequence analysis.
    case migrationDestroyer = "migration_destroyer"

    /// Tuned for scheduling and prioritizing analyses.
    case scheduler = "scheduler"

    /// Tuned for tenant isolation probing.
    case tenantProber = "tenant_prober"

    /// Tuned for automation rule analysis.
    case automationAnalyzer = "automation_analyzer"

    /// General-purpose fallback.
    case generalPurpose = "general_purpose"

    /// Domains this kernel specializes in.
    public var specializedDomains: [ReasoningDomain] {
        switch self {
        case .controlAttacker:
            return [.accessControl, .auditIntegrity]
        case .workflowKnotFinder:
            return [.workflowStates]
        case .migrationDestroyer:
            return [.updateSequence]
        case .scheduler:
            return []  // Meta-kernel
        case .tenantProber:
            return [.tenantIsolation]
        case .automationAnalyzer:
            return [.automationRules]
        case .generalPurpose:
            return ReasoningDomain.allCases
        }
    }

    /// Default configuration for this kernel type.
    public var defaultConfig: ReasonerConfig {
        switch self {
        case .controlAttacker:
            return ReasonerConfig(maxTransitions: 150, maxStepsAllowed: 5000, maxTimeMs: 10000)
        case .workflowKnotFinder:
            return ReasonerConfig(maxTransitions: 200, maxStepsAllowed: 15000, maxTimeMs: 20000)
        case .migrationDestroyer:
            return ReasonerConfig(maxTransitions: 100, maxStepsAllowed: 3000, maxTimeMs: 15000)
        case .scheduler:
            return ReasonerConfig(maxTransitions: 50, maxStepsAllowed: 500, maxTimeMs: 2000)
        case .tenantProber:
            return ReasonerConfig(maxTransitions: 100, maxStepsAllowed: 5000, maxTimeMs: 10000)
        case .automationAnalyzer:
            return ReasonerConfig(maxTransitions: 150, maxStepsAllowed: 8000, maxTimeMs: 12000)
        case .generalPurpose:
            return ReasonerConfig()
        }
    }
}

extension ReasoningDomain: CaseIterable {
    public static let allCases: [ReasoningDomain] = [
        .accessControl, .tenantIsolation, .auditIntegrity,
        .updateSequence, .automationRules, .workflowStates,
        .dataLifecycle, .compliance
    ]
}

// MARK: - Specialized Kernel

/// A specialized reasoning kernel for a specific domain.
public actor SpecializedKernel {
    /// Type of this kernel.
    public let kernelType: SpecializedKernelType

    /// Underlying reasoner.
    private let reasoner: RecursiveReasoner

    /// Statistics.
    private var puzzlesSolved: Int = 0
    private var violationsFound: Int = 0
    private var averageDurationMs: Double = 0

    public init(type: SpecializedKernelType) {
        self.kernelType = type
        self.reasoner = RecursiveReasoner(config: type.defaultConfig)
    }

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) async {
        await reasoner.setAuditLog(log)
    }

    /// Solves a puzzle using this specialized kernel.
    public func solve(_ puzzle: ReasoningPuzzle) async throws -> ReasoningResult {
        let result = try await reasoner.solve(puzzle)

        // Update statistics
        puzzlesSolved += 1
        if result.outcome == .foundViolation {
            violationsFound += 1
        }

        // Rolling average duration
        let newWeight = 1.0 / Double(puzzlesSolved)
        averageDurationMs = averageDurationMs * (1 - newWeight) + Double(result.durationMs) * newWeight

        return result
    }

    /// Gets kernel statistics.
    public func getStatistics() -> SpecializedKernelStatistics {
        SpecializedKernelStatistics(
            kernelType: kernelType,
            puzzlesSolved: puzzlesSolved,
            violationsFound: violationsFound,
            averageDurationMs: averageDurationMs
        )
    }

    /// Checks if this kernel is suitable for a domain.
    public func isSuitableFor(domain: ReasoningDomain) -> Bool {
        kernelType.specializedDomains.contains(domain) || kernelType == .generalPurpose
    }
}

/// Statistics for a specialized kernel.
public struct SpecializedKernelStatistics: Sendable {
    public let kernelType: SpecializedKernelType
    public let puzzlesSolved: Int
    public let violationsFound: Int
    public let averageDurationMs: Double
}

// MARK: - Ensemble Analysis

/// Result from running a puzzle through multiple kernels.
public struct EnsembleAnalysisResult: Sendable {
    /// The puzzle analyzed.
    public let puzzleId: UUID

    /// Results from each kernel.
    public let kernelResults: [SpecializedKernelType: ReasoningResult]

    /// Consensus outcome (if kernels agree).
    public let consensusOutcome: ReasoningOutcome?

    /// Disagreement flag.
    public let hasDisagreement: Bool

    /// Combined confidence.
    public let combinedConfidence: Double

    /// All unique violation paths found.
    public let allViolationPaths: [[String]]

    /// Analysis summary.
    public let summary: String

    /// Whether this puzzle is "interesting" (kernels disagreed or found unexpected results).
    public var isInteresting: Bool {
        hasDisagreement || allViolationPaths.count > 1
    }
}

// MARK: - Reasoning Orchestrator

/// Top-level orchestrator for multi-kernel reasoning.
/// Dispatches puzzles to appropriate specialized kernels and aggregates results.
public actor ReasoningOrchestrator {
    /// Specialized kernels.
    private var kernels: [SpecializedKernelType: SpecializedKernel] = [:]

    /// Audit log.
    private var auditLog: (any AuditLogging)?

    /// Risk-based scheduling state.
    private var domainRiskScores: [ReasoningDomain: Double] = [:]

    /// Recent analyses for adaptive scheduling.
    private var recentAnalyses: [AnalysisRecord] = []

    /// Total ensemble analyses run.
    private var ensembleAnalysesRun: Int = 0

    /// Total disagreements detected.
    private var disagreementsDetected: Int = 0

    public init() {
        // Initialize all specialized kernels
        for type in SpecializedKernelType.allCases {
            kernels[type] = SpecializedKernel(type: type)
        }

        // Initialize risk scores
        for domain in ReasoningDomain.allCases {
            domainRiskScores[domain] = 0.5  // Neutral starting risk
        }
    }

    /// Configures the orchestrator with dependencies.
    public func configure(auditLog: any AuditLogging) async {
        self.auditLog = auditLog
        for kernel in kernels.values {
            await kernel.setAuditLog(auditLog)
        }
    }

    // MARK: - Single Kernel Dispatch

    /// Dispatches a puzzle to the most appropriate kernel.
    public func dispatch(_ puzzle: ReasoningPuzzle) async throws -> ReasoningResult {
        let kernel = selectKernel(for: puzzle.domain)
        let result = try await kernel.solve(puzzle)

        // Record for adaptive scheduling
        recordAnalysis(domain: puzzle.domain, outcome: result.outcome, duration: result.durationMs)

        return result
    }

    // MARK: - Ensemble Analysis

    /// Runs a puzzle through multiple kernels and compares results.
    /// Use for high-risk or ambiguous puzzles.
    public func analyzeWithEnsemble(
        _ puzzle: ReasoningPuzzle,
        kernelTypes: [SpecializedKernelType]? = nil
    ) async throws -> EnsembleAnalysisResult {
        let typesToUse = kernelTypes ?? selectKernelsForEnsemble(domain: puzzle.domain)

        var results: [SpecializedKernelType: ReasoningResult] = [:]

        // Run puzzle through each kernel (could be parallelized)
        for type in typesToUse {
            if let kernel = kernels[type] {
                do {
                    results[type] = try await kernel.solve(puzzle)
                } catch {
                    // Log but continue with other kernels
                    try? await auditLog?.recordEvent(
                        id: UUID(),
                        type: ContractsCore.AuditEventType.custom,
                        principal: "reasoning_orchestrator",
                        module: "ReasoningOrchestrator",
                        description: "Kernel \(type.rawValue) failed: \(error.localizedDescription)",
                        metadata: ["puzzle_id": puzzle.puzzleId.uuidString, "original_event_type": "systemError"]
                    )
                }
            }
        }

        // Analyze consensus
        let outcomes = results.values.map { $0.outcome }
        let uniqueOutcomes = Set(outcomes)

        let hasDisagreement = uniqueOutcomes.count > 1
        if hasDisagreement {
            disagreementsDetected += 1
        }

        let consensusOutcome: ReasoningOutcome? = uniqueOutcomes.count == 1 ? outcomes.first : nil

        // Collect all violation paths
        var allPaths: [[String]] = []
        for result in results.values {
            if result.outcome == .foundViolation && !result.transitionSequence.isEmpty {
                if !allPaths.contains(where: { $0 == result.transitionSequence }) {
                    allPaths.append(result.transitionSequence)
                }
            }
        }

        // Combined confidence
        let confidences = results.values.map { $0.confidence }
        let combinedConfidence = confidences.isEmpty ? 0.0 : confidences.reduce(0.0, +) / Double(confidences.count)

        // Summary
        let summary = generateEnsembleSummary(
            outcomes: outcomes,
            hasDisagreement: hasDisagreement,
            pathCount: allPaths.count
        )

        ensembleAnalysesRun += 1

        // Record for adaptive scheduling
        recordAnalysis(
            domain: puzzle.domain,
            outcome: consensusOutcome ?? .notFound,
            duration: results.values.map { $0.durationMs }.max() ?? 0
        )

        return EnsembleAnalysisResult(
            puzzleId: puzzle.puzzleId,
            kernelResults: results,
            consensusOutcome: consensusOutcome,
            hasDisagreement: hasDisagreement,
            combinedConfidence: combinedConfidence,
            allViolationPaths: allPaths,
            summary: summary
        )
    }

    // MARK: - Adaptive Scheduling

    /// Gets the current risk-based priority for each domain.
    public func getDomainPriorities() -> [(domain: ReasoningDomain, priority: Double)] {
        domainRiskScores.map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    /// Updates risk score for a domain based on external signals.
    public func updateDomainRisk(
        _ domain: ReasoningDomain,
        factor: ReasoningRiskFactor,
        magnitude: Double
    ) {
        let currentRisk = domainRiskScores[domain] ?? 0.5
        let adjustment: Double

        switch factor {
        case .recentCodeChange:
            adjustment = 0.2 * magnitude
        case .recentProbeFailure:
            adjustment = 0.3 * magnitude
        case .complianceDeadline:
            adjustment = 0.25 * magnitude
        case .historicalVulnerability:
            adjustment = 0.15 * magnitude
        case .externalThreatIntel:
            adjustment = 0.4 * magnitude
        case .userReport:
            adjustment = 0.1 * magnitude
        }

        // Clamp to [0, 1]
        domainRiskScores[domain] = max(0, min(1, currentRisk + adjustment))
    }

    /// Suggests which domains should be analyzed next based on risk.
    public func suggestNextAnalyses(count: Int = 5) -> [ReasoningDomain] {
        getDomainPriorities()
            .prefix(count)
            .map { $0.domain }
    }

    // MARK: - Statistics

    /// Gets orchestrator statistics.
    public func getStatistics() async -> OrchestratorStatistics {
        var kernelStats: [SpecializedKernelType: SpecializedKernelStatistics] = [:]
        for (type, kernel) in kernels {
            kernelStats[type] = await kernel.getStatistics()
        }

        return OrchestratorStatistics(
            ensembleAnalysesRun: ensembleAnalysesRun,
            disagreementsDetected: disagreementsDetected,
            domainRiskScores: domainRiskScores,
            kernelStatistics: kernelStats
        )
    }

    // MARK: - Private Helpers

    private func selectKernel(for domain: ReasoningDomain) -> SpecializedKernel {
        // Find a specialized kernel for this domain
        for (type, kernel) in kernels {
            if type.specializedDomains.contains(domain) {
                return kernel
            }
        }
        // Fall back to general purpose
        return kernels[.generalPurpose]!
    }

    private func selectKernelsForEnsemble(domain: ReasoningDomain) -> [SpecializedKernelType] {
        var selected: [SpecializedKernelType] = []

        // Always include a specialist if available
        for type in SpecializedKernelType.allCases {
            if type.specializedDomains.contains(domain) {
                selected.append(type)
            }
        }

        // Always include general purpose for comparison
        if !selected.contains(.generalPurpose) {
            selected.append(.generalPurpose)
        }

        // Cap at 3 kernels for performance
        return Array(selected.prefix(3))
    }

    private func generateEnsembleSummary(
        outcomes: [ReasoningOutcome],
        hasDisagreement: Bool,
        pathCount: Int
    ) -> String {
        if hasDisagreement {
            return "Ensemble disagreement detected across \(outcomes.count) kernels. Found \(pathCount) unique violation paths. Manual review recommended."
        } else if let consensus = outcomes.first {
            switch consensus {
            case .foundViolation:
                return "All \(outcomes.count) kernels agree: violation found with \(pathCount) unique paths."
            case .provedInvariant:
                return "All \(outcomes.count) kernels agree: invariant proved safe."
            case .notFound:
                return "All \(outcomes.count) kernels agree: no violation found within budget."
            default:
                return "Ensemble analysis complete with consensus: \(consensus.rawValue)"
            }
        }
        return "Ensemble analysis complete."
    }

    private func recordAnalysis(domain: ReasoningDomain, outcome: ReasoningOutcome, duration: Int) {
        let record = AnalysisRecord(
            timestamp: Date(),
            domain: domain,
            outcome: outcome,
            durationMs: duration
        )
        recentAnalyses.append(record)

        // Keep only recent analyses (last 1000)
        if recentAnalyses.count > 1000 {
            recentAnalyses.removeFirst(recentAnalyses.count - 1000)
        }

        // Update risk scores based on outcomes
        if outcome == .foundViolation {
            updateDomainRisk(domain, factor: .recentProbeFailure, magnitude: 0.5)
        } else if outcome == .provedInvariant {
            // Slightly reduce risk for proven domains
            domainRiskScores[domain] = max(0, (domainRiskScores[domain] ?? 0.5) - 0.05)
        }
    }
}

/// Risk factors for adaptive scheduling in reasoning.
public enum ReasoningRiskFactor: String, Sendable {
    case recentCodeChange = "recent_code_change"
    case recentProbeFailure = "recent_probe_failure"
    case complianceDeadline = "compliance_deadline"
    case historicalVulnerability = "historical_vulnerability"
    case externalThreatIntel = "external_threat_intel"
    case userReport = "user_report"
}

/// Record of an analysis for scheduling.
private struct AnalysisRecord {
    let timestamp: Date
    let domain: ReasoningDomain
    let outcome: ReasoningOutcome
    let durationMs: Int
}

/// Statistics for the orchestrator.
public struct OrchestratorStatistics: Sendable {
    public let ensembleAnalysesRun: Int
    public let disagreementsDetected: Int
    public let domainRiskScores: [ReasoningDomain: Double]
    public let kernelStatistics: [SpecializedKernelType: SpecializedKernelStatistics]
}
