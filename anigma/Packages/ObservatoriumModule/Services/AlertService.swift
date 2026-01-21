//
//  AlertService.swift
//  ObservatoriumModule
//
//  Central service for alert management and notification.
//  Handles alert lifecycle, deduplication, and escalation.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore
import ContractsCore

/// Central alert management service.
/// Handles alert creation, lifecycle, notification, and escalation.
public actor AlertService {
    // MARK: - Dependencies

    private let world: World
    private let governance: GovernanceController

    // MARK: - Configuration

    /// How long to dedupe similar alerts.
    private let dedupeWindow: TimeInterval

    /// Grace period before re-firing resolved alerts.
    private let resolvedGracePeriod: TimeInterval

    // MARK: - State

    private var alertIndex: [AlertId: EntityId] = [:]
    private var alertsBySource: [String: [AlertId]] = [:]  // fingerprint/metric → alert IDs
    private var activeAlerts: [AlertId: AlertComponent] = [:]

    // MARK: - Statistics

    private var totalAlertsTriggered: Int = 0
    private var totalAlertsAcknowledged: Int = 0
    private var totalAlertsResolved: Int = 0

    // MARK: - Initialization

    public init(
        world: World,
        governance: GovernanceController,
        dedupeWindow: TimeInterval = 300,  // 5 minutes
        resolvedGracePeriod: TimeInterval = 3600  // 1 hour
    ) {
        self.world = world
        self.governance = governance
        self.dedupeWindow = dedupeWindow
        self.resolvedGracePeriod = resolvedGracePeriod
    }

    // MARK: - Alert Creation

    /// Creates or re-fires an alert.
    public func triggerAlert(_ alert: AlertComponent) async -> AlertComponent {
        // Check for existing active alert to dedupe
        let sourceKey = alert.metricId?.raw.uuidString ?? alert.errorFingerprint ?? alert.id.raw.uuidString

        if let existingIds = alertsBySource[sourceKey],
           let existingId = existingIds.first(where: { activeAlerts[$0] != nil }),
           var existingAlert = activeAlerts[existingId] {
            // Re-fire existing alert
            existingAlert.refire()
            activeAlerts[existingId] = existingAlert

            // Update in World
            if let entityId = alertIndex[existingId] {
                await world.addComponent(entityId, existingAlert)
            }

            return existingAlert
        }

        // New alert
        let entityId = await world.createEntity()
        await world.addComponent(entityId, alert)

        alertIndex[alert.id] = entityId
        alertsBySource[sourceKey, default: []].append(alert.id)
        activeAlerts[alert.id] = alert

        totalAlertsTriggered += 1

        // Audit
        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: "system",
            module: "AlertService",
            description: "Alert triggered: [\(alert.severity.rawValue)] \(alert.title)",
            metadata: ["original_event_type": "alert_triggered", "severity": alert.severity.rawValue, "title": alert.title]
        )

        await sendNotifications(for: alert)

        return alert
    }

    /// Creates a threshold alert from a metric.
    public func triggerThresholdAlert(
        metric: MetricDefinitionComponent,
        actualValue: Double,
        severity: AlertSeverity
    ) async -> AlertComponent {
        let alert = AlertComponent.thresholdAlert(
            metric: metric,
            actualValue: actualValue,
            severity: severity
        )
        return await triggerAlert(alert)
    }

    /// Creates an SLA violation alert.
    public func triggerSLAAlert(
        title: String,
        message: String,
        module: String,
        metricId: MetricId? = nil,
        actualValue: Double? = nil,
        slaTarget: Double? = nil
    ) async -> AlertComponent {
        let alert = AlertComponent.slaViolation(
            title: title,
            message: message,
            module: module,
            metricId: metricId,
            actualValue: actualValue,
            slaTarget: slaTarget
        )
        return await triggerAlert(alert)
    }

    /// Creates an error rate alert.
    public func triggerErrorRateAlert(
        module: String,
        errorFingerprint: String,
        count: Int,
        period: String
    ) async -> AlertComponent {
        let alert = AlertComponent.errorRateAlert(
            module: module,
            errorFingerprint: errorFingerprint,
            count: count,
            period: period
        )
        return await triggerAlert(alert)
    }

    // MARK: - Alert Queries

    /// Gets an alert by ID.
    public func getAlert(id: AlertId) async -> AlertComponent? {
        guard let entityId = alertIndex[id] else { return nil }
        return await world.getComponent(entityId, AlertComponent.self)
    }

    /// Gets all active (non-resolved) alerts.
    public func getActiveAlerts() -> [AlertComponent] {
        Array(activeAlerts.values)
            .filter { $0.state != .resolved && $0.state != .closed }
            .sorted { ($0.severity, $0.triggeredAt) > ($1.severity, $1.triggeredAt) }
    }

    /// Gets alerts by severity.
    public func getAlerts(severity: AlertSeverity) -> [AlertComponent] {
        activeAlerts.values.filter { $0.severity == severity }
    }

    /// Gets alerts by module.
    public func getAlerts(module: String) -> [AlertComponent] {
        activeAlerts.values.filter { $0.module == module }
    }

    /// Gets critical alerts requiring immediate attention.
    public func getCriticalAlerts() -> [AlertComponent] {
        activeAlerts.values
            .filter { $0.severity == .critical && $0.state == .triggered }
            .sorted { $0.triggeredAt > $1.triggeredAt }
    }

    /// Gets alerts needing acknowledgment.
    public func getUnacknowledgedAlerts() -> [AlertComponent] {
        activeAlerts.values
            .filter { $0.state == .triggered }
            .sorted { ($0.severity, $0.triggeredAt) > ($1.severity, $1.triggeredAt) }
    }

    // MARK: - Alert Management

    /// Acknowledges an alert.
    public func acknowledgeAlert(
        id: AlertId,
        by principal: String
    ) async throws -> AlertComponent {
        guard let entityId = alertIndex[id],
              var alert = activeAlerts[id] else {
            throw ObservatoriumError.metricNotFound(id.raw.uuidString)
        }

        alert.acknowledge(by: principal)
        activeAlerts[id] = alert
        await world.addComponent(entityId, alert)

        totalAlertsAcknowledged += 1

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "AlertService",
            description: "Alert acknowledged: \(alert.title)",
            metadata: ["original_event_type": "alert_acknowledged", "alert_id": alert.id.raw.uuidString]
        )

        return alert
    }

    /// Resolves an alert.
    public func resolveAlert(
        id: AlertId,
        notes: String,
        by principal: String
    ) async throws -> AlertComponent {
        guard let entityId = alertIndex[id],
              var alert = activeAlerts[id] else {
            throw ObservatoriumError.metricNotFound(id.raw.uuidString)
        }

        alert.resolve(notes: notes, by: principal)
        activeAlerts.removeValue(forKey: id)
        await world.addComponent(entityId, alert)

        totalAlertsResolved += 1

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "AlertService",
            description: "Alert resolved: \(alert.title)",
            metadata: ["original_event_type": "alert_resolved", "alert_id": alert.id.raw.uuidString]
        )

        return alert
    }

    /// Snoozes an alert temporarily.
    public func snoozeAlert(
        id: AlertId,
        until: Date,
        by principal: String
    ) async throws -> AlertComponent {
        guard let entityId = alertIndex[id],
              var alert = activeAlerts[id] else {
            throw ObservatoriumError.metricNotFound(id.raw.uuidString)
        }

        alert.state = .snoozed
        alert.updatedAt = Date()
        activeAlerts[id] = alert
        await world.addComponent(entityId, alert)

        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: principal,
            module: "AlertService",
            description: "Alert snoozed until \(until): \(alert.title)",
            metadata: ["original_event_type": "alert_snoozed", "alert_id": alert.id.raw.uuidString, "snoozed_until": until.ISO8601Format()]
        )

        return alert
    }

    /// Assigns an alert to someone.
    public func assignAlert(
        id: AlertId,
        to assignees: [String],
        by principal: String
    ) async throws -> AlertComponent {
        guard let entityId = alertIndex[id],
              var alert = activeAlerts[id] else {
            throw ObservatoriumError.metricNotFound(id.raw.uuidString)
        }

        alert.assignees = assignees
        alert.updatedAt = Date()
        activeAlerts[id] = alert
        await world.addComponent(entityId, alert)

        return alert
    }

    // MARK: - Notifications

    private func sendNotifications(for alert: AlertComponent) async {
        if var mutableAlert = activeAlerts[alert.id], !mutableAlert.notificationsSent {
            mutableAlert.notificationsSent = true
            activeAlerts[alert.id] = mutableAlert

            if let entityId = alertIndex[alert.id] {
                await world.addComponent(entityId, mutableAlert)
            }

            try? await governance.auditLog.record(
                eventType: ContractsCore.AuditEventType.custom,
                principal: "system",
                module: "AlertService",
                description: "Alert notifications sent: [\(alert.severity.rawValue)] \(alert.title)",
                metadata: [
                    "original_event_type": "alert_notification_sent",
                    "alert_id": alert.id.raw.uuidString,
                    "severity": alert.severity.rawValue,
                    "title": alert.title
                ]
            )
        }
    }

    // MARK: - Dashboard Data

    /// Gets alert summary for dashboards.
    public func getDashboardSummary() -> AlertDashboardSummary {
        let active = Array(activeAlerts.values)

        let bySeverity = Dictionary(grouping: active) { $0.severity }
            .mapValues { $0.count }

        let byState = Dictionary(grouping: active) { $0.state }
            .mapValues { $0.count }

        let byModule = Dictionary(grouping: active) { $0.module }
            .mapValues { $0.count }

        return AlertDashboardSummary(
            totalActive: active.count,
            criticalCount: bySeverity[.critical] ?? 0,
            errorCount: bySeverity[.error] ?? 0,
            warningCount: bySeverity[.warning] ?? 0,
            unacknowledgedCount: byState[.triggered] ?? 0,
            bySeverity: bySeverity,
            byState: byState,
            byModule: byModule,
            recentAlerts: Array(active.sorted { $0.triggeredAt > $1.triggeredAt }.prefix(10))
        )
    }

    // MARK: - Statistics

    /// Returns alert service statistics.
    public func getStatistics() -> AlertStatistics {
        AlertStatistics(
            totalTriggered: totalAlertsTriggered,
            totalAcknowledged: totalAlertsAcknowledged,
            totalResolved: totalAlertsResolved,
            currentlyActive: activeAlerts.count
        )
    }
}

/// Alert dashboard summary.
public struct AlertDashboardSummary: Sendable {
    public let totalActive: Int
    public let criticalCount: Int
    public let errorCount: Int
    public let warningCount: Int
    public let unacknowledgedCount: Int
    public let bySeverity: [AlertSeverity: Int]
    public let byState: [AlertState: Int]
    public let byModule: [String: Int]
    public let recentAlerts: [AlertComponent]
}

/// Alert service statistics.
public struct AlertStatistics: Sendable {
    public let totalTriggered: Int
    public let totalAcknowledged: Int
    public let totalResolved: Int
    public let currentlyActive: Int
}
