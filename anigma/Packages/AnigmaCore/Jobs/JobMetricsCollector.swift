//
//  JobMetricsCollector.swift
//  AnigmaCore
//
//  Comprehensive job metrics collection and reporting system.
//

import Foundation
import AnigmaPrimitives

/// Comprehensive job metrics collector for monitoring and reporting.
public actor JobMetricsCollector: JobMetricsCollector {
    // MARK: - Configuration
    private let maxHistorySize: Int
    private let retentionPeriod: TimeInterval
    
    // MARK: - Metrics Storage
    private var metricsHistory: [JobMetric] = []
    private var counters: [JobMetricType: Int] = [:]
    private var timers: [JobMetricType: [TimeInterval]] = [:]
    private var jobTypeMetrics: [String: JobTypeMetrics] = [:]
    private var hourlyStats: [Date: HourlyStats] = [:]
    
    // Performance statistics
    private var lastCleanup = Date()
    private let cleanupInterval: TimeInterval = 3600 // 1 hour
    
    public init(maxHistorySize: Int = 10000, retentionPeriod: TimeInterval = 86400 * 7) {
        self.maxHistorySize = maxHistorySize
        self.retentionPeriod = retentionPeriod
        
        // Initialize counters
        for metricType in JobMetricType.allCases {
            counters[metricType] = 0
            timers[metricType] = []
        }
    }
    
    // MARK: - JobMetricsCollector Protocol
    
    public func record(
        type: JobMetricType,
        jobId: JobId?,
        jobType: String?,
        duration: Int64?,
        count: Int?
    ) async {
        let timestamp = Date()
        let metric = JobMetric(
            type: type,
            timestamp: timestamp,
            jobId: jobId,
            jobType: jobType,
            duration: duration,
            count: count
        )
        
        // Store in history
        metricsHistory.append(metric)
        if metricsHistory.count > maxHistorySize {
            metricsHistory.removeFirst()
        }
        
        // Update counters
        counters[type, default: 0] += (count ?? 1)
        
        // Update timers for duration metrics
        if let duration = duration {
            let durationInSeconds = TimeInterval(duration) / 1000.0
            timers[type, default: []].append(durationInSeconds)
            
            // Keep only recent timer data
            if timers[type]?.count ?? 0 > 1000 {
                timers[type]?.removeFirst(500)
            }
        }
        
        // Update job type metrics
        if let jobType = jobType {
            await updateJobTypeMetrics(jobType: jobType, metric: metric)
        }
        
        // Update hourly stats
        await updateHourlyStats(timestamp: timestamp, metric: metric)
        
        // Periodic cleanup
        if timestamp.timeIntervalSince(lastCleanup) > cleanupInterval {
            await performCleanup()
            lastCleanup = timestamp
        }
    }
    
    // MARK: - Metrics Queries
    
    /// Get overall statistics for all jobs.
    public func getOverallStats() async -> JobOverallStats {
        let now = Date()
        let cutoff24h = now.addingTimeInterval(-86400) // Last 24 hours
        let cutoff7d = now.addingTimeInterval(-86400 * 7) // Last 7 days
        
        let recentMetrics = metricsHistory.filter { $0.timestamp >= cutoff24h }
        let weeklyMetrics = metricsHistory.filter { $0.timestamp >= cutoff7d }
        
        return JobOverallStats(
            totalSubmitted: counters[.jobSubmitted] ?? 0,
            totalCompleted: counters[.jobCompleted] ?? 0,
            totalFailed: counters[.jobFailed] ?? 0,
            totalCancelled: counters[.jobCancelled] ?? 0,
            totalRetried: counters[.jobRetried] ?? 0,
            submittedLast24h: recentMetrics.filter { $0.type == .jobSubmitted }.count,
            completedLast24h: recentMetrics.filter { $0.type == .jobCompleted }.count,
            failedLast24h: recentMetrics.filter { $0.type == .jobFailed }.count,
            completedLast7d: weeklyMetrics.filter { $0.type == .jobCompleted }.count,
            failedLast7d: weeklyMetrics.filter { $0.type == .jobFailed }.count,
            averageExecutionTime: calculateAverageExecutionTime(),
            successRate: calculateSuccessRate(),
            timeoutRate: calculateTimeoutRate()
        )
    }
    
    /// Get statistics for a specific job type.
    public func getJobTypeStats(_ jobType: String) async -> JobTypeStats? {
        let metrics = jobTypeMetrics[jobType]
        guard let metrics = metrics else { return nil }
        
        let recentMetrics = metricsHistory.filter { 
            $0.jobType == jobType && 
            $0.timestamp >= Date().addingTimeInterval(-86400)
        }
        
        return JobTypeStats(
            jobType: jobType,
            totalSubmitted: metrics.submitted,
            totalCompleted: metrics.completed,
            totalFailed: metrics.failed,
            averageExecutionTime: metrics.averageExecutionTime,
            successRate: metrics.successRate,
            timeoutRate: metrics.timeoutRate,
            submittedLast24h: recentMetrics.filter { $0.type == .jobSubmitted }.count,
            completedLast24h: recentMetrics.filter { $0.type == .jobCompleted }.count,
            failedLast24h: recentMetrics.filter { $0.type == .jobFailed }.count
        )
    }
    
    /// Get performance metrics over time.
    public func getPerformanceMetrics(timeRange: TimeRange) async -> [PerformanceDataPoint] {
        let cutoff: Date
        let interval: TimeInterval
        
        switch timeRange {
        case .lastHour:
            cutoff = Date().addingTimeInterval(-3600)
            interval = 300 // 5 minutes
        case .last24Hours:
            cutoff = Date().addingTimeInterval(-86400)
            interval = 3600 // 1 hour
        case .last7Days:
            cutoff = Date().addingTimeInterval(-86400 * 7)
            interval = 86400 // 1 day
        case .last30Days:
            cutoff = Date().addingTimeInterval(-86400 * 30)
            interval = 86400 // 1 day
        }
        
        let relevantMetrics = metricsHistory.filter { $0.timestamp >= cutoff }
        var dataPoints: [PerformanceDataPoint] = []
        
        let startTime = cutoff
        let endTime = Date()
        var currentTime = startTime
        
        while currentTime < endTime {
            let nextTime = currentTime.addingTimeInterval(interval)
            let windowMetrics = relevantMetrics.filter { 
                $0.timestamp >= currentTime && $0.timestamp < nextTime
            }
            
            let completed = windowMetrics.filter { $0.type == .jobCompleted }.count
            let failed = windowMetrics.filter { $0.type == .jobFailed }.count
            let durations = windowMetrics.compactMap { $0.duration }.map { TimeInterval($0) / 1000.0 }
            
            dataPoints.append(PerformanceDataPoint(
                timestamp: currentTime,
                completedJobs: completed,
                failedJobs: failed,
                averageExecutionTime: durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count),
                throughput: Double(completed + failed) / interval
            ))
            
            currentTime = nextTime
        }
        
        return dataPoints
    }
    
    /// Get error classification statistics.
    public func getErrorStats() async -> ErrorStats {
        var errorCounts: [String: Int] = [:]
        var errorTrends: [Date: [String]] = [:]
        
        // This would need to be integrated with the error classification system
        // For now, return basic error metrics
        
        return ErrorStats(
            totalErrors: counters[.jobFailed] ?? 0,
            errorsLast24h: metricsHistory.filter { 
                $0.type == .jobFailed && 
                $0.timestamp >= Date().addingTimeInterval(-86400)
            }.count,
            errorClassification: errorCounts,
            errorTrends: errorTrends
        )
    }
    
    /// Export metrics in various formats.
    public func exportMetrics(format: ExportFormat) async -> Data {
        let stats = await getOverallStats()
        
        switch format {
        case .json:
            return try! JSONEncoder().encode(stats)
        case .csv:
            return generateCSV(from: stats)
        case .prometheus:
            return generatePrometheusFormat(from: stats)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func updateJobTypeMetrics(jobType: String, metric: JobMetric) async {
        if jobTypeMetrics[jobType] == nil {
            jobTypeMetrics[jobType] = JobTypeMetrics(
                jobType: jobType,
                submitted: 0,
                completed: 0,
                failed: 0,
                averageExecutionTime: 0,
                successRate: 0,
                timeoutRate: 0
            )
        }
        
        var metrics = jobTypeMetrics[jobType]!
        
        switch metric.type {
        case .jobSubmitted:
            metrics.submitted += 1
        case .jobCompleted:
            metrics.completed += 1
            if let duration = metric.duration {
                let durationInSeconds = TimeInterval(duration) / 1000.0
                metrics.totalExecutionTime += durationInSeconds
                metrics.executionCount += 1
                metrics.averageExecutionTime = metrics.totalExecutionTime / Double(metrics.executionCount)
            }
        case .jobCompletedWithTimeout:
            metrics.completed += 1
            metrics.timeoutCount += 1
            if let duration = metric.duration {
                let durationInSeconds = TimeInterval(duration) / 1000.0
                metrics.totalExecutionTime += durationInSeconds
                metrics.executionCount += 1
                metrics.averageExecutionTime = metrics.totalExecutionTime / Double(metrics.executionCount)
            }
        case .jobFailed:
            metrics.failed += 1
        default:
            break
        }
        
        // Calculate rates
        let totalFinished = metrics.completed + metrics.failed
        if totalFinished > 0 {
            metrics.successRate = Double(metrics.completed) / Double(totalFinished)
            metrics.timeoutRate = Double(metrics.timeoutCount) / Double(metrics.completed)
        }
        
        jobTypeMetrics[jobType] = metrics
    }
    
    private func updateHourlyStats(timestamp: Date, metric: JobMetric) async {
        let hourStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day, .hour], from: timestamp))!
        
        if hourlyStats[hourStart] == nil {
            hourlyStats[hourStart] = HourlyStats(timestamp: hourStart)
        }
        
        var stats = hourlyStats[hourStart]!
        
        switch metric.type {
        case .jobSubmitted:
            stats.submitted += 1
        case .jobCompleted, .jobCompletedWithTimeout:
            stats.completed += 1
        case .jobFailed:
            stats.failed += 1
        case .jobCancelled:
            stats.cancelled += 1
        default:
            break
        }
        
        hourlyStats[hourStart] = stats
    }
    
    private func performCleanup() async {
        let cutoff = Date().addingTimeInterval(-retentionPeriod)
        metricsHistory.removeAll { $0.timestamp < cutoff }
        hourlyStats = hourlyStats.filter { $0.key >= cutoff }
    }
    
    private func calculateAverageExecutionTime() -> TimeInterval {
        let durations = timers[.jobCompleted] ?? []
        return durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
    }
    
    private func calculateSuccessRate() -> Double {
        let completed = counters[.jobCompleted] ?? 0
        let failed = counters[.jobFailed] ?? 0
        let total = completed + failed
        return total > 0 ? Double(completed) / Double(total) : 0
    }
    
    private func calculateTimeoutRate() -> Double {
        let completed = counters[.jobCompleted] ?? 0
        let completedWithTimeout = counters[.jobCompletedWithTimeout] ?? 0
        return completed > 0 ? Double(completedWithTimeout) / Double(completed) : 0
    }
    
    private func generateCSV(from stats: JobOverallStats) -> Data {
        var csv = "Metric,Value\n"
        csv += "Total Submitted,\(stats.totalSubmitted)\n"
        csv += "Total Completed,\(stats.totalCompleted)\n"
        csv += "Total Failed,\(stats.totalFailed)\n"
        csv += "Success Rate,\(String(format: "%.2f%%", stats.successRate * 100))\n"
        csv += "Average Execution Time,\(String(format: "%.2f", stats.averageExecutionTime))s\n"
        return csv.data(using: .utf8) ?? Data()
    }
    
    private func generatePrometheusFormat(from stats: JobOverallStats) -> Data {
        var prometheus = ""
        prometheus += "# HELP anigma_jobs_submitted_total Total number of jobs submitted\n"
        prometheus += "# TYPE anigma_jobs_submitted_total counter\n"
        prometheus += "anigma_jobs_submitted_total \(stats.totalSubmitted)\n\n"
        
        prometheus += "# HELP anigma_jobs_completed_total Total number of jobs completed\n"
        prometheus += "# TYPE anigma_jobs_completed_total counter\n"
        prometheus += "anigma_jobs_completed_total \(stats.totalCompleted)\n\n"
        
        prometheus += "# HELP anigma_jobs_failed_total Total number of jobs failed\n"
        prometheus += "# TYPE anigma_jobs_failed_total counter\n"
        prometheus += "anigma_jobs_failed_total \(stats.totalFailed)\n\n"
        
        prometheus += "# HELP anigma_jobs_success_rate Success rate of jobs\n"
        prometheus += "# TYPE anigma_jobs_success_rate gauge\n"
        prometheus += "anigma_jobs_success_rate \(stats.successRate)\n\n"
        
        prometheus += "# HELP anigma_jobs_average_execution_seconds Average execution time in seconds\n"
        prometheus += "# TYPE anigma_jobs_average_execution_seconds gauge\n"
        prometheus += "anigma_jobs_average_execution_seconds \(stats.averageExecutionTime)\n"
        
        return prometheus.data(using: .utf8) ?? Data()
    }
}

// MARK: - Supporting Types

/// Individual job metric entry.
public struct JobMetric: Codable, Sendable {
    public let type: JobMetricType
    public let timestamp: Date
    public let jobId: JobId?
    public let jobType: String?
    public let duration: Int64?
    public let count: Int?
}

/// Metrics specific to a job type.
public struct JobTypeMetrics: Codable, Sendable {
    public let jobType: String
    public var submitted: Int
    public var completed: Int
    public var failed: Int
    public var averageExecutionTime: TimeInterval
    public var successRate: Double
    public var timeoutRate: Double
    public var totalExecutionTime: TimeInterval
    public var executionCount: Int
    public var timeoutCount: Int
    
    public init(
        jobType: String,
        submitted: Int,
        completed: Int,
        failed: Int,
        averageExecutionTime: TimeInterval,
        successRate: Double,
        timeoutRate: Double
    ) {
        self.jobType = jobType
        self.submitted = submitted
        self.completed = completed
        self.failed = failed
        self.averageExecutionTime = averageExecutionTime
        self.successRate = successRate
        self.timeoutRate = timeoutRate
        self.totalExecutionTime = 0
        self.executionCount = 0
        self.timeoutCount = 0
    }
}

/// Hourly statistics aggregation.
public struct HourlyStats: Codable, Sendable {
    public let timestamp: Date
    public var submitted: Int
    public var completed: Int
    public var failed: Int
    public var cancelled: Int
    
    public init(timestamp: Date) {
        self.timestamp = timestamp
        self.submitted = 0
        self.completed = 0
        self.failed = 0
        self.cancelled = 0
    }
}

/// Overall job statistics.
public struct JobOverallStats: Codable, Sendable {
    public let totalSubmitted: Int
    public let totalCompleted: Int
    public let totalFailed: Int
    public let totalCancelled: Int
    public let totalRetried: Int
    public let submittedLast24h: Int
    public let completedLast24h: Int
    public let failedLast24h: Int
    public let completedLast7d: Int
    public let failedLast7d: Int
    public let averageExecutionTime: TimeInterval
    public let successRate: Double
    public let timeoutRate: Double
}

/// Job type specific statistics.
public struct JobTypeStats: Codable, Sendable {
    public let jobType: String
    public let totalSubmitted: Int
    public let totalCompleted: Int
    public let totalFailed: Int
    public let averageExecutionTime: TimeInterval
    public let successRate: Double
    public let timeoutRate: Double
    public let submittedLast24h: Int
    public let completedLast24h: Int
    public let failedLast24h: Int
}

/// Performance data point for time series.
public struct PerformanceDataPoint: Codable, Sendable {
    public let timestamp: Date
    public let completedJobs: Int
    public let failedJobs: Int
    public let averageExecutionTime: TimeInterval?
    public let throughput: Double
}

/// Error statistics.
public struct ErrorStats: Codable, Sendable {
    public let totalErrors: Int
    public let errorsLast24h: Int
    public let errorClassification: [String: Int]
    public let errorTrends: [Date: [String]]
}

/// Time range for metrics queries.
public enum TimeRange: String, CaseIterable {
    case lastHour = "1h"
    case last24Hours = "24h"
    case last7Days = "7d"
    case last30Days = "30d"
}

/// Export format for metrics.
public enum ExportFormat: String, CaseIterable {
    case json
    case csv
    case prometheus
}