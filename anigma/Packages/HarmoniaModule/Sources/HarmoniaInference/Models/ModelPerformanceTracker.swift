//
//  ModelPerformanceTracker.swift
//  HarmoniaModule
//
//  Performance metrics and regression detection for ML models.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import InferenceCore
import AnigmaPrimitives
import DatabaseCore
@preconcurrency import Foundation

/// Performance metrics for a model
public struct ModelPerformanceMetrics: Sendable, Codable {
    public let modelId: String
    public let modelName: String
    public let timestamp: Date
    public let inferenceLatencyMs: InferenceLatencyMetrics
    public let throughputTokensPerSec: ThroughputMetrics
    public let memoryUsageMB: MemoryMetrics
    public let accuracyMetrics: AccuracyMetrics
    public let errorRate: Double  // 0-1
    public let cachedResponses: Int
    public let totalInferences: Int

    public init(
        modelId: String,
        modelName: String,
        timestamp: Date,
        inferenceLatencyMs: InferenceLatencyMetrics,
        throughputTokensPerSec: ThroughputMetrics,
        memoryUsageMB: MemoryMetrics,
        accuracyMetrics: AccuracyMetrics,
        errorRate: Double,
        cachedResponses: Int,
        totalInferences: Int
    ) {
        self.modelId = modelId
        self.modelName = modelName
        self.timestamp = timestamp
        self.inferenceLatencyMs = inferenceLatencyMs
        self.throughputTokensPerSec = throughputTokensPerSec
        self.memoryUsageMB = memoryUsageMB
        self.accuracyMetrics = accuracyMetrics
        self.errorRate = errorRate
        self.cachedResponses = cachedResponses
        self.totalInferences = totalInferences
    }
}

/// Latency percentile metrics
public struct InferenceLatencyMetrics: Sendable, Codable {
    public let p50: Double  // Median
    public let p95: Double  // 95th percentile
    public let p99: Double  // 99th percentile
    public let min: Double
    public let max: Double
    public let mean: Double

    public init(p50: Double, p95: Double, p99: Double, min: Double, max: Double, mean: Double) {
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
        self.min = min
        self.max = max
        self.mean = mean
    }
}

/// Throughput metrics
public struct ThroughputMetrics: Sendable, Codable {
    public let p50: Double
    public let p95: Double
    public let p99: Double
    public let min: Double
    public let max: Double
    public let mean: Double

    public init(p50: Double, p95: Double, p99: Double, min: Double, max: Double, mean: Double) {
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
        self.min = min
        self.max = max
        self.mean = mean
    }
}

/// Memory usage metrics
public struct MemoryMetrics: Sendable, Codable {
    public let peakUsage: Double
    public let averageUsage: Double
    public let minUsage: Double
    public let maxUsage: Double

    public init(peakUsage: Double, averageUsage: Double, minUsage: Double, maxUsage: Double) {
        self.peakUsage = peakUsage
        self.averageUsage = averageUsage
        self.minUsage = minUsage
        self.maxUsage = maxUsage
    }
}

/// Accuracy-related metrics
public struct AccuracyMetrics: Sendable, Codable {
    public let quality: Double  // 0-1 estimated quality score
    public let relevanceScore: Double  // 0-1
    public let coherenceScore: Double  // 0-1
    public let completenessScore: Double  // 0-1

    public init(quality: Double, relevanceScore: Double, coherenceScore: Double, completenessScore: Double) {
        self.quality = quality
        self.relevanceScore = relevanceScore
        self.coherenceScore = coherenceScore
        self.completenessScore = completenessScore
    }
}

/// Performance regression detection
public struct PerformanceRegression: Sendable, Codable {
    public let regressionId: String
    public let modelId: String
    public let metric: String  // latency, throughput, accuracy, memory
    public let previousValue: Double
    public let currentValue: Double
    public let percentChange: Double
    public let severity: String  // low, medium, high, critical
    public let timestamp: Date
    public let recommendation: String

    public init(
        regressionId: String,
        modelId: String,
        metric: String,
        previousValue: Double,
        currentValue: Double,
        percentChange: Double,
        severity: String,
        timestamp: Date,
        recommendation: String
    ) {
        self.regressionId = regressionId
        self.modelId = modelId
        self.metric = metric
        self.previousValue = previousValue
        self.currentValue = currentValue
        self.percentChange = percentChange
        self.severity = severity
        self.timestamp = timestamp
        self.recommendation = recommendation
    }
}

/// Performance trend over time
public struct PerformanceTrend: Sendable, Codable {
    public let trendId: String
    public let modelId: String
    public let metric: String
    public let measurements: [PerformanceMeasurement]
    public let trend: String  // improving, degrading, stable
    public let trendStrength: Double  // 0-1

    public init(
        trendId: String,
        modelId: String,
        metric: String,
        measurements: [PerformanceMeasurement],
        trend: String,
        trendStrength: Double
    ) {
        self.trendId = trendId
        self.modelId = modelId
        self.metric = metric
        self.measurements = measurements
        self.trend = trend
        self.trendStrength = trendStrength
    }
}

/// Single performance measurement
public struct PerformanceMeasurement: Sendable, Codable {
    public let timestamp: Date
    public let value: Double
    public let context: String?

    public init(timestamp: Date, value: Double, context: String? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.context = context
    }
}

/// Actor for tracking model performance
public actor ModelPerformanceTracker {
    private let dbActor: (any DatabaseAuthority)?
    private var performanceHistory: [String: [PerformanceMeasurement]] = [:]
    private var regressions: [PerformanceRegression] = []
    private let maxHistorySize = 10000

    public init(dbActor: (any DatabaseAuthority)? = nil) {
        self.dbActor = dbActor
    }

    /// Record a performance measurement
    public func recordMeasurement(
        modelId: String,
        metric: String,
        value: Double,
        context: String? = nil
    ) async throws {
        let key = "\(modelId):\(metric)"
        var measurements = performanceHistory[key] ?? []

        measurements.append(PerformanceMeasurement(
            timestamp: Date(),
            value: value,
            context: context
        ))

        // Trim history if too large
        if measurements.count > maxHistorySize {
            measurements = Array(measurements.suffix(maxHistorySize / 2))
        }

        performanceHistory[key] = measurements
    }

    /// Get performance metrics for a model
    public func getMetrics(modelId: String, lastN: Int = 100) -> ModelPerformanceMetrics {
        let latencyMeasurements = getMeasurements(modelId: modelId, metric: "latency", lastN: lastN)
        let throughputMeasurements = getMeasurements(modelId: modelId, metric: "throughput", lastN: lastN)
        let memoryMeasurements = getMeasurements(modelId: modelId, metric: "memory", lastN: lastN)
        let accuracyMeasurements = getMeasurements(modelId: modelId, metric: "accuracy", lastN: lastN)

        let latencyPercentiles = computePercentiles(values: latencyMeasurements)
        let throughputPercentiles = computePercentiles(values: throughputMeasurements)
        let latencyMetrics: InferenceLatencyMetrics = latencyPercentiles
        let throughputMetrics = ThroughputMetrics(

            p50: throughputPercentiles.p50,
            p95: throughputPercentiles.p95,
            p99: throughputPercentiles.p99,
            min: throughputPercentiles.min,
            max: throughputPercentiles.max,
            mean: throughputPercentiles.mean
        )
        let memoryStats = computeMemoryStats(values: memoryMeasurements)
        let accuracyScores = computeAccuracyScores(values: accuracyMeasurements)

        let errorCount = performanceHistory["\(modelId):errors"]?.count ?? 0
        let totalInferences = latencyMeasurements.count
        let cachedResponses = performanceHistory["\(modelId):cached"]?.count ?? 0

        return ModelPerformanceMetrics(
            modelId: modelId,
            modelName: modelId,  // Could be enhanced with name lookup
            timestamp: Date(),
            inferenceLatencyMs: latencyMetrics,
            throughputTokensPerSec: throughputMetrics,
            memoryUsageMB: memoryStats,
            accuracyMetrics: accuracyScores,
            errorRate: totalInferences > 0 ? Double(errorCount) / Double(totalInferences) : 0,
            cachedResponses: cachedResponses,
            totalInferences: totalInferences
        )
    }

    /// Detect performance regressions
    public func detectRegressions(
        modelId: String,
        threshold: Double = 0.15  // 15% change threshold
    ) -> [PerformanceRegression] {
        var detectedRegressions: [PerformanceRegression] = []

        for metric in ["latency", "throughput", "memory", "accuracy"] {
            let measurements = getMeasurements(modelId: modelId, metric: metric, lastN: 200)

            if measurements.count < 50 {
                continue  // Need baseline
            }

            let baselineEndIndex = measurements.count / 2
            let baselineValues = Array(measurements.prefix(baselineEndIndex))
            let recentValues = Array(measurements.suffix(measurements.count - baselineEndIndex))

            let baselineMean = baselineValues.reduce(0, +) / Double(baselineValues.count)
            let recentMean = recentValues.reduce(0, +) / Double(recentValues.count)

            let percentChange = Swift.abs((recentMean - baselineMean) / baselineMean)

            if percentChange > threshold {
                let isRegression = (metric == "latency" || metric == "memory") ? recentMean > baselineMean : recentMean < baselineMean

                if isRegression {
                    let severity = determineSeverity(metric: metric, percentChange: percentChange)
                    let recommendation = generateRegressionRecommendation(metric: metric, severity: severity)

                    detectedRegressions.append(PerformanceRegression(
                        regressionId: UUID().uuidString,
                        modelId: modelId,
                        metric: metric,
                        previousValue: baselineMean,
                        currentValue: recentMean,
                        percentChange: percentChange,
                        severity: severity,
                        timestamp: Date(),
                        recommendation: recommendation
                    ))
                }
            }
        }

        self.regressions = detectedRegressions
        return detectedRegressions
    }

    /// Get performance trend
    public func getTrend(modelId: String, metric: String, window: Int = 100) -> PerformanceTrend {
        let key = "\(modelId):\(metric)"
        let storedMeasurements = performanceHistory[key] ?? []
        let measurements = Array(storedMeasurements.suffix(window))

        let trend = analyzeTrend(measurements: measurements)
        let strength = calculateTrendStrength(measurements: measurements)

        return PerformanceTrend(
            trendId: UUID().uuidString,
            modelId: modelId,
            metric: metric,
            measurements: measurements,
            trend: trend,
            trendStrength: strength
        )
    }

    /// Compare two models
    public func compareModels(modelId1: String, modelId2: String) -> ModelComparison {
        let metrics1 = getMetrics(modelId: modelId1)
        let metrics2 = getMetrics(modelId: modelId2)

        let latencyDiff = ((metrics2.inferenceLatencyMs.mean - metrics1.inferenceLatencyMs.mean) / metrics1.inferenceLatencyMs.mean) * 100
        let throughputDiff = ((metrics2.throughputTokensPerSec.mean - metrics1.throughputTokensPerSec.mean) / metrics1.throughputTokensPerSec.mean) * 100
        let memoryDiff = ((metrics2.memoryUsageMB.averageUsage - metrics1.memoryUsageMB.averageUsage) / metrics1.memoryUsageMB.averageUsage) * 100
        let accuracyDiff = metrics2.accuracyMetrics.quality - metrics1.accuracyMetrics.quality

        return ModelComparison(
            comparisonId: UUID().uuidString,
            model1Id: modelId1,
            model2Id: modelId2,
            latencyDifference: latencyDiff,
            throughputDifference: throughputDiff,
            memoryDifference: memoryDiff,
            accuracyDifference: accuracyDiff,
            recommendation: recommendBetter(latencyDiff: latencyDiff, accuracyDiff: accuracyDiff)
        )
    }

    // MARK: - Private Helpers

    private func getMeasurements(modelId: String, metric: String, lastN: Int) -> [Double] {
        let key = "\(modelId):\(metric)"
        let measurements = performanceHistory[key] ?? []
        return measurements.suffix(lastN).map { $0.value }
    }

    private func computePercentiles(values: [Double]) -> InferenceLatencyMetrics {
        guard !values.isEmpty else {
            return InferenceLatencyMetrics(p50: 0, p95: 0, p99: 0, min: 0, max: 0, mean: 0)
        }

        let sorted = values.sorted()
        let mean = values.reduce(0, +) / Double(values.count)

        let p50Value = sorted[Int(Double(sorted.count) * 0.5)]
        let p95Value = sorted[Int(Double(sorted.count) * 0.95)]
        let p99Value = sorted[Int(Double(sorted.count) * 0.99)]

        return InferenceLatencyMetrics(
            p50: p50Value,
            p95: p95Value,
            p99: p99Value,
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            mean: mean
        )
    }

    private func computeMemoryStats(values: [Double]) -> MemoryMetrics {
        guard !values.isEmpty else {
            return MemoryMetrics(peakUsage: 0, averageUsage: 0, minUsage: 0, maxUsage: 0)
        }

        let average = values.reduce(0, +) / Double(values.count)

        return MemoryMetrics(
            peakUsage: values.max() ?? 0,
            averageUsage: average,
            minUsage: values.min() ?? 0,
            maxUsage: values.max() ?? 0
        )
    }

    private func computeAccuracyScores(values: [Double]) -> AccuracyMetrics {
        guard !values.isEmpty else {
            return AccuracyMetrics(quality: 0, relevanceScore: 0, coherenceScore: 0, completenessScore: 0)
        }

        let meanQuality = values.reduce(0, +) / Double(values.count)

        return AccuracyMetrics(
            quality: meanQuality,
            relevanceScore: meanQuality * 0.95,  // Heuristic
            coherenceScore: meanQuality * 0.92,
            completenessScore: meanQuality * 0.88
        )
    }

    private func determineSeverity(metric: String, percentChange: Double) -> String {
        if percentChange > 0.5 {
            return "critical"
        } else if percentChange > 0.3 {
            return "high"
        } else if percentChange > 0.2 {
            return "medium"
        } else {
            return "low"
        }
    }

    private func generateRegressionRecommendation(metric: String, severity: String) -> String {
        switch (metric, severity) {
        case ("latency", "critical"):
            return "Critical latency increase - investigate model optimization, consider model quantization or caching"
        case ("latency", _):
            return "Latency degraded - profile inference pipeline and review input preprocessing"
        case ("memory", "critical"):
            return "Critical memory increase - reduce batch size or implement memory-efficient attention"
        case ("memory", _):
            return "Memory usage increased - review parameter count and consider pruning"
        case ("throughput", "critical"):
            return "Critical throughput decrease - verify GPU/hardware availability and check for bottlenecks"
        case ("accuracy", _):
            return "Accuracy decreased - verify training data quality and model convergence"
        default:
            return "Performance degradation detected - review recent model updates"
        }
    }

    private func analyzeTrend(measurements: [PerformanceMeasurement]) -> String {
        guard measurements.count >= 10 else { return "insufficient_data" }

        let mid = measurements.count / 2
        let firstHalf = measurements.prefix(mid).map { $0.value }
        let secondHalf = measurements.suffix(measurements.count - mid).map { $0.value }

        let firstMean = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondMean = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let change = (secondMean - firstMean) / firstMean

        if Swift.abs(change) < 0.05 {
            return "stable"
        } else if change > 0 {
            return "degrading"
        } else {
            return "improving"
        }
    }

    private func calculateTrendStrength(measurements: [PerformanceMeasurement]) -> Double {
        guard measurements.count >= 2 else { return 0 }

        let values = measurements.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        let stdDev = sqrt(variance)

        // Trend strength based on consistency
        return min(1.0, 1.0 - (stdDev / (mean + 0.001)))
    }

    private func recommendBetter(latencyDiff: Double, accuracyDiff: Double) -> String {
        if accuracyDiff > 0.05 && latencyDiff < 20 {
            return "Model 2 recommended - better accuracy with acceptable latency"
        } else if latencyDiff < -20 && accuracyDiff > -0.05 {
            return "Model 2 recommended - faster with similar accuracy"
        } else if accuracyDiff < -0.05 {
            return "Model 1 recommended - higher accuracy outweighs performance"
        } else if latencyDiff > 20 {
            return "Model 1 recommended - better latency is critical"
        } else {
            return "Models are comparable - choose based on resource constraints"
        }
    }
}

/// Model comparison result
public struct ModelComparison: Sendable, Codable {
    public let comparisonId: String
    public let model1Id: String
    public let model2Id: String
    public let latencyDifference: Double  // Percentage
    public let throughputDifference: Double  // Percentage
    public let memoryDifference: Double  // Percentage
    public let accuracyDifference: Double  // Absolute
    public let recommendation: String

    public init(
        comparisonId: String,
        model1Id: String,
        model2Id: String,
        latencyDifference: Double,
        throughputDifference: Double,
        memoryDifference: Double,
        accuracyDifference: Double,
        recommendation: String
    ) {
        self.comparisonId = comparisonId
        self.model1Id = model1Id
        self.model2Id = model2Id
        self.latencyDifference = latencyDifference
        self.throughputDifference = throughputDifference
        self.memoryDifference = memoryDifference
        self.accuracyDifference = accuracyDifference
        self.recommendation = recommendation
    }
}
