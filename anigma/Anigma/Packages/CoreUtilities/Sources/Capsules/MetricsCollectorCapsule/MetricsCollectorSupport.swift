import Foundation

// MARK: - Metrics Storage Protocol

/// Protocol for metrics storage backends
public protocol MetricsStorage: Sendable {
    /// Store a metric
    /// - Parameter metric: Metric to store
    func store(_ metric: Metric)
    
    /// Query metrics
    /// - Parameters:
    ///   - name: Metric name
    ///   - tags: Metric tags
    ///   - aggregation: Aggregation type
    ///   - timeRange: Time range
    /// - Returns: Metric value
    func query(
        name: String,
        tags: [String: String],
        aggregation: AggregationType,
        timeRange: TimeRange
    ) async -> Double?
    
    /// Query by tag
    /// - Parameters:
    ///   - tagKey: Tag key
    ///   - tagValue: Tag value (optional)
    /// - Returns: Array of matching metrics
    func queryByTag(tagKey: String, tagValue: String?) async -> [Metric]
    
    /// Get all metric names
    /// - Returns: Array of metric names
    func getAllMetricNames() async -> [String]
    
    /// Get all metrics in time range
    /// - Parameter timeRange: Time range
    /// - Returns: Array of metrics
    func getAllMetrics(timeRange: TimeRange) async -> [Metric]
    
    /// Get metrics count
    /// - Returns: Number of stored metrics
    func getMetricsCount() async -> Int
    
    /// Clear metrics
    /// - Parameters:
    ///   - name: Specific metric name to clear (optional)
    ///   - olderThan: Clear metrics older than this time (optional)
    func clear(name: String?, olderThan: Date?) async
    
    /// Shutdown storage
    func shutdown() async
}

// MARK: - In-Memory Storage

/// In-memory metrics storage implementation
public class InMemoryMetricsStorage: MetricsStorage {
    private let lock = NSLock()
    private nonisolated(unsafe) var metrics: [Metric] = []
    private let maxMetrics: Int
    
    public init(maxMetrics: Int = 10000) {
        self.maxMetrics = maxMetrics
    }
    
    public func store(_ metric: Metric) {
        lock.lock()
        defer { lock.unlock() }
        
        metrics.append(metric)
        
        // Remove oldest metrics if we exceed the limit
        if metrics.count > maxMetrics {
            metrics.removeFirst(metrics.count - maxMetrics)
        }
    }
    
    public func query(
        name: String,
        tags: [String: String],
        aggregation: AggregationType,
        timeRange: TimeRange
    ) async -> Double? {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let (startTime, _) = timeRangeToDates(timeRange, now: now)
        
        let filteredMetrics = metrics.filter { metric in
            metric.name == name &&
            metric.timestamp >= startTime &&
            tags.allSatisfy { key, value in metric.tags[key] == value }
        }
        
        guard !filteredMetrics.isEmpty else { return nil }
        
        return aggregate(filteredMetrics.map { $0.value }, aggregation: aggregation)
    }
    
    public func queryByTag(tagKey: String, tagValue: String?) async -> [Metric] {
        lock.lock()
        defer { lock.unlock() }
        
        return metrics.filter { metric in
            if let tagValue = tagValue {
                return metric.tags[tagKey] == tagValue
            } else {
                return metric.tags[tagKey] != nil
            }
        }
    }
    
    public func getAllMetricNames() async -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        return Set(metrics.map { $0.name }).sorted()
    }
    
    public func getAllMetrics(timeRange: TimeRange) async -> [Metric] {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let (startTime, _) = timeRangeToDates(timeRange, now: now)
        
        return metrics.filter { $0.timestamp >= startTime }
    }
    
    public func getMetricsCount() async -> Int {
        lock.lock()
        defer { lock.unlock() }
        return metrics.count
    }
    
    public func clear(name: String?, olderThan: Date?) async {
        lock.lock()
        defer { lock.unlock() }
        
        metrics = metrics.filter { metric in
            var shouldKeep = true
            
            if let name = name {
                shouldKeep = shouldKeep && metric.name != name
            }
            
            if let olderThan = olderThan {
                shouldKeep = shouldKeep && metric.timestamp >= olderThan
            }
            
            return shouldKeep
        }
    }
    
    public func shutdown() async {
        lock.lock()
        defer { lock.unlock() }
        metrics.removeAll()
    }
    
    private func aggregate(_ values: [Double], aggregation: AggregationType) -> Double {
        guard !values.isEmpty else { return 0 }
        
        switch aggregation {
        case .sum:
            return values.reduce(0, +)
        case .average:
            return values.reduce(0, +) / Double(values.count)
        case .min:
            return values.min() ?? 0
        case .max:
            return values.max() ?? 0
        case .count:
            return Double(values.count)
        case .last:
            return values.last ?? 0
        case .percentile:
            // Default to 95th percentile
            let sortedValues = values.sorted()
            let index = Int(Double(sortedValues.count) * 0.95)
            return sortedValues[min(index, sortedValues.count - 1)]
        }
    }
    
    private func timeRangeToDates(_ timeRange: TimeRange, now: Date) -> (Date, Date) {
        switch timeRange {
        case .lastMinute:
            return (now.addingTimeInterval(-60), now)
        case .lastFiveMinutes:
            return (now.addingTimeInterval(-300), now)
        case .lastFifteenMinutes:
            return (now.addingTimeInterval(-900), now)
        case .lastHour:
            return (now.addingTimeInterval(-3600), now)
        case .lastSixHours:
            return (now.addingTimeInterval(-21600), now)
        case .lastDay:
            return (now.addingTimeInterval(-86400), now)
        case .lastWeek:
            return (now.addingTimeInterval(-604800), now)
        case .custom(let start, let end):
            return (start, end)
        }
    }
}

// MARK: - Metrics Aggregator Protocol

/// Protocol for metrics aggregation
public protocol MetricsAggregator: Sendable {
    /// Process a metric for aggregation
    /// - Parameter metric: Metric to process
    func process(_ metric: Metric)
    
    /// Get aggregated metrics
    /// - Parameters:
    ///   - name: Metric name
    ///   - tags: Metric tags
    ///   - timeRange: Time range
    /// - Returns: Aggregated metrics
    func getAggregatedMetrics(
        name: String,
        tags: [String: String],
        timeRange: TimeRange
    ) async -> AggregatedMetrics?
    
    /// Shutdown aggregator
    func shutdown() async
}

// MARK: - Default Aggregator

/// Default metrics aggregator implementation
public class DefaultMetricsAggregator: MetricsAggregator {
    private let lock = NSLock()
    private nonisolated(unsafe) var aggregatedData: [String: [Double]] = [:]
    private let aggregationWindow: TimeInterval
    
    public init(aggregationWindow: TimeInterval = 300.0) { // 5 minutes
        self.aggregationWindow = aggregationWindow
    }
    
    public func process(_ metric: Metric) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = metricKey(name: metric.name, tags: metric.tags)
        if aggregatedData[key] == nil {
            aggregatedData[key] = []
        }
        aggregatedData[key]?.append(metric.value)
        
        // Keep only recent data
        let cutoffTime = Date().addingTimeInterval(-aggregationWindow)
        // In a real implementation, we'd store timestamps with values
        // For now, just keep the last 1000 values per key
        if let values = aggregatedData[key], values.count > 1000 {
            aggregatedData[key] = Array(values.suffix(1000))
        }
    }
    
    public func getAggregatedMetrics(
        name: String,
        tags: [String: String],
        timeRange: TimeRange
    ) async -> AggregatedMetrics? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = metricKey(name: name, tags: tags)
        guard let values = aggregatedData[key], !values.isEmpty else { return nil }
        
        let count = values.count
        let sum = values.reduce(0, +)
        let average = sum / Double(count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        
        let sortedValues = values.sorted()
        let percentiles: [Double: Double] = [
            50.0: sortedValues[max(0, Int(Double(count) * 0.5))],
            90.0: sortedValues[max(0, Int(Double(count) * 0.9))],
            95.0: sortedValues[max(0, Int(Double(count) * 0.95))],
            99.0: sortedValues[max(0, Int(Double(count) * 0.99))]
        ]
        
        return AggregatedMetrics(
            name: name,
            type: .gauge, // Default type for aggregated metrics
            tags: tags,
            timeRange: timeRange,
            count: count,
            sum: sum,
            average: average,
            min: min,
            max: max,
            percentiles: percentiles,
            firstTimestamp: Date(), // Would need to track actual timestamps
            lastTimestamp: Date()
        )
    }
    
    public func shutdown() async {
        lock.lock()
        defer { lock.unlock() }
        aggregatedData.removeAll()
    }
    
    private func metricKey(name: String, tags: [String: String]) -> String {
        let tagString = tags.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "\(name){\(tagString)}"
    }
}

// MARK: - Metrics Reporter Protocol

/// Protocol for metrics reporting
public protocol MetricsReporter: Sendable {
    /// Report a single metric
    /// - Parameter metric: Metric to report
    func report(_ metric: Metric)
    
    /// Report multiple metrics
    /// - Parameter metrics: Metrics to report
    func report(_ metrics: [Metric])
    
    /// Last report time
    var lastReportTime: Date? { get }
    
    /// Shutdown reporter
    func shutdown() async
}

// MARK: - Default Reporter

/// Default metrics reporter implementation
public class DefaultMetricsReporter: MetricsReporter {
    private let lock = NSLock()
    private nonisolated(unsafe) var _lastReportTime: Date?
    
    public var lastReportTime: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _lastReportTime
    }
    
    public func report(_ metric: Metric) {
        lock.lock()
        defer { lock.unlock() }
        
        _lastReportTime = Date()
        
        // In a real implementation, this would send to external systems
        print("METRIC: \(metric.name) \(metric.value) \(metric.tags)")
    }
    
    public func report(_ metrics: [Metric]) {
        lock.lock()
        defer { lock.unlock() }
        
        _lastReportTime = Date()
        
        for metric in metrics {
            print("METRIC: \(metric.name) \(metric.value) \(metric.tags)")
        }
    }
    
    public func shutdown() async {
        lock.lock()
        defer { lock.unlock() }
        _lastReportTime = nil
    }
}

// MARK: - Exporters

/// Prometheus metrics exporter
public struct PrometheusExporter {
    public init() {}
    
    public func export(_ metrics: [Metric]) throws -> Data {
        var lines: [String] = []
        let groupedMetrics = Dictionary(grouping: metrics) { "\($0.name)_\($0.tags.sorted { $0.key < $1.key }.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ","))" }
        
        for (key, metricsGroup) in groupedMetrics {
            lines.append("# HELP \(key) Metric exported from Anigma")
            lines.append("# TYPE \(key) gauge")
            
            for metric in metricsGroup {
                let value = String(format: "%.6f", metric.value)
                lines.append("\(key) \(value) \(Int(metric.timestamp.timeIntervalSince1970))")
            }
        }
        
        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }
}

/// CSV metrics exporter
public struct CSVExporter {
    public init() {}
    
    public func export(_ metrics: [Metric]) throws -> Data {
        var lines: [String] = []
        
        // Header
        lines.append("timestamp,name,type,value,tags")
        
        // Data rows
        for metric in metrics {
            let timestamp = ISO8601DateFormatter().string(from: metric.timestamp)
            let tags = metric.tags.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
            let value = String(format: "%.6f", metric.value)
            lines.append("\(timestamp),\(metric.name),\(metric.type.rawValue),\(value),\"\(tags)\"")
        }
        
        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }
}

// MARK: - Utility Functions

/// Create a metrics collector with default configuration
public func createMetricsCollector(
    id: String = UUID().uuidString,
    diagnostics: CapsuleDiagnostics,
    maxMetrics: Int = 10000
) -> MetricsCollectorCapsule {
    let storage = InMemoryMetricsStorage(maxMetrics: maxMetrics)
    let configuration = MetricsConfiguration.default
    
    return MetricsCollectorCapsule(
        id: id,
        diagnostics: diagnostics,
        configuration: configuration,
        storage: storage
    )
}

/// Create a timer helper
public func timer<T>(
    metrics: MetricsCollectorCapsule,
    name: String,
    tags: [String: String] = [:]
) -> TimerHelper<T> {
    return TimerHelper(metrics: metrics, name: name, tags: tags)
}

/// Helper for timing operations
public class TimerHelper<T>: Sendable {
    private let metrics: MetricsCollectorCapsule
    private let name: String
    private let tags: [String: String]
    
    init(metrics: MetricsCollectorCapsule, name: String, tags: [String: String]) {
        self.metrics = metrics
        self.name = name
        self.tags = tags
    }
    
    public func time(_ operation: () throws -> T) rethrows -> T {
        return try metrics.time(name: name, tags: tags, operation: operation)
    }
    
    public func time(_ operation: () async throws -> T) async rethrows -> T {
        return try await metrics.time(name: name, tags: tags, operation: operation)
    }
}