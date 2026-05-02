/// ObservabilityKit aggregates metrics from TelemetryCore and provides dashboard data export
/// with SLI/SLO tracking capabilities.

import Foundation

/// Metric type enumeration
public enum MetricType {
    case counter(name: String)
    case gauge(name: String)
    case histogram(name: String, buckets: [Double])
}

/// SLI (Service Level Indicator) definition
public struct SLI {
    public let name: String
    public let description: String
    public let threshold: Double
    
    public init(name: String, description: String, threshold: Double) {
        self.name = name
        self.description = description
        self.threshold = threshold
    }
}

/// SLO (Service Level Objective) definition
public struct SLO {
    public let name: String
    public let sli: SLI
    public let targetPercentile: Double
    
    public init(name: String, sli: SLI, targetPercentile: Double) {
        self.name = name
        self.sli = sli
        self.targetPercentile = targetPercentile
    }
}

/// Metric measurement
public struct Measurement {
    public let timestamp: Date
    public let value: Double
    public let labels: [String: String]
    
    public init(timestamp: Date = Date(), value: Double, labels: [String: String] = [:]) {
        self.timestamp = timestamp
        self.value = value
        self.labels = labels
    }
}

/// Metrics aggregator
public actor MetricsAggregator {
    private var measurements: [String: [Measurement]] = [:]
    private var sliDefinitions: [SLI] = []
    private var sloDefinitions: [SLO] = []
    
    public init() {}
    
    /// Record a measurement
    public func recordMeasurement(name: String, value: Double, labels: [String: String] = [:]) {
        let measurement = Measurement(value: value, labels: labels)
        if measurements[name] == nil {
            measurements[name] = []
        }
        measurements[name]?.append(measurement)
    }
    
    /// Register an SLI
    public func registerSLI(_ sli: SLI) {
        sliDefinitions.append(sli)
    }
    
    /// Register an SLO
    public func registerSLO(_ slo: SLO) {
        sloDefinitions.append(slo)
    }
    
    /// Calculate average for a metric
    public func calculateAverage(for metricName: String) -> Double? {
        guard let measurements = measurements[metricName], !measurements.isEmpty else {
            return nil
        }
        let sum = measurements.reduce(0.0) { $0 + $1.value }
        return sum / Double(measurements.count)
    }
    
    /// Calculate percentile for a metric
    public func calculatePercentile(for metricName: String, percentile: Double) -> Double? {
        guard let measurements = measurements[metricName], !measurements.isEmpty else {
            return nil
        }
        let sorted = measurements.sorted { $0.value < $1.value }
        let index = Int(Double(sorted.count - 1) * percentile / 100.0)
        return sorted[index].value
    }
    
    /// Check if SLO is met
    public func isSLOMet(_ slo: SLO) -> Bool {
        guard let percentileValue = calculatePercentile(for: slo.sli.name, percentile: slo.targetPercentile) else {
            return false
        }
        return percentileValue <= slo.sli.threshold
    }
    
    /// Export metrics as JSON
    public func exportAsJSON() -> [String: Any] {
        var result: [String: Any] = [:]
        result["timestamp"] = ISO8601DateFormatter().string(from: Date())
        result["metrics"] = measurements.mapValues { measurements in
            measurements.map { m in
                [
                    "timestamp": ISO8601DateFormatter().string(from: m.timestamp),
                    "value": m.value,
                    "labels": m.labels
                ]
            }
        }
        result["slis"] = sliDefinitions.map { sli in
            [
                "name": sli.name,
                "description": sli.description,
                "threshold": sli.threshold
            ]
        }
        return result
    }
    
    /// Export metrics for dashboard
    public func exportForDashboard() -> DashboardData {
        return DashboardData(
            timestamp: Date(),
            metrics: measurements,
            sliStatus: calculateSLIStatus(),
            sloStatus: calculateSLOStatus()
        )
    }
    
    private func calculateSLIStatus() -> [String: Double] {
        var status: [String: Double] = [:]
        for sli in sliDefinitions {
            if let avg = calculateAverage(for: sli.name) {
                status[sli.name] = avg
            }
        }
        return status
    }
    
    private func calculateSLOStatus() -> [String: Bool] {
        var status: [String: Bool] = [:]
        for slo in sloDefinitions {
            status[slo.name] = isSLOMet(slo)
        }
        return status
    }
}

/// Dashboard data structure
public struct DashboardData {
    public let timestamp: Date
    public let metrics: [String: [Measurement]]
    public let sliStatus: [String: Double]
    public let sloStatus: [String: Bool]
    
    public init(
        timestamp: Date,
        metrics: [String: [Measurement]],
        sliStatus: [String: Double],
        sloStatus: [String: Bool]
    ) {
        self.timestamp = timestamp
        self.metrics = metrics
        self.sliStatus = sliStatus
        self.sloStatus = sloStatus
    }
}
