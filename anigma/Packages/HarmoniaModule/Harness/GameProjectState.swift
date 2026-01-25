//
//  GameProjectState.swift
//  HarmoniaModule
//
//  Explicit state model for game project domain.
//  Mirrors Swift6MigrationState pattern for different domain.
//

@preconcurrency import Foundation

/// Outcome of a game playtest session.
public struct GamePlaytestOutcome: Sendable, Codable {
    /// Session index.
    public var sessionIndex: Int

    /// Health score from the session.
    public var healthScore: Double

    /// Whether the session was tainted.
    public var tainted: Bool

    /// Configuration ID used for the session.
    public var configId: String

    /// Feature category of the session.
    public var featureCategory: String

    /// Scene that was tested (if applicable).
    public var sceneId: String?

    /// Test parameters used.
    public var testParameters: [String: String]

    /// When the session occurred.
    public var timestamp: Date

    /// Creates a new playtest outcome.
    public init(
        sessionIndex: Int,
        healthScore: Double,
        tainted: Bool,
        configId: String,
        featureCategory: String,
        sceneId: String? = nil,
        testParameters: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.sessionIndex = sessionIndex
        self.healthScore = healthScore
        self.tainted = tainted
        self.configId = configId
        self.featureCategory = featureCategory
        self.sceneId = sceneId
        self.testParameters = testParameters
        self.timestamp = timestamp
    }
}

/// Test status for a game scene.
public enum SceneTestStatus: String, Sendable, Codable {
    case pending
    case passed
    case failed
    case broken
    case skipped
}

/// Test definition for a game scene.
public struct SceneTest: Sendable, Codable {
    /// Unique identifier.
    public var id: UUID

    /// Scene identifier.
    public var sceneId: String

    /// Test name.
    public var name: String

    /// Test description.
    public var description: String

    /// Test status.
    public var status: SceneTestStatus

    /// Priority (higher = more important).
    public var priority: Int?

    /// Test parameters (e.g., difficulty, player count, etc.).
    public var parameters: [String: String]

    /// When the test was created.
    public var createdAt: Date

    /// When the test was last run.
    public var lastRunAt: Date?

    /// Creates a new scene test.
    public init(
        id: UUID = UUID(),
        sceneId: String,
        name: String,
        description: String,
        status: SceneTestStatus = .pending,
        parameters: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sceneId = sceneId
        self.name = name
        self.description = description
        self.status = status
        self.parameters = parameters
        self.createdAt = createdAt
    }
}

/// Task for game project work.
public struct GameTask: Sendable, Codable {
    /// Unique identifier.
    public var id: UUID

    /// Project identifier.
    public var projectId: UUID

    /// Task title.
    public var title: String

    /// Task description.
    public var description: String

    /// Task status.
    public var status: MigrationTaskStatus

    /// Priority (higher = more important).
    public var priority: Int?

    /// Associated scene (if applicable).
    public var sceneId: String?

    /// Task kind (e.g., "fix-bug", "add-feature", "optimize").
    public var taskKind: String

    /// When the task was created.
    public var createdAt: Date

    /// When the task was last updated.
    public var updatedAt: Date

    /// Creates a new game task.
    public init(
        id: UUID = UUID(),
        projectId: UUID,
        title: String,
        description: String,
        status: MigrationTaskStatus = .pending,
        priority: Int? = nil,
        sceneId: String? = nil,
        taskKind: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.sceneId = sceneId
        self.taskKind = taskKind
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

/// Summary of a game scene's status.
public struct SceneSummary: Sendable, Codable {
    /// Scene identifier.
    public var id: String

    /// Scene name.
    public var name: String

    /// Scene description.
    public var description: String

    /// Scene tests.
    public var tests: [SceneTest]

    /// Game tasks for this scene.
    public var tasks: [GameTask]

    /// Index of the last session that tested this scene.
    public var lastTestedSession: Int?

    /// Outcome of the last test for this scene.
    public var lastOutcome: GamePlaytestOutcome?

    /// Whether this scene has any tainted sessions in recent history.
    public var hasRecentTaintedSessions: Bool

    /// Whether the scene is currently broken (failing tests).
    public var isBroken: Bool

    /// Creates a new scene summary.
    public init(
        id: String,
        name: String,
        description: String,
        tests: [SceneTest],
        tasks: [GameTask],
        lastTestedSession: Int? = nil,
        lastOutcome: GamePlaytestOutcome? = nil,
        hasRecentTaintedSessions: Bool = false,
        isBroken: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tests = tests
        self.tasks = tasks
        self.lastTestedSession = lastTestedSession
        self.lastOutcome = lastOutcome
        self.hasRecentTaintedSessions = hasRecentTaintedSessions
        self.isBroken = isBroken
    }

    /// Number of open tasks for this scene.
    public var openTaskCount: Int {
        tasks.filter { $0.status == .pending || $0.status == .active }.count
    }

    /// Number of failing tests for this scene.
    public var failingTestCount: Int {
        tests.filter { $0.status == .failed || $0.status == .broken }.count
    }

    /// Whether this scene has any pending work.
    public var hasPendingWork: Bool {
        openTaskCount > 0 || failingTestCount > 0
    }

    /// Priority level based on failures and tasks.
    public var priority: Int {
        if isBroken { return 100 }
        if failingTestCount > 0 { return 50 + failingTestCount }
        if openTaskCount > 0 { return 10 + openTaskCount }
        return 0
    }
}

/// Complete state snapshot for game project domain.
public struct GameProjectState: Sendable, Codable {
    /// Project identifier.
    public var projectId: UUID

    /// Total number of scenes.
    public var totalScenes: Int

    /// Total number of tests.
    public var totalTests: Int

    /// Total number of game tasks.
    public var totalTasks: Int

    /// Number of open (pending/active) tasks.
    public var openTasks: Int

    /// Number of failing tests.
    public var failingTests: Int

    /// Number of broken scenes.
    public var brokenScenes: Int

    /// Number of tainted sessions in recent history.
    public var taintedSessions: Int

    /// Recent playtest outcomes (last N sessions).
    public var recentPlaytests: [GamePlaytestOutcome]

    /// Scene summaries grouped by scene ID.
    public var scenes: [SceneSummary]

    /// Overall health score (average of recent playtests).
    public var overallHealthScore: Double

    /// Whether project is healthy (no broken scenes, low failing tests).
    public var isHealthy: Bool {
        brokenScenes == 0 && failingTests < 3
    }

    /// Whether project work is complete (no open tasks, all tests passing).
    public var isComplete: Bool {
        openTasks == 0 && failingTests == 0 && brokenScenes == 0
    }

    /// Creates a new game project state.
    public init(
        projectId: UUID,
        totalScenes: Int,
        totalTests: Int,
        totalTasks: Int,
        openTasks: Int,
        failingTests: Int,
        brokenScenes: Int,
        taintedSessions: Int,
        recentPlaytests: [GamePlaytestOutcome],
        scenes: [SceneSummary],
        overallHealthScore: Double
    ) {
        self.projectId = projectId
        self.totalScenes = totalScenes
        self.totalTests = totalTests
        self.totalTasks = totalTasks
        self.openTasks = openTasks
        self.failingTests = failingTests
        self.brokenScenes = brokenScenes
        self.taintedSessions = taintedSessions
        self.recentPlaytests = recentPlaytests
        self.scenes = scenes
        self.overallHealthScore = overallHealthScore
    }

    /// Scenes with pending work, sorted by priority.
    public var scenesWithPendingWork: [SceneSummary] {
        scenes.filter { $0.hasPendingWork }.sorted { scene1, scene2 in
            // Sort by: broken scenes first, then failing tests, then open tasks
            if scene1.isBroken != scene2.isBroken {
                return scene1.isBroken && !scene2.isBroken
            }
            if scene1.failingTestCount != scene2.failingTestCount {
                return scene1.failingTestCount > scene2.failingTestCount
            }
            return scene1.openTaskCount > scene2.openTaskCount
        }
    }

    /// Scenes that have had tainted sessions recently.
    public var scenesWithRecentTaintedSessions: [SceneSummary] {
        scenes.filter { $0.hasRecentTaintedSessions }
    }

    /// Whether there are any scenes with recent tainted sessions.
    public var hasRecentTaintedScenes: Bool {
        !scenesWithRecentTaintedSessions.isEmpty
    }

    /// Broken scenes (isBroken = true).
    public var brokenSceneSummaries: [SceneSummary] {
        scenes.filter { $0.isBroken }
    }
}

/// Policy configuration for game project.
public struct GameProjectPolicy: Sendable, Codable {
    /// Maximum number of scenes to test per session.
    public var maxScenesPerSession: Int

    /// Whether to avoid scenes with recent tainted sessions.
    public var avoidTaintedAreas: Bool

    /// Number of sessions to consider "recent" for taint avoidance.
    public var taintMemorySessions: Int

    /// Preference for broken scenes.
    public var preferBrokenScenes: Bool

    /// Whether to allow resimulation when no tests are available.
    public var allowResimulation: Bool

    /// Default policy for game projects.
    public static let `default` = GameProjectPolicy(
        maxScenesPerSession: 1,
        avoidTaintedAreas: true,
        taintMemorySessions: 3,
        preferBrokenScenes: true,
        allowResimulation: true
    )

    /// Creates a new game project policy.
    public init(
        maxScenesPerSession: Int = 1,
        avoidTaintedAreas: Bool = true,
        taintMemorySessions: Int = 3,
        preferBrokenScenes: Bool = true,
        allowResimulation: Bool = true
    ) {
        self.maxScenesPerSession = maxScenesPerSession
        self.avoidTaintedAreas = avoidTaintedAreas
        self.taintMemorySessions = taintMemorySessions
        self.preferBrokenScenes = preferBrokenScenes
        self.allowResimulation = allowResimulation
    }
}
