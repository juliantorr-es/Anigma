//
//  AlertComponent.swift
//  ObservatoriumModule
//
//  Alert component for system alerts and notifications.
//  Alerts are triggered by thresholds, errors, or conditions.
//

import Foundation
import AnigmaCore

/// Component representing a system alert.
/// Alerts notify operators and can trigger automated responses.
public struct AlertComponent: Component, Codable, Identifiable {
    // MARK: - Identity

    /// Unique alert ID.
    public let id: AlertId

    /// Alert type for categorization.
    public var alertType: AlertType

    /// Human-readable title.
    public var title: String

    /// Detailed message.
    public var message: String

    // MARK: - Classification

    /// Severity level.
    public var severity: AlertSeverity

    /// Category for grouping.
    public var category: MetricCategory

    /// Module that triggered the alert.
    public var module: String

    /// Tags for filtering.
    public var tags: [String]

    // MARK: - Source

    /// What triggered this alert.
    public var source: AlertSource

    /// Related metric ID (if metric-triggered).
    public var metricId: MetricId?

    /// Related error fingerprint (if error-triggered).
    public var errorFingerprint: String?

    /// Threshold value that was exceeded.
    public var thresholdValue: Double?

    /// Actual value that triggered the alert.
    public var actualValue: Double?

    // MARK: - State

    /// Current alert state.
    public var state: AlertState

    /// Who acknowledged this alert (if acknowledged).
    public var acknowledgedBy: String?

    /// When it was acknowledged.
    public var acknowledgedAt: Date?

    /// Resolution notes.
    public var resolutionNotes: String?

    /// When it was resolved.
    public var resolvedAt: Date?

    /// How many times this alert has fired (for recurring alerts).
    public var fireCount: Int

    // MARK: - Notification

    /// Channels this alert should notify.
    public var notificationChannels: [NotificationChannel]

    /// Whether notifications have been sent.
    public var notificationsSent: Bool

    /// Who should be notified.
    public var assignees: [String]

    // MARK: - Correlation

    /// Related alerts (for grouping cascading issues).
    public var relatedAlertIds: [AlertId]

    /// Correlation ID for tracing.
    public var correlationId: String?

    // MARK: - Timestamps

    public let triggeredAt: Date
    public var lastFiredAt: Date
    public var updatedAt: Date

    // MARK: - Initialization

    public init(
        id: AlertId = AlertId(),
        alertType: AlertType,
        title: String,
        message: String,
        severity: AlertSeverity,
        category: MetricCategory,
        module: String,
        tags: [String] = [],
        source: AlertSource,
        metricId: MetricId? = nil,
        errorFingerprint: String? = nil,
        thresholdValue: Double? = nil,
        actualValue: Double? = nil,
        state: AlertState = .triggered,
        acknowledgedBy: String? = nil,
        acknowledgedAt: Date? = nil,
        resolutionNotes: String? = nil,
        resolvedAt: Date? = nil,
        fireCount: Int = 1,
        notificationChannels: [NotificationChannel] = [.inApp],
        notificationsSent: Bool = false,
        assignees: [String] = [],
        relatedAlertIds: [AlertId] = [],
        correlationId: String? = nil,
        triggeredAt: Date = Date(),
        lastFiredAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.alertType = alertType
        self.title = title
        self.message = message
        self.severity = severity
        self.category = category
        self.module = module
        self.tags = tags
        self.source = source
        self.metricId = metricId
        self.errorFingerprint = errorFingerprint
        self.thresholdValue = thresholdValue
        self.actualValue = actualValue
        self.state = state
        self.acknowledgedBy = acknowledgedBy
        self.acknowledgedAt = acknowledgedAt
        self.resolutionNotes = resolutionNotes
        self.resolvedAt = resolvedAt
        self.fireCount = fireCount
        self.notificationChannels = notificationChannels
        self.notificationsSent = notificationsSent
        self.assignees = assignees
        self.relatedAlertIds = relatedAlertIds
        self.correlationId = correlationId
        self.triggeredAt = triggeredAt
        self.lastFiredAt = lastFiredAt
        self.updatedAt = updatedAt
    }

    /// Re-fires an existing alert.
    public mutating func refire() {
        fireCount += 1
        lastFiredAt = Date()
        updatedAt = Date()

        // Reset state if it was resolved
        if state == .resolved || state == .closed {
            state = .triggered
            acknowledgedBy = nil
            acknowledgedAt = nil
            resolutionNotes = nil
            resolvedAt = nil
        }
    }

    /// Acknowledges the alert.
    public mutating func acknowledge(by principal: String) {
        state = .acknowledged
        acknowledgedBy = principal
        acknowledgedAt = Date()
        updatedAt = Date()
    }

    /// Resolves the alert.
    public mutating func resolve(notes: String, by principal: String) {
        state = .resolved
        resolutionNotes = notes
        resolvedAt = Date()
        updatedAt = Date()
        if acknowledgedBy == nil {
            acknowledgedBy = principal
            acknowledgedAt = Date()
        }
    }
}

/// Types of alerts.
public enum AlertType: String, Codable, Sendable {
    case threshold = "threshold"     // Metric crossed threshold
    case error = "error"             // Error rate exceeded
    case sla = "sla"                 // SLA violation
    case security = "security"       // Security concern
    case capacity = "capacity"       // Resource constraint
    case anomaly = "anomaly"         // Unusual pattern detected
    case scheduled = "scheduled"     // Scheduled check (e.g., backup verification)
    case manual = "manual"           // Manually created
}

/// What triggered the alert.
public enum AlertSource: String, Codable, Sendable {
    case metric = "metric"           // Metric threshold
    case errorAggregation = "error"  // Error count/rate
    case healthCheck = "health"      // Health check failure
    case rule = "rule"               // Custom rule
    case schedule = "schedule"       // Scheduled check
    case manual = "manual"           // Human-created
    case aiDetection = "ai"          // AI/ML anomaly detection
}

/// Alert lifecycle states.
public enum AlertState: String, Codable, Sendable {
    case triggered      // Just fired
    case acknowledged   // Someone saw it
    case investigating  // Being looked at
    case resolved       // Fixed
    case closed         // Administratively closed
    case snoozed        // Temporarily silenced
}

/// Notification channels for alerts.
public enum NotificationChannel: String, Codable, Sendable {
    case inApp = "in_app"   // In-application notification
    case email = "email"    // Email notification
    case slack = "slack"    // Slack/Teams integration (future)
    case webhook = "webhook" // Custom webhook
    case sms = "sms"        // SMS (critical only, future)
}

// MARK: - Alert Summary

/// Lightweight summary for dashboards.
public struct AlertSummary: Sendable, Identifiable {
    public let id: AlertId
    public let alertType: AlertType
    public let title: String
    public let severity: AlertSeverity
    public let state: AlertState
    public let module: String
    public let triggeredAt: Date
    public let fireCount: Int

    public init(from alert: AlertComponent) {
        self.id = alert.id
        self.alertType = alert.alertType
        self.title = alert.title
        self.severity = alert.severity
        self.state = alert.state
        self.module = alert.module
        self.triggeredAt = alert.triggeredAt
        self.fireCount = alert.fireCount
    }
}

// MARK: - Alert Builders

extension AlertComponent {
    /// Creates a threshold alert from a metric.
    public static func thresholdAlert(
        metric: MetricDefinitionComponent,
        actualValue: Double,
        severity: AlertSeverity
    ) -> AlertComponent {
        let threshold: Double? = {
            switch severity {
            case .critical: return metric.criticalThreshold
            case .error: return metric.errorThreshold
            case .warning: return metric.warningThreshold
            case .info: return nil
            }
        }()

        return AlertComponent(
            alertType: .threshold,
            title: "\(metric.displayName) threshold exceeded",
            message: """
                \(metric.displayName) has reached \(String(format: "%.2f", actualValue)) \(metric.unit.rawValue), \
                exceeding the \(severity.rawValue) threshold of \(threshold.map { String(format: "%.2f", $0) } ?? "N/A").
                """,
            severity: severity,
            category: metric.category,
            module: metric.module ?? "System",
            tags: metric.tags,
            source: .metric,
            metricId: metric.id,
            thresholdValue: threshold,
            actualValue: actualValue
        )
    }

    /// Creates an SLA violation alert.
    public static func slaViolation(
        title: String,
        message: String,
        module: String,
        metricId: MetricId? = nil,
        actualValue: Double? = nil,
        slaTarget: Double? = nil
    ) -> AlertComponent {
        AlertComponent(
            alertType: .sla,
            title: title,
            message: message,
            severity: .error,
            category: .domain,
            module: module,
            tags: ["sla", "compliance"],
            source: .metric,
            metricId: metricId,
            thresholdValue: slaTarget,
            actualValue: actualValue
        )
    }

    /// Creates an error rate alert.
    public static func errorRateAlert(
        module: String,
        errorFingerprint: String,
        count: Int,
        period: String
    ) -> AlertComponent {
        AlertComponent(
            alertType: .error,
            title: "High error rate in \(module)",
            message: "Error '\(errorFingerprint.prefix(8))' occurred \(count) times in the last \(period).",
            severity: count > 100 ? .critical : (count > 50 ? .error : .warning),
            category: .error,
            module: module,
            tags: ["error", "rate"],
            source: .errorAggregation,
            errorFingerprint: errorFingerprint,
            actualValue: Double(count)
        )
    }
}
