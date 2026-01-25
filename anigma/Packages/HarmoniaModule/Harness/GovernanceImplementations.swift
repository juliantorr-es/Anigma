//
//  GovernanceImplementations.swift
//  HarmoniaModule
//
//  Protocol implementations for existing components.
//  Angelic hierarchy mapping in comments only.
//

@preconcurrency import Foundation
@preconcurrency import GRDB
import AnigmaPrimitives

// MARK: - Policy Registry Implementation (Seraphim)

/// Policy registry implementation wrapping BlessedConfigRegistry.
/// Angelic mapping: Seraphim (highest rank, sets policy)
public struct BlessedPolicyRegistry: PolicyRegistry {
    public init() {}

    public func getConfigs(for category: String) -> [BlessedConfig] {
        BlessedConfigRegistry.configs(for: category)
    }

    public func getConfigIds(for category: String) -> [String] {
        BlessedConfigRegistry.configIds(for: category)
    }

    public func getConfig(withId id: String) -> BlessedConfig? {
        BlessedConfigRegistry.config(withId: id)
    }

    public func getAllCategories() -> Set<String> {
        Set(BlessedConfigRegistry.defaultConfigs.flatMap { $0.featureCategories })
    }

    public func getDefaultConfigs() -> [BlessedConfig] {
        BlessedConfigRegistry.defaultConfigs
    }

    /// Gets configs allowed for a specific trust tier.
    public func getConfigs(for category: String, trustTier: SessionTrustTier) -> [BlessedConfig] {
        let allConfigs = getConfigs(for: category)

        switch trustTier {
        case .system:
            // System tier: only canonical, highly-tested configs
            return allConfigs.filter { $0.tags.contains("canonical") || $0.tags.contains("system") }

        case .trusted:
            // Trusted tier: all configs except adversarial-only
            return allConfigs.filter { !$0.tags.contains("adversarial-only") }

        case .adversarial:
            // Adversarial tier: sandbox configs only
            return allConfigs.filter { $0.tags.contains("sandbox") || $0.tags.contains("adversarial") }
        }
    }

    public func normalizeConfigChoice(
        intent: SessionIntent,
        candidateConfigId: String
    ) async throws -> String {
        // Check if config exists and is allowed for this trust tier
        guard getConfig(withId: candidateConfigId) != nil else {
            // Config doesn't exist, fall back to default for trust tier
            return getDefaultConfig(for: intent.featureCategory, trustTier: intent.trustTier)
        }

        // Check if config is allowed for this trust tier
        let allowedConfigs = getConfigs(for: intent.featureCategory, trustTier: intent.trustTier)
        guard allowedConfigs.contains(where: { $0.id == candidateConfigId }) else {
            // Config not allowed for this trust tier, downgrade to allowed one
            return downgradeConfig(for: intent, candidateConfigId: candidateConfigId)
        }

        return candidateConfigId
    }

    public func validateSessionPlan(
        intent: SessionIntent,
        configId: String
    ) async throws -> HarnessGovernanceDecision {
        // Check if config exists
        guard let config = getConfig(withId: configId) else {
            return .deny(reason: "Config \(configId) not found")
        }

        // Check if config is allowed for this trust tier
        let allowedConfigs = getConfigs(for: intent.featureCategory, trustTier: intent.trustTier)
        guard allowedConfigs.contains(where: { $0.id == configId }) else {
            return .deny(reason: "Config \(configId) not allowed for trust tier \(intent.trustTier)")
        }

        // Additional trust tier specific checks
        switch intent.trustTier {
        case .system:
            // System tier requires canonical configs
            if !config.tags.contains("canonical") && !config.tags.contains("system") {
                return .requireEscalation(reason: "System tier using non-canonical config")
            }

        case .adversarial:
            // Adversarial tier should use sandbox configs
            if !config.tags.contains("sandbox") && !config.tags.contains("adversarial") {
                return .requireEscalation(reason: "Adversarial tier using non-sandbox config")
            }

        case .trusted:
            // Trusted tier: normal checks already passed
            break
        }

        return .allow
    }

    // MARK: - Private Helpers

    private func getDefaultConfig(for category: String, trustTier: SessionTrustTier) -> String {
        let allowedConfigs = getConfigs(for: category, trustTier: trustTier)

        // Try to find a canonical config first
        if let canonical = allowedConfigs.first(where: { $0.tags.contains("canonical") }) {
            return canonical.id
        }

        // Otherwise use first allowed config
        if let first = allowedConfigs.first {
            return first.id
        }

        // Fallback
        return "default"
    }

    private func downgradeConfig(for intent: SessionIntent, candidateConfigId: String) -> String {
        // Log the downgrade
        print("[PolicyRegistry] Downgrading config \(candidateConfigId) for trust tier \(intent.trustTier)")

        // Get allowed configs for this trust tier
        let allowedConfigs = getConfigs(for: intent.featureCategory, trustTier: intent.trustTier)

        // Try to find a similar config (same category, different trust level)
        if let similar = allowedConfigs.first(where: { $0.featureCategories.contains(intent.featureCategory) }) {
            return similar.id
        }

        // Fall back to default for trust tier
        return getDefaultConfig(for: intent.featureCategory, trustTier: intent.trustTier)
    }
}

// MARK: - Bandit Governor Implementation (Thrones)

/// Bandit governor implementation wrapping BanditConfigSelector.
/// Angelic mapping: Thrones (executes policy through bandit learning)
public actor BanditGovernorImpl: BanditGovernor {
    private let selector: BanditConfigSelector
    private let policyRegistry: PolicyRegistry

    public init(
        selector: BanditConfigSelector = BanditConfigSelector(),
        policyRegistry: PolicyRegistry = BlessedPolicyRegistry()
    ) {
        self.selector = selector
        self.policyRegistry = policyRegistry
    }

    public func selectConfig(
        intent: SessionIntent
    ) async throws -> String {
        // Trust tier determines the bandit lane
        switch intent.trustTier {
        case .system:
            // System tier: no bandit learning, use canonical configs only
            // Policy registry will handle this
            return "system_default"

        case .trusted:
            // Trusted tier: normal bandit learning with main state
            return try await selector.selectConfig(
                projectId: intent.projectId,
                featureCategory: intent.featureCategory
            )

        case .adversarial:
            // Adversarial tier: separate bandit state for red-team
            // Use adversarial-specific storage key
            _ = "adversarial:\(intent.featureCategory)"
            // For now, fall back to default config
            // In future: separate bandit state for adversarial lane
            return "adversarial_default"
        }
    }

    public func recordOutcome(
        intent: SessionIntent,
        configId: String,
        reward: Double
    ) async throws {
        // Skip learning for system tier (policy-driven, not regret-driven)
        guard intent.trustTier != .system else {
            return
        }

        // Skip learning for tainted sessions (handled by epilogue)
        // This will be called by the epilogue runner

        // For adversarial tier, we'd update separate bandit state
        // For now, just update main state for trusted tier
        if intent.trustTier == .trusted {
            // In a real implementation, this would update bandit stats
            // using a lane-specific key
        }
    }

    /// Updates bandit reward, skipping tainted sessions.
    public func updateReward(
        for report: SessionReport,
        tainted: Bool
    ) async throws {
        guard !tainted else {
            // Skip learning for tainted sessions
            return
        }

        guard let configId = report.configId,
              let featureCategory = report.featureCategory else {
            return
        }

        // Use bandit reward from report
        let reward = report.banditReward

        let lane = report.governanceTrace?.lane?.name ?? "normal"
        let laneCategory = lane == "normal" ? featureCategory : "\(featureCategory)#\(lane)"

        try await selector.updateStats(
            projectId: report.projectId,
            featureCategory: laneCategory,
            configId: configId,
            reward: reward
        )
    }
}

// MARK: - Gatekeeper Implementation (Cherubim)

/// Gatekeeper implementation wrapping ToolUsageInspector.
/// Angelic mapping: Cherubim (guards access, checks behavioral invariants)
public actor GatekeeperImpl: Gatekeeper {
    private let inspector: ToolUsageInspector
    private let invariants: BehavioralInvariants

    public init(
        inspector: ToolUsageInspector = ToolUsageInspector(),
        invariants: BehavioralInvariants = .juniorEngineer
    ) {
        self.inspector = inspector
        self.invariants = invariants
    }

    public func evaluate(
        intent: SessionIntent,
        configId: String
    ) async throws -> HarnessGovernanceDecision {
        // For now, always allow
        // In a real implementation, this would check behavioral invariants
        // and other gatekeeping rules
        return .allow
    }

    private func filterViolations(
        _ violations: [InvariantViolation],
        for trustTier: SessionTrustTier
    ) -> [InvariantViolation] {
        switch trustTier {
        case .system:
            // System tier sees all violations
            return violations

        case .trusted:
            // Trusted tier sees only critical violations
            return violations.filter { $0.severity >= 0.7 }

        case .adversarial:
            // Adversarial tier sees only critical violations with severity > 0.8
            return violations.filter { $0.severity > 0.8 }
        }
    }
}

// MARK: - Security Enforcer Implementation (Dominions)

/// Security enforcer implementation with quarantine logic.
/// Angelic mapping: Dominions (enforces security, quarantines bad actors)
public actor SecurityEnforcerImpl: SecurityEnforcer {
    private let store: ProjectHarnessStore
    private var quarantineRegistry: [UUID: QuarantineStatus] = [:]

    public init(store: ProjectHarnessStore = .shared) {
        self.store = store
    }

    public func handleViolation(
        _ event: GovernanceLogEvent
    ) async {
        // Log the violation
        print("🚨 Security violation: \(event.message)")

        // Check if we should quarantine
        if event.severity == .critical {
            let reason = "Critical security violation: \(event.message)"
            do {
                try await quarantineProject(
                    projectId: event.projectId,
                    reason: reason,
                    duration: 3600 // 1 hour
                )
            } catch {
                print("Failed to quarantine project: \(error)")
            }
        }
    }

    public func isProjectQuarantined(
        _ projectId: UUID
    ) async -> Bool {
        if let status = quarantineRegistry[projectId], status.isActive {
            return true
        }
        return false
    }

    public func quarantineProject(
        projectId: UUID,
        reason: String,
        duration: TimeInterval = 3600 // 1 hour
    ) async throws {
        let status = QuarantineStatus(
            projectId: projectId,
            reason: reason,
            startTime: Date(),
            endTime: Date().addingTimeInterval(duration),
            isActive: true
        )

        quarantineRegistry[projectId] = status

        // Log quarantine event to console
        print("🚨 Project \(projectId.uuidString.prefix(8)) quarantined: \(reason)")
    }

    public func releaseFromQuarantine(projectId: UUID) async throws {
        if let status = quarantineRegistry[projectId] {
            let newStatus = QuarantineStatus(
                projectId: projectId,
                reason: status.reason,
                startTime: status.startTime,
                endTime: Date(),
                isActive: false
            )

            quarantineRegistry[projectId] = newStatus

            // Log release event to console
            print("✅ Project \(projectId.uuidString.prefix(8)) released from quarantine")
        }
    }

    public func getQuarantineStatus(projectId: UUID) -> QuarantineStatus? {
        quarantineRegistry[projectId]
    }

    public func getQuarantineStatus(
        projectId: UUID
    ) async -> QuarantineStatus? {
        quarantineRegistry[projectId]
    }

    private func getRecentViolations(
        projectId: UUID,
        limit: Int
    ) async throws -> [InvariantViolation] {
        // This would query the store for recent violations
        // For now, return empty array
        return []
    }
}

// MARK: - Harness Runner Implementation (Archangels)

/// Harness runner implementation wrapping existing harness execution.
/// Angelic mapping: Archangels (executes the actual work)
public actor HarnessRunnerImpl: HarnessRunner {
    private let store: ProjectHarnessStore

    public init(store: ProjectHarnessStore = .shared) {
        self.store = store
    }

    public func run(
        intent: SessionIntent,
        project: ProjectSpec,
        configId: String
    ) async throws -> SessionReport {
        // This would execute the actual harness session
        // For now, create a mock report with healthy metrics

        let sessionIndex = try await getNextSessionIndex(projectId: project.id)

        // Create healthy metrics
        let metrics = BehavioralHealthMetrics(
            sessionIndex: sessionIndex,
            projectId: project.id,
            featureId: nil,
            analysisRatio: 0.5,
            firstEditLatency: 3,
            toolDiversity: 2,
            editCalls: 10,
            analysisCalls: 8,
            testCalls: 5,
            filesChanged: nil,
            linesChanged: nil,
            testsPassed: 5,
            testsFailed: 0,
            formatterSucceeded: true,
            formatterWarnings: nil,
            formatterErrors: nil,
            gitDiffSummary: nil,
            lintSucceeded: true,
            lintWarnings: nil,
            lintErrors: nil
        )

        let report = SessionReport(
            sessionIndex: sessionIndex,
            projectId: project.id,
            featureId: nil,
            metrics: metrics,
            violations: [],
            toolSummary: ["edit": 10, "analyze": 8, "test": 5],
            narrative: "Session completed via governance protocols",
            recommendations: [],
            verdict: "Healthy",
            generatedAt: Date(),
            acknowledgedAt: nil,
            configId: configId,
            featureCategory: intent.featureCategory
        )

        // Save the session report
        try await store.saveSessionReport(report)

        return report
    }

    private func getNextSessionIndex(projectId: UUID) async throws -> Int {
        let snapshots = try await store.getProgressSnapshots(projectId: projectId)
        return (snapshots.last?.sessionIndex ?? 0) + 1
    }
}

// MARK: - Console Event Sink

/// Simple console event sink for logging governance events.
public actor ConsoleEventSink: GovernanceEventSink {
    public init() {}

    public func emit(_ event: GovernanceLogEvent) async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let severityIcon: String
        switch event.severity {
        case .info: severityIcon = "ℹ️"
        case .warning: severityIcon = "⚠️"
        case .critical: severityIcon = "🚨"
        }

        print("\(severityIcon) [\(timestamp)] Project \(event.projectId.uuidString.prefix(8)): \(event.message)")

        if !event.context.isEmpty {
            let contextStr = event.context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            print("   Context: \(contextStr)")
        }
    }
}

// MARK: - Supporting Types

public struct QuarantineStatus: Sendable {
    public let projectId: UUID
    public let reason: String
    public let startTime: Date
    public let endTime: Date
    public var isActive: Bool

    public init(
        projectId: UUID,
        reason: String,
        startTime: Date,
        endTime: Date,
        isActive: Bool
    ) {
        self.projectId = projectId
        self.reason = reason
        self.startTime = startTime
        self.endTime = endTime
        self.isActive = isActive
    }

    public var timeRemaining: TimeInterval {
        max(0, endTime.timeIntervalSince(Date()))
    }
}
