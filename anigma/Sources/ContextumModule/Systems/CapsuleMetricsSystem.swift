import Foundation

public struct CapsuleMetrics: Codable, Sendable, Equatable {
    public var capsuleName: String
    public var operationCount: Int64
    public var successCount: Int64
    public var fallbackCount: Int64
    public var averageLatencyMs: Double
    public var totalBytesProcessed: Int64
    public var simdAccelerationCount: Int64
    public var lastUsed: Date
    public var errorRate: Double

    public init(
        capsuleName: String,
        operationCount: Int64 = 0,
        successCount: Int64 = 0,
        fallbackCount: Int64 = 0,
        averageLatencyMs: Double = 0,
        totalBytesProcessed: Int64 = 0,
        simdAccelerationCount: Int64 = 0,
        lastUsed: Date = Date(),
        errorRate: Double = 0
    ) {
        self.capsuleName = capsuleName
        self.operationCount = operationCount
        self.successCount = successCount
        self.fallbackCount = fallbackCount
        self.averageLatencyMs = averageLatencyMs
        self.totalBytesProcessed = totalBytesProcessed
        self.simdAccelerationCount = simdAccelerationCount
        self.lastUsed = lastUsed
        self.errorRate = errorRate
    }

    public var acceleratedPercentage: Double {
        guard operationCount > 0 else { return 0 }
        return Double(simdAccelerationCount) / Double(operationCount) * 100
    }

    public var successRate: Double {
        guard operationCount > 0 else { return 0 }
        return Double(successCount) / Double(operationCount) * 100
    }
}

public struct CapsuleAccelerationReport: Codable, Sendable {
    public var totalOperations: Int64
    public var capsuleAcceleratedOperations: Int64
    public var fallbackOperations: Int64
    public var overallAccelerationRate: Double
    public var totalBytesProcessed: Int64
    public var averageLatencyMs: Double
    public var simdUtilizationRate: Double
    public var topPerformingCapsules: [String]
    public var underperformingCapsules: [String]
    public var generatedAt: Date
    public var capsuleBreakdown: [String: CapsuleMetrics]

    public init(
        totalOperations: Int64,
        capsuleAcceleratedOperations: Int64,
        fallbackOperations: Int64,
        overallAccelerationRate: Double,
        totalBytesProcessed: Int64,
        averageLatencyMs: Double,
        simdUtilizationRate: Double,
        topPerformingCapsules: [String],
        underperformingCapsules: [String],
        generatedAt: Date = Date(),
        capsuleBreakdown: [String: CapsuleMetrics] = [:]
    ) {
        self.totalOperations = totalOperations
        self.capsuleAcceleratedOperations = capsuleAcceleratedOperations
        self.fallbackOperations = fallbackOperations
        self.overallAccelerationRate = overallAccelerationRate
        self.totalBytesProcessed = totalBytesProcessed
        self.averageLatencyMs = averageLatencyMs
        self.simdUtilizationRate = simdUtilizationRate
        self.topPerformingCapsules = topPerformingCapsules
        self.underperformingCapsules = underperformingCapsules
        self.generatedAt = generatedAt
        self.capsuleBreakdown = capsuleBreakdown
    }
}

public enum CapsuleType: String, CaseIterable, Sendable {
    case cosineSimilarity = "CosineSimilarityCapsule"
    case rankFusion = "RankFusionCapsule"
    case textChunking = "TextChunkingCapsule"
    case compression = "CompressionCapsule"
    case layoutEngine = "LayoutEngineCapsule"
    case mediaContainer = "MediaContainerCapsule"
    case mediaFingerprint = "MediaFingerprintCapsule"
    case vizAggregation = "VizAggregationCapsule"
    case vector = "VectorCapsule"
    case textPipeline = "TextPipelineCapsule"

    public var displayName: String {
        switch self {
        case .cosineSimilarity: return "Cosine Similarity"
        case .rankFusion: return "Rank Fusion"
        case .textChunking: return "Text Chunking"
        case .compression: return "Compression"
        case .layoutEngine: return "Layout Engine"
        case .mediaContainer: return "Media Container"
        case .mediaFingerprint: return "Media Fingerprint"
        case .vizAggregation: return "Viz Aggregation"
        case .vector: return "Vector"
        case .textPipeline: return "Text Pipeline"
        }
    }

    public var supportsSIMD: Bool {
        switch self {
        case .cosineSimilarity, .vector, .textChunking, .compression:
            return true
        default:
            return false
        }
    }
}

public struct FallbackRecord: Codable, Sendable {
    public let capsuleName: String
    public let reason: String
    public let timestamp: Date
    public let operationType: String?

    public init(capsuleName: String, reason: String, timestamp: Date = Date(), operationType: String? = nil) {
        self.capsuleName = capsuleName
        self.reason = reason
        self.timestamp = timestamp
        self.operationType = operationType
    }
}

public struct ErrorRecord: Codable, Sendable, Identifiable {
    public let id: String
    public let capsuleName: String
    public let errorType: String
    public let errorMessage: String
    public let timestamp: Date
    public let operationType: String?

    public init(
        capsuleName: String,
        errorType: String,
        errorMessage: String,
        timestamp: Date = Date(),
        operationType: String? = nil
    ) {
        self.id = UUID().uuidString
        self.capsuleName = capsuleName
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.timestamp = timestamp
        self.operationType = operationType
    }
}

public actor CapsuleMetricsSystem {
    private var metrics: [String: CapsuleMetrics] = [:]
    private var fallbackHistory: [FallbackRecord] = []
    private var errorHistory: [ErrorRecord] = []
    private var operationLatencies: [String: [Double]] = [:]
    private var recentOperationsLimit: Int = 10000
    private var fallbackHistoryLimit: Int = 1000
    private var errorHistoryLimit: Int = 1000

    private let telemetryEmitter: ((TelemetryEventComponent) -> Void)?

    public init(telemetryEmitter: ((TelemetryEventComponent) -> Void)? = nil) {
        self.telemetryEmitter = telemetryEmitter
        for capsule in CapsuleType.allCases {
            metrics[capsule.rawValue] = CapsuleMetrics(capsuleName: capsule.rawValue)
        }
    }

    private func initializeDefaultMetrics() {
        for capsule in CapsuleType.allCases {
            metrics[capsule.rawValue] = CapsuleMetrics(capsuleName: capsule.rawValue)
        }
    }

    public func recordOperation(
        capsule: String,
        success: Bool,
        latencyMs: Double,
        bytesProcessed: Int64,
        usedSIMD: Bool,
        operationType: String? = nil
    ) {
        let currentMetrics = metrics[capsule] ?? CapsuleMetrics(capsuleName: capsule)
        var updatedMetrics = currentMetrics

        updatedMetrics.operationCount += 1
        updatedMetrics.lastUsed = Date()

        if success {
            updatedMetrics.successCount += 1
        }

        if usedSIMD {
            updatedMetrics.simdAccelerationCount += 1
        }

        updatedMetrics.totalBytesProcessed += bytesProcessed

        let totalLatencySum = updatedMetrics.averageLatencyMs * Double(updatedMetrics.successCount - 1)
        let newAverageLatency = (totalLatencySum + latencyMs) / Double(updatedMetrics.successCount)
        updatedMetrics.averageLatencyMs = newAverageLatency

        if !success {
            let errorCount = updatedMetrics.operationCount - updatedMetrics.successCount
            updatedMetrics.errorRate = Double(errorCount) / Double(updatedMetrics.operationCount) * 100

            let errorRecord = ErrorRecord(
                capsuleName: capsule,
                errorType: "operation_failure",
                errorMessage: "Operation failed after \(latencyMs)ms",
                operationType: operationType
            )
            errorHistory.append(errorRecord)
            if errorHistory.count > errorHistoryLimit {
                errorHistory.removeFirst()
            }
        }

        if operationLatencies[capsule] == nil {
            operationLatencies[capsule] = []
        }
        operationLatencies[capsule]?.append(latencyMs)
        if let latencies = operationLatencies[capsule], latencies.count > recentOperationsLimit {
            operationLatencies[capsule] = Array(latencies.suffix(recentOperationsLimit))
        }

        metrics[capsule] = updatedMetrics

        emitTelemetryEvent(
            capsule: capsule,
            success: success,
            latencyMs: latencyMs,
            bytesProcessed: bytesProcessed,
            usedSIMD: usedSIMD,
            operationType: operationType
        )
    }

    public func recordFallback(capsule: String, reason: String, operationType: String? = nil) {
        let currentMetrics = metrics[capsule] ?? CapsuleMetrics(capsuleName: capsule)
        var updatedMetrics = currentMetrics

        updatedMetrics.fallbackCount += 1
        updatedMetrics.lastUsed = Date()

        metrics[capsule] = updatedMetrics

        let fallbackRecord = FallbackRecord(
            capsuleName: capsule,
            reason: reason,
            operationType: operationType
        )
        fallbackHistory.append(fallbackRecord)
        if fallbackHistory.count > fallbackHistoryLimit {
            fallbackHistory.removeFirst()
        }

        emitFallbackTelemetry(capsule: capsule, reason: reason, operationType: operationType)
    }

    public func recordError(capsule: String, errorType: String, errorMessage: String, operationType: String? = nil) {
        let currentMetrics = metrics[capsule] ?? CapsuleMetrics(capsuleName: capsule)
        var updatedMetrics = currentMetrics

        updatedMetrics.operationCount += 1
        updatedMetrics.lastUsed = Date()

        let errorCount = updatedMetrics.operationCount - updatedMetrics.successCount
        updatedMetrics.errorRate = Double(errorCount) / Double(updatedMetrics.operationCount) * 100

        metrics[capsule] = updatedMetrics

        let errorRecord = ErrorRecord(
            capsuleName: capsule,
            errorType: errorType,
            errorMessage: errorMessage,
            operationType: operationType
        )
        errorHistory.append(errorRecord)
        if errorHistory.count > errorHistoryLimit {
            errorHistory.removeFirst()
        }

        emitErrorTelemetry(capsule: capsule, errorType: errorType, errorMessage: errorMessage, operationType: operationType)
    }

    public func getMetrics(for capsule: String) -> CapsuleMetrics? {
        return metrics[capsule]
    }

    public func getAllMetrics() -> [String: CapsuleMetrics] {
        return metrics
    }

    public func getOverallAccelerationStats() -> CapsuleAccelerationReport {
        var totalOperations: Int64 = 0
        var totalAccelerated: Int64 = 0
        var totalFallbacks: Int64 = 0
        var totalBytes: Int64 = 0
        var totalLatencySum: Double = 0
        var totalLatencyCount: Int64 = 0
        var totalSIMDCount: Int64 = 0

        var capsuleBreakdown: [String: CapsuleMetrics] = [:]

        for (name, metric) in metrics {
            totalOperations += metric.operationCount
            totalAccelerated += metric.simdAccelerationCount
            totalFallbacks += metric.fallbackCount
            totalBytes += metric.totalBytesProcessed
            totalLatencySum += metric.averageLatencyMs * Double(metric.successCount)
            totalLatencyCount += metric.successCount
            totalSIMDCount += metric.simdAccelerationCount
            capsuleBreakdown[name] = metric
        }

        let overallAccelerationRate = totalOperations > 0 ? Double(totalAccelerated) / Double(totalOperations) * 100 : 0
        let averageLatencyMs = totalLatencyCount > 0 ? totalLatencySum / Double(totalLatencyCount) : 0
        let simdUtilizationRate = totalOperations > 0 ? Double(totalSIMDCount) / Double(totalOperations) * 100 : 0

        let performanceRanks = metrics
            .filter { $0.value.operationCount > 0 }
            .sorted { $0.value.acceleratedPercentage > $1.value.acceleratedPercentage }

        let topPerformingCapsules = Array(performanceRanks.prefix(3).map { $0.key })
        let underperformingCapsules = Array(performanceRanks.suffix(3).map { $0.key })

        return CapsuleAccelerationReport(
            totalOperations: totalOperations,
            capsuleAcceleratedOperations: totalAccelerated,
            fallbackOperations: totalFallbacks,
            overallAccelerationRate: overallAccelerationRate,
            totalBytesProcessed: totalBytes,
            averageLatencyMs: averageLatencyMs,
            simdUtilizationRate: simdUtilizationRate,
            topPerformingCapsules: topPerformingCapsules,
            underperformingCapsules: underperformingCapsules,
            capsuleBreakdown: capsuleBreakdown
        )
    }

    public func getCapsuleLatencyPercentiles(for capsule: String, percentiles: [Double] = [0.5, 0.95, 0.99]) -> [Double: Double] {
        guard let latencies = operationLatencies[capsule], !latencies.isEmpty else {
            return [:]
        }

        let sortedLatencies = latencies.sorted()
        var result: [Double: Double] = [:]

        for percentile in percentiles {
            let index = Int(Double(sortedLatencies.count - 1) * percentile)
            result[percentile] = sortedLatencies[max(0, min(index, sortedLatencies.count - 1))]
        }

        return result
    }

    public func getFallbackHistory(for capsule: String? = nil, limit: Int = 100) -> [FallbackRecord] {
        if let capsule = capsule {
            return Array(fallbackHistory.filter { $0.capsuleName == capsule }.suffix(limit))
        }
        return Array(fallbackHistory.suffix(limit))
    }

    public func getErrorHistory(for capsule: String? = nil, limit: Int = 100) -> [ErrorRecord] {
        if let capsule = capsule {
            return Array(errorHistory.filter { $0.capsuleName == capsule }.suffix(limit))
        }
        return Array(errorHistory.suffix(limit))
    }

    public func getErrorFrequency(for capsule: String? = nil) -> [String: Int] {
        var errorCounts: [String: Int] = [:]

        let filteredErrors: [ErrorRecord]
        if let capsule = capsule {
            filteredErrors = errorHistory.filter { $0.capsuleName == capsule }
        } else {
            filteredErrors = errorHistory
        }

        for error in filteredErrors {
            errorCounts[error.errorType, default: 0] += 1
        }

        return errorCounts
    }

    public func getFallbackReasons(for capsule: String? = nil) -> [String: Int] {
        var reasonCounts: [String: Int] = [:]

        let filteredFallbacks: [FallbackRecord]
        if let capsule = capsule {
            filteredFallbacks = fallbackHistory.filter { $0.capsuleName == capsule }
        } else {
            filteredFallbacks = fallbackHistory
        }

        for fallback in filteredFallbacks {
            reasonCounts[fallback.reason, default: 0] += 1
        }

        return reasonCounts
    }

    public func resetMetrics(for capsule: String?) {
        if let capsule = capsule {
            metrics[capsule] = CapsuleMetrics(capsuleName: capsule)
            operationLatencies[capsule] = []
        } else {
            metrics = [:]
            operationLatencies = [:]
            initializeDefaultMetrics()
        }
    }

    public func exportPrometheusMetrics() -> String {
        var output = "# HELP capsule_operations_total Total number of capsule operations\n"
        output += "# TYPE capsule_operations_total counter\n"

        for (name, metric) in metrics {
            output += "capsule_operations_total{capsule=\"\(name)\"} \(metric.operationCount)\n"
        }

        output += "\n# HELP capsule_operations_success_total Total successful capsule operations\n"
        output += "# TYPE capsule_operations_success_total counter\n"

        for (name, metric) in metrics {
            output += "capsule_operations_success_total{capsule=\"\(name)\"} \(metric.successCount)\n"
        }

        output += "\n# HELP capsule_operations_fallback_total Total fallback operations for capsules\n"
        output += "# TYPE capsule_operations_fallback_total counter\n"

        for (name, metric) in metrics {
            output += "capsule_operations_fallback_total{capsule=\"\(name)\"} \(metric.fallbackCount)\n"
        }

        output += "\n# HELP capsule_simd_accelerated_total Total SIMD accelerated operations\n"
        output += "# TYPE capsule_simd_accelerated_total counter\n"

        for (name, metric) in metrics {
            output += "capsule_simd_accelerated_total{capsule=\"\(name)\"} \(metric.simdAccelerationCount)\n"
        }

        output += "\n# HELP capsule_bytes_processed_total Total bytes processed by capsules\n"
        output += "# TYPE capsule_bytes_processed_total counter\n"

        for (name, metric) in metrics {
            output += "capsule_bytes_processed_total{capsule=\"\(name)\"} \(metric.totalBytesProcessed)\n"
        }

        output += "\n# HELP capsule_latency_milliseconds Average operation latency in milliseconds\n"
        output += "# TYPE capsule_latency_milliseconds gauge\n"

        for (name, metric) in metrics {
            output += "capsule_latency_milliseconds{capsule=\"\(name)\"} \(String(format: "%.6f", metric.averageLatencyMs))\n"
        }

        output += "\n# HELP capsule_error_rate_percent Error rate as a percentage\n"
        output += "# TYPE capsule_error_rate_percent gauge\n"

        for (name, metric) in metrics {
            output += "capsule_error_rate_percent{capsule=\"\(name)\"} \(String(format: "%.6f", metric.errorRate))\n"
        }

        output += "\n# HELP capsule_acceleration_rate_percent Percentage of operations using SIMD acceleration\n"
        output += "# TYPE capsule_acceleration_rate_percent gauge\n"

        for (name, metric) in metrics {
            output += "capsule_acceleration_rate_percent{capsule=\"\(name)\"} \(String(format: "%.6f", metric.acceleratedPercentage))\n"
        }

        output += "\n# HELP capsule_last_used_seconds_seconds Seconds since last capsule use\n"
        output += "# TYPE capsule_last_used_seconds_seconds gauge\n"

        let currentTime = Date().timeIntervalSince1970
        for (name, metric) in metrics {
            let secondsAgo = currentTime - metric.lastUsed.timeIntervalSince1970
            output += "capsule_last_used_seconds_seconds{capsule=\"\(name)\"} \(String(format: "%.6f", secondsAgo))\n"
        }

        output += "\n# HELP capsule_fallback_rate_percent Percentage of operations that fell back\n"
        output += "# TYPE capsule_fallback_rate_percent gauge\n"

        for (name, metric) in metrics {
            let fallbackRate = metric.operationCount > 0 ? Double(metric.fallbackCount) / Double(metric.operationCount) * 100 : 0
            output += "capsule_fallback_rate_percent{capsule=\"\(name)\"} \(String(format: "%.6f", fallbackRate))\n"
        }

        let overallStats = getOverallAccelerationStats()
        output += "\n# HELP capsule_overall_acceleration_rate_percent Overall acceleration rate across all capsules\n"
        output += "# TYPE capsule_overall_acceleration_rate_percent gauge\n"
        output += "capsule_overall_acceleration_rate_percent \(String(format: "%.6f", overallStats.overallAccelerationRate))\n"

        output += "\n# HELP capsule_overall_simd_utilization_rate_percent Overall SIMD utilization rate\n"
        output += "# TYPE capsule_overall_simd_utilization_rate_percent gauge\n"
        output += "capsule_overall_simd_utilization_rate_percent \(String(format: "%.6f", overallStats.simdUtilizationRate))\n"

        output += "\n# HELP capsule_overall_average_latency_milliseconds Overall average latency across all capsules\n"
        output += "# TYPE capsule_overall_average_latency_milliseconds gauge\n"
        output += "capsule_overall_average_latency_milliseconds \(String(format: "%.6f", overallStats.averageLatencyMs))\n"

        return output
    }

    public func getJsonReport() -> Data {
        let report = getOverallAccelerationReport()
        return (try? JSONEncoder().encode(report)) ?? Data()
    }

    public func getOverallReport() -> CapsuleAccelerationReport {
        return getOverallAccelerationStats()
    }

    private func emitTelemetryEvent(
        capsule: String,
        success: Bool,
        latencyMs: Double,
        bytesProcessed: Int64,
        usedSIMD: Bool,
        operationType: String?
    ) {
        guard let emitter = telemetryEmitter else { return }

        var diagnosticPayload: [String: String] = [
            "capsule": capsule,
            "bytes_processed": String(bytesProcessed),
            "used_simd": String(usedSIMD)
        ]
        if let operationType = operationType {
            diagnosticPayload["operation_type"] = operationType
        }

        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .system,
            durationMs: Int(latencyMs),
            outcome: success ? .success : .failure,
            errorCode: success ? nil : "CAPSULE_OPERATION_FAILED",
            diagnosticPayload: diagnosticPayload
        )

        emitter(event)
    }

    private func emitFallbackTelemetry(capsule: String, reason: String, operationType: String?) {
        guard let emitter = telemetryEmitter else { return }

        var diagnosticPayload: [String: String] = [
            "capsule": capsule,
            "fallback_reason": reason
        ]
        if let operationType = operationType {
            diagnosticPayload["operation_type"] = operationType
        }

        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .system,
            outcome: .success,
            errorCode: "CAPSULE_FALLBACK",
            diagnosticPayload: diagnosticPayload
        )

        emitter(event)
    }

    private func emitErrorTelemetry(capsule: String, errorType: String, errorMessage: String, operationType: String?) {
        guard let emitter = telemetryEmitter else { return }

        var diagnosticPayload: [String: String] = [
            "capsule": capsule,
            "error_type": errorType,
            "error_message": errorMessage
        ]
        if let operationType = operationType {
            diagnosticPayload["operation_type"] = operationType
        }

        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .system,
            outcome: .failure,
            errorCode: errorType,
            diagnosticPayload: diagnosticPayload
        )

        emitter(event)
    }
}

extension CapsuleMetricsSystem {
    public func getOverallAccelerationReport() -> CapsuleAccelerationReport {
        return getOverallAccelerationStats()
    }
}
