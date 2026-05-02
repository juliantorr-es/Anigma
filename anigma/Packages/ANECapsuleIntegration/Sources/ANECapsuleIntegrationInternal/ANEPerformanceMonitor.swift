import Foundation
import ANEServicesCore

/// ANE performance monitor for detailed metrics tracking and analysis
public actor ANEPerformanceMonitor {
    /// Performance metrics for a single batch execution
    public struct BatchMetrics: Sendable, Codable {
        public let batchId: UUID
        public let capsuleId: String
        public let batchSize: Int
        public let executionTime: TimeInterval
        public let computeUnit: ANEComputeUnit
        public let memoryUsedMB: Double
        public let powerUsedWatts: Double
        public let success: Bool
        public let fallbackUsed: Bool
        public let timestamp: Date
        
        public init(
            batchId: UUID,
            capsuleId: String,
            batchSize: Int,
            executionTime: TimeInterval,
            computeUnit: ANEComputeUnit,
            memoryUsedMB: Double,
            powerUsedWatts: Double,
            success: Bool,
            fallbackUsed: Bool,
            timestamp: Date = Date()
        ) {
            self.batchId = batchId
            self.capsuleId = capsuleId
            self.batchSize = batchSize
            self.executionTime = executionTime
            self.computeUnit = computeUnit
            self.memoryUsedMB = memoryUsedMB
            self.powerUsedWatts = powerUsedWatts
            self.success = success
            self.fallbackUsed = fallbackUsed
            self.timestamp = timestamp
        }
    }
    
    /// Performance statistics aggregated over time
    public struct PerformanceStatistics: Sendable {
        public let totalBatches: Int
        public let totalWorkloads: Int
        public let successfulBatches: Int
        public let failedBatches: Int
        public let averageBatchSize: Double
        public let averageExecutionTime: TimeInterval
        public let minExecutionTime: TimeInterval
        public let maxExecutionTime: TimeInterval
        public let aneBatches: Int
        public let cpuBatches: Int
        public let gpuBatches: Int
        public let fallbackBatches: Int
        public let memoryEfficiency: Double
        public let powerEfficiency: Double
        public let successRate: Double
        public let aneUtilizationRate: Double
        public let fallbackRate: Double
        
        public init(
            totalBatches: Int = 0,
            totalWorkloads: Int = 0,
            successfulBatches: Int = 0,
            failedBatches: Int = 0,
            averageBatchSize: Double = 0.0,
            averageExecutionTime: TimeInterval = 0.0,
            minExecutionTime: TimeInterval = .infinity,
            maxExecutionTime: TimeInterval = 0.0,
            aneBatches: Int = 0,
            cpuBatches: Int = 0,
            gpuBatches: Int = 0,
            fallbackBatches: Int = 0,
            memoryEfficiency: Double = 0.0,
            powerEfficiency: Double = 0.0,
            successRate: Double = 0.0,
            aneUtilizationRate: Double = 0.0,
            fallbackRate: Double = 0.0
        ) {
            self.totalBatches = totalBatches
            self.totalWorkloads = totalWorkloads
            self.successfulBatches = successfulBatches
            self.failedBatches = failedBatches
            self.averageBatchSize = averageBatchSize
            self.averageExecutionTime = averageExecutionTime
            self.minExecutionTime = minExecutionTime
            self.maxExecutionTime = maxExecutionTime
            self.aneBatches = aneBatches
            self.cpuBatches = cpuBatches
            self.gpuBatches = gpuBatches
            self.fallbackBatches = fallbackBatches
            self.memoryEfficiency = memoryEfficiency
            self.powerEfficiency = powerEfficiency
            self.successRate = successRate
            self.aneUtilizationRate = aneUtilizationRate
            self.fallbackRate = fallbackRate
        }
    }
    
    /// Performance trend analysis
    public struct PerformanceTrend: Sendable {
        public let period: TimeInterval
        public let batchesPerMinute: Double
        public let workloadsPerMinute: Double
        public let executionTimeTrend: TrendDirection
        public let successRateTrend: TrendDirection
        public let aneUtilizationTrend: TrendDirection
        public let memoryEfficiencyTrend: TrendDirection
        public let powerEfficiencyTrend: TrendDirection
        public let fallbackRate: Double
        
        public init(
            period: TimeInterval = 300.0, // 5 minutes
            batchesPerMinute: Double = 0.0,
            workloadsPerMinute: Double = 0.0,
            executionTimeTrend: TrendDirection = .stable,
            successRateTrend: TrendDirection = .stable,
            aneUtilizationTrend: TrendDirection = .stable,
            memoryEfficiencyTrend: TrendDirection = .stable,
            powerEfficiencyTrend: TrendDirection = .stable,
            fallbackRate: Double = 0.0
        ) {
            self.period = period
            self.batchesPerMinute = batchesPerMinute
            self.workloadsPerMinute = workloadsPerMinute
            self.executionTimeTrend = executionTimeTrend
            self.successRateTrend = successRateTrend
            self.aneUtilizationTrend = aneUtilizationTrend
            self.memoryEfficiencyTrend = memoryEfficiencyTrend
            self.powerEfficiencyTrend = powerEfficiencyTrend
            self.fallbackRate = fallbackRate
        }
    }
    
    /// Trend direction for performance metrics
    public enum TrendDirection: String, Sendable, Codable {
        case improving = "IMPROVING"
        case stable = "STABLE"
        case degrading = "DEGRADING"
        case unknown = "UNKNOWN"
    }
    
    /// Performance alert thresholds
    public struct AlertThresholds: Sendable {
        public let maxExecutionTime: TimeInterval
        public let minSuccessRate: Double
        public let maxMemoryUsageMB: Double
        public let maxPowerUsageWatts: Double
        public let maxFallbackRate: Double
        
        public init(
            maxExecutionTime: TimeInterval = 2.0,
            minSuccessRate: Double = 0.95,
            maxMemoryUsageMB: Double = 400.0,
            maxPowerUsageWatts: Double = 12.0,
            maxFallbackRate: Double = 0.3
        ) {
            self.maxExecutionTime = maxExecutionTime
            self.minSuccessRate = minSuccessRate
            self.maxMemoryUsageMB = maxMemoryUsageMB
            self.maxPowerUsageWatts = maxPowerUsageWatts
            self.maxFallbackRate = maxFallbackRate
        }
    }
    
    /// Performance alert
    public struct PerformanceAlert: Sendable, Identifiable {
        public let id: UUID
        public let severity: AlertSeverity
        public let metric: String
        public let value: Double
        public let threshold: Double
        public let description: String
        public let timestamp: Date
        public let capsuleId: String?
        
        public init(
            severity: AlertSeverity,
            metric: String,
            value: Double,
            threshold: Double,
            description: String,
            capsuleId: String? = nil
        ) {
            self.id = UUID()
            self.severity = severity
            self.metric = metric
            self.value = value
            self.threshold = threshold
            self.description = description
            self.timestamp = Date()
            self.capsuleId = capsuleId
        }
    }
    
    /// Alert severity levels
    public enum AlertSeverity: String, Sendable, Codable {
        case info = "INFO"
        case warning = "WARNING"
        case critical = "CRITICAL"
    }
    
    private var batchMetrics: [BatchMetrics] = []
    private var performanceAlerts: [PerformanceAlert] = []
    private let maxMetricsHistory = 1000
    private let maxAlertsHistory = 100
    private let alertThresholds: AlertThresholds
    private var lastTrendAnalysis: Date = Date()
    private let trendAnalysisInterval: TimeInterval = 60.0 // Analyze trends every minute
    private var periodicAnalysisTask: Task<Void, Never>?
    
    public init(alertThresholds: AlertThresholds = AlertThresholds()) {
        self.alertThresholds = alertThresholds
        Task { [weak self] in
            await self?.startPeriodicAnalysis()
        }
    }
    
    deinit {}
    
    /// Record batch execution metrics
    public func recordBatchExecution(
        batchId: UUID = UUID(),
        capsuleId: String,
        batchSize: Int,
        executionTime: TimeInterval,
        computeUnit: ANEComputeUnit,
        memoryUsedMB: Double,
        powerUsedWatts: Double,
        success: Bool,
        fallbackUsed: Bool
    ) {
        let metrics = BatchMetrics(
            batchId: batchId,
            capsuleId: capsuleId,
            batchSize: batchSize,
            executionTime: executionTime,
            computeUnit: computeUnit,
            memoryUsedMB: memoryUsedMB,
            powerUsedWatts: powerUsedWatts,
            success: success,
            fallbackUsed: fallbackUsed
        )
        
        batchMetrics.append(metrics)
        
        // Trim history if needed
        if batchMetrics.count > maxMetricsHistory {
            batchMetrics.removeFirst(batchMetrics.count - maxMetricsHistory)
        }
        
        // Check for alerts
        checkForAlerts(metrics: metrics)
    }
    
    /// Convenience method for recording from batch processor
    public func recordBatchExecution(
        batchSize: Int,
        executionTime: TimeInterval,
        computeUnit: ANEComputeUnit,
        fallbackUsed: Bool
    ) {
        recordBatchExecution(
            capsuleId: "unknown",
            batchSize: batchSize,
            executionTime: executionTime,
            computeUnit: computeUnit,
            memoryUsedMB: 0.0,
            powerUsedWatts: 0.0,
            success: true,
            fallbackUsed: fallbackUsed
        )
    }
    
    /// Get current performance statistics
    public func getStatistics() -> PerformanceStatistics {
        guard !batchMetrics.isEmpty else {
            return PerformanceStatistics()
        }
        
        let recentMetrics = getRecentMetrics(period: 300.0) // Last 5 minutes
        
        let totalBatches = recentMetrics.count
        let totalWorkloads = recentMetrics.reduce(0) { $0 + $1.batchSize }
        let successfulBatches = recentMetrics.filter { $0.success }.count
        let failedBatches = totalBatches - successfulBatches
        
        let averageBatchSize = totalBatches > 0 ? Double(totalWorkloads) / Double(totalBatches) : 0.0
        let averageExecutionTime = totalBatches > 0 ? recentMetrics.reduce(0.0) { $0 + $1.executionTime } / Double(totalBatches) : 0.0
        
        let minExecutionTime = recentMetrics.map { $0.executionTime }.min() ?? 0.0
        let maxExecutionTime = recentMetrics.map { $0.executionTime }.max() ?? 0.0
        
        let aneBatches = recentMetrics.filter { $0.computeUnit == .neuralEngine }.count
        let cpuBatches = recentMetrics.filter { $0.computeUnit == .cpu }.count
        let gpuBatches = recentMetrics.filter { $0.computeUnit == .gpu }.count
        let fallbackBatches = recentMetrics.filter { $0.fallbackUsed }.count
        
        // Calculate efficiency metrics
        let memoryEfficiency = calculateMemoryEfficiency(metrics: recentMetrics)
        let powerEfficiency = calculatePowerEfficiency(metrics: recentMetrics)
        
        let successRate = totalBatches > 0 ? Double(successfulBatches) / Double(totalBatches) : 0.0
        let aneUtilizationRate = totalBatches > 0 ? Double(aneBatches) / Double(totalBatches) : 0.0
        let fallbackRate = totalBatches > 0 ? Double(fallbackBatches) / Double(totalBatches) : 0.0
        
        return PerformanceStatistics(
            totalBatches: totalBatches,
            totalWorkloads: totalWorkloads,
            successfulBatches: successfulBatches,
            failedBatches: failedBatches,
            averageBatchSize: averageBatchSize,
            averageExecutionTime: averageExecutionTime,
            minExecutionTime: minExecutionTime,
            maxExecutionTime: maxExecutionTime,
            aneBatches: aneBatches,
            cpuBatches: cpuBatches,
            gpuBatches: gpuBatches,
            fallbackBatches: fallbackBatches,
            memoryEfficiency: memoryEfficiency,
            powerEfficiency: powerEfficiency,
            successRate: successRate,
            aneUtilizationRate: aneUtilizationRate,
            fallbackRate: fallbackRate
        )
    }
    
    /// Get performance trend analysis
    public func getPerformanceTrend(period: TimeInterval = 300.0) -> PerformanceTrend {
        let recentMetrics = getRecentMetrics(period: period)
        let olderMetrics = getRecentMetrics(period: period * 2, endDate: Date().addingTimeInterval(-period))
        
        guard !recentMetrics.isEmpty && !olderMetrics.isEmpty else {
            return PerformanceTrend(period: period)
        }
        
        let recentStats = calculateStatistics(for: recentMetrics)
        let olderStats = calculateStatistics(for: olderMetrics)
        
        // Calculate rates per minute
        let batchesPerMinute = Double(recentMetrics.count) / (period / 60.0)
        let workloadsPerMinute = Double(recentStats.totalWorkloads) / (period / 60.0)
        
        // Calculate trends
        let executionTimeTrend = calculateTrend(
            current: recentStats.averageExecutionTime,
            previous: olderStats.averageExecutionTime,
            threshold: 0.1 // 10% change
        )
        
        let successRateTrend = calculateTrend(
            current: recentStats.successRate,
            previous: olderStats.successRate,
            threshold: 0.05 // 5% change
        )
        
        let aneUtilizationTrend = calculateTrend(
            current: recentStats.aneUtilizationRate,
            previous: olderStats.aneUtilizationRate,
            threshold: 0.1 // 10% change
        )
        
        let memoryEfficiencyTrend = calculateTrend(
            current: recentStats.memoryEfficiency,
            previous: olderStats.memoryEfficiency,
            threshold: 0.05 // 5% change
        )
        
        let powerEfficiencyTrend = calculateTrend(
            current: recentStats.powerEfficiency,
            previous: olderStats.powerEfficiency,
            threshold: 0.05 // 5% change
        )
        
        return PerformanceTrend(
            period: period,
            batchesPerMinute: batchesPerMinute,
            workloadsPerMinute: workloadsPerMinute,
            executionTimeTrend: executionTimeTrend,
            successRateTrend: successRateTrend,
            aneUtilizationTrend: aneUtilizationTrend,
            memoryEfficiencyTrend: memoryEfficiencyTrend,
            powerEfficiencyTrend: powerEfficiencyTrend,
            fallbackRate: recentStats.fallbackRate
        )
    }
    
    /// Get active performance alerts
    public func getActiveAlerts() -> [PerformanceAlert] {
        // Return alerts from last hour
        let oneHourAgo = Date().addingTimeInterval(-3600.0)
        return performanceAlerts.filter { $0.timestamp > oneHourAgo }
    }
    
    /// Clear old alerts
    public func clearOldAlerts() {
        let oneDayAgo = Date().addingTimeInterval(-86400.0)
        performanceAlerts.removeAll { $0.timestamp < oneDayAgo }
        
        // Trim history if needed
        if performanceAlerts.count > maxAlertsHistory {
            performanceAlerts.removeFirst(performanceAlerts.count - maxAlertsHistory)
        }
    }
    
    /// Export performance metrics for analysis
    public func exportMetrics(since date: Date) -> [BatchMetrics] {
        batchMetrics.filter { $0.timestamp >= date }
    }
    
    /// Reset all metrics (for testing)
    public func reset() {
        batchMetrics.removeAll()
        performanceAlerts.removeAll()
        lastTrendAnalysis = Date()
    }
    
    // MARK: - Private Methods
    
    private func getRecentMetrics(period: TimeInterval, endDate: Date = Date()) -> [BatchMetrics] {
        let startDate = endDate.addingTimeInterval(-period)
        return batchMetrics.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }
    
    private func calculateStatistics(for metrics: [BatchMetrics]) -> PerformanceStatistics {
        guard !metrics.isEmpty else {
            return PerformanceStatistics()
        }
        
        let totalBatches = metrics.count
        let totalWorkloads = metrics.reduce(0) { $0 + $1.batchSize }
        let successfulBatches = metrics.filter { $0.success }.count
        let failedBatches = totalBatches - successfulBatches
        
        let averageBatchSize = Double(totalWorkloads) / Double(totalBatches)
        let averageExecutionTime = metrics.reduce(0.0) { $0 + $1.executionTime } / Double(totalBatches)
        
        let minExecutionTime = metrics.map { $0.executionTime }.min() ?? 0.0
        let maxExecutionTime = metrics.map { $0.executionTime }.max() ?? 0.0
        
        let aneBatches = metrics.filter { $0.computeUnit == .neuralEngine }.count
        let cpuBatches = metrics.filter { $0.computeUnit == .cpu }.count
        let gpuBatches = metrics.filter { $0.computeUnit == .gpu }.count
        let fallbackBatches = metrics.filter { $0.fallbackUsed }.count
        
        let memoryEfficiency = calculateMemoryEfficiency(metrics: metrics)
        let powerEfficiency = calculatePowerEfficiency(metrics: metrics)
        
        let successRate = Double(successfulBatches) / Double(totalBatches)
        let aneUtilizationRate = Double(aneBatches) / Double(totalBatches)
        let fallbackRate = Double(fallbackBatches) / Double(totalBatches)
        
        return PerformanceStatistics(
            totalBatches: totalBatches,
            totalWorkloads: totalWorkloads,
            successfulBatches: successfulBatches,
            failedBatches: failedBatches,
            averageBatchSize: averageBatchSize,
            averageExecutionTime: averageExecutionTime,
            minExecutionTime: minExecutionTime,
            maxExecutionTime: maxExecutionTime,
            aneBatches: aneBatches,
            cpuBatches: cpuBatches,
            gpuBatches: gpuBatches,
            fallbackBatches: fallbackBatches,
            memoryEfficiency: memoryEfficiency,
            powerEfficiency: powerEfficiency,
            successRate: successRate,
            aneUtilizationRate: aneUtilizationRate,
            fallbackRate: fallbackRate
        )
    }
    
    private func calculateMemoryEfficiency(metrics: [BatchMetrics]) -> Double {
        guard !metrics.isEmpty else { return 0.0 }
        
        // Calculate memory efficiency as (workloads processed per MB) / (optimal workloads per MB)
        let totalWorkloads = metrics.reduce(0) { $0 + $1.batchSize }
        let totalMemoryMB = metrics.reduce(0.0) { $0 + $1.memoryUsedMB }
        
        guard totalMemoryMB > 0 else { return 0.0 }
        
        let actualEfficiency = Double(totalWorkloads) / totalMemoryMB
        
        // Assume optimal efficiency is 10 workloads per MB (placeholder)
        // STUB_TRACK: ane-memory-efficiency – Memory efficiency optimal threshold is placeholder
        print("⚠️  STUB INVOKED: ANEPerformanceMonitor.calculateMemoryEfficiency()")
        print("   Memory efficiency threshold is placeholder value - not calibrated")
        let optimalEfficiency = 10.0
        
        return min(actualEfficiency / optimalEfficiency, 1.0)
    }
    
    private func calculatePowerEfficiency(metrics: [BatchMetrics]) -> Double {
        guard !metrics.isEmpty else { return 0.0 }
        
        // Calculate power efficiency as (workloads processed per Watt) / (optimal workloads per Watt)
        let totalWorkloads = metrics.reduce(0) { $0 + $1.batchSize }
        let totalPowerWatts = metrics.reduce(0.0) { $0 + $1.powerUsedWatts }
        
        guard totalPowerWatts > 0 else { return 0.0 }
        
        let actualEfficiency = Double(totalWorkloads) / totalPowerWatts
        
        // Assume optimal efficiency is 100 workloads per Watt (placeholder)
        // STUB_TRACK: ane-power-efficiency – Power efficiency optimal threshold is placeholder
        print("⚠️  STUB INVOKED: ANEPerformanceMonitor.calculatePowerEfficiency()")
        print("   Power efficiency threshold is placeholder value - not calibrated")
        let optimalEfficiency = 100.0
        
        return min(actualEfficiency / optimalEfficiency, 1.0)
    }
    
    private func calculateTrend(current: Double, previous: Double, threshold: Double) -> TrendDirection {
        guard previous > 0 else { return .unknown }
        
        let change = (current - previous) / previous
        
        if Swift.abs(change) < threshold {
            return .stable
        } else if change > 0 {
            // For metrics where higher is better (success rate, efficiency)
            return .improving
        } else {
            // For metrics where lower is better (execution time)
            // Note: For execution time, we invert the logic
            if current == previous {
                return .stable
            } else if current < previous {
                return .improving
            } else {
                return .degrading
            }
        }
    }
    
    private func checkForAlerts(metrics: BatchMetrics) {
        // Check execution time
        if metrics.executionTime > alertThresholds.maxExecutionTime {
            addAlert(
                severity: metrics.executionTime > alertThresholds.maxExecutionTime * 2 ? .critical : .warning,
                metric: "execution_time",
                value: metrics.executionTime,
                threshold: alertThresholds.maxExecutionTime,
                description: "Batch execution time exceeded threshold",
                capsuleId: metrics.capsuleId
            )
        }
        
        // Check memory usage
        if metrics.memoryUsedMB > alertThresholds.maxMemoryUsageMB {
            addAlert(
                severity: .warning,
                metric: "memory_usage",
                value: metrics.memoryUsedMB,
                threshold: alertThresholds.maxMemoryUsageMB,
                description: "Memory usage exceeded threshold",
                capsuleId: metrics.capsuleId
            )
        }
        
        // Check power usage
        if metrics.powerUsedWatts > alertThresholds.maxPowerUsageWatts {
            addAlert(
                severity: .warning,
                metric: "power_usage",
                value: metrics.powerUsedWatts,
                threshold: alertThresholds.maxPowerUsageWatts,
                description: "Power usage exceeded threshold",
                capsuleId: metrics.capsuleId
            )
        }
        
        // Check for consecutive failures
        let recentFailures = getRecentMetrics(period: 60.0).filter { !$0.success }
        if recentFailures.count >= 3 {
            addAlert(
                severity: .critical,
                metric: "consecutive_failures",
                value: Double(recentFailures.count),
                threshold: 3.0,
                description: "Multiple consecutive batch failures",
                capsuleId: metrics.capsuleId
            )
        }
    }
    
    private func addAlert(
        severity: AlertSeverity,
        metric: String,
        value: Double,
        threshold: Double,
        description: String,
        capsuleId: String?
    ) {
        let alert = PerformanceAlert(
            severity: severity,
            metric: metric,
            value: value,
            threshold: threshold,
            description: description,
            capsuleId: capsuleId
        )
        
        performanceAlerts.append(alert)
        
        // Trim history if needed
        if performanceAlerts.count > maxAlertsHistory {
            performanceAlerts.removeFirst(performanceAlerts.count - maxAlertsHistory)
        }
        
        // Log alert
        print("\(severity.rawValue) ALERT: \(description) (metric: \(metric), value: \(value), threshold: \(threshold))")
    }
    
    private func startPeriodicAnalysis() {
        guard periodicAnalysisTask == nil else { return }
        periodicAnalysisTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                try? await Task.sleep(nanoseconds: UInt64(self.trendAnalysisInterval * 1_000_000_000))
                await self.analyzeTrends()
            }
        }
    }
    
    private func stopPeriodicAnalysis() {
        periodicAnalysisTask?.cancel()
        periodicAnalysisTask = nil
    }
    
    private func analyzeTrends() {
        let trend = getPerformanceTrend()
        
        // Check for concerning trends
        if trend.executionTimeTrend == .degrading {
            addAlert(
                severity: .warning,
                metric: "execution_time_trend",
                value: 0.0,
                threshold: 0.0,
                description: "Execution time trend is degrading",
                capsuleId: nil
            )
        }
        
        if trend.successRateTrend == .degrading {
            addAlert(
                severity: .critical,
                metric: "success_rate_trend",
                value: 0.0,
                threshold: 0.0,
                description: "Success rate trend is degrading",
                capsuleId: nil
            )
        }
        
        if trend.fallbackRate > alertThresholds.maxFallbackRate {
            addAlert(
                severity: .warning,
                metric: "fallback_rate",
                value: trend.fallbackRate,
                threshold: alertThresholds.maxFallbackRate,
                description: "Fallback rate exceeded threshold",
                capsuleId: nil
            )
        }
        
        lastTrendAnalysis = Date()
    }
}
