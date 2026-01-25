//
//  PrincipalityProjectController+Scouts.swift
//  HarmoniaModule
//
//  Scout and migration task extensions for PrincipalityProjectController.
//

@preconcurrency import Foundation
import AnigmaPrimitives

// MARK: - Scout and Task Management

extension PrincipalityProjectController {
    /// The scout orchestrator for this project.
    private var scoutOrchestrator: ScoutOrchestrator {
        ScoutOrchestrator(store: ProjectHarnessStore.shared)
    }

    /// Runs a Swift 6 diagnostic scout for the project.
    /// - Returns: Summary of the scout run.
    public func runSwift6Scout() async throws -> ScoutRunSummary {
        // Register the Swift 6 scout
        let swift6Scout = Swift6DiagnosticScout.selfHostScout()
        await scoutOrchestrator.register(scout: swift6Scout, name: "swift6")

        // Run the scout
        return try await scoutOrchestrator.runScout("swift6", for: projectId, createTasks: true)
    }

    /// Lists pending migration tasks for the project.
    /// - Parameters:
    ///   - featureCategory: Optional feature category filter.
    ///   - limit: Maximum number of tasks to return.
    /// - Returns: Array of pending migration tasks.
    public func listPendingMigrationTasks(
        featureCategory: String? = nil,
        limit: Int = 10
    ) async throws -> [MigrationTask] {
        return try await scoutOrchestrator.nextPendingTasks(
            projectId: projectId,
            featureCategory: featureCategory,
            limit: limit
        )
    }

    /// Lists all migration tasks for the project.
    /// - Parameters:
    ///   - featureCategory: Optional feature category filter.
    ///   - status: Optional status filter.
    ///   - limit: Maximum number of tasks to return.
    /// - Returns: Array of migration tasks.
    public func listMigrationTasks(
        featureCategory: String? = nil,
        status: MigrationTaskStatus? = nil,
        limit: Int = 100
    ) async throws -> [MigrationTask] {
        return try await scoutOrchestrator.getTasks(
            projectId: projectId,
            featureCategory: featureCategory,
            status: status,
            limit: limit
        )
    }

    /// Lists scout findings for the project.
    /// - Parameters:
    ///   - problemKind: Optional problem kind filter.
    ///   - severity: Optional severity filter.
    ///   - limit: Maximum number of findings to return.
    /// - Returns: Array of scout findings.
    public func listScoutFindings(
        problemKind: String? = nil,
        severity: ScoutFindingSeverity? = nil,
        limit: Int = 100
    ) async throws -> [ScoutFinding] {
        return try await scoutOrchestrator.getFindings(
            projectId: projectId,
            problemKind: problemKind,
            severity: severity,
            limit: limit
        )
    }

    /// Runs the next pending migration task.
    /// - Parameters:
    ///   - featureCategory: Optional feature category filter.
    ///   - trustTier: Trust tier for the session.
    ///   - sessionLane: Session lane for the session.
    /// - Returns: Session report from the task execution.
    public func runNextMigrationTask(
        featureCategory: String? = nil,
        trustTier: TrustTier = .platinum,
        sessionLane: SessionLane = .normal
    ) async throws -> SessionReport {
        // Get the next pending task
        let tasks = try await scoutOrchestrator.nextPendingTasks(
            projectId: projectId,
            featureCategory: featureCategory,
            limit: 1
        )

        guard let task = tasks.first else {
            throw ScoutError.noPendingTasks
        }

        // Run the task
        return try await runMigrationTask(task, trustTier: trustTier, sessionLane: sessionLane)
    }

    /// Runs a specific migration task.
    /// - Parameters:
    ///   - task: The migration task to run.
    ///   - trustTier: Trust tier for the session.
    ///   - sessionLane: Session lane for the session.
    /// - Returns: Session report from the task execution.
    public func runMigrationTask(
        _ task: MigrationTask,
        trustTier: TrustTier = .platinum,
        sessionLane: SessionLane = .normal
    ) async throws -> SessionReport {
        // Mark task as active
        try await scoutOrchestrator.markTaskActive(task.id)

        // Get the project spec
        _ = try await requireProject()

        // Get the associated finding if available
        var finding: ScoutFinding?
        if let findingId = task.findingId {
            let findings = try await scoutOrchestrator.getFindings(
                projectId: projectId,
                problemKind: nil,
                severity: nil,
                limit: 1
            )
            finding = findings.first { $0.id == findingId }
        }

        // Create session intent based on the task
        let sessionIntent = try await createSessionIntent(
            for: task,
            finding: finding,
            trustTier: trustTier,
            sessionLane: sessionLane
        )

        // Run the session through the governance stack
        let sessionReport: SessionReport
        do {
            sessionReport = try await runSession(
                featureCategory: task.featureCategory,
                trustTier: trustTier,
                intent: sessionIntent
            )

            // Mark task as completed
            try await scoutOrchestrator.markTaskCompleted(
                task.id,
                sessionIndex: sessionReport.sessionIndex
            )
        } catch {
            // Mark task as failed
            try await scoutOrchestrator.markTaskFailed(
                task.id,
                sessionIndex: nil
            )
            throw error
        }

        return sessionReport
    }

    /// Runs a batch of migration tasks.
    /// - Parameters:
    ///   - tasks: The migration tasks to run.
    ///   - trustTier: Trust tier for the sessions.
    ///   - sessionLane: Session lane for the sessions.
    /// - Returns: Array of session reports from task executions.
    public func runMigrationTasks(
        _ tasks: [MigrationTask],
        trustTier: TrustTier = .platinum,
        sessionLane: SessionLane = .normal
    ) async throws -> [SessionReport] {
        var reports: [SessionReport] = []

        for task in tasks {
            let report = try await runMigrationTask(
                task,
                trustTier: trustTier,
                sessionLane: sessionLane
            )
            reports.append(report)
        }

        return reports
    }

    // MARK: - Swift 6 Migration State

    /// Loads the Swift 6 migration state for the project.
    /// - Returns: Complete migration state snapshot.
    public func loadSwift6MigrationState() async throws -> Swift6MigrationState {
        _ = try await requireProject()

        // Get all findings and tasks
        let findings: [ScoutFinding] = try await store.getScoutFindings(projectId: projectId)
        let tasks: [MigrationTask] = try await store.getMigrationTasks(projectId: projectId)

        // Get recent sessions
        let recentSessions = try await loadRecentSwift6Sessions()

        // Group findings and tasks by file
        var filesByPath: [String: [ScoutFinding]] = [:]
        var findingIdToFilePath: [UUID: String] = [:]
        for finding in findings {
            filesByPath[finding.filePath, default: []].append(finding)
            findingIdToFilePath[finding.id] = finding.filePath
        }
        var tasksByPath: [String: [MigrationTask]] = [:]
        for task in tasks {
            let path = task.findingId.flatMap { findingIdToFilePath[$0] } ?? ""
            tasksByPath[path, default: []].append(task)
        }

        // Build file summaries
        var fileSummaries: [Swift6FileSummary] = []
        var allFilePaths = Set(filesByPath.keys)
        allFilePaths.formUnion(tasksByPath.keys)

        for filePath in allFilePaths {
            let fileFindings = filesByPath[filePath] ?? []
            let fileTasks = tasksByPath[filePath] ?? []

            // Find recent sessions for this file
            let fileSessions = recentSessions.filter { session in
                // Check if session metadata contains this file path
                // This is a simplification - in reality we'd need to track file-session mapping
                session.featureCategory.contains("swift6") // Simple heuristic
            }

            let lastSession = fileSessions.sorted { $0.sessionIndex > $1.sessionIndex }.first
            let hasRecentTainted = fileSessions.contains { $0.tainted }

            let summary = Swift6FileSummary(
                path: filePath,
                findings: fileFindings,
                tasks: fileTasks,
                lastTouchedSession: lastSession?.sessionIndex,
                lastOutcome: lastSession,
                hasRecentTaintedSessions: hasRecentTainted
            )

            fileSummaries.append(summary)
        }

        // Calculate overall metrics
        let openTasks = tasks.filter { $0.status == .pending || $0.status == .active }.count
        let taintedSessions = recentSessions.filter { $0.tainted }.count
        let overallHealth = recentSessions.isEmpty ? 1.0 :
            recentSessions.map { $0.healthScore }.reduce(0, +) / Double(recentSessions.count)

        return Swift6MigrationState(
            projectId: projectId,
            totalFindings: findings.count,
            totalTasks: tasks.count,
            openTasks: openTasks,
            taintedSessions: taintedSessions,
            recentSessions: recentSessions,
            files: fileSummaries,
            overallHealthScore: overallHealth
        )
    }

    /// Runs a single Swift 6 migration step.
    /// - Parameters:
    ///   - engine: Step engine to use (defaults to basic engine).
    ///   - policy: Migration policy (defaults to default policy).
    /// - Returns: Tuple of chosen intent and optional session report.
    public func runSwift6Step(
        engine: any Swift6StepEngine = BasicSwift6StepEngine(),
        policy: Swift6MigrationPolicy = .default
    ) async throws -> (Swift6StepIntent, SessionReport?) {
        _ = try await requireProject()

        // Load current state
        let state = try await loadSwift6MigrationState()

        // Choose next step
        let intent = engine.chooseNextStep(from: state, policy: policy)

        // Execute the intent
        switch intent {
        case .runTask(let taskId):
            guard let task = try await store.getMigrationTask(taskId) else {
                throw HarnessError.invalidProjectState("Migration task not found: \(taskId)")
            }
            let report = try await runMigrationTask(task)
            return (intent, report)

        case .rescoutFile:
            // For now, run full scout - could be optimized to scout just one file
            _ = try await runSwift6Scout()
            return (intent, nil)

        case .pause:
            return (intent, nil)
        }
    }

    /// Runs multiple Swift 6 migration steps.
    /// - Parameters:
    ///   - count: Maximum number of steps to run.
    ///   - engine: Step engine to use.
    ///   - policy: Migration policy.
    /// - Returns: Array of step results.
    public func runSwift6Steps(
        count: Int,
        engine: any Swift6StepEngine = BasicSwift6StepEngine(),
        policy: Swift6MigrationPolicy = .default
    ) async throws -> [(Swift6StepIntent, SessionReport?)] {
        var results: [(Swift6StepIntent, SessionReport?)] = []

        for _ in 0..<count {
            let result = try await runSwift6Step(engine: engine, policy: policy)
            results.append(result)

            // Stop if we paused
            if case .pause = result.0 {
                break
            }
        }

        return results
    }

    // MARK: - Private Helpers

    /// Loads recent Swift 6 migration sessions.
    private func loadRecentSwift6Sessions() async throws -> [Swift6SessionOutcome] {
        // Get recent sessions from the store
        let recentReports = try await store.getSessionReports(projectId: projectId, limit: 20)

        // Filter to Swift 6 migration sessions and convert to outcomes
        return recentReports.compactMap { (report: SessionReport) -> Swift6SessionOutcome? in
            // Check if this is a Swift 6 migration session
            // We look for sessions with Swift 6 feature category or migration task metadata
            let isSwift6Session = (report.featureCategory?.contains("swift6") ?? false) ||
                                 (report.featureCategory?.contains("migration") ?? false) ||
                                 (report.toolSummary["migration_task_id"] != nil)

            guard isSwift6Session else { return nil }

            // Determine if session was tainted (simplified - check for low health score)
            let tainted = report.metrics.healthScore < 0.5 || report.verdict.lowercased().contains("tainted")

            return Swift6SessionOutcome(
                sessionIndex: report.sessionIndex,
                healthScore: report.metrics.healthScore,
                tainted: tainted,
                configId: report.configId ?? "",
                featureCategory: report.featureCategory ?? "",
                timestamp: Date() // Note: SessionReport doesn't have timestamp field in current model
            )
        }
    }

    /// Creates a session intent for a migration task.
    private func createSessionIntent(
        for task: MigrationTask,
        finding: ScoutFinding?,
        trustTier: TrustTier,
        sessionLane: SessionLane
    ) async throws -> SessionIntent {
        _ = try await requireProject()

        // Create a prompt based on the task and finding
        let prompt = createPrompt(for: task, finding: finding)

        // Create session intent
        return SessionIntent(
            projectId: projectId,
            featureCategory: task.featureCategory,
            requestedConfigId: nil,
            trustTier: trustTier.sessionTrustTier,
            lane: sessionLane,
            metadata: [
                "migration_task_id": task.id.uuidString,
                "finding_id": finding?.id.uuidString ?? "",
                "problem_kind": finding?.problemKind ?? "",
                "severity": finding?.severity.rawValue ?? "",
                "prompt": prompt,
                "max_steps": "50"
            ]
        )
    }

    /// Creates a prompt for a migration task.
    private func createPrompt(for task: MigrationTask, finding: ScoutFinding?) -> String {
        var prompt = "Fix the Swift 6 compatibility issue"

        if let finding = finding {
            prompt += " in \(finding.filePath)"

            if let lineStart = finding.lineStart {
                prompt += " at line \(lineStart)"
                if let lineEnd = finding.lineEnd, lineEnd != lineStart {
                    prompt += "-\(lineEnd)"
                }
            }

            prompt += ":\n\n"
            prompt += "Issue: \(finding.description)\n\n"

            if let suggestedFix = finding.suggestedFix {
                prompt += "Suggested fix: \(suggestedFix)\n\n"
            }

            prompt += "Please fix this issue to make the code Swift 6 compatible."
        } else {
            prompt += " for feature category: \(task.featureCategory)\n\n"
            prompt += "This is a migration task created from scout findings. "
            prompt += "Please analyze the code and fix any Swift 6 compatibility issues."
        }

        return prompt
    }

    // MARK: - Game Project Domain

    /// Loads the current game project state.
    /// - Returns: Current game project state.
    public func loadGameProjectState() async throws -> GameProjectState {
        _ = try await requireProject()

        let migrationTasks = (try? await store.getMigrationTasks(projectId: projectId, limit: 200)) ?? []
        let tasks: [GameTask] = migrationTasks.map { task in
            GameTask(
                id: task.id,
                projectId: task.projectId,
                title: task.featureCategory,
                description: "Migration task for \(task.featureCategory)",
                status: task.status,
                priority: task.priority,
                sceneId: parseSceneId(from: task.featureCategory),
                taskKind: task.featureCategory,
                createdAt: task.createdAt
            )
        }
        let tests: [SceneTest] = []

        // Get recent playtest sessions
        let recentPlaytests = try await loadRecentGamePlaytests()

        let testsByScene = Dictionary(grouping: tests) { $0.sceneId }
        let tasksByScene = Dictionary(grouping: tasks.compactMap { task in
            task.sceneId.map { ($0, task) }
        }) { $0.0 }
        let playtestsByScene = Dictionary(grouping: recentPlaytests.compactMap { outcome in
            outcome.sceneId.map { ($0, outcome) }
        }) { $0.0 }

        var sceneSummaries: [SceneSummary] = []
        for (sceneId, taskPairs) in tasksByScene {
            let sceneTasks = taskPairs.map { $0.1 }
            let sceneTests = testsByScene[sceneId] ?? []
            let outcomes = playtestsByScene[sceneId]?.map { $0.1 } ?? []
            let lastOutcome = outcomes.sorted { $0.timestamp > $1.timestamp }.first
            let hasTainted = outcomes.contains { $0.tainted }
            let isBroken = sceneTests.contains { $0.status == .failed || $0.status == .broken }

            sceneSummaries.append(
                SceneSummary(
                    id: sceneId,
                    name: "Scene \(sceneId)",
                    description: "Derived from migration tasks",
                    tests: sceneTests,
                    tasks: sceneTasks,
                    lastTestedSession: lastOutcome?.sessionIndex,
                    lastOutcome: lastOutcome,
                    hasRecentTaintedSessions: hasTainted,
                    isBroken: isBroken
                )
            )
        }

        return GameProjectState(
            projectId: projectId,
            totalScenes: sceneSummaries.count,
            totalTests: tests.count,
            totalTasks: tasks.count,
            openTasks: tasks.filter { $0.status == .pending || $0.status == .active }.count,
            failingTests: tests.filter { $0.status == .failed || $0.status == .broken }.count,
            brokenScenes: sceneSummaries.filter { $0.isBroken }.count,
            taintedSessions: recentPlaytests.filter { $0.tainted }.count,
            recentPlaytests: recentPlaytests,
            scenes: sceneSummaries,
            overallHealthScore: recentPlaytests.isEmpty ? 1.0 :
                recentPlaytests.map { $0.healthScore }.reduce(0, +) / Double(recentPlaytests.count)
        )
    }

    private func parseSceneId(from featureCategory: String) -> String? {
        let lower = featureCategory.lowercased()
        if let range = lower.range(of: "scene:") {
            return String(featureCategory[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        if let range = lower.range(of: "scene/") {
            return String(featureCategory[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// Runs a single game project step.
    /// - Parameters:
    ///   - engine: Step engine to use (defaults to basic engine).
    ///   - policy: Game project policy (defaults to default policy).
    /// - Returns: Tuple of chosen intent and optional session report.
    public func runGameStep(
        engine: any GameStepEngine = BasicGameStepEngine(),
        policy: GameProjectPolicy = .default
    ) async throws -> (GameStepIntent, SessionReport?) {
        _ = try await requireProject()

        // Load current state
        let state = try await loadGameProjectState()

        // Choose next step
        let intent = engine.chooseNextStep(from: state, policy: policy)

        // Execute the intent
        switch intent {
        case .runSceneTest(let sceneId):
            let report = try await runGameSceneTest(sceneId)
            return (intent, report)

        case .resimulateScene:
            // For now, run full simulation - could be optimized to simulate just one scene
            _ = try await runGameSimulation()
            return (intent, nil)

        case .pause:
            return (intent, nil)
        }
    }

    /// Runs multiple game project steps.
    /// - Parameters:
    ///   - count: Maximum number of steps to run.
    ///   - engine: Step engine to use.
    ///   - policy: Game project policy.
    /// - Returns: Array of step results.
    public func runGameSteps(
        count: Int,
        engine: any GameStepEngine = BasicGameStepEngine(),
        policy: GameProjectPolicy = .default
    ) async throws -> [(GameStepIntent, SessionReport?)] {
        var results: [(GameStepIntent, SessionReport?)] = []

        for _ in 0..<count {
            let result = try await runGameStep(engine: engine, policy: policy)
            results.append(result)

            // Stop if we paused
            if case .pause = result.0 {
                break
            }
        }

        return results
    }

    // MARK: - Private Game Helpers

    /// Loads recent game playtest sessions.
    private func loadRecentGamePlaytests() async throws -> [GamePlaytestOutcome] {
        // Get recent sessions from the store
        let recentReports = try await store.getSessionReports(projectId: projectId, limit: 20)

        // Filter to game playtest sessions and convert to outcomes
        return recentReports.compactMap { report -> GamePlaytestOutcome? in
            // Check if this is a game playtest session
            // We look for sessions with game feature category or scene test metadata
            let isGameSession = (report.featureCategory?.contains("game") ?? false) ||
                               (report.featureCategory?.contains("playtest") ?? false) ||
                               (report.toolSummary["scene_id"] != nil)

            guard isGameSession else { return nil }

            // Determine if session was tainted (simplified - check for low health score)
            let tainted = report.metrics.healthScore < 0.5 || report.verdict.lowercased().contains("tainted")

            return GamePlaytestOutcome(
                sessionIndex: report.sessionIndex,
                healthScore: report.metrics.healthScore,
                tainted: tainted,
                configId: report.configId ?? "",
                featureCategory: report.featureCategory ?? "",
                sceneId: report.toolSummary["scene_id"].map(String.init),
                testParameters: [:],
                timestamp: Date() // Note: SessionReport doesn't have timestamp field in current model
            )
        }
    }

    /// Runs a game scene test.
    /// - Parameter sceneId: Scene identifier.
    /// - Returns: Session report.
    private func runGameSceneTest(_ sceneId: UUID) async throws -> SessionReport {
        // Placeholder implementation
        // In a real implementation, this would create and run a session for testing the scene
        throw NotImplementedError("runGameSceneTest not implemented")
    }

    /// Runs a full game simulation.
    /// - Returns: Session report.
    private func runGameSimulation() async throws -> SessionReport {
        // Placeholder implementation
        // In a real implementation, this would create and run a session for simulating the game
        throw NotImplementedError("runGameSimulation not implemented")
    }
}

/// Error for not implemented functionality.
private struct NotImplementedError: Error {
    let message: String
    init(_ message: String) {
        self.message = message
    }
}
