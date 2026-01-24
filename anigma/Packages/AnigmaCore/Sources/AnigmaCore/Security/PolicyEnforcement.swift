//
//  PolicyEnforcement.swift
//  AnigmaCore
//
//  Hybrid policy enforcement infrastructure.
//  Provides in-band Policy Enforcement Points (PEPs) for zero-latency enforcement.
//
//  This addresses the critical latency gap between detection and enforcement
//  that exists in purely passive monitoring systems.
//
//  Design principles:
//  - Zero-latency enforcement for critical threats
//  - In-band PEPs that block traffic synchronously
//  - Integration with external enforcement systems
//  - Audit trail for all enforcement actions
//

import Foundation
import ContractsCore
import AnigmaPrimitives

// MARK: - Threat Levels

/// Severity levels for detected threats.
public enum ThreatLevel: Int, Sendable, Codable, Comparable {
    /// Informational - log only.
    case info = 0

    /// Low - monitor closely.
    case low = 1

    /// Medium - alert and consider action.
    case medium = 2

    /// High - immediate response required.
    case high = 3

    /// Critical - automatic blocking.
    case critical = 4

    public static func < (lhs: ThreatLevel, rhs: ThreatLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .info: return "INFO"
        case .low: return "LOW"
        case .medium: return "MEDIUM"
        case .high: return "HIGH"
        case .critical: return "CRITICAL"
        }
    }
}

// MARK: - Enforcement Actions

/// Actions that can be taken by policy enforcement.
public enum EnforcementAction: String, Sendable, Codable {
    /// Allow the operation to proceed.
    case allow = "ALLOW"

    /// Log the operation but allow.
    case logOnly = "LOG_ONLY"

    /// Rate limit the source.
    case rateLimit = "RATE_LIMIT"

    /// Require additional authentication.
    case stepUpAuth = "STEP_UP_AUTH"

    /// Quarantine for manual review.
    case quarantine = "QUARANTINE"

    /// Block the operation.
    case block = "BLOCK"

    /// Terminate the session.
    case terminateSession = "TERMINATE_SESSION"

    /// Isolate the source entirely.
    case isolate = "ISOLATE"
}

// MARK: - Threat Detection

/// A detected threat requiring enforcement.
public struct DetectedThreat: Sendable, Codable, Identifiable {
    public let id: UUID

    /// Type of threat.
    public let threatType: String

    /// Severity level.
    public let level: ThreatLevel

    /// Source identifier (user, IP, session, etc.).
    public let source: String

    /// Target of the threat (resource, entity, etc.).
    public let target: String?

    /// Description of the threat.
    public let description: String

    /// Evidence supporting the detection.
    public let evidence: [String: String]

    /// When the threat was detected.
    public let detectedAt: Date

    /// Confidence in the detection (0.0 - 1.0).
    public let confidence: Double

    /// XAI explanation ID if available.
    public let explanationId: UUID?

    public init(
        id: UUID = UUID(),
        threatType: String,
        level: ThreatLevel,
        source: String,
        target: String? = nil,
        description: String,
        evidence: [String: String] = [:],
        detectedAt: Date = Date(),
        confidence: Double = 1.0,
        explanationId: UUID? = nil
    ) {
        self.id = id
        self.threatType = threatType
        self.level = level
        self.source = source
        self.target = target
        self.description = description
        self.evidence = evidence
        self.detectedAt = detectedAt
        self.confidence = min(1.0, max(0.0, confidence))
        self.explanationId = explanationId
    }
}

// MARK: - Enforcement Decision

/// A decision made by the policy enforcement system.
public struct EnforcementDecision: Sendable, Codable, Identifiable {
    public let id: UUID

    /// The threat that triggered this decision.
    public let threatId: UUID

    /// The action taken.
    public let action: EnforcementAction

    /// Why this action was taken.
    public let reason: String

    /// The policy that mandated this action.
    public let policyId: String

    /// When the decision was made.
    public let decidedAt: Date

    /// When the enforcement expires (for temporary actions).
    public let expiresAt: Date?

    /// Whether the action was successfully applied.
    public var wasApplied: Bool

    /// Error message if application failed.
    public var applicationError: String?

    public init(
        id: UUID = UUID(),
        threatId: UUID,
        action: EnforcementAction,
        reason: String,
        policyId: String,
        decidedAt: Date = Date(),
        expiresAt: Date? = nil,
        wasApplied: Bool = false,
        applicationError: String? = nil
    ) {
        self.id = id
        self.threatId = threatId
        self.action = action
        self.reason = reason
        self.policyId = policyId
        self.decidedAt = decidedAt
        self.expiresAt = expiresAt
        self.wasApplied = wasApplied
        self.applicationError = applicationError
    }
}

// MARK: - Enforcement Policy

/// A policy that maps threats to enforcement actions.
public protocol EnforcementPolicy: Sendable {
    /// Unique identifier.
    var id: String { get }

    /// Human-readable name.
    var name: String { get }

    /// Priority (higher = evaluated first).
    var priority: Int { get }

    /// Evaluates a threat and returns the recommended action.
    func evaluate(_ threat: DetectedThreat) -> EnforcementAction?

    /// Gets the expiration duration for an action (nil = permanent).
    func expirationDuration(for action: EnforcementAction) -> TimeInterval?
}

/// Default policy based on threat level.
public struct ThreatLevelPolicy: EnforcementPolicy, Sendable {
    public let id: String
    public let name: String
    public let priority: Int

    /// Actions for each threat level.
    public let levelActions: [ThreatLevel: EnforcementAction]

    /// Minimum confidence to take action.
    public let minimumConfidence: Double

    public init(
        id: String = "threat-level-default",
        name: String = "Default Threat Level Policy",
        priority: Int = 100,
        levelActions: [ThreatLevel: EnforcementAction] = [
            .info: .logOnly,
            .low: .logOnly,
            .medium: .rateLimit,
            .high: .quarantine,
            .critical: .block
        ],
        minimumConfidence: Double = 0.7
    ) {
        self.id = id
        self.name = name
        self.priority = priority
        self.levelActions = levelActions
        self.minimumConfidence = minimumConfidence
    }

    public func evaluate(_ threat: DetectedThreat) -> EnforcementAction? {
        guard threat.confidence >= minimumConfidence else {
            return .logOnly
        }

        return levelActions[threat.level]
    }

    public func expirationDuration(for action: EnforcementAction) -> TimeInterval? {
        switch action {
        case .rateLimit: return 300     // 5 minutes
        case .quarantine: return 3600   // 1 hour
        case .block: return 86400       // 24 hours
        case .terminateSession: return nil
        case .isolate: return nil
        default: return nil
        }
    }
}

/// Policy for specific threat types.
public struct ThreatTypePolicy: EnforcementPolicy, Sendable {
    public let id: String
    public let name: String
    public let priority: Int

    /// Threat types this policy handles.
    public let threatTypes: Set<String>

    /// Action to take for these threats.
    public let action: EnforcementAction

    /// How long the action lasts.
    public let duration: TimeInterval?

    public init(
        id: String,
        name: String,
        priority: Int = 200,
        threatTypes: Set<String>,
        action: EnforcementAction,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.priority = priority
        self.threatTypes = threatTypes
        self.action = action
        self.duration = duration
    }

    public func evaluate(_ threat: DetectedThreat) -> EnforcementAction? {
        guard threatTypes.contains(threat.threatType) else {
            return nil
        }
        return action
    }

    public func expirationDuration(for action: EnforcementAction) -> TimeInterval? {
        duration
    }
}

// MARK: - Policy Enforcement Point (PEP)

/// Protocol for Policy Enforcement Points.
/// PEPs are the execution layer that applies enforcement decisions.
public protocol PolicyEnforcementPoint: Sendable {
    /// Unique identifier for this PEP.
    var id: String { get }

    /// Type of enforcement this PEP provides.
    var enforcementType: String { get }

    /// Actions this PEP can execute.
    var supportedActions: Set<EnforcementAction> { get }

    /// Applies an enforcement decision.
    func apply(_ decision: EnforcementDecision, threat: DetectedThreat) async throws

    /// Revokes a previous enforcement decision.
    func revoke(_ decision: EnforcementDecision) async throws

    /// Checks if an enforcement is still active.
    func isActive(_ decision: EnforcementDecision) async -> Bool
}

// MARK: - In-Memory Rate Limiter PEP

/// In-memory rate limiter for demonstration.
public actor InMemoryRateLimiter: PolicyEnforcementPoint {
    public let id: String
    public let enforcementType = "rate_limit"
    public let supportedActions: Set<EnforcementAction> = [.rateLimit, .block]

    private var blocked: [String: Date] = [:]  // source -> unblock time
    private var rateLimited: [String: (count: Int, resetAt: Date)] = [:]

    private let maxRequests: Int
    private let windowSeconds: TimeInterval

    public init(id: String = "rate-limiter", maxRequests: Int = 100, windowSeconds: TimeInterval = 60) {
        self.id = id
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
    }

    public func apply(_ decision: EnforcementDecision, threat: DetectedThreat) async throws {
        let source = threat.source

        switch decision.action {
        case .block:
            let unblockAt = decision.expiresAt ?? Date.distantFuture
            blocked[source] = unblockAt

        case .rateLimit:
            let resetAt = Date().addingTimeInterval(windowSeconds)
            rateLimited[source] = (count: maxRequests / 2, resetAt: resetAt)  // Reduce allowance

        default:
            throw EnforcementError.unsupportedAction(decision.action)
        }
    }

    public func revoke(_ decision: EnforcementDecision) async throws {
        // We'd need to track which source was affected
        // For simplicity, this is a no-op in the demo
    }

    public func isActive(_ decision: EnforcementDecision) async -> Bool {
        if let expiresAt = decision.expiresAt {
            return Date() < expiresAt
        }
        return true
    }

    /// Checks if a request from a source should be allowed.
    public func shouldAllow(source: String) -> Bool {
        // Check block list
        if let unblockAt = blocked[source] {
            if Date() < unblockAt {
                return false
            } else {
                blocked.removeValue(forKey: source)
            }
        }

        // Check rate limit
        if var limit = rateLimited[source] {
            if Date() >= limit.resetAt {
                // Reset the window
                limit = (count: maxRequests, resetAt: Date().addingTimeInterval(windowSeconds))
                rateLimited[source] = limit
            }

            if limit.count <= 0 {
                return false
            }

            limit.count -= 1
            rateLimited[source] = limit
        }

        return true
    }
}

// MARK: - Session Terminator PEP

/// PEP that terminates sessions.
public actor SessionTerminator: PolicyEnforcementPoint {
    public let id: String
    public let enforcementType = "session"
    public let supportedActions: Set<EnforcementAction> = [.terminateSession]

    private var terminatedSessions: Set<String> = []

    public init(id: String = "session-terminator") {
        self.id = id
    }

    public func apply(_ decision: EnforcementDecision, threat: DetectedThreat) async throws {
        // In a real implementation, this would call into a session manager
        terminatedSessions.insert(threat.source)
    }

    public func revoke(_ decision: EnforcementDecision) async throws {
        // Sessions can't be un-terminated, but we can allow new ones
    }

    public func isActive(_ decision: EnforcementDecision) async -> Bool {
        true  // Session termination is permanent for that session
    }

    /// Checks if a session has been terminated.
    public func isSessionTerminated(_ sessionId: String) -> Bool {
        terminatedSessions.contains(sessionId)
    }
}

// MARK: - Policy Enforcement Engine

/// Central engine that coordinates threat detection and policy enforcement.
public actor PolicyEnforcementEngine {
    private var policies: [any EnforcementPolicy] = []
    private var peps: [String: any PolicyEnforcementPoint] = [:]
    private var decisions: [UUID: EnforcementDecision] = [:]
    private var auditLog: (any AuditLogging)?

    public init() {
        // Add default policy
        policies.append(ThreatLevelPolicy())
    }

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Registers a policy.
    public func registerPolicy(_ policy: any EnforcementPolicy) {
        policies.append(policy)
        policies.sort { $0.priority > $1.priority }
    }

    /// Removes a policy.
    public func removePolicy(id: String) {
        policies.removeAll { $0.id == id }
    }

    /// Registers a Policy Enforcement Point.
    public func registerPEP(_ pep: any PolicyEnforcementPoint) {
        peps[pep.id] = pep
    }

    /// Removes a PEP.
    public func removePEP(id: String) {
        peps.removeValue(forKey: id)
    }

    /// Processes a detected threat and enforces appropriate action.
    /// This is the main entry point for the enforcement engine.
    public func enforce(_ threat: DetectedThreat) async -> EnforcementDecision {
        // Evaluate policies to determine action
        var selectedAction: EnforcementAction = .logOnly
        var selectedPolicy: (any EnforcementPolicy)?
        var expiresAt: Date?

        for policy in policies {
            if let action = policy.evaluate(threat) {
                selectedAction = action
                selectedPolicy = policy
                if let duration = policy.expirationDuration(for: action) {
                    expiresAt = Date().addingTimeInterval(duration)
                }
                break
            }
        }

        var decision = EnforcementDecision(
            threatId: threat.id,
            action: selectedAction,
            reason: "Policy \(selectedPolicy?.name ?? "default") selected action \(selectedAction.rawValue) for threat level \(threat.level.label)",
            policyId: selectedPolicy?.id ?? "default",
            expiresAt: expiresAt
        )

        // Apply enforcement through appropriate PEPs
        var applied = false
        var errors: [String] = []

        for pep in peps.values {
            if pep.supportedActions.contains(selectedAction) {
                do {
                    try await pep.apply(decision, threat: threat)
                    applied = true
                } catch {
                    errors.append("\(pep.id): \(error.localizedDescription)")
                }
            }
        }

        decision.wasApplied = applied
        if !errors.isEmpty {
            decision.applicationError = errors.joined(separator: "; ")
        }

        // Store decision
        decisions[decision.id] = decision

        // Audit log
        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: applied ? ContractsCore.AuditEventType.policyEvaluated : ContractsCore.AuditEventType.policyViolation,
                principal: threat.source,
                module: "PolicyEnforcement",
                description: "Enforcement: \(selectedAction.rawValue) for \(threat.threatType)",
                metadata: [
                    "threat_id": threat.id.uuidString,
                    "decision_id": decision.id.uuidString,
                    "action": selectedAction.rawValue,
                    "policy": selectedPolicy?.id ?? "default",
                    "applied": applied ? "true" : "false"
                ]
            )
        }

        return decision
    }

    /// Processes a threat synchronously and blocks if necessary.
    /// This is the zero-latency enforcement path.
    public func enforceBlocking(_ threat: DetectedThreat) async throws {
        let decision = await enforce(threat)

        if decision.action == .block && !decision.wasApplied {
            throw EnforcementError.enforcementFailed(
                action: decision.action,
                reason: decision.applicationError ?? "Unknown error"
            )
        }
    }

    /// Revokes an enforcement decision.
    public func revoke(decisionId: UUID, reason: String) async throws {
        guard var decision = decisions[decisionId] else {
            throw EnforcementError.decisionNotFound(decisionId)
        }

        for pep in peps.values {
            if pep.supportedActions.contains(decision.action) {
                try await pep.revoke(decision)
            }
        }

        decision.wasApplied = false
        decisions[decisionId] = decision

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.custom,
                principal: "policy_enforcement",
                module: "PolicyEnforcement",
                description: "Enforcement revoked: \(reason)",
                metadata: [
                    "decision_id": decisionId.uuidString,
                    "action": decision.action.rawValue,
                    "original_event_type": "humanOverride"
                ]
            )
        }
    }

    /// Gets a decision by ID.
    public func getDecision(_ id: UUID) -> EnforcementDecision? {
        decisions[id]
    }

    /// Gets recent decisions.
    public func recentDecisions(limit: Int = 100) -> [EnforcementDecision] {
        Array(decisions.values.sorted { $0.decidedAt > $1.decidedAt }.prefix(limit))
    }

    /// Cleans up expired decisions.
    public func cleanupExpired() async {
        let now = Date()
        let expired = decisions.filter { _, decision in
            if let expiresAt = decision.expiresAt {
                return now >= expiresAt
            }
            return false
        }

        for (id, decision) in expired {
            for pep in peps.values {
                if pep.supportedActions.contains(decision.action) {
                    try? await pep.revoke(decision)
                }
            }
            decisions.removeValue(forKey: id)
        }
    }

    /// Evaluates a candidate action against policies.
    public func evaluateAction(
        action: CandidateAction,
        context: StepContext,
        trustTier: TrustTier
    ) async throws -> PolicyEvaluationResult {
        // Placeholder implementation:
        // In a real scenario, this would involve complex logic:
        // 1. Checking action against registered policies (e.g., access control, data sensitivity)
        // 2. Considering the StepContext (e.g., current security zone, allowed capabilities)
        // 3. Factoring in the required TrustTier
        // 4. Generating PolicyFlags for warnings/information
        // 5. Identifying PolicyViolations for disallowed actions

        // For now, we return a default "allowed" result.
        // You can add more sophisticated logic here later.

        var policyFlags: [PolicyFlag] = []
        var policyViolations: [PolicyViolation] = []
        var allowed = true

        // Example placeholder logic:
        // If action type is deleteFile and trustTier is too low, add a violation
        if action.type == .deleteFile && trustTier < .gold {
            allowed = false
            policyViolations.append(PolicyViolation(
                policy: "DeletePolicy",
                rule: "MinTrustTier",
                severity: .critical,
                description: "Cannot delete files with trust tier below Gold.",
                remediation: "Increase trust tier or remove delete action."
            ))
        }

        // If a highly sensitive action is attempted in a low security zone, add a flag
        if action.type == .callAPI && context.securityZone == .sandbox {
            policyFlags.append(PolicyFlag(
                policy: "NetworkPolicy",
                severity: .warning,
                message: "API call from sandbox environment. Review carefully."
            ))
        }

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: allowed ? ContractsCore.AuditEventType.policyEvaluated : ContractsCore.AuditEventType.policyViolation,
                principal: context.sessionId,
                module: "PolicyEnforcement",
                description: "Action evaluation for \(action.type.rawValue)",
                metadata: [
                    "action_type": action.type.rawValue,
                    "trust_tier": trustTier.rawValue,
                    "allowed": String(allowed),
                    "violations": String(policyViolations.count)
                ]
            )
        }

        return PolicyEvaluationResult(allowed: allowed, flags: policyFlags, violations: policyViolations)
    }
}

// MARK: - Enforcement Errors

public enum EnforcementError: Error, LocalizedError, Sendable {
    case unsupportedAction(EnforcementAction)
    case enforcementFailed(action: EnforcementAction, reason: String)
    case decisionNotFound(UUID)
    case pepNotAvailable(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedAction(let action):
            return "Action not supported: \(action.rawValue)"
        case .enforcementFailed(let action, let reason):
            return "Failed to enforce \(action.rawValue): \(reason)"
        case .decisionNotFound(let id):
            return "Decision not found: \(id)"
        case .pepNotAvailable(let id):
            return "Policy Enforcement Point not available: \(id)"
        }
    }
}

// MARK: - Threat Detection Integration

/// Helper to create threats from various detection sources.
public struct ThreatFactory: Sendable {
    private init() {}

    /// Creates a threat from an access control denial.
    public static func fromAccessDenial(
        principal: String,
        resource: String,
        reason: String
    ) -> DetectedThreat {
        DetectedThreat(
            threatType: "ACCESS_VIOLATION",
            level: .medium,
            source: principal,
            target: resource,
            description: "Access denied: \(reason)",
            evidence: ["resource": resource, "reason": reason]
        )
    }

    /// Creates a threat from anomalous behavior.
    public static func fromAnomaly(
        source: String,
        anomalyScore: Double,
        description: String,
        explanationId: UUID? = nil
    ) -> DetectedThreat {
        let level: ThreatLevel = switch anomalyScore {
        case 0..<0.5: .low
        case 0.5..<0.7: .medium
        case 0.7..<0.9: .high
        default: .critical
        }

        return DetectedThreat(
            threatType: "BEHAVIORAL_ANOMALY",
            level: level,
            source: source,
            description: description,
            evidence: ["anomaly_score": String(format: "%.2f", anomalyScore)],
            confidence: anomalyScore,
            explanationId: explanationId
        )
    }

    /// Creates a threat from a data poisoning attempt.
    public static func fromPoisoningAttempt(
        source: String,
        modelId: UUID,
        poisoningType: String,
        confidence: Double
    ) -> DetectedThreat {
        DetectedThreat(
            threatType: "DATA_POISONING",
            level: ThreatLevel.critical, // Explicitly state ThreatLevel
            source: source,
            target: modelId.uuidString,
            description: "Suspected data poisoning: \(poisoningType)",
            evidence: ["model_id": modelId.uuidString, "type": poisoningType],
            confidence: confidence
        )
    }

    /// Creates a threat from repeated authentication failures.
    public static func fromAuthFailures(
        source: String,
        failureCount: Int,
        timeWindowMinutes: Int
    ) -> DetectedThreat {
        let level: ThreatLevel = switch failureCount {
        case 0..<5: .low
        case 5..<10: .medium
        case 10..<20: .high
        default: .critical
        }

        return DetectedThreat(
            threatType: "BRUTE_FORCE_ATTEMPT",
            level: level,
            source: source,
            description: "\(failureCount) failed auth attempts in \(timeWindowMinutes) minutes",
            evidence: [
                "failure_count": String(failureCount),
                "window_minutes": String(timeWindowMinutes)
            ]
        )
    }
}
