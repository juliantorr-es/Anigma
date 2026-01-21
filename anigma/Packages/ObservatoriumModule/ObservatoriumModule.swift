//
//  ObservatoriumModule.swift
//  ObservatoriumModule
//
//  Observability and telemetry domain ("observatorium" = Latin for "observation place").
//  Provides: System health, performance metrics, error tracking, user feedback,
//  and domain-level operational metrics for institutional deployment.
//
//  This module makes "insane performance reports" manageable by:
//  - Capturing structured telemetry with privacy-respecting redaction
//  - Promoting error clusters into Pragma issues automatically
//  - Tracking domain-specific SLA metrics (alt-media turnaround, case handling, etc.)
//  - Providing dashboards and alerts for operations teams
//

import Foundation
import AnigmaCore

// MARK: - Module Initialization

/// Initializes the Observatorium module.
public enum ObservatoriumModule {
    /// Module version for compatibility tracking.
    public static let version = "0.1.0"

    /// Initializes the observability infrastructure.
    /// Call during application bootstrap after AnigmaCore.
    public static func initialize() async {
        // Register components with the ECS registry if needed
        // Set up default metric collectors
        // Initialize error aggregation
    }
}

extension ObservatoriumModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        // Register observability systems with the runtime
        await Logger.shared.info("ObservatoriumModule registered", category: "ObservatoriumModule")
    }
}

// MARK: - Metric Types

/// Categories of metrics for organization and filtering.
public enum MetricCategory: String, Codable, Sendable {
    case system       // CPU, memory, disk, network
    case performance  // Latency, throughput, queue depth
    case domain       // Business/workflow metrics (alt-media turnaround, etc.)
    case user         // User-perceived performance
    case error        // Error rates and counts
    case security     // Security-related events
}

/// Units for metric values.
public enum MetricUnit: String, Codable, Sendable {
    case count
    case milliseconds
    case seconds
    case minutes
    case hours
    case bytes
    case kilobytes
    case megabytes
    case percentage
    case ratio
    case custom
}

/// Severity levels for alerts and errors.
public enum AlertSeverity: String, Codable, Sendable, Comparable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"

    public static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        let order: [AlertSeverity] = [.info, .warning, .error, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Error Types

/// Errors specific to the Observatorium module.
public enum ObservatoriumError: Error, Sendable {
    case metricNotFound(String)
    case invalidMetricValue
    case alertThresholdExceeded(metric: String, value: Double, threshold: Double)
    case feedbackSubmissionFailed(reason: String)
    case telemetryBufferFull
    case aggregationFailed(reason: String)
}

// MARK: - Identifiers

/// Unique identifier for a metric definition.
public struct MetricId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() {
        self.raw = UUID()
    }

    public init(raw: UUID) {
        self.raw = raw
    }

    public var description: String {
        raw.uuidString.prefix(8).lowercased()
    }
}

/// Unique identifier for a telemetry event.
public struct TelemetryEventId: Hashable, Codable, Sendable {
    public let raw: UUID

    public init() {
        self.raw = UUID()
    }

    public init(raw: UUID) {
        self.raw = raw
    }
}

/// Unique identifier for an error record.
public struct ErrorRecordId: Hashable, Codable, Sendable {
    public let raw: UUID

    public init() {
        self.raw = UUID()
    }

    public init(raw: UUID) {
        self.raw = raw
    }
}

/// Unique identifier for a feedback item.
public struct FeedbackId: Hashable, Codable, Sendable {
    public let raw: UUID

    public init() {
        self.raw = UUID()
    }

    public init(raw: UUID) {
        self.raw = raw
    }
}

/// Unique identifier for an alert.
public struct AlertId: Hashable, Codable, Sendable {
    public let raw: UUID

    public init() {
        self.raw = UUID()
    }

    public init(raw: UUID) {
        self.raw = raw
    }
}
