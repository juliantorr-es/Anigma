//
//  ProjectHarnessStoreExtensions.swift
//  HarmoniaModule
//
//  Extensions for ProjectHarnessStore with behavioral history and session reports.
//

@preconcurrency import Foundation
@preconcurrency import GRDB

extension ProjectHarnessStore {
    public func updateFeatureBehavioralHistory(
        featureId: UUID,
        sessionIndex: Int,
        healthScore: Double,
        analysisRatio: Double,
        editCalls: Int,
        analysisCalls: Int,
        testCalls: Int,
        testsPassed: Bool? = nil,
        workSummary: String
    ) async throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try await dbPool.write { db in
            guard var feature = try FeatureTestCase.fetchOne(db, key: featureId) else {
                throw HarnessError.featureNotFound(featureId)
            }

            // Create new snapshot
            let snapshot = FeatureBehavioralSnapshot(
                sessionIndex: sessionIndex,
                healthScore: healthScore,
                analysisRatio: analysisRatio,
                editCalls: editCalls,
                analysisCalls: analysisCalls,
                testCalls: testCalls,
                testsPassed: testsPassed,
                timestamp: Date(),
                workSummary: workSummary
            )

            // Update behavioral history
            var history = feature.behavioralHistory ?? []
            history.append(snapshot)
            feature.behavioralHistory = history

            // Update sessions spent
            feature.sessionsSpent = (feature.sessionsSpent ?? 0) + 1

            // Save updated feature
            try feature.update(db)
        }
    }

    /// Marks a feature as completed with behavioral insights.
    public func completeFeature(
        featureId: UUID,
        completionNotes: String,
        healthScore: Double,
        testsPassed: Bool
    ) async throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try await dbPool.write { db in
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
                let avgHealthScore = history.map { $0.healthScore }.reduce(0, +) / Double(history.count)
                let avgAnalysisRatio = history.map { $0.analysisRatio }.reduce(0, +) / Double(history.count)
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

                feature.completionNotes = (feature.completionNotes ?? "") + "\n\n" + behavioralSummary
            }

            try feature.update(db)
        }
    }

    /// Gets behavioral insights for a feature.
    public func getFeatureBehavioralInsights(featureId: UUID) async throws -> [String: Any] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try await dbPool.read { db in
            guard let feature = try FeatureTestCase.fetchOne(db, key: featureId) else {
                throw HarnessError.featureNotFound(featureId)
            }

            guard let history = feature.behavioralHistory, !history.isEmpty else {
                return ["error": "No behavioral history available"]
            }

            // Calculate statistics
            let avgHealthScore = history.map { $0.healthScore }.reduce(0, +) / Double(history.count)
            let avgAnalysisRatio = history.map { $0.analysisRatio }.reduce(0, +) / Double(history.count)
            let totalEdits = history.map { $0.editCalls }.reduce(0, +)
            let totalAnalysis = history.map { $0.analysisCalls }.reduce(0, +)
            let totalTests = history.map { $0.testCalls }.reduce(0, +)

            // Find best and worst sessions
            let bestSession = history.max { $0.healthScore < $1.healthScore }
            let worstSession = history.min { $0.healthScore < $1.healthScore }

            // Calculate improvement trend
            let healthScores = history.sorted { $0.sessionIndex < $1.sessionIndex }.map { $0.healthScore }
            guard healthScores.count > 1, let improvementTrend = healthScores.last else {
                fatalError("Failed to unwrap improvementTrend")
            }

            // Analyze patterns
            let sessionsWithLowAnalysis = history.filter { $0.analysisRatio < 0.1 }.count
            let sessionsWithoutTests = history.filter { $0.testCalls == 0 && $0.editCalls > 0 }.count
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
                "best_session": bestSession.map { [
                    "session_index": $0.sessionIndex,
                    "health_score": $0.healthScore,
                    "analysis_ratio": $0.analysisRatio,
                    "work_summary": $0.workSummary
                ] } as Any,
                "worst_session": worstSession.map { [
                    "session_index": $0.sessionIndex,
                    "health_score": $0.healthScore,
                    "analysis_ratio": $0.analysisRatio,
                    "work_summary": $0.workSummary
                ] } as Any,
                "trends": [
                    "improvement_trend": improvementTrend,
                    "sessions_with_low_analysis": sessionsWithLowAnalysis,
                    "sessions_without_tests": sessionsWithoutTests,
                    "consistently_healthy_sessions": consistentlyHealthy,
                    "health_trend": healthScores
                ],
                "recommendations": self.generateFeatureRecommendations(
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

    private nonisolated func generateFeatureRecommendations(
        history: [FeatureBehavioralSnapshot],
        avgHealthScore: Double,
        sessionsWithLowAnalysis: Int,
        sessionsWithoutTests: Int
    ) -> [String] {
        var recommendations: [String] = []

        if avgHealthScore < 0.6 {
            recommendations.append("Feature development showed poor behavioral health - consider tightening prompts")
        }

        if sessionsWithLowAnalysis > history.count / 2 {
            recommendations.append("Multiple sessions had low analysis ratios - add analysis requirements to prompt")
        }

        if sessionsWithoutTests > 0 {
            recommendations.append("Some sessions made edits without running tests - enforce test requirements")
        }

        let healthTrend = history.sorted { $0.sessionIndex < $1.sessionIndex }.map { $0.healthScore }
        if healthTrend.count > 2 && healthTrend.last! < healthTrend.first! {
            recommendations.append("Health score declined over time - review prompt effectiveness")
        }

        if avgHealthScore >= 0.8 {
            recommendations.append("Excellent behavioral health - this prompt configuration works well for similar features")
        }

        return recommendations
    }
}

// MARK: - Store Extension for Session Reports

extension ProjectHarnessStore {
    /// Saves a session report.
    public func saveSessionReport(_ report: SessionReport) async throws {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        try await dbPool.write { db in
            try report.save(db)
        }
    }

    /// Gets session reports for a project.
    public func getSessionReports(projectId: UUID, limit: Int = 20) async throws -> [SessionReport] {
        guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

        return try await dbPool.read { db in
            try SessionReport
                .filter(SessionReport.Columns.projectId == projectId.uuidString)
                .order(SessionReport.Columns.sessionIndex.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}
