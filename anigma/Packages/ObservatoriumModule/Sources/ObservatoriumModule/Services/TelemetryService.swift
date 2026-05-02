import Foundation
import AnigmaPrimitives

// MARK: - Telemetry Service Protocol
public protocol TelemetryServiceProtocol: Sendable {
    func recordEvent(_ event: TelemetryEvent) async
    func recordMetric(_ metric: PerformanceMetrics) async
    func getEvents(since date: Date) async -> [TelemetryEvent]
    func getMetrics(since date: Date) async -> [PerformanceMetrics]
    func getAggregatedMetrics(for timeRange: TimeRange) async -> AggregatedMetrics?
    func startCollection() async
    func stopCollection() async
}

// MARK: - Aggregated Metrics
public struct AggregatedMetrics: Sendable {
    public let timeRange: TimeRange
    public let averageCPUUsage: Double
    public let peakCPUUsage: Double
    public let averageMemoryUsage: UInt64
    public let peakMemoryUsage: UInt64
    public let totalNetworkIn: UInt64
    public let totalNetworkOut: UInt64
    public let eventCount: Int
    public let errorCount: Int
    public let warningCount: Int
    
    public init(
        timeRange: TimeRange,
        averageCPUUsage: Double,
        peakCPUUsage: Double,
        averageMemoryUsage: UInt64,
        peakMemoryUsage: UInt64,
        totalNetworkIn: UInt64,
        totalNetworkOut: UInt64,
        eventCount: Int,
        errorCount: Int,
        warningCount: Int
    ) {
        self.timeRange = timeRange
        self.averageCPUUsage = averageCPUUsage
        self.peakCPUUsage = peakCPUUsage
        self.averageMemoryUsage = averageMemoryUsage
        self.peakMemoryUsage = peakMemoryUsage
        self.totalNetworkIn = totalNetworkIn
        self.totalNetworkOut = totalNetworkOut
        self.eventCount = eventCount
        self.errorCount = errorCount
        self.warningCount = warningCount
    }
}

// MARK: - Telemetry Service Implementation
@MainActor
public final class TelemetryService: TelemetryServiceProtocol {
    private let eventStore: InMemoryEventStore
    private let metricsCollector: MetricsCollector
    private let aggregationEngine: AggregationEngine
    private let anomalyDetector = TelemetryAnomalyDetector()
    private var collectionTask: Task<Void, Never>?
    
    // MARK: - Configuration
    private let configuration: TelemetryConfiguration
    
    public init(configuration: TelemetryConfiguration = .default) {
        self.configuration = configuration
        self.eventStore = InMemoryEventStore(maxEvents: configuration.maxStoredEvents)
        self.metricsCollector = MetricsCollector()
        self.aggregationEngine = AggregationEngine()
    }
    
    // MARK: - TelemetryServiceProtocol
    public func recordEvent(_ event: TelemetryEvent) async {
        eventStore.addEvent(event)
        
        // Forward to AnigmaDaemonCore if needed
        if configuration.forwardToDaemonCore {
            // Integration with AnigmaDaemonCore would happen here
        }
        
        // Trigger alert evaluation for critical events
        if event.severity.level >= TelemetrySeverity.error.level {
            NotificationCenter.default.post(
                name: .criticalTelemetryEvent,
                object: event
            )
        }
    }
    
    public func recordMetric(_ metric: PerformanceMetrics) async {
        metricsCollector.addMetric(metric)
        
        // Check for threshold violations
        if metricsCollector.checkThresholds(metric) {
            let event = TelemetryEvent(
                type: .performanceMetric,
                source: "telemetry_service",
                data: [
                    "cpu_usage": metric.cpuUsage,
                    "memory_usage": metric.memoryUsage,
                    "disk_usage": metric.diskUsage
                ],
                severity: .warning
            )
            await recordEvent(event)
        }

        let anomaly = anomalyDetector.record(metric)
        guard anomaly.isAnomalous else { return }

        let event = TelemetryEvent(
            type: .anomalyDetected,
            source: "telemetry_anomaly_detector",
            data: [
                "anomaly_score": anomaly.score,
                "preferred_lane": anomaly.preferredLane.rawValue,
                "cpu_baseline": anomaly.cpuBaseline,
                "memory_baseline": anomaly.memoryBaseline,
                "disk_baseline": anomaly.diskBaseline,
                "connections_baseline": anomaly.connectionsBaseline
            ],
            severity: anomaly.severity
        )
        await recordEvent(event)
    }
    
    public func getEvents(since date: Date) async -> [TelemetryEvent] {
        eventStore.getEvents(since: date)
    }
    
    public func getMetrics(since date: Date) async -> [PerformanceMetrics] {
        metricsCollector.getMetrics(since: date)
    }
    
    public func getAggregatedMetrics(for timeRange: TimeRange) async -> AggregatedMetrics? {
        let interval = timeRange.dateInterval
        let metrics = await getMetrics(since: interval.start)
        let events = await getEvents(since: interval.start)
        
        return aggregationEngine.aggregate(
            metrics: metrics,
            events: events,
            for: timeRange
        )
    }
    
    public func startCollection() async {
        guard collectionTask == nil else { return }
        
        collectionTask = Task {
            while !Task.isCancelled {
                await collectSystemMetrics()
                try? await Task.sleep(nanoseconds: UInt64(configuration.collectionInterval * 1_000_000_000))
            }
        }
    }
    
    public func stopCollection() async {
        collectionTask?.cancel()
        collectionTask = nil
    }
    
    // MARK: - Private Methods
    private func collectSystemMetrics() async {
        let metrics = metricsCollector.collectCurrentMetrics()
        await recordMetric(metrics)
    }
}

// MARK: - Telemetry Configuration
public struct TelemetryConfiguration: Sendable {
    public let maxStoredEvents: Int
    public let collectionInterval: TimeInterval
    public let retentionPeriod: TimeInterval
    public let forwardToDaemonCore: Bool
    
    public static let `default` = TelemetryConfiguration(
        maxStoredEvents: 10000,
        collectionInterval: 30.0, // 30 seconds
        retentionPeriod: 7 * 24 * 3600, // 7 days
        forwardToDaemonCore: true
    )
    
    public init(
        maxStoredEvents: Int,
        collectionInterval: TimeInterval,
        retentionPeriod: TimeInterval,
        forwardToDaemonCore: Bool
    ) {
        self.maxStoredEvents = maxStoredEvents
        self.collectionInterval = collectionInterval
        self.retentionPeriod = retentionPeriod
        self.forwardToDaemonCore = forwardToDaemonCore
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let criticalTelemetryEvent = Notification.Name("criticalTelemetryEvent")
}

// MARK: - In-Memory Event Store
@MainActor
private final class InMemoryEventStore {
    private var events: [TelemetryEvent] = []
    private let maxEvents: Int
    
    init(maxEvents: Int) {
        self.maxEvents = maxEvents
    }
    
    func addEvent(_ event: TelemetryEvent) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }
    
    func getEvents(since date: Date) -> [TelemetryEvent] {
        events.filter { $0.timestamp >= date }
    }
}

// MARK: - Metrics Collector
@MainActor
private final class MetricsCollector {
    private var metrics: [PerformanceMetrics] = []
    private let maxMetrics: Int = 1000
    
    func addMetric(_ metric: PerformanceMetrics) {
        metrics.append(metric)
        if metrics.count > maxMetrics {
            metrics.removeFirst(metrics.count - maxMetrics)
        }
    }
    
    func getMetrics(since date: Date) -> [PerformanceMetrics] {
        metrics.filter { $0.timestamp >= date }
    }
    
    func collectCurrentMetrics() -> PerformanceMetrics {
        // Simulate system metrics collection
        // In a real implementation, this would use system APIs
        let cpuUsage = Double.random(in: 0.1...0.8)
        let memoryUsage = UInt64.random(in: 1_000_000_000...8_000_000_000)
        let diskUsage = UInt64.random(in: 100_000_000_000...500_000_000_000)
        let networkIO = NetworkIO(
            bytesIn: UInt64.random(in: 1000...1_000_000),
            bytesOut: UInt64.random(in: 1000...1_000_000),
            connections: Int.random(in: 1...50)
        )
        
        return PerformanceMetrics(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            diskUsage: diskUsage,
            networkIO: networkIO
        )
    }
    
    func checkThresholds(_ metric: PerformanceMetrics) -> Bool {
        // Check if metrics exceed thresholds
        metric.cpuUsage > 0.8 || // 80% CPU
        metric.memoryUsage > 8_000_000_000 || // 8GB memory
        metric.diskUsage > 450_000_000_000 // 450GB disk
    }
}

// MARK: - Anomaly Detector
private struct TelemetryAnomalyAssessment {
    let score: Double
    let isAnomalous: Bool
    let severity: TelemetrySeverity
    let preferredLane: HardwareLane
    let cpuBaseline: Double
    let memoryBaseline: Double
    let diskBaseline: Double
    let connectionsBaseline: Double
}

@MainActor
private final class TelemetryAnomalyDetector {
    private var recentMetrics: [PerformanceMetrics] = []
    private let windowSize: Int
    private let anomalyThreshold: Double

    init(windowSize: Int = 16, anomalyThreshold: Double = 0.65) {
        self.windowSize = windowSize
        self.anomalyThreshold = anomalyThreshold
    }

    func record(_ metric: PerformanceMetrics) -> TelemetryAnomalyAssessment {
        recentMetrics.append(metric)
        if recentMetrics.count > windowSize {
            recentMetrics.removeFirst(recentMetrics.count - windowSize)
        }

        let samples = recentMetrics
        let cpuBaseline = samples.map(\.cpuUsage).reduce(0, +) / Double(samples.count)
        let memoryBaseline = samples.map { Double($0.memoryUsage) }.reduce(0, +) / Double(samples.count)
        let diskBaseline = samples.map { Double($0.diskUsage) }.reduce(0, +) / Double(samples.count)
        let connectionsBaseline = samples.map { Double($0.networkIO.connections) }.reduce(0, +) / Double(samples.count)

        let cpuDeviation = normalizedDeviation(current: metric.cpuUsage, baseline: cpuBaseline, floor: 0.1)
        let memoryDeviation = normalizedDeviation(current: Double(metric.memoryUsage), baseline: memoryBaseline, floor: 1.0)
        let diskDeviation = normalizedDeviation(current: Double(metric.diskUsage), baseline: diskBaseline, floor: 1.0)
        let connectionDeviation = normalizedDeviation(current: Double(metric.networkIO.connections), baseline: connectionsBaseline, floor: 1.0)

        let score = (cpuDeviation * 0.4) + (memoryDeviation * 0.25) + (diskDeviation * 0.2) + (connectionDeviation * 0.15)
        let saturationSpike = metric.cpuUsage > 0.9 || metric.memoryUsage > 8_500_000_000 || metric.diskUsage > 475_000_000_000
        let isAnomalous = score >= anomalyThreshold || saturationSpike
        let severity: TelemetrySeverity = score >= 1.0 || saturationSpike ? .error : .warning

        return TelemetryAnomalyAssessment(
            score: score,
            isAnomalous: isAnomalous,
            severity: severity,
            preferredLane: .perception,
            cpuBaseline: cpuBaseline,
            memoryBaseline: memoryBaseline,
            diskBaseline: diskBaseline,
            connectionsBaseline: connectionsBaseline
        )
    }

    private func normalizedDeviation(current: Double, baseline: Double, floor: Double) -> Double {
        let denominator = max(baseline, floor)
        return Swift.abs(current - baseline) / denominator
    }
}

// MARK: - Aggregation Engine
@MainActor
private final class AggregationEngine {
    func aggregate(
        metrics: [PerformanceMetrics],
        events: [TelemetryEvent],
        for timeRange: TimeRange
    ) -> AggregatedMetrics {
        let cpuUsages = metrics.map { $0.cpuUsage }
        let memoryUsages = metrics.map { $0.memoryUsage }
        let networkIn = metrics.map { $0.networkIO.bytesIn }.reduce(0, +)
        let networkOut = metrics.map { $0.networkIO.bytesOut }.reduce(0, +)
        
        let errorCount = events.filter { $0.severity == .error }.count
        let warningCount = events.filter { $0.severity == .warning }.count
        
        return AggregatedMetrics(
            timeRange: timeRange,
            averageCPUUsage: cpuUsages.isEmpty ? 0 : cpuUsages.reduce(0, +) / Double(cpuUsages.count),
            peakCPUUsage: cpuUsages.max() ?? 0,
            averageMemoryUsage: memoryUsages.isEmpty ? 0 : memoryUsages.reduce(0, +) / UInt64(memoryUsages.count),
            peakMemoryUsage: memoryUsages.max() ?? 0,
            totalNetworkIn: networkIn,
            totalNetworkOut: networkOut,
            eventCount: events.count,
            errorCount: errorCount,
            warningCount: warningCount
        )
    }
}
