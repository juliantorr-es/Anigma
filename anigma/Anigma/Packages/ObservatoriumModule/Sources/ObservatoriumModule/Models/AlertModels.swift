import Foundation

// MARK: - Alert Types
public enum AlertType: String, Codable, CaseIterable, Sendable {
    case threshold = "threshold"
    case anomaly = "anomaly"
    case system = "system"
    case security = "security"
    case performance = "performance"
    case availability = "availability"
}

// MARK: - Alert Severity
public enum AlertSeverity: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Alert Status
public enum AlertStatus: String, Codable, CaseIterable, Sendable {
    case active = "active"
    case acknowledged = "acknowledged"
    case resolved = "resolved"
    case suppressed = "suppressed"
}

// MARK: - Alert Rule
public struct AlertRule: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let type: AlertType
    public let conditions: [AlertCondition]
    public let severity: AlertSeverity
    public let enabled: Bool
    public let cooldownInterval: TimeInterval
    public let notificationChannels: [String]
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        name: String,
        description: String,
        type: AlertType,
        conditions: [AlertCondition],
        severity: AlertSeverity,
        enabled: Bool = true,
        cooldownInterval: TimeInterval = 300, // 5 minutes default
        notificationChannels: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.type = type
        self.conditions = conditions
        self.severity = severity
        self.enabled = enabled
        self.cooldownInterval = cooldownInterval
        self.notificationChannels = notificationChannels
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Alert Condition
public struct AlertCondition: Codable, Sendable {
    public let metric: String
    public let op: AlertOperator
    public let threshold: Double
    public let duration: TimeInterval?
    
    public init(metric: String, op: AlertOperator, threshold: Double, duration: TimeInterval? = nil) {
        self.metric = metric
        self.op = op
        self.threshold = threshold
        self.duration = duration
    }
}

// MARK: - Alert Operator
public enum AlertOperator: String, Codable, CaseIterable, Sendable {
    case greaterThan = "gt"
    case lessThan = "lt"
    case greaterThanOrEqual = "gte"
    case lessThanOrEqual = "lte"
    case equal = "eq"
    case notEqual = "ne"
}

// MARK: - Alert
public struct Alert: Codable, Identifiable, Sendable {
    public let id: UUID
    public let ruleId: UUID
    public let ruleName: String
    public let type: AlertType
    public let severity: AlertSeverity
    public var status: AlertStatus
    public let title: String
    public let message: String
    public let triggeredAt: Date
    public var acknowledgedAt: Date?
    public var resolvedAt: Date?
    public let metadata: [String: String]
    
    public init(
        ruleId: UUID,
        ruleName: String,
        type: AlertType,
        severity: AlertSeverity,
        title: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.ruleId = ruleId
        self.ruleName = ruleName
        self.type = type
        self.severity = severity
        self.status = .active
        self.title = title
        self.message = message
        self.triggeredAt = Date()
        self.acknowledgedAt = nil
        self.resolvedAt = nil
        self.metadata = metadata
    }
    
    public mutating func acknowledge() {
        self.status = .acknowledged
        self.acknowledgedAt = Date()
    }
    
    public mutating func resolve() {
        self.status = .resolved
        self.resolvedAt = Date()
    }
}

// MARK: - Notification Channel
public struct NotificationChannel: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let type: NotificationType
    public let config: [String: String]
    public let enabled: Bool
    
    public init(name: String, type: NotificationType, config: [String: String], enabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.config = config
        self.enabled = enabled
    }
}

// MARK: - Notification Type
public enum NotificationType: String, Codable, CaseIterable, Sendable {
    case email = "email"
    case slack = "slack"
    case webhook = "webhook"
    case push = "push"
    case sms = "sms"
}
