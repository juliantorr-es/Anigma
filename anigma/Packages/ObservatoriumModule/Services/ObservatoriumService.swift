//
//  ObservatoriumService.swift
//  ObservatoriumModule
//
//  Unified observability service providing a single entry point
//  for all telemetry, error tracking, feedback, and alerting.
//

import Foundation
import AnigmaCore
import ContractsCore

/// Unified observability service.
/// Provides a single entry point for all observability concerns.
public actor ObservatoriumService {
    // MARK: - Sub-services

    public let telemetry: TelemetryService
    public let errors: ErrorService
    public let feedback: FeedbackService
    public let alerts: AlertService

    // MARK: - Dependencies

    private let world: World
    private let governance: GovernanceController

    // MARK: - Initialization

    public init(world: World, governance: GovernanceController) {
        self.world = world
        self.governance = governance

        self.telemetry = TelemetryService(world: world, governance: governance)
        self.errors = ErrorService(world: world, governance: governance)
        self.feedback = FeedbackService(world: world, governance: governance)
        self.alerts = AlertService(world: world, governance: governance)
    }

    // MARK: - Quick Recording Methods

    /// Records a performance trace.
    public func trace(
        module: String,
        action: String,
        durationMs: Double,
        properties: [String: TelemetryValue] = [:]
    ) async {
        await telemetry.recordTrace(
            module: module,
            action: action,
            durationMs: durationMs,
            properties: properties
        )
    }

    /// Records a metric value.
    public func metric(
        name: String,
        value: Double,
        dimensions: [String: String] = [:]
    ) async {
        _ = await telemetry.recordMetric(
            name: name,
            value: value,
            dimensions: dimensions
        )
    }

    /// Records an error.
    public func error(
        type: String,
        message: String,
        module: String,
        severity: AlertSeverity = .error,
        context: [String: String] = [:]
    ) async {
        let errorSeverity = ErrorSeverity(rawValue: severity.rawValue)!
        _ = await errors.recordError(
            type: type,
            message: message,
            severity: errorSeverity,
            module: module,
            context: context
        )
    }

    /// Records a Swift error.
    public func error(_ swiftError: Error, module: String) async {
        _ = await errors.recordSwiftError(swiftError, module: module)
    }

    // MARK: - Timed Operations

    /// Measures and records the duration of an async operation.
    public func measure<T>(
        module: String,
        action: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        let result = try await operation()
        let durationMs = Date().timeIntervalSince(start) * 1000

        await trace(module: module, action: action, durationMs: durationMs)

        return result
    }

    /// Measures and records an operation, catching errors.
    public func measureWithErrorTracking<T>(
        module: String,
        action: String,
        operation: () async throws -> T
    ) async throws -> T {
        let start = Date()

        do {
            let result = try await operation()
            let durationMs = Date().timeIntervalSince(start) * 1000
            await trace(module: module, action: action, durationMs: durationMs, properties: ["success": .bool(true)])
            return result
        } catch {
            let durationMs = Date().timeIntervalSince(start) * 1000
            await trace(module: module, action: action, durationMs: durationMs, properties: ["success": .bool(false)])
            _ = await errors.recordSwiftError(error, module: module, component: action)
            throw error
        }
    }

    // MARK: - Domain Metrics Helpers

    /// Records alt-media turnaround time.
    public func recordAltMediaTurnaround(
        requestId: String,
        hours: Double,
        department: String? = nil
    ) async {
        var dimensions: [String: String] = ["request_id": requestId]
        if let dept = department {
            dimensions["department"] = dept
        }

        await telemetry.recordMetric(
            name: "diaplasion.altmedia.turnaround",
            value: hours,
            dimensions: dimensions
        )
    }

    /// Records case resolution time.
    public func recordCaseResolution(
        caseId: String,
        hours: Double,
        caseType: String? = nil
    ) async {
        var dimensions: [String: String] = ["case_id": caseId]
        if let type = caseType {
            dimensions["case_type"] = type
        }

        await telemetry.recordMetric(
            name: "conexus.case.resolution_time",
            value: hours,
            dimensions: dimensions
        )
    }

    /// Records current queue depth.
    public func recordQueueDepth(
        queue: String,
        depth: Int
    ) async {
        await telemetry.recordMetric(
            name: "system.queue.depth",
            value: Double(depth),
            dimensions: ["queue": queue]
        )
    }

    // MARK: - Health & Status

    /// Gets overall system health summary.
    public func getHealthSummary() async -> SystemHealthSummary {
        let telemetryStats = await telemetry.getStatistics()
        let errorStats = await errors.getStatistics()
        let alertDashboard = await alerts.getDashboardSummary()
        let feedbackStats = await feedback.getStatistics()

        // Determine overall status
        let status: HealthStatus = {
            if alertDashboard.criticalCount > 0 {
                return .critical
            } else if alertDashboard.errorCount > 5 || errorStats.recentErrorCount > 50 {
                return .degraded
            } else if alertDashboard.warningCount > 10 {
                return .warning
            } else {
                return .healthy
            }
        }()

        return SystemHealthSummary(
            status: status,
            timestamp: Date(),
            activeAlerts: alertDashboard.totalActive,
            criticalAlerts: alertDashboard.criticalCount,
            recentErrors: errorStats.recentErrorCount,
            errorClusters: errorStats.clusterCount,
            pendingFeedback: feedbackStats.byState[.submitted, default: 0] + feedbackStats.byState[.acknowledged, default: 0],
            telemetryEventsReceived: telemetryStats.eventsReceived,
            metricsReceived: telemetryStats.metricsReceived
        )
    }

    /// Gets a comprehensive operations dashboard.
    public func getOperationsDashboard() async -> OperationsDashboard {
        let health = await getHealthSummary()
        let alerts = await self.alerts.getDashboardSummary()
        let errors = await self.errors.getStatistics()
        let feedback = await self.feedback.getStatistics()
        let telemetry = await self.telemetry.getStatistics()

        return OperationsDashboard(
            generatedAt: Date(),
            health: health,
            alerts: alerts,
            errorStats: errors,
            feedbackStats: feedback,
            telemetryStats: telemetry
        )
    }

    // MARK: - Weekly Reports

    /// Generates a weekly operations report.
    public func generateWeeklyReport(from: Date, to: Date) async -> WeeklyOperationsReport {
        let feedbackSummary = await feedback.generateWeeklySummary(from: from, to: to)
        let currentHealth = await getHealthSummary()
        let alertStats = await alerts.getStatistics()
        let errorStats = await errors.getStatistics()

        return WeeklyOperationsReport(
            periodStart: from,
            periodEnd: to,
            generatedAt: Date(),
            healthStatus: currentHealth.status,
            totalAlertsTriggered: alertStats.totalTriggered,
            totalAlertsResolved: alertStats.totalResolved,
            totalErrors: errorStats.totalErrorsReceived,
            errorClusters: errorStats.clusterCount,
            errorsByModule: errorStats.byModule,
            feedbackReceived: feedbackSummary.totalReceived,
            feedbackResolved: feedbackSummary.totalResolved,
            feedbackByType: feedbackSummary.byType,
            highlights: generateHighlights(
                feedbackSummary: feedbackSummary,
                errorStats: errorStats,
                alertStats: alertStats
            )
        )
    }

    private func generateHighlights(
        feedbackSummary: FeedbackSummaryReport,
        errorStats: ErrorStatistics,
        alertStats: AlertStatistics
    ) -> [String] {
        var highlights: [String] = []

        highlights.append(contentsOf: feedbackSummary.highlights)

        if errorStats.clusterCount > 20 {
            highlights.append("\(errorStats.clusterCount) unique error patterns detected")
        }

        if alertStats.totalTriggered > 100 {
            highlights.append("High alert volume: \(alertStats.totalTriggered) alerts this period")
        }

        let resolutionRate = alertStats.totalTriggered > 0
            ? Double(alertStats.totalResolved) / Double(alertStats.totalTriggered) * 100
            : 100
        if resolutionRate < 80 {
            highlights.append("Alert resolution rate below target: \(String(format: "%.0f", resolutionRate))%")
        }

        return highlights
    }
}

// MARK: - Health & Dashboard Types

/// Overall system health status.
public enum HealthStatus: String, Codable, Sendable {
    case healthy = "healthy"
    case warning = "warning"
    case degraded = "degraded"
    case critical = "critical"
}

/// System health summary.
public struct SystemHealthSummary: Sendable {
    public let status: HealthStatus
    public let timestamp: Date
    public let activeAlerts: Int
    public let criticalAlerts: Int
    public let recentErrors: Int
    public let errorClusters: Int
    public let pendingFeedback: Int
    public let telemetryEventsReceived: Int
    public let metricsReceived: Int
}

/// Comprehensive operations dashboard.
public struct OperationsDashboard: Sendable {
    public let generatedAt: Date
    public let health: SystemHealthSummary
    public let alerts: AlertDashboardSummary
    public let errorStats: ErrorStatistics
    public let feedbackStats: FeedbackStatistics
    public let telemetryStats: TelemetryStatistics
}

/// Weekly operations report.
public struct WeeklyOperationsReport: Sendable {
    public let periodStart: Date
    public let periodEnd: Date
    public let generatedAt: Date
    public let healthStatus: HealthStatus
    public let totalAlertsTriggered: Int
    public let totalAlertsResolved: Int
    public let totalErrors: Int
    public let errorClusters: Int
    public let errorsByModule: [String: Int]
    public let feedbackReceived: Int
    public let feedbackResolved: Int
    public let feedbackByType: [FeedbackType: Int]
    public let highlights: [String]
}
