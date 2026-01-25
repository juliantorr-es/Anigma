//
//  HarmoniaCICDGate.swift
//  HarmoniaModule
//
//  CI/CD gate integration for Harmonia reasoning.
//  Blocks merges when reasoning analysis finds critical issues.
//
//  This makes the gremlin a first-class citizen in the PR pipeline:
//  - Analyzes changes touching critical domains
//  - Generates blocking/warning statuses
//  - Creates adversarial scenarios from findings
//  - Integrates with Pragma for issue tracking
//

@preconcurrency import Foundation
import AnigmaCore
import ContractsCore

// MARK: - CI/CD Gate Result

/// Result from a CI/CD gate check.
public struct HarmoniaCICDGateResult: Sendable {
    /// Unique ID for this gate check.
    public let checkId: UUID

    /// Timestamp of the check.
    public let timestamp: Date

    /// Overall gate status.
    public let status: GateStatus

    /// Individual check results.
    public let checkResults: [IndividualCheckResult]

    /// Summary message.
    public let summary: String

    /// Blocking issues.
    public let blockingIssues: [BlockingIssue]

    /// Warnings (non-blocking).
    public let warnings: [GateWarning]

    /// Whether the gate passes.
    public var passes: Bool {
        status == .passed || status == .passedWithWarnings
    }

    public enum GateStatus: String, Sendable {
        case passed = "passed"
        case passedWithWarnings = "passed_with_warnings"
        case failed = "failed"
        case error = "error"
    }

    public init(
        checkId: UUID = UUID(),
        timestamp: Date = Date(),
        status: GateStatus,
        checkResults: [IndividualCheckResult],
        summary: String,
        blockingIssues: [BlockingIssue],
        warnings: [GateWarning]
    ) {
        self.checkId = checkId
        self.timestamp = timestamp
        self.status = status
        self.checkResults = checkResults
        self.summary = summary
        self.blockingIssues = blockingIssues
        self.warnings = warnings
    }
}

/// Individual check result.
public struct IndividualCheckResult: Sendable {
    public let checkName: String
    public let domain: HarmoniaReasoningDomain
    public let passed: Bool
    public let message: String
    public let durationMs: Int

    public init(checkName: String, domain: HarmoniaReasoningDomain, passed: Bool, message: String, durationMs: Int) {
        self.checkName = checkName
        self.domain = domain
        self.passed = passed
        self.message = message
        self.durationMs = durationMs
    }
}

/// A blocking issue that prevents merge.
public struct BlockingIssue: Sendable {
    public let issueId: String
    public let domain: HarmoniaReasoningDomain
    public let severity: IssueSeverity
    public let description: String
    public let violationPath: [String]
    public let suggestedFix: String?

    public enum IssueSeverity: String, Sendable {
        case critical = "critical"
        case high = "high"
    }

    public init(
        issueId: String,
        domain: HarmoniaReasoningDomain,
        severity: IssueSeverity,
        description: String,
        violationPath: [String],
        suggestedFix: String? = nil
    ) {
        self.issueId = issueId
        self.domain = domain
        self.severity = severity
        self.description = description
        self.violationPath = violationPath
        self.suggestedFix = suggestedFix
    }
}

/// A warning (non-blocking).
public struct GateWarning: Sendable {
    public let warningId: String
    public let domain: HarmoniaReasoningDomain
    public let message: String

    public init(warningId: String, domain: HarmoniaReasoningDomain, message: String) {
        self.warningId = warningId
        self.domain = domain
        self.message = message
    }
}

// MARK: - Change Set Analysis

/// Represents a set of changes to be analyzed.
public struct ChangeSet: Sendable {
    /// Changed file paths.
    public let changedFiles: [String]

    /// Changed modules.
    public let changedModules: Set<String>

    /// New dependencies introduced.
    public let newDependencies: [ModuleIntegrationPuzzleBuilder.ModuleDependency]

    /// Modified workflows.
    public let modifiedWorkflows: [(id: String, steps: [WorkflowSafetyPuzzleBuilder.WorkflowStep])]

    /// Branch name.
    public let branchName: String

    /// Commit SHA.
    public let commitSha: String

    public init(
        changedFiles: [String],
        changedModules: Set<String>,
        newDependencies: [ModuleIntegrationPuzzleBuilder.ModuleDependency] = [],
        modifiedWorkflows: [(id: String, steps: [WorkflowSafetyPuzzleBuilder.WorkflowStep])] = [],
        branchName: String,
        commitSha: String
    ) {
        self.changedFiles = changedFiles
        self.changedModules = changedModules
        self.newDependencies = newDependencies
        self.modifiedWorkflows = modifiedWorkflows
        self.branchName = branchName
        self.commitSha = commitSha
    }

    /// Critical modules that trigger full analysis.
    public static let criticalModules: Set<String> = [
        "AnigmaCore",
        "Security",
        "Governance",
        "Identity",
        "Compliance",
        "Reasoning",
        "DSPS",
        "Transcriptum",
        "Tenant",
        "Storage",
        "Automation"
    ]

    /// Whether this change set touches critical modules.
    public var touchesCriticalModules: Bool {
        !changedModules.intersection(Self.criticalModules).isEmpty
    }
}

// MARK: - CI/CD Gate Service

/// Service for running CI/CD gate checks.
public actor HarmoniaCICDGateService {
    /// Underlying reasoning service.
    private let reasoningService: HarmoniaReasoningService

    /// Audit log.
    private var auditLog: AuditLog?

    /// Gate configuration.
    private let config: CICDGateConfig

    /// Recent gate results.
    private var recentResults: [HarmoniaCICDGateResult] = []

    public init(reasoningService: HarmoniaReasoningService, config: CICDGateConfig = .default) {
        self.reasoningService = reasoningService
        self.config = config
    }

    /// Configures the service.
    public func configure(auditLog: AuditLog) async {
        self.auditLog = auditLog
        await reasoningService.configure(auditLog: auditLog)
    }

    // MARK: - Gate Check

    /// Runs a full gate check on a change set.
    public func runGateCheck(changeSet: ChangeSet) async throws -> HarmoniaCICDGateResult {
        let checkId = UUID()
        let startTime = Date()

        var checkResults: [IndividualCheckResult] = []
        var blockingIssues: [BlockingIssue] = []
        var warnings: [GateWarning] = []

        // Determine which checks to run based on changed modules
        let checksToRun = determineChecks(for: changeSet)

        // Run each check
        for check in checksToRun {
            let checkStart = Date()

            do {
                let result = try await runCheck(check, changeSet: changeSet)

                let duration = Int(Date().timeIntervalSince(checkStart) * 1000)

                checkResults.append(IndividualCheckResult(
                    checkName: check.name,
                    domain: check.domain,
                    passed: !result.isBlocking,
                    message: result.diagnosis,
                    durationMs: duration
                ))

                // Collect issues
                if result.isBlocking {
                    blockingIssues.append(BlockingIssue(
                        issueId: "\(checkId.uuidString.prefix(8))_\(check.name)",
                        domain: check.domain,
                        severity: result.riskLevel == .critical ? .critical : .high,
                        description: result.diagnosis,
                        violationPath: result.baseResult.transitionSequence,
                        suggestedFix: result.recommendations.first?.suggestedFix
                    ))
                } else if result.riskLevel == .moderate {
                    warnings.append(GateWarning(
                        warningId: "\(checkId.uuidString.prefix(8))_\(check.name)_warn",
                        domain: check.domain,
                        message: result.diagnosis
                    ))
                }

            } catch {
                checkResults.append(IndividualCheckResult(
                    checkName: check.name,
                    domain: check.domain,
                    passed: !config.blockOnCheckError,
                    message: "Check failed with error: \(error.localizedDescription)",
                    durationMs: Int(Date().timeIntervalSince(checkStart) * 1000)
                ))

                if config.blockOnCheckError {
                    blockingIssues.append(BlockingIssue(
                        issueId: "\(checkId.uuidString.prefix(8))_\(check.name)_error",
                        domain: check.domain,
                        severity: .high,
                        description: "Check error: \(error.localizedDescription)",
                        violationPath: []
                    ))
                }
            }
        }

        // Determine overall status
        let status: HarmoniaCICDGateResult.GateStatus
        if !blockingIssues.isEmpty {
            status = .failed
        } else if !warnings.isEmpty {
            status = .passedWithWarnings
        } else {
            status = .passed
        }

        // Build summary
        let totalDuration = Int(Date().timeIntervalSince(startTime) * 1000)
        let summary = buildSummary(
            status: status,
            checksRun: checkResults.count,
            blockingCount: blockingIssues.count,
            warningCount: warnings.count,
            durationMs: totalDuration,
            changeSet: changeSet
        )

        let result = HarmoniaCICDGateResult(
            checkId: checkId,
            timestamp: Date(),
            status: status,
            checkResults: checkResults,
            summary: summary,
            blockingIssues: blockingIssues,
            warnings: warnings
        )

        // Record result
        recentResults.append(result)
        if recentResults.count > 100 {
            recentResults.removeFirst(recentResults.count - 100)
        }

        // Audit log
        if let log = auditLog {
            try? await log.record(
                eventType: status == .failed ? .securityHardening : .policyEvaluated,
                principal: "cicd_gate",
                module: "reasoning.cicd_gate",
                description: "Gate check \(status.rawValue) for \(changeSet.branchName)",
                metadata: [
                    "check_id": checkId.uuidString,
                    "branch": changeSet.branchName,
                    "commit": changeSet.commitSha,
                    "blocking_issues": String(blockingIssues.count),
                    "warnings": String(warnings.count)
                ]
            )
        }

        return result
    }

    /// Gets recent gate results.
    public func getRecentResults() -> [HarmoniaCICDGateResult] {
        recentResults
    }

    // MARK: - Private Helpers

    private func determineChecks(for changeSet: ChangeSet) -> [GateCheck] {
        var checks: [GateCheck] = []

        // Always run basic checks
        checks.append(GateCheck(
            name: "module_boundaries",
            domain: .architectureBoundary,
            isRequired: true
        ))

        // Add checks based on changed modules
        if changeSet.changedModules.contains("Security") ||
           changeSet.changedModules.contains("Governance") ||
           changeSet.changedModules.contains("Identity") {
            checks.append(GateCheck(
                name: "security_boundaries",
                domain: .architectureBoundary,
                isRequired: true
            ))
        }

        if !changeSet.modifiedWorkflows.isEmpty {
            checks.append(GateCheck(
                name: "workflow_safety",
                domain: .workflowSafety,
                isRequired: true
            ))
        }

        if changeSet.touchesCriticalModules {
            checks.append(GateCheck(
                name: "critical_module_analysis",
                domain: .moduleIntegration,
                isRequired: config.requireCriticalModuleAnalysis
            ))
        }

        return checks
    }

    private func runCheck(
        _ check: GateCheck,
        changeSet: ChangeSet
    ) async throws -> HarmoniaReasoningResult {

        switch check.domain {
        case .architectureBoundary:
            return try await reasoningService.verifySecuredWorldEnforcement(
                modules: Array(changeSet.changedModules),
                worldAccessPoints: []  // Would be populated from static analysis
            )

        case .workflowSafety:
            // Analyze each modified workflow
            for workflow in changeSet.modifiedWorkflows {
                let result = try await reasoningService.analyzeWorkflowSafety(
                    workflowId: workflow.id,
                    steps: workflow.steps,
                    constraints: config.defaultWorkflowConstraints,
                    workspaceRoot: "/"
                )
                if result.isBlocking {
                    return result
                }
            }
            // Return a passing result if all workflows pass
            return HarmoniaReasoningResult(
                baseResult: ReasoningResult(
                    puzzleId: UUID(),
                    outcome: .provedInvariant,
                    transitionSequence: [],
                    finalState: nil,
                    violatedConstraints: [],
                    confidence: 1.0,
                    stepsExplored: 0,
                    durationMs: 0,
                    explanation: "All workflows passed",
                    truncated: false
                ),
                harmoniaDomain: .workflowSafety,
                diagnosis: "All workflows passed safety checks",
                recommendations: [],
                isBlocking: false,
                riskLevel: .safe
            )

        case .moduleIntegration:
            return try await reasoningService.analyzeModuleIntegration(
                newModule: changeSet.changedModules.first ?? "unknown",
                existingModules: Array(ChangeSet.criticalModules),
                proposedDependencies: changeSet.newDependencies,
                architectureRules: config.defaultArchitectureRules
            )

        default:
            // Default passing result for unhandled domains
            return HarmoniaReasoningResult(
                baseResult: ReasoningResult(
                    puzzleId: UUID(),
                    outcome: .provedInvariant,
                    transitionSequence: [],
                    finalState: nil,
                    violatedConstraints: [],
                    confidence: 1.0,
                    stepsExplored: 0,
                    durationMs: 0,
                    explanation: "No specific analysis for domain",
                    truncated: false
                ),
                harmoniaDomain: check.domain,
                diagnosis: "Check passed (no specific analysis for domain)",
                recommendations: [],
                isBlocking: false,
                riskLevel: .safe
            )
        }
    }

    private func buildSummary(
        status: HarmoniaCICDGateResult.GateStatus,
        checksRun: Int,
        blockingCount: Int,
        warningCount: Int,
        durationMs: Int,
        changeSet: ChangeSet
    ) -> String {
        var lines: [String] = []

        lines.append("## Harmonia Reasoning Gate Check")
        lines.append("")
        lines.append("**Status:** \(status.rawValue.uppercased())")
        lines.append("**Branch:** \(changeSet.branchName)")
        lines.append("**Commit:** \(changeSet.commitSha.prefix(8))")
        lines.append("**Duration:** \(durationMs)ms")
        lines.append("")
        lines.append("### Summary")
        lines.append("- Checks run: \(checksRun)")
        lines.append("- Blocking issues: \(blockingCount)")
        lines.append("- Warnings: \(warningCount)")
        lines.append("- Changed modules: \(changeSet.changedModules.joined(separator: ", "))")

        if changeSet.touchesCriticalModules {
            lines.append("")
            lines.append("⚠️ **Critical modules touched:** \(changeSet.changedModules.intersection(ChangeSet.criticalModules).joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

/// A gate check to run.
private struct GateCheck {
    let name: String
    let domain: HarmoniaReasoningDomain
    let isRequired: Bool
}

/// Configuration for CI/CD gate.
public struct CICDGateConfig: Sendable {
    public let blockOnCheckError: Bool
    public let requireCriticalModuleAnalysis: Bool
    public let defaultWorkflowConstraints: [WorkflowSafetyPuzzleBuilder.SafetyConstraint]
    public let defaultArchitectureRules: [ModuleIntegrationPuzzleBuilder.ArchitectureRule]

    public static let `default` = CICDGateConfig(
        blockOnCheckError: true,
        requireCriticalModuleAnalysis: true,
        defaultWorkflowConstraints: [
            WorkflowSafetyPuzzleBuilder.SafetyConstraint(
                constraintId: "no_rm_rf",
                description: "No destructive recursive deletes",
                forbiddenCommands: ["rm -rf /", "rm -rf ~", "rm -rf *"]
            ),
            WorkflowSafetyPuzzleBuilder.SafetyConstraint(
                constraintId: "protect_git",
                description: "Protect .git directory",
                protectedPaths: [".git"]
            )
        ],
        defaultArchitectureRules: [
            ModuleIntegrationPuzzleBuilder.ArchitectureRule(
                ruleId: "no_direct_world",
                description: "No module may directly access World without SecuredWorld",
                forbiddenDependency: nil,
                severity: .critical
            )
        ]
    )

    public init(
        blockOnCheckError: Bool,
        requireCriticalModuleAnalysis: Bool,
        defaultWorkflowConstraints: [WorkflowSafetyPuzzleBuilder.SafetyConstraint],
        defaultArchitectureRules: [ModuleIntegrationPuzzleBuilder.ArchitectureRule]
    ) {
        self.blockOnCheckError = blockOnCheckError
        self.requireCriticalModuleAnalysis = requireCriticalModuleAnalysis
        self.defaultWorkflowConstraints = defaultWorkflowConstraints
        self.defaultArchitectureRules = defaultArchitectureRules
    }
}
