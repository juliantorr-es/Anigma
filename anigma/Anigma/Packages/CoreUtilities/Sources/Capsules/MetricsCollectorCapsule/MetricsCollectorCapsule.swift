import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - Metrics Collector Capsule

/// Performance and usage metrics collection capsule
public final class MetricsCollectorCapsule: Sendable {
    
    // MARK: - Properties
    
    public let id: String
    private let diagnostics: CapsuleDiagnostics
    private let configuration: MetricsConfiguration
    private let storage: MetricsStorage
    private let aggregator: MetricsAggregator
    private let reporter: MetricsReporter
    
    // MARK: - Initialization
    
    /// Initialize MetricsCollectorCapsule
    /// - Parameters:
    ///   - id: Unique identifier for this metrics collector instance
    ///   - diagnostics: Diagnostics collector for observability
    ///   - configuration: Metrics configuration
    ///   - storage: Metrics storage backend
    ///   - aggregator: Metrics aggregator
    ///   - reporter: Metrics reporter
    public init(
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics,
        configuration: MetricsConfiguration = .default,
        storage: MetricsStorage? = nil,
        aggregator: MetricsAggregator? = nil,
        reporter: MetricsReporter? = nil
    ) {
        self.id = id
        self.diagnostics = diagnostics
        self.configuration = configuration
        self.storage = storage ?? InMemoryMetricsStorage()
        self.aggregator = aggregator ?? DefaultMetricsAggregator()
        self.reporter = reporter ?? DefaultMetricsReporter()
    }
    
    // MARK: - Public API
    
    /// Record a counter metric
    /// - Parameters:
    ///   - name: Metric name
    ///   - value: Counter increment value (default: 1)
    ///   - tags: Metric tags
    ///   - timestamp: Custom timestamp (default: now)
    public func counter(
        name: String,
        value: Double = 1.0,
        tags: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        let metric = Metric(
            name: name,
            type: .counter,
            value: value,
            tags: tags,
            timestamp: timestamp
        )
        
        storage.store(metric)
        aggregator.process(metric)
        
        if configuration.enableRealTimeReporting {
            reporter.report(metric)
        }
    }
    
    /// Record a gauge metric
    /// - Parameters:
    ///   - name: Metric name
    ///   - value: Gauge value
    ///   - tags: Metric tags
    ///   - timestamp: Custom timestamp (default: now)
    public func gauge(
        name: String,
        value: Double,
        tags: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        let metric = Metric(
            name: name,
            type: .gauge,
            value: value,
            tags: tags,
            timestamp: timestamp
        )
        
        storage.store(metric)
        aggregator.process(metric)
        
        if configuration.enableRealTimeReporting {
            reporter.report(metric)
        }
    }
    
    /// Record a histogram metric
    /// - Parameters:
    ///   - name: Metric name
    ///   - value: Histogram value
    ///   - tags: Metric tags
    ///   - timestamp: Custom timestamp (default: now)
    public func histogram(
        name: String,
        value: Double,
        tags: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        let metric = Metric(
            name: name,
            type: .histogram,
            value: value,
            tags: tags,
            timestamp: timestamp
        )
        
        storage.store(metric)
        aggregator.process(metric)
        
        if configuration.enableRealTimeReporting {
            reporter.report(metric)
        }
    }
    
    /// Record a timer metric
    /// - Parameters:
    ///   - name: Metric name
    ///   - duration: Duration in seconds
    ///   - tags: Metric tags
    ///   - timestamp: Custom timestamp (default: now)
    public func timer(
        name: String,
        duration: TimeInterval,
        tags: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        let metric = Metric(
            name: name,
            type: .timer,
            value: duration,
            tags: tags,
            timestamp: timestamp
        )
        
        storage.store(metric)
        aggregator.process(metric)
        
        if configuration.enableRealTimeReporting {
            reporter.report(metric)
        }
    }
    
    /// Time an operation
    /// - Parameters:
    ///   - name: Timer name
    ///   - tags: Metric tags
    ///   - operation: Operation to time
    /// - Returns: Result of the operation
    public func time<T>(
        name: String,
        tags: [String: String] = [:],
        operation: () throws -> T
    ) rethrows -> T {
        let startTime = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(startTime)
        
        timer(name: name, duration: duration, tags: tags)
        
        return result
    }
    
    /// Time an async operation
    /// - Parameters:
    ///   - name: Timer name
    ///   - tags: Metric tags
    ///   - operation: Async operation to time
    /// - Returns: Result of the operation
    public func time<T>(
        name: String,
        tags: [String: String] = [:],
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        
        timer(name: name, duration: duration, tags: tags)
        
        return result
    }
    
    /// Get metric value
    /// - Parameters:
    ///   - name: Metric name
    ///   - tags: Metric tags (optional)
    ///   - aggregation: Aggregation type
    ///   - timeRange: Time range for query
    /// - Returns: Metric value if found
    public func getMetric(
        name: String,
        tags: [String: String] = [:],
        aggregation: AggregationType = .last,
        timeRange: TimeRange = .lastMinute
    ) async -> Double? {
        return await storage.query(
            name: name,
            tags: tags,
            aggregation: aggregation,
            timeRange: timeRange
        )
    }
    
    /// Get aggregated metrics
    /// - Parameters:
    ///   - name: Metric name
    ///   - tags: Metric tags (optional)
    ///   - timeRange: Time range for query
    /// - Returns: Aggregated metric data
    public func getAggregatedMetrics(
        name: String,
        tags: [String: String] = [:],
        timeRange: TimeRange = .lastHour
    ) async -> AggregatedMetrics? {
        return await aggregator.getAggregatedMetrics(
            name: name,
            tags: tags,
            timeRange: timeRange
        )
    }
    
    /// Get all metric names
    /// - Returns: Array of metric names
    public func getAllMetricNames() async -> [String] {
        return await storage.getAllMetricNames()
    }
    
    /// Get metrics by tag
    /// - Parameters:
    ///   - tagKey: Tag key
    ///   - tagValue: Tag value (optional)
    /// - Returns: Array of matching metrics
    public func getMetricsByTag(
        tagKey: String,
        tagValue: String? = nil
    ) async -> [Metric] {
        return await storage.queryByTag(tagKey: tagKey, tagValue: tagValue)
    }
    
    /// Export metrics in specified format
    /// - Parameters:
    ///   - format: Export format
    ///   - timeRange: Time range for export
    /// - Returns: Exported metrics data
    public func export(
        format: ExportFormat,
        timeRange: TimeRange = .lastHour
    ) async throws -> Data {
        let metrics = await storage.getAllMetrics(timeRange: timeRange)
        
        switch format {
        case .json:
            return try JSONEncoder().encode(metrics)
        case .prometheus:
            return try PrometheusExporter().export(metrics)
        case .csv:
            return try CSVExporter().export(metrics)
        }
    }
    
    /// Clear metrics
    /// - Parameters:
    ///   - name: Specific metric name to clear (optional)
    ///   - olderThan: Clear metrics older than this time (optional)
    public func clearMetrics(name: String? = nil, olderThan: Date? = nil) async {
        await storage.clear(name: name, olderThan: olderThan)
    }
    
    /// Get collector health status
    /// - Returns: Health information
    public func getHealthStatus() -> MetricsHealth {
        return MetricsHealth(
            status: .healthy,
            metricsStored: await storage.getMetricsCount(),
            storageType: String(describing: type(of: storage)),
            lastReportTime: reporter.lastReportTime,
            aggregationEnabled: true
        )
    }
    
    /// Shutdown the metrics collector
    public func shutdown() async {
        await storage.shutdown()
        await aggregator.shutdown()
        await reporter.shutdown()
        
        diagnostics.event(
            level: .info,
            category: "metrics.shutdown",
            message: "MetricsCollectorCapsule shutdown completed",
            correlationID: nil,
            metadata: ["collector_id": id]
        )
    }
}

// MARK: - Metric Models

/// Metric data structure
public struct Metric: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let type: MetricType
    public let value: Double
    public let tags: [String: String]
    public let timestamp: Date
    
    public init(
        name: String,
        type: MetricType,
        value: Double,
        tags: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.value = value
        self.tags = tags
        self.timestamp = timestamp
    }
}

/// Metric type enumeration
public enum MetricType: String, Codable, Sendable {
    case counter = "counter"
    case gauge = "gauge"
    case histogram = "histogram"
    case timer = "timer"
}

/// Aggregation type enumeration
public enum AggregationType: String, Codable, Sendable {
    case sum = "sum"
    case average = "average"
    case min = "min"
    case max = "max"
    case count = "count"
    case last = "last"
    case percentile = "percentile"
}

/// Time range for metric queries
public enum TimeRange: Codable, Sendable {
    case lastMinute
    case lastFiveMinutes
    case lastFifteenMinutes
    case lastHour
    case lastSixHours
    case lastDay
    case lastWeek
    case custom(Date, Date)
    
    public var duration: TimeInterval {
        switch self {
        case .lastMinute:
            return 60
        case .lastFiveMinutes:
            return 300
        case .lastFifteenMinutes:
            return 900
        case .lastHour:
            return 3600
        case .lastSixHours:
            return 21600
        case .lastDay:
            return 86400
        case .lastWeek:
            return 604800
        case .custom(let start, let end):
            return end.timeIntervalSince(start)
        }
    }
}

/// Aggregated metrics data
public struct AggregatedMetrics: Codable, Sendable {
    public let name: String
    public let type: MetricType
    public let tags: [String: String]
    public let timeRange: TimeRange
    public let count: Int
    public let sum: Double
    public let average: Double
    public let min: Double
    public let max: Double
    public let percentiles: [Double: Double]
    public let firstTimestamp: Date
    public let lastTimestamp: Date
    
    public init(
        name: String,
        type: MetricType,
        tags: [String: String],
        timeRange: TimeRange,
        count: Int,
        sum: Double,
        average: Double,
        min: Double,
        max: Double,
        percentiles: [Double: Double],
        firstTimestamp: Date,
        lastTimestamp: Date
    ) {
        self.name = name
        self.type = type
        self.tags = tags
        self.timeRange = timeRange
        self.count = count
        self.sum = sum
        self.average = average
        self.min = min
        self.max = max
        self.percentiles = percentiles
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
    }
}

/// Metrics configuration
public struct MetricsConfiguration: Sendable {
    public let enableRealTimeReporting: Bool
    public let retentionPeriod: TimeInterval
    public let maxMetrics: Int
    public let aggregationInterval: TimeInterval
    public let reportingInterval: TimeInterval
    
    public static let `default` = MetricsConfiguration(
        enableRealTimeReporting: false,
        retentionPeriod: 24 * 60 * 60, // 24 hours
        maxMetrics: 10000,
        aggregationInterval: 60.0, // 1 minute
        reportingInterval: 300.0 // 5 minutes
    )
    
    public init(
        enableRealTimeReporting: Bool = false,
        retentionPeriod: TimeInterval = 24 * 60 * 60,
        maxMetrics: Int = 10000,
        aggregationInterval: TimeInterval = 60.0,
        reportingInterval: TimeInterval = 300.0
    ) {
        self.enableRealTimeReporting = enableRealTimeReporting
        self.retentionPeriod = retentionPeriod
        self.maxMetrics = maxMetrics
        self.aggregationInterval = aggregationInterval
        self.reportingInterval = reportingInterval
    }
}

/// Metrics health status
public struct MetricsHealth: Codable, Sendable {
    public let status: HealthStatus
    public let metricsStored: Int
    public let storageType: String
    public let lastReportTime: Date?
    public let aggregationEnabled: Bool
    
    public init(
        status: HealthStatus,
        metricsStored: Int,
        storageType: String,
        lastReportTime: Date?,
        aggregationEnabled: Bool
    ) {
        self.status = status
        self.metricsStored = metricsStored
        self.storageType = storageType
        self.lastReportTime = lastReportTime
        self.aggregationEnabled = aggregationEnabled
    }
}

/// Export format enumeration
public enum ExportFormat: String, Codable, Sendable {
    case json = "json"
    case prometheus = "prometheus"
    case csv = "csv"
}