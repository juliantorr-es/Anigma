//
//  GovernanceProtocols.swift
//  HarmoniaModule
//
//  Phase B: Governance vocabulary layer.
//  Neutral names, angelic mapping in comments only.
//  Defines the "choir" interfaces without touching the bones.
//

import Foundation
import AnigmaPrimitives

// MARK: - Shared core types

/// Trust tier for session execution.
/// System: "holy" - internal, non-negotiable configs/agents
/// Trusted: "mortal but allowed" - normal harness runs, scouts, etc.
/// Adversarial: fuzzers, red-team, weird external jobs
public enum SessionTrustTier: String, Codable, Sendable {
    case system
    case trusted
    case adversarial
}

/// Intent description sent into the governance stack before a session runs.
public struct SessionIntent: Sendable {
    public let projectId: UUID
    public let featureCategory: String
    public let requestedConfigId: String?
    public let trustTier: SessionTrustTier
    public let lane: SessionLane?
    public let metadata: [String: String]

public init(
        projectId: UUID,
        featureCategory: String,
        requestedConfigId: String? = nil,
        trustTier: SessionTrustTier = .trusted,
        lane: SessionLane? = nil,
        metadata: [String: String] = [:]
    ) {
        self.projectId = projectId
        self.featureCategory = featureCategory
        self.requestedConfigId = requestedConfigId
        self.trustTier = trustTier
        self.lane = lane
        self.metadata = metadata
    }
}

// MARK: - Trust tier bridging

public extension SessionTrustTier {
    init(trustTier: TrustTier) {
        switch trustTier {
        case .platinum:
            self = .system
        case .trusted:
            self = .trusted
        default:
            self = .trusted
        }
    }
}

public extension TrustTier {
    var sessionTrustTier: SessionTrustTier {
        switch self {
        case .platinum:
            return .system
        case .trusted:
            return .trusted
        default:
            return .trusted
        }
    }
}

/// Result of a governance check.
public enum HarnessGovernanceDecision: Sendable {
    case allow
    case deny(reason: String)
    case requireEscalation(reason: String)
}

/// Severity for violations flowing up the chain.
public enum GovernanceSeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

/// Event emitted when something goes wrong or interesting.
public struct GovernanceLogEvent: Sendable {
    public let projectId: UUID
    public let severity: GovernanceSeverity
    public let code: String       // machine-readable
    public let message: String    // human-readable
    public let context: [String: String]

    public init(
        projectId: UUID,
        severity: GovernanceSeverity,
        code: String,
        message: String,
        context: [String: String] = [:]
    ) {
        self.projectId = projectId
        self.severity = severity
        self.code = code
        self.message = message
        self.context = context
    }
}

// MARK: - PolicyRegistry (Seraphim layer)

/// Defines non-negotiable constraints and blessed configs.
/// Think: "tests must pass", "no writes outside sandbox", "only blessed configs".
public protocol PolicyRegistry: Sendable {
    /// Returns id of a blessed config if the requested one is not allowed for this intent.
    func normalizeConfigChoice(
        intent: SessionIntent,
        candidateConfigId: String
    ) async throws -> String

    /// Validate that the resulting session plan is allowed at all.
    func validateSessionPlan(
        intent: SessionIntent,
        configId: String
    ) async throws -> HarnessGovernanceDecision
}

// MARK: - Gatekeeper (Cherubim layer)

/// Performs per-session checks right before execution.
/// Schema guards, permission checks, rate limits, etc.
public protocol Gatekeeper: Sendable {
    func evaluate(
        intent: SessionIntent,
        configId: String
    ) async throws -> HarnessGovernanceDecision
}

// MARK: - BanditGovernor (Virtues/Thrones layer)

/// Wraps bandit logic: selection + learning, bounded by blessed configs.
public protocol BanditGovernor: Sendable {
    /// Suggest a config id for this intent, before Seraphim normalization.
    func selectConfig(
        intent: SessionIntent
    ) async throws -> String

    /// Update bandit state from a completed session.
    func recordOutcome(
        intent: SessionIntent,
        configId: String,
        reward: Double
    ) async throws
}

// MARK: - SecurityEnforcer (Powers / Dominions layer)

/// Responsible for kill switches, quarantines, intrusion detection.
public protocol SecurityEnforcer: Sendable {
    /// Called when something bad happens during or after the run.
    func handleViolation(
        _ event: GovernanceLogEvent
    ) async

    /// Whether a project is currently quarantined / blocked.
    func isProjectQuarantined(
        _ projectId: UUID
    ) async -> Bool

    /// Gets quarantine status details if project is quarantined.
    func getQuarantineStatus(
        projectId: UUID
    ) async -> QuarantineStatus?
}

// MARK: - HarnessRunner (Archangel layer)

/// Executes the actual work under a finalized plan.
/// No policy decisions here, just "do the job" and report.
public protocol HarnessRunner: Sendable {
    func run(
        intent: SessionIntent,
        project: ProjectSpec,
        configId: String
    ) async throws -> SessionReport
}

// MARK: - GovernanceEventSink

/// Optional sink all layers can use to emit events.
/// Your Principality can implement this and fan out to logs/metrics.
public protocol GovernanceEventSink: Sendable {
    func emit(_ event: GovernanceLogEvent) async
}

// MARK: - Governance Trace Types

/// Policy decision outcome.
public enum PolicyDecision: String, Codable, Sendable {
    case allowed
    case denied
    case downgraded // e.g., forced safer config
    case escalated  // requires human review
}

/// Security outcome for a session.
public enum SecurityOutcome: String, Codable, Sendable {
    case clean
    case quarantined
    case quarantinedAfter // post-hoc quarantine
    case tainted          // marked as suspicious but not quarantined
}

/// Finding from gatekeeper or post-hoc analysis.
public struct GovernanceFinding: Codable, Sendable {
    public let code: String
    public let message: String
    public let severity: GovernanceSeverity
    public let timestamp: Date

    public init(
        code: String,
        message: String,
        severity: GovernanceSeverity,
        timestamp: Date = Date()
    ) {
        self.code = code
        self.message = message
        self.severity = severity
        self.timestamp = timestamp
    }
}

/// Lane for session execution (normal vs adversarial with specific demon).
public enum SessionLane: Sendable, Codable {
    case normal
    case adversarial(name: String) // "fuzzer", "prompt-injection-tester", etc.

    public var name: String {
        switch self {
        case .normal: return "normal"
        case .adversarial(let name): return "adversarial:\(name)"
        }
    }
}

/// Complete trace of governance decisions for a session.
public struct GovernanceTrace: Codable, Sendable {
    public var configId: String?
    public var trustTier: SessionTrustTier
    public var lane: SessionLane?
    public var policyDecision: PolicyDecision
    public var gatekeeperFindings: [GovernanceFinding]
    public var securityOutcome: SecurityOutcome
    public var escalated: Bool
    public var tainted: Bool
    public var quarantineApplied: Bool
    public var timestamp: Date

    public init(
        configId: String?,
        trustTier: SessionTrustTier,
        lane: SessionLane? = nil,
        policyDecision: PolicyDecision,
        gatekeeperFindings: [GovernanceFinding] = [],
        securityOutcome: SecurityOutcome = .clean,
        escalated: Bool = false,
        tainted: Bool = false,
        quarantineApplied: Bool = false,
        timestamp: Date = Date()
    ) {
        self.configId = configId
        self.trustTier = trustTier
        self.lane = lane
        self.policyDecision = policyDecision
        self.gatekeeperFindings = gatekeeperFindings
        self.securityOutcome = securityOutcome
        self.escalated = escalated
        self.tainted = tainted
        self.quarantineApplied = quarantineApplied
        self.timestamp = timestamp
    }

    public static func `default`(
        configId: String? = nil,
        trustTier: SessionTrustTier = .trusted,
        lane: SessionLane? = nil
    ) -> GovernanceTrace {
        GovernanceTrace(
            configId: configId,
            trustTier: trustTier,
            lane: lane,
            policyDecision: .allowed,
            gatekeeperFindings: [],
            securityOutcome: .clean,
            escalated: false,
            tainted: false,
            quarantineApplied: false
        )
    }
}

// MARK: - Governance Errors

public enum GovernanceError: LocalizedError {
    case projectQuarantined(UUID)
    case policyDenied(reason: String)
    case policyEscalationRequired(reason: String)
    case gatekeeperDenied(reason: String)
    case gatekeeperEscalationRequired(reason: String)
    case configNotAllowed(String)
    case insufficientTrust(SessionTrustTier, required: SessionTrustTier)

    public var errorDescription: String? {
        switch self {
        case .projectQuarantined(let projectId):
            return "Project is quarantined: \(projectId)"
        case .policyDenied(let reason):
            return "Policy denied: \(reason)"
        case .policyEscalationRequired(let reason):
            return "Policy escalation required: \(reason)"
        case .gatekeeperDenied(let reason):
            return "Gatekeeper denied: \(reason)"
        case .gatekeeperEscalationRequired(let reason):
            return "Gatekeeper escalation required: \(reason)"
        case .configNotAllowed(let configId):
            return "Config not allowed: \(configId)"
        case .insufficientTrust(let current, let required):
            return "Insufficient trust tier: \(current) < \(required)"
        }
    }
}
