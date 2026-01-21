//
//  ProjectHarnessModels.swift
//  HarmoniaModule
//
//  GRDB models for the long-running coding harness.
//  Stores project specs, feature test cases, and progress snapshots.
//

import AnigmaCore
import Foundation
import GRDB

// MARK: - Project Status

/// Status of a project in the coding harness.
public enum ProjectStatus: String, Codable, Sendable, DatabaseValueConvertible {
    /// Project spec has been created but not yet initialized.
    case uninitialized

    /// Project has been initialized (feature breakdown created, scaffolding generated).
    case initialized

    /// Project is actively being worked on.
    case inProgress

    /// Project has been completed (all features passing).
    case completed

    /// Project has been paused or abandoned.
    case paused
}

// MARK: - Feature Test Status

/// Status of a feature test case.
public enum FeatureTestStatus: String, Codable, Sendable, DatabaseValueConvertible {
    /// Feature has not been attempted yet.
    case pending

    /// Feature implementation is currently being worked on.
    case inProgress

    /// Feature tests are passing.
    case passing

    /// Feature tests are failing.
    case failing

    /// Feature has been skipped or is not applicable.
    case skipped
}

// MARK: - Project Spec

/// Project specification (PRD) for the coding harness.
public struct ProjectSpec: Codable, Sendable, TableRecord, FetchableRecord, PersistableRecord {
    /// Unique project identifier.
    public var id: UUID

    /// Human-readable project name.
    public var name: String

    /// Project specification / PRD text.
    public var specText: String

    /// Project status.
    public var status: ProjectStatus

    /// Base directory for the project (where code lives).
    public var projectDirectory: String?

    /// Git repository URL (if applicable).
    public var gitRepositoryURL: String?

    /// When the project was created.
    public var createdAt: Date

    /// When the project was last updated.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        specText: String,
        status: ProjectStatus = .uninitialized,
        projectDirectory: String? = nil,
        gitRepositoryURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.specText = specText
        self.status = status
        self.projectDirectory = projectDirectory
        self.gitRepositoryURL = gitRepositoryURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - GRDB Table Definition

    public static var databaseTableName: String { "project_specs" }

    public enum Columns: String, ColumnExpression {
        case id
        case name
        case specText
        case status
        case projectDirectory
        case gitRepositoryURL
        case createdAt
        case updatedAt
    }

    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column(Columns.id.rawValue, .text).primaryKey()
            t.column(Columns.name.rawValue, .text).notNull()
            t.column(Columns.specText.rawValue, .text).notNull()
            t.column(Columns.status.rawValue, .text).notNull()
            t.column(Columns.projectDirectory.rawValue, .text)
            t.column(Columns.gitRepositoryURL.rawValue, .text)
            t.column(Columns.createdAt.rawValue, .datetime).notNull()
            t.column(Columns.updatedAt.rawValue, .datetime).notNull()
        }

        // Create indexes for common queries
        try db.create(
            index: "idx_project_specs_status", on: databaseTableName,
            columns: [Columns.status.rawValue], ifNotExists: true)
        try db.create(
            index: "idx_project_specs_updated_at", on: databaseTableName,
            columns: [Columns.updatedAt.rawValue], ifNotExists: true)
    }
}

// MARK: - Bandit Learning Extension

extension ProjectHarnessStore {
    // MARK: - Bandit Policy Operations

    /// Gets bandit statistics for a project and feature category.
    public func getBanditStats(
        projectId: UUID,
        featureCategory: String,
        configIds: [String]
    ) async throws -> [BanditArmStats] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try await dbPool.read { db in
            let states =
                try ConfigPolicyState
                .filter(ConfigPolicyState.Columns.projectId == projectId.uuidString)
                .filter(ConfigPolicyState.Columns.featureCategory == featureCategory)
                .filter(configIds.contains(ConfigPolicyState.Columns.configId))
                .fetchAll(db)

            return states.map { state in
                BanditArmStats(
                    configId: state.configId,
                    pulls: state.pulls,
                    totalReward: state.totalReward
                )
            }
        }
    }

    /// Updates bandit statistics after a session.
    public func updateBanditStats(
        projectId: UUID,
        featureCategory: String,
        configId: String,
        reward: Double
    ) async throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try await dbPool.write { db in
            // Try to find existing state
            if var state =
                try ConfigPolicyState
                .filter(ConfigPolicyState.Columns.projectId == projectId.uuidString)
                .filter(ConfigPolicyState.Columns.featureCategory == featureCategory)
                .filter(ConfigPolicyState.Columns.configId == configId)
                .fetchOne(db) {
                // Update existing state
                state.pulls += 1
                state.totalReward += reward
                state.lastUpdatedAt = Date()
                try state.update(db)
            } else {
                // Create new state
                let state = ConfigPolicyState(
                    id: nil,
                    projectId: projectId.uuidString,
                    featureCategory: featureCategory,
                    configId: configId,
                    pulls: 1,
                    totalReward: reward,
                    lastUpdatedAt: Date()
                )
                try state.insert(db)
            }
        }
    }

    /// Gets all config IDs with statistics for a project and category.
    public func getAllBanditStats(
        projectId: UUID,
        featureCategory: String
    ) async throws -> [ConfigPolicyState] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try await dbPool.read { db in
            try ConfigPolicyState
                .filter(ConfigPolicyState.Columns.projectId == projectId.uuidString)
                .filter(ConfigPolicyState.Columns.featureCategory == featureCategory)
                .order(ConfigPolicyState.Columns.totalReward.desc)
                .fetchAll(db)
        }
    }

    /// Resets bandit statistics for a project and category.
    public func resetBanditStats(
        projectId: UUID,
        featureCategory: String? = nil
    ) async throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try await dbPool.write { db in
            var request =
                ConfigPolicyState
                .filter(ConfigPolicyState.Columns.projectId == projectId.uuidString)

            if let featureCategory = featureCategory {
                request = request.filter(
                    ConfigPolicyState.Columns.featureCategory == featureCategory)
            }

            let states = try request.fetchAll(db)
            for var state in states {
                state.pulls = 0
                state.totalReward = 0
                state.lastUpdatedAt = Date()
                try state.update(db)
            }
        }
    }

    // MARK: - Config Selection

    /// Selects a config for a feature category using bandit policy.
    public func selectConfig(
        projectId: UUID,
        featureCategory: String,
        policy: EpsilonGreedyPolicy = EpsilonGreedyPolicy()
    ) async throws -> String {
        // Get blessed configs for this category
        let blessedConfigs = BlessedConfigRegistry.configIds(for: featureCategory)
        guard !blessedConfigs.isEmpty else {
            // Fall back to default config
            return "default"
        }

        // Get bandit stats for these configs
        let armStats = try await getBanditStats(
            projectId: projectId,
            featureCategory: featureCategory,
            configIds: blessedConfigs
        )

        // Calculate total pulls for epsilon decay
        let totalPulls = armStats.reduce(0) { $0 + $1.pulls }

        // If we have stats, use policy to select
        if let selectedConfigId = policy.selectArm(arms: armStats, totalPulls: totalPulls) {
            return selectedConfigId
        } else {
            // No stats yet, pick first blessed config
            return blessedConfigs.first ?? "default"
        }
    }

    /// Gets the best performing config for a category (based on average reward).
    public func getBestConfig(
        projectId: UUID,
        featureCategory: String
    ) async throws -> String? {
        let stats = try await getAllBanditStats(
            projectId: projectId,
            featureCategory: featureCategory
        )

        // Filter to only blessed configs
        let blessedConfigs = BlessedConfigRegistry.configIds(for: featureCategory)
        let blessedStats = stats.filter { blessedConfigs.contains($0.configId) }

        // Return config with highest average reward (minimum 5 pulls)
        return
            blessedStats
            .filter { $0.pulls >= 5 }
            .max { $0.averageReward < $1.averageReward }?
            .configId
    }

    /// Identifies configs that should be considered for deprecation.
    /// - Parameters:
    ///   - projectId: Project identifier
    ///   - featureCategory: Feature category
    ///   - minPulls: Minimum pulls to consider (default: 10)
    ///   - performanceThreshold: Configs below this average reward are candidates (default: 0.3)
    ///   - relativeThreshold: Configs performing worse than best by this margin are candidates (default: 0.4)
    /// - Returns: Array of config IDs that should be considered for deprecation
    public func getDeprecationCandidates(
        projectId: UUID,
        featureCategory: String,
        minPulls: Int = 10,
        performanceThreshold: Double = 0.3,
        relativeThreshold: Double = 0.4
    ) async throws -> [String] {
        let stats = try await getAllBanditStats(
            projectId: projectId,
            featureCategory: featureCategory
        )

        // Filter to only blessed configs with sufficient pulls
        let blessedConfigs = BlessedConfigRegistry.configIds(for: featureCategory)
        let relevantStats = stats.filter {
            blessedConfigs.contains($0.configId) && $0.pulls >= minPulls
        }

        guard !relevantStats.isEmpty else { return [] }

        // Find best performing config
        let bestReward =
            relevantStats
            .map { $0.averageReward }
            .max() ?? 0

        // Identify candidates:
        // 1. Absolute performance too low
        // 2. Relative performance too far from best
        return relevantStats.filter { stat in
            let isLowAbsolute = stat.averageReward < performanceThreshold
            let isLowRelative = (bestReward - stat.averageReward) > relativeThreshold

            return isLowAbsolute || isLowRelative
        }.map { $0.configId }
    }

    /// Gets a performance report for all configs in a category.
    /// - Parameters:
    ///   - projectId: Project identifier
    ///   - featureCategory: Feature category
    /// - Returns: Dictionary with config performance metrics
    public func getPerformanceReport(
        projectId: UUID,
        featureCategory: String
    ) async throws -> [String: [String: Any]] {
        let stats = try await getAllBanditStats(
            projectId: projectId,
            featureCategory: featureCategory
        )

        // Filter to only blessed configs
        let blessedConfigs = BlessedConfigRegistry.configIds(for: featureCategory)
        let blessedStats = stats.filter { blessedConfigs.contains($0.configId) }

        var report: [String: [String: Any]] = [:]

        for stat in blessedStats {
            let config = BlessedConfigRegistry.config(withId: stat.configId)
            report[stat.configId] = [
                "name": config?.name ?? stat.configId,
                "pulls": stat.pulls,
                "total_reward": stat.totalReward,
                "average_reward": stat.averageReward,
                "description": config?.description ?? "",
                "categories": config?.featureCategories ?? []
            ]
        }

        return report
    }
}

// MARK: - Feature Behavioral Snapshot

/// Snapshot of feature behavioral metrics for a single session.
public struct FeatureBehavioralSnapshot: Codable, Sendable {
    /// Session index.
    public let sessionIndex: Int

    /// Health score (0...1).
    public let healthScore: Double

    /// Analysis ratio: analysis_calls / (analysis_calls + edit_calls).
    public let analysisRatio: Double

    /// Edit calls count.
    public let editCalls: Int

    /// Analysis calls count.
    public let analysisCalls: Int

    /// Test calls count.
    public let testCalls: Int

    /// Whether tests passed.
    public let testsPassed: Bool?

    /// When the snapshot was taken.
    public let timestamp: Date

    /// Summary of work done.
    public let workSummary: String

    public init(
        sessionIndex: Int,
        healthScore: Double,
        analysisRatio: Double,
        editCalls: Int,
        analysisCalls: Int,
        testCalls: Int,
        testsPassed: Bool?,
        timestamp: Date,
        workSummary: String
    ) {
        self.sessionIndex = sessionIndex
        self.healthScore = healthScore
        self.analysisRatio = analysisRatio
        self.editCalls = editCalls
        self.analysisCalls = analysisCalls
        self.testCalls = testCalls
        self.testsPassed = testsPassed
        self.timestamp = timestamp
        self.workSummary = workSummary
    }
}

// MARK: - Feature Test Case

/// A single feature test case derived from a project spec.
public struct FeatureTestCase: Codable, Sendable, TableRecord, FetchableRecord, PersistableRecord {
    /// Unique feature identifier.
    public var id: UUID

    /// Project this feature belongs to.
    public var projectId: UUID

    /// Feature name (e.g., "User Authentication").
    public var name: String

    /// Feature category (e.g., "Authentication", "UI", "API").
    public var category: String

    /// Detailed description of the feature.
    public var description: String

    /// Validation steps to confirm the feature works.
    public var validationSteps: [String]

    /// Current status of the feature.
    public var status: FeatureTestStatus

    /// When the feature was created.
    public var createdAt: Date

    /// When the feature was last updated.
    public var updatedAt: Date

    /// Optional: Last error message if status is .failing.
    public var lastError: String?

    /// Optional: Priority hint (lower = higher priority).
    public var priority: Int?

    /// Optional: Estimated complexity (1-5).
    public var estimatedComplexity: Int?

    /// Behavioral history for this feature.
    public var behavioralHistory: [FeatureBehavioralSnapshot]?

    /// Completion notes with behavioral insights.
    public var completionNotes: String?

    /// Health score when feature was completed.
    public var completionHealthScore: Double?

    /// Number of sessions spent on this feature.
    public var sessionsSpent: Int?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        name: String,
        category: String,
        description: String,
        validationSteps: [String] = [],
        status: FeatureTestStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastError: String? = nil,
        priority: Int? = nil,
        estimatedComplexity: Int? = nil,
        behavioralHistory: [FeatureBehavioralSnapshot]? = nil,
        completionNotes: String? = nil,
        completionHealthScore: Double? = nil,
        sessionsSpent: Int? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.category = category
        self.description = description
        self.validationSteps = validationSteps
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastError = lastError
        self.priority = priority
        self.estimatedComplexity = estimatedComplexity
        self.behavioralHistory = behavioralHistory
        self.completionNotes = completionNotes
        self.completionHealthScore = completionHealthScore
        self.sessionsSpent = sessionsSpent
    }

    // MARK: - GRDB Table Definition

    public static var databaseTableName: String { "feature_test_cases" }

    public enum Columns: String, ColumnExpression {
        case id
        case projectId
        case name
        case category
        case description
        case validationSteps
        case status
        case createdAt
        case updatedAt
        case lastError
        case priority
        case estimatedComplexity
        case behavioralHistory
        case completionNotes
        case completionHealthScore
        case sessionsSpent
    }

    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column(Columns.id.rawValue, .text).primaryKey()
            t.column(Columns.projectId.rawValue, .text).notNull().indexed().references(
                "project_specs", column: "id", onDelete: .cascade)
            t.column(Columns.name.rawValue, .text).notNull()
            t.column(Columns.category.rawValue, .text).notNull()
            t.column(Columns.description.rawValue, .text).notNull()
            t.column(Columns.validationSteps.rawValue, .text).notNull()
            t.column(Columns.status.rawValue, .text).notNull()
            t.column(Columns.createdAt.rawValue, .datetime).notNull()
            t.column(Columns.updatedAt.rawValue, .datetime).notNull()
            t.column(Columns.lastError.rawValue, .text)
            t.column(Columns.priority.rawValue, .integer)
            t.column(Columns.estimatedComplexity.rawValue, .integer)
            t.column(Columns.behavioralHistory.rawValue, .text)
            t.column(Columns.completionNotes.rawValue, .text)
            t.column(Columns.completionHealthScore.rawValue, .double)
            t.column(Columns.sessionsSpent.rawValue, .integer)
        }

        // Create indexes for common queries
        do {
            try db.create(
                index: "idx_feature_test_cases_project_status", on: databaseTableName,
                columns: [Columns.projectId.rawValue, Columns.status.rawValue], ifNotExists: true)
        } catch {
            // Index already exists - ignore
        }
        do {
            try db.create(
                index: "idx_feature_test_cases_priority", on: databaseTableName,
                columns: [Columns.priority.rawValue], ifNotExists: true)
        } catch {
            // Index already exists - ignore
        }
        do {
            try db.create(
                index: "idx_feature_test_cases_category", on: databaseTableName,
                columns: [Columns.category.rawValue], ifNotExists: true)
        } catch {
            // Index already exists - ignore
        }
    }
}

// MARK: - Project Progress Snapshot

/// Snapshot of project progress at a point in time.
public struct ProjectProgressSnapshot: Codable, Sendable, TableRecord, FetchableRecord,
    PersistableRecord {
    /// Unique snapshot identifier.
    public var id: UUID

    /// Project this snapshot belongs to.
    public var projectId: UUID

    /// Monotonic session index (increments with each coding session).
    public var sessionIndex: Int

    /// Summary text of what was accomplished.
    public var summary: String

    /// When the snapshot was taken.
    public var timestamp: Date

    /// Optional: List of feature IDs touched in this session.
    public var featureIdsTouched: [UUID]?

    /// Optional: Git commit hash at time of snapshot.
    public var gitCommitHash: String?

    /// Optional: Test results summary.
    public var testResults: String?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        sessionIndex: Int,
        summary: String,
        timestamp: Date = Date(),
        featureIdsTouched: [UUID]? = nil,
        gitCommitHash: String? = nil,
        testResults: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.sessionIndex = sessionIndex
        self.summary = summary
        self.timestamp = timestamp
        self.featureIdsTouched = featureIdsTouched
        self.gitCommitHash = gitCommitHash
        self.testResults = testResults
    }

    // MARK: - GRDB Table Definition

    public static var databaseTableName: String { "project_progress_snapshots" }

    public enum Columns: String, ColumnExpression {
        case id
        case projectId
        case sessionIndex
        case summary
        case timestamp
        case featureIdsTouched
        case gitCommitHash
        case testResults
    }

    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column(Columns.id.rawValue, .text).primaryKey()
            t.column(Columns.projectId.rawValue, .text).notNull().indexed().references(
                "project_specs", column: "id", onDelete: .cascade)
            t.column(Columns.sessionIndex.rawValue, .integer).notNull()
            t.column(Columns.summary.rawValue, .text).notNull()
            t.column(Columns.timestamp.rawValue, .datetime).notNull()
            t.column(Columns.featureIdsTouched.rawValue, .text)
            t.column(Columns.gitCommitHash.rawValue, .text)
            t.column(Columns.testResults.rawValue, .text)
        }

        // Create indexes for common queries
        try db.create(
            index: "idx_project_progress_snapshots_project_session", on: databaseTableName,
            columns: [Columns.projectId.rawValue, Columns.sessionIndex.rawValue], unique: true,
            ifNotExists: true)
        try db.create(
            index: "idx_project_progress_snapshots_timestamp", on: databaseTableName,
            columns: [Columns.timestamp.rawValue], ifNotExists: true)
    }
}

// MARK: - Project Harness Store

/// GRDB store for project harness data.
public actor ProjectHarnessStore {
    /// Shared instance.
    public static let shared = ProjectHarnessStore()

    /// Current project this store is operating on.
    public var projectId = UUID()

    /// Database connection pool.
    internal var dbPool: DatabasePool?

    /// Whether store is initialized.
    private var isInitialized = false

    private init() {}

    /// Gets the database pool (for internal use by other components).
    public func getDBPool() throws -> DatabasePool {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }
        return dbPool
    }

    /// Initializes the database connection and creates tables.
    public func initialize(databasePath: String = "harmonia_harness.sqlite") throws {
        guard !isInitialized else { return }

        let databaseURL = URL(fileURLWithPath: databasePath)

        // Create parent directory if needed
        let parentDir = databaseURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(
                at: parentDir, withIntermediateDirectories: true)
        }

        // Configure database pool
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            // Enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            // Enable WAL mode for better concurrency
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        // Create database pool
        dbPool = try DatabasePool(path: databaseURL.path, configuration: configuration)

        // Create tables
        try dbPool?.write { db in
            try ProjectSpec.createTable(db)
            try FeatureTestCase.createTable(db)
            try ProjectProgressSnapshot.createTable(db)
            try ToolUsageLog.createTable(db)
            try BehavioralHealthMetrics.createTable(db)
            try SessionReport.createTable(db)
            try ConfigPolicyState.createTable(db)
            try MigrationTask.createTable(db)
            try ScoutFinding.createTable(db)
        }

        isInitialized = true
    }

    // MARK: - Project Spec Operations

    /// Creates a new project spec.
    public func createProjectSpec(_ spec: ProjectSpec) throws -> ProjectSpec {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try dbPool.write { db in
            try spec.insert(db)
        }
        return spec
    }

    /// Async version for actor compatibility
    public func saveProject(_ spec: ProjectSpec) async throws {
        _ = try createProjectSpec(spec)
    }

    /// Gets a project spec by ID.
    public func getProjectSpec(id: UUID) throws -> ProjectSpec? {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try dbPool.read { db in
            try ProjectSpec.fetchOne(db, key: id)
        }
    }

    /// Async version for actor compatibility
    public func loadProject(id: String) async throws -> ProjectSpec? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try getProjectSpec(id: uuid)
    }

    /// Updates a project spec.
    public func updateProjectSpec(_ spec: ProjectSpec) throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        var updatedSpec = spec
        updatedSpec.updatedAt = Date()

        try dbPool.write { db in
            try updatedSpec.update(db)
        }
    }

    /// Lists all project specs.
    public func listProjectSpecs(status: ProjectStatus? = nil) throws -> [ProjectSpec] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try dbPool.read { db in
            var request = ProjectSpec.all()
            if let status = status {
                request = request.filter(ProjectSpec.Columns.status == status)
            }
            request = request.order(ProjectSpec.Columns.updatedAt.desc)
            return try request.fetchAll(db)
        }
    }

    /// Async version for actor compatibility
    public func loadAllProjects() async throws -> [ProjectSpec] {
        return try listProjectSpecs()
    }

    // MARK: - Feature Test Case Operations

    /// Creates feature test cases for a project.
    public func createFeatureTestCases(_ features: [FeatureTestCase]) throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try dbPool.write { db in
            for feature in features {
                try feature.insert(db)
            }
        }
    }

    // MARK: - Config Policy State for Bandit Learning

    /// GRDB record for multi-armed bandit policy state.
    public struct ConfigPolicyState: Codable, Sendable, TableRecord, FetchableRecord,
        PersistableRecord {
        /// Auto-incrementing primary key.
        public var id: Int64?

        /// Project identifier.
        public var projectId: String

        /// Feature category (e.g., "ui", "backend", "tests").
        public var featureCategory: String

        /// Identifier of a blessed config.
        public var configId: String

        /// Times this config has been chosen.
        public var pulls: Int

        /// Sum of rewards received.
        public var totalReward: Double

        /// When this record was last updated.
        public var lastUpdatedAt: Date

        /// Computed average reward.
        public var averageReward: Double {
            guard pulls > 0 else { return 0 }
            return totalReward / Double(pulls)
        }

        public init(
            id: Int64? = nil,
            projectId: String,
            featureCategory: String,
            configId: String,
            pulls: Int = 0,
            totalReward: Double = 0,
            lastUpdatedAt: Date = Date()
        ) {
            self.id = id
            self.projectId = projectId
            self.featureCategory = featureCategory
            self.configId = configId
            self.pulls = pulls
            self.totalReward = totalReward
            self.lastUpdatedAt = lastUpdatedAt
        }

        // MARK: - GRDB Table Definition

        public static var databaseTableName: String { "config_policy_state" }

        public enum Columns: String, ColumnExpression {
            case id
            case projectId
            case featureCategory
            case configId
            case pulls
            case totalReward
            case lastUpdatedAt
        }

        public static func createTable(_ db: Database) throws {
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey(Columns.id.rawValue)
                t.column(Columns.projectId.rawValue, .text).notNull().indexed()
                t.column(Columns.featureCategory.rawValue, .text).notNull().indexed()
                t.column(Columns.configId.rawValue, .text).notNull()
                t.column(Columns.pulls.rawValue, .integer).notNull().defaults(to: 0)
                t.column(Columns.totalReward.rawValue, .double).notNull().defaults(to: 0)
                t.column(Columns.lastUpdatedAt.rawValue, .datetime).notNull()

                // Unique constraint: one row per (project, category, config)
                t.uniqueKey([
                    Columns.projectId.rawValue, Columns.featureCategory.rawValue,
                    Columns.configId.rawValue
                ])
            }

            // Create indexes for common queries
            try db.create(
                index: "idx_config_policy_project_category", on: databaseTableName,
                columns: [Columns.projectId.rawValue, Columns.featureCategory.rawValue],
                ifNotExists: true)
            try db.create(
                index: "idx_config_policy_last_updated", on: databaseTableName,
                columns: [Columns.lastUpdatedAt.rawValue], ifNotExists: true)
        }
    }

    /// Marks a feature as completed with behavioral insights.
    public func completeFeature(
        featureId: UUID,
        completionNotes: String,
        healthScore: Double,
        testsPassed: Bool
    ) throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try dbPool.write { db in
            guard var feature = try FeatureTestCase.fetchOne(db, key: featureId) else {
                throw HarnessError.featureNotFound(featureId)
            }

            // Update feature status
            feature.status = testsPassed ? .passing : .failing
            feature.completionNotes = completionNotes
            feature.completionHealthScore = healthScore
            feature.updatedAt = Date()

            // Generate behavioral summary if we have history
            if let history = feature.behavioralHistory, !history.isEmpty {
                let avgHealthScore =
                    history.map { $0.healthScore }.reduce(0, +) / Double(history.count)
                let avgAnalysisRatio =
                    history.map { $0.analysisRatio }.reduce(0, +) / Double(history.count)
                let totalEdits = history.map { $0.editCalls }.reduce(0, +)
                let totalAnalysis = history.map { $0.analysisCalls }.reduce(0, +)
                let totalTests = history.map { $0.testCalls }.reduce(0, +)

                let behavioralSummary = """
                    Behavioral Summary:
                    - Sessions: \(history.count)
                    - Avg Health Score: \(String(format: "%.1f%%", avgHealthScore * 100))
                    - Avg Analysis Ratio: \(String(format: "%.1f%%", avgAnalysisRatio * 100))
                    - Total Edits: \(totalEdits)
                    - Total Analysis: \(totalAnalysis)
                    - Total Tests: \(totalTests)
                    - Final Health: \(String(format: "%.1f%%", healthScore * 100))
                    """

                feature.completionNotes =
                    (feature.completionNotes ?? "") + "\n\n" + behavioralSummary
            }

            try feature.update(db)
        }
    }

    /// Gets behavioral insights for a feature.
    public func getFeatureBehavioralInsights(featureId: UUID) throws -> [String: Any] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try dbPool.read { db in
            guard let feature = try FeatureTestCase.fetchOne(db, key: featureId) else {
                throw HarnessError.featureNotFound(featureId)
            }

            guard let history = feature.behavioralHistory, !history.isEmpty else {
                return ["error": "No behavioral history available"]
            }

            // Calculate statistics
            let avgHealthScore = history.map { $0.healthScore }.reduce(0, +) / Double(history.count)
            let avgAnalysisRatio =
                history.map { $0.analysisRatio }.reduce(0, +) / Double(history.count)
            let totalEdits = history.map { $0.editCalls }.reduce(0, +)
            let totalAnalysis = history.map { $0.analysisCalls }.reduce(0, +)
            let totalTests = history.map { $0.testCalls }.reduce(0, +)

            // Find best and worst sessions
            let bestSession = history.max { $0.healthScore < $1.healthScore }
            let worstSession = history.min { $0.healthScore < $1.healthScore }

            // Calculate improvement trend
            let healthScores = history.sorted { $0.sessionIndex < $1.sessionIndex }.map {
                $0.healthScore
            }
            let improvementTrend =
                healthScores.count > 1 ? healthScores.last! - healthScores.first! : 0.0

            // Analyze patterns
            let sessionsWithLowAnalysis = history.filter { $0.analysisRatio < 0.1 }.count
            let sessionsWithoutTests = history.filter { $0.testCalls == 0 && $0.editCalls > 0 }
                .count
            let consistentlyHealthy = history.filter { $0.healthScore >= 0.7 }.count

            return [
                "feature_id": featureId.uuidString,
                "feature_name": feature.name,
                "sessions_count": history.count,
                "sessions_spent": feature.sessionsSpent ?? 0,
                "status": feature.status.rawValue,
                "completion_health_score": feature.completionHealthScore ?? 0.0,
                "statistics": [
                    "avg_health_score": avgHealthScore,
                    "avg_analysis_ratio": avgAnalysisRatio,
                    "total_edits": totalEdits,
                    "total_analysis": totalAnalysis,
                    "total_tests": totalTests,
                    "edits_per_session": Double(totalEdits) / Double(history.count),
                    "analysis_per_session": Double(totalAnalysis) / Double(history.count),
                    "tests_per_session": Double(totalTests) / Double(history.count)
                ],
                "best_session": bestSession.map {
                    [
                        "session_index": $0.sessionIndex,
                        "health_score": $0.healthScore,
                        "analysis_ratio": $0.analysisRatio,
                        "work_summary": $0.workSummary
                    ]
                } as Any,
                "worst_session": worstSession.map {
                    [
                        "session_index": $0.sessionIndex,
                        "health_score": $0.healthScore,
                        "analysis_ratio": $0.analysisRatio,
                        "work_summary": $0.workSummary
                    ]
                } as Any,
                "trends": [
                    "improvement_trend": improvementTrend,
                    "sessions_with_low_analysis": sessionsWithLowAnalysis,
                    "sessions_without_tests": sessionsWithoutTests,
                    "consistently_healthy_sessions": consistentlyHealthy,
                    "health_trend": healthScores
                ],
                "recommendations": generateFeatureRecommendations(
                    history: history,
                    avgHealthScore: avgHealthScore,
                    sessionsWithLowAnalysis: sessionsWithLowAnalysis,
                    sessionsWithoutTests: sessionsWithoutTests
                ),
                "session_history": history.map { snapshot in
                    [
                        "session_index": snapshot.sessionIndex,
                        "health_score": snapshot.healthScore,
                        "analysis_ratio": snapshot.analysisRatio,
                        "edit_calls": snapshot.editCalls,
                        "analysis_calls": snapshot.analysisCalls,
                        "test_calls": snapshot.testCalls,
                        "tests_passed": snapshot.testsPassed ?? false,
                        "work_summary": snapshot.workSummary,
                        "timestamp": snapshot.timestamp
                    ]
                }
            ]
        }
    }

    private func generateFeatureRecommendations(
        history: [FeatureBehavioralSnapshot],
        avgHealthScore: Double,
        sessionsWithLowAnalysis: Int,
        sessionsWithoutTests: Int
    ) -> [String] {
        var recommendations: [String] = []

        if avgHealthScore < 0.6 {
            recommendations.append(
                "Feature development showed poor behavioral health - consider tightening prompts")
        }

        if sessionsWithLowAnalysis > history.count / 2 {
            recommendations.append(
                "Multiple sessions had low analysis ratios - add analysis requirements to prompt")
        }

        if sessionsWithoutTests > 0 {
            recommendations.append(
                "Some sessions made edits without running tests - enforce test requirements")
        }

        let healthTrend = history.sorted { $0.sessionIndex < $1.sessionIndex }.map {
            $0.healthScore
        }
        if healthTrend.count > 2 && healthTrend.last! < healthTrend.first! {
            recommendations.append("Health score declined over time - review prompt effectiveness")
        }

        if avgHealthScore >= 0.8 {
            recommendations.append(
                "Excellent behavioral health - this prompt configuration works well for similar features"
            )
        }

        return recommendations
    }

    /// Async version for actor compatibility
    public func saveFeatures(_ features: [FeatureTestCase]) async throws {
        try createFeatureTestCases(features)
    }

    /// Gets feature test cases for a project.
    public func getFeatureTestCases(projectId: UUID, status: FeatureTestStatus? = nil) throws
        -> [FeatureTestCase] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try dbPool.read { db in
            var request = FeatureTestCase.filter(FeatureTestCase.Columns.projectId == projectId)
            if let status = status {
                request = request.filter(FeatureTestCase.Columns.status == status)
            }
            request = request.order(FeatureTestCase.Columns.priority.asc)
            return try request.fetchAll(db)
        }
    }

    /// Async version for actor compatibility
    public func loadFeatures(forProjectId projectId: String) async throws -> [FeatureTestCase] {
        guard let uuid = UUID(uuidString: projectId) else { return [] }
        return try getFeatureTestCases(projectId: uuid)
    }

    /// Updates a feature test case.
    public func updateFeatureTestCase(_ feature: FeatureTestCase) throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        var updatedFeature = feature
        updatedFeature.updatedAt = Date()

        try dbPool.write { db in
            try updatedFeature.update(db)
        }
    }

    /// Async version for actor compatibility
    public func saveFeature(_ feature: FeatureTestCase) async throws {
        try updateFeatureTestCase(feature)
    }

    // MARK: - Progress Snapshot Operations

    /// Creates a progress snapshot.
    public func createProgressSnapshot(_ snapshot: ProjectProgressSnapshot) throws
        -> ProjectProgressSnapshot {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try dbPool.write { db in
            try snapshot.insert(db)
        }
        return snapshot
    }

    /// Gets the latest progress snapshot for a project.
    public func getLatestProgressSnapshot(projectId: UUID) throws -> ProjectProgressSnapshot? {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try dbPool.read { db in
            try ProjectProgressSnapshot
                .filter(ProjectProgressSnapshot.Columns.projectId == projectId)
                .order(ProjectProgressSnapshot.Columns.sessionIndex.desc)
                .fetchOne(db)
        }
    }

    /// Gets all progress snapshots for a project.
    public func getProgressSnapshots(projectId: UUID) throws -> [ProjectProgressSnapshot] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try dbPool.read { db in
            try ProjectProgressSnapshot
                .filter(ProjectProgressSnapshot.Columns.projectId == projectId)
                .order(ProjectProgressSnapshot.Columns.sessionIndex.asc)
                .fetchAll(db)
        }
    }
}

// MARK: - Errors

// MARK: - Tool Usage Log

/// Log of tool usage for observability.
public struct ToolUsageLog: Codable, Sendable, TableRecord, FetchableRecord, PersistableRecord {
    /// Unique log identifier.
    public var id: UUID

    /// Project identifier.
    public var projectId: UUID

    /// Session index.
    public var sessionIndex: Int

    /// Tool name.
    public var toolName: String

    /// When the tool was invoked.
    public var invokedAt: Date

    /// Duration in milliseconds.
    public var durationMs: Int?

    /// Whether the tool succeeded.
    public var success: Bool

    /// Error message if failed.
    public var errorMessage: String?

    /// Feature ID being worked on (if any).
    public var featureId: UUID?

    /// Additional context.
    public var context: String?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        sessionIndex: Int,
        toolName: String,
        invokedAt: Date = Date(),
        durationMs: Int? = nil,
        success: Bool,
        errorMessage: String? = nil,
        featureId: UUID? = nil,
        context: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.sessionIndex = sessionIndex
        self.toolName = toolName
        self.invokedAt = invokedAt
        self.durationMs = durationMs
        self.success = success
        self.errorMessage = errorMessage
        self.featureId = featureId
        self.context = context
    }

    // MARK: - GRDB Table Definition

    public static var databaseTableName: String { "tool_usage_logs" }

    public enum Columns: String, ColumnExpression {
        case id
        case projectId
        case sessionIndex
        case toolName
        case invokedAt
        case durationMs
        case success
        case errorMessage
        case featureId
        case context
    }

    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column(Columns.id.rawValue, .text).primaryKey()
            t.column(Columns.projectId.rawValue, .text).notNull().indexed().references(
                "project_specs", column: "id", onDelete: .cascade)
            t.column(Columns.sessionIndex.rawValue, .integer).notNull()
            t.column(Columns.toolName.rawValue, .text).notNull()
            t.column(Columns.invokedAt.rawValue, .datetime).notNull()
            t.column(Columns.durationMs.rawValue, .integer)
            t.column(Columns.success.rawValue, .boolean).notNull()
            t.column(Columns.errorMessage.rawValue, .text)
            t.column(Columns.featureId.rawValue, .text).indexed().references(
                "feature_test_cases", column: "id", onDelete: .setNull)
            t.column(Columns.context.rawValue, .text)
        }

        // Create indexes for common queries
        try db.create(
            index: "idx_tool_usage_logs_project_session", on: databaseTableName,
            columns: [Columns.projectId.rawValue, Columns.sessionIndex.rawValue], ifNotExists: true)
        try db.create(
            index: "idx_tool_usage_logs_tool_name", on: databaseTableName,
            columns: [Columns.toolName.rawValue], ifNotExists: true)
        try db.create(
            index: "idx_tool_usage_logs_invoked_at", on: databaseTableName,
            columns: [Columns.invokedAt.rawValue], ifNotExists: true)
    }
}

// MARK: - Store Extension for Tool Logging

extension ProjectHarnessStore {
    /// Logs tool usage.
    public func logToolUsage(_ log: ToolUsageLog) throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try dbPool.write { db in
            try log.insert(db)
        }
    }

    /// Gets tool usage statistics for a project.
    public func getToolUsageStats(projectId: UUID, sessionIndex: Int? = nil) throws -> [String:
        Sendable] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try dbPool.read { db in
            var request = ToolUsageLog.filter(
                ToolUsageLog.Columns.projectId == projectId.uuidString)

            if let sessionIndex = sessionIndex {
                request = request.filter(ToolUsageLog.Columns.sessionIndex == sessionIndex)
            }

            let logs = try request.fetchAll(db)

            // Calculate statistics
            let totalCalls = logs.count
            let successCalls = logs.filter { $0.success }.count
            let failureCalls = totalCalls - successCalls
            let successRate = totalCalls > 0 ? Double(successCalls) / Double(totalCalls) : 0.0

            let toolCounts = Dictionary(grouping: logs) { $0.toolName }
                .mapValues { $0.count }

            let avgDuration = logs.compactMap { $0.durationMs }.reduce(0, +)
            let avgDurationMs =
                logs.compactMap { $0.durationMs }.isEmpty
                ? 0 : avgDuration / logs.compactMap { $0.durationMs }.count

            return [
                "total_calls": totalCalls,
                "success_calls": successCalls,
                "failure_calls": failureCalls,
                "success_rate": successRate,
                "tool_counts": toolCounts,
                "avg_duration_ms": avgDurationMs,
                "logs": logs.prefix(100).map { log -> [String: Sendable] in
                    [
                        "tool": log.toolName,
                        "success": log.success,
                        "duration_ms": log.durationMs ?? 0,
                        "feature_id": log.featureId?.uuidString ?? "none",
                        "context": log.context ?? ""
                    ]
                }
            ]
        }
    }
}

public enum HarnessError: LocalizedError {
    case storeNotInitialized
    case projectNotFound(UUID)
    case featureNotFound(UUID)
    case invalidProjectState(String)

    public var errorDescription: String? {
        switch self {
        case .storeNotInitialized:
            return "Project harness store not initialized"
        case .projectNotFound(let id):
            return "Project not found: \(id)"
        case .featureNotFound(let id):
            return "Feature test case not found: \(id)"
        case .invalidProjectState(let message):
            return "Invalid project state: \(message)"
        }
    }
}
