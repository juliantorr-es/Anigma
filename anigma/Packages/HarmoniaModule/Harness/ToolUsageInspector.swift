//
//  ToolUsageInspector.swift
//  HarmoniaModule
//
//  Inspector that checks for behavioral invariants - not vibes, assertions.
//

import Foundation
import GRDB

// MARK: - Behavioral Invariants

/// Invariants that define "healthy" harness behavior.
public struct BehavioralInvariants: Sendable {
    /// Maximum files that should be touched in a single session for one feature.
    public let maxFilesPerSession: Int

    /// Maximum edits before tests must be run.
    public let maxEditsBeforeTests: Int

    /// Whether analysis calls are required before edits.
    public let requireAnalysisBeforeEdits: Bool

    /// Minimum analysis ratio (analysis_calls / total_calls).
    public let minAnalysisRatio: Double

    /// Maximum first edit latency (analysis calls before first edit).
    public let maxFirstEditLatency: Int

    /// Minimum tool diversity for sessions with significant activity.
    public let minToolDiversity: Int

    public init(
        maxFilesPerSession: Int = 5,
        maxEditsBeforeTests: Int = 3,
        requireAnalysisBeforeEdits: Bool = true,
        minAnalysisRatio: Double = 0.1,
        maxFirstEditLatency: Int = 10,
        minToolDiversity: Int = 2
    ) {
        self.maxFilesPerSession = maxFilesPerSession
        self.maxEditsBeforeTests = maxEditsBeforeTests
        self.requireAnalysisBeforeEdits = requireAnalysisBeforeEdits
        self.minAnalysisRatio = minAnalysisRatio
        self.maxFirstEditLatency = maxFirstEditLatency
        self.minToolDiversity = minToolDiversity
    }

    /// Default invariants for a junior engineer pattern.
    public static let juniorEngineer = BehavioralInvariants(
        maxFilesPerSession: 5,
        maxEditsBeforeTests: 3,
        requireAnalysisBeforeEdits: true,
        minAnalysisRatio: 0.2,
        maxFirstEditLatency: 5,
        minToolDiversity: 3
    )

    /// Default invariants for a gremlin pattern (very permissive).
    public static let gremlin = BehavioralInvariants(
        maxFilesPerSession: 20,
        maxEditsBeforeTests: 10,
        requireAnalysisBeforeEdits: false,
        minAnalysisRatio: 0.0,
        maxFirstEditLatency: 100,
        minToolDiversity: 1
    )
}

// MARK: - Invariant Violation

/// A violation of a behavioral invariant.
public struct InvariantViolation: Codable, Sendable {
    public enum ViolationType: String, Codable, CaseIterable, Sendable {
        case editWithoutAnalysis = "edit_without_analysis"
        case tooManyEditsBeforeTests = "too_many_edits_before_tests"
        case lowAnalysisRatio = "low_analysis_ratio"
        case highFirstEditLatency = "high_first_edit_latency"
        case lowToolDiversity = "low_tool_diversity"
        case noTestsAfterEdits = "no_tests_after_edits"
    }

    /// Session index where violation occurred.
    public let sessionIndex: Int

    /// Type of violation.
    public let type: ViolationType

    /// Description of the violation.
    public let description: String

    /// Metrics at time of violation.
    public let metrics: BehavioralHealthMetrics

    /// Severity (0.0 = minor, 1.0 = critical).
    public let severity: Double

    public init(
        sessionIndex: Int,
        type: ViolationType,
        description: String,
        metrics: BehavioralHealthMetrics,
        severity: Double
    ) {
        self.sessionIndex = sessionIndex
        self.type = type
        self.description = description
        self.metrics = metrics
        self.severity = severity
    }
}

// MARK: - Tool Usage Inspector

/// Inspector that checks behavioral invariants.
public actor ToolUsageInspector {
    private let store: ProjectHarnessStore
    private let invariants: BehavioralInvariants

    public init(
        store: ProjectHarnessStore = .shared, invariants: BehavioralInvariants = .juniorEngineer
    ) {
        self.store = store
        self.invariants = invariants
    }

    /// Checks invariants for a specific session.
    public func checkSessionInvariants(
        projectId: UUID,
        sessionIndex: Int
    ) async throws -> [InvariantViolation] {
        let metrics = try await store.computeBehavioralMetrics(
            projectId: projectId,
            sessionIndex: sessionIndex
        )

        var violations: [InvariantViolation] = []

        // 1. Check for edits without analysis
        if invariants.requireAnalysisBeforeEdits && metrics.editCalls > 0
            && metrics.analysisCalls == 0 {
            violations.append(
                InvariantViolation(
                    sessionIndex: sessionIndex,
                    type: .editWithoutAnalysis,
                    description: "\(metrics.editCalls) edit calls with 0 analysis calls",
                    metrics: metrics,
                    severity: 0.9
                ))
        }

        // 2. Check for too many edits before tests
        if metrics.editCalls > invariants.maxEditsBeforeTests && metrics.testCalls == 0 {
            violations.append(
                InvariantViolation(
                    sessionIndex: sessionIndex,
                    type: .tooManyEditsBeforeTests,
                    description:
                        "\(metrics.editCalls) edits before any tests (max: \(invariants.maxEditsBeforeTests))",
                    metrics: metrics,
                    severity: 0.7
                ))
        }

        // 3. Check for low analysis ratio
        if metrics.analysisRatio < invariants.minAnalysisRatio
            && (metrics.editCalls + metrics.testCalls) > 0 {
            violations.append(
                InvariantViolation(
                    sessionIndex: sessionIndex,
                    type: .lowAnalysisRatio,
                    description: String(
                        format: "Analysis ratio %.2f < min %.2f", metrics.analysisRatio,
                        invariants.minAnalysisRatio),
                    metrics: metrics,
                    severity: 0.5
                ))
        }

        // 4. Check for high first edit latency (procrastination)
        if metrics.firstEditLatency > invariants.maxFirstEditLatency && metrics.editCalls > 0 {
            violations.append(
                InvariantViolation(
                    sessionIndex: sessionIndex,
                    type: .highFirstEditLatency,
                    description:
                        "First edit after \(metrics.firstEditLatency) analysis calls (max: \(invariants.maxFirstEditLatency))",
                    metrics: metrics,
                    severity: 0.4
                ))
        }

        // 5. Check for low tool diversity
        if metrics.toolDiversity < invariants.minToolDiversity
            && (metrics.editCalls + metrics.analysisCalls + metrics.testCalls) > 3 {
            violations.append(
                InvariantViolation(
                    sessionIndex: sessionIndex,
                    type: .lowToolDiversity,
                    description:
                        "Only \(metrics.toolDiversity) distinct tools used (min: \(invariants.minToolDiversity))",
                    metrics: metrics,
                    severity: 0.3
                ))
        }

        // 6. Check for no tests after edits
        if metrics.editCalls > 0 && metrics.testCalls == 0 {
            violations.append(
                InvariantViolation(
                    sessionIndex: sessionIndex,
                    type: .noTestsAfterEdits,
                    description: "\(metrics.editCalls) edits but 0 test calls",
                    metrics: metrics,
                    severity: 0.8
                ))
        }

        return violations
    }

    /// Checks invariants for all sessions in a project.
    public func checkProjectInvariants(projectId: UUID) async throws -> [InvariantViolation] {
        // Get all sessions for this project
        let toolLogs = try await store.getToolUsageStats(projectId: projectId)
        guard let logs = toolLogs["logs"] as? [[String: Any]] else {
            return []
        }

        // Extract unique session indices
        let sessionIndices = Set(logs.compactMap { $0["session"] as? Int })

        var allViolations: [InvariantViolation] = []

        for sessionIndex in sessionIndices.sorted() {
            let violations = try await checkSessionInvariants(
                projectId: projectId,
                sessionIndex: sessionIndex
            )
            allViolations.append(contentsOf: violations)
        }

        return allViolations
    }

    /// Gets a health report for a project.
    public func getHealthReport(projectId: UUID) async throws -> [String: Sendable] {
        let violations = try await checkProjectInvariants(projectId: projectId)
        let healthStats = try await store.getHealthStatistics(projectId: projectId)

        // Calculate violation statistics
        let criticalViolations = violations.filter { $0.severity >= 0.7 }.count
        let warningViolations = violations.filter { $0.severity >= 0.4 && $0.severity < 0.7 }.count
        let minorViolations = violations.filter { $0.severity < 0.4 }.count

        // Group violations by type
        let violationsByType = Dictionary(grouping: violations) { $0.type }
            .mapValues { $0.count }

        // Get recent violations
        let recentViolations = violations.sorted { $0.sessionIndex > $1.sessionIndex }
            .prefix(5)
            .map { violation -> [String: Sendable] in
                [
                    "session": violation.sessionIndex,
                    "type": violation.type.rawValue,
                    "description": violation.description,
                    "severity": violation.severity
                ]
            }

        let summary: [String: Sendable] = [
            "total": violations.count,
            "critical": criticalViolations,
            "warning": warningViolations,
            "minor": minorViolations,
            "by_type": violationsByType
        ]

        return [
            "violation_summary": summary,
            "recent_violations": recentViolations,
            "health_stats": healthStats,
            "assessment": getAssessment(violations: violations, healthStats: healthStats)
        ]
    }

    private func getAssessment(violations: [InvariantViolation], healthStats: [String: Any])
        -> String {
        guard let healthRate = healthStats["health_rate"] as? Double else {
            return "❓ Insufficient data"
        }

        let criticalViolations = violations.filter { $0.severity >= 0.7 }.count

        if healthRate >= 0.8 && criticalViolations == 0 {
            return "✅ Excellent: Junior engineer behavior"
        } else if healthRate >= 0.6 && criticalViolations <= 1 {
            return "⚠️  Good: Mostly disciplined with minor issues"
        } else if healthRate >= 0.4 {
            return "⚠️  Concerning: Pattern issues need attention"
        } else if criticalViolations > 3 {
            return "❌ Critical: Gremlin behavior detected"
        } else {
            return "❌ Unhealthy: Needs prompt/architecture tuning"
        }
    }

    /// Exports behavioral data as CSV for analysis.
    public func exportBehavioralCSV(projectId: UUID) async throws -> String {
        let metrics = try await store.getBehavioralMetrics(projectId: projectId)

        var csv =
            "session_index,analysis_ratio,first_edit_latency,tool_diversity,edit_calls,analysis_calls,test_calls,health_score,is_healthy\n"

        for metric in metrics.sorted(by: { $0.sessionIndex < $1.sessionIndex }) {
            csv += "\(metric.sessionIndex),"
            csv += String(format: "%.3f,", metric.analysisRatio)
            csv += "\(metric.firstEditLatency),"
            csv += "\(metric.toolDiversity),"
            csv += "\(metric.editCalls),"
            csv += "\(metric.analysisCalls),"
            csv += "\(metric.testCalls),"
            csv += String(format: "%.3f,", metric.healthScore)
            csv += "\(metric.isHealthy)\n"
        }

        return csv
    }

    /// Runs A/B comparison between two configurations with judgemental verdicts.
    public func runABComparison(
        projectIdA: UUID,
        projectIdB: UUID,
        labelA: String = "Config A",
        labelB: String = "Config B"
    ) async throws -> ABComparisonResult {
        let statsA = try await store.getHealthStatistics(projectId: projectIdA)
        let statsB = try await store.getHealthStatistics(projectId: projectIdB)

        let violationsA = try await checkProjectInvariants(projectId: projectIdA)
        let violationsB = try await checkProjectInvariants(projectId: projectIdB)

        let criticalA = violationsA.filter { $0.severity >= 0.7 }.count
        let criticalB = violationsB.filter { $0.severity >= 0.7 }.count

        let healthRateA = statsA["health_rate"] as? Double ?? 0.0
        let healthRateB = statsB["health_rate"] as? Double ?? 0.0

        let avgAnalysisRatioA = statsA["avg_analysis_ratio"] as? Double ?? 0.0
        let avgAnalysisRatioB = statsB["avg_analysis_ratio"] as? Double ?? 0.0

        let avgHealthScoreA = statsA["avg_health_score"] as? Double ?? 0.0
        let avgHealthScoreB = statsB["avg_health_score"] as? Double ?? 0.0

        let avgFirstEditLatencyA = statsA["avg_first_edit_latency"] as? Double ?? 0.0
        let avgFirstEditLatencyB = statsB["avg_first_edit_latency"] as? Double ?? 0.0

        let avgToolDiversityA = statsA["avg_tool_diversity"] as? Double ?? 0.0
        let avgToolDiversityB = statsB["avg_tool_diversity"] as? Double ?? 0.0

        // Calculate differences
        let healthRateDiff = healthRateB - healthRateA
        let analysisRatioDiff = avgAnalysisRatioB - avgAnalysisRatioA
        let healthScoreDiff = avgHealthScoreB - avgHealthScoreA
        let criticalViolationsDiff = criticalB - criticalA

        // Generate judgemental verdict
        let verdict = generateJudgementalVerdict(
            healthRateA: healthRateA,
            healthRateB: healthRateB,
            healthRateDiff: healthRateDiff,
            criticalA: criticalA,
            criticalB: criticalB,
            analysisRatioA: avgAnalysisRatioA,
            analysisRatioB: avgAnalysisRatioB,
            analysisRatioDiff: analysisRatioDiff,
            labelA: labelA,
            labelB: labelB
        )

        // Generate concrete recommendations
        let recommendations = generateABRecommendations(
            statsA: statsA,
            statsB: statsB,
            violationsA: violationsA,
            violationsB: violationsB,
            labelA: labelA,
            labelB: labelB
        )

        // Generate improvement assessment
        let improvement = assessImprovement(
            healthRateDiff: healthRateDiff,
            criticalViolationsDiff: criticalViolationsDiff,
            analysisRatioDiff: analysisRatioDiff
        )

        let winner: String
        if healthRateDiff > 0 {
            winner = labelB
        } else if healthRateDiff < 0 {
            winner = labelA
        } else {
            winner = "tie"
        }

        return ABComparisonResult(
            configA: labelA,
            configB: labelB,
            metrics: [
                "health_rate": MetricComparison(
                    a: healthRateA, b: healthRateB, difference: healthRateDiff),
                "avg_analysis_ratio": MetricComparison(
                    a: avgAnalysisRatioA, b: avgAnalysisRatioB, difference: analysisRatioDiff),
                "avg_health_score": MetricComparison(
                    a: avgHealthScoreA, b: avgHealthScoreB, difference: healthScoreDiff),
                "avg_first_edit_latency": MetricComparison(
                    a: avgFirstEditLatencyA, b: avgFirstEditLatencyB,
                    difference: avgFirstEditLatencyB - avgFirstEditLatencyA),
                "avg_tool_diversity": MetricComparison(
                    a: avgToolDiversityA, b: avgToolDiversityB,
                    difference: avgToolDiversityB - avgToolDiversityA),
                "critical_violations": MetricComparison(
                    a: Double(criticalA), b: Double(criticalB),
                    difference: Double(criticalViolationsDiff))
            ],
            verdict: verdict,
            recommendations: recommendations,
            improvement: improvement,
            winner: winner
        )
    }

    private func generateJudgementalVerdict(
        healthRateA: Double,
        healthRateB: Double,
        healthRateDiff: Double,
        criticalA: Int,
        criticalB: Int,
        analysisRatioA: Double,
        analysisRatioB: Double,
        analysisRatioDiff: Double,
        labelA: String,
        labelB: String
    ) -> String {
        var verdict = ""
        if healthRateDiff > 0.2 {
            verdict +=
                "🔥 **DRAMATIC IMPROVEMENT**: \(labelB) is \(String(format: "%.0f%%", healthRateDiff * 100)) better than \(labelA). "
        } else if healthRateDiff > 0.1 {
            verdict += "✅ **CLEAR WINNER**: \(labelB) shows meaningful improvement over \(labelA). "
        } else if healthRateDiff > 0.05 {
            verdict += "⚠️  **SLIGHT EDGE**: \(labelB) is marginally better than \(labelA). "
        } else if abs(healthRateDiff) <= 0.05 {
            verdict += "⚖️  **STATISTICAL TIE**: Both configurations perform similarly. "
        } else if healthRateDiff < -0.1 {
            verdict +=
                "❌ **SIGNIFICANT REGRESSION**: \(labelB) is \(String(format: "%.0f%%", -healthRateDiff * 100)) worse than \(labelA). "
        } else {
            verdict += "⚠️  **MINOR REGRESSION**: \(labelB) is slightly worse than \(labelA). "
        }

        // Critical violations comparison
        if criticalB == 0 && criticalA > 0 {
            verdict +=
                "🎯 **CRITICAL FIX**: \(labelB) eliminated all critical violations that plagued \(labelA). "
        } else if criticalB < criticalA {
            verdict +=
                "👍 **IMPROVEMENT**: \(labelB) reduced critical violations from \(criticalA) to \(criticalB). "
        } else if criticalB > criticalA {
            verdict +=
                "👎 **REGRESSION**: \(labelB) introduced more critical violations (\(criticalB) vs \(criticalA)). "
        }

        // Analysis behavior comparison
        if analysisRatioDiff > 0.1 {
            verdict +=
                "🧠 **SMARTER ANALYSIS**: \(labelB) uses \(String(format: "%.0f%%", analysisRatioDiff * 100)) more analysis before editing. "
        } else if analysisRatioDiff < -0.1 {
            verdict +=
                "🤔 **LESS THOUGHTFUL**: \(labelB) uses \(String(format: "%.0f%%", -analysisRatioDiff * 100)) less analysis than \(labelA). "
        }

        // Overall judgement
        if healthRateB >= 0.8 && criticalB == 0 {
            verdict +=
                "🏆 **CHAMPION CONFIG**: \(labelB) achieves junior engineer behavior consistently. "
        } else if healthRateB >= 0.6 && criticalB <= 1 {
            verdict += "👍 **SOLID CONFIG**: \(labelB) shows good discipline with minor issues. "
        } else if healthRateB < 0.4 || criticalB > 2 {
            verdict += "🚨 **PROBLEMATIC CONFIG**: \(labelB) exhibits gremlin-like behavior. "
        }

        return verdict
    }

    private func generateABRecommendations(
        statsA: [String: Any],
        statsB: [String: Any],
        violationsA: [InvariantViolation],
        violationsB: [InvariantViolation],
        labelA: String,
        labelB: String
    ) -> [String] {
        var recommendations: [String] = []

        // Compare health rates
        let healthRateA = statsA["health_rate"] as? Double ?? 0.0
        let healthRateB = statsB["health_rate"] as? Double ?? 0.0

        if healthRateB > healthRateA {
            recommendations.append(
                "**Adopt \(labelB) configuration** - it achieves \(String(format: "%.0f%%", (healthRateB - healthRateA) * 100)) better health rate"
            )
        }

        // Compare critical violations
        let criticalA = violationsA.filter { $0.severity >= 0.7 }.count
        let criticalB = violationsB.filter { $0.severity >= 0.7 }.count

        if criticalB < criticalA {
            recommendations.append(
                "**Use \(labelB)'s approach to critical violations** - reduced from \(criticalA) to \(criticalB)"
            )
        } else if criticalB > criticalA {
            recommendations.append(
                "**Avoid \(labelB)'s violation pattern** - increased critical violations from \(criticalA) to \(criticalB)"
            )
        }

        // Compare analysis ratios
        let analysisRatioA = statsA["avg_analysis_ratio"] as? Double ?? 0.0
        let analysisRatioB = statsB["avg_analysis_ratio"] as? Double ?? 0.0

        if analysisRatioB > analysisRatioA && analysisRatioB < 0.3 {
            recommendations.append(
                "**Increase analysis ratio further** - \(labelB)'s \(String(format: "%.0f%%", analysisRatioB * 100)) is better but still below ideal 30%"
            )
        }

        // Compare tool diversity
        let toolDiversityA = statsA["avg_tool_diversity"] as? Double ?? 0.0
        let toolDiversityB = statsB["avg_tool_diversity"] as? Double ?? 0.0

        if toolDiversityB > toolDiversityA && toolDiversityB < 4.0 {
            recommendations.append(
                "**Expand tool usage** - \(labelB)'s \(String(format: "%.1f", toolDiversityB)) tools is better but aim for 4+ distinct tools"
            )
        }

        // Specific violation improvements
        let violationTypesA = Set(violationsA.map { $0.type })
        let violationTypesB = Set(violationsB.map { $0.type })

        let fixedViolations = violationTypesA.subtracting(violationTypesB)
        let newViolations = violationTypesB.subtracting(violationTypesA)

        for violation in fixedViolations {
            recommendations.append(
                "**Keep \(labelB)'s fix for \(violation.rawValue)** - successfully eliminated this violation"
            )
        }

        for violation in newViolations {
            recommendations.append(
                "**Address \(labelB)'s new \(violation.rawValue) violation** - this regression needs attention"
            )
        }

        // Configuration-specific recommendations
        if healthRateB >= 0.8 {
            recommendations.append(
                "**Standardize on \(labelB) as baseline** - it demonstrates consistent junior engineer behavior"
            )
        } else if healthRateB < 0.5 {
            recommendations.append(
                "**Avoid \(labelB) in production** - health rate below 50% indicates fundamental issues"
            )
        }

        return recommendations
    }

    private func assessImprovement(
        healthRateDiff: Double,
        criticalViolationsDiff: Int,
        analysisRatioDiff: Double
    ) -> String {
        var improvements: [String] = []

        if healthRateDiff > 0.15 {
            improvements.append("major health improvement")
        } else if healthRateDiff > 0.05 {
            improvements.append("moderate health improvement")
        }

        if criticalViolationsDiff < 0 {
            improvements.append("reduced critical violations")
        } else if criticalViolationsDiff > 0 {
            improvements.append("more critical violations")
        }

        if analysisRatioDiff > 0.1 {
            improvements.append("better analysis behavior")
        } else if analysisRatioDiff < -0.1 {
            improvements.append("worse analysis behavior")
        }

        if improvements.isEmpty {
            return "No significant changes detected"
        }

        return "Improvements: " + improvements.joined(separator: ", ")
    }
}

// MARK: - A/B Comparison Result

/// Result of A/B comparison with judgemental verdicts.
public struct ABComparisonResult: Sendable {
    /// Configuration A label.
    public let configA: String

    /// Configuration B label.
    public let configB: String

    /// Comparison metrics.
    public let metrics: [String: MetricComparison]

    /// Judgemental verdict.
    public let verdict: String

    /// Concrete recommendations.
    public let recommendations: [String]

    /// Improvement assessment.
    public let improvement: String

    /// Winning configuration.
    public let winner: String

    public init(
        configA: String,
        configB: String,
        metrics: [String: MetricComparison],
        verdict: String,
        recommendations: [String],
        improvement: String,
        winner: String
    ) {
        self.configA = configA
        self.configB = configB
        self.metrics = metrics
        self.verdict = verdict
        self.recommendations = recommendations
        self.improvement = improvement
        self.winner = winner
    }

    /// Returns a markdown-formatted comparison report.
    public var markdownReport: String {
        var markdown = "# A/B Comparison Report\n\n"
        markdown += "**Config A**: \(configA)  \n"
        markdown += "**Config B**: \(configB)  \n"
        markdown += "**Winner**: \(winner)  \n\n"

        markdown += "## 🏆 Verdict\n\n"
        markdown += "\(verdict)\n\n"

        markdown += "## 📊 Metrics Comparison\n\n"
        markdown += "| Metric | Config A | Config B | Difference |\n"
        markdown += "|--------|----------|----------|------------|\n"

        for (metricName, comparison) in metrics.sorted(by: { $0.key < $1.key }) {
            let aStr = formatValue(comparison.a)
            let bStr = formatValue(comparison.b)
            let diffStr = formatValue(comparison.difference)

            markdown += "| \(metricName) | \(aStr) | \(bStr) | \(diffStr) |\n"
        }
        markdown += "\n"

        markdown += "## 💡 Recommendations\n\n"
        for (index, recommendation) in recommendations.enumerated() {
            markdown += "\(index + 1). \(recommendation)  \n"
        }
        markdown += "\n"

        markdown += "## 📈 Improvement Assessment\n\n"
        markdown += "\(improvement)\n"

        return markdown
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 0 {
            return String(format: "+%.3f", value)
        } else {
            return String(format: "%.3f", value)
        }
    }
}

/// Metric comparison for A/B testing.
public struct MetricComparison: Sendable {
    public let a: Double
    public let b: Double
    public let difference: Double

    public init(a: Double, b: Double, difference: Double) {
        self.a = a
        self.b = b
        self.difference = difference
    }
}
