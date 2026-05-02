import Foundation
import TelemetryCore
import ANEServicesCore

/// Comprehensive metrics collection system for ANE operations
/// Integrates with existing telemetry and monitoring infrastructure
public actor ANEMetrics {
    
    /// Configuration for ANE metrics collection
    public struct Configuration: Sendable, Codable {
        /// Whether to enable metrics collection
        public let enabled: Bool
        
        /// Collection interval in seconds
        public let collectionInterval: TimeInterval
        
        /// Maximum number of historical data points to keep
        public let maxHistorySize: Int
        
        /// Whether to emit telemetry events for critical metrics
        public let emitTelemetryEvents: Bool
        
        /// Thresholds for alerting
        public let thresholds: Thresholds
        
        /// Default configuration
        public static let `default` = Configuration(
            enabled: true,
            collectionInterval: 5.0,
            maxHistorySize: 1000,
            emitTelemetryEvents: true,
            thresholds: .default
        )
        
        /// Metric thresholds for alerting
        public struct Thresholds: Sendable, Codable {
            /// Maximum ANE utilization percentage before warning
            public let maxUtilizationWarning: Double
            
            /// Maximum ANE utilization percentage before error
            public let maxUtilizationError: Double
            
            /// Maximum temperature before warning
            public let maxTemperatureWarning: Double
            
            /// Maximum temperature before error
            public let maxTemperatureError: Double
            
            /// Maximum power consumption before warning
            public let maxPowerWarning: Double
            
            /// Maximum power consumption before error
            public let maxPowerError: Double
            
            /// Minimum success rate before warning
            public let minSuccessRateWarning: Double
            
            /// Minimum success rate before error
            public let minSuccessRateError: Double
            
            /// Default thresholds
            public static let `default` = Thresholds(
                maxUtilizationWarning: 80.0,
                maxUtilizationError: 95.0,
                maxTemperatureWarning: 75.0,
                maxTemperatureError: 85.0,
                maxPowerWarning: 8.0,
                maxPowerError: 10.0,
                minSuccessRateWarning: 0.95,
                minSuccessRateError: 0.90
            )
        }
    }
    
    /// ANE metric types
    public enum MetricType: String, Sendable, Codable, CaseIterable {
        case utilization = "ane_utilization"
        case temperature = "ane_temperature"
        case power = "ane_power"
        case successRate = "ane_success_rate"
        case latency = "ane_latency"
        case throughput = "ane_throughput"
        case memoryUsage = "ane_memory_usage"
        case errorRate = "ane_error_rate"
        case fallbackRate = "ane_fallback_rate"
        case cacheHitRate = "ane_cache_hit_rate"
    }
    
    /// ANE metric data point
    public struct MetricDataPoint: Sendable, Codable {
        public let timestamp: Date
        public let type: MetricType
        public let value: Double
        public let unit: String
        public let tags: [String: String]
        
        public init(
            timestamp: Date = Date(),
            type: MetricType,
            value: Double,
            unit: String,
            tags: [String: String] = [:]
        ) {
            self.timestamp = timestamp
            self.type = type
            self.value = value
            self.unit = unit
            self.tags = tags
        }
    }
    
    /// ANE health status
    public enum HealthStatus: String, Sendable, Codable {
        case healthy = "HEALTHY"
        case degraded = "DEGRADED"
        case unhealthy = "UNHEALTHY"
        case unknown = "UNKNOWN"
        
        public var numericValue: Int {
            switch self {
            case .healthy: return 0
            case .degraded: return 1
            case .unhealthy: return 2
            case .unknown: return 3
            }
        }
    }
    
    /// ANE health check result
    public struct HealthCheckResult: Sendable, Codable {
        public let status: HealthStatus
        public let timestamp: Date
        public let checks: [HealthCheck]
        public let overallScore: Double
        public let issues: [String]
        
        public init(
            status: HealthStatus,
            timestamp: Date = Date(),
            checks: [HealthCheck],
            overallScore: Double,
            issues: [String] = []
        ) {
            self.status = status
            self.timestamp = timestamp
            self.checks = checks
            self.overallScore = overallScore
            self.issues = issues
        }
    }
    
    /// Individual health check
    public struct HealthCheck: Sendable, Codable {
        public let name: String
        public let status: HealthStatus
        public let score: Double
        public let message: String
        public let details: [String: String]
        
        public init(
            name: String,
            status: HealthStatus,
            score: Double,
            message: String,
            details: [String: String] = [:]
        ) {
            self.name = name
            self.status = status
            self.score = score
            self.message = message
            self.details = details
        }
    }
    
    /// ANE performance summary
    public struct PerformanceSummary: Sendable, Codable {
        public let timestamp: Date
        public let utilization: Double
        public let temperature: Double
        public let power: Double
        public let successRate: Double
        public let averageLatency: TimeInterval
        public let throughput: Double
        public let errorRate: Double
        public let fallbackRate: Double
        public let cacheHitRate: Double
        
        public init(
            timestamp: Date = Date(),
            utilization: Double,
            temperature: Double,
            power: Double,
            successRate: Double,
            averageLatency: TimeInterval,
            throughput: Double,
            errorRate: Double,
            fallbackRate: Double,
            cacheHitRate: Double
        ) {
            self.timestamp = timestamp
            self.utilization = utilization
            self.temperature = temperature
            self.power = power
            self.successRate = successRate
            self.averageLatency = averageLatency
            self.throughput = throughput
            self.errorRate = errorRate
            self.fallbackRate = fallbackRate
            self.cacheHitRate = cacheHitRate
        }
    }
    
    /// Telemetry client for integration with existing telemetry
    private let telemetry: TelemetryClient
    
    /// Configuration
    private let configuration: Configuration
    
    /// Metric history storage
    private var metricHistory: [MetricType: [MetricDataPoint]]
    
    /// Health check history
    private var healthCheckHistory: [HealthCheckResult]
    
    /// Performance summary history
    private var performanceSummaryHistory: [PerformanceSummary]
    
    /// Current health status
    private var currentHealthStatus: HealthStatus
    
    /// Last collection time
    private var lastCollectionTime: Date?
    
    /// Collection timer
    private var collectionTimer: Task<Void, Never>?
    
    public init(
        configuration: Configuration = .default,
        telemetry: TelemetryClient
    ) {
        let shouldStartCollection = configuration.enabled
        self.configuration = configuration
        self.telemetry = telemetry
        self.metricHistory = [:]
        self.healthCheckHistory = []
        self.performanceSummaryHistory = []
        self.currentHealthStatus = .unknown
        
        // Initialize metric history for all types
        for metricType in MetricType.allCases {
            metricHistory[metricType] = []
        }
        
        if shouldStartCollection {
            Task { [weak self] in
                await self?.startCollection()
            }
        }
    }
    
    deinit {}
    
    /// Start metrics collection
    public func startCollection() {
        guard configuration.enabled else { return }
        
        collectionTimer = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                do {
                    try await self.collectMetrics()
                    try await Task.sleep(nanoseconds: UInt64(self.configuration.collectionInterval * 1_000_000_000))
                } catch {
                    // Log error but continue collection
                    await self.recordError(error)
                }
            }
        }
    }
    
    /// Stop metrics collection
    public func stopCollection() {
        collectionTimer?.cancel()
        collectionTimer = nil
    }
    
    /// Collect metrics from ANE subsystem
    private func collectMetrics() async throws {
        let collectionTime = Date()
        
        // Collect system metrics
        let systemMetrics = try await collectSystemMetrics()
        
        // Collect performance metrics
        let performanceMetrics = try await collectPerformanceMetrics()
        
        // Update metric history
        updateMetricHistory(systemMetrics: systemMetrics, performanceMetrics: performanceMetrics, timestamp: collectionTime)
        
        // Run health checks
        let healthCheckResult = try await runHealthChecks(systemMetrics: systemMetrics, performanceMetrics: performanceMetrics)
        
        // Update health status
        currentHealthStatus = healthCheckResult.status
        
        // Emit telemetry events if configured
        if configuration.emitTelemetryEvents {
            await emitTelemetryEvents(
                systemMetrics: systemMetrics,
                performanceMetrics: performanceMetrics,
                healthCheckResult: healthCheckResult
            )
        }
        
        // Generate performance summary
        let performanceSummary = generatePerformanceSummary(
            systemMetrics: systemMetrics,
            performanceMetrics: performanceMetrics,
            timestamp: collectionTime
        )
        
        performanceSummaryHistory.append(performanceSummary)
        
        // Trim history if needed
        trimHistory()
        
        lastCollectionTime = collectionTime
    }
    
    /// Collect system metrics (utilization, temperature, power)
    private func collectSystemMetrics() async throws -> SystemMetrics {
        // In a real implementation, this would query system APIs
        // For now, we'll use mock data that simulates realistic values
        
        let utilization = Double.random(in: 0...100)
        let temperature = Double.random(in: 30...90)
        let power = Double.random(in: 0...12)
        let memoryUsage = Double.random(in: 0...100)
        
        return SystemMetrics(
            utilization: utilization,
            temperature: temperature,
            power: power,
            memoryUsage: memoryUsage
        )
    }
    
    /// Collect performance metrics (success rate, latency, throughput)
    private func collectPerformanceMetrics() async throws -> ANEPerformanceMetrics {
        // In a real implementation, this would track actual execution statistics
        // For now, we'll use mock data
        
        let successRate = Double.random(in: 0.85...1.0)
        let averageLatency = Double.random(in: 0.001...0.1)
        let throughput = Double.random(in: 100...1000)
        let errorRate = Double.random(in: 0...0.15)
        let fallbackRate = Double.random(in: 0...0.1)
        let cacheHitRate = Double.random(in: 0.7...1.0)
        
        return ANEPerformanceMetrics(
            successRate: successRate,
            averageLatency: averageLatency,
            throughput: throughput,
            errorRate: errorRate,
            fallbackRate: fallbackRate,
            cacheHitRate: cacheHitRate
        )
    }
    
    /// Update metric history with new data
    private func updateMetricHistory(
        systemMetrics: SystemMetrics,
        performanceMetrics: ANEPerformanceMetrics,
        timestamp: Date
    ) {
        // System metrics
        metricHistory[.utilization]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .utilization,
            value: systemMetrics.utilization,
            unit: "%"
        ))
        
        metricHistory[.temperature]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .temperature,
            value: systemMetrics.temperature,
            unit: "°C"
        ))
        
        metricHistory[.power]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .power,
            value: systemMetrics.power,
            unit: "W"
        ))
        
        metricHistory[.memoryUsage]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .memoryUsage,
            value: systemMetrics.memoryUsage,
            unit: "%"
        ))
        
        // Performance metrics
        metricHistory[.successRate]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .successRate,
            value: performanceMetrics.successRate * 100,
            unit: "%"
        ))
        
        metricHistory[.latency]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .latency,
            value: performanceMetrics.averageLatency * 1000,
            unit: "ms"
        ))
        
        metricHistory[.throughput]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .throughput,
            value: performanceMetrics.throughput,
            unit: "ops/s"
        ))
        
        metricHistory[.errorRate]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .errorRate,
            value: performanceMetrics.errorRate * 100,
            unit: "%"
        ))
        
        metricHistory[.fallbackRate]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .fallbackRate,
            value: performanceMetrics.fallbackRate * 100,
            unit: "%"
        ))
        
        metricHistory[.cacheHitRate]?.append(MetricDataPoint(
            timestamp: timestamp,
            type: .cacheHitRate,
            value: performanceMetrics.cacheHitRate * 100,
            unit: "%"
        ))
    }
    
    /// Run comprehensive health checks
    private func runHealthChecks(
        systemMetrics: SystemMetrics,
        performanceMetrics: ANEPerformanceMetrics
    ) async throws -> HealthCheckResult {
        var checks: [HealthCheck] = []
        var issues: [String] = []
        var overallScore = 0.0
        
        // Utilization check
        let utilizationCheck = checkUtilization(systemMetrics.utilization)
        checks.append(utilizationCheck)
        if utilizationCheck.status.rawValue != ANEHealthCheck.HealthStatus.healthy.rawValue {
            issues.append("High ANE utilization: \(systemMetrics.utilization)%")
        }
        
        // Temperature check
        let temperatureCheck = checkTemperature(systemMetrics.temperature)
        checks.append(temperatureCheck)
        if temperatureCheck.status.rawValue != ANEHealthCheck.HealthStatus.healthy.rawValue {
            issues.append("High ANE temperature: \(systemMetrics.temperature)°C")
        }
        
        // Power check
        let powerCheck = checkPower(systemMetrics.power)
        checks.append(powerCheck)
        if powerCheck.status.rawValue != ANEHealthCheck.HealthStatus.healthy.rawValue {
            issues.append("High power consumption: \(systemMetrics.power)W")
        }
        
        // Success rate check
        let successRateCheck = checkSuccessRate(performanceMetrics.successRate)
        checks.append(successRateCheck)
        if successRateCheck.status.rawValue != ANEHealthCheck.HealthStatus.healthy.rawValue {
            issues.append("Low success rate: \(performanceMetrics.successRate * 100)%")
        }
        
        // Memory usage check
        let memoryCheck = checkMemoryUsage(systemMetrics.memoryUsage)
        checks.append(memoryCheck)
        if memoryCheck.status.rawValue != ANEHealthCheck.HealthStatus.healthy.rawValue {
            issues.append("High memory usage: \(systemMetrics.memoryUsage)%")
        }
        
        // Calculate overall score
        let healthyChecks = checks.filter { $0.status.rawValue == ANEHealthCheck.HealthStatus.healthy.rawValue }.count
        overallScore = Double(healthyChecks) / Double(checks.count)
        
        // Determine overall status
        let status = determineOverallStatus(checks: checks, overallScore: overallScore)
        
        return HealthCheckResult(
            status: status,
            checks: checks,
            overallScore: overallScore,
            issues: issues
        )
    }
    
    /// Check utilization against thresholds
    private func checkUtilization(_ utilization: Double) -> HealthCheck {
        let status: HealthStatus
        let score: Double
        let message: String
        
        if utilization >= configuration.thresholds.maxUtilizationError {
            status = .unhealthy
            score = 0.0
            message = "ANE utilization critically high"
        } else if utilization >= configuration.thresholds.maxUtilizationWarning {
            status = .degraded
            score = 0.5
            message = "ANE utilization elevated"
        } else {
            status = .healthy
            score = 1.0
            message = "ANE utilization normal"
        }
        
        return HealthCheck(
            name: "ANE Utilization",
            status: status,
            score: score,
            message: message,
            details: ["utilization": "\(utilization)%"]
        )
    }
    
    /// Check temperature against thresholds
    private func checkTemperature(_ temperature: Double) -> HealthCheck {
        let status: HealthStatus
        let score: Double
        let message: String
        
        if temperature >= configuration.thresholds.maxTemperatureError {
            status = .unhealthy
            score = 0.0
            message = "ANE temperature critically high"
        } else if temperature >= configuration.thresholds.maxTemperatureWarning {
            status = .degraded
            score = 0.5
            message = "ANE temperature elevated"
        } else {
            status = .healthy
            score = 1.0
            message = "ANE temperature normal"
        }
        
        return HealthCheck(
            name: "ANE Temperature",
            status: status,
            score: score,
            message: message,
            details: ["temperature": "\(temperature)°C"]
        )
    }
    
    /// Check power consumption against thresholds
    private func checkPower(_ power: Double) -> HealthCheck {
        let status: HealthStatus
        let score: Double
        let message: String
        
        if power >= configuration.thresholds.maxPowerError {
            status = .unhealthy
            score = 0.0
            message = "Power consumption critically high"
        } else if power >= configuration.thresholds.maxPowerWarning {
            status = .degraded
            score = 0.5
            message = "Power consumption elevated"
        } else {
            status = .healthy
            score = 1.0
            message = "Power consumption normal"
        }
        
        return HealthCheck(
            name: "ANE Power",
            status: status,
            score: score,
            message: message,
            details: ["power": "\(power)W"]
        )
    }
    
    /// Check success rate against thresholds
    private func checkSuccessRate(_ successRate: Double) -> HealthCheck {
        let status: HealthStatus
        let score: Double
        let message: String
        
        if successRate <= configuration.thresholds.minSuccessRateError {
            status = .unhealthy
            score = 0.0
            message = "Success rate critically low"
        } else if successRate <= configuration.thresholds.minSuccessRateWarning {
            status = .degraded
            score = 0.5
            message = "Success rate low"
        } else {
            status = .healthy
            score = 1.0
            message = "Success rate normal"
        }
        
        return HealthCheck(
            name: "ANE Success Rate",
            status: status,
            score: score,
            message: message,
            details: ["success_rate": "\(successRate * 100)%"]
        )
    }
    
    /// Check memory usage
    private func checkMemoryUsage(_ memoryUsage: Double) -> HealthCheck {
        let status: HealthStatus
        let score: Double
        let message: String
        
        if memoryUsage >= 90 {
            status = .unhealthy
            score = 0.0
            message = "Memory usage critically high"
        } else if memoryUsage >= 80 {
            status = .degraded
            score = 0.5
            message = "Memory usage elevated"
        } else {
            status = .healthy
            score = 1.0
            message = "Memory usage normal"
        }
        
        return HealthCheck(
            name: "ANE Memory",
            status: status,
            score: score,
            message: message,
            details: ["memory_usage": "\(memoryUsage)%"]
        )
    }
    
    /// Determine overall health status
    private func determineOverallStatus(checks: [HealthCheck], overallScore: Double) -> HealthStatus {
        let unhealthyChecks = checks.filter { $0.status.rawValue == ANEHealthCheck.HealthStatus.unhealthy.rawValue }
        let degradedChecks = checks.filter { $0.status == .degraded }
        
        if !unhealthyChecks.isEmpty {
            return .unhealthy
        } else if !degradedChecks.isEmpty {
            return .degraded
        } else if overallScore >= 0.9 {
            return .healthy
        } else {
            return .degraded
        }
    }
    
    /// Emit telemetry events for integration with existing monitoring
    private func emitTelemetryEvents(
        systemMetrics: SystemMetrics,
        performanceMetrics: ANEPerformanceMetrics,
        healthCheckResult: HealthCheckResult
    ) async {
        // Emit metric events
        // TODO: Fix telemetry API - DiagnosticEvent uses 'level' not 'severity'
        // await telemetry.record(DiagnosticEvent(
        //     severity: .info,
        //     category: "ane_metrics",
        //     message: "ANE metrics collected",
        //     metadata: [
        //         "utilization": "\(systemMetrics.utilization)",
        //         "temperature": "\(systemMetrics.temperature)",
        //         "power": "\(systemMetrics.power)",
        //         "success_rate": "\(performanceMetrics.successRate)",
        //         "latency": "\(performanceMetrics.averageLatency)",
        //         "health_status": healthCheckResult.status.rawValue,
        //         "health_score": "\(healthCheckResult.overallScore)"
        //     ]
        // ))
        
        // Emit warning/error events for unhealthy status
        // TODO: Fix telemetry API - DiagnosticEvent uses 'level' not 'severity'
        // if healthCheckResult.status.rawValue == ANEHealthCheck.HealthStatus.unhealthy.rawValue {
        //     await telemetry.record(DiagnosticEvent(
        //         severity: .error,
        //         category: "ane_health",
        //         message: "ANE health check failed",
        //         metadata: [
        //             "status": healthCheckResult.status.rawValue,
        //             "issues": healthCheckResult.issues.joined(separator: "; "),
        //             "score": "\(healthCheckResult.overallScore)"
        //         ]
        //     ))
        // } else if healthCheckResult.status == .degraded {
        //     await telemetry.record(DiagnosticEvent(
        //         severity: .warning,
        //         category: "ane_health",
        //         message: "ANE health degraded",
        //         metadata: [
        //             "status": healthCheckResult.status.rawValue,
        //             "issues": healthCheckResult.issues.joined(separator: "; "),
        //             "score": "\(healthCheckResult.overallScore)"
        //         ]
        //     ))
        // }
    }
    
    /// Generate performance summary
    private func generatePerformanceSummary(
        systemMetrics: SystemMetrics,
        performanceMetrics: ANEPerformanceMetrics,
        timestamp: Date
    ) -> PerformanceSummary {
        return PerformanceSummary(
            timestamp: timestamp,
            utilization: systemMetrics.utilization,
            temperature: systemMetrics.temperature,
            power: systemMetrics.power,
            successRate: performanceMetrics.successRate,
            averageLatency: performanceMetrics.averageLatency,
            throughput: performanceMetrics.throughput,
            errorRate: performanceMetrics.errorRate,
            fallbackRate: performanceMetrics.fallbackRate,
            cacheHitRate: performanceMetrics.cacheHitRate
        )
    }
    
    /// Trim history to maximum size
    private func trimHistory() {
        // Trim metric history
        for (metricType, history) in metricHistory {
            if history.count > configuration.maxHistorySize {
                metricHistory[metricType] = Array(history.suffix(configuration.maxHistorySize))
            }
        }
        
        // Trim health check history
        if healthCheckHistory.count > configuration.maxHistorySize {
            healthCheckHistory = Array(healthCheckHistory.suffix(configuration.maxHistorySize))
        }
        
        // Trim performance summary history
        if performanceSummaryHistory.count > configuration.maxHistorySize {
            performanceSummaryHistory = Array(performanceSummaryHistory.suffix(configuration.maxHistorySize))
        }
    }
    
    /// Record error in telemetry
    private func recordError(_ error: Error) async {
        // TODO: Fix telemetry API - DiagnosticEvent uses 'level' not 'severity'
        // await telemetry.record(DiagnosticEvent(
        //     severity: .error,
        //     category: "ane_metrics",
        //     message: "Metrics collection error",
        //     metadata: [
        //         "error": error.localizedDescription
        //     ]
        // ))
    }
    
    // MARK: - Public API
    
    /// Get current health status
    public func getHealthStatus() -> HealthStatus {
        return currentHealthStatus
    }
    
    /// Get latest health check result
    public func getLatestHealthCheck() -> HealthCheckResult? {
        return healthCheckHistory.last
    }
    
    /// Get health check history
    public func getHealthCheckHistory(limit: Int? = nil) -> [HealthCheckResult] {
        guard let limit = limit else {
            return healthCheckHistory
        }
        return Array(healthCheckHistory.suffix(limit))
    }
    
    /// Get metric history for a specific type
    public func getMetricHistory(for type: MetricType, limit: Int? = nil) -> [MetricDataPoint] {
        guard let history = metricHistory[type] else {
            return []
        }
        
        guard let limit = limit else {
            return history
        }
        return Array(history.suffix(limit))
    }
    
    /// Get latest performance summary
    public func getLatestPerformanceSummary() -> PerformanceSummary? {
        return performanceSummaryHistory.last
    }
    
    /// Get performance summary history
    public func getPerformanceSummaryHistory(limit: Int? = nil) -> [PerformanceSummary] {
        guard let limit = limit else {
            return performanceSummaryHistory
        }
        return Array(performanceSummaryHistory.suffix(limit))
    }
    
    /// Get statistics for a specific metric type
    public func getMetricStatistics(for type: MetricType, window: TimeInterval? = nil) -> MetricStatistics {
        guard let history = metricHistory[type] else {
            return MetricStatistics.empty
        }
        
        let filteredHistory: [MetricDataPoint]
        if let window = window {
            let cutoffDate = Date().addingTimeInterval(-window)
            filteredHistory = history.filter { $0.timestamp >= cutoffDate }
        } else {
            filteredHistory = history
        }
        
        guard !filteredHistory.isEmpty else {
            return MetricStatistics.empty
        }
        
        let values = filteredHistory.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        let variance = values.map { pow($0 - average, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        
        return MetricStatistics(
            average: average,
            min: min,
            max: max,
            stdDev: stdDev,
            count: values.count,
            lastValue: filteredHistory.last?.value ?? 0,
            lastTimestamp: filteredHistory.last?.timestamp ?? Date()
        )
    }
    
    /// Force a metrics collection cycle
    public func forceCollection() async throws {
        try await collectMetrics()
    }
    
    /// Clear all collected metrics
    public func clearMetrics() {
        for metricType in MetricType.allCases {
            metricHistory[metricType] = []
        }
        healthCheckHistory = []
        performanceSummaryHistory = []
        currentHealthStatus = .unknown
    }
}

// MARK: - Supporting Types

/// System metrics collected from ANE
private struct SystemMetrics: Sendable {
    let utilization: Double
    let temperature: Double
    let power: Double
    let memoryUsage: Double
}

/// Performance metrics collected from ANE operations
struct ANEPerformanceMetrics: Sendable {
    let successRate: Double
    let averageLatency: TimeInterval
    let throughput: Double
    let errorRate: Double
    let fallbackRate: Double
    let cacheHitRate: Double
}

/// Metric statistics
public struct MetricStatistics: Sendable, Codable {
    public let average: Double
    public let min: Double
    public let max: Double
    public let stdDev: Double
    public let count: Int
    public let lastValue: Double
    public let lastTimestamp: Date
    
    public static let empty = MetricStatistics(
        average: 0,
        min: 0,
        max: 0,
        stdDev: 0,
        count: 0,
        lastValue: 0,
        lastTimestamp: Date()
    )
}

// MARK: - Alerting System

extension ANEMetrics {
    
    /// Alert severity levels
    public enum AlertSeverity: String, Sendable, Codable {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
    }
    
    /// Alert type
    public enum AlertType: String, Sendable, Codable, CaseIterable {
        case utilizationHigh = "ANE_UTILIZATION_HIGH"
        case temperatureHigh = "ANE_TEMPERATURE_HIGH"
        case powerHigh = "ANE_POWER_HIGH"
        case successRateLow = "ANE_SUCCESS_RATE_LOW"
        case memoryHigh = "ANE_MEMORY_HIGH"
        case healthDegraded = "ANE_HEALTH_DEGRADED"
        case healthUnhealthy = "ANE_HEALTH_UNHEALTHY"
    }
    
    /// Alert
    public struct Alert: Sendable, Codable {
        public let id: String
        public let type: AlertType
        public let severity: AlertSeverity
        public let message: String
        public let timestamp: Date
        public let metricValue: Double?
        public let threshold: Double?
        public let details: [String: String]
        
        public init(
            id: String = UUID().uuidString,
            type: AlertType,
            severity: AlertSeverity,
            message: String,
            timestamp: Date = Date(),
            metricValue: Double? = nil,
            threshold: Double? = nil,
            details: [String: String] = [:]
        ) {
            self.id = id
            self.type = type
            self.severity = severity
            self.message = message
            self.timestamp = timestamp
            self.metricValue = metricValue
            self.threshold = threshold
            self.details = details
        }
    }
    
    /// Check for alerts based on current metrics
    public func checkForAlerts() -> [Alert] {
        var alerts: [Alert] = []
        
        guard let latestSummary = getLatestPerformanceSummary() else {
            return alerts
        }
        
        // Check utilization
        if latestSummary.utilization >= configuration.thresholds.maxUtilizationError {
            alerts.append(Alert(
                type: .utilizationHigh,
                severity: .critical,
                message: "ANE utilization critically high: \(latestSummary.utilization)%",
                metricValue: latestSummary.utilization,
                threshold: configuration.thresholds.maxUtilizationError,
                details: ["metric": "utilization", "unit": "%"]
            ))
        } else if latestSummary.utilization >= configuration.thresholds.maxUtilizationWarning {
            alerts.append(Alert(
                type: .utilizationHigh,
                severity: .warning,
                message: "ANE utilization elevated: \(latestSummary.utilization)%",
                metricValue: latestSummary.utilization,
                threshold: configuration.thresholds.maxUtilizationWarning,
                details: ["metric": "utilization", "unit": "%"]
            ))
        }
        
        // Check temperature
        if latestSummary.temperature >= configuration.thresholds.maxTemperatureError {
            alerts.append(Alert(
                type: .temperatureHigh,
                severity: .critical,
                message: "ANE temperature critically high: \(latestSummary.temperature)°C",
                metricValue: latestSummary.temperature,
                threshold: configuration.thresholds.maxTemperatureError,
                details: ["metric": "temperature", "unit": "°C"]
            ))
        } else if latestSummary.temperature >= configuration.thresholds.maxTemperatureWarning {
            alerts.append(Alert(
                type: .temperatureHigh,
                severity: .warning,
                message: "ANE temperature elevated: \(latestSummary.temperature)°C",
                metricValue: latestSummary.temperature,
                threshold: configuration.thresholds.maxTemperatureWarning,
                details: ["metric": "temperature", "unit": "°C"]
            ))
        }
        
        // Check power
        if latestSummary.power >= configuration.thresholds.maxPowerError {
            alerts.append(Alert(
                type: .powerHigh,
                severity: .critical,
                message: "Power consumption critically high: \(latestSummary.power)W",
                metricValue: latestSummary.power,
                threshold: configuration.thresholds.maxPowerError,
                details: ["metric": "power", "unit": "W"]
            ))
        } else if latestSummary.power >= configuration.thresholds.maxPowerWarning {
            alerts.append(Alert(
                type: .powerHigh,
                severity: .warning,
                message: "Power consumption elevated: \(latestSummary.power)W",
                metricValue: latestSummary.power,
                threshold: configuration.thresholds.maxPowerWarning,
                details: ["metric": "power", "unit": "W"]
            ))
        }
        
        // Check success rate
        if latestSummary.successRate <= configuration.thresholds.minSuccessRateError {
            alerts.append(Alert(
                type: .successRateLow,
                severity: .critical,
                message: "Success rate critically low: \(latestSummary.successRate * 100)%",
                metricValue: latestSummary.successRate * 100,
                threshold: configuration.thresholds.minSuccessRateError * 100,
                details: ["metric": "success_rate", "unit": "%"]
            ))
        } else if latestSummary.successRate <= configuration.thresholds.minSuccessRateWarning {
            alerts.append(Alert(
                type: .successRateLow,
                severity: .warning,
                message: "Success rate low: \(latestSummary.successRate * 100)%",
                metricValue: latestSummary.successRate * 100,
                threshold: configuration.thresholds.minSuccessRateWarning * 100,
                details: ["metric": "success_rate", "unit": "%"]
            ))
        }
        
        // Check health status
        let healthStatus = getHealthStatus()
        if healthStatus == .unhealthy {
            alerts.append(Alert(
                type: .healthUnhealthy,
                severity: .critical,
                message: "ANE health status: UNHEALTHY",
                details: ["status": healthStatus.rawValue]
            ))
        } else if healthStatus == .degraded {
            alerts.append(Alert(
                type: .healthDegraded,
                severity: .warning,
                message: "ANE health status: DEGRADED",
                details: ["status": healthStatus.rawValue]
            ))
        }
        
        return alerts
    }
}
