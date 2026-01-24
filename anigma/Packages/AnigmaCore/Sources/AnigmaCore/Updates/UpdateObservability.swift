//
//  UpdateObservability.swift
//  AnigmaCore
//
//  AnigmaCore - Update Observability Integration
//
//  Wires update events into Observatorium for telemetry, metrics, and alerts.
//  Makes updates visible in operational dashboards and reports.
//

import Foundation

// MARK: - Update Telemetry

/// Telemetry events for update lifecycle.
public struct UpdateTelemetryEvents {

    /// Event names for update telemetry.
    public enum EventName: String {
        case releaseAnnounced = "update.release.announced"
        case drainModeStarted = "update.drain.started"
        case drainModeEnded = "update.drain.ended"
        case clientBlocked = "update.client.blocked"
        case clientUpdated = "update.client.updated"
        case maintenanceStarted = "update.maintenance.started"
        case maintenanceEnded = "update.maintenance.ended"
        case migrationStarted = "update.migration.started"
        case migrationCompleted = "update.migration.completed"
        case migrationFailed = "update.migration.failed"
        case rollbackStarted = "update.rollback.started"
        case rollbackCompleted = "update.rollback.completed"
        case rollbackFailed = "update.rollback.failed"
        case verificationPassed = "update.verification.passed"
        case verificationFailed = "update.verification.failed"
        case cohortRolloutChanged = "update.cohort.rollout_changed"
        case versionPolicyChanged = "update.policy.changed"
    }
}

// MARK: - Update Metrics

/// Metric definitions for update monitoring.
public struct UpdateMetrics {

    /// Metric names for updates.
    public enum MetricName: String {
        // Client metrics
        case clientsOnCurrentVersion = "update.clients.current_version"
        case clientsOutdated = "update.clients.outdated"
        case clientsBlocked = "update.clients.blocked"
        case clientsDraining = "update.clients.draining"
        case clientUpdateLatency = "update.client.update_latency_hours"

        // Migration metrics
        case migrationDuration = "update.migration.duration_seconds"
        case migrationAffectedEntities = "update.migration.affected_entities"
        case migrationSuccessRate = "update.migration.success_rate"

        // Rollout metrics
        case rolloutProgress = "update.rollout.progress_percent"
        case rolloutDuration = "update.rollout.duration_hours"
        case cohortsCompleted = "update.rollout.cohorts_completed"

        // Phase metrics
        case timeInDrainMode = "update.phase.drain_duration_hours"
        case timeInMaintenance = "update.phase.maintenance_duration_minutes"

        // Error metrics
        case updateFailures = "update.errors.failures"
        case rollbackCount = "update.errors.rollbacks"
        case blockedOperations = "update.errors.blocked_operations"
    }
}

// MARK: - Update Telemetry Recorder

/// Records update telemetry events and metrics.
/// Bridge between UpdateService and ObservatoriumService.
public actor UpdateTelemetryRecorder {

    // State tracking for duration calculations
    private var phaseStartTimes: [UpdatePhase: Date] = [:]
    private var rolloutStartTimes: [SemanticVersion: Date] = [:]
    private var clientUpdateRequested: [UUID: Date] = [:]

    public init() {}

    // MARK: - Event Recording

    /// Record an update event with telemetry properties.
    public func recordEvent(
        _ event: UpdateEvent
    ) -> UpdateTelemetryPayload {
        var properties: [String: String] = [
            "event_type": event.eventType.rawValue,
            "phase": event.phase.rawValue,
            "affected_clients": String(event.affectedClients)
        ]

        if let fromVersion = event.fromVersion {
            properties["from_version"] = fromVersion.description
        }
        if let toVersion = event.toVersion {
            properties["to_version"] = toVersion.description
        }

        // Track phase transitions
        switch event.eventType {
        case .drainModeStarted:
            phaseStartTimes[.draining] = event.timestamp
        case .drainModeEnded:
            if let start = phaseStartTimes[.draining] {
                let duration = event.timestamp.timeIntervalSince(start) / 3600
                properties["drain_duration_hours"] = String(format: "%.2f", duration)
            }
        case .maintenanceStarted:
            phaseStartTimes[.maintenance] = event.timestamp
        case .maintenanceEnded:
            if let start = phaseStartTimes[.maintenance] {
                let duration = event.timestamp.timeIntervalSince(start) / 60
                properties["maintenance_duration_minutes"] = String(format: "%.2f", duration)
            }
        case .releaseAnnounced:
            if let version = event.toVersion {
                rolloutStartTimes[version] = event.timestamp
            }
        case .deploymentCompleted:
            if let version = event.toVersion, let start = rolloutStartTimes[version] {
                let duration = event.timestamp.timeIntervalSince(start) / 3600
                properties["rollout_duration_hours"] = String(format: "%.2f", duration)
            }
        default:
            break
        }

        return UpdateTelemetryPayload(
            eventName: mapEventType(event.eventType),
            timestamp: event.timestamp,
            properties: properties,
            details: event.details
        )
    }

    /// Record client update completion for latency tracking.
    public func recordClientUpdate(
        clientId: UUID,
        oldVersion: SemanticVersion,
        newVersion: SemanticVersion,
        timestamp: Date = Date()
    ) -> Double? {
        guard let requestTime = clientUpdateRequested[clientId] else {
            return nil
        }

        let latencyHours = timestamp.timeIntervalSince(requestTime) / 3600
        clientUpdateRequested.removeValue(forKey: clientId)
        return latencyHours
    }

    /// Mark that a client was notified about an update.
    public func markUpdateRequested(clientId: UUID, at time: Date = Date()) {
        clientUpdateRequested[clientId] = time
    }

    /// Record migration execution.
    public func recordMigration(
        _ record: MigrationRecord
    ) -> MigrationTelemetryPayload {
        return MigrationTelemetryPayload(
            migrationId: record.id,
            version: record.version,
            status: record.status,
            duration: record.duration ?? 0,
            affectedEntities: record.affectedEntities,
            error: record.error
        )
    }

    // MARK: - Metrics Snapshots

    /// Generate current update metrics snapshot.
    public func generateMetricsSnapshot(
        from statistics: UpdateStatistics
    ) -> UpdateMetricsSnapshot {
        return UpdateMetricsSnapshot(
            timestamp: Date(),
            phase: statistics.phase,
            currentVersion: statistics.currentVersion,
            pendingVersion: statistics.pendingVersion,
            totalClients: statistics.totalClients,
            currentClients: statistics.currentClients,
            outdatedClients: statistics.outdatedClients,
            drainingClients: statistics.drainingClients,
            blockedClients: statistics.blockedClients,
            updateProgress: statistics.updateProgress
        )
    }

    // MARK: - Private Helpers

    private func mapEventType(_ type: UpdateEventType) -> String {
        switch type {
        case .releaseAnnounced: return UpdateTelemetryEvents.EventName.releaseAnnounced.rawValue
        case .drainModeStarted: return UpdateTelemetryEvents.EventName.drainModeStarted.rawValue
        case .drainModeEnded: return UpdateTelemetryEvents.EventName.drainModeEnded.rawValue
        case .clientBlocked: return UpdateTelemetryEvents.EventName.clientBlocked.rawValue
        case .clientUpdated: return UpdateTelemetryEvents.EventName.clientUpdated.rawValue
        case .maintenanceStarted: return UpdateTelemetryEvents.EventName.maintenanceStarted.rawValue
        case .maintenanceEnded: return UpdateTelemetryEvents.EventName.maintenanceEnded.rawValue
        case .migrationStarted: return UpdateTelemetryEvents.EventName.migrationStarted.rawValue
        case .migrationCompleted: return UpdateTelemetryEvents.EventName.migrationCompleted.rawValue
        case .migrationFailed: return UpdateTelemetryEvents.EventName.migrationFailed.rawValue
        case .rollbackInitiated: return UpdateTelemetryEvents.EventName.rollbackStarted.rawValue
        case .rollbackCompleted: return UpdateTelemetryEvents.EventName.rollbackCompleted.rawValue
        case .deploymentCompleted: return UpdateTelemetryEvents.EventName.migrationCompleted.rawValue
        case .verificationPassed: return UpdateTelemetryEvents.EventName.verificationPassed.rawValue
        case .verificationFailed: return UpdateTelemetryEvents.EventName.verificationFailed.rawValue
        }
    }
}

// MARK: - Telemetry Payloads

/// Payload for update telemetry events.
public struct UpdateTelemetryPayload: Sendable {
    public let eventName: String
    public let timestamp: Date
    public let properties: [String: String]
    public let details: String
}

/// Payload for migration telemetry.
public struct MigrationTelemetryPayload: Sendable {
    public let migrationId: String
    public let version: SemanticVersion
    public let status: MigrationStatus
    public let duration: TimeInterval
    public let affectedEntities: Int
    public let error: String?
}

/// Snapshot of current update metrics.
public struct UpdateMetricsSnapshot: Sendable {
    public let timestamp: Date
    public let phase: UpdatePhase
    public let currentVersion: SemanticVersion
    public let pendingVersion: SemanticVersion?
    public let totalClients: Int
    public let currentClients: Int
    public let outdatedClients: Int
    public let drainingClients: Int
    public let blockedClients: Int
    public let updateProgress: Double
}

// MARK: - Update Alerts

/// Alert definitions for update monitoring.
public struct UpdateAlerts {

    /// Alert types for updates.
    public enum AlertType: String {
        case updateStalled = "update.stalled"
        case migrationFailed = "update.migration_failed"
        case rollbackRequired = "update.rollback_required"
        case clientsBlocked = "update.clients_blocked"
        case drainPeriodExpiring = "update.drain_expiring"
        case versionDriftDetected = "update.version_drift"
        case highBlockedOperations = "update.high_blocked_ops"
    }

    /// Threshold configurations.
    public struct Thresholds {
        /// Percentage of clients that must be updated before stall alert
        public var stallThreshold: Double = 0.5

        /// Hours in drain mode before expiring alert
        public var drainExpiringHours: Double = 4.0

        /// Number of blocked operations before alert
        public var blockedOperationsThreshold: Int = 100

        /// Maximum acceptable version drift (major versions)
        public var maxVersionDrift: Int = 1

        public init() {}
    }
}

// MARK: - Update Dashboard Data

/// Data for update-specific dashboards.
public struct UpdateDashboardData: Sendable {
    public let generatedAt: Date
    public let currentPhase: UpdatePhase
    public let currentVersion: SemanticVersion
    public let pendingVersion: SemanticVersion?
    public let clientBreakdown: ClientVersionBreakdown
    public let rolloutProgress: RolloutProgress?
    public let recentEvents: [UpdateEventSummary]
    public let migrationHistory: [MigrationSummary]
    public let activeAlerts: [UpdateAlertSummary]

    public init(
        generatedAt: Date = Date(),
        currentPhase: UpdatePhase,
        currentVersion: SemanticVersion,
        pendingVersion: SemanticVersion? = nil,
        clientBreakdown: ClientVersionBreakdown,
        rolloutProgress: RolloutProgress? = nil,
        recentEvents: [UpdateEventSummary] = [],
        migrationHistory: [MigrationSummary] = [],
        activeAlerts: [UpdateAlertSummary] = []
    ) {
        self.generatedAt = generatedAt
        self.currentPhase = currentPhase
        self.currentVersion = currentVersion
        self.pendingVersion = pendingVersion
        self.clientBreakdown = clientBreakdown
        self.rolloutProgress = rolloutProgress
        self.recentEvents = recentEvents
        self.migrationHistory = migrationHistory
        self.activeAlerts = activeAlerts
    }
}

/// Client version breakdown.
public struct ClientVersionBreakdown: Sendable {
    public let total: Int
    public let current: Int
    public let outdated: Int
    public let draining: Int
    public let blocked: Int

    public var currentPercentage: Double {
        guard total > 0 else { return 100 }
        return Double(current) / Double(total) * 100
    }

    public init(total: Int, current: Int, outdated: Int, draining: Int, blocked: Int) {
        self.total = total
        self.current = current
        self.outdated = outdated
        self.draining = draining
        self.blocked = blocked
    }
}

/// Rollout progress information.
public struct RolloutProgress: Sendable {
    public let version: SemanticVersion
    public let startedAt: Date
    public let estimatedCompletion: Date?
    public let percentComplete: Double
    public let cohortProgress: [CohortProgress]

    public init(
        version: SemanticVersion,
        startedAt: Date,
        estimatedCompletion: Date? = nil,
        percentComplete: Double,
        cohortProgress: [CohortProgress] = []
    ) {
        self.version = version
        self.startedAt = startedAt
        self.estimatedCompletion = estimatedCompletion
        self.percentComplete = percentComplete
        self.cohortProgress = cohortProgress
    }
}

/// Progress for a single cohort.
public struct CohortProgress: Sendable {
    public let cohortName: String
    public let state: CohortRolloutState
    public let clientsTotal: Int
    public let clientsUpdated: Int

    public var percentComplete: Double {
        guard clientsTotal > 0 else { return 100 }
        return Double(clientsUpdated) / Double(clientsTotal) * 100
    }

    public init(cohortName: String, state: CohortRolloutState, clientsTotal: Int, clientsUpdated: Int) {
        self.cohortName = cohortName
        self.state = state
        self.clientsTotal = clientsTotal
        self.clientsUpdated = clientsUpdated
    }
}

/// Summary of an update event.
public struct UpdateEventSummary: Sendable {
    public let timestamp: Date
    public let eventType: String
    public let description: String
    public let affectedClients: Int

    public init(timestamp: Date, eventType: String, description: String, affectedClients: Int) {
        self.timestamp = timestamp
        self.eventType = eventType
        self.description = description
        self.affectedClients = affectedClients
    }
}

/// Summary of a migration.
public struct MigrationSummary: Sendable {
    public let id: String
    public let version: String
    public let description: String
    public let status: String
    public let duration: TimeInterval?
    public let affectedEntities: Int

    public init(id: String, version: String, description: String, status: String, duration: TimeInterval?, affectedEntities: Int) {
        self.id = id
        self.version = version
        self.description = description
        self.status = status
        self.duration = duration
        self.affectedEntities = affectedEntities
    }
}

/// Summary of an update alert.
public struct UpdateAlertSummary: Sendable {
    public let alertType: String
    public let severity: String
    public let message: String
    public let triggeredAt: Date

    public init(alertType: String, severity: String, message: String, triggeredAt: Date) {
        self.alertType = alertType
        self.severity = severity
        self.message = message
        self.triggeredAt = triggeredAt
    }
}

// MARK: - Update Report Generator

/// Generates update reports for various audiences.
public struct UpdateReportGenerator {

    /// Generate a summary report for administrators.
    public static func generateAdminSummary(
        from dashboard: UpdateDashboardData
    ) -> String {
        var report = """
        # Update Status Report
        Generated: \(ISO8601DateFormatter().string(from: dashboard.generatedAt))

        ## Current State
        - **Phase**: \(dashboard.currentPhase.rawValue)
        - **Current Version**: \(dashboard.currentVersion)
        """

        if let pending = dashboard.pendingVersion {
            report += "\n- **Pending Version**: \(pending)"
        }

        report += """

        ## Client Status
        - Total Clients: \(dashboard.clientBreakdown.total)
        - On Current Version: \(dashboard.clientBreakdown.current) (\(String(format: "%.1f", dashboard.clientBreakdown.currentPercentage))%)
        - Outdated: \(dashboard.clientBreakdown.outdated)
        - In Drain Mode: \(dashboard.clientBreakdown.draining)
        - Blocked: \(dashboard.clientBreakdown.blocked)
        """

        if let progress = dashboard.rolloutProgress {
            report += """

            ## Rollout Progress
            - Version: \(progress.version)
            - Started: \(ISO8601DateFormatter().string(from: progress.startedAt))
            - Progress: \(String(format: "%.1f", progress.percentComplete))%
            """

            if !progress.cohortProgress.isEmpty {
                report += "\n\n### Cohort Progress"
                for cohort in progress.cohortProgress {
                    report += "\n- **\(cohort.cohortName)**: \(cohort.state.rawValue) (\(String(format: "%.0f", cohort.percentComplete))%)"
                }
            }
        }

        if !dashboard.activeAlerts.isEmpty {
            report += "\n\n## Active Alerts"
            for alert in dashboard.activeAlerts {
                report += "\n- [\(alert.severity.uppercased())] \(alert.message)"
            }
        }

        if !dashboard.recentEvents.isEmpty {
            report += "\n\n## Recent Events"
            for event in dashboard.recentEvents.prefix(10) {
                let time = ISO8601DateFormatter().string(from: event.timestamp)
                report += "\n- \(time): \(event.description)"
            }
        }

        return report
    }
}
