import Foundation

// MARK: - Queue Events

/// Events emitted by the QueueManager
public enum QueueEvent: Sendable {
    case jobSubmitted(Job)
    case jobStarted(Job)
    case jobCompleted(Job, result: JobResult)
    case jobFailed(Job, error: CapsuleError)
    case jobCancelled(Job)
    case workerStarted(String)
    case workerStopped(String)
    case queueFull
    case queueEmpty
    case shutdownCompleted
}

/// Queue event listener
public actor QueueEventListener: Identifiable, Sendable {
    public let id: String
    private let handler: (QueueEvent) async -> Void
    
    public init(id: String = UUID().uuidString, handler: @escaping (QueueEvent) async -> Void) {
        self.id = id
        self.handler = handler
    }
    
    func handleEvent(_ event: QueueEvent) async {
        await handler(event)
    }
}

// MARK: - Job Extensions

extension Job: CustomStringConvertible {
    public var description: String {
        return "Job(id: \(id), type: \(type), priority: \(priority.rawValue), status: \(status.rawValue))"
    }
}

// MARK: - Utility Functions

/// Create a simple job
public func job(
    type: String,
    payload: Data,
    priority: JobPriority = .normal,
    metadata: [String: String] = [:]
) -> Job {
    return Job(
        type: type,
        priority: priority,
        payload: payload,
        metadata: metadata
    )
}

/// Create a job with string payload
public func job(
    type: String,
    payload: String,
    priority: JobPriority = .normal,
    metadata: [String: String] = [:]
) -> Job {
    return Job(
        type: type,
        priority: priority,
        payload: payload.data(using: .utf8) ?? Data(),
        metadata: metadata
    )
}

/// Create a job with JSON payload
public func job<T: Codable>(
    type: String,
    payload: T,
    priority: JobPriority = .normal,
    metadata: [String: String] = [:]
) throws -> Job {
    let data = try JSONEncoder().encode(payload)
    return Job(
        type: type,
        priority: priority,
        payload: data,
        metadata: metadata
    )
}

/// Job builder for fluent API
public class JobBuilder {
    private var id: String = UUID().uuidString
    private var type: String = ""
    private var priority: JobPriority = .normal
    private var payload: Data = Data()
    private var metadata: [String: String] = [:]
    private var maxRetries: Int = 3
    private var timeout: TimeInterval = 30.0
    
    public init() {}
    
    public func id(_ id: String) -> JobBuilder {
        self.id = id
        return self
    }
    
    public func type(_ type: String) -> JobBuilder {
        self.type = type
        return self
    }
    
    public func priority(_ priority: JobPriority) -> JobBuilder {
        self.priority = priority
        return self
    }
    
    public func payload(_ payload: Data) -> JobBuilder {
        self.payload = payload
        return self
    }
    
    public func payload(_ payload: String) -> JobBuilder {
        self.payload = payload.data(using: .utf8) ?? Data()
        return self
    }
    
    public func payload<T: Codable>(_ payload: T) throws -> JobBuilder {
        self.payload = try JSONEncoder().encode(payload)
        return self
    }
    
    public func metadata(_ metadata: [String: String]) -> JobBuilder {
        self.metadata = metadata
        return self
    }
    
    public func metadata(key: String, value: String) -> JobBuilder {
        self.metadata[key] = value
        return self
    }
    
    public func maxRetries(_ maxRetries: Int) -> JobBuilder {
        self.maxRetries = maxRetries
        return self
    }
    
    public func timeout(_ timeout: TimeInterval) -> JobBuilder {
        self.timeout = timeout
        return self
    }
    
    public func build() -> Job {
        return Job(
            id: id,
            type: type,
            priority: priority,
            payload: payload,
            metadata: metadata,
            maxRetries: maxRetries,
            timeout: timeout
        )
    }
}

/// Job template for reusable job configurations
public struct JobTemplate: Sendable {
    public let type: String
    public let priority: JobPriority
    public let defaultMetadata: [String: String]
    public let maxRetries: Int
    public let timeout: TimeInterval
    
    public init(
        type: String,
        priority: JobPriority = .normal,
        defaultMetadata: [String: String] = [:],
        maxRetries: Int = 3,
        timeout: TimeInterval = 30.0
    ) {
        self.type = type
        self.priority = priority
        self.defaultMetadata = defaultMetadata
        self.maxRetries = maxRetries
        self.timeout = timeout
    }
    
    public func createJob(payload: Data, metadata: [String: String] = [:]) -> Job {
        var combinedMetadata = defaultMetadata
        for (key, value) in metadata {
            combinedMetadata[key] = value
        }
        
        return Job(
            type: type,
            priority: priority,
            payload: payload,
            metadata: combinedMetadata,
            maxRetries: maxRetries,
            timeout: timeout
        )
    }
    
    public func createJob(payload: String, metadata: [String: String] = [:]) -> Job {
        return createJob(payload: payload.data(using: .utf8) ?? Data(), metadata: metadata)
    }
    
    public func createJob<T: Codable>(payload: T, metadata: [String: String] = [:]) throws -> Job {
        let data = try JSONEncoder().encode(payload)
        return createJob(payload: data, metadata: metadata)
    }
}

/// Job filter for querying jobs
public struct JobFilter: Sendable {
    public let types: Set<String>?
    public let priorities: Set<JobPriority>?
    public let statuses: Set<JobStatus>?
    public let createdAfter: Date?
    public let createdBefore: Date?
    public let limit: Int?
    
    public init(
        types: Set<String>? = nil,
        priorities: Set<JobPriority>? = nil,
        statuses: Set<JobStatus>? = nil,
        createdAfter: Date? = nil,
        createdBefore: Date? = nil,
        limit: Int? = nil
    ) {
        self.types = types
        self.priorities = priorities
        self.statuses = statuses
        self.createdAfter = createdAfter
        self.createdBefore = createdBefore
        self.limit = limit
    }
    
    public func matches(_ job: Job) -> Bool {
        if let types = types, !types.contains(job.type) {
            return false
        }
        
        if let priorities = priorities, !priorities.contains(job.priority) {
            return false
        }
        
        if let statuses = statuses, !statuses.contains(job.status) {
            return false
        }
        
        // Note: Job doesn't have creation timestamp in current implementation
        // This would need to be added for time-based filtering
        
        return true
    }
}

/// Queue performance metrics
public struct QueueMetrics: Codable, Sendable {
    public let timestamp: Date
    public let totalJobs: Int
    public let pendingJobs: Int
    public let runningJobs: Int
    public let completedJobs: Int
    public let failedJobs: Int
    public let cancelledJobs: Int
    public let averageProcessingTime: TimeInterval
    public let throughputPerSecond: Double
    public let errorRate: Double
    
    public init(
        timestamp: Date = Date(),
        totalJobs: Int,
        pendingJobs: Int,
        runningJobs: Int,
        completedJobs: Int,
        failedJobs: Int,
        cancelledJobs: Int,
        averageProcessingTime: TimeInterval,
        throughputPerSecond: Double,
        errorRate: Double
    ) {
        self.timestamp = timestamp
        self.totalJobs = totalJobs
        self.pendingJobs = pendingJobs
        self.runningJobs = runningJobs
        self.completedJobs = completedJobs
        self.failedJobs = failedJobs
        self.cancelledJobs = cancelledJobs
        self.averageProcessingTime = averageProcessingTime
        self.throughputPerSecond = throughputPerSecond
        self.errorRate = errorRate
    }
}

/// Job correlation tracking
public struct JobCorrelation: Sendable {
    public let correlationID: String
    public let jobIDs: [String]
    public let status: CorrelationStatus
    public let startTime: Date
    public let endTime: Date?
    
    public init(
        correlationID: String,
        jobIDs: [String],
        status: CorrelationStatus,
        startTime: Date,
        endTime: Date? = nil
    ) {
        self.correlationID = correlationID
        self.jobIDs = jobIDs
        self.status = status
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// Correlation status
public enum CorrelationStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case partial
}