//
//  SessionEpilogueRunner.swift
//  HarmoniaModule
//
//  The reflex arc: automatically runs behavioral analysis after every session.
//  Turns monitoring into steering.
//

import Foundation
import GRDB

// MARK: - Session Epilogue Context

/// Context for session epilogue.
public struct SessionEpilogueContext: Sendable {
    public let projectId: UUID
    public let sessionIndex: Int
    public let featureId: UUID?
    public let sessionResult: CodingSessionResult
    public let configId: String?
    public let featureCategory: String?

    public init(
        projectId: UUID,
        sessionIndex: Int,
        featureId: UUID? = nil,
        sessionResult: CodingSessionResult,
        configId: String? = nil,
        featureCategory: String? = nil
    ) {
        self.projectId = projectId
        self.sessionIndex = sessionIndex
        self.featureId = featureId
        self.sessionResult = sessionResult
        self.configId = configId
        self.featureCategory = featureCategory
    }
}

// MARK: - Session Health Summary

/// Summary of session health for CLI notification.
public struct SessionHealthSummary: Sendable {
    public let projectId: UUID
    public let sessionIndex: Int
    public let metrics: BehavioralHealthMetrics
    public let violations: [InvariantViolation]
    public let isHealthy: Bool
    public let healthScore: Double

    public init(
        projectId: UUID,
        sessionIndex: Int,
        metrics: BehavioralHealthMetrics,
        violations: [InvariantViolation],
        isHealthy: Bool,
        healthScore: Double
    ) {
        self.projectId = projectId
        self.sessionIndex = sessionIndex
        self.metrics = metrics
        self.violations = violations
        self.isHealthy = isHealthy
        self.healthScore = healthScore
    }

    /// Whether there are critical violations (severity >= 0.7).
    public var hasCriticalViolations: Bool {
        violations.contains { $0.severity >= 0.7 }
    }

    /// Critical violations count.
    public var criticalViolationsCount: Int {
        violations.filter { $0.severity >= 0.7 }.count
    }
}

// MARK: - Git Diff Service

/// Service for computing git diffs.
public actor GitDiffService {
    private let store: ProjectHarnessStore

    public init(store: ProjectHarnessStore = .shared) {
        self.store = store
    }

    /// Computes git diff summary for a session.
    public func diffForSession(
        projectId: UUID,
        sessionIndex: Int
    ) async throws -> GitDiffSummary? {
        // Get project to find directory
        guard let project = try await store.loadProject(id: projectId.uuidString) else {
            return nil
        }

        guard let projectDirectory = project.projectDirectory else {
            return nil
        }

        // Try to get actual git diff
        return try await getActualGitDiff(projectDirectory: projectDirectory)
    }

    /// Gets git diff from actual git tool.
    private func getActualGitDiff(projectDirectory: String) async throws -> GitDiffSummary? {
        let fileManager = FileManager.default

        // Check if directory exists and is a git repo
        guard fileManager.fileExists(atPath: projectDirectory) else {
            return nil
        }

        let gitDir = URL(fileURLWithPath: projectDirectory).appendingPathComponent(".git").path
        guard fileManager.fileExists(atPath: gitDir) else {
            return nil
        }

        // Run git diff --stat to get summary
        let statOutput = try await runGitCommand(
            at: projectDirectory,
            arguments: ["diff", "--stat", "--numstat", "HEAD~1..HEAD"]
        )

        // Parse the output
        return parseGitDiffStats(statOutput)
    }

    /// Runs a git command and returns output.
    private func runGitCommand(at path: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let exitCode = process.terminationStatus
        let output = String(data: outputData, encoding: .utf8) ?? ""
        _ = String(data: errorData, encoding: .utf8) ?? ""

        guard exitCode == 0 else {
            // If git command fails (e.g., no commits yet), return empty
            return ""
        }

        return output
    }

    /// Parses git diff --stat --numstat output.
    private func parseGitDiffStats(_ output: String) -> GitDiffSummary? {
        var filesAdded = 0
        var filesModified = 0
        var filesDeleted = 0
        var linesAdded = 0
        var linesRemoved = 0

        let lines = output.split(separator: "\n")

        // If no output, return nil
        if lines.isEmpty {
            return nil
        }

        for line in lines {
            let parts = line.split(separator: "\t")
            guard parts.count >= 3 else { continue }

            let additions = Int(parts[0]) ?? 0
            let deletions = Int(parts[1]) ?? 0
            let filename = String(parts[2])

            if additions == 0 && deletions == 0 {
                // Binary file or rename
                continue
            }

            // Classify file change type
            if filename.hasPrefix("Binary files") {
                // Binary file
                continue
            } else if additions > 0 && deletions == 0 {
                // New file or all additions
                filesAdded += 1
            } else if additions == 0 && deletions > 0 {
                // File deletion
                filesDeleted += 1
            } else {
                // File modification
                filesModified += 1
            }

            linesAdded += additions
            linesRemoved += deletions
        }

        // If no changes detected, return nil
        if filesAdded == 0 && filesModified == 0 && filesDeleted == 0 {
            return nil
        }

        return GitDiffSummary(
            filesAdded: filesAdded,
            filesModified: filesModified,
            filesDeleted: filesDeleted,
            linesAdded: linesAdded,
            linesRemoved: linesRemoved
        )
    }
}

// MARK: - Behavioral Metrics Service

/// Service for computing behavioral metrics.
public actor BehavioralMetricsService {
    private let store: ProjectHarnessStore

    public init(store: ProjectHarnessStore = .shared) {
        self.store = store
    }

    /// Computes behavioral metrics for a session.
    public func computeMetrics(
        projectId: UUID,
        sessionIndex: Int,
        diffSummary: GitDiffSummary? = nil,
        formatterResults: FormatterResults? = nil,
        linterResults: LinterResults? = nil
    ) async throws -> BehavioralHealthMetrics {
        // Use existing store method to compute metrics
        let metrics = try await store.computeBehavioralMetrics(
            projectId: projectId,
            sessionIndex: sessionIndex
        )

        // Create metrics with all available data
        let filesChanged = diffSummary.map { $0.filesAdded + $0.filesModified + $0.filesDeleted }
        let linesChanged = diffSummary.map { $0.linesAdded + $0.linesRemoved }

        return BehavioralHealthMetrics(
            sessionIndex: metrics.sessionIndex,
            projectId: metrics.projectId,
            featureId: metrics.featureId,
            analysisRatio: metrics.analysisRatio,
            firstEditLatency: metrics.firstEditLatency,
            toolDiversity: metrics.toolDiversity,
            editCalls: metrics.editCalls,
            analysisCalls: metrics.analysisCalls,
            testCalls: metrics.testCalls,
            filesChanged: filesChanged,
            linesChanged: linesChanged,
            testsPassed: metrics.testsPassed,
            testsFailed: metrics.testsFailed,
            formatterSucceeded: formatterResults?.succeeded,
            formatterWarnings: formatterResults?.warnings,
            formatterErrors: formatterResults?.errors,
            gitDiffSummary: diffSummary,
            lintSucceeded: linterResults?.succeeded,
            lintWarnings: linterResults?.warnings,
            lintErrors: linterResults?.errors
        )
    }
}

// MARK: - Session Epilogue Runner

/// Runner that executes the session epilogue automatically.
public actor SessionEpilogueRunner {
    private let store: ProjectHarnessStore
    private let metricsService: BehavioralMetricsService
    private let reportGenerator: SessionReportGenerator
    private let gitService: GitDiffService
    private let codeQualityService: CodeQualityService
    private let inspector: ToolUsageInspector

    public init(
        store: ProjectHarnessStore = .shared,
        metricsService: BehavioralMetricsService = BehavioralMetricsService(),
        reportGenerator: SessionReportGenerator = SessionReportGenerator(),
        gitService: GitDiffService = GitDiffService(),
        codeQualityService: CodeQualityService = .shared,
        inspector: ToolUsageInspector = ToolUsageInspector()
    ) {
        self.store = store
        self.metricsService = metricsService
        self.reportGenerator = reportGenerator
        self.gitService = gitService
        self.codeQualityService = codeQualityService
        self.inspector = inspector
    }

    /// Runs the epilogue for a session.
    public func runEpilogue(_ context: SessionEpilogueContext) async throws -> SessionHealthSummary {
        let projectId = context.projectId
        let sessionIndex = context.sessionIndex

        // 1. Compute git diff summary
        let diffSummary = try await gitService.diffForSession(
            projectId: projectId,
            sessionIndex: sessionIndex
        )

        // 2. Run code quality tools (if project directory available)
        var formatterResults: FormatterResults?
        var linterResults: LinterResults?

        if let project = try await store.loadProject(id: projectId.uuidString),
           let projectDirectory = project.projectDirectory {

            // Run formatter
            formatterResults = try await codeQualityService.runFormatter(
                projectDirectory: projectDirectory
            )

            // Run linter
            linterResults = try await codeQualityService.runLinter(
                projectDirectory: projectDirectory
            )
        }

        // 3. Compute behavioral metrics
        let metrics = try await metricsService.computeMetrics(
            projectId: projectId,
            sessionIndex: sessionIndex,
            diffSummary: diffSummary,
            formatterResults: formatterResults,
            linterResults: linterResults
        )

        // 3. Save metrics to store
        try await store.saveBehavioralMetrics(metrics)

        // 4. Update feature history if applicable
        if let featureId = context.featureId {
            try await updateFeatureBehavioralHistory(
                projectId: projectId,
                featureId: featureId,
                sessionIndex: sessionIndex,
                metrics: metrics,
                sessionResult: context.sessionResult
            )
        }

        // 5. Generate and save session report
        let report = try await reportGenerator.generateReport(
            projectId: projectId,
            sessionIndex: sessionIndex,
            featureId: context.featureId,
            configId: context.configId,
            featureCategory: context.featureCategory
        )
        try await store.saveSessionReport(report)

        // 6. Update bandit stats if config was used
        if let configId = context.configId,
           let featureCategory = context.featureCategory,
           report.isValidForBanditLearning {
            let reward = report.banditReward
            try await store.updateBanditStats(
                projectId: projectId,
                featureCategory: featureCategory,
                configId: configId,
                reward: reward
            )
        }

        // 8. Run invariant checks
        let violations = try await inspector.checkSessionInvariants(
            projectId: projectId,
            sessionIndex: sessionIndex
        )

        // 9. Post-hoc governance checks and tainting
        let (tainted, governanceFindings) = try await checkPostHocGovernance(
            projectId: projectId,
            sessionIndex: sessionIndex,
            report: report,
            metrics: metrics,
            violations: violations
        )

        // 10. Update report with taint and findings if needed
        if tainted || !governanceFindings.isEmpty {
            try await updateReportWithGovernanceFindings(
                projectId: projectId,
                sessionIndex: sessionIndex,
                tainted: tainted,
                findings: governanceFindings
            )
        }

        return SessionHealthSummary(
            projectId: projectId,
            sessionIndex: sessionIndex,
            metrics: metrics,
            violations: violations,
            isHealthy: metrics.isHealthy,
            healthScore: metrics.healthScore
        )
    }

    // MARK: - Post-Hoc Governance

    /// Checks for post-hoc governance violations and marks sessions as tainted.
    private func checkPostHocGovernance(
        projectId: UUID,
        sessionIndex: Int,
        report: SessionReport,
        metrics: BehavioralHealthMetrics,
        violations: [InvariantViolation]
    ) async throws -> (tainted: Bool, findings: [GovernanceFinding]) {
        var findings: [GovernanceFinding] = []
        var tainted = false

        // Check 1: Health score too low
        if metrics.healthScore < 0.3 {
            findings.append(GovernanceFinding(
                code: "health_too_low",
                message: "Health score \(String(format: "%.0f%%", metrics.healthScore * 100)) is below threshold (30%)",
                severity: .critical
            ))
            tainted = true
        }

        // Check 2: Critical violations
        let criticalViolations = violations.filter { $0.severity >= 0.7 }
        if !criticalViolations.isEmpty {
            findings.append(GovernanceFinding(
                code: "critical_violations",
                message: "\(criticalViolations.count) critical behavioral violations",
                severity: .critical
            ))
            tainted = true
        }

        // Check 3: Too many files changed (potential blast radius)
        if let filesChanged = metrics.filesChanged, filesChanged > 20 {
            findings.append(GovernanceFinding(
                code: "large_diff",
                message: "Changed \(filesChanged) files (potential blast radius)",
                severity: .warning
            ))
            // Large diffs are suspicious but not automatically tainted
        }

        // Check 4: All tests failed
        if let testsPassed = metrics.testsPassed,
           let testsFailed = metrics.testsFailed,
           testsPassed == 0 && testsFailed > 0 {
            findings.append(GovernanceFinding(
                code: "all_tests_failed",
                message: "All \(testsFailed) tests failed",
                severity: .critical
            ))
            tainted = true
        }

        // Check 5: Formatter failed
        if let formatterSucceeded = metrics.formatterSucceeded, !formatterSucceeded {
            findings.append(GovernanceFinding(
                code: "formatter_failed",
                message: "Code formatter failed to run",
                severity: .warning
            ))
        }

        return (tainted, findings)
    }

    /// Updates session report with governance findings and taint status.
    private func updateReportWithGovernanceFindings(
        projectId: UUID,
        sessionIndex: Int,
        tainted: Bool,
        findings: [GovernanceFinding]
    ) async throws {
        // Get the report
        let reports = try await store.getSessionReports(projectId: projectId, limit: 1)
        guard var report = reports.first else {
            return
        }

        // Update governance trace if it exists
        if var trace = report.governanceTrace {
            trace.gatekeeperFindings.append(contentsOf: findings)
            trace.tainted = tainted
            if tainted {
                trace.securityOutcome = .tainted
            }
            report.governanceTrace = trace
        } else {
            // Create a basic trace if none exists
            report.governanceTrace = GovernanceTrace.default(
                configId: report.configId,
                trustTier: .trusted
            )
            report.governanceTrace?.gatekeeperFindings = findings
            report.governanceTrace?.tainted = tainted
            if tainted {
                report.governanceTrace?.securityOutcome = .tainted
            }
        }

        // Save updated report
        try await store.saveSessionReport(report)

        // Log tainting
        if tainted {
            print("[Governance] Session \(sessionIndex) marked as TAINTED with \(findings.count) findings")
        } else if !findings.isEmpty {
            print("[Governance] Session \(sessionIndex) has \(findings.count) governance findings")
        }
    }

    /// Updates feature behavioral history.
    private func updateFeatureBehavioralHistory(
        projectId: UUID,
        featureId: UUID,
        sessionIndex: Int,
        metrics: BehavioralHealthMetrics,
        sessionResult: CodingSessionResult
    ) async throws {
        // Get test results from session result
        let testsPassed = sessionResult.testsFailed == 0 && sessionResult.testsPassed > 0

        // Create work summary from session result
        let workSummary = """
        Session \(sessionIndex): \(sessionResult.summary)
        Features worked on: \(sessionResult.featuresWorkedOn.map { $0.name }.joined(separator: ", "))
        Tests: \(sessionResult.testsPassed) passed, \(sessionResult.testsFailed) failed
        """

        // Update feature behavioral history
            try await store.updateFeatureBehavioralHistory(
            featureId: featureId,
            sessionIndex: sessionIndex,
            healthScore: metrics.healthScore,
            analysisRatio: metrics.analysisRatio,
            editCalls: metrics.editCalls,
            analysisCalls: metrics.analysisCalls,
            testCalls: metrics.testCalls,
            testsPassed: testsPassed,
            workSummary: workSummary
        )
    }
}

// MARK: - Rude CLI Notifier

/// Notifier that bullies you about session health.
public actor RudeCLINotifier {
    private let store: ProjectHarnessStore
    private let reportGenerator: SessionReportGenerator

    public init(
        store: ProjectHarnessStore = .shared,
        reportGenerator: SessionReportGenerator = SessionReportGenerator()
    ) {
        self.store = store
        self.reportGenerator = reportGenerator
    }

    /// Handles post-session notification and bullying.
    public func handlePostSession(
        projectId: UUID,
        sessionIndex: Int,
        summary: SessionHealthSummary
    ) async throws {
        // Only bully if there are issues
        if summary.isHealthy && !summary.hasCriticalViolations {
            print("✅ Session \(sessionIndex) completed with healthy behavior")
            return
        }

        // Get the session report
        let reports = try await store.getSessionReports(projectId: projectId, limit: 1)
        guard let report = reports.first else {
            print("⚠️  Session \(sessionIndex) completed but no report found")
            return
        }

        // Show bullying message
        print("\n" + String(repeating: "🚨", count: 20))
        print("🚨 HARESS BEHAVIOR ALERT 🚨")
        print(String(repeating: "🚨", count: 20))
        print()

        print("Session \(sessionIndex) for project \(projectId.uuidString.prefix(8))...")
        print()

        if !summary.isHealthy {
            print("❌ UNHEALTHY BEHAVIOR DETECTED")
            print("Health score: \(String(format: "%.0f%%", summary.healthScore * 100))")
            print("Analysis ratio: \(String(format: "%.0f%%", summary.metrics.analysisRatio * 100))")
            print("First edit latency: \(summary.metrics.firstEditLatency) analysis calls")
            print("Tool diversity: \(summary.metrics.toolDiversity) tools")
            print()
        }

        if summary.hasCriticalViolations {
            print("🔴 CRITICAL VIOLATIONS:")
            for violation in summary.violations.filter({ $0.severity >= 0.7 }) {
                print("  - \(violation.type.rawValue): \(violation.description)")
            }
            print()
        }

        // Show report excerpt
        print("📖 SESSION REPORT EXCERPT:")
        let lines = report.narrative.split(separator: ". ")
        for line in lines.prefix(3) {
            print("  • \(line).")
        }
        print()

        // Show recommendations
        if !report.recommendations.isEmpty {
            print("💡 RECOMMENDATIONS:")
            for (index, recommendation) in report.recommendations.prefix(3).enumerated() {
                print("  \(index + 1). \(recommendation)")
            }
            print()
        }

        print("⚠️  ACKNOWLEDGE THIS SESSION TO CONTINUE:")
        print("  harmonia acknowledge --project \(projectId) --session \(sessionIndex)")
        print("  OR view full report: harmonia view-report --session \(sessionIndex)")
        print()
        print(String(repeating: "🚨", count: 20))
        print()
    }

    /// Acknowledges a session to silence warnings.
    public func acknowledgeSession(
        projectId: UUID,
        sessionIndex: Int
    ) async throws {
        try await store.acknowledgeSession(projectId: projectId, sessionIndex: sessionIndex)
        print("✅ Session \(sessionIndex) acknowledged. Warnings silenced.")

        // Show one-line summary anyway
        let reports = try await store.getSessionReports(projectId: projectId, limit: 1)
        if let report = reports.first {
            print("📝 Summary: \(report.oneLineSummary)")
        }
    }

    /// Forces reading of the last session report.
    public func forceReadLastReport(projectId: UUID) async throws {
        let reports = try await store.getSessionReports(projectId: projectId, limit: 1)
        guard let report = reports.first else {
            print("No reports found for project \(projectId.uuidString.prefix(8))...")
            return
        }

        print("\n" + String(repeating: "👀", count: 20))
        print("👀 FORCED REPORT READING 👀")
        print(String(repeating: "👀", count: 20))
        print()

        print(report.markdownReport)

        print("\n" + String(repeating: "👀", count: 20))
        print("END OF REPORT")
        print(String(repeating: "👀", count: 20))
    }

    // MARK: - Post-Hoc Governance

    /// Checks for post-hoc governance violations and marks sessions as tainted.
    private func checkPostHocGovernance(
        projectId: UUID,
        sessionIndex: Int,
        report: SessionReport,
        metrics: BehavioralHealthMetrics,
        violations: [InvariantViolation]
    ) async throws -> (tainted: Bool, findings: [GovernanceFinding]) {
        var findings: [GovernanceFinding] = []
        var tainted = false

        // Check 1: Health score too low
        if metrics.healthScore < 0.3 {
            findings.append(GovernanceFinding(
                code: "health_too_low",
                message: "Health score \(String(format: "%.0f%%", metrics.healthScore * 100)) is below threshold (30%)",
                severity: .critical
            ))
            tainted = true
        }

        // Check 2: Critical violations
        let criticalViolations = violations.filter { $0.severity >= 0.7 }
        if !criticalViolations.isEmpty {
            findings.append(GovernanceFinding(
                code: "critical_violations",
                message: "\(criticalViolations.count) critical behavioral violations",
                severity: .critical
            ))
            tainted = true
        }

        // Check 3: Too many files changed (potential blast radius)
        if let filesChanged = metrics.filesChanged, filesChanged > 20 {
            findings.append(GovernanceFinding(
                code: "large_diff",
                message: "Changed \(filesChanged) files (potential blast radius)",
                severity: .warning
            ))
            // Large diffs are suspicious but not automatically tainted
        }

        // Check 4: All tests failed
        if let testsPassed = metrics.testsPassed,
           let testsFailed = metrics.testsFailed,
           testsPassed == 0 && testsFailed > 0 {
            findings.append(GovernanceFinding(
                code: "all_tests_failed",
                message: "All \(testsFailed) tests failed",
                severity: .critical
            ))
            tainted = true
        }

        // Check 5: Formatter failed
        if let formatterSucceeded = metrics.formatterSucceeded, !formatterSucceeded {
            findings.append(GovernanceFinding(
                code: "formatter_failed",
                message: "Code formatter failed to run",
                severity: .warning
            ))
        }

        return (tainted, findings)
    }

    /// Updates session report with governance findings and taint status.
    private func updateReportWithGovernanceFindings(
        projectId: UUID,
        sessionIndex: Int,
        tainted: Bool,
        findings: [GovernanceFinding]
    ) async throws {
        // Get the report
        let reports = try await store.getSessionReports(projectId: projectId, limit: 1)
        guard var report = reports.first else {
            return
        }

        // Update governance trace if it exists
        if var trace = report.governanceTrace {
            trace.gatekeeperFindings.append(contentsOf: findings)
            trace.tainted = tainted
            if tainted {
                trace.securityOutcome = .tainted
            }
            report.governanceTrace = trace
        } else {
            // Create a basic trace if none exists
            report.governanceTrace = GovernanceTrace(
                configId: report.configId,
                trustTier: .trusted, // Default
                policyDecision: .allowed, // Default
                gatekeeperFindings: findings,
                securityOutcome: tainted ? .tainted : .clean,
                tainted: tainted
            )
        }

        // Save updated report
        try await store.saveSessionReport(report)

        // Log tainting
        if tainted {
            print("[Governance] Session \(sessionIndex) marked as TAINTED with \(findings.count) findings")
        } else if !findings.isEmpty {
            print("[Governance] Session \(sessionIndex) has \(findings.count) governance findings")
        }
    }
}
