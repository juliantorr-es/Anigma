import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - Queue Manager

/// Actor-based job queue manager with priority support and concurrent processing
public actor QueueManager: Sendable {
    
    // MARK: - Properties
    
    /// Diagnostics for observability
    private let diagnostics: CapsuleDiagnostics
    
    /// Configuration for the queue manager
    private let configuration: QueueManagerConfiguration
    
    /// Priority queues for different job priorities
    private var priorityQueues: [JobPriority: [Job]] = [:]
    
    /// Active workers processing jobs
    private var workers: [Worker] = []
    
    /// Job tracking for correlation and monitoring
    private var activeJobs: [String: Job] = [:]
    private var completedJobs: [String: Job] = [:]
    private var failedJobs: [String: Job] = [:]
    
    /// Queue statistics
    private var statistics: QueueStatistics
    
    /// Event listeners
    private var eventListeners: [QueueEventListener] = []
    
    /// Shutdown flag
    private var isShutdown: Bool = false
    
    // MARK: - Initialization
    
    /// Initialize QueueManager
    /// - Parameters:
    ///   - diagnostics: Diagnostics collector for observability
    ///   - configuration: Queue manager configuration
    public init(
        diagnostics: CapsuleDiagnostics,
        configuration: QueueManagerConfiguration = .default
    ) async {
        self.diagnostics = diagnostics
        self.configuration = configuration
        self.statistics = QueueStatistics()
        
        // Initialize priority queues
        for priority in JobPriority.allCases {
            priorityQueues[priority] = []
        }
        
        // Start workers
        await startWorkers()
        
        let span = diagnostics.beginSpan(
            name: "QueueManager.init",
            category: "queue.initialization",
            correlationID: nil,
            tags: ["worker_count": "\(configuration.workerCount)"]
        )
        
        span.end(status: .ok)
        
        diagnostics.event(
            level: .info,
            category: "queue.initialization",
            message: "QueueManager initialized with \(configuration.workerCount) workers",
            correlationID: nil,
            metadata: ["worker_count": "\(configuration.workerCount)"]
        )
    }
    
    deinit {
        Task {
            await shutdown()
        }
    }
    
    // MARK: - Public API
    
    /// Submit a job to the queue
    /// - Parameters:
    ///   - job: Job to submit
    ///   - correlationID: Request ID for tracing
    /// - Returns: Job ID for tracking
    /// - Throws: CapsuleError if submission fails
    public func submitJob(
        _ job: Job,
        correlationID: String? = nil
    ) async throws -> String {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "QueueManager.submitJob",
            category: "queue.submission",
            correlationID: corrID,
            tags: [
                "job_type": job.type,
                "priority": job.priority.rawValue
            ]
        )
        
        guard !isShutdown else {
            span.end(status: .error)
            throw CapsuleError.operationFailed(
                code: 3001,
                message: "QueueManager is shutdown",
                context: ["job_id": job.id]
            )
        }
        
        // Validate job
        try validateJob(job)
        
        // Add to appropriate priority queue
        priorityQueues[job.priority]?.append(job)
        activeJobs[job.id] = job
        
        // Update statistics
        statistics.totalJobsSubmitted += 1
        statistics.queueLength = priorityQueues.values.map { $0.count }.reduce(0, +)
        
        // Notify workers
        await notifyWorkers()
        
        // Notify listeners
        await notifyJobSubmitted(job)
        
        span.end(status: .ok)
        
        diagnostics.event(
            level: .debug,
            category: "queue.submission",
            message: "Job submitted: \(job.type)",
            correlationID: corrID,
            metadata: [
                "job_id": job.id,
                "priority": job.priority.rawValue,
                "queue_length": "\(statistics.queueLength)"
            ]
        )
        
        return job.id
    }
    
    /// Get job status
    /// - Parameters:
    ///   - jobID: Unique identifier of the job
    ///   - correlationID: Request ID for tracing
    /// - Returns: Job status if found
    public func getJobStatus(
        _ jobID: String,
        correlationID: String? = nil
    ) async -> JobStatus? {
        if let job = activeJobs[jobID] {
            return job.status
        } else if let job = completedJobs[jobID] {
            return job.status
        } else if let job = failedJobs[jobID] {
            return job.status
        }
        return nil
    }
    
    /// Get job details
    /// - Parameters:
    ///   - jobID: Unique identifier of the job
    ///   - correlationID: Request ID for tracing
    /// - Returns: Job details if found
    public func getJob(
        _ jobID: String,
        correlationID: String? = nil
    ) async -> Job? {
        return activeJobs[jobID] ?? completedJobs[jobID] ?? failedJobs[jobID]
    }
    
    /// Cancel a job
    /// - Parameters:
    ///   - jobID: Unique identifier of the job
    ///   - correlationID: Request ID for tracing
    /// - Returns: True if job was cancelled
    /// - Throws: CapsuleError if cancellation fails
    public func cancelJob(
        _ jobID: String,
        correlationID: String? = nil
    ) async throws -> Bool {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "QueueManager.cancelJob",
            category: "queue.cancellation",
            correlationID: corrID,
            tags: ["job_id": jobID]
        )
        
        defer { span.end(status: .ok) }
        
        guard var job = activeJobs[jobID] else {
            return false
        }
        
        // Can only cancel pending jobs
        guard job.status == .pending else {
            return false
        }
        
        // Remove from queue
        priorityQueues[job.priority]?.removeAll { $0.id == jobID }
        activeJobs.removeValue(forKey: jobID)
        
        // Update job status
        job.status = .cancelled
        job.endTime = Date()
        job.result = .cancelled
        
        // Track cancelled job
        failedJobs[jobID] = job
        
        // Update statistics
        statistics.totalJobsCancelled += 1
        statistics.queueLength = priorityQueues.values.map { $0.count }.reduce(0, +)
        
        // Notify listeners
        await notifyJobCancelled(job)
        
        diagnostics.event(
            level: .info,
            category: "queue.cancellation",
            message: "Job cancelled: \(jobID)",
            correlationID: corrID,
            metadata: ["job_id": jobID]
        )
        
        return true
    }
    
    /// Get queue statistics
    /// - Returns: Current queue statistics
    public func getStatistics() -> QueueStatistics {
        return statistics
    }
    
    /// Get queue health status
    /// - Returns: Health information
    public func getHealthStatus() -> QueueHealth {
        let activeWorkers = workers.filter { $0.isActive }.count
        let utilization = statistics.totalJobsSubmitted > 0 ? 
            Double(statistics.totalJobsCompleted) / Double(statistics.totalJobsSubmitted) : 0.0
        
        return QueueHealth(
            status: isShutdown ? .shutdown : (activeWorkers > 0 ? .healthy : .idle),
            activeWorkers: activeWorkers,
            queueLength: statistics.queueLength,
            utilization: utilization,
            averageProcessingTime: statistics.averageProcessingTime
        )
    }
    
    /// Shutdown the queue manager
    public func shutdown() async {
        guard !isShutdown else { return }
        
        isShutdown = true
        
        // Stop all workers
        for worker in workers {
            await worker.stop()
        }
        workers.removeAll()
        
        // Cancel all pending jobs
        for priority in JobPriority.allCases {
            for job in priorityQueues[priority] ?? [] {
                job.status = .cancelled
                job.endTime = Date()
                job.result = .cancelled
                failedJobs[job.id] = job
            }
            priorityQueues[priority]?.removeAll()
        }
        
        // Clear active jobs
        activeJobs.removeAll()
        
        diagnostics.event(
            level: .info,
            category: "queue.shutdown",
            message: "QueueManager shutdown completed",
            correlationID: nil,
            metadata: [
                "cancelled_jobs": "\(failedJobs.count)",
                "completed_jobs": "\(completedJobs.count)"
            ]
        )
    }
    
    /// Add event listener
    /// - Parameter listener: Event listener
    public func addEventListener(_ listener: QueueEventListener) {
        eventListeners.append(listener)
    }
    
    /// Remove event listener
    /// - Parameter listener: Event listener to remove
    public func removeEventListener(_ listener: QueueEventListener) {
        eventListeners.removeAll { $0.id == listener.id }
    }
    
    // MARK: - Private Methods
    
    private func startWorkers() async {
        for i in 0..<configuration.workerCount {
            let worker = Worker(
                id: "worker-\(i)",
                queueManager: self,
                diagnostics: diagnostics,
                configuration: configuration
            )
            workers.append(worker)
            await worker.start()
        }
    }
    
    private func validateJob(_ job: Job) throws {
        guard !job.id.isEmpty else {
            throw CapsuleError.invalidInput(
                field: "job.id",
                constraint: "Job ID cannot be empty"
            )
        }
        
        guard !job.type.isEmpty else {
            throw CapsuleError.invalidInput(
                field: "job.type",
                constraint: "Job type cannot be empty"
            )
        }
        
        guard job.payload != nil else {
            throw CapsuleError.invalidInput(
                field: "job.payload",
                constraint: "Job payload cannot be nil"
            )
        }
        
        // Check queue capacity
        let totalQueueLength = priorityQueues.values.map { $0.count }.reduce(0, +)
        if totalQueueLength >= configuration.maxQueueLength {
            throw CapsuleError.resourceExhausted(
                resource: "queue",
                limit: "\(configuration.maxQueueLength)"
            )
        }
    }
    
    internal func getNextJob() async -> Job? {
        // Check priorities in order
        for priority in JobPriority.allCases {
            if let queue = priorityQueues[priority], !queue.isEmpty {
                return queue.removeFirst()
            }
        }
        return nil
    }
    
    internal func jobStarted(_ job: Job) async {
        job.status = .running
        job.startTime = Date()
        statistics.totalJobsStarted += 1
        statistics.queueLength = priorityQueues.values.map { $0.count }.reduce(0, +)
        
        await notifyJobStarted(job)
    }
    
    internal func jobCompleted(_ job: Job, result: JobResult) async {
        job.status = .completed
        job.endTime = Date()
        job.result = result
        
        // Move from active to completed
        activeJobs.removeValue(forKey: job.id)
        completedJobs[job.id] = job
        
        // Update statistics
        statistics.totalJobsCompleted += 1
        let processingTime = job.endTime!.timeIntervalSince(job.startTime!)
        statistics.totalProcessingTime += processingTime
        statistics.averageProcessingTime = statistics.totalProcessingTime / Double(statistics.totalJobsCompleted)
        
        // Clean up old completed jobs if needed
        if completedJobs.count > configuration.maxCompletedJobs {
            let oldest = completedJobs.min { $0.value.endTime! < $1.value.endTime! }!
            completedJobs.removeValue(forKey: oldest.key)
        }
        
        await notifyJobCompleted(job, result: result)
    }
    
    internal func jobFailed(_ job: Job, error: CapsuleError) async {
        job.status = .failed
        job.endTime = Date()
        job.result = .failed(error)
        
        // Move from active to failed
        activeJobs.removeValue(forKey: job.id)
        failedJobs[job.id] = job
        
        // Update statistics
        statistics.totalJobsFailed += 1
        
        // Clean up old failed jobs if needed
        if failedJobs.count > configuration.maxFailedJobs {
            let oldest = failedJobs.min { $0.value.endTime! < $1.value.endTime! }!
            failedJobs.removeValue(forKey: oldest.key)
        }
        
        await notifyJobFailed(job, error: error)
    }
    
    private func notifyWorkers() async {
        // Wake up all workers to check for new jobs
        for worker in workers {
            await worker.wakeUp()
        }
    }
    
    private func notifyJobSubmitted(_ job: Job) async {
        let event = QueueEvent.jobSubmitted(job)
        for listener in eventListeners {
            await listener.handleEvent(event)
        }
    }
    
    private func notifyJobStarted(_ job: Job) async {
        let event = QueueEvent.jobStarted(job)
        for listener in eventListeners {
            await listener.handleEvent(event)
        }
    }
    
    private func notifyJobCompleted(_ job: Job, result: JobResult) async {
        let event = QueueEvent.jobCompleted(job, result: result)
        for listener in eventListeners {
            await listener.handleEvent(event)
        }
    }
    
    private func notifyJobFailed(_ job: Job, error: CapsuleError) async {
        let event = QueueEvent.jobFailed(job, error: error)
        for listener in eventListeners {
            await listener.handleEvent(event)
        }
    }
    
    private func notifyJobCancelled(_ job: Job) async {
        let event = QueueEvent.jobCancelled(job)
        for listener in eventListeners {
            await listener.handleEvent(event)
        }
    }
}

// MARK: - Supporting Types

/// Job priority levels
public enum JobPriority: String, CaseIterable, Codable, Sendable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
    
    var sortWeight: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .normal: return 2
        case .low: return 1
        }
    }
}

/// Job status
public enum JobStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

/// Job result
public enum JobResult: Codable, Sendable {
    case success(Data)
    case failed(CapsuleError)
    case cancelled
    case timeout
    
    public var isSuccess: Bool {
        switch self {
        case .success: return true
        default: return false
        }
    }
}

/// Job definition
public final class Job: Codable, Sendable, Identifiable {
    public let id: String
    public let type: String
    public let priority: JobPriority
    public let payload: Data
    public let metadata: [String: String]
    public let maxRetries: Int
    public let timeout: TimeInterval
    
    private let lock = NSLock()
    nonisolated(unsafe) private var _status: JobStatus = .pending
    nonisolated(unsafe) private var _startTime: Date?
    nonisolated(unsafe) private var _endTime: Date?
    nonisolated(unsafe) private var _result: JobResult?
    nonisolated(unsafe) private var _retryCount: Int = 0
    
    public var status: JobStatus {
        lock.lock()
        defer { lock.unlock() }
        return _status
    }
    
    public var startTime: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _startTime
    }
    
    public var endTime: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _endTime
    }
    
    public var result: JobResult? {
        lock.lock()
        defer { lock.unlock() }
        return _result
    }
    
    public var retryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _retryCount
    }
    
    public init(
        id: String = UUID().uuidString,
        type: String,
        priority: JobPriority = .normal,
        payload: Data,
        metadata: [String: String] = [:],
        maxRetries: Int = 3,
        timeout: TimeInterval = 30.0
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.payload = payload
        self.metadata = metadata
        self.maxRetries = maxRetries
        self.timeout = timeout
    }
    
    internal func incrementRetryCount() {
        lock.lock()
        defer { lock.unlock() }
        _retryCount += 1
    }
    
    internal func setStatus(_ newStatus: JobStatus) {
        lock.lock()
        defer { lock.unlock() }
        _status = newStatus
    }
    
    internal func setStartTime(_ startTime: Date) {
        lock.lock()
        defer { lock.unlock() }
        _startTime = startTime
    }
    
    internal func setEndTime(_ endTime: Date) {
        lock.lock()
        defer { lock.unlock() }
        _endTime = endTime
    }
    
    internal func setResult(_ result: JobResult) {
        lock.lock()
        defer { lock.unlock() }
        _result = result
    }
}

/// Queue manager configuration
public struct QueueManagerConfiguration: Sendable {
    public let workerCount: Int
    public let maxQueueLength: Int
    public let maxCompletedJobs: Int
    public let maxFailedJobs: Int
    public let workerIdleTimeout: TimeInterval
    public let enableMetrics: Bool
    
    public static let `default` = QueueManagerConfiguration(
        workerCount: 4,
        maxQueueLength: 1000,
        maxCompletedJobs: 100,
        maxFailedJobs: 100,
        workerIdleTimeout: 60.0,
        enableMetrics: true
    )
    
    public init(
        workerCount: Int = 4,
        maxQueueLength: Int = 1000,
        maxCompletedJobs: Int = 100,
        maxFailedJobs: Int = 100,
        workerIdleTimeout: TimeInterval = 60.0,
        enableMetrics: Bool = true
    ) {
        self.workerCount = workerCount
        self.maxQueueLength = maxQueueLength
        self.maxCompletedJobs = maxCompletedJobs
        self.maxFailedJobs = maxFailedJobs
        self.workerIdleTimeout = workerIdleTimeout
        self.enableMetrics = enableMetrics
    }
}

/// Queue statistics
public struct QueueStatistics: Codable, Sendable {
    public var totalJobsSubmitted: Int = 0
    public var totalJobsStarted: Int = 0
    public var totalJobsCompleted: Int = 0
    public var totalJobsFailed: Int = 0
    public var totalJobsCancelled: Int = 0
    public var queueLength: Int = 0
    public var totalProcessingTime: TimeInterval = 0.0
    public var averageProcessingTime: TimeInterval = 0.0
    
    public init() {}
}

/// Queue health status
public struct QueueHealth: Codable, Sendable {
    public let status: QueueStatus
    public let activeWorkers: Int
    public let queueLength: Int
    public let utilization: Double
    public let averageProcessingTime: TimeInterval
    
    public init(
        status: QueueStatus,
        activeWorkers: Int,
        queueLength: Int,
        utilization: Double,
        averageProcessingTime: TimeInterval
    ) {
        self.status = status
        self.activeWorkers = activeWorkers
        self.queueLength = queueLength
        self.utilization = utilization
        self.averageProcessingTime = averageProcessingTime
    }
}

/// Queue status
public enum QueueStatus: String, Codable, Sendable {
    case healthy
    case degraded
    case idle
    case shutdown
    case error
}