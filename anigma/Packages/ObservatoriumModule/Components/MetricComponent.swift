//
//  MetricComponent.swift
//  ObservatoriumModule
//
//  Core metric component for tracking measurable values.
//  Metrics are the foundation of observability - they tell us
//  what's happening in the system and across institutional workflows.
//

import Foundation
import AnigmaCore

/// Component representing a metric definition.
/// Attached to entities for tracking specific measurable values.
public struct MetricDefinitionComponent: Component, Codable, Identifiable {
    // MARK: - Identity

    /// Unique metric ID.
    public let id: MetricId

    /// Human-readable name (e.g., "alt_media_turnaround_time").
    public var name: String

    /// Display name for UIs (e.g., "Alt-Media Turnaround Time").
    public var displayName: String

    /// Description of what this metric measures.
    public var description: String

    // MARK: - Classification

    /// Category for organization.
    public var category: MetricCategory

    /// Module this metric belongs to (e.g., "Diaplasion", "Conexus").
    public var module: String?

    /// Unit of measurement.
    public var unit: MetricUnit

    /// Tags for filtering.
    public var tags: [String]

    // MARK: - Aggregation

    /// How to aggregate multiple values.
    public var aggregationType: AggregationType

    /// Retention period for raw values.
    public var retentionDays: Int

    /// Whether this metric is enabled.
    public var isEnabled: Bool

    // MARK: - Thresholds

    /// Warning threshold (triggers warning alert if exceeded).
    public var warningThreshold: Double?

    /// Error threshold (triggers error alert if exceeded).
    public var errorThreshold: Double?

    /// Critical threshold (triggers critical alert if exceeded).
    public var criticalThreshold: Double?

    /// Whether lower is better (for threshold comparison).
    public var lowerIsBetter: Bool

    // MARK: - Timestamps

    public let createdAt: Date
    public var updatedAt: Date

    // MARK: - Initialization

    public init(
        id: MetricId = MetricId(),
        name: String,
        displayName: String,
        description: String,
        category: MetricCategory,
        module: String? = nil,
        unit: MetricUnit = .count,
        tags: [String] = [],
        aggregationType: AggregationType = .average,
        retentionDays: Int = 90,
        isEnabled: Bool = true,
        warningThreshold: Double? = nil,
        errorThreshold: Double? = nil,
        criticalThreshold: Double? = nil,
        lowerIsBetter: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.category = category
        self.module = module
        self.unit = unit
        self.tags = tags
        self.aggregationType = aggregationType
        self.retentionDays = retentionDays
        self.isEnabled = isEnabled
        self.warningThreshold = warningThreshold
        self.errorThreshold = errorThreshold
        self.criticalThreshold = criticalThreshold
        self.lowerIsBetter = lowerIsBetter
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Checks if a value exceeds any threshold.
    public func checkThresholds(_ value: Double) -> AlertSeverity? {
        if lowerIsBetter {
            if let critical = criticalThreshold, value >= critical {
                return .critical
            }
            if let error = errorThreshold, value >= error {
                return .error
            }
            if let warning = warningThreshold, value >= warning {
                return .warning
            }
        } else {
            if let critical = criticalThreshold, value <= critical {
                return .critical
            }
            if let error = errorThreshold, value <= error {
                return .error
            }
            if let warning = warningThreshold, value <= warning {
                return .warning
            }
        }
        return nil
    }
}

/// How to aggregate metric values over time.
public enum AggregationType: String, Codable, Sendable {
    case sum        // Total count or accumulation
    case average    // Mean value
    case min        // Minimum value
    case max        // Maximum value
    case count      // Number of observations
    case p50        // 50th percentile (median)
    case p90        // 90th percentile
    case p95        // 95th percentile
    case p99        // 99th percentile
    case rate       // Rate per time unit
    case last       // Most recent value
}

// MARK: - Metric Data Point

/// A single metric data point.
public struct MetricDataPoint: Codable, Sendable {
    /// The metric this belongs to.
    public let metricId: MetricId

    /// The recorded value.
    public let value: Double

    /// When this was recorded.
    public let timestamp: Date

    /// Optional dimensions for slicing (e.g., department, module, user).
    public let dimensions: [String: String]

    /// Optional correlation ID for tracing.
    public let correlationId: String?

    public init(
        metricId: MetricId,
        value: Double,
        timestamp: Date = Date(),
        dimensions: [String: String] = [:],
        correlationId: String? = nil
    ) {
        self.metricId = metricId
        self.value = value
        self.timestamp = timestamp
        self.dimensions = dimensions
        self.correlationId = correlationId
    }
}

// MARK: - Aggregated Metric

/// Aggregated metric values over a time window.
public struct AggregatedMetric: Codable, Sendable {
    public let metricId: MetricId
    public let metricName: String
    public let windowStart: Date
    public let windowEnd: Date
    public let dimensions: [String: String]

    // Aggregated values
    public let count: Int
    public let sum: Double
    public let min: Double
    public let max: Double
    public let average: Double
    public let p50: Double?
    public let p90: Double?
    public let p95: Double?
    public let p99: Double?

    public init(
        metricId: MetricId,
        metricName: String,
        windowStart: Date,
        windowEnd: Date,
        dimensions: [String: String] = [:],
        count: Int,
        sum: Double,
        min: Double,
        max: Double,
        average: Double,
        p50: Double? = nil,
        p90: Double? = nil,
        p95: Double? = nil,
        p99: Double? = nil
    ) {
        self.metricId = metricId
        self.metricName = metricName
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.dimensions = dimensions
        self.count = count
        self.sum = sum
        self.min = min
        self.max = max
        self.average = average
        self.p50 = p50
        self.p90 = p90
        self.p95 = p95
        self.p99 = p99
    }
}

// MARK: - Built-in Metrics

extension MetricDefinitionComponent {
    /// Built-in system metrics.
    public static let systemLatency = MetricDefinitionComponent(
        name: "system.request.latency",
        displayName: "Request Latency",
        description: "Time to process a request",
        category: .performance,
        unit: .milliseconds,
        tags: ["system", "performance"],
        aggregationType: .p95,
        warningThreshold: 500,
        errorThreshold: 1000,
        criticalThreshold: 5000
    )

    public static let errorRate = MetricDefinitionComponent(
        name: "system.error.rate",
        displayName: "Error Rate",
        description: "Percentage of requests resulting in errors",
        category: .error,
        unit: .percentage,
        tags: ["system", "reliability"],
        aggregationType: .average,
        warningThreshold: 1.0,
        errorThreshold: 5.0,
        criticalThreshold: 10.0
    )

    public static let queueDepth = MetricDefinitionComponent(
        name: "system.queue.depth",
        displayName: "Queue Depth",
        description: "Number of items waiting in processing queues",
        category: .performance,
        unit: .count,
        tags: ["system", "capacity"],
        aggregationType: .max,
        warningThreshold: 100,
        errorThreshold: 500,
        criticalThreshold: 1000
    )

    /// Alt-media domain metrics.
    public static let altMediaTurnaroundTime = MetricDefinitionComponent(
        name: "diaplasion.altmedia.turnaround",
        displayName: "Alt-Media Turnaround Time",
        description: "Time from request to delivery for alt-media materials",
        category: .domain,
        module: "Diaplasion",
        unit: .hours,
        tags: ["altmedia", "sla", "dsps"],
        aggregationType: .p90,
        warningThreshold: 24,   // 1 day
        errorThreshold: 72,     // 3 days
        criticalThreshold: 168  // 7 days
    )

    public static let altMediaBacklog = MetricDefinitionComponent(
        name: "diaplasion.altmedia.backlog",
        displayName: "Alt-Media Backlog",
        description: "Number of pending alt-media requests",
        category: .domain,
        module: "Diaplasion",
        unit: .count,
        tags: ["altmedia", "capacity", "dsps"],
        aggregationType: .last,
        warningThreshold: 50,
        errorThreshold: 100,
        criticalThreshold: 200
    )

    /// Case handling metrics.
    public static let caseResolutionTime = MetricDefinitionComponent(
        name: "conexus.case.resolution_time",
        displayName: "Case Resolution Time",
        description: "Time from case creation to resolution",
        category: .domain,
        module: "Conexus",
        unit: .hours,
        tags: ["cases", "sla"],
        aggregationType: .p90
    )

    public static let activeCases = MetricDefinitionComponent(
        name: "conexus.case.active_count",
        displayName: "Active Cases",
        description: "Number of currently open cases",
        category: .domain,
        module: "Conexus",
        unit: .count,
        tags: ["cases", "capacity"],
        aggregationType: .last
    )
}
