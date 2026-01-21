//
//  BehavioralHealthMetrics.swift
//  HarmoniaModule
//
//  Metrics for evaluating harness behavior - not vibes, data.
//

import Foundation
import GRDB

// MARK: - Git Diff Summary

/// Summary of git diff changes.
public struct GitDiffSummary: Codable, Sendable {
    /// Files added.
    public let filesAdded: Int

    /// Files modified.
    public let filesModified: Int

    /// Files deleted.
    public let filesDeleted: Int

    /// Lines added.
    public let linesAdded: Int

    /// Lines removed.
    public let linesRemoved: Int

    /// Whether changes are surgical (few files, focused).
    public let isSurgical: Bool

    /// Whether changes are thrash (many files, scattered).
    public let isThrash: Bool

    /// Change concentration score (0.0 = scattered, 1.0 = focused).
    public let changeConcentration: Double

    public init(
        filesAdded: Int,
        filesModified: Int,
        filesDeleted: Int,
        linesAdded: Int,
        linesRemoved: Int
    ) {
        self.filesAdded = filesAdded
        self.filesModified = filesModified
        self.filesDeleted = filesDeleted
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved

        let totalFiles = filesAdded + filesModified + filesDeleted
        let totalLines = linesAdded + linesRemoved

        // Calculate surgical vs thrash
        self.isSurgical = totalFiles <= 3 && totalLines <= 50
        self.isThrash = totalFiles > 10 || totalLines > 200

        // Calculate change concentration
        if totalFiles > 0 {
            let avgLinesPerFile = Double(totalLines) / Double(totalFiles)
            self.changeConcentration = min(avgLinesPerFile / 50.0, 1.0)  // More lines per file = more concentrated
        } else {
            self.changeConcentration = 0.0
        }
    }
}

// MARK: - Behavioral Health Metrics

/// Metrics for evaluating harness behavior per session.
public struct BehavioralHealthMetrics: Codable, Sendable {
    /// Session index.
    public let sessionIndex: Int

    /// Project identifier.
    public let projectId: UUID

    /// Feature being worked on (if any).
    public let featureId: UUID?

    /// Analysis ratio: analysis_calls / (analysis_calls + edit_calls)
    public let analysisRatio: Double

    /// First-edit latency: how many analysis calls before first edit
    public let firstEditLatency: Int

    /// Tool diversity: number of distinct tools used
    public let toolDiversity: Int

    /// Edit calls count.
    public let editCalls: Int

    /// Analysis calls count.
    public let analysisCalls: Int

    /// Test calls count.
    public let testCalls: Int

    /// Files changed (from git diff).
    public let filesChanged: Int?

    /// Lines changed (from git diff).
    public let linesChanged: Int?

    /// Tests passed.
    public let testsPassed: Int?

    /// Tests failed.
    public let testsFailed: Int?

    /// Whether formatter succeeded.
    public var formatterSucceeded: Bool?

    /// Formatter warnings count.
    public var formatterWarnings: Int?

    /// Formatter errors count.
    public var formatterErrors: Int?

    /// Git diff summary.
    public let gitDiffSummary: GitDiffSummary?

    /// Whether linting succeeded.
    public var lintSucceeded: Bool?

    /// Lint warnings count.
    public var lintWarnings: Int?

    /// Lint errors count.
    public var lintErrors: Int?

    /// Timestamp.
    public let timestamp: Date

    public init(
        sessionIndex: Int,
        projectId: UUID,
        featureId: UUID? = nil,
        analysisRatio: Double,
        firstEditLatency: Int,
        toolDiversity: Int,
        editCalls: Int,
        analysisCalls: Int,
        testCalls: Int,
        filesChanged: Int? = nil,
        linesChanged: Int? = nil,
        testsPassed: Int? = nil,
        testsFailed: Int? = nil,
        formatterSucceeded: Bool? = nil,
        formatterWarnings: Int? = nil,
        formatterErrors: Int? = nil,
        gitDiffSummary: GitDiffSummary? = nil,
        lintSucceeded: Bool? = nil,
        lintWarnings: Int? = nil,
        lintErrors: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.sessionIndex = sessionIndex
        self.projectId = projectId
        self.featureId = featureId
        self.analysisRatio = analysisRatio
        self.firstEditLatency = firstEditLatency
        self.toolDiversity = toolDiversity
        self.editCalls = editCalls
        self.analysisCalls = analysisCalls
        self.testCalls = testCalls
        self.filesChanged = filesChanged
        self.linesChanged = linesChanged
        self.testsPassed = testsPassed
        self.testsFailed = testsFailed
        self.formatterSucceeded = formatterSucceeded
        self.formatterWarnings = formatterWarnings
        self.formatterErrors = formatterErrors
        self.gitDiffSummary = gitDiffSummary
        self.lintSucceeded = lintSucceeded
        self.lintWarnings = lintWarnings
        self.lintErrors = lintErrors
        self.timestamp = timestamp
    }

    /// Whether this session shows healthy behavior.
    public var isHealthy: Bool {
        // 1. No edits without analysis
        if editCalls > 0 && analysisCalls == 0 {
            return false
        }

        // 2. Reasonable analysis ratio (at least some analysis before edits)
        if analysisRatio < 0.1 && editCalls > 0 {
            return false
        }

        // 3. Tests were run if edits were made
        if editCalls > 2 && testCalls == 0 {
            return false
        }

        // 4. First edit latency reasonable (not zero, not huge)
        if firstEditLatency == 0 && editCalls > 0 {
            return false
        }

        // 5. Tool diversity reasonable (not just one tool)
        if toolDiversity < 2 && (editCalls + analysisCalls + testCalls) > 3 {
            return false
        }

        // 6. Formatter should succeed if run
        if let formatterSucceeded = formatterSucceeded, !formatterSucceeded {
            return false
        }

        // 7. Lint should succeed if run
        if let lintSucceeded = lintSucceeded, !lintSucceeded {
            return false
        }

        // 8. Avoid massive changes without analysis
        if let gitDiffSummary = gitDiffSummary {
            let totalLines = gitDiffSummary.linesAdded + gitDiffSummary.linesRemoved
            if totalLines > 200 && analysisCalls < 5 {
                return false
            }
        }

        return true
    }

    /// Health score from 0.0 (gremlin) to 1.0 (junior engineer).
    public var healthScore: Double {
        var score = 0.0
        var weightTotal = 0.0

        // 1. Analysis ratio weight: 25%
        let analysisScore = min(analysisRatio * 3.0, 1.0)  // Want at least 0.33 ratio
        score += analysisScore * 0.25
        weightTotal += 0.25

        // 2. First edit latency weight: 15%
        let latencyScore: Double
        if firstEditLatency == 0 {
            latencyScore = 0.0
        } else if firstEditLatency <= 3 {
            latencyScore = 1.0
        } else if firstEditLatency <= 10 {
            latencyScore = 0.5
        } else {
            latencyScore = 0.1
        }
        score += latencyScore * 0.15
        weightTotal += 0.15

        // 3. Tool diversity weight: 15%
        let diversityScore = min(Double(toolDiversity) / 4.0, 1.0)  // Want at least 4 tools
        score += diversityScore * 0.15
        weightTotal += 0.15

        // 4. Test coverage weight: 20%
        let testScore: Double
        if editCalls == 0 {
            testScore = 1.0  // No edits, no tests needed
        } else if testCalls == 0 {
            testScore = 0.0
        } else {
            testScore = min(Double(testCalls) / Double(editCalls), 1.0)  // At least 1 test per edit
        }
        score += testScore * 0.20
        weightTotal += 0.20

        // 5. Formatter success weight: 10%
        let formatterScore: Double
        if let formatterSucceeded = formatterSucceeded {
            formatterScore = formatterSucceeded ? 1.0 : 0.0
            // Penalize for warnings/errors
            let warningPenalty = min(Double(formatterWarnings ?? 0) * 0.1, 0.3)
            let errorPenalty = min(Double(formatterErrors ?? 0) * 0.3, 0.7)
            score += max(0, formatterScore - warningPenalty - errorPenalty) * 0.10
        } else {
            formatterScore = 0.5  // Neutral if not measured
            score += formatterScore * 0.10
        }
        weightTotal += 0.10

        // 6. Lint success weight: 10%
        let lintScore: Double
        if let lintSucceeded = lintSucceeded {
            lintScore = lintSucceeded ? 1.0 : 0.0
            // Penalize for warnings/errors
            let warningPenalty = min(Double(lintWarnings ?? 0) * 0.05, 0.2)
            let errorPenalty = min(Double(lintErrors ?? 0) * 0.2, 0.8)
            score += max(0, lintScore - warningPenalty - errorPenalty) * 0.10
        } else {
            lintScore = 0.5  // Neutral if not measured
            score += lintScore * 0.10
        }
        weightTotal += 0.10

        // 7. Git diff quality weight: 5%
        let gitDiffScore: Double
        if let gitDiffSummary = gitDiffSummary {
            // Reward surgical changes, penalize thrash
            var diffScore = 0.5  // Base score

            if gitDiffSummary.isSurgical {
                diffScore += 0.3
            }
            if gitDiffSummary.isThrash {
                diffScore -= 0.3
            }

            // Reward concentrated changes
            diffScore += gitDiffSummary.changeConcentration * 0.2

            // Penalize massive changes without corresponding analysis
            if gitDiffSummary.linesAdded + gitDiffSummary.linesRemoved > 100 && analysisCalls < 3 {
                diffScore -= 0.2
            }

            gitDiffScore = max(0, min(diffScore, 1.0))
        } else {
            gitDiffScore = 0.5  // Neutral if not measured
        }
        score += gitDiffScore * 0.05
        weightTotal += 0.05

        // Normalize by actual weight total
        return score / weightTotal
    }

    /// Returns a human-readable health assessment.
    public var healthAssessment: String {
        let score = healthScore

        switch score {
        case 0.8...1.0:
            return "✅ Healthy (junior engineer behavior)"
        case 0.6..<0.8:
            return "⚠️  Moderate (needs improvement)"
        case 0.4..<0.6:
            return "⚠️  Concerning (pattern issues)"
        case 0.2..<0.4:
            return "❌ Unhealthy (gremlin behavior)"
        default:
            return "❌ Critical (broken behavior)"
        }
    }
}

// MARK: - GRDB Integration

extension BehavioralHealthMetrics: TableRecord, FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "behavioral_health_metrics" }

    public enum Columns: String, ColumnExpression {
        case sessionIndex
        case projectId
        case featureId
        case analysisRatio
        case firstEditLatency
        case toolDiversity
        case editCalls
        case analysisCalls
        case testCalls
        case filesChanged
        case linesChanged
        case testsPassed
        case testsFailed
        case formatterSucceeded
        case formatterWarnings
        case formatterErrors
        case gitDiffSummary
        case lintSucceeded
        case lintWarnings
        case lintErrors
        case timestamp
    }

    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column(Columns.sessionIndex.rawValue, .integer).notNull()
            t.column(Columns.projectId.rawValue, .text).notNull().indexed()
            t.column(Columns.featureId.rawValue, .text).indexed()
            t.column(Columns.analysisRatio.rawValue, .double).notNull()
            t.column(Columns.firstEditLatency.rawValue, .integer).notNull()
            t.column(Columns.toolDiversity.rawValue, .integer).notNull()
            t.column(Columns.editCalls.rawValue, .integer).notNull()
            t.column(Columns.analysisCalls.rawValue, .integer).notNull()
            t.column(Columns.testCalls.rawValue, .integer).notNull()
            t.column(Columns.filesChanged.rawValue, .integer)
            t.column(Columns.linesChanged.rawValue, .integer)
            t.column(Columns.testsPassed.rawValue, .integer)
            t.column(Columns.testsFailed.rawValue, .integer)
            t.column(Columns.formatterSucceeded.rawValue, .boolean)
            t.column(Columns.formatterWarnings.rawValue, .integer)
            t.column(Columns.formatterErrors.rawValue, .integer)
            t.column(Columns.gitDiffSummary.rawValue, .text)
            t.column(Columns.lintSucceeded.rawValue, .boolean)
            t.column(Columns.lintWarnings.rawValue, .integer)
            t.column(Columns.lintErrors.rawValue, .integer)
            t.column(Columns.timestamp.rawValue, .datetime).notNull()
        }

        // Create indexes for common queries
        try db.create(
            index: "idx_behavioral_metrics_project_session", on: databaseTableName,
            columns: [Columns.projectId.rawValue, Columns.sessionIndex.rawValue], unique: true,
            ifNotExists: true)
        try db.create(
            index: "idx_behavioral_metrics_health_score", on: databaseTableName,
            columns: [Columns.analysisRatio.rawValue, Columns.firstEditLatency.rawValue],
            ifNotExists: true)
    }
}

// MARK: - Store Extension for Behavioral Metrics

extension ProjectHarnessStore {
    /// Computes behavioral health metrics for a session.
    public func computeBehavioralMetrics(
        projectId: UUID,
        sessionIndex: Int,
        featureId: UUID? = nil
    ) throws -> BehavioralHealthMetrics {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try dbPool.read { db in
            // Get all tool logs for this session
            let logs =
                try ToolUsageLog
                .filter(ToolUsageLog.Columns.projectId == projectId.uuidString)
                .filter(ToolUsageLog.Columns.sessionIndex == sessionIndex)
                .fetchAll(db)

            // Categorize tools
            let analysisTools = Set(["code_question", "code_search", "symbol_lookup"])
            let editTools = Set(["write_file"])
            let testTools = Set(["run_tests"])

            var analysisCalls = 0
            var editCalls = 0
            var testCalls = 0
            var firstEditIndex: Int?
            var toolNames = Set<String>()

            for (index, log) in logs.enumerated() {
                toolNames.insert(log.toolName)

                if analysisTools.contains(log.toolName) {
                    analysisCalls += 1
                } else if editTools.contains(log.toolName) {
                    editCalls += 1
                    if firstEditIndex == nil {
                        firstEditIndex = index
                    }
                } else if testTools.contains(log.toolName) {
                    testCalls += 1
                }
            }

            // Calculate metrics
            let totalCalls = analysisCalls + editCalls + testCalls
            let analysisRatio = totalCalls > 0 ? Double(analysisCalls) / Double(totalCalls) : 0.0
            let firstEditLatency = firstEditIndex ?? 0

            // Get test results from progress snapshot
            let testResults =
                try? ProjectProgressSnapshot
                .filter(ProjectProgressSnapshot.Columns.projectId == projectId.uuidString)
                .filter(ProjectProgressSnapshot.Columns.sessionIndex == sessionIndex)
                .fetchOne(db)

            // Parse test results from snapshot (simplified)
            var testsPassed: Int?
            var testsFailed: Int?

            if let testResultsJson = testResults?.testResults,
                let data = testResultsJson.data(using: .utf8),
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                testsPassed = dict["passed"] as? Int
                testsFailed = dict["failed"] as? Int
            }

            return BehavioralHealthMetrics(
                sessionIndex: sessionIndex,
                projectId: projectId,
                featureId: featureId,
                analysisRatio: analysisRatio,
                firstEditLatency: firstEditLatency,
                toolDiversity: toolNames.count,
                editCalls: editCalls,
                analysisCalls: analysisCalls,
                testCalls: testCalls,
                filesChanged: nil,  // Will be populated from git diff
                linesChanged: nil,  // Will be populated from git diff
                testsPassed: testsPassed,
                testsFailed: testsFailed,
                formatterSucceeded: nil,  // Will be populated from formatter step
                formatterWarnings: nil,
                formatterErrors: nil,
                gitDiffSummary: nil,
                lintSucceeded: nil,
                lintWarnings: nil,
                lintErrors: nil
            )
        }
    }

    /// Saves behavioral health metrics.
    public func saveBehavioralMetrics(_ metrics: BehavioralHealthMetrics) throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try dbPool.write { db in
            try metrics.save(db)
        }
    }

    /// Gets behavioral metrics for a project.
    public func getBehavioralMetrics(projectId: UUID, limit: Int = 20) throws
        -> [BehavioralHealthMetrics] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try dbPool.read { db in
            try BehavioralHealthMetrics
                .filter(BehavioralHealthMetrics.Columns.projectId == projectId.uuidString)
                .order(BehavioralHealthMetrics.Columns.sessionIndex.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Gets health statistics for a project.
    public func getHealthStatistics(projectId: UUID) throws -> [String: Sendable] {
        let metrics = try getBehavioralMetrics(projectId: projectId, limit: 100)

        guard !metrics.isEmpty else {
            return ["error": "No metrics available"]
        }

        let healthySessions = metrics.filter { $0.isHealthy }.count
        let healthRate = Double(healthySessions) / Double(metrics.count)

        let avgAnalysisRatio = metrics.map { $0.analysisRatio }.reduce(0, +) / Double(metrics.count)
        let avgFirstEditLatency =
            Double(metrics.map { $0.firstEditLatency }.reduce(0, +)) / Double(metrics.count)
        let avgToolDiversity =
            Double(metrics.map { $0.toolDiversity }.reduce(0, +)) / Double(metrics.count)
        let avgHealthScore = metrics.map { $0.healthScore }.reduce(0, +) / Double(metrics.count)

        // Find problematic sessions
        let problematicSessions = metrics.filter { !$0.isHealthy }.map { $0.sessionIndex }

        return [
            "total_sessions": metrics.count,
            "healthy_sessions": healthySessions,
            "health_rate": healthRate,
            "avg_analysis_ratio": avgAnalysisRatio,
            "avg_first_edit_latency": avgFirstEditLatency,
            "avg_tool_diversity": avgToolDiversity,
            "avg_health_score": avgHealthScore,
            "problematic_sessions": problematicSessions,
            "recent_metrics": metrics.prefix(5).map { metric -> [String: Sendable] in
                [
                    "session": metric.sessionIndex,
                    "health_score": metric.healthScore,
                    "analysis_ratio": metric.analysisRatio,
                    "first_edit_latency": metric.firstEditLatency,
                    "tool_diversity": metric.toolDiversity,
                    "is_healthy": metric.isHealthy
                ]
            }
        ]
    }
}
