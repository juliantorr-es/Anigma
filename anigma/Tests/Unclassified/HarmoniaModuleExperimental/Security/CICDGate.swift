//
//  CICDGate.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  CI/CD blocking gates based on doctrine health scores.
//  Blocks merges/releases when security posture is insufficient.
//  Not vibes - actual blocking with configurable thresholds.
//

import Foundation
import HarmoniaModule

// MARK: - CI/CD Gate Configuration

/// Configuration for CI/CD gates.
public struct CICDGateConfig: Sendable, Codable {
    /// Minimum security health score to allow merge (0-100).
    public let minimumSecurityScore: Double

    /// Minimum overall doctrine health score to allow merge (0-100).
    public let minimumDoctrineScore: Double

    /// Critical security violations that always block.
    public let blockingViolations: [String]  // Rule IDs

    /// Whether to block on any critical violation.
    public let blockOnCritical: Bool

    /// Whether to block on any security violation.
    public let blockOnSecurityViolation: Bool

    /// Whether to allow overrides with platinum trust tier.
    public let allowPlatinumOverride: Bool

    /// Whether to create GitHub status checks.
    public let createStatusChecks: Bool

    /// Whether to comment on PR with violations.
    public let commentOnPR: Bool

    /// Whether to fail fast on first blocking violation.
    public let failFast: Bool

    public init(
        minimumSecurityScore: Double = 80.0,
        minimumDoctrineScore: Double = 70.0,
        blockingViolations: [String] = ["sec-secret-001", "sec-auth-001", "sec-crypto-001"],
        blockOnCritical: Bool = true,
        blockOnSecurityViolation: Bool = true,
        allowPlatinumOverride: Bool = false,
        createStatusChecks: Bool = true,
        commentOnPR: Bool = true,
        failFast: Bool = true
    ) {
        self.minimumSecurityScore = max(0.0, min(100.0, minimumSecurityScore))
        self.minimumDoctrineScore = max(0.0, min(100.0, minimumDoctrineScore))
        self.blockingViolations = blockingViolations
        self.blockOnCritical = blockOnCritical
        self.blockOnSecurityViolation = blockOnSecurityViolation
        self.allowPlatinumOverride = allowPlatinumOverride
        self.createStatusChecks = createStatusChecks
        self.commentOnPR = commentOnPR
        self.failFast = failFast
    }

    /// Default configuration for production.
    public static let production = CICDGateConfig(
        minimumSecurityScore: 90.0,
        minimumDoctrineScore: 80.0,
        blockOnCritical: true,
        blockOnSecurityViolation: true,
        allowPlatinumOverride: false
    )

    /// Default configuration for development.
    public static let development = CICDGateConfig(
        minimumSecurityScore: 70.0,
        minimumDoctrineScore: 60.0,
        blockOnCritical: true,
        blockOnSecurityViolation: false,
        allowPlatinumOverride: true
    )
}

// MARK: - CI/CD Gate Result

/// Result of CI/CD gate check.
public struct CICDGateResult: Sendable, Codable {
    public let passed: Bool
    public let blockingReasons: [String]
    public let warnings: [String]
    public let statistics: [String: String]
    public let violations: [DoctrineViolation]
    public let securityScore: Double
    public let doctrineScore: Double

    public init(
        passed: Bool,
        blockingReasons: [String] = [],
        warnings: [String] = [],
        statistics: [String: String] = [:],
        violations: [DoctrineViolation] = [],
        securityScore: Double = 100.0,
        doctrineScore: Double = 100.0
    ) {
        self.passed = passed
        self.blockingReasons = blockingReasons
        self.warnings = warnings
        self.statistics = statistics
        self.violations = violations
        self.securityScore = securityScore
        self.doctrineScore = doctrineScore
    }

    /// Create a failing result with reasons.
    public static func failed(reasons: [String], violations: [DoctrineViolation] = []) -> CICDGateResult {
        return CICDGateResult(
            passed: false,
            blockingReasons: reasons,
            violations: violations
        )
    }

    /// Create a passing result.
    public static func passed(warnings: [String] = []) -> CICDGateResult {
        return CICDGateResult(
            passed: true,
            warnings: warnings
        )
    }
}

// MARK: - CI/CD Gate

/// CI/CD gate that blocks merges/releases based on doctrine health.
public actor CICDGate {
    private let config: CICDGateConfig
    private let doctrineService: DoctrineDebtTaskService
    private let trustTier: TrustTier

    public init(
        config: CICDGateConfig = .production,
        doctrineService: DoctrineDebtTaskService,
        trustTier: TrustTier = .bronze  // Default to most restrictive
    ) {
        self.config = config
        self.doctrineService = doctrineService
        self.trustTier = trustTier
    }

    /// Check if current state passes CI/CD gates.
    public func check() async throws -> CICDGateResult {
        // Get all violations
        let violations = try await doctrineService.getUnresolvedViolations()

        // Calculate scores
        let securityScore = try await doctrineService.getSecurityHealthScore()
        let doctrineScore = try await calculateDoctrineHealthScore()

        // Check for blocking violations
        var blockingReasons: [String] = []
        var warnings: [String] = []

        // Check security score
        if securityScore < config.minimumSecurityScore {
            let reason = "Security health score \(String(format: "%.1f", securityScore)) below minimum \(config.minimumSecurityScore)"
            if config.blockOnSecurityViolation {
                blockingReasons.append(reason)
            } else {
                warnings.append(reason)
            }
        }

        // Check doctrine score
        if doctrineScore < config.minimumDoctrineScore {
            let reason = "Doctrine health score \(String(format: "%.1f", doctrineScore)) below minimum \(config.minimumDoctrineScore)"
            blockingReasons.append(reason)
        }

        // Check for critical violations
        let criticalViolations = violations.filter { $0.severity == .critical }
        if !criticalViolations.isEmpty && config.blockOnCritical {
            let criticalCount = criticalViolations.count
            blockingReasons.append("\(criticalCount) critical doctrine violation(s)")

            // Add specific critical violations to result
            if config.failFast {
                return .failed(
                    reasons: blockingReasons,
                    violations: Array(criticalViolations.prefix(5))  // Limit for readability
                )
            }
        }

        // Check for specific blocking violations
        let blockingRuleViolations = violations.filter { config.blockingViolations.contains($0.ruleId) }
        if !blockingRuleViolations.isEmpty {
            let blockingRules = Set(blockingRuleViolations.map { $0.ruleId })
            blockingReasons.append("Blocking violations: \(blockingRules.joined(separator: ", "))")

            if config.failFast {
                return .failed(
                    reasons: blockingReasons,
                    violations: Array(blockingRuleViolations.prefix(5))
                )
            }
        }

        // Check if platinum override is allowed
        if !blockingReasons.isEmpty && config.allowPlatinumOverride && trustTier == .platinum {
            warnings.append("Platinum trust tier override applied for: \(blockingReasons.joined(separator: ", "))")
            blockingReasons.removeAll()
        }

        // Gather statistics
        let statistics = try await gatherStatistics(violations: violations)

        if blockingReasons.isEmpty {
            return CICDGateResult(
                passed: true,
                warnings: warnings,
                statistics: statistics,
                violations: [],
                securityScore: securityScore,
                doctrineScore: doctrineScore
            )
        } else {
            return CICDGateResult(
                passed: false,
                blockingReasons: blockingReasons,
                warnings: warnings,
                statistics: statistics,
                violations: Array(violations.prefix(10)),  // Limit for readability
                securityScore: securityScore,
                doctrineScore: doctrineScore
            )
        }
    }

    /// Check a specific PR/commit.
    public func checkPR(
        prNumber: Int? = nil,
        commitSha: String? = nil,
        baseRef: String? = nil,
        headRef: String? = nil
    ) async throws -> CICDGateResult {
        // In a real implementation, this would:
        // 1. Check out the PR/commit
        // 2. Run doctrine scans on changed files
        // 3. Compare with base
        // 4. Return result

        // For now, just run the standard check
        return try await check()
    }

    /// Create GitHub status check.
    public func createGitHubStatusCheck(
        result: CICDGateResult,
        context: String = "doctrine/security",
        description: String? = nil,
        targetURL: String? = nil
    ) async throws -> GitHubStatusCheck {
        let state: GitHubStatusState = result.passed ? .success : .failure

        let defaultDescription: String
        if result.passed {
            defaultDescription = "Doctrine checks passed: Security \(String(format: "%.1f", result.securityScore))/100, Overall \(String(format: "%.1f", result.doctrineScore))/100"
        } else {
            defaultDescription = "Doctrine checks failed: \(result.blockingReasons.joined(separator: "; "))"
        }

        return GitHubStatusCheck(
            state: state,
            context: context,
            description: description ?? defaultDescription,
            targetURL: targetURL
        )
    }

    /// Create PR comment with violations.
    public func createPRComment(result: CICDGateResult) -> String {
        var comment = "## Doctrine Security Check\n\n"

        if result.passed {
            comment += "✅ **All checks passed!**\n\n"
            comment += "**Scores:**\n"
            comment += "- Security: \(String(format: "%.1f", result.securityScore))/100\n"
            comment += "- Overall: \(String(format: "%.1f", result.doctrineScore))/100\n\n"

            if !result.warnings.isEmpty {
                comment += "**Warnings:**\n"
                for warning in result.warnings {
                    comment += "- ⚠️ \(warning)\n"
                }
                comment += "\n"
            }
        } else {
            comment += "❌ **Checks failed**\n\n"
            comment += "**Blocking reasons:**\n"
            for reason in result.blockingReasons {
                comment += "- 🚫 \(reason)\n"
            }
            comment += "\n"

            comment += "**Scores:**\n"
            comment += "- Security: \(String(format: "%.1f", result.securityScore))/100 (minimum: \(config.minimumSecurityScore))\n"
            comment += "- Overall: \(String(format: "%.1f", result.doctrineScore))/100 (minimum: \(config.minimumDoctrineScore))\n\n"

            if !result.violations.isEmpty {
                comment += "**Top violations:**\n"
                for violation in result.violations.prefix(5) {
                    comment += "### \(violation.ruleId)\n"
                    comment += "- **File:** `\(violation.filePath)`\n"
                    comment += "- **Line:** \(violation.lineNumber)\n"
                    comment += "- **Context:** \(violation.context)\n"
                    if let suggestion = violation.metadata["suggestion"] as? String {
                        comment += "- **Suggestion:** \(suggestion)\n"
                    }
                    comment += "\n"
                }

                if result.violations.count > 5 {
                    comment += "... and \(result.violations.count - 5) more violations\n\n"
                }
            }

            if config.allowPlatinumOverride && trustTier < .platinum {
                comment += "**Note:** Platinum trust tier can override these checks.\n\n"
            }
        }

        comment += "---\n"
        comment += "*Powered by Anigma Doctrine Engine*"

        return comment
    }

    // MARK: - Private Methods

    private func calculateDoctrineHealthScore() async throws -> Double {
        let violations = try await doctrineService.getUnresolvedViolations()

        if violations.isEmpty {
            return 100.0
        }

        var score = 100.0

        for violation in violations {
            let weight: Double
            switch violation.severity {
            case .critical:
                weight = 10.0
            case .error:
                weight = 5.0
            case .warning:
                weight = 2.0
            case .info:
                weight = 1.0
            }

            // Extra weight for security violations
            if violation.ruleId.hasPrefix("sec-") {
                score -= weight * 1.5
            } else {
                score -= weight
            }
        }

        return max(0.0, score)
    }

    private func gatherStatistics(violations: [DoctrineViolation]) async throws -> [String: Any] {
        var stats: [String: Any] = [:]

        // Count by domain
        var domainStats: [String: Int] = [:]
        var severityStats: [String: Int] = [
            "critical": 0,
            "error": 0,
            "warning": 0,
            "info": 0
        ]

        // Group by rule
        var ruleStats: [String: Int] = [:]

        for violation in violations {
            // Determine domain from rule ID
            let domain: String
            if violation.ruleId.hasPrefix("sec-") {
                domain = "security"
            } else if violation.ruleId.hasPrefix("cs-") {
                domain = "computer_science"
            } else if violation.ruleId.hasPrefix("stat-") {
                domain = "statistics"
            } else if violation.ruleId.hasPrefix("law-") {
                domain = "law_compliance"
            } else {
                domain = "unknown"
            }

            domainStats[domain, default: 0] += 1

            // Count by severity
            switch violation.severity {
            case .critical:
                severityStats["critical"]! += 1
            case .error:
                severityStats["error"]! += 1
            case .warning:
                severityStats["warning"]! += 1
            case .info:
                severityStats["info"]! += 1
            }

            // Count by rule
            ruleStats[violation.ruleId, default: 0] += 1
        }

        stats["total_violations"] = violations.count
        stats["by_domain"] = domainStats
        stats["by_severity"] = severityStats
        stats["by_rule"] = ruleStats

        // Add security-specific stats if available
        if let securityStats = try? await doctrineService.getSecurityStatistics() {
            stats["security"] = securityStats
        }

        return stats
    }
}

// MARK: - GitHub Integration

/// GitHub status check.
public struct GitHubStatusCheck: Sendable, Codable {
    public let state: GitHubStatusState
    public let context: String
    public let description: String
    public let targetURL: String?

    public init(
        state: GitHubStatusState,
        context: String,
        description: String,
        targetURL: String? = nil
    ) {
        self.state = state
        self.context = context
        self.description = description
        self.targetURL = targetURL
    }
}

/// GitHub status state.
public enum GitHubStatusState: String, Sendable, Codable {
    case error
    case failure
    case pending
    case success
}

/// GitHub API client for CI/CD integration.
public actor GitHubCICDClient {
    private let token: String
    private let baseURL: String
    private let repoOwner: String
    private let repoName: String

    public init(
        token: String,
        repoOwner: String,
        repoName: String,
        baseURL: String = "https://api.github.com"
    ) {
        self.token = token
        self.repoOwner = repoOwner
        self.repoName = repoName
        self.baseURL = baseURL
    }

    /// Create a status check.
    public func createStatusCheck(
        sha: String,
        statusCheck: GitHubStatusCheck
    ) async throws {
        // In a real implementation, this would make HTTP request to GitHub API
        // For now, just log
        print("GitHub Status Check for \(sha):")
        print("  Context: \(statusCheck.context)")
        print("  State: \(statusCheck.state.rawValue)")
        print("  Description: \(statusCheck.description)")
        if let url = statusCheck.targetURL {
            print("  Target URL: \(url)")
        }
    }

    /// Create a PR comment.
    public func createPRComment(
        prNumber: Int,
        comment: String
    ) async throws {
        // In a real implementation, this would make HTTP request to GitHub API
        print("GitHub PR Comment for #\(prNumber):")
        print(comment)
    }

    /// Get changed files in a PR.
    public func getPRFiles(prNumber: Int) async throws -> [String] {
        // In a real implementation, this would fetch from GitHub API
        // For now, return empty array
        return []
    }
}

// MARK: - GitLab Integration

/// GitLab API client for CI/CD integration.
public actor GitLabCICDClient {
    private let token: String
    private let baseURL: String
    private let projectId: String

    public init(
        token: String,
        projectId: String,
        baseURL: String = "https://gitlab.com/api/v4"
    ) {
        self.token = token
        self.projectId = projectId
        self.baseURL = baseURL
    }

    /// Create a pipeline status.
    public func createPipelineStatus(
        sha: String,
        status: String,
        context: String,
        description: String
    ) async throws {
        // In a real implementation, this would make HTTP request to GitLab API
        print("GitLab Pipeline Status for \(sha):")
        print("  Context: \(context)")
        print("  Status: \(status)")
        print("  Description: \(description)")
    }
}

// MARK: - CI/CD Runner

/// Runs CI/CD checks and integrates with CI systems.
public actor CICDRunner {
    private let gate: CICDGate
    private let githubClient: GitHubCICDClient?
    private let gitlabClient: GitLabCICDClient?

    public init(
        gate: CICDGate,
        githubClient: GitHubCICDClient? = nil,
        gitlabClient: GitLabCICDClient? = nil
    ) {
        self.gate = gate
        self.githubClient = githubClient
        self.gitlabClient = gitlabClient
    }

    /// Run CI/CD checks for current state.
    public func runChecks() async throws -> CICDGateResult {
        let result = try await gate.check()

        // Integrate with CI systems if configured
        if let githubClient = githubClient {
            // Get commit SHA from environment or git
            let sha = getCommitSHA()

            let statusCheck = try await gate.createGitHubStatusCheck(result: result)
            try await githubClient.createStatusCheck(sha: sha, statusCheck: statusCheck)

            // Get PR number from environment
            if let prNumber = getPRNumber() {
                let comment = gate.createPRComment(result: result)
                try await githubClient.createPRComment(prNumber: prNumber, comment: comment)
            }
        }

        if let gitlabClient = gitlabClient {
            let sha = getCommitSHA()
            let status = result.passed ? "success" : "failed"
            try await gitlabClient.createPipelineStatus(
                sha: sha,
                status: status,
                context: "doctrine/security",
                description: result.passed ? "Doctrine checks passed" : "Doctrine checks failed"
            )
        }

        return result
    }

    /// Run CI/CD checks for a PR.
    public func runPRChecks(prNumber: Int) async throws -> CICDGateResult {
        let result = try await gate.checkPR(prNumber: prNumber)

        if let githubClient = githubClient {
            let sha = getCommitSHA()
            let statusCheck = try await gate.createGitHubStatusCheck(result: result)
            try await githubClient.createStatusCheck(sha: sha, statusCheck: statusCheck)

            let comment = gate.createPRComment(result: result)
            try await githubClient.createPRComment(prNumber: prNumber, comment: comment)
        }

        return result
    }

    // MARK: - Private Methods

    private func getCommitSHA() -> String {
        // Try to get from environment variables first
        if let sha = ProcessInfo.processInfo.environment["GITHUB_SHA"] {
            return sha
        }
        if let sha = ProcessInfo.processInfo.environment["CI_COMMIT_SHA"] {
            return sha
        }

        // Fall back to git command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
            return String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        } catch {
            return "unknown"
        }
    }

    private func getPRNumber() -> Int? {
        // Try to get from environment variables
        if let prNumberStr = ProcessInfo.processInfo.environment["GITHUB_PR_NUMBER"] {
            return Int(prNumberStr)
        }
        if let prNumberStr = ProcessInfo.processInfo.environment["CI_MERGE_REQUEST_IID"] {
            return Int(prNumberStr)
        }

        return nil
    }
}

// MARK: - GitHub Actions Workflow Example

/*
 Example GitHub Actions workflow:

 name: Doctrine Security Gates
 on:
   pull_request:
     branches: [ main ]
   push:
     branches: [ main ]

 jobs:
   doctrine-check:
     runs-on: macos-latest
     
     steps:
     - uses: actions/checkout@v4
     
     - name: Setup Swift
       uses: swift-actions/setup-swift@v2
       with:
         swift-version: '5.9'
     
     - name: Run Doctrine Checks
       run: |
         swift run harmonia-cli doctrine-check --ci-gate --minimum-security-score 80
       
     - name: Upload Violations Report
       if: failure()
       uses: actions/upload-artifact@v4
       with:
         name: doctrine-violations
         path: doctrine-report.json
*/

// MARK: - GitLab CI Example

/*
 Example GitLab CI configuration:

 doctrine_check:
   stage: test
   script:
     - swift run harmonia-cli doctrine-check --ci-gate --minimum-security-score 80
   artifacts:
     when: on_failure
     paths:
       - doctrine-report.json
*/

// MARK: - Command Line Interface

extension CICDGate {
    /// Run CI/CD gate from command line.
    public static func runFromCLI(config: CICDGateConfig = .production) async throws {
        // Initialize services
        let doctrineService = DoctrineDebtTaskService()  // Would need proper initialization
        let gate = CICDGate(config: config, doctrineService: doctrineService)

        let result = try await gate.check()

        // Print results
        if result.passed {
            print("✅ CI/CD gates passed")
            print("Security score: \(String(format: "%.1f", result.securityScore))/100")
            print("Doctrine score: \(String(format: "%.1f", result.doctrineScore))/100")

            if !result.warnings.isEmpty {
                print("\n⚠️  Warnings:")
                for warning in result.warnings {
                    print("  - \(warning)")
                }
            }
        } else {
            print("❌ CI/CD gates failed")
            print("\nBlocking reasons:")
            for reason in result.blockingReasons {
                print("  - 🚫 \(reason)")
            }

            print("\nScores:")
            print("  - Security: \(String(format: "%.1f", result.securityScore))/100 (minimum: \(config.minimumSecurityScore))")
            print("  - Overall: \(String(format: "%.1f", result.doctrineScore))/100 (minimum: \(config.minimumDoctrineScore))")

            if !result.violations.isEmpty {
                print("\nTop violations:")
                for violation in result.violations.prefix(5) {
                    print("\n  \(violation.ruleId)")
                    print("    File: \(violation.filePath)")
                    print("    Line: \(violation.lineNumber)")
                    print("    Context: \(violation.context)")
                }
            }

            // Exit with error code
            exit(1)
        }
    }
}
