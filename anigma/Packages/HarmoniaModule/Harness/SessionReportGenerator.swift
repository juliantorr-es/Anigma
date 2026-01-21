//
//  SessionReportGenerator.swift
//  HarmoniaModule
//
//  Generates narrative session reports with health metrics as the spine.
//  Turns data into stories that can't be ignored.
//

import Foundation
import GRDB

// MARK: - Session Report

/// Comprehensive session report with narrative structure.
public struct SessionReport: Codable, Sendable, TableRecord, FetchableRecord, PersistableRecord {
  /// Session index.
  public let sessionIndex: Int

  /// Project identifier.
  public let projectId: UUID

  /// Feature being worked on (if any).
  public let featureId: UUID?

  /// Behavioral health metrics.
  public let metrics: BehavioralHealthMetrics

  /// Invariant violations (if any).
  public let violations: [InvariantViolation]

  /// Tool usage summary.
  public let toolSummary: [String: Int]

  /// Narrative summary of the session.
  public let narrative: String

  /// Recommendations for improvement.
  public let recommendations: [String]

  /// Health verdict.
  public let verdict: String

  /// When the report was generated.
  public let generatedAt: Date

  /// When the session was acknowledged by a human (nil = unacknowledged).
  public var acknowledgedAt: Date?

  /// Config ID used for this session (for bandit learning).
  public let configId: String?

  /// Feature category (e.g., "ui", "backend") for bandit learning.
  public let featureCategory: String?

  /// Governance trace - decisions made by the angelic hierarchy.
  public var governanceTrace: GovernanceTrace?

  public init(
    sessionIndex: Int,
    projectId: UUID,
    featureId: UUID? = nil,
    metrics: BehavioralHealthMetrics,
    violations: [InvariantViolation],
    toolSummary: [String: Int],
    narrative: String,
    recommendations: [String],
    verdict: String,
    generatedAt: Date = Date(),
    acknowledgedAt: Date? = nil,
    configId: String? = nil,
    featureCategory: String? = nil,
    governanceTrace: GovernanceTrace? = nil
  ) {
    self.sessionIndex = sessionIndex
    self.projectId = projectId
    self.featureId = featureId
    self.metrics = metrics
    self.violations = violations
    self.toolSummary = toolSummary
    self.narrative = narrative
    self.recommendations = recommendations
    self.verdict = verdict
    self.generatedAt = generatedAt
    self.acknowledgedAt = acknowledgedAt
    self.configId = configId
    self.featureCategory = featureCategory
    self.governanceTrace = governanceTrace
  }

  /// Returns a markdown-formatted report.
  public var markdownReport: String {
    var markdown = "# Session Report\n\n"
    markdown += "**Session**: \(sessionIndex)  \n"
    markdown += "**Project**: \(projectId.uuidString.prefix(8))...  \n"
    if let featureId = featureId {
      markdown += "**Feature**: \(featureId.uuidString.prefix(8))...  \n"
    }
    markdown += "**Generated**: \(generatedAt.formatted())  \n\n"

    markdown += "## 🏥 Health Assessment\n\n"
    markdown += "**Verdict**: \(verdict)  \n"
    markdown += "**Health Score**: \(String(format: "%.1f%%", metrics.healthScore * 100))  \n"
    markdown += "**Analysis Ratio**: \(String(format: "%.1f%%", metrics.analysisRatio * 100))  \n"
    markdown += "**First Edit Latency**: \(metrics.firstEditLatency) analysis calls  \n"
    markdown += "**Tool Diversity**: \(metrics.toolDiversity) distinct tools  \n\n"

    if !violations.isEmpty {
      markdown += "## ⚠️ Behavioral Violations\n\n"
      for violation in violations.sorted(by: { $0.severity > $1.severity }) {
        let severityIcon = violation.severity >= 0.7 ? "🔴" : violation.severity >= 0.4 ? "🟡" : "🔵"
        markdown += "\(severityIcon) **\(violation.type.rawValue)**  \n"
        markdown += "\(violation.description)  \n"
        markdown += "Severity: \(String(format: "%.1f", violation.severity))  \n\n"
      }
    } else {
      markdown += "## ✅ No Behavioral Violations\n\n"
      markdown += "All invariants satisfied. Good work!  \n\n"
    }

    markdown += "## 🛠️ Tool Usage\n\n"
    markdown += "| Tool | Count |\n"
    markdown += "|------|-------|\n"
    for (tool, count) in toolSummary.sorted(by: { $0.value > $1.value }) {
      markdown += "| \(tool) | \(count) |\n"
    }
    markdown += "\n"

    markdown += "## 📊 Metrics Summary\n\n"
    markdown += "- **Edit Calls**: \(metrics.editCalls)  \n"
    markdown += "- **Analysis Calls**: \(metrics.analysisCalls)  \n"
    markdown += "- **Test Calls**: \(metrics.testCalls)  \n"
    if let filesChanged = metrics.filesChanged {
      markdown += "- **Files Changed**: \(filesChanged)  \n"
    }
    if let linesChanged = metrics.linesChanged {
      markdown += "- **Lines Changed**: \(linesChanged)  \n"
    }
    if let testsPassed = metrics.testsPassed, let testsFailed = metrics.testsFailed {
      markdown += "- **Tests**: \(testsPassed) passed, \(testsFailed) failed  \n"
    }
    if let formatterSucceeded = metrics.formatterSucceeded {
      markdown += "- **Formatter**: \(formatterSucceeded ? "✅ Succeeded" : "❌ Failed")  \n"
    }
    markdown += "\n"

    if let trace = governanceTrace {
      markdown += "## 👼 Governance Trace\n\n"
      markdown += "**Trust Tier**: \(trace.trustTier)  \n"
      if let lane = trace.lane {
        markdown += "**Lane**: \(lane.name)  \n"
      }
      markdown += "**Policy Decision**: \(trace.policyDecision)  \n"
      markdown += "**Security Outcome**: \(trace.securityOutcome)  \n"
      markdown += "**Escalated**: \(trace.escalated ? "Yes" : "No")  \n"
      markdown += "**Tainted**: \(trace.tainted ? "Yes ⚠️" : "No ✅")  \n"
      markdown += "**Quarantine Applied**: \(trace.quarantineApplied ? "Yes 🔒" : "No")  \n"

      if !trace.gatekeeperFindings.isEmpty {
        markdown += "\n**Gatekeeper Findings**:  \n"
        for finding in trace.gatekeeperFindings {
          let severityIcon =
            finding.severity == .critical ? "🔴" : finding.severity == .warning ? "🟡" : "🔵"
          markdown += "- \(severityIcon) \(finding.code): \(finding.message)  \n"
        }
      }
      markdown += "\n"
    }

    markdown += "## 📖 Narrative\n\n"
    markdown += "\(narrative)\n\n"

    if !recommendations.isEmpty {
      markdown += "## 💡 Recommendations\n\n"
      for (index, recommendation) in recommendations.enumerated() {
        markdown += "\(index + 1). \(recommendation)  \n"
      }
    }

    return markdown
  }

  /// Returns a concise one-line summary.
  public var oneLineSummary: String {
    let healthIcon = metrics.healthScore >= 0.8 ? "✅" : metrics.healthScore >= 0.6 ? "⚠️" : "❌"
    let violationCount = violations.count
    let violationIcon = violationCount == 0 ? "✅" : "⚠️"

    return
      "Session \(sessionIndex): \(healthIcon) \(String(format: "%.0f%%", metrics.healthScore * 100)) health, \(violationIcon) \(violationCount) violations, \(metrics.editCalls) edits, \(metrics.analysisCalls) analyses"
  }

  // MARK: - Bandit Reward Calculation

  /// Calculates the reward for bandit learning.
  /// Reward = healthScore + testPassedBonus - criticalViolationPenalty - largeDiffPenalty
  public var banditReward: Double {
    let base = metrics.healthScore  // 0...1

    // Bonus if tests passed (or at least some tests passed)
    let testsBonus: Double
    if let testsPassed = metrics.testsPassed, testsPassed > 0 {
      let totalTests = (metrics.testsPassed ?? 0) + (metrics.testsFailed ?? 0)
      if totalTests > 0 {
        testsBonus = Double(metrics.testsPassed ?? 0) / Double(totalTests)
      } else {
        testsBonus = 0
      }
    } else {
      testsBonus = 0
    }

    // Penalty for critical violations (severity >= 0.7)
    let criticalViolations = violations.filter { $0.severity >= 0.7 }.count
    let violationPenalty = Double(criticalViolations) * 2.0

    // Penalty for large diffs
    let diffPenalty: Double
    if let linesChanged = metrics.linesChanged {
      if linesChanged > 500 {
        diffPenalty = 2.0
      } else if linesChanged > 200 {
        diffPenalty = 1.0
      } else {
        diffPenalty = 0.0
      }
    } else {
      diffPenalty = 0.0
    }

    return base + testsBonus - violationPenalty - diffPenalty
  }

  /// Whether this session report is valid for bandit learning.
  /// Sessions without configId or featureCategory can't be used for learning.
  public var isValidForBanditLearning: Bool {
    configId != nil && featureCategory != nil
  }

}

// MARK: - Session Report Generator

/// Generates narrative session reports from behavioral data.
public actor SessionReportGenerator {
  private let store: ProjectHarnessStore
  private let inspector: ToolUsageInspector
  public init(
    store: ProjectHarnessStore = .shared, inspector: ToolUsageInspector = ToolUsageInspector()
  ) {
    self.store = store
    self.inspector = inspector
  }

  private func getDBPool() async throws -> DatabasePool {
    try await store.getDBPool()
  }

  /// Generates a comprehensive session report.
  public func generateReport(
    projectId: UUID,
    sessionIndex: Int,
    featureId: UUID? = nil,
    configId: String? = nil,
    featureCategory: String? = nil
  ) async throws -> SessionReport {
    // Get metrics
    let metrics = try await store.computeBehavioralMetrics(
      projectId: projectId,
      sessionIndex: sessionIndex,
      featureId: featureId
    )

    // Get violations
    let violations = try await inspector.checkSessionInvariants(
      projectId: projectId,
      sessionIndex: sessionIndex
    )

    // Get tool usage
    let toolStats = try await store.getToolUsageStats(
      projectId: projectId, sessionIndex: sessionIndex)
    let toolSummary = toolStats["tool_counts"] as? [String: Int] ?? [:]

    // Generate narrative
    let narrative = generateNarrative(
      metrics: metrics,
      violations: violations,
      toolSummary: toolSummary
    )

    // Generate recommendations
    let recommendations = generateRecommendations(
      metrics: metrics,
      violations: violations
    )

    // Generate verdict
    let verdict = generateVerdict(
      metrics: metrics,
      violations: violations
    )

    return SessionReport(
      sessionIndex: sessionIndex,
      projectId: projectId,
      featureId: featureId,
      metrics: metrics,
      violations: violations,
      toolSummary: toolSummary,
      narrative: narrative,
      recommendations: recommendations,
      verdict: verdict,
      configId: configId,
      featureCategory: featureCategory
    )
  }

  /// Generates narrative for the session.
  private func generateNarrative(
    metrics: BehavioralHealthMetrics,
    violations: [InvariantViolation],
    toolSummary: [String: Int]
  ) -> String {
    var narrative = ""

    // Opening based on health score
    if metrics.healthScore >= 0.8 {
      narrative += "This session demonstrates disciplined, junior engineer-like behavior. "
    } else if metrics.healthScore >= 0.6 {
      narrative += "This session shows mostly good practices with some room for improvement. "
    } else if metrics.healthScore >= 0.4 {
      narrative += "This session reveals concerning behavioral patterns that need attention. "
    } else {
      narrative += "This session exhibits problematic, gremlin-like behavior. "
    }

    // Analysis behavior
    if metrics.analysisCalls == 0 && metrics.editCalls > 0 {
      narrative +=
        "The agent jumped straight into editing without any analysis, which is a red flag. "
    } else if metrics.analysisRatio >= 0.3 {
      narrative += "Good analysis-to-edit ratio suggests thoughtful approach. "
    } else if metrics.analysisRatio > 0 {
      narrative += "Some analysis was performed, but could be more thorough. "
    }

    // First edit latency
    if metrics.firstEditLatency == 0 && metrics.editCalls > 0 {
      narrative += "Immediate editing without context gathering is risky. "
    } else if metrics.firstEditLatency <= 3 {
      narrative += "Quick but reasonable analysis before editing. "
    } else if metrics.firstEditLatency > 10 {
      narrative += "Excessive analysis before first edit suggests hesitation or over-analysis. "
    }

    // Tool usage
    if metrics.toolDiversity >= 4 {
      narrative += "Good tool diversity indicates comprehensive approach. "
    } else if metrics.toolDiversity == 1 && (metrics.editCalls + metrics.analysisCalls) > 3 {
      narrative += "Limited tool usage suggests narrow focus or missing capabilities. "
    }

    // Testing behavior
    if metrics.editCalls > 0 && metrics.testCalls == 0 {
      narrative += "Critical omission: no tests were run after making edits. "
    } else if metrics.testCalls > 0 {
      narrative += "Testing was incorporated, which is essential for quality. "
    }

    // Violations summary
    if !violations.isEmpty {
      let criticalCount = violations.filter { $0.severity >= 0.7 }.count
      if criticalCount > 0 {
        narrative += "\(criticalCount) critical behavioral violations were detected. "
      }
      narrative += "These violations indicate areas where prompt or architecture tuning is needed. "
    } else {
      narrative += "No behavioral violations detected - all invariants satisfied. "
    }

    // Overall assessment
    if metrics.isHealthy {
      narrative += "Overall, this session follows healthy software engineering practices."
    } else {
      narrative +=
        "Overall, this session deviates from recommended practices and needs improvement."
    }

    return narrative
  }

  /// Generates recommendations based on metrics and violations.
  private func generateRecommendations(
    metrics: BehavioralHealthMetrics,
    violations: [InvariantViolation]
  ) -> [String] {
    var recommendations: [String] = []

    // Analysis recommendations
    if metrics.analysisCalls == 0 && metrics.editCalls > 0 {
      recommendations.append(
        "Add analysis tools to the prompt and require at least 2 analysis calls before editing")
    } else if metrics.analysisRatio < 0.2 {
      recommendations.append(
        "Increase analysis ratio by adding more analysis-focused tools or constraints")
    }

    // First edit latency recommendations
    if metrics.firstEditLatency == 0 && metrics.editCalls > 0 {
      recommendations.append("Enforce minimum analysis before editing in the prompt")
    } else if metrics.firstEditLatency > 10 {
      recommendations.append("Consider reducing analysis paralysis by limiting analysis tool calls")
    }

    // Tool diversity recommendations
    if metrics.toolDiversity < 2 && (metrics.editCalls + metrics.analysisCalls) > 3 {
      recommendations.append(
        "Expand toolset to include more specialized analysis and validation tools")
    }

    // Testing recommendations
    if metrics.editCalls > 0 && metrics.testCalls == 0 {
      recommendations.append("Mandate test runs after every 3 edits in the prompt")
    }

    // Violation-specific recommendations
    for violation in violations {
      switch violation.type {
      case .editWithoutAnalysis:
        recommendations.append("Add 'analysis_before_edits' invariant to prompt")
      case .tooManyEditsBeforeTests:
        recommendations.append("Reduce max_edits_before_tests threshold from 3 to 2")
      case .lowAnalysisRatio:
        recommendations.append("Increase min_analysis_ratio requirement")
      case .highFirstEditLatency:
        recommendations.append("Add analysis time limit to prevent over-analysis")
      case .lowToolDiversity:
        recommendations.append("Require use of at least 3 different tools per session")
      case .noTestsAfterEdits:
        recommendations.append("Make test runs mandatory after any edit")
      }
    }

    // Health score recommendations
    if metrics.healthScore < 0.6 {
      recommendations.append("Review and tighten behavioral invariants in the prompt")
    }

    // Remove duplicates while preserving order
    var seen = Set<String>()
    return recommendations.filter { seen.insert($0).inserted }
  }

  /// Generates a verdict based on metrics and violations.
  private func generateVerdict(
    metrics: BehavioralHealthMetrics,
    violations: [InvariantViolation]
  ) -> String {
    let criticalViolations = violations.filter { $0.severity >= 0.7 }.count

    if metrics.healthScore >= 0.8 && criticalViolations == 0 {
      return "✅ Excellent: Junior engineer behavior"
    } else if metrics.healthScore >= 0.7 && criticalViolations <= 1 {
      return "✅ Good: Mostly disciplined"
    } else if metrics.healthScore >= 0.6 {
      return "⚠️  Fair: Needs minor improvements"
    } else if metrics.healthScore >= 0.4 || criticalViolations <= 2 {
      return "⚠️  Concerning: Pattern issues"
    } else if criticalViolations > 2 {
      return "❌ Critical: Gremlin behavior"
    } else {
      return "❌ Unhealthy: Needs prompt tuning"
    }
  }

  /// Generates reports for multiple sessions.
  public func generateBatchReports(
    projectId: UUID,
    sessionIndices: [Int]
  ) async throws -> [SessionReport] {
    var reports: [SessionReport] = []

    for sessionIndex in sessionIndices.sorted() {
      do {
        let report = try await generateReport(
          projectId: projectId,
          sessionIndex: sessionIndex
        )
        reports.append(report)
      } catch {
        // Skip sessions that can't be analyzed
        continue
      }
    }

    return reports
  }

  /// Generates a project summary report.
  public func generateProjectSummary(projectId: UUID) async throws -> String {
    let healthStats = try await store.getHealthStatistics(projectId: projectId)
    let violations = try await inspector.checkProjectInvariants(projectId: projectId)

    guard let totalSessions = healthStats["total_sessions"] as? Int,
      let healthySessions = healthStats["healthy_sessions"] as? Int,
      let healthRate = healthStats["health_rate"] as? Double,
      let avgHealthScore = healthStats["avg_health_score"] as? Double
    else {
      return "Insufficient data for project summary"
    }

    let criticalViolations = violations.filter { $0.severity >= 0.7 }.count

    var summary = "# Project Behavioral Summary\n\n"
    summary += "**Project**: \(projectId.uuidString.prefix(8))...  \n"
    summary += "**Total Sessions**: \(totalSessions)  \n"
    summary += "**Healthy Sessions**: \(healthySessions)  \n"
    summary += "**Health Rate**: \(String(format: "%.1f%%", healthRate * 100))  \n"
    summary += "**Avg Health Score**: \(String(format: "%.1f%%", avgHealthScore * 100))  \n"
    summary += "**Critical Violations**: \(criticalViolations)  \n\n"

    if let recentMetrics = healthStats["recent_metrics"] as? [[String: Any]] {
      summary += "## Recent Sessions\n\n"
      summary += "| Session | Health | Analysis Ratio | Violations |\n"
      summary += "|---------|--------|----------------|------------|\n"

      for metric in recentMetrics.prefix(5) {
        guard let session = metric["session"] as? Int,
          let healthScore = metric["health_score"] as? Double,
          let analysisRatio = metric["analysis_ratio"] as? Double,
          let isHealthy = metric["is_healthy"] as? Bool
        else {
          continue
        }

        let healthIcon = healthScore >= 0.8 ? "✅" : healthScore >= 0.6 ? "⚠️" : "❌"
        let violationIcon = isHealthy ? "✅" : "⚠️"

        summary +=
          "| \(session) | \(healthIcon) \(String(format: "%.0f%%", healthScore * 100)) | \(String(format: "%.0f%%", analysisRatio * 100)) | \(violationIcon) |\n"
      }
      summary += "\n"
    }

    if !violations.isEmpty {
      summary += "## Common Violations\n\n"
      let violationsByType = Dictionary(grouping: violations) { $0.type }

      for (type, typeViolations) in violationsByType.sorted(by: { $0.value.count > $1.value.count }) {
        summary += "**\(type.rawValue)**: \(typeViolations.count) occurrences  \n"
      }
      summary += "\n"
    }

    // Overall assessment
    if healthRate >= 0.8 && criticalViolations == 0 {
      summary += "## ✅ Overall Assessment\n\n"
      summary +=
        "Project shows consistently healthy behavior. The harness is working as intended with junior engineer-like patterns.\n"
    } else if healthRate >= 0.6 {
      summary += "## ⚠️ Overall Assessment\n\n"
      summary +=
        "Project shows mostly good behavior with some areas for improvement. Consider tightening invariants or adjusting prompts.\n"
    } else {
      summary += "## ❌ Overall Assessment\n\n"
      summary +=
        "Project shows concerning behavioral patterns. Significant prompt or architecture tuning is needed.\n"
    }

    return summary
  }

  /// Exports all session reports as markdown files.
  public func exportReportsToMarkdown(
    projectId: UUID,
    outputDirectory: String
  ) async throws {
    // Get all sessions
    let toolStats = try await store.getToolUsageStats(projectId: projectId)
    guard let logs = toolStats["logs"] as? [[String: Any]] else {
      throw HarnessError.invalidProjectState("No tool logs found")
    }

    let sessionIndices = Set(logs.compactMap { $0["session"] as? Int })

    // Create output directory
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: outputDirectory) {
      try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
    }

    // Generate reports
    for sessionIndex in sessionIndices.sorted() {
      do {
        let report = try await generateReport(
          projectId: projectId,
          sessionIndex: sessionIndex
        )

        let filename = "session_\(sessionIndex)_report.md"
        let filePath = (outputDirectory as NSString).appendingPathComponent(filename)

        try report.markdownReport.write(
          toFile: filePath,
          atomically: true,
          encoding: .utf8
        )
      } catch {
        // Skip problematic sessions
        continue
      }
    }

    // Generate project summary
    let summary = try await generateProjectSummary(projectId: projectId)
    let summaryPath = (outputDirectory as NSString).appendingPathComponent("project_summary.md")
    try summary.write(toFile: summaryPath, atomically: true, encoding: .utf8)
  }
}

// MARK: - GRDB Integration

extension SessionReport {
  public static var databaseTableName: String { "session_reports" }

  public enum Columns: String, ColumnExpression {
    case sessionIndex
    case projectId
    case featureId
    case metrics
    case violations
    case toolSummary
    case narrative
    case recommendations
    case verdict
    case generatedAt
    case acknowledgedAt
  }

  public static func createTable(_ db: Database) throws {
    try db.create(table: databaseTableName, ifNotExists: true) { t in
      t.column(Columns.sessionIndex.rawValue, .integer).notNull()
      t.column(Columns.projectId.rawValue, .text).notNull()
      t.column(Columns.featureId.rawValue, .text)
      t.column(Columns.metrics.rawValue, .text).notNull()
      t.column(Columns.violations.rawValue, .text).notNull()
      t.column(Columns.toolSummary.rawValue, .text).notNull()
      t.column(Columns.narrative.rawValue, .text).notNull()
      t.column(Columns.recommendations.rawValue, .text).notNull()
      t.column(Columns.verdict.rawValue, .text).notNull()
      t.column(Columns.generatedAt.rawValue, .datetime).notNull()
      t.column(Columns.acknowledgedAt.rawValue, .datetime)

      // Composite primary key: project + session
      t.primaryKey([Columns.projectId.rawValue, Columns.sessionIndex.rawValue])
    }

    // Create indexes for common queries
    try db.create(
      index: "idx_session_reports_project_session", on: databaseTableName,
      columns: [Columns.projectId.rawValue, Columns.sessionIndex.rawValue], unique: true,
      ifNotExists: true)
    try db.create(
      index: "idx_session_reports_acknowledged", on: databaseTableName,
      columns: [Columns.acknowledgedAt.rawValue], ifNotExists: true)
    try db.create(
      index: "idx_session_reports_generated", on: databaseTableName,
      columns: [Columns.generatedAt.rawValue], ifNotExists: true)
  }
}

extension ProjectHarnessStore {
  /// Saves a session report.
  public func saveSessionReport(_ report: SessionReport) throws {
    guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

    try dbPool.write { db in
      try report.save(db)
    }
  }

  /// Gets session reports for a project.
  public func getSessionReports(projectId: UUID, limit: Int = 20) throws -> [SessionReport] {
    guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

    return try dbPool.read { db in
      try SessionReport
        .filter(SessionReport.Columns.projectId == projectId.uuidString)
        .order(SessionReport.Columns.sessionIndex.desc)
        .limit(limit)
        .fetchAll(db)
    }
  }

  /// Acknowledges a session (marks it as reviewed by a human).
  public func acknowledgeSession(projectId: UUID, sessionIndex: Int) throws {
    guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

    try dbPool.write { db in
      // Get the report
      guard
        var report =
          try SessionReport
          .filter(SessionReport.Columns.projectId == projectId.uuidString)
          .filter(SessionReport.Columns.sessionIndex == sessionIndex)
          .fetchOne(db)
      else {
        throw HarnessError.invalidProjectState("Session report not found")
      }

      // Update acknowledged timestamp
      report.acknowledgedAt = Date()

      // Save updated report
      try report.update(db)
    }
  }

  /// Acknowledges a range of sessions.
  public func acknowledgeSessions(projectId: UUID, fromSession: Int, toSession: Int) throws {
    guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

    try dbPool.write { db in
      // Get all reports in range
      let reports =
        try SessionReport
        .filter(SessionReport.Columns.projectId == projectId.uuidString)
        .filter(SessionReport.Columns.sessionIndex >= fromSession)
        .filter(SessionReport.Columns.sessionIndex <= toSession)
        .fetchAll(db)

      // Update each report
      for var report in reports {
        report.acknowledgedAt = Date()
        try report.update(db)
      }
    }
  }

  /// Gets unacknowledged sessions for a project.
  public func getUnacknowledgedSessions(projectId: UUID) throws -> [SessionReport] {
    guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

    return try dbPool.read { db in
      try SessionReport
        .filter(SessionReport.Columns.projectId == projectId.uuidString)
        .filter(SessionReport.Columns.acknowledgedAt == nil)
        .order(SessionReport.Columns.sessionIndex.desc)
        .fetchAll(db)
    }
  }

  /// Gets the latest unacknowledged unhealthy session.
  public func getLatestUnacknowledgedUnhealthySession(projectId: UUID) throws -> SessionReport? {
    guard let dbPool = dbPool else { throw HarnessError.storeNotInitialized }

    return try dbPool.read { db in
      let reports =
        try SessionReport
        .filter(SessionReport.Columns.projectId == projectId.uuidString)
        .filter(SessionReport.Columns.acknowledgedAt == nil)
        .order(SessionReport.Columns.sessionIndex.desc)
        .fetchAll(db)

      // Find first unhealthy session (health score < 0.6 or has critical violations)
      return reports.first { report in
        report.metrics.healthScore < 0.6 || report.violations.contains { $0.severity >= 0.7 }
      }
    }
  }
}
