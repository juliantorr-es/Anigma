// EventAnalytics.swift
// Event analytics and metrics for monitoring and optimization

import Foundation
import AnigmaPrimitives

/// Event analytics configuration
public struct EventAnalyticsConfig: Sendable, Codable {
    public let sampleRate: Double
    public let maxMetricsHistory: Int
    public let metricsFlushInterval: TimeInterval
    
    public static let `default` = EventAnalyticsConfig(
        sampleRate: 1.0, // Sample all events
        maxMetricsHistory: 1000,
        metricsFlushInterval: 60.0 // 1 minute
    )
    
    public static let production = EventAnalyticsConfig(
        sampleRate: 0.1, // Sample 10% of events
        maxMetricsHistory: 10000,
        metricsFlushInterval: 300.0 // 5 minutes
    )
}

/// Event metric types
public enum EventMetricType: String, Sendable, Codable {
    case count = "count"
    case latency = "latency"
    case throughput = "throughput"
    case errorRate = "errorRate"
    case size = "size"
}

/// Event metric data point
public struct EventMetricDataPoint: Sendable, Codable {
    public let timestamp: Date
    public let value: Double
    public let eventType: String
    public let metricType: EventMetricType
    public let tags: [String: String]?
    
    public init(timestamp: Date, value: Double, eventType: String, metricType: EventMetricType, tags: [String: String]? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.eventType = eventType
        self.metricType = metricType
        self.tags = tags
    }
}

/// Event analytics protocol
public protocol EventAnalytics: Sendable {
    /// Record an event metric
    /// - Parameters:
    ///   - event: The event that was processed
    ///   - metricType: Type of metric
    ///   - value: Metric value
    ///   - tags: Additional tags for filtering
    func record<Event: AnigmaEvent>(_ event: Event, metricType: EventMetricType, value: Double, tags: [String: String]?) async
    
    /// Get current metrics
    /// - Parameters:
    ///   - eventType: Optional event type filter
    ///   - metricType: Optional metric type filter
    ///   - limit: Maximum number of data points
    /// - Returns: Array of metric data points
    func getMetrics(eventType: String?, metricType: EventMetricType?, limit: Int?) async -> [EventMetricDataPoint]
    
    /// Get aggregated metrics
    /// - Parameters:
    ///   - eventType: Optional event type filter
    ///   - metricType: Optional metric type filter
    ///   - timeRange: Optional time range
    /// - Returns: Aggregated metrics
    func getAggregatedMetrics(eventType: String?, metricType: EventMetricType?, timeRange: ClosedRange<Date>?) async -> EventMetricsAggregation
    
    /// Clear metrics
    /// - Parameters:
    ///   - eventType: Optional event type to clear
    ///   - olderThan: Optional age threshold
    func clearMetrics(eventType: String?, olderThan: Date?) async
    
    /// Get analytics statistics
    /// - Returns: Statistics about collected metrics
    func statistics() async -> EventAnalyticsStats
}

/// Event metrics aggregation
public struct EventMetricsAggregation: Sendable, Codable {
    public let eventType: String
    public let metricType: EventMetricType
    public let count: Int
    public let min: Double?
    public let max: Double?
    public let average: Double?
    public let sum: Double?
    public let timeRange: ClosedRange<Date>?
    
    public init(eventType: String, metricType: EventMetricType, count: Int, min: Double?, max: Double?, average: Double?, sum: Double?, timeRange: ClosedRange<Date>?) {
        self.eventType = eventType
        self.metricType = metricType
        self.count = count
        self.min = min
        self.max = max
        self.average = average
        self.sum = sum
        self.timeRange = timeRange
    }
}

/// Event analytics statistics
public struct EventAnalyticsStats: Sendable, Codable {
    public let totalMetrics: Int
    public let eventTypes: [String: Int]
    public let metricTypes: [EventMetricType: Int]
    public let oldestMetric: Date?
    public let newestMetric: Date?
    public let storageSize: Int64
}

/// In-memory event analytics
public actor InMemoryEventAnalytics: EventAnalytics {
    private let config: EventAnalyticsConfig
    private var metrics: [EventMetricDataPoint] = []
    private let random: @Sendable () -> Double
    
    public init(config: EventAnalyticsConfig = .default, random: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }) {
        self.config = config
        self.random = random
    }
    
    public func record<Event: AnigmaEvent>(_ event: Event, metricType: EventMetricType, value: Double, tags: [String: String]? = nil) async {
        // Apply sampling if needed
        guard random() < config.sampleRate else { return }
        
        let dataPoint = EventMetricDataPoint(
            timestamp: Date(),
            value: value,
            eventType: Event.eventType,
            metricType: metricType,
            tags: tags
        )
        
        metrics.append(dataPoint)
        
        // Clean up old metrics
        cleanupOldMetrics()
    }
    
    public func getMetrics(eventType: String?, metricType: EventMetricType?, limit: Int?) async -> [EventMetricDataPoint] {
        let filter: (EventMetricDataPoint) -> Bool = { metric in
            if let eventType = eventType, metric.eventType != eventType {
                return false
            }
            if let metricType = metricType, metric.metricType != metricType {
                return false
            }
            return true
        }
        
        let filtered = metrics.filter(filter)
        let sorted = filtered.sorted { $0.timestamp > $1.timestamp } // Newest first
        let limited = limit.map { Array(sorted.prefix($0)) } ?? sorted
        
        return Array(limited)
    }
    
    public func getAggregatedMetrics(eventType: String?, metricType: EventMetricType?, timeRange: ClosedRange<Date>?) async -> EventMetricsAggregation {
        let filtered = metrics.filter { metric in
            if let eventType = eventType, metric.eventType != eventType {
                return false
            }
            if let metricType = metricType, metric.metricType != metricType {
                return false
            }
            if let timeRange = timeRange, !timeRange.contains(metric.timestamp) {
                return false
            }
            return true
        }
        
        guard !filtered.isEmpty else {
            return EventMetricsAggregation(
                eventType: eventType ?? "unknown",
                metricType: metricType ?? .count,
                count: 0,
                min: nil,
                max: nil,
                average: nil,
                sum: nil,
                timeRange: timeRange
            )
        }
        
        let values = filtered.map { $0.value }
        let min = values.min()
        let max = values.max()
        let sum = values.reduce(0, +)
        let average = sum / Double(values.count)
        
        let startTime = filtered.min { $0.timestamp < $1.timestamp }?.timestamp
        let endTime = filtered.max { $0.timestamp < $1.timestamp }?.timestamp
        let range = startTime.flatMap { start in
            endTime.map { end in
                start...end
            }
        }
        
        return EventMetricsAggregation(
            eventType: eventType ?? filtered[0].eventType,
            metricType: metricType ?? filtered[0].metricType,
            count: filtered.count,
            min: min,
            max: max,
            average: average,
            sum: sum,
            timeRange: range
        )
    }
    
    public func clearMetrics(eventType: String?, olderThan: Date?) async {
        metrics = metrics.filter { metric in
            if let eventType = eventType, metric.eventType != eventType {
                return true // Keep events of different types
            }
            if let olderThan = olderThan, metric.timestamp < olderThan {
                return false // Remove old events
            }
            return true // Keep events
        }
    }
    
    public func statistics() async -> EventAnalyticsStats {
        let eventTypes = Dictionary(metrics.map { ($0.eventType, 1) }, uniquingKeysWith: +)
        let metricTypes = Dictionary(metrics.map { ($0.metricType, 1) }, uniquingKeysWith: +)
        let oldest = metrics.min(by: { $0.timestamp < $1.timestamp })?.timestamp
        let newest = metrics.max(by: { $0.timestamp < $1.timestamp })?.timestamp
        let size = Int64(metrics.count * MemoryLayout<EventMetricDataPoint>.size)
        
        return EventAnalyticsStats(
            totalMetrics: metrics.count,
            eventTypes: eventTypes,
            metricTypes: metricTypes,
            oldestMetric: oldest,
            newestMetric: newest,
            storageSize: size
        )
    }
    
    // MARK: - Private Methods
    
    private func cleanupOldMetrics() {
        let cutoffTime = Date().addingTimeInterval(-config.metricsFlushInterval)
        metrics = metrics.filter { $0.timestamp >= cutoffTime }
        
        if metrics.count > config.maxMetricsHistory {
            metrics = Array(metrics.suffix(config.maxMetricsHistory))
        }
    }
}

/// Event analytics wrapper for the shared event bus
public actor AnalyticsEventBus: EventBus {
    private let underlyingBus: EventBus
    private let analytics: EventAnalytics
    private let shouldAnalyze: @Sendable (any AnigmaEvent.Type) -> Bool
    
    public init(
        underlyingBus: EventBus = sharedEventBus,
        analytics: EventAnalytics = InMemoryEventAnalytics(config: .default),
        shouldAnalyze: @escaping @Sendable (any AnigmaEvent.Type) -> Bool = { _ in true }
    ) {
        self.underlyingBus = underlyingBus
        self.analytics = analytics
        self.shouldAnalyze = shouldAnalyze
    }
    
    public func publish<Event: AnigmaEvent>(_ event: Event, source: String?) async -> Task<Void, any Error> {
        let startTime = DispatchTime.now()
        
        // Publish to underlying bus
        let task = await underlyingBus.publish(event, source: source)
        
        // Record analytics if needed
        if shouldAnalyze(Event.self) {
            let endTime = DispatchTime.now()
            let latency = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000 // Convert to ms
            
            // Record latency metric
            await analytics.record(event, metricType: .latency, value: latency, tags: source.map { ["source": $0] })
            
            // Record count metric
            await analytics.record(event, metricType: .count, value: 1, tags: source.map { ["source": $0] })
        }
        
        return task
    }
    
    public func subscribe<Event: AnigmaEvent>(to type: Event.Type, handler: @escaping @Sendable (TypedEvent<Event>) async -> Void) async -> UUID {
        let startTime = DispatchTime.now()
        let shouldAnalyze = self.shouldAnalyze
        let analytics = self.analytics
        
        // Subscribe to underlying bus
        let id = await underlyingBus.subscribe(to: type, handler: { event in
            let endTime = DispatchTime.now()
            let latency = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000 // Convert to ms
            
            // Record processing latency
            if shouldAnalyze(Event.self) {
                await analytics.record(event.event, metricType: .latency, value: latency, tags: nil)
            }
            
            await handler(event)
        })
        
        return id
    }
    
    public func unsubscribe(id: UUID) async {
        await underlyingBus.unsubscribe(id: id)
    }
    
    public func unsubscribeAll<Event: AnigmaEvent>(from type: Event.Type) async {
        await underlyingBus.unsubscribeAll(from: type)
    }
    
    /// Get analytics metrics
    public func getMetrics(eventType: String?, metricType: EventMetricType?, limit: Int?) async -> [EventMetricDataPoint] {
        await analytics.getMetrics(eventType: eventType, metricType: metricType, limit: limit)
    }
    
    /// Get aggregated metrics
    public func getAggregatedMetrics(eventType: String?, metricType: EventMetricType?, timeRange: ClosedRange<Date>?) async -> EventMetricsAggregation {
        await analytics.getAggregatedMetrics(eventType: eventType, metricType: metricType, timeRange: timeRange)
    }
    
    /// Clear analytics data
    public func clearMetrics(eventType: String?, olderThan: Date?) async {
        await analytics.clearMetrics(eventType: eventType, olderThan: olderThan)
    }
    
    /// Get analytics statistics
    public func statistics() async -> EventAnalyticsStats {
        await analytics.statistics()
    }
}

/// Default analytics strategy for common event types
public func defaultAnalyticsStrategy(for eventType: any AnigmaEvent.Type) -> Bool {
    let eventTypeString = String(describing: eventType)
    
    // Always analyze critical events
    if eventTypeString.contains("Workflow") || 
       eventTypeString.contains("Job") || 
       eventTypeString.contains("Agent") ||
       eventTypeString.contains("System") {
        return true
    }
    
    // Don't analyze debug/progress events by default
    return false
}

/// Event analytics utilities
public enum EventAnalyticsUtils {
    /// Calculate event throughput
    public static func calculateThroughput(metrics: [EventMetricDataPoint], timeRange: ClosedRange<Date>?) -> Double? {
        guard !metrics.isEmpty else { return nil }
        
        let filtered = timeRange.map { range in
            metrics.filter { point in
                point.timestamp >= range.lowerBound && point.timestamp <= range.upperBound
            }
        } ?? metrics
        guard !filtered.isEmpty else { return nil }
        
        let startTime = filtered.min { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
        let endTime = filtered.max { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        guard duration > 0 else { return nil }
        
        return Double(filtered.count) / duration
    }
    
    /// Calculate event error rate
    public static func calculateErrorRate(metrics: [EventMetricDataPoint]) -> Double? {
        let errorMetrics = metrics.filter { $0.metricType == .errorRate }
        guard !errorMetrics.isEmpty else { return nil }
        
        let totalErrors = errorMetrics.reduce(0) { $0 + $1.value }
        let totalEvents = metrics.count
        
        guard totalEvents > 0 else { return nil }
        
        return totalErrors / Double(totalEvents)
    }
    
    /// Calculate average event latency
    public static func calculateAverageLatency(metrics: [EventMetricDataPoint]) -> Double? {
        let latencyMetrics = metrics.filter { $0.metricType == .latency }
        guard !latencyMetrics.isEmpty else { return nil }
        
        let sum = latencyMetrics.reduce(0) { $0 + $1.value }
        return sum / Double(latencyMetrics.count)
    }
}
