//
//  TelemetryService.swift
//  ObservatoriumModule
//
//  Central service for telemetry collection and management.
//  Handles event ingestion, buffering, and aggregation.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore
import ContractsCore

/// Central telemetry collection and management service.
/// Ingests events, buffers them, and provides aggregation.
public actor TelemetryService {
    // MARK: - Dependencies

    private let world: World
    private let governance: GovernanceController

    // MARK: - Configuration

    private let bufferSize: Int
    private let flushInterval: TimeInterval
    private let sensitivityFilter: TelemetrySensitivity

    // MARK: - State

    private var eventBuffer: [TelemetryEventComponent] = []
    private var metricBuffer: [MetricDataPoint] = []
    private var metricDefinitions: [String: MetricDefinitionComponent] = [:]
    private var metricEntityIndex: [String: EntityId] = [:]
    private var lastFlush = Date()

    // MARK: - Statistics

    private var eventsReceived: Int = 0
    private var eventsDropped: Int = 0
    private var metricsReceived: Int = 0

    // MARK: - Initialization

    public init(
        world: World,
        governance: GovernanceController,
        bufferSize: Int = 1000,
        flushInterval: TimeInterval = 60,
        sensitivityFilter: TelemetrySensitivity = .restricted
    ) {
        self.world = world
        self.governance = governance
        self.bufferSize = bufferSize
        self.flushInterval = flushInterval
        self.sensitivityFilter = sensitivityFilter

        // Register built-in metrics inline (actor isolation workaround)
        let builtIns: [MetricDefinitionComponent] = [
            .systemLatency,
            .errorRate,
            .queueDepth,
            .altMediaTurnaroundTime,
            .altMediaBacklog,
            .caseResolutionTime,
            .activeCases
        ]
        for metric in builtIns {
            metricDefinitions[metric.name] = metric
        }
    }

    // MARK: - Metric Registration

    /// Registers a metric definition.
    public func registerMetric(_ metric: MetricDefinitionComponent) async {
        metricDefinitions[metric.name] = metric

        // Create entity for persistent storage
        let entityId = await world.createEntity()
        await world.addComponent(entityId, metric)
        metricEntityIndex[metric.name] = entityId
    }

    /// Gets a registered metric by name.
    public func getMetric(name: String) -> MetricDefinitionComponent? {
        metricDefinitions[name]
    }

    /// Lists all registered metrics.
    public func listMetrics() -> [MetricDefinitionComponent] {
        Array(metricDefinitions.values)
    }

    private nonisolated func getBuiltInMetrics() -> [MetricDefinitionComponent] {
        [
            .systemLatency,
            .errorRate,
            .queueDepth,
            .altMediaTurnaroundTime,
            .altMediaBacklog,
            .caseResolutionTime,
            .activeCases
        ]
    }

    private func registerBuiltInMetrics() {
        for metric in getBuiltInMetrics() {
            metricDefinitions[metric.name] = metric
        }
    }

    // MARK: - Event Ingestion

    /// Records a telemetry event.
    public func record(_ event: TelemetryEventComponent) async {
        eventsReceived += 1

        // Filter by sensitivity
        guard event.sensitivityLevel <= sensitivityFilter else {
            eventsDropped += 1
            return
        }

        // Buffer overflow protection
        if eventBuffer.count >= bufferSize {
            eventsDropped += 1
            // Could also trigger flush here
            return
        }

        // Redact if needed for internal sensitivity
        let eventToStore = event.sensitivityLevel == .restricted ? event.redacted() : event
        eventBuffer.append(eventToStore)

        // Auto-flush if interval exceeded
        if Date().timeIntervalSince(lastFlush) > flushInterval {
            await flush()
        }
    }

    /// Records a performance trace.
    public func recordTrace(
        module: String,
        action: String,
        durationMs: Double,
        properties: [String: TelemetryValue] = [:],
        correlationId: String? = nil
    ) async {
        let event = TelemetryEventComponent.performanceTrace(
            module: module,
            action: action,
            durationMs: durationMs,
            properties: properties,
            correlationId: correlationId
        )
        await record(event)

        // Also record as latency metric
        await recordMetric(name: "system.request.latency", value: durationMs, dimensions: [
            "module": module,
            "action": action
        ])
    }

    /// Records a workflow completion.
    public func recordWorkflowComplete(
        module: String,
        workflowName: String,
        durationMs: Double,
        success: Bool
    ) async {
        let event = TelemetryEventComponent.workflowComplete(
            module: module,
            workflowName: workflowName,
            durationMs: durationMs,
            success: success
        )
        await record(event)
    }

    // MARK: - Metric Recording

    /// Records a metric data point.
    public func recordMetric(
        name: String,
        value: Double,
        dimensions: [String: String] = [:],
        correlationId: String? = nil
    ) async {
        guard let metric = metricDefinitions[name], metric.isEnabled else {
            return
        }

        metricsReceived += 1

        let dataPoint = MetricDataPoint(
            metricId: metric.id,
            value: value,
            dimensions: dimensions,
            correlationId: correlationId
        )

        metricBuffer.append(dataPoint)

        // Check thresholds
        if let severity = metric.checkThresholds(value) {
            await triggerThresholdAlert(metric: metric, value: value, severity: severity)
        }
    }

    /// Records multiple metric data points.
    public func recordMetrics(_ dataPoints: [MetricDataPoint]) async {
        for point in dataPoints {
            metricBuffer.append(point)
            metricsReceived += 1
        }
    }

    // MARK: - Threshold Alerts

    private func triggerThresholdAlert(
        metric: MetricDefinitionComponent,
        value: Double,
        severity: AlertSeverity
    ) async {
        let alert = AlertComponent.thresholdAlert(
            metric: metric,
            actualValue: value,
            severity: severity
        )

        let entityId = await world.createEntity()
        await world.addComponent(entityId, alert)

        // Audit
        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: "system",
            module: "TelemetryService",
            description: "Alert triggered: \(alert.title)",
            metadata: ["original_event_type": "telemetry_threshold_alert", "metric_name": metric.name, "severity": severity.rawValue]
        )
    }

    // MARK: - Flush & Aggregation

    /// Flushes buffered events to storage.
    public func flush() async {
        guard !eventBuffer.isEmpty || !metricBuffer.isEmpty else { return }

        // Store events
        for event in eventBuffer {
            let entityId = await world.createEntity()
            await world.addComponent(entityId, event)
        }

        // Clear buffers
        let eventCount = eventBuffer.count
        let metricCount = metricBuffer.count
        eventBuffer.removeAll()
        metricBuffer.removeAll()
        lastFlush = Date()

        // Audit the flush
        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: "system",
            module: "TelemetryService",
            description: "Telemetry flush: \(eventCount) events, \(metricCount) metrics",
            metadata: ["original_event_type": "telemetry_flush", "event_count": "\(eventCount)", "metric_count": "\(metricCount)"]
        )
    }

    /// Aggregates metrics for a time window.
    public func aggregateMetrics(
        name: String,
        from: Date,
        to: Date,
        dimensions: [String: String]? = nil
    ) async -> AggregatedMetric? {
        guard let metric = metricDefinitions[name] else { return nil }

        // Filter data points from buffer
        let relevantPoints = metricBuffer.filter { point in
            point.metricId == metric.id &&
            point.timestamp >= from &&
            point.timestamp <= to &&
            (dimensions == nil || dimensions!.allSatisfy { point.dimensions[$0.key] == $0.value })
        }

        guard !relevantPoints.isEmpty else { return nil }

        let values = relevantPoints.map { $0.value }.sorted()
        let count = values.count
        let sum = values.reduce(0, +)
        let min = values.first ?? 0
        let max = values.last ?? 0
        let average = sum / Double(count)

        return AggregatedMetric(
            metricId: metric.id,
            metricName: metric.name,
            windowStart: from,
            windowEnd: to,
            dimensions: dimensions ?? [:],
            count: count,
            sum: sum,
            min: min,
            max: max,
            average: average,
            p50: percentile(values, 0.50),
            p90: percentile(values, 0.90),
            p95: percentile(values, 0.95),
            p99: percentile(values, 0.99)
        )
    }

    private func percentile(_ sortedValues: [Double], _ p: Double) -> Double? {
        guard !sortedValues.isEmpty else { return nil }
        let index = Int(Double(sortedValues.count - 1) * p)
        return sortedValues[index]
    }

    // MARK: - Statistics

    /// Returns service statistics.
    public func getStatistics() -> TelemetryStatistics {
        TelemetryStatistics(
            eventsReceived: eventsReceived,
            eventsDropped: eventsDropped,
            eventBufferSize: eventBuffer.count,
            metricsReceived: metricsReceived,
            metricBufferSize: metricBuffer.count,
            registeredMetrics: metricDefinitions.count,
            lastFlush: lastFlush
        )
    }
}

/// Telemetry service statistics.
public struct TelemetryStatistics: Sendable {
    public let eventsReceived: Int
    public let eventsDropped: Int
    public let eventBufferSize: Int
    public let metricsReceived: Int
    public let metricBufferSize: Int
    public let registeredMetrics: Int
    public let lastFlush: Date
}
