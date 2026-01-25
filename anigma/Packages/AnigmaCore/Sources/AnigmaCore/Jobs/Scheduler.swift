//
//  Scheduler.swift
//  AnigmaCore
//
//  Enhanced job scheduler with timeout enforcement, retry logic, and recovery.
//

import Foundation
import AnigmaPrimitives

public actor Scheduler {
    // MARK: - Configuration
    private let maxConcurrentJobs: Int
    private let workflowRunner: WorkflowRunner
    private let persistence: JobPersistence?
    
    // MARK: - State
    private var queue: [JobRecord] = []
    private var activeJobs: Set<JobId> = []
    private var jobRecords: [JobId: JobRecord] = [:]
    
    // Circuit breaker for resilient execution
    private let circuitBreaker: CircuitBreaker
    
    // Timeout tracking for active jobs
    private var activeJobTasks: [JobId: Task<Void, Error>] = [:]
    
    public init(
        maxConcurrentJobs: Int = 4,
        workflowRunner: WorkflowRunner,
        persistence: JobPersistence? = nil,
        circuitBreaker: CircuitBreaker = CircuitBreaker()
    ) {
        self.maxConcurrentJobs = maxConcurrentJobs
        self.workflowRunner = workflowRunner
        self.persistence = persistence
        self.circuitBreaker = circuitBreaker
    }
    
    // MARK: - Job Submission
    
    /// Submit a job to the queue.
    public func submit(_ job: Job) async throws -> JobRecord {
        let record = JobRecord(job: job)
        jobRecords[record.id] = record
        
        if let persistence = persistence {
            try await persistence.save(record: record)
        }
        
        enqueue(record)
        return record
    }
    
    /// Enqueue a job record for processing.
    private func enqueue(_ record: JobRecord) {
        // Only queue if not already in a terminal state
        guard record.status.isActive else { return }
        
        // Remove from queue if already present (to avoid duplicates)
        queue.removeAll { $0.id == record.id }
        
        // Add to queue and sort by priority and deadline
        queue.append(record)
        sortQueue()
        
        // Trigger processing
        Task { await processQueue() }
    }
    
    /// Sort queue by priority (critical > high > normal > low > background), 
    /// then by deadline (earlier first), then by creation time (earlier first).
    private func sortQueue() {
        queue.sort { record1, record2 in
            // First compare priority
            if record1.job.priority != record2.job.priority {
                return record1.job.priority.rawValue > record2.job.priority.rawValue
            }
            
            // Then compare deadlines (earlier deadline first)
            switch (record1.job.deadline, record2.job.deadline) {
            case (let deadline1?, let deadline2?):
                return deadline1 < deadline2
            case (nil, _?):
                return true // Jobs with deadlines come first
            case (_?, nil):
                return false
            case (nil, nil):
                break
            }
            
            // Finally compare creation time (earlier first)
            return record1.job.createdAt < record2.job.createdAt
        }
    }
    
    // MARK: - Queue Processing
    
    /// Main queue processing loop.
    private func processQueue() async {
        while activeJobs.count < maxConcurrentJobs, !queue.isEmpty {
            guard let record = dequeueNextJob() else { break }
            
            await executeJob(record)
        }
    }
    
    /// Get the next job to execute, considering readiness and deferral.
    private func dequeueNextJob() -> JobRecord? {
        // Remove completed/failed jobs from queue
        queue.removeAll { !$0.status.isActive }
        
        // Find the first ready job
        for (index, record) in queue.enumerated() {
            // Check if job is ready to run
            if record.isDeferralExpired {
                // Deferral expired, make it ready
                var readyRecord = record
                readyRecord.status = .pending
                readyRecord.deferralReason = nil
                readyRecord.deferredUntil = nil
                jobRecords[record.id] = readyRecord
                queue[index] = readyRecord
            }
            
            guard record.job.isReady && !record.job.isExpired else {
                if record.job.isExpired {
                    // Mark expired jobs as expired
                    var expiredRecord = record
                    expiredRecord.status = .expired
                    expiredRecord.completedAt = Date()
                    jobRecords[record.id] = expiredRecord
                    Task { await persistRecord(expiredRecord) }
                }
                continue
            }
            
            queue.remove(at: index)
            return record
        }
        
        return nil
    }
    
    // MARK: - Job Execution
    
    /// Execute a job with timeout enforcement and error handling.
    private func executeJob(_ record: JobRecord) async {
        let jobId = record.job.id
        activeJobs.insert(jobId)
        
        // Update record to running state
        var runningRecord = record
        runningRecord.status = .running
        runningRecord.attempts += 1
        runningRecord.lastAttemptAt = Date()
        jobRecords[jobId] = runningRecord
        await persistRecord(runningRecord)
        
        // Calculate timeout
        let timeoutPolicy = record.job.timeoutPolicy ?? .default
        let effectiveTimeout = timeoutPolicy.effectiveTimeout(jobTimeout: record.job.timeoutDuration)
        
        // Create execution task with timeout
        let task: Task<Void, any Error> = Task {
            do {
                // Execute with timeout
                let result = try await withThrowingTaskGroup(of: JobResult.self) { group in
                    // Add the actual job execution
                    group.addTask {
                        try await self.workflowRunner.execute(job: record.job, in: self.getWorld())
                    }
                    
                    // Add timeout task if specified
                    if effectiveTimeout.isFinite {
                        group.addTask {
                            try await Task.sleep(for: .seconds(effectiveTimeout))
                            throw JobError.executionTimeout(jobId, effectiveTimeout)
                        }
                    }
                    
                    // Wait for first completion (either job finishes or times out)
                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
                
                // Handle successful completion
                await completeJob(jobId: jobId, result: result, timedOut: false)
                
            } catch let error as JobError where error.isTimeout {
                // Handle execution errors
                await failJob(jobId: jobId, error: error, timedOut: true)
            } catch {
                // Handle execution errors
                await failJob(jobId: jobId, error: error, timedOut: false)
            }
        }
        
        activeJobTasks[jobId] = task
        
        // Wait for task completion and continue processing
        _ = await task.result
        activeJobs.remove(jobId)
        activeJobTasks.removeValue(forKey: jobId)
        
        // Continue processing queue
        Task { await processQueue() }
    }
    
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
        await persistRecord(record)
        
        print("Scheduler: Job \(jobId) completed in \(result.durationMs)ms")
    }
    
    /// Handle job failure with retry logic.
    private func failJob(jobId: JobId, error: Error, timedOut: Bool) async {
        guard var record = jobRecords[jobId] else { return }
        
        record.status = .failed
        record.completedAt = Date()
        record.error = error.localizedDescription
        
        jobRecords[jobId] = record
        await persistRecord(record)
        
        // Check if we should retry
        if record.canRetry && !timedOut && isRetryableError(error) {
            let retryDelay = record.nextRetryAt ?? Date()
            var retryRecord = record
            retryRecord.status = .retrying
            retryRecord.deferredUntil = retryDelay
            retryRecord.deferralReason = "Scheduled retry due to: \(error.localizedDescription)"
            
            jobRecords[jobId] = retryRecord
            await persistRecord(retryRecord)
            
            // Schedule retry
            Task {
                try? await Task.sleep(for: .seconds(retryDelay.timeIntervalSinceNow))
                self.enqueue(retryRecord)
            }
            
            print("Scheduler: Job \(jobId) failed, retry scheduled at \(retryDelay)")
        } else {
            print("Scheduler: Job \(jobId) failed permanently: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get the world instance for job execution.
    private func getWorld() -> World {
        // TODO: Implement world injection/retrieval
        fatalError("World injection not implemented")
    }
    
    /// Check if an error is retryable.
    private func isRetryableError(_ error: Error) -> Bool {
        switch error {
        case JobError.executionFailed, JobError.executionTimeout:
            return true
        case JobError.jobNotFound, JobError.invalidState, JobError.queueFull:
            return false
        default:
            // Check circuit breaker state
            return circuitBreaker.state != .open
        }
    }
    
    /// Persist job record if persistence is available.
    private func persistRecord(_ record: JobRecord) async {
        guard let persistence = persistence else { return }
        do {
            try await persistence.save(record: record)
        } catch {
            print("Scheduler: Failed to persist record \(record.id): \(error)")
        }
    }
    
    // MARK: - Public API
    
    /// Cancel a job if it's queued or running.
    public func cancel(jobId: JobId) async throws {
        guard var record = jobRecords[jobId] else {
            throw JobError.jobNotFound(jobId)
        }
        
        // Cancel if running
        if let task = activeJobTasks[jobId] {
            task.cancel()
        }
        
        // Remove from queue if queued
        queue.removeAll { $0.id == jobId }
        
        // Update status
        record.status = .cancelled
        record.completedAt = Date()
        jobRecords[jobId] = record
        
        await persistRecord(record)
        
        print("Scheduler: Job \(jobId) cancelled")
    }
    
    /// Get job status.
    public func getJob(jobId: JobId) -> JobRecord? {
        return jobRecords[jobId]
    }
    
    /// Get queue statistics.
    public func getStats() -> SchedulerStats {
        return SchedulerStats(
            queued: queue.count,
            running: activeJobs.count,
            total: jobRecords.count,
            circuitBreakerState: circuitBreaker.state
        )
    }
}

// MARK: - Supporting Types

public struct SchedulerStats: Sendable {
    public let queued: Int
    public let running: Int
    public let total: Int
    public let circuitBreakerState: CircuitBreakerState
}

public enum CircuitBreakerState: String, Sendable, Codable {
    case closed, open, halfOpen
}

public struct CircuitBreaker: Sendable {
    public private(set) var state: CircuitBreakerState = .closed
    public private(set) var failureCount: Int = 0
    private let failureThreshold: Int = 5
    private let recoveryTimeout: TimeInterval = 30.0
    private var lastFailureTime: Date?
    
    public var isOpen: Bool {
        state == .open
    }
    
    public init() {}
    
    public mutating func recordSuccess() {
        if state == .halfOpen {
            state = .closed
        }
        failureCount = 0
    }
    
    public mutating func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= failureThreshold {
            state = .open
        }
    }
    
    public mutating func attemptReset() {
        if state == .open, let lastFailure = lastFailureTime {
            if Date().timeIntervalSince(lastFailure) >= recoveryTimeout {
                state = .halfOpen
                failureCount = 0
            }
        }
    }
}

// MARK: - JobError Extension

extension JobError {
    public static func executionTimeoutHelper(_ jobId: JobId, _ timeout: TimeInterval) -> JobError {
        return .executionTimeout(jobId, timeout)
    }
}
