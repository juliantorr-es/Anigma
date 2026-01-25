//
//  ProjectCodingAgentSystem.swift
//  HarmoniaModule
//
//  System that implements a coding agent for working on project features.
//  Uses existing tool runtime to edit code, run tests, and make progress.
//

import AnigmaCore
import AnigmaPrimitives
@preconcurrency import Foundation

// MARK: - Project Coding Agent System

/// System that implements a coding agent for working on project features.
public struct ProjectCodingAgentSystem: System {
    public let name = "ProjectCodingAgent"

    /// Project execution surface - workers talk to this, not to GRDB directly.
    private let project: ProjectExecutionSurface

    /// Tool registry for tool execution.
    private let toolRegistry: SimpleToolRegistry

    /// Sandbox configuration for safe tool execution.
    private let sandboxConfig: CodingSandboxConfig

    public init(
        project: ProjectExecutionSurface,
        toolRegistry: SimpleToolRegistry = SimpleToolRegistry(),
        sandboxConfig: CodingSandboxConfig = .default
    ) {
        self.project = project
        self.toolRegistry = toolRegistry
        self.sandboxConfig = sandboxConfig
    }

    public func update(world: World) async {
        await Logger.shared.info(
            "ProjectCodingAgentSystem: Checking project status",
            category: "Harness"
        )

        do {
            let governance = try await project.getGovernanceStatus()
            guard !governance.isQuarantined else {
                await Logger.shared.warning(
                    "ProjectCodingAgentSystem: Project quarantined (\(governance.quarantineStatus?.reason ?? "unknown reason"))",
                    category: "Harness"
                )
                return
            }

            let service = ProjectCodingAgentService(
                project: project,
                toolRegistry: toolRegistry,
                sandboxConfig: sandboxConfig
            )
            _ = try await service.runCodingSession(
                featureCategory: "core",
                trustTier: .trusted,
                maxIterations: 1
            )
        } catch {
            await Logger.shared.error(
                "ProjectCodingAgentSystem failed: \(error.localizedDescription)",
                category: "Harness"
            )
        }
    }
}

// MARK: - Coding Agent Service

/// Service for coding agent logic.
public actor ProjectCodingAgentService {
    private let project: ProjectExecutionSurface
    private let toolRegistry: SimpleToolRegistry
    private let sandboxConfig: CodingSandboxConfig
    private let epilogueRunner: SessionEpilogueRunner
    private let rudeNotifier: RudeCLINotifier

    public init(
        project: ProjectExecutionSurface,
        toolRegistry: SimpleToolRegistry = SimpleToolRegistry(),
        sandboxConfig: CodingSandboxConfig = .default,
        epilogueRunner: SessionEpilogueRunner = SessionEpilogueRunner(),
        rudeNotifier: RudeCLINotifier = RudeCLINotifier()
    ) {
        self.project = project
        self.toolRegistry = toolRegistry
        self.sandboxConfig = sandboxConfig
        self.epilogueRunner = epilogueRunner
        self.rudeNotifier = rudeNotifier
    }

    /// Runs a coding session for a project.
    public func runCodingSession(
        featureCategory: String,
        trustTier: AnigmaPrimitives.TrustTier = .silver,
        maxIterations: Int = 1
    ) async throws -> CodingSessionResult {
        // Note: Project status validation is handled by the governance stack
        // when we call project.runSession() below

        var sessionResult = CodingSessionResult(
            projectId: project.projectId,
            sessionIndex: 0,  // Will be set by principality
            featuresWorkedOn: [],
            featuresCompleted: 0,
            testsPassed: 0,
            testsFailed: 0,
            summary: "Coding session started"
        )

        // Run iterations
        for iteration in 1...maxIterations {
            await Logger.shared.info(
                "Starting iteration \(iteration)/\(maxIterations) for project", category: "Harness")

            let iterationResult = try await runCodingIteration(
                featureCategory: featureCategory,
                trustTier: trustTier,
                iteration: iteration
            )

            // Update session result
            sessionResult.featuresWorkedOn.append(contentsOf: iterationResult.featuresWorkedOn)
            sessionResult.featuresCompleted += iterationResult.featuresCompleted
            sessionResult.testsPassed += iterationResult.testsPassed
            sessionResult.testsFailed += iterationResult.testsFailed
            sessionResult.summary = iterationResult.summary

            // Short delay between iterations (if not last iteration)
            if iteration < maxIterations {
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            }
        }

        return sessionResult
    }

    // MARK: - Private Methods

    /// Runs a single coding iteration.
    private func runCodingIteration(
        featureCategory: String,
        trustTier: TrustTier,
        iteration: Int
    ) async throws -> CodingIterationResult {
        // Step 1: Run session through principality (goes through governance stack)
        let sessionReport = try await project.runSession(
            featureCategory: featureCategory,
            explicitConfigId: nil,
            trustTier: trustTier,
            intent: nil
        )

        // Step 2: Build context from session report
        let context = try await buildCodingContext(
            sessionReport: sessionReport,
            iteration: iteration
        )

        // Step 3: Execute coding tools
        let toolResults = try await executeCodingTools(
            context: context,
            sandboxConfig: sandboxConfig
        )

        // Step 4: Run tests
        let testResults = try await runTests(
            context: context
        )

        // Step 5: Generate summary
        let summary = generateIterationSummary(
            sessionReport: sessionReport,
            toolResults: toolResults,
            testResults: testResults,
            iteration: iteration
        )

        // Note: Feature status updates are handled by the principality/governance stack
        // We don't update features directly here

        return CodingIterationResult(
            feature: FeatureTestCase(
                id: UUID(),
                projectId: project.projectId,
                name: featureCategory,
                category: featureCategory,
                description: "Coding iteration for \(featureCategory)",
                validationSteps: [],
                status: testResults.allPassed ? .passing : .failing,
                createdAt: Date(),
                updatedAt: Date(),
                lastError: testResults.allPassed ? nil : testResults.output,
                priority: 50
            ),
            featuresWorkedOn: [],  // Features are managed by principality
            featuresCompleted: testResults.allPassed ? 1 : 0,
            testsPassed: testResults.passedCount,
            testsFailed: testResults.failedCount,
            gitCommitHash: toolResults.gitCommitHash,
            summary: summary
        )
    }

    /// Builds coding context for the LLM.
    private func buildCodingContext(
        sessionReport: SessionReport,
        iteration: Int
    ) async throws -> CodingContext {
        // Get recent sessions for context
        _ = try await project.listRecentSessions(limit: 3)

        // Get project status summary
        let statusSummary = try await project.getStatus()

        // Create a stub project spec for context
        let projectSpec = ProjectSpec(
            id: project.projectId,
            name: statusSummary.name,
            specText: "Coding project",
            status: .inProgress,  // Default status for coding context
            createdAt: Date(),
            updatedAt: Date()
        )

        // Create a stub feature for context
        let feature = FeatureTestCase(
            id: UUID(),
            projectId: project.projectId,
            name: sessionReport.featureCategory ?? "unknown",
            category: sessionReport.featureCategory ?? "unknown",
            description: "Coding iteration \(iteration)",
            validationSteps: ["Run tests", "Check code quality"],
            status: .pending,
            createdAt: Date(),
            updatedAt: Date(),
            lastError: nil,
            priority: 50
        )

        let gitDiff = try await getGitDiff(projectSpec: projectSpec)
        let recentChanges = try await getRecentCodeChanges(projectSpec: projectSpec)

        return CodingContext(
            projectSpec: projectSpec,
            feature: feature,
            sessionIndex: sessionReport.sessionIndex,
            iteration: iteration,
            recentSnapshots: [],  // Snapshots are managed by principality
            gitDiff: gitDiff,
            recentChanges: recentChanges,
            sandboxConfig: sandboxConfig
        )
    }

    /// Executes coding tools via the tool registry.
    private func executeCodingTools(
        context: CodingContext,
        sandboxConfig: CodingSandboxConfig
    ) async throws -> ToolExecutionResults {
        await Logger.shared.info(
            "Executing coding tools for feature: \(context.feature.name)",
            category: "Harness"
        )

        var toolsExecuted: [String] = []
        var outputs: [String] = []
        var success = true

        if let response = try? await executeTool(
            name: "run_shell",
            arguments: ["command": "echo \"Harness coding step: \(context.feature.name)\""],
            sessionId: context.sessionIndex
        ) {
            toolsExecuted.append("run_shell")
            outputs.append(response.output)
            success = success && response.success
        }

        if let response = try? await executeTool(
            name: "git",
            arguments: ["action": "status"],
            sessionId: context.sessionIndex
        ) {
            toolsExecuted.append("git")
            outputs.append(response.output)
            success = success && response.success
        }

        return ToolExecutionResults(
            toolsExecuted: toolsExecuted,
            success: success,
            output: outputs.joined(separator: "\n"),
            gitCommitHash: nil
        )
    }

    /// Runs tests for the feature.
    private func runTests(
        context: CodingContext
    ) async throws -> TestResults {
        await Logger.shared.info(
            "Running tests for feature: \(context.feature.name)",
            category: "Harness"
        )

        let started = Date()
        if let response = try? await executeTool(
            name: "run_tests",
            arguments: [:],
            sessionId: context.sessionIndex
        ) {
            let allPassed = response.success
            return TestResults(
                allPassed: allPassed,
                passedCount: allPassed ? 1 : 0,
                failedCount: allPassed ? 0 : 1,
                output: response.output,
                duration: Date().timeIntervalSince(started)
            )
        }

        return TestResults(
            allPassed: false,
            passedCount: 0,
            failedCount: 1,
            output: "Test tool unavailable",
            duration: Date().timeIntervalSince(started)
        )
    }

    /// Generates iteration summary.
    private func generateIterationSummary(
        sessionReport: SessionReport,
        toolResults: ToolExecutionResults,
        testResults: TestResults,
        iteration: Int
    ) -> String {
        let statusEmoji = testResults.allPassed ? "✅" : "❌"
        return """
            Iteration \(iteration): Worked on '\(sessionReport.featureCategory ?? "unknown")' \(statusEmoji)
            Session index: \(sessionReport.sessionIndex)
            Tools executed: \(toolResults.toolsExecuted.joined(separator: ", "))
            Tests: \(testResults.passedCount) passed, \(testResults.failedCount) failed
            """
    }

    /// Gets git diff for the project.
    private func getGitDiff(projectSpec: ProjectSpec) async throws -> String? {
        if let response = try? await executeTool(
            name: "git",
            arguments: ["action": "diff"],
            sessionId: 0
        ) {
            return response.output
        }
        if let response = try? await executeTool(
            name: "run_shell",
            arguments: ["command": "git diff --stat"],
            sessionId: 0
        ) {
            return response.output
        }
        return nil
    }

    /// Gets recent code changes.
    private func getRecentCodeChanges(projectSpec: ProjectSpec) async throws -> [String] {
        if let response = try? await executeTool(
            name: "git",
            arguments: ["action": "status"],
            sessionId: 0
        ) {
            return parseChangedFiles(from: response.output)
        }
        return []
    }

    /// Runs session epilogue - automatic behavioral analysis.
    private func runSessionEpilogue(
        projectId: UUID,
        sessionIndex: Int,
        sessionResult: CodingSessionResult
    ) async throws {
        // Get the feature worked on in this session
        let featureId = sessionResult.featuresWorkedOn.first?.id

        // Create epilogue context
        let context = SessionEpilogueContext(
            projectId: projectId,
            sessionIndex: sessionIndex,
            featureId: featureId,
            sessionResult: sessionResult
        )

        // Run epilogue
        let healthSummary = try await epilogueRunner.runEpilogue(context)

        // Run rude notifier
        try await rudeNotifier.handlePostSession(
            projectId: projectId,
            sessionIndex: sessionIndex,
            summary: healthSummary
        )

        await Logger.shared.info(
            "Session epilogue completed for session \(sessionIndex). Health score: \(String(format: "%.0f%%", healthSummary.healthScore * 100))",
            category: "Harness"
        )
    }

    private func executeTool(
        name: String,
        arguments: [String: String],
        sessionId: Int
    ) async throws -> ToolResponse {
        let request = ToolRequest(
            name: name,
            arguments: arguments,
            sessionId: "session-\(sessionId)",
            projectId: project.projectId.uuidString
        )
        return try await toolRegistry.execute(request: request)
    }

    private func parseChangedFiles(from output: String) -> [String] {
        let lines = output.split(separator: "\n").map(String.init)
        var files: [String] = []
        for line in lines {
            if line.contains("no changes") || line.contains("clean") {
                continue
            }
            if let range = line.range(of: ":") {
                let candidate = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty {
                    files.append(candidate)
                }
            }
        }
        return files
    }
}

// MARK: - Helper Types

/// Configuration for the coding sandbox.
public struct CodingSandboxConfig: Sendable {
    /// Allowed file paths for writing (empty = project directory only).
    public var allowedWritePaths: [String]

    /// Allowed shell commands.
    public var allowedCommands: [String]

    /// Maximum execution time per tool (seconds).
    public var maxExecutionTime: TimeInterval

    /// Whether to allow network access.
    public var allowNetworkAccess: Bool

    /// Whether to allow file system writes.
    public var allowFileWrites: Bool

    public init(
        allowedWritePaths: [String] = [],
        allowedCommands: [String] = ["git", "swift", "npm", "yarn", "cargo", "python", "python3"],
        maxExecutionTime: TimeInterval = 30.0,
        allowNetworkAccess: Bool = false,
        allowFileWrites: Bool = true
    ) {
        self.allowedWritePaths = allowedWritePaths
        self.allowedCommands = allowedCommands
        self.maxExecutionTime = maxExecutionTime
        self.allowNetworkAccess = allowNetworkAccess
        self.allowFileWrites = allowFileWrites
    }

    public static let `default` = CodingSandboxConfig()

    /// Strict sandbox for untrusted code.
    public static let strict = CodingSandboxConfig(
        allowedWritePaths: [],
        allowedCommands: ["git", "swift"],
        maxExecutionTime: 10.0,
        allowNetworkAccess: false,
        allowFileWrites: false
    )
}

/// Context for coding agent.
public struct CodingContext: Sendable {
    public let projectSpec: ProjectSpec
    public let feature: FeatureTestCase
    public let sessionIndex: Int
    public let iteration: Int
    public let recentSnapshots: [ProjectProgressSnapshot]
    public let gitDiff: String?
    public let recentChanges: [String]
    public let sandboxConfig: CodingSandboxConfig

    /// Builds a prompt for the LLM.
    public func buildPrompt() -> String {
        return """
            Project: \(projectSpec.name)
            Feature: \(feature.name)
            Description: \(feature.description)

            Validation Steps:
            \(feature.validationSteps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

            Recent Progress:
            \(recentSnapshots.map { "- Session \($0.sessionIndex): \($0.summary)" }.joined(separator: "\n"))

            Constraints:
            - Only edit files in project directory
            - Allowed commands: \(sandboxConfig.allowedCommands.joined(separator: ", "))
            - No network access unless explicitly allowed

            Task: Implement or fix the '\(feature.name)' feature.
            """
    }
}

/// Results of tool execution.
public struct ToolExecutionResults: Sendable {
    public let toolsExecuted: [String]
    public let success: Bool
    public let output: String
    public let gitCommitHash: String?

    public init(
        toolsExecuted: [String],
        success: Bool,
        output: String,
        gitCommitHash: String? = nil
    ) {
        self.toolsExecuted = toolsExecuted
        self.success = success
        self.output = output
        self.gitCommitHash = gitCommitHash
    }
}

/// Results of test execution.
public struct TestResults: Sendable {
    public let allPassed: Bool
    public let passedCount: Int
    public let failedCount: Int
    public let output: String
    public let duration: TimeInterval

    public init(
        allPassed: Bool,
        passedCount: Int,
        failedCount: Int,
        output: String,
        duration: TimeInterval
    ) {
        self.allPassed = allPassed
        self.passedCount = passedCount
        self.failedCount = failedCount
        self.output = output
        self.duration = duration
    }
}

/// Result of a coding iteration.
public struct CodingIterationResult: Sendable {
    public let feature: FeatureTestCase
    public let featuresWorkedOn: [FeatureTestCase]
    public let featuresCompleted: Int
    public let testsPassed: Int
    public let testsFailed: Int
    public let gitCommitHash: String?
    public let summary: String

    public init(
        feature: FeatureTestCase,
        featuresWorkedOn: [FeatureTestCase],
        featuresCompleted: Int,
        testsPassed: Int,
        testsFailed: Int,
        gitCommitHash: String? = nil,
        summary: String
    ) {
        self.feature = feature
        self.featuresWorkedOn = featuresWorkedOn
        self.featuresCompleted = featuresCompleted
        self.testsPassed = testsPassed
        self.testsFailed = testsFailed
        self.gitCommitHash = gitCommitHash
        self.summary = summary
    }
}

/// Result of a coding session.
public struct CodingSessionResult: Sendable {
    public let projectId: UUID
    public let sessionIndex: Int
    public var featuresWorkedOn: [FeatureTestCase]
    public var featuresCompleted: Int
    public var testsPassed: Int
    public var testsFailed: Int
    public var summary: String

    public init(
        projectId: UUID,
        sessionIndex: Int,
        featuresWorkedOn: [FeatureTestCase],
        featuresCompleted: Int,
        testsPassed: Int,
        testsFailed: Int,
        summary: String
    ) {
        self.projectId = projectId
        self.sessionIndex = sessionIndex
        self.featuresWorkedOn = featuresWorkedOn
        self.featuresCompleted = featuresCompleted
        self.testsPassed = testsPassed
        self.testsFailed = testsFailed
        self.summary = summary
    }
}
