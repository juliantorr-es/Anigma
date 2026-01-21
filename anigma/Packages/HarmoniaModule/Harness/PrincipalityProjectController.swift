//
//  PrincipalityProjectController.swift
//  HarmoniaModule
//
//  Single coordination point for everything that happens to one project.
//  External callers (CLI, future UI, scouts) should only talk to this.
//  Phase B: Governance protocols with angelic hierarchy (comments only).
//

import Foundation
import GRDB
import AnigmaPrimitives

/// Single coordination point for everything that happens to one project.
/// External callers (CLI, future UI, scouts) should only talk to this.
/// Angelic hierarchy mapping in comments only.
public actor PrincipalityProjectController {
  public let projectId: UUID

  let store: ProjectHarnessStore
  private let sessionListing: SessionListingProviding  // New capability module dependency
  private let policyRegistry: PolicyRegistry  // Seraphim
  private let banditGovernor: BanditGovernor  // Thrones
  private let gatekeeper: Gatekeeper  // Cherubim
  private let securityEnforcer: SecurityEnforcer  // Dominions
  private let harnessRunner: HarnessRunner  // Archangels
  private let eventSink: GovernanceEventSink
  private let trustVerifier: SessionTrustVerifier
  private let rudeCLI: RudeCLICommands

  public init(
    projectId: UUID,
    store: ProjectHarnessStore = .shared,
    sessionListing: SessionListingProviding? = nil,
    policyRegistry: PolicyRegistry = BlessedPolicyRegistry(),
    banditGovernor: BanditGovernor = BanditGovernorImpl(),
    gatekeeper: Gatekeeper = GatekeeperImpl(),
    securityEnforcer: SecurityEnforcer = SecurityEnforcerImpl(),
    harnessRunner: HarnessRunner = HarnessRunnerImpl(),
    eventSink: GovernanceEventSink = ConsoleEventSink(),
    trustVerifier: SessionTrustVerifier = LegacySessionTrustVerifier(),
    rudeCLI: RudeCLICommands = RudeCLICommands()
  ) {
    self.projectId = projectId
    self.store = store
    // Use legacy adapter if no session listing provided (backward compatibility)
    self.sessionListing =
      sessionListing ?? SessionListingAdapterFactory.createLegacyAdapter(store: store)
    self.policyRegistry = policyRegistry
    self.banditGovernor = banditGovernor
    self.gatekeeper = gatekeeper
    self.securityEnforcer = securityEnforcer
    self.harnessRunner = harnessRunner
    self.eventSink = eventSink
    self.trustVerifier = trustVerifier
    self.rudeCLI = rudeCLI
  }

  // MARK: - Public API surface

  /// Gets the project spec, throwing if not found.
  public func requireProject() async throws -> ProjectSpec {
    guard let project = try await store.loadProject(id: projectId.uuidString) else {
      throw HarnessError.projectNotFound(projectId)
    }
    return project
  }

  /// Main entrypoint: run a harness session for a feature category.
  /// Optionally allow callers to pin a configId instead of letting the bandit decide.
  @discardableResult
  nonisolated public func runSession(
    featureCategory: String,
    explicitConfigId: String? = nil,
    trustTier: TrustTier = .trusted,
    intent: SessionIntent? = nil
  ) async throws -> SessionReport {
    try await runSessionActor(
        featureCategory: featureCategory,
        explicitConfigId: explicitConfigId,
        trustTier: trustTier,
        intent: intent
    )
  }

  private func runSessionActor(
    featureCategory: String,
    explicitConfigId: String? = nil,
    trustTier: TrustTier = .trusted,
    intent: SessionIntent? = nil
  ) async throws -> SessionReport {

    // 1) Resolve project
    let project = try await requireProject()

    // 2) Governance flow: BanditGovernor → PolicyRegistry → Gatekeeper → SecurityEnforcer → HarnessRunner
    //    Each level can escalate or deny

    // Create intent if not provided
    let sessionIntent =
      intent
      ?? SessionIntent(
        projectId: projectId,
        featureCategory: featureCategory,
        requestedConfigId: explicitConfigId,
        trustTier: trustTier.sessionTrustTier,
        metadata: ["description": "Feature implementation for \(featureCategory)"]
      )

    // 2a) BanditGovernor selects config (Thrones)
    let configId: String
    if let explicitConfigId = explicitConfigId {
      configId = explicitConfigId
    } else {
      configId = try await banditGovernor.selectConfig(intent: sessionIntent)
    }

    // 2b) PolicyRegistry validates and normalizes config (Seraphim)

    let normalizedConfigId = try await policyRegistry.normalizeConfigChoice(
      intent: sessionIntent,
      candidateConfigId: configId
    )

    let policyDecision = try await policyRegistry.validateSessionPlan(
      intent: sessionIntent,
      configId: normalizedConfigId
    )

    switch policyDecision {
    case .allow:
      // Continue with session
      break
    case .deny(let reason):
      throw PrincipalityError.sessionDenied(reason)
    case .requireEscalation(let reason):
      // Log escalation requirement
      await eventSink.emit(
        GovernanceLogEvent(
          projectId: projectId,
          severity: .warning,
          code: "policy_escalation",
          message: "Escalation required: \(reason)",
          context: ["intent": sessionIntent.featureCategory]
        ))
    // For now, continue but log the need for escalation
    }

    // 2c) Gatekeeper checks (Cherubim)
    let gatekeeperDecision = try await gatekeeper.evaluate(
      intent: sessionIntent,
      configId: normalizedConfigId
    )

    switch gatekeeperDecision {
    case .allow:
      // Continue with session
      break
    case .deny(let reason):
      throw PrincipalityError.sessionDenied(reason)
    case .requireEscalation(let reason):
      // Log escalation requirement
      await eventSink.emit(
        GovernanceLogEvent(
          projectId: projectId,
          severity: .warning,
          code: "gatekeeper_escalation",
          message: "Gatekeeper escalation: \(reason)",
          context: ["intent": sessionIntent.featureCategory]
        ))
    }

    // 2d) Check if project is quarantined (Dominions)
    let isQuarantined = await securityEnforcer.isProjectQuarantined(projectId)
    if isQuarantined {
      throw PrincipalityError.projectQuarantined(projectId)
    }

    // 3) Execute session with HarnessRunner (Archangels)
    let report = try await harnessRunner.run(
      intent: sessionIntent,
      project: project,
      configId: normalizedConfigId
    )

    // 4) Update bandit learning from outcome
    // For now, use a simple reward based on whether session was healthy
    let reward: Double = report.metrics.isHealthy ? 1.0 : 0.0
    try await banditGovernor.recordOutcome(
      intent: sessionIntent,
      configId: normalizedConfigId,
      reward: reward
    )

    // 5) Emit governance events
    await eventSink.emit(
      GovernanceLogEvent(
        projectId: projectId,
        severity: .info,
        code: "session_completed",
        message: "Session completed for \(featureCategory) with config \(normalizedConfigId)",
        context: [
          "featureCategory": featureCategory,
          "configId": normalizedConfigId,
          "trustTier": "\(trustTier)"
        ]
      ))

    return report

  }

  /// Human-readable per-project status snapshot for `harmonia status`.
  nonisolated public func getStatus() async throws -> ProjectStatusSummary {
    return try await getStatusActor()
  }

  /// Human-readable per-project status snapshot for `harmonia status`.
  private func getStatusActor() async throws -> ProjectStatusSummary {
    let project = try await requireProject()

    // Get session stats
    let healthStats = try await store.getHealthStatistics(projectId: projectId)
    let totalSessions = healthStats["total_sessions"] as? Int ?? 0
    let healthySessions = healthStats["healthy_sessions"] as? Int ?? 0
    let healthRate = healthStats["health_rate"] as? Double ?? 0.0

    // Get bandit stats summary
    let banditSummary = try await getBanditStatsSummary()

    // Get unacknowledged issues
    let unacknowledgedCount = try await getUnacknowledgedIssueCount()

    // Get quarantine status
    let isQuarantined = await securityEnforcer.isProjectQuarantined(projectId)
    let quarantineReason =
      isQuarantined
      ? (await securityEnforcer.getQuarantineStatus(projectId: projectId)?.reason) : nil

    return ProjectStatusSummary(
      projectId: projectId,
      name: project.name,
      healthRate: healthRate,
      totalSessions: totalSessions,
      healthySessions: healthySessions,
      banditSummary: banditSummary,
      unacknowledgedIssueCount: unacknowledgedCount,
      isQuarantined: isQuarantined,
      quarantineReason: quarantineReason
    )

  }

  /// Gets governance status including events and layer health.
  nonisolated public func getGovernanceStatus() async throws -> GovernanceStatus {
    return try await getGovernanceStatusActor()
  }

  /// Gets governance status including events and layer health.
  private func getGovernanceStatusActor() async throws -> GovernanceStatus {
    let project = try await requireProject()

    let isQuarantined = await securityEnforcer.isProjectQuarantined(projectId)
    let quarantineStatus =
      isQuarantined ? (await securityEnforcer.getQuarantineStatus(projectId: projectId)) : nil

    // Get recent sessions for governance analysis
    let recentSessions = try await store.getSessionReports(projectId: projectId, limit: 20)

    // Analyze governance traces
    var trustTierBreakdown: [SessionTrustTier: Int] = [.system: 0, .trusted: 0, .adversarial: 0]
    var taintedCount = 0
    var escalatedCount = 0
    var policyDenials = 0
    var lastPolicyDenial: String?
    var lastQuarantineDecision: String?

    for session in recentSessions {
      if let trace = session.governanceTrace {
        // Count trust tiers
        trustTierBreakdown[trace.trustTier, default: 0] += 1

        // Count tainted sessions
        if trace.tainted {
          taintedCount += 1
        }

        // Count escalations
        if trace.escalated {
          escalatedCount += 1
        }

        // Track policy decisions
        if trace.policyDecision == .denied {
          policyDenials += 1
          lastPolicyDenial =
            "Session \(session.sessionIndex): \(trace.gatekeeperFindings.first?.message ?? "denied")"
        }

        // Track quarantine
        if trace.quarantineApplied {
          lastQuarantineDecision = "Session \(session.sessionIndex): Quarantine applied"
        }
      }
    }

    // Get total session stats
    let healthStats = try await store.getHealthStatistics(projectId: projectId)
    let totalSessions = healthStats["total_sessions"] as? Int ?? 0
    let healthySessions = healthStats["healthy_sessions"] as? Int ?? 0

    return GovernanceStatus(
      projectId: projectId,
      projectName: project.name,
      isQuarantined: isQuarantined,
      quarantineStatus: quarantineStatus,
      governanceSummary: nil,
      recentSessionCount: recentSessions.count,
      lastSessionIndex: recentSessions.first?.sessionIndex,
      trustTierBreakdown: trustTierBreakdown,
      taintedCount: taintedCount,
      escalatedCount: escalatedCount,
      policyDenials: policyDenials,
      lastPolicyDenial: lastPolicyDenial,
      lastQuarantineDecision: lastQuarantineDecision,
      totalSessions: totalSessions,
      healthySessions: healthySessions
    )

  }

  /// Used by `harmonia bully` / acknowledge flows.
  nonisolated public func acknowledgeSession(sessionIndex: Int) async throws {
    try await acknowledgeSessionActor(sessionIndex: sessionIndex)
  }

  /// Used by `harmonia bully` / acknowledge flows.
  private func acknowledgeSessionActor(sessionIndex: Int) async throws {
    try await store.acknowledgeSession(
      projectId: projectId,
      sessionIndex: sessionIndex
    )

  }

  /// Acknowledge all unhealthy sessions.
  public func acknowledgeAllUnhealthySessions() async throws {
    let unacknowledged = try await store.getUnacknowledgedSessions(projectId: projectId)
    for report in unacknowledged where !report.metrics.isHealthy {
      try await store.acknowledgeSession(
        projectId: projectId,
        sessionIndex: report.sessionIndex
      )
    }
  }

  /// Text report suitable for CLI `harmonia inspect --bandit`.
  nonisolated public func getBanditReport() async throws -> String {
    return try await getBanditReportActor()
  }

  /// Text report suitable for CLI `harmonia inspect --bandit`.
  private func getBanditReportActor() async throws -> String {
    // For now, return a simple message
    // In a real implementation, this would query bandit stats
    return "Bandit report not yet implemented with governance protocols"

  }

  /// Lists recent sessions for this project.
  /// Required by ProjectExecutionSurface protocol.
  /// Now uses SessionListingProviding capability module instead of direct store access.
  nonisolated public func listRecentSessions(limit: Int) async throws -> [SessionReport] {
    return try await listRecentSessionsActor(limit: limit)
  }

  /// Lists recent sessions for this project.
  /// Required by ProjectExecutionSurface protocol.
  /// Now uses SessionListingProviding capability module instead of direct store access.
  private func listRecentSessionsActor(limit: Int) async throws -> [SessionReport] {
    try await sessionListing.listRecentSessions(
      projectId: projectId,
      limit: limit,
      trustTier: .trusted
    )

  }

  /// Streams recent sessions for this project with reactive, error-first interface.
  /// New capability provided by SessionListingProviding module.
  nonisolated public func recentSessionsStream(limit: Int) -> AsyncThrowingStream<SessionReport, any Error> {
    AsyncThrowingStream { continuation in
      Task { [weak self] in
        guard let self else {
          continuation.finish()
          return
        }

        do {
          let sessions = try await self.listRecentSessionsActor(limit: limit)

          for session in sessions {
            let trustResult = try await self.trustVerifier.verifySession(
              sessionId: "\(session.sessionIndex)"
            )

            if trustResult.isTrusted {
              continuation.yield(session)
            } else {
              throw SessionListingError.trustVerificationFailed(
                sessionId: "\(session.sessionIndex)",
                reason: trustResult.reasons.joined(separator: ", ")
              )
            }
          }

          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  /// Checks if caller has permission to list sessions for this project.
  /// New capability provided by SessionListingProviding module.
  nonisolated public func canListSessions() async throws -> Bool {
    return try await canListSessionsActor()
  }

  /// Checks if caller has permission to list sessions for this project.
  /// New capability provided by SessionListingProviding module.
  private func canListSessionsActor() async throws -> Bool {
    try await sessionListing.canListSessions(
      projectId: projectId,
      trustTier: .trusted
    )

  }

  /// Gets session reports for a project (ProjectExecutionSurface requirement).
  nonisolated public func getSessionReports(projectId: UUID, limit: Int) async throws -> [SessionReport] {
    return try await getSessionReportsActor(projectId: projectId, limit: limit)
  }

  private func getSessionReportsActor(projectId: UUID, limit: Int) async throws -> [SessionReport] {
    try await store.getSessionReports(projectId: projectId, limit: limit)
  }

  /// Gets deprecation recommendations for configs.
  public func getDeprecationRecommendations() async throws -> [String] {
    return try await rudeCLI.showDeprecationRecommendations(projectId: projectId)
      .split(separator: "\n")
      .map(String.init)
  }

  /// Shows critical violations that need immediate attention.
  public func getCriticalViolations() async throws -> String {
    return try await rudeCLI.showCriticalViolations(projectId: projectId)
  }

  /// Shows the worst session with brutal honesty.
  public func getWorstSession() async throws -> String {
    return try await rudeCLI.showWorstSession(projectId: projectId)
  }

  /// Generates a report card with grades.
  public func getReportCard() async throws -> String {
    return try await rudeCLI.generateReportCard(projectId: projectId)
  }

  /// Forces reading of the last session's report.
  public func forceReadLastReport() async throws -> String {
    return try await rudeCLI.forceReadLastReport(projectId: projectId)
  }

  /// Checks for unacknowledged unhealthy sessions.
  public func checkUnacknowledged() async throws -> String {
    return try await rudeCLI.checkUnacknowledged(projectId: projectId)
  }

  /// Compares two sessions brutally.
  public func compareSessionsBrutally(sessionIndex1: Int, sessionIndex2: Int) async throws -> String {
    return try await rudeCLI.compareBrutally(
      projectId: projectId,
      sessionIndex1: sessionIndex1,
      sessionIndex2: sessionIndex2
    )
  }

  /// Runs the "bully" command - aggressively surfaces issues.
  public func bully() async throws -> String {
    return try await rudeCLI.bully(projectId: projectId)
  }

  // MARK: - Internal helpers

  private func getNextSessionIndex() async throws -> Int {
    let snapshots = try await store.getProgressSnapshots(projectId: projectId)
    return (snapshots.last?.sessionIndex ?? 0) + 1
  }

  private func getBanditStatsSummary() async throws -> BanditStatsSummary {
    // For now, return empty stats
    // In a real implementation, this would query bandit stats
    return BanditStatsSummary(categoryStats: [:])
  }

  private func getUnacknowledgedIssueCount() async throws -> Int {
    let unacknowledged = try await store.getUnacknowledgedSessions(projectId: projectId)
    return unacknowledged.filter { !$0.metrics.isHealthy }.count
  }
}

// MARK: - Status Models

/// Minimal, CLI-focused status model.
/// This is what `harmonia status` prints.
public struct ProjectStatusSummary: Sendable {
  public let projectId: UUID
  public let name: String

  public let healthRate: Double
  public let totalSessions: Int
  public let healthySessions: Int

  public let banditSummary: BanditStatsSummary
  public let unacknowledgedIssueCount: Int
  public let isQuarantined: Bool
  public let quarantineReason: String?

  public init(
    projectId: UUID,
    name: String,
    healthRate: Double,
    totalSessions: Int,
    healthySessions: Int,
    banditSummary: BanditStatsSummary,
    unacknowledgedIssueCount: Int,
    isQuarantined: Bool = false,
    quarantineReason: String? = nil
  ) {
    self.projectId = projectId
    self.name = name
    self.healthRate = healthRate
    self.totalSessions = totalSessions
    self.healthySessions = healthySessions
    self.banditSummary = banditSummary
    self.unacknowledgedIssueCount = unacknowledgedIssueCount
    self.isQuarantined = isQuarantined
    self.quarantineReason = quarantineReason
  }
}

/// Summary of bandit statistics for a project.
public struct BanditStatsSummary: Sendable {
  public let categoryStats: [String: BanditCategoryStats]

  public init(categoryStats: [String: BanditCategoryStats] = [:]) {
    self.categoryStats = categoryStats
  }
}

/// Bandit statistics for a specific category.
public struct BanditCategoryStats: Sendable {
  public let totalPulls: Int
  public let totalReward: Double
  public let averageReward: Double
  public let bestConfigId: String?
  public let bestConfigReward: Double?
  public let worstConfigId: String?
  public let worstConfigReward: Double?
}

// MARK: - Governance Status Models

/// Governance status for a project.
public struct GovernanceStatus: Sendable {
  public let projectId: UUID
  public let projectName: String
  public let isQuarantined: Bool
  public let quarantineStatus: QuarantineStatus?
  public let governanceSummary: GovernanceSummary?
  public let recentSessionCount: Int
  public let lastSessionIndex: Int?

  // Phase D: Governance triage board
  public let trustTierBreakdown: [SessionTrustTier: Int]
  public let taintedCount: Int
  public let escalatedCount: Int
  public let policyDenials: Int
  public let lastPolicyDenial: String?
  public let lastQuarantineDecision: String?
  public let totalSessions: Int
  public let healthySessions: Int

  public init(
    projectId: UUID,
    projectName: String,
    isQuarantined: Bool,
    quarantineStatus: QuarantineStatus?,
    governanceSummary: GovernanceSummary?,
    recentSessionCount: Int,
    lastSessionIndex: Int?,
    trustTierBreakdown: [SessionTrustTier: Int] = [:],
    taintedCount: Int = 0,
    escalatedCount: Int = 0,
    policyDenials: Int = 0,
    lastPolicyDenial: String? = nil,
    lastQuarantineDecision: String? = nil,
    totalSessions: Int = 0,
    healthySessions: Int = 0
  ) {
    self.projectId = projectId
    self.projectName = projectName
    self.isQuarantined = isQuarantined
    self.quarantineStatus = quarantineStatus
    self.governanceSummary = governanceSummary
    self.recentSessionCount = recentSessionCount
    self.lastSessionIndex = lastSessionIndex
    self.trustTierBreakdown = trustTierBreakdown
    self.taintedCount = taintedCount
    self.escalatedCount = escalatedCount
    self.policyDenials = policyDenials
    self.lastPolicyDenial = lastPolicyDenial
    self.lastQuarantineDecision = lastQuarantineDecision
    self.totalSessions = totalSessions
    self.healthySessions = healthySessions
  }

  /// Returns a simple status string for CLI.
  public var statusString: String {
    if isQuarantined {
      return "🚨 Quarantined"
    } else if let summary = governanceSummary {
      return summary.statusString
    } else {
      return "✅ Operational"
    }
  }

  /// Returns a detailed report for CLI inspect.
  public var detailedReport: String {
    var report = "🏛️  Governance Status for \(projectName)\n"
    report += "================================\n\n"

    report += "Project: \(projectName) (\(projectId.uuidString.prefix(8)))\n"
    report += "Status: \(statusString)\n\n"

    if isQuarantined, let quarantine = quarantineStatus {
      report += "Quarantine Details:\n"
      report += "  • Reason: \(quarantine.reason)\n"
      report += "  • Started: \(quarantine.startTime)\n"
      if quarantine.isActive {
        report += "  • Time remaining: \(Int(quarantine.timeRemaining / 60)) minutes\n"
      } else {
        report += "  • Ended: \(quarantine.endTime)\n"
      }
      report += "\n"
    }

    if let summary = governanceSummary {
      report += summary.detailedReport
    }

    report += "Session Activity:\n"
    report += "  • Recent sessions: \(recentSessionCount)\n"
    if let lastIndex = lastSessionIndex {
      report += "  • Last session: #\(lastIndex)\n"
    }

    // Phase D: Governance Triage Board
    report += "\n👼 Governance Triage Board (last \(recentSessionCount) sessions):\n"
    report += "  • Total sessions: \(totalSessions)\n"
    report +=
      "  • Healthy sessions: \(healthySessions) (\(String(format: "%.0f%%", Double(healthySessions) / Double(max(totalSessions, 1)) * 100)))\n"
    report += "  • Tainted sessions: \(taintedCount) ⚠️\n"
    report += "  • Escalated sessions: \(escalatedCount) ⚠️\n"
    report += "  • Policy denials: \(policyDenials)\n"

    if !trustTierBreakdown.isEmpty {
      report += "\n  Trust Tier Breakdown:\n"
      for (tier, count) in trustTierBreakdown.sorted(by: { $0.key.hashValue < $1.key.hashValue }) {
        let tierIcon = tier == .system ? "🔧" : tier == .trusted ? "✅" : "👿"
        report += "    • \(tierIcon) \(tier): \(count) sessions\n"
      }
    }

    if let lastDenial = lastPolicyDenial {
      report += "\n  Last policy denial: \(lastDenial)\n"
    }

    if let lastQuarantine = lastQuarantineDecision {
      report += "  Last quarantine: \(lastQuarantine)\n"
    }

    // Summary judgment
    report += "\n📋 Summary:\n"
    if isQuarantined {
      report += "  🚨 PROJECT QUARANTINED - All execution blocked\n"
    } else if taintedCount > recentSessionCount / 2 {
      report += "  ⚠️  HIGH TAINT RATE - Consider quarantine\n"
    } else if policyDenials > 0 {
      report += "  ⚠️  POLICY VIOLATIONS - Review trust tiers\n"
    } else {
      report += "  ✅ Governance operational - Choir singing\n"
    }

    return report
  }
}
