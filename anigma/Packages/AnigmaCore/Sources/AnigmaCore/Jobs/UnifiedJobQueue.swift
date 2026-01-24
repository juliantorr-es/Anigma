//
//  UnifiedJobQueue.swift
//  AnigmaCore
//
//  Unified job queue system combining AnigmaCore and DaemonCore capabilities.
//

import Foundation
import AnigmaPrimitives

/// Unified job queue that consolidates AnigmaCore and DaemonCore functionality.
public actor UnifiedJobQueue {
    // MARK: - Configuration
    private let maxConcurrentJobs: Int
    private let workflowRunner: WorkflowRunner
    private let persistence: JobPersistence
    private var circuitBreaker: CircuitBreaker
    private let metricsCollector: JobMetricsCollectorProtocol?
    
    // MARK: - State
    private var queue: [JobRecord] = []
    private var activeJobs: Set<JobId> = []
    private var jobRecords: [JobId: JobRecord] = [:]
    private var activeJobTasks: [JobId: Task<Void, Error>] = [:]
    
    // Background task for processing
    private var processingTask: Task<Void, Never>?
    
    // MARK: - Notification System
    private let notificationCenter = NotificationCenter()
    
    public init(
        maxConcurrentJobs: Int = 8,
        workflowRunner: WorkflowRunner,
        persistence: JobPersistence,
        circuitBreaker: CircuitBreaker = CircuitBreaker(),
        metricsCollector: JobMetricsCollectorProtocol? = nil
    ) {
        self.maxConcurrentJobs = maxConcurrentJobs
        self.workflowRunner = workflowRunner
        self.persistence = persistence
        self.circuitBreaker = circuitBreaker
        self.metricsCollector = metricsCollector
    }
    
    // MARK: - Lifecycle Management
    
    /// Start the unified job queue and restore any active jobs.
    public func start() async throws {
        // Initialize persistence if needed
        if let sqlitePersistence = persistence as? SQLiteJobPersistence {
            try await sqlitePersistence.initialize()
        }
        
        // Restore active jobs from persistence
        await restoreJobs()
        
        // Start background processing
        if processingTask == nil {
            processingTask = Task {
                await MainActor.run {
                    // Run processing loop
                }
                await processingLoop()
            }
        }
        
        await recordMetric(.queueStarted)
        print("UnifiedJobQueue: Started with max concurrency: \(maxConcurrentJobs)")
    }
    
    /// Stop the queue gracefully.
    public func stop() async {
        // Cancel processing task
        processingTask?.cancel()
        processingTask = nil
        
        // Cancel all active jobs with grace period
        for (jobId, task) in activeJobTasks {
            task.cancel()
            await recordMetric(.jobCancelled, jobId: jobId)
        }
        activeJobTasks.removeAll()
        
        await recordMetric(.queueStopped)
        print("UnifiedJobQueue: Stopped")
    }
    
    /// Restore active jobs from persistence after restart.
    private func restoreJobs() async {
        do {
            let activeJobs = try await persistence.loadActiveJobs()
            
            for var record in activeJobs {
                // Reset running jobs to pending (they crashed)
                if record.status == .running {
                    record.status = .pending
                    record.error = "Job was running when system crashed - requeued"
                }
                
                jobRecords[record.id] = record
                enqueue(record)
            }
            
            print("UnifiedJobQueue: Restored \(activeJobs.count) jobs from persistence")
            await recordMetric(.jobsRestored, count: activeJobs.count)
            
        } catch {
            print("UnifiedJobQueue: Failed to restore jobs: \(error)")
        }
    }
    
    // MARK: - Job Submission
    
    /// Submit a new job to the queue.
    public func submit(
        _ job: Job,
        world: World? = nil
    ) async throws -> JobRecord {
        let record = JobRecord(job: job)
        jobRecords[record.id] = record
        
        try await persistence.save(record: record)
        enqueue(record)
        
        await recordMetric(.jobSubmitted, jobId: record.id, jobType: job.typeId)
        await notifyJobStatusChange(record)
        
        print("UnifiedJobQueue: Submitted job \(record.id) (type: \(job.typeId))")
        return record
    }
    
    /// Submit a batch of jobs atomically.
    public func submitBatch(_ jobs: [Job]) async throws -> [JobRecord] {
        var records: [JobRecord] = []
        
        for job in jobs {
            let record = JobRecord(job: job)
            records.append(record)
            jobRecords[record.id] = record
        }
        
        // Save all records
        for record in records {
            try await persistence.save(record: record)
        }
        
        // Enqueue all records
        for record in records {
            enqueue(record)
        }
        
        await recordMetric(.jobsSubmittedBatch, count: jobs.count)
        print("UnifiedJobQueue: Submitted batch of \(jobs.count) jobs")
        
        return records
    }
    
    // MARK: - Queue Management
    
    /// Add a job record to the queue and trigger processing.
    private func enqueue(_ record: JobRecord) {
        guard record.status.isActive else { return }
        
        // Remove existing entry to avoid duplicates
        queue.removeAll { $0.id == record.id }
        queue.append(record)
        sortQueue()
    }
    
    /// Sort queue by priority, deadline, and creation time.
    private func sortQueue() {
        queue.sort { record1, record2 in
            // Priority first
            if record1.job.priority != record2.job.priority {
                return record1.job.priority.rawValue > record2.job.priority.rawValue
            }
            
            // Deadline second (earlier deadline first)
            switch (record1.job.deadline, record2.job.deadline) {
            case (let deadline1?, let deadline2?):
                return deadline1 < deadline2
            case (nil, let deadline2?):
                return true
            case (let deadline1?, nil):
                return false
            case (nil, nil):
                break
            }
            
            // Creation time third (earlier first)
            return record1.job.createdAt < record2.job.createdAt
        }
    }
    
    /// Main processing loop for job execution.
    private func processingLoop() async {
        while !Task.isCancelled {
            await processQueue()
            
            // Sleep briefly between iterations
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                break
            }
        }
    }
    
    /// Process the job queue, executing jobs as capacity allows.
    private func processQueue() async {
        while activeJobs.count < maxConcurrentJobs, !queue.isEmpty {
            guard let record = dequeueNextJob() else { break }
            
            await executeJob(record)
        }
    }
    
    /// Get the next job to execute, considering readiness and deferral.
    private func dequeueNextJob() -> JobRecord? {
        // Clean up queue
        queue.removeAll { !$0.status.isActive }
        
        // Find ready job
        for (index, record) in queue.enumerated() {
            // Check deferral expiration
            if record.isDeferralExpired {
                var readyRecord = record
                readyRecord.status = .pending
                readyRecord.deferralReason = nil
                readyRecord.deferredUntil = nil
                jobRecords[record.id] = readyRecord
                queue[index] = readyRecord
            }
            
            // Check if job is ready and not expired
            guard record.job.isReady && !record.job.isExpired else {
                if record.job.isExpired {
                    var expiredRecord = record
                    expiredRecord.status = .expired
                    expiredRecord.completedAt = Date()
                    jobRecords[record.id] = expiredRecord
                    Task { try? await persistAndNotify(expiredRecord) }
                }
                continue
            }
            
            queue.remove(at: index)
            return record
        }
        
        return nil
    }
    
    // MARK: - Job Execution
    
    /// Execute a job with comprehensive timeout and error handling.
    private func executeJob(_ record: JobRecord) async {
        let jobId = record.job.id
        activeJobs.insert(jobId)
        
        // Update to running state
        var runningRecord = record
        runningRecord.status = .running
        runningRecord.attempts += 1
        runningRecord.lastAttemptAt = Date()
        jobRecords[jobId] = runningRecord
        
        await persistAndNotify(runningRecord)
        await recordMetric(.jobStarted, jobId: jobId, jobType: record.job.typeId)
        
        // Calculate timeout
        let timeoutPolicy = record.job.timeoutPolicy ?? .default
        let baseTimeout = timeoutPolicy.effectiveTimeout(jobTimeout: record.job.timeoutDuration)
        
        // Launch the job in a detached task
        let task: Task<Void, any Error> = Task {
            do {
                // Check circuit breaker first
                if circuitBreaker.isOpen {
                    throw JobError.executionFailed("Circuit breaker is open")
                }

                let result = try await executeWithTimeout(
                    record: runningRecord,
                    timeout: baseTimeout,
                    timeoutPolicy: timeoutPolicy
                )
                
                // Handle successful completion
                await completeJob(jobId: jobId, result: result, timedOut: false)
                
            } catch {
                // Handle execution errors
                let timedOut: Bool
                if case JobError.executionTimeout = error {
                    timedOut = true
                } else {
                    timedOut = false
                }
                await failJob(jobId: jobId, error: error, timedOut: timedOut)
            }
            
            // Clean up
            activeJobs.remove(jobId)
            activeJobTasks.removeValue(forKey: jobId)
            
            // Continue processing
            Task { await processQueue() }
        }
        
        activeJobTasks[jobId] = task
    }
    
    /// Execute job with timeout enforcement and progress monitoring.
    private func executeWithTimeout(
        record: JobRecord,
        timeout: TimeInterval,
        timeoutPolicy: TimeoutPolicy
    ) async throws -> JobResult {
        return try await withThrowingTaskGroup(of: JobResult.self) { group in
            // Add main execution task
            group.addTask {
                return try await self.workflowRunner.execute(job: record.job, in: self.getWorld())
            }
            
            // Add timeout task if timeout is finite
            if timeout.isFinite {
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    throw JobError.executionTimeout(record.id, timeout)
                }
            }
            
            // Wait for first completion
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// Get the world instance for job execution.
    private func getWorld() -> World {
        // TODO: Implement proper world injection
        fatalError("World injection not implemented")
    }
    
    // MARK: - Job Completion Handling
    
    /// Handle successful job completion.
    private func completeJob(jobId: JobId, result: JobResult, timedOut: Bool) async {
        guard var record = jobRecords[jobId] else { return }
        
        record.status = .completed
        record.completedAt = Date()
        record.result = result
        
        if timedOut {
            record.error = "Job completed successfully but exceeded timeout"
        }
        
        jobRecords[jobId] = record
        await persistAndNotify(record)
        
        let metric: JobMetricType = timedOut ? .jobCompletedWithTimeout : .jobCompleted
        await recordMetric(metric, jobId: jobId, jobType: record.job.typeId, duration: result.durationMs)
        
        print("UnifiedJobQueue: Job \(jobId) completed in \(result.durationMs)ms")
    }
    
    /// Handle job failure with retry logic.
    private func failJob(jobId: JobId, error: Error, timedOut: Bool) async {
        guard var record = jobRecords[jobId] else { return }
        
        record.status = .failed
        record.completedAt = Date()
        record.error = error.localizedDescription
        
        jobRecords[jobId] = record
        await persistAndNotify(record)
        
        // Check retry eligibility
        let shouldRetry = record.canRetry && 
                          !timedOut && 
                          isRetryableError(error) &&
                          circuitBreaker.state != .open
        
        if shouldRetry {
            let retryTime = record.nextRetryAt ?? Date()
            var retryRecord = record
            retryRecord.status = .retrying
            retryRecord.deferredUntil = retryTime
            retryRecord.deferralReason = "Scheduled retry due to: \(error.localizedDescription)"
            
            jobRecords[jobId] = retryRecord
            await persistAndNotify(retryRecord)
            
            // Schedule retry
            Task {
                try? await Task.sleep(for: .seconds(retryTime.timeIntervalSinceNow))
                await enqueue(retryRecord)
            }
            
            await recordMetric(.jobRetried, jobId: jobId, jobType: record.job.typeId)
            print("UnifiedJobQueue: Job \(jobId) failed, retry scheduled at \(retryTime)")
            
        } else {
            await recordMetric(.jobFailed, jobId: jobId, jobType: record.job.typeId)
            print("UnifiedJobQueue: Job \(jobId) failed permanently: \(error)")
        }
        
        // Update circuit breaker
        if shouldRetry {
            circuitBreaker.recordFailure()
        } else {
            circuitBreaker.recordSuccess()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if an error is retryable.
    private func isRetryableError(_ error: Error) -> Bool {
        switch error {
        case JobError.executionFailed, JobError.executionTimeout:
            return true
        case JobError.jobNotFound, JobError.invalidState, JobError.queueFull:
            return false
        default:
            return true // Default to retryable for unknown errors
        }
    }
    
    /// Persist record and send notifications.
    private func persistAndNotify(_ record: JobRecord) async {
        do {
            try await persistence.save(record: record)
            await notifyJobStatusChange(record)
        } catch {
            print("UnifiedJobQueue: Failed to persist record \(record.id): \(error)")
        }
    }
    
    /// Send job status change notification.
    private func notifyJobStatusChange(_ record: JobRecord) async {
        let userInfo: [String: Any] = [
            "jobId": record.id.raw,
            "status": record.status.rawValue,
            "jobType": record.job.typeId,
            "record": record
        ]
        
        notificationCenter.post(name: .jobStatusDidChange, object: nil, userInfo: userInfo)
    }
    
    /// Record job metrics.
    private func recordMetric(_ type: JobMetricType, jobId: JobId? = nil, jobType: String? = nil, duration: Int64? = nil, count: Int? = nil) async {
        await metricsCollector?.record(
            type: type,
            jobId: jobId,
            jobType: jobType,
            duration: duration,
            count: count
        )
    }
    
    // MARK: - Public API
    
    /// Cancel a job.
    public func cancel(jobId: JobId) async throws {
        guard let record = jobRecords[jobId] else {
            throw JobError.jobNotFound(jobId)
        }
        
        // Cancel running task
        if let task = activeJobTasks[jobId] {
            task.cancel()
        }
        
        // Remove from queue
        queue.removeAll { $0.id == jobId }
        
        // Update status
        var cancelledRecord = record
        cancelledRecord.status = .cancelled
        cancelledRecord.completedAt = Date()
        jobRecords[jobId] = cancelledRecord
        
        await persistAndNotify(cancelledRecord)
        await recordMetric(.jobCancelled, jobId: jobId, jobType: record.job.typeId)
        
        print("UnifiedJobQueue: Job \(jobId) cancelled")
    }
    
    /// Get job record.
    public func getJob(_ jobId: JobId) -> JobRecord? {
        return jobRecords[jobId]
    }
    
    /// Get queue statistics.
    public func getStats() -> UnifiedQueueStats {
        return UnifiedQueueStats(
            queued: queue.count,
            running: activeJobs.count,
            total: jobRecords.count,
            circuitBreakerState: circuitBreaker.state
        )
    }
    
    /// List jobs with filtering and pagination.
    public func listJobs(
        status: Set<JobStatus>? = nil,
        jobType: String? = nil,
        limit: Int? = nil
    ) async throws -> [JobRecord] {
        var records = Array(jobRecords.values)
        
        // Filter by status
        if let status = status {
            records = records.filter { status.contains($0.status) }
        }
        
        // Filter by job type
        if let jobType = jobType {
            records = records.filter { $0.job.typeId == jobType }
        }
        
        // Sort by creation time (newest first)
        records.sort { $0.job.createdAt > $1.job.createdAt }
        
        // Apply limit
        if let limit = limit {
            records = Array(records.prefix(limit))
        }
        
        return records
    }
    
    /// Retry a failed job.
    public func retry(_ jobId: JobId) async throws {
        guard var record = jobRecords[jobId] else {
            throw JobError.jobNotFound(jobId)
        }
        
        guard record.status == .failed else {
            throw JobError.invalidState(current: record.status, expected: .failed)
        }
        
        // Reset for retry
        record.status = .pending
        record.error = nil
        record.deferredUntil = nil
        record.deferralReason = "Manual retry"
        
        jobRecords[jobId] = record
        await persistAndNotify(record)
        enqueue(record)
        
        await recordMetric(.jobManuallyRetried, jobId: jobId, jobType: record.job.typeId)
        print("UnifiedJobQueue: Manually retrying job \(jobId)")
    }
}

// MARK: - Supporting Types

/// Unified queue statistics.
public struct UnifiedQueueStats: Sendable, Codable {
    public let queued: Int
    public let running: Int
    public let total: Int
    public let circuitBreakerState: CircuitBreakerState
}

/// Job metrics collector protocol.
public protocol JobMetricsCollectorProtocol: Sendable {
    func record(
        type: JobMetricType,
        jobId: JobId?,
        jobType: String?,
        duration: Int64?,
        count: Int?
    ) async
    
    func getOverallStats() async -> JobOverallStats
    func getJobTypeStats(_ jobType: String) async -> JobTypeStats?
    func getPerformanceMetrics(timeRange: TimeRange, jobType: String?) async -> [PerformanceDataPoint]
}

/// Types of job metrics.
public enum JobMetricType: String, Sendable, Codable, CaseIterable {
    case queueStarted
    case queueStopped
    case jobsRestored
    case jobSubmitted
    case jobsSubmittedBatch
    case jobStarted
    case jobCompleted
    case jobCompletedWithTimeout
    case jobFailed
    case jobCancelled
    case jobRetried
    case jobManuallyRetried
}

// MARK: - Notification Names

extension Notification.Name {
    static let jobStatusDidChange = Notification.Name("JobStatusDidChange")
}