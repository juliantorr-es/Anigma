import Foundation

/// Types of security events tracked by the system.
/// Defined in Tier 1 (SecurityEventsManager) as pure data structures.
public enum SecurityEventType: String, Sendable, Codable {
    case capabilityBlocked = "capability_blocked"
    case capabilityGranted = "capability_granted"
    case doctrineViolation = "doctrine_violation"
    case researchInadequate = "research_inadequate"
    case trustDegraded = "trust_degraded"
    case trustPromoted = "trust_promoted"
    case modeChanged = "mode_changed"
    case redTeamAttack = "red_team_attack"
    case unauthorizedAccess = "unauthorized_access"
    case networkExfiltration = "network_exfiltration"
    case promptInjection = "prompt_injection"
    case capabilityEscalation = "capability_escalation"
    case trustRecalculation = "trust_recalculation"
}

/// Security event severity levels.
public enum SecurityEventSeverity: String, Sendable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Security event details structure.
public struct SecurityEventDetails: Sendable, Codable {
    public let engineType: String?
    public let engineId: String?
    public let zone: String?
    public let capability: String?
    public let doctrineRule: String?
    public let researchBundleId: String?
    public let taskId: String?
    public let reason: String?
    public let attemptedAction: String?
    public let blockedAction: String?
    public let metadata: [String: String]?

    public init(
        engineType: String? = nil,
        engineId: String? = nil,
        zone: String? = nil,
        capability: String? = nil,
        doctrineRule: String? = nil,
        researchBundleId: String? = nil,
        taskId: String? = nil,
        reason: String? = nil,
        attemptedAction: String? = nil,
        blockedAction: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.engineType = engineType
        self.engineId = engineId
        self.zone = zone
        self.capability = capability
        self.doctrineRule = doctrineRule
        self.researchBundleId = researchBundleId
        self.taskId = taskId
        self.reason = reason
        self.attemptedAction = attemptedAction
        self.blockedAction = blockedAction
        self.metadata = metadata
    }
}

/// Security event for observability.
public struct SecurityEvent: Sendable, Codable {
    public let id: String
    public let type: String
    public let engineId: String?
    public let operation: String?
    public let severity: String
    public let details: SecurityEventDetails
    public let createdAt: String

    public init(
        id: String,
        type: String,
        engineId: String? = nil,
        operation: String? = nil,
        severity: String,
        details: SecurityEventDetails,
        createdAt: String
    ) {
        self.id = id
        self.type = type
        self.engineId = engineId
        self.operation = operation
        self.severity = severity
        self.details = details
        self.createdAt = createdAt
    }
}

/// Security event statistics for observability.
public struct SecurityEventStats: Sendable, Codable {
    public var totalEvents: Int = 0
    public var recentEvents24h: Int = 0
    public var eventsByType: [String: Int] = [:]
    public var eventsBySeverity: [String: Int] = [:]

    public init() {}

    public var blockingRate: Double {
        guard totalEvents > 0 else { return 0.0 }
        let blockingEvents = eventsByType["capability_blocked", default: 0] +
                           eventsByType["doctrine_violation", default: 0] +
                           eventsByType["research_inadequate", default: 0]
        return Double(blockingEvents) / Double(totalEvents)
    }

    public var criticalSeverityCount: Int {
        return eventsBySeverity["critical", default: 0]
    }

    public var highSeverityCount: Int {
        return eventsBySeverity["high", default: 0]
    }
}
