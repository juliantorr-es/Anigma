/// RegressionGuardrails.swift
/// Performance guardrails for capsule boundaries, batch efficiency, and cross-language calls
/// 
/// Tracks:
/// - Capsule allocation counts (delta detection)
/// - Batch operation efficiency (individual vs batch)
/// - Cross-language call volume (FFI/interop transitions)
/// 
/// Design: Lightweight, reproducible checks with configurable thresholds

import Foundation
import CapsuleCore
import AnigmaPrimitives

// MARK: - Guardrail Types

/// Performance guardrail categories
public enum GuardrailCategory: String, Sendable {
    case capsuleAllocation = "capsule.allocation"
    case batchEfficiency = "batch.efficiency"
    case crossLanguageCallVolume = "cross_lang.calls"
    case hotPathFusion = "hot_path.fusion"
}

/// Regression detection severity
public enum RegressionSeverity: String, Sendable {
    case warning = "warning"
    case failure = "failure"
}

/// Performance measurement result
public struct PerformanceMeasurement: Sendable {
    public let category: GuardrailCategory
    public let operationName: String
    public let metricName: String
    public let value: Double
    public let unit: String
    public let timestamp: Date
    public let tags: [String: String]
    
    public init(
        category: GuardrailCategory,
        operationName: String,
        metricName: String,
        value: Double,
        unit: String,
        tags: [String: String] = [:]
    ) {
        self.category = category
        self.operationName = operationName
        self.metricName = metricName
        self.value = value
        self.unit = unit
        self.timestamp = Date()
        self.tags = tags
    }
}

/// Regression detection result
public struct RegressionResult: Sendable {
    public let category: GuardrailCategory
    public let operationName: String
    public let metricName: String
    public let currentValue: Double
    public let baselineValue: Double?
    public let threshold: Double
    public let unit: String
    public let severity: RegressionSeverity
    public let message: String
    public let delta: Double?
    
    public var isRegression: Bool {
        guard let baseline = baselineValue else { return false }
        let delta = Swift.abs(currentValue - baseline) / Swift.max(baseline, 1.0)
        return delta > (threshold / 100.0)
    }
}

/// Guardrail configuration
public struct GuardrailConfiguration: Sendable, Equatable {
    // Capsule allocation guardrails
    public let capsuleAllocationThreshold: Double  // % deviation allowed
    public let maxCapsuleAllocationsPerOperation: Int
    
    // Batch efficiency guardrails
    public let batchEfficiencyThreshold: Double  // Minimum speedup ratio
    public let minBatchSize: Int  // Below this, batching may not be optimal
    
    // Cross-language call volume guardrails
    public let crossLanguageCallThreshold: Int  // Max calls per operation
    public let callFrequencyThreshold: Double  // Calls per millisecond
    
    // Hot path fusion guardrails
    public let maxIntermediateAllocationsPerFusion: Int
    public let hotPathThreshold: Double  // Time in ms to consider "hot"
    
    public static let `default` = GuardrailConfiguration(
        capsuleAllocationThreshold: 15.0,  // Allow 15% deviation
        maxCapsuleAllocationsPerOperation: 3,
        batchEfficiencyThreshold: 1.2,  // Batch should be at least 1.2x faster
        minBatchSize: 10,
        crossLanguageCallThreshold: 5,
        callFrequencyThreshold: 0.1,  // 0.1 calls per ms
        maxIntermediateAllocationsPerFusion: 2,
        hotPathThreshold: 5.0
    )
    
    public static let strict = GuardrailConfiguration(
        capsuleAllocationThreshold: 5.0,
        maxCapsuleAllocationsPerOperation: 1,
        batchEfficiencyThreshold: 1.5,
        minBatchSize: 5,
        crossLanguageCallThreshold: 2,
        callFrequencyThreshold: 0.05,
        maxIntermediateAllocationsPerFusion: 1,
        hotPathThreshold: 2.0
    )
    
    public static let relaxed = GuardrailConfiguration(
        capsuleAllocationThreshold: 30.0,
        maxCapsuleAllocationsPerOperation: 5,
        batchEfficiencyThreshold: 1.0,  // No minimum speedup
        minBatchSize: 50,
        crossLanguageCallThreshold: 20,
        callFrequencyThreshold: 0.5,
        maxIntermediateAllocationsPerFusion: 5,
        hotPathThreshold: 10.0
    )
}

// MARK: - Capsule Allocation Tracker

/// Tracks memory allocations within capsule operations
public actor CapsuleAllocationTracker: Sendable {
    private var allocationRecords: [String: AllocationRecord] = [:]
    private let diagnostics: CapsuleDiagnostics?
    
    private struct AllocationRecord: Sendable {
        let operationName: String
        var allocationCount: Int
        var peakMemory: UInt64
        var timestamp: Date
        var callCounts: [String: Int]  // cross-language call tracking
    }
    
    public init(diagnostics: CapsuleDiagnostics? = nil) {
        self.diagnostics = diagnostics
    }
    
    /// Record an allocation for an operation
    /// - Parameters:
    ///   - operationName: Name of the operation
    ///   - size: Size allocated in bytes
    public func recordAllocation(operationName: String, size: UInt64) {
        var record = allocationRecords[operationName] ?? AllocationRecord(
            operationName: operationName,
            allocationCount: 0,
            peakMemory: 0,
            timestamp: Date(),
            callCounts: [:]
        )
        
        record.allocationCount += 1
        record.peakMemory = max(record.peakMemory, size)
        allocationRecords[operationName] = record
    }
    
    /// Record a cross-language call
    /// - Parameters:
    ///   - operationName: Name of the operation
    ///   - callType: Type of cross-language call (e.g., "swift_to_c", "objc_to_swift")
    public func recordCrossLanguageCall(operationName: String, callType: String) {
        var record = allocationRecords[operationName] ?? AllocationRecord(
            operationName: operationName,
            allocationCount: 0,
            peakMemory: 0,
            timestamp: Date(),
            callCounts: [:]
        )
        
        record.callCounts[callType, default: 0] += 1
        allocationRecords[operationName] = record
    }
    
    /// Get allocation statistics for an operation
    /// - Parameters:
    ///   - operationName: Name of the operation
    /// - Returns: Tuple of (allocationCount, peakMemory, callCounts)
    public func getAllocationStats(for operationName: String) -> (count: Int, peakMemory: UInt64, calls: [String: Int]) {
        guard let record = allocationRecords[operationName] else {
            return (0, 0, [:])
        }
        return (record.allocationCount, record.peakMemory, record.callCounts)
    }
    
    /// Clear records for an operation
    public func clearRecords(for operationName: String) {
        allocationRecords.removeValue(forKey: operationName)
    }
    
    /// Clear all records
    public func clearAllRecords() {
        allocationRecords.removeAll()
    }
    
    /// Get all records
    public func getAllRecords() -> [String: (count: Int, peakMemory: UInt64, calls: [String: Int])] {
        var result: [String: (count: Int, peakMemory: UInt64, calls: [String: Int])] = [:]
        for (key, record) in allocationRecords {
            result[key] = (record.allocationCount, record.peakMemory, record.callCounts)
        }
        return result
    }
}

// MARK: - Batch Efficiency Checker

/// Monitors batch operation efficiency
public struct BatchEfficiencyResult: Sendable {
    public let operationName: String
    public let individualTime: Double
    public let batchTime: Double
    public let itemCount: Int
    public let speedup: Double
    public let isEfficient: Bool
    
    public init(
        operationName: String,
        individualTime: Double,
        batchTime: Double,
        itemCount: Int,
        threshold: Double = 1.2
    ) {
        self.operationName = operationName
        self.individualTime = individualTime
        self.batchTime = batchTime
        self.itemCount = itemCount
        self.speedup = batchTime > 0 ? individualTime / batchTime : 0
        self.isEfficient = self.speedup >= threshold
    }
    
    public var description: String {
        let speedupStr = String(format: "%.2f", speedup)
        let efficientStr = isEfficient ? "✓" : "✗"
        return "\(operationName) [\(itemCount) items]: \(speedupStr)x speedup \(efficientStr)"
    }
}

public actor BatchEfficiencyMonitor: Sendable {
    private var measurements: [String: [BatchEfficiencyResult]] = [:]
    private let configuration: GuardrailConfiguration
    
    public init(configuration: GuardrailConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Record a batch efficiency measurement
    public func recordMeasurement(_ result: BatchEfficiencyResult) {
        if measurements[result.operationName] == nil {
            measurements[result.operationName] = []
        }
        measurements[result.operationName]?.append(result)
    }
    
    /// Check if a batch operation meets efficiency requirements
    public func checkEfficiency(for operationName: String) -> RegressionResult? {
        guard let results = measurements[operationName], !results.isEmpty else {
            return nil
        }
        
        let avgSpeedup = results.map(\.speedup).reduce(0, +) / Double(results.count)
        let isRegression = avgSpeedup < configuration.batchEfficiencyThreshold
        
        if isRegression {
            return RegressionResult(
                category: .batchEfficiency,
                operationName: operationName,
                metricName: "batch_speedup",
                currentValue: avgSpeedup,
                baselineValue: configuration.batchEfficiencyThreshold,
                threshold: 10.0,  // Failure if < 90% of threshold
                unit: "x",
                severity: .warning,
                message: "Batch operation '\(operationName)' speedup \(String(format: "%.2f", avgSpeedup))x below threshold \(String(format: "%.2f", configuration.batchEfficiencyThreshold))x",
                delta: ((configuration.batchEfficiencyThreshold - avgSpeedup) / configuration.batchEfficiencyThreshold) * 100
            )
        }
        
        return nil
    }
    
    /// Get all measurements for an operation
    public func getMeasurements(for operationName: String) -> [BatchEfficiencyResult]? {
        measurements[operationName]
    }
    
    /// Clear measurements
    public func clearMeasurements() {
        measurements.removeAll()
    }
}

// MARK: - Cross-Language Call Volume Checker

/// Monitors FFI and cross-language call patterns
public struct CrossLanguageCallMetrics: Sendable {
    public let operationName: String
    public let callTypes: [String: Int]  // e.g., ["swift_to_c": 5, "objc_to_swift": 2]
    public let totalCalls: Int
    public let durationMs: Double
    public let callFrequency: Double  // calls per millisecond
    
    public init(
        operationName: String,
        callTypes: [String: Int],
        durationMs: Double
    ) {
        self.operationName = operationName
        self.callTypes = callTypes
        self.totalCalls = callTypes.values.reduce(0, +)
        self.durationMs = durationMs > 0 ? durationMs : 1.0
        self.callFrequency = Double(self.totalCalls) / self.durationMs
    }
    
    public var description: String {
        let breakdown = callTypes.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        return "\(operationName): \(totalCalls) calls (\(String(format: "%.3f", callFrequency)) calls/ms) [\(breakdown)]"
    }
}

public actor CrossLanguageCallMonitor: Sendable {
    private var callMetrics: [String: [CrossLanguageCallMetrics]] = [:]
    private let configuration: GuardrailConfiguration
    
    public init(configuration: GuardrailConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Record cross-language call metrics
    public func recordMetrics(_ metrics: CrossLanguageCallMetrics) {
        if callMetrics[metrics.operationName] == nil {
            callMetrics[metrics.operationName] = []
        }
        callMetrics[metrics.operationName]?.append(metrics)
    }
    
    /// Check call volume against guardrails
    public func checkCallVolume(for operationName: String) -> [RegressionResult] {
        guard let metrics = callMetrics[operationName], !metrics.isEmpty else {
            return []
        }
        
        var regressions: [RegressionResult] = []
        
        for metric in metrics {
            // Check total call count
            if metric.totalCalls > configuration.crossLanguageCallThreshold {
                regressions.append(RegressionResult(
                    category: .crossLanguageCallVolume,
                    operationName: operationName,
                    metricName: "total_calls",
                    currentValue: Double(metric.totalCalls),
                    baselineValue: Double(configuration.crossLanguageCallThreshold),
                    threshold: 10.0,
                    unit: "calls",
                    severity: .warning,
                    message: "Operation '\(operationName)' exceeds cross-language call threshold: \(metric.totalCalls) > \(configuration.crossLanguageCallThreshold)",
                    delta: Double(metric.totalCalls - configuration.crossLanguageCallThreshold)
                ))
            }
            
            // Check call frequency
            if metric.callFrequency > configuration.callFrequencyThreshold {
                regressions.append(RegressionResult(
                    category: .crossLanguageCallVolume,
                    operationName: operationName,
                    metricName: "call_frequency",
                    currentValue: metric.callFrequency,
                    baselineValue: configuration.callFrequencyThreshold,
                    threshold: 10.0,
                    unit: "calls/ms",
                    severity: .warning,
                    message: "Operation '\(operationName)' has high call frequency: \(String(format: "%.3f", metric.callFrequency)) calls/ms",
                    delta: ((metric.callFrequency - configuration.callFrequencyThreshold) / configuration.callFrequencyThreshold) * 100
                ))
            }
        }
        
        return regressions
    }
    
    /// Get metrics for an operation
    public func getMetrics(for operationName: String) -> [CrossLanguageCallMetrics]? {
        callMetrics[operationName]
    }
    
    /// Clear metrics
    public func clearMetrics() {
        callMetrics.removeAll()
    }
}

// MARK: - Main Regression Guardrails Manager

/// Central manager for all performance guardrails
public actor RegressionGuardrails: Sendable {
    private let configuration: GuardrailConfiguration
    private let allocationTracker: CapsuleAllocationTracker
    private let batchEfficiencyMonitor: BatchEfficiencyMonitor
    private let crossLanguageCallMonitor: CrossLanguageCallMonitor
    private var baselineValues: [String: Double] = [:]
    private let diagnostics: CapsuleDiagnostics?
    
    public init(
        configuration: GuardrailConfiguration = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) {
        self.configuration = configuration
        self.diagnostics = diagnostics
        self.allocationTracker = CapsuleAllocationTracker(diagnostics: diagnostics)
        self.batchEfficiencyMonitor = BatchEfficiencyMonitor(configuration: configuration)
        self.crossLanguageCallMonitor = CrossLanguageCallMonitor(configuration: configuration)
    }
    
    // MARK: - Capsule Allocation Guardrails
    
    /// Record capsule allocation
    public func recordCapsuleAllocation(
        operationName: String,
        size: UInt64
    ) {
        Task {
            await allocationTracker.recordAllocation(operationName: operationName, size: size)
        }
    }
    
    /// Record cross-language call
    public func recordCrossLanguageCall(
        operationName: String,
        callType: String
    ) {
        Task {
            await allocationTracker.recordCrossLanguageCall(operationName: operationName, callType: callType)
        }
    }
    
    /// Check capsule allocation against guardrails
    /// NOTE: ASYNC LIMITATION - This method creates a Task but cannot await it synchronously.
    /// Callers must use checkCapsuleAllocationsAsync for proper async handling.
    /// This returns nil as a stub due to actor/async context constraints.
    public func checkCapsuleAllocations(for operationName: String) -> RegressionResult? {
        // TRACKED STUB: Unable to await actor method from synchronous context.
        // Use checkCapsuleAllocationsAsync instead for proper async handling.
        diagnostics?.event(
            level: .warning,
            category: "performance.guardrails",
            message: "checkCapsuleAllocations called with async limitation - returning nil stub. " +
            "Use checkCapsuleAllocationsAsync for real allocation tracking.",
            correlationID: nil,
            metadata: ["stub": "allocation-check", "operation": operationName]
        )
        return nil
    }
    
    /// Async version of capsule allocation check (proper implementation)
    public func checkCapsuleAllocationsAsync(for operationName: String) async -> RegressionResult? {
        let stats = await allocationTracker.getAllocationStats(for: operationName)
        
        guard stats.count > 0 else {
            return nil
        }
        
        if stats.count > configuration.maxCapsuleAllocationsPerOperation {
            return RegressionResult(
                category: .capsuleAllocation,
                operationName: operationName,
                metricName: "allocation_count",
                currentValue: Double(stats.count),
                baselineValue: Double(configuration.maxCapsuleAllocationsPerOperation),
                threshold: 10.0,
                unit: "allocations",
                severity: .warning,
                message: "Operation '\(operationName)' exceeded max allocations: \(stats.count) > \(configuration.maxCapsuleAllocationsPerOperation)",
                delta: Double(stats.count - configuration.maxCapsuleAllocationsPerOperation)
            )
        }
        
        return nil
    }
    
    // MARK: - Batch Efficiency Guardrails
    
    /// Record batch efficiency measurement
    public func recordBatchEfficiency(
        operationName: String,
        individualTime: Double,
        batchTime: Double,
        itemCount: Int
    ) {
        let result = BatchEfficiencyResult(
            operationName: operationName,
            individualTime: individualTime,
            batchTime: batchTime,
            itemCount: itemCount,
            threshold: configuration.batchEfficiencyThreshold
        )
        
        Task {
            await batchEfficiencyMonitor.recordMeasurement(result)
        }
    }
    
    /// Check batch efficiency for an operation
    /// NOTE: ASYNC LIMITATION - This method creates a Task but cannot await it synchronously.
    /// Callers must use checkBatchEfficiencyAsync for proper async handling.
    /// This returns nil as a stub due to actor/async context constraints.
    public func checkBatchEfficiency(for operationName: String) -> RegressionResult? {
        // TRACKED STUB: Unable to await actor method from synchronous context.
        // Use checkBatchEfficiencyAsync instead for real batch efficiency checks.
        diagnostics?.event(
            level: .warning,
            category: "performance.guardrails",
            message: "checkBatchEfficiency called with async limitation - returning nil stub. " +
            "Use checkBatchEfficiencyAsync for real efficiency tracking.",
            correlationID: nil,
            metadata: ["stub": "batch-efficiency", "operation": operationName]
        )
        return nil
    }
    
    /// Async version of batch efficiency check (proper implementation)
    public func checkBatchEfficiencyAsync(for operationName: String) async -> RegressionResult? {
        return await batchEfficiencyMonitor.checkEfficiency(for: operationName)
    }
    
    // MARK: - Cross-Language Call Guardrails
    
    /// Record cross-language call metrics
    public func recordCrossLanguageCallMetrics(
        operationName: String,
        callTypes: [String: Int],
        durationMs: Double
    ) {
        let metrics = CrossLanguageCallMetrics(
            operationName: operationName,
            callTypes: callTypes,
            durationMs: durationMs
        )
        
        Task {
            await crossLanguageCallMonitor.recordMetrics(metrics)
        }
    }
    
    /// Check cross-language call volume
    /// NOTE: ASYNC LIMITATION - This method creates a Task but cannot await it synchronously.
    /// Callers must use checkCrossLanguageCallsAsync for proper async handling.
    /// This returns nil as a stub due to actor/async context constraints.
    public func checkCrossLanguageCalls(for operationName: String) -> [RegressionResult]? {
        // TRACKED STUB: Unable to await actor method from synchronous context.
        // Use checkCrossLanguageCallsAsync instead for real call volume tracking.
        diagnostics?.event(
            level: .warning,
            category: "performance.guardrails",
            message: "checkCrossLanguageCalls called with async limitation - returning nil stub. " +
            "Use checkCrossLanguageCallsAsync for real call monitoring.",
            correlationID: nil,
            metadata: ["stub": "cross-lang-calls", "operation": operationName]
        )
        return nil
    }
    
    /// Async version of cross-language call check (proper implementation)
    public func checkCrossLanguageCallsAsync(for operationName: String) async -> [RegressionResult] {
        return await crossLanguageCallMonitor.checkCallVolume(for: operationName)
    }
    
    // MARK: - Baseline Management
    
    /// Set baseline value for a metric
    public func setBaseline(for metricName: String, value: Double) {
        baselineValues[metricName] = value
    }
    
    /// Get baseline value
    public func getBaseline(for metricName: String) -> Double? {
        baselineValues[metricName]
    }
    
    /// Clear all baselines
    public func clearBaselines() {
        baselineValues.removeAll()
    }
    
    // MARK: - Reporting
    
    /// Generate performance report
    public func generateReport() -> String {
        var report = """
        ╔════════════════════════════════════════════════════════════╗
        ║         PERFORMANCE REGRESSION GUARDRAILS REPORT            ║
        ╚════════════════════════════════════════════════════════════╝
        
        Configuration: \(configuration == GuardrailConfiguration.strict ? "STRICT" : configuration == GuardrailConfiguration.relaxed ? "RELAXED" : "DEFAULT")
        
        """
        
        return report
    }
    
    /// Reset all tracking
    public func reset() {
        Task {
            await allocationTracker.clearAllRecords()
            await batchEfficiencyMonitor.clearMeasurements()
            await crossLanguageCallMonitor.clearMetrics()
        }
        baselineValues.removeAll()
    }
}
