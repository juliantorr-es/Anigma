//
//  JobAdministrationTools.swift
//  AnigmaCore
//
//  Administrative tools for job inspection, management, and control.
//

import Foundation
import AnigmaPrimitives

/// Comprehensive administrative interface for job management.
public actor JobAdministration {
    // MARK: - Dependencies
    private let unifiedQueue: UnifiedJobQueue
    private let auditTrail: JobAuditTrail
    private let metricsCollector: JobMetricsCollector
    private let notificationSystem: JobNotificationSystem
    private let errorClassifier: JobErrorClassifier
    
    // MARK: - Admin State
    private var adminSessions: [AdminSession] = []
    private var maintenanceWindows: [MaintenanceWindow] = []
    private var systemLocks: [SystemLock] = []
    
    public init(
        unifiedQueue: UnifiedJobQueue,
        auditTrail: JobAuditTrail,
        metricsCollector: JobMetricsCollector,
        notificationSystem: JobNotificationSystem,
        errorClassifier: JobErrorClassifier
    ) {
        self.unifiedQueue = unifiedQueue
        self.auditTrail = auditTrail
        self.metricsCollector = metricsCollector
        self.notificationSystem = notificationSystem
        self.errorClassifier = errorClassifier
    }
    
    // MARK: - Job Inspection
    
    /// Get detailed job information including full audit trail.
    public func getJobDetails(_ jobId: JobId, includeAudit: Bool = true) async -> JobDetails {
        let record = unifiedQueue.getJob(jobId)
        let auditTrail = includeAudit ? await auditTrail.getJobAuditTrail(jobId) : []
        let stats = await metricsCollector.getJobTypeStats(record?.job.typeId ?? "unknown")
        
        return JobDetails(
            record: record,
            auditTrail: auditTrail,
            jobTypeStats: stats,
            timestamp: Date()
        )
    }
    
    /// List jobs with comprehensive filtering and sorting.
    public func listJobs(request: JobListRequest) async -> JobListResponse {
        // Apply filters
        var records = try! await unifiedQueue.listJobs(
            status: request.statuses,
            jobType: request.jobType
        )
        
        // Apply additional filters
        if let userId = request.userId {
            // Filter by user if audit trail has user info
            let auditEntries = await auditTrail.getAuditEntries(userId: userId)
            let userJobIds = Set(auditEntries.compactMap { $0.jobId })
            records = records.filter { userJobIds.contains($0.id) }
        }
        
        if let createdAfter = request.createdAfter {
            records = records.filter { $0.job.createdAt >= createdAfter }
        }
        
        if let createdBefore = request.createdBefore {
            records = records.filter { $0.job.createdAt <= createdBefore }
        }
        
        // Apply sorting
        records.sort { record1, record2 in
            switch request.sortBy {
            case .createdAt:
                return request.sortOrder == .ascending ? 
                    record1.job.createdAt < record2.job.createdAt :
                    record1.job.createdAt > record2.job.createdAt
            case .priority:
                return request.sortOrder == .ascending ?
                    record1.job.priority.rawValue < record2.job.priority.rawValue :
                    record1.job.priority.rawValue > record2.job.priority.rawValue
            case .status:
                return request.sortOrder == .ascending ?
                    record1.status.rawValue < record2.status.rawValue :
                    record1.status.rawValue > record2.status.rawValue
            case .attempts:
                return request.sortOrder == .ascending ?
                    record1.attempts < record2.attempts :
                    record1.attempts > record2.attempts
            }
        }
        
        // Apply pagination
        let startIndex = request.page * request.pageSize
        let endIndex = min(startIndex + request.pageSize, records.count)
        let pageRecords = startIndex < records.count ? Array(records[startIndex..<endIndex]) : []
        
        return JobListResponse(
            jobs: pageRecords,
            total: records.count,
            page: request.page,
            pageSize: request.pageSize,
            hasMore: endIndex < records.count
        )
    }
    
    /// Get system overview statistics.
    public func getSystemOverview() async -> SystemOverview {
        let queueStats = unifiedQueue.getStats()
        let overallStats = await metricsCollector.getOverallStats()
        let auditStats = await auditTrail.getAuditStatistics()
        
        // Get job type breakdown
        let jobTypeStats = await getJobTypeBreakdown()
        
        // Get recent activity
        let recentActivity = await getRecentActivity(hours: 24)
        
        return SystemOverview(
            queueStats: queueStats,
            overallStats: overallStats,
            auditStats: auditStats,
            jobTypeBreakdown: jobTypeStats,
            recentActivity: recentActivity,
            maintenanceWindows: maintenanceWindows,
            systemLocks: systemLocks,
            timestamp: Date()
        )
    }
    
    // MARK: - Job Control
    
    /// Cancel a job with reason and authorization.
    public func cancelJob(
        _ jobId: JobId,
        reason: String,
        cancelledBy: String,
        force: Bool = false
    ) async throws -> AdminActionResult {
        // Check if job can be cancelled
        guard let record = unifiedQueue.getJob(jobId) else {
            throw AdminError.jobNotFound(jobId)
        }
        
        // Check permissions
        if !force && record.status.isTerminal {
            throw AdminError.jobAlreadyCompleted(jobId, record.status)
        }
        
        // Cancel the job
        try await unifiedQueue.cancel(jobId: jobId)
        
        // Record in audit trail
        await auditTrail.recordJobCancellation(
            jobId: jobId,
            cancelledBy: cancelledBy,
            reason: reason
        )
        
        // Send notification
        await notificationSystem.notifyJobFailed(
            jobId: jobId,
            jobType: record.job.typeId,
            error: "Cancelled by admin: \(reason)"
        )
        
        return AdminActionResult(
            success: true,
            message: "Job \(jobId.raw) cancelled successfully",
            affectedJobs: [jobId]
        )
    }
    
    /// Retry a failed job with optional configuration changes.
    public func retryJob(
        _ jobId: JobId,
        retryReason: String,
        requestedBy: String,
        newPriority: JobPriority? = nil,
        newTimeout: TimeInterval? = nil,
        newRetryPolicy: RetryPolicy? = nil
    ) async throws -> AdminActionResult {
        guard let record = unifiedQueue.getJob(jobId) else {
            throw AdminError.jobNotFound(jobId)
        }
        
        guard record.status == .failed else {
            throw AdminError.jobNotRetryable(jobId, record.status)
        }
        
        // Create new job with updated configuration if specified
        var job = record.job
        if let newPriority = newPriority {
            job = Job(
                id: job.id,
                typeId: job.typeId,
                priority: newPriority,
                createdAt: job.createdAt,
                scheduledFor: job.scheduledFor,
                deadline: job.deadline,
                timeoutDuration: job.timeoutDuration,
                timeoutPolicy: job.timeoutPolicy,
                retryPolicy: job.retryPolicy,
                inputRefs: job.inputRefs,
                outputRefs: job.outputRefs,
                metadata: job.metadata,
                label: job.label,
                tags: job.tags
            )
        }
        
        // Retry the job
        try await unifiedQueue.retry(jobId)
        
        // Record in audit trail
        await auditTrail.recordJobRetry(
            jobId: jobId,
            retryReason: retryReason,
            backoffDelay: 0,
            nextRetryAt: Date()
        )
        
        return AdminActionResult(
            success: true,
            message: "Job \(jobId.raw) queued for retry",
            affectedJobs: [jobId]
        )
    }
    
    /// Pause job processing for maintenance.
    public func pauseProcessing(
        reason: String,
        duration: TimeInterval,
        requestedBy: String
    ) async throws -> AdminActionResult {
        let window = MaintenanceWindow(
            id: UUID(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(duration),
            reason: reason,
            requestedBy: requestedBy,
            type: .planned
        )
        
        maintenanceWindows.append(window)
        
        // Record in audit trail
        await auditTrail.recordSystemEvent(
            eventType: .systemEvent,
            description: "Job processing paused for maintenance: \(reason)",
            systemInfo: [
                "maintenanceWindowId": window.id.uuidString,
                "duration": duration,
                "requestedBy": requestedBy
            ]
        )
        
        // Send notification
        await notificationSystem.notifySystemEvent(
            title: "Maintenance Window Started",
            message: "Job processing is paused for: \(reason)",
            severity: .warning
        )
        
        return AdminActionResult(
            success: true,
            message: "Job processing paused until \(window.endTime)",
            affectedJobs: []
        )
    }
    
    /// Resume job processing.
    public func resumeProcessing(reason: String, requestedBy: String) async throws -> AdminActionResult {
        let activeWindows = maintenanceWindows.filter { $0.endTime > Date() }
        guard !activeWindows.isEmpty else {
            throw AdminError.noActiveMaintenanceWindow
        }
        
        // End active windows
        for window in activeWindows {
            var endedWindow = window
            endedWindow.endTime = Date()
            
            maintenanceWindows.removeAll { $0.id == window.id }
        }
        
        // Record in audit trail
        await auditTrail.recordSystemEvent(
            eventType: .systemEvent,
            description: "Job processing resumed: \(reason)",
            systemInfo: [
                "reason": reason,
                "requestedBy": requestedBy
            ]
        )
        
        // Send notification
        await notificationSystem.notifySystemEvent(
            title: "Processing Resumed",
            message: "Job processing has been resumed",
            severity: .info
        )
        
        return AdminActionResult(
            success: true,
            message: "Job processing resumed",
            affectedJobs: []
        )
    }
    
    // MARK: - Job Type Management
    
    /// Get job type performance analysis.
    public func getJobTypeAnalysis(_ jobType: String, timeRange: TimeRange) async -> JobTypeAnalysis {
        let stats = await metricsCollector.getJobTypeStats(jobType)
        let performanceData = await metricsCollector.getPerformanceMetrics(timeRange: timeRange)
        let recentEntries = await auditTrail.getAuditEntries(
            startDate: timeRange.startDate,
            endDate: Date()
        ).filter { entry in
            // Filter entries related to this job type
            if let jobId = entry.jobId {
                // This would need job record lookup
                return true
            }
            return false
        }
        
        // Calculate error patterns
        let errorPatterns = analyzeErrorPatterns(from: recentEntries)
        
        return JobTypeAnalysis(
            jobType: jobType,
            stats: stats,
            performanceData: performanceData.filter { $0.jobType == jobType },
            errorPatterns: errorPatterns,
            recommendations: generateRecommendations(for: jobType, analysis: stats),
            timeRange: timeRange
        )
    }
    
    /// Bulk job operations.
    public func bulkJobOperation(_ operation: BulkJobOperation) async throws -> BulkJobResult {
        var results: [JobId: AdminActionResult] = [:]
        var successCount = 0
        var failureCount = 0
        
        for jobId in operation.jobIds {
            do {
                let result: AdminActionResult
                
                switch operation.type {
                case .cancel(let reason, let cancelledBy):
                    result = try await cancelJob(jobId, reason: reason, cancelledBy: cancelledBy, force: operation.force)
                case .retry(let reason, let requestedBy):
                    result = try await retryJob(jobId, retryReason: reason, requestedBy: requestedBy)
                }
                
                results[jobId] = result
                successCount += 1
                
            } catch {
                results[jobId] = AdminActionResult(
                    success: false,
                    message: error.localizedDescription,
                    affectedJobs: [jobId]
                )
                failureCount += 1
            }
        }
        
        // Record bulk operation in audit trail
        await auditTrail.recordSystemEvent(
            eventType: .systemEvent,
            description: "Bulk job operation: \(operation.type)",
            systemInfo: [
                "operation": operation.type.rawValue,
                "jobCount": operation.jobIds.count,
                "successCount": successCount,
                "failureCount": failureCount,
                "requestedBy": operation.requestedBy
            ]
        )
        
        return BulkJobResult(
            operation: operation,
            results: results,
            successCount: successCount,
            failureCount: failureCount,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func getJobTypeBreakdown() async -> [String: Int] {
        let records = try! await unifiedQueue.listJobs()
        return Dictionary(grouping: records) { $0.job.typeId }.mapValues { $0.count }
    }
    
    private func getRecentActivity(hours: Int) async -> [RecentActivity] {
        let cutoff = Date().addingTimeInterval(-TimeInterval(hours * 3600))
        let entries = await auditTrail.getAuditEntries(startDate: cutoff)
        
        return entries.map { entry in
            RecentActivity(
                timestamp: entry.timestamp,
                type: entry.eventType,
                jobId: entry.jobId,
                description: "\(entry.eventType.rawValue) - \(entry.jobId?.raw ?? "System")"
            )
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func analyzeErrorPatterns(from entries: [JobAuditEntry]) -> [ErrorPattern] {
        let errorEntries = entries.filter { $0.eventType == .jobFailed }
        
        // Group by error message patterns
        let errorGroups = Dictionary(grouping: errorEntries) { entry in
            // Extract error pattern (simplified)
            let message = entry.data["error"] as? String ?? ""
            return extractErrorPattern(from: message)
        }
        
        return errorGroups.map { (pattern, entries) in
            ErrorPattern(
                pattern: pattern,
                count: entries.count,
                lastOccurrence: entries.max { $0.timestamp < $1.timestamp }?.timestamp ?? Date(),
                jobIds: entries.compactMap { $0.jobId }
            )
        }.sorted { $0.count > $1.count }
    }
    
    private func extractErrorPattern(from errorMessage: String) -> String {
        // Simple pattern extraction - could be enhanced with ML
        let patterns = [
            "timeout",
            "connection",
            "authentication",
            "permission",
            "not found",
            "invalid",
            "quota",
            "memory"
        ]
        
        for pattern in patterns {
            if errorMessage.lowercased().contains(pattern) {
                return pattern
            }
        }
        
        return "other"
    }
    
    private func generateRecommendations(for jobType: String, analysis: JobTypeStats?) -> [String] {
        guard let analysis = analysis else { return [] }
        
        var recommendations: [String] = []
        
        // Success rate recommendations
        if analysis.successRate < 0.9 {
            recommendations.append("Consider investigating failure patterns - success rate is \(Int(analysis.successRate * 100))%")
        }
        
        // Timeout recommendations
        if analysis.timeoutRate > 0.1 {
            recommendations.append("High timeout rate (\(Int(analysis.timeoutRate * 100))%) - consider increasing timeout or optimizing performance")
        }
        
        // Execution time recommendations
        if analysis.averageExecutionTime > 300 { // 5 minutes
            recommendations.append("Long execution times - consider optimizing workflow or increasing timeout")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

/// Request for listing jobs.
public struct JobListRequest: Codable, Sendable {
    public let statuses: Set<JobStatus>?
    public let jobType: String?
    public let userId: String?
    public let createdAfter: Date?
    public let createdBefore: Date?
    public let sortBy: JobSortField
    public let sortOrder: SortOrder
    public let page: Int
    public let pageSize: Int
    
    public init(
        statuses: Set<JobStatus>? = nil,
        jobType: String? = nil,
        userId: String? = nil,
        createdAfter: Date? = nil,
        createdBefore: Date? = nil,
        sortBy: JobSortField = .createdAt,
        sortOrder: SortOrder = .descending,
        page: Int = 0,
        pageSize: Int = 50
    ) {
        self.statuses = statuses
        self.jobType = jobType
        self.userId = userId
        self.createdAfter = createdAfter
        self.createdBefore = createdBefore
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.page = page
        self.pageSize = pageSize
    }
}

/// Response for job list requests.
public struct JobListResponse: Codable, Sendable {
    public let jobs: [JobRecord]
    public let total: Int
    public let page: Int
    public let pageSize: Int
    public let hasMore: Bool
}

/// Detailed job information.
public struct JobDetails: Codable, Sendable {
    public let record: JobRecord?
    public let auditTrail: [JobAuditEntry]
    public let jobTypeStats: JobTypeStats?
    public let timestamp: Date
}

/// System overview information.
public struct SystemOverview: Codable, Sendable {
    public let queueStats: UnifiedQueueStats
    public let overallStats: JobOverallStats
    public let auditStats: AuditStatistics
    public let jobTypeBreakdown: [String: Int]
    public let recentActivity: [RecentActivity]
    public let maintenanceWindows: [MaintenanceWindow]
    public let systemLocks: [SystemLock]
    public let timestamp: Date
}

/// Job type analysis results.
public struct JobTypeAnalysis: Codable, Sendable {
    public let jobType: String
    public let stats: JobTypeStats?
    public let performanceData: [PerformanceDataPoint]
    public let errorPatterns: [ErrorPattern]
    public let recommendations: [String]
    public let timeRange: TimeRange
}

/// Result of administrative action.
public struct AdminActionResult: Codable, Sendable {
    public let success: Bool
    public let message: String
    public let affectedJobs: [JobId]
}

/// Bulk job operation.
public struct BulkJobOperation: Codable, Sendable {
    public let type: BulkOperationType
    public let jobIds: [JobId]
    public let force: Bool
    public let requestedBy: String
}

/// Bulk job operation result.
public struct BulkJobResult: Codable, Sendable {
    public let operation: BulkJobOperation
    public let results: [JobId: AdminActionResult]
    public let successCount: Int
    public let failureCount: Int
    public let timestamp: Date
}

/// Maintenance window.
public struct MaintenanceWindow: Codable, Sendable {
    public let id: UUID
    public var startTime: Date
    public var endTime: Date
    public let reason: String
    public let requestedBy: String
    public let type: MaintenanceType
}

/// System lock.
public struct SystemLock: Codable, Sendable {
    public let id: UUID
    public let resource: String
    public let reason: String
    public let lockedBy: String
    public let lockedAt: Date
    public let expiresAt: Date?
}

/// Recent activity entry.
public struct RecentActivity: Codable, Sendable {
    public let timestamp: Date
    public let type: AuditEventType
    public let jobId: JobId?
    public let description: String
}

/// Error pattern.
public struct ErrorPattern: Codable, Sendable {
    public let pattern: String
    public let count: Int
    public let lastOccurrence: Date
    public let jobIds: [JobId]
}

/// Admin session.
public struct AdminSession: Codable, Sendable {
    public let id: UUID
    public let userId: String
    public let startedAt: Date
    public let lastActivity: Date
    public let permissions: [AdminPermission]
}

/// Enums and supporting types
public enum JobSortField: String, Codable, CaseIterable {
    case createdAt
    case priority
    case status
    case attempts
}

public enum SortOrder: String, Codable, CaseIterable {
    case ascending
    case descending
}

public enum BulkOperationType: String, Codable {
    case cancel(reason: String, cancelledBy: String)
    case retry(reason: String, requestedBy: String)
}

public enum MaintenanceType: String, Codable {
    case planned
    case emergency
}

public enum AdminPermission: String, Codable, CaseIterable {
    case viewJobs
    case cancelJobs
    case retryJobs
    case pauseProcessing
    case viewMetrics
    case manageNotifications
}

// MARK: - Error Types

public enum AdminError: Error, LocalizedError {
    case jobNotFound(JobId)
    case jobAlreadyCompleted(JobId, JobStatus)
    case jobNotRetryable(JobId, JobStatus)
    case noActiveMaintenanceWindow
    case insufficientPermission(String)
    
    public var errorDescription: String? {
        switch self {
        case .jobNotFound(let jobId):
            return "Job not found: \(jobId)"
        case .jobAlreadyCompleted(let jobId, let status):
            return "Job \(jobId) is already completed with status: \(status)"
        case .jobNotRetryable(let jobId, let status):
            return "Job \(jobId) cannot be retried in status: \(status)"
        case .noActiveMaintenanceWindow:
            return "No active maintenance window found"
        case .insufficientPermission(let permission):
            return "Insufficient permission: \(permission)"
        }
    }
}

// MARK: - Extensions

extension TimeRange {
    var startDate: Date {
        switch self {
        case .lastHour:
            return Date().addingTimeInterval(-3600)
        case .last24Hours:
            return Date().addingTimeInterval(-86400)
        case .last7Days:
            return Date().addingTimeInterval(-86400 * 7)
        case .last30Days:
            return Date().addingTimeInterval(-86400 * 30)
        }
    }
}