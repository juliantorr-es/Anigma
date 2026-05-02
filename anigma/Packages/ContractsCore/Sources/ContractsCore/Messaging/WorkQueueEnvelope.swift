import Foundation

/// Unique identifier for a worker
public struct WorkerId: Hashable, Codable, Sendable {
  public var id: String
  
  public init(_ id: String) {
    self.id = id
  }
}

/// Priority level for job execution (0-100, higher = sooner)
public struct JobPriority: Comparable, Codable, Sendable, Hashable {
  public var level: Int
  
  public init(_ level: Int) {
    self.level = max(0, min(100, level))
  }
  
  public static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
    lhs.level < rhs.level
  }
  
  public static func == (lhs: JobPriority, rhs: JobPriority) -> Bool {
    lhs.level == rhs.level
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(level)
  }
}

/// Retry strategy for failed jobs
public struct RetryPolicy: Codable, Sendable {
  /// Maximum number of attempts (1 = no retry)
  public var maxAttempts: Int
  
  /// Initial retry delay in milliseconds
  public var initialDelayMs: Int
  
  /// Multiplier for exponential backoff (1.0 = fixed delay)
  public var backoffMultiplier: Double
  
  /// Maximum delay between retries in milliseconds
  public var maxDelayMs: Int
  
  /// Whether to move to dead-letter after max attempts
  public var deadLetterAfterFailed: Bool
  
  public init(maxAttempts: Int = 3, initialDelayMs: Int = 1000,
              backoffMultiplier: Double = 2.0, maxDelayMs: Int = 60_000,
              deadLetterAfterFailed: Bool = true) {
    self.maxAttempts = maxAttempts
    self.initialDelayMs = initialDelayMs
    self.backoffMultiplier = backoffMultiplier
    self.maxDelayMs = maxDelayMs
    self.deadLetterAfterFailed = deadLetterAfterFailed
  }
  
  /// Calculate delay for retry attempt (0-indexed)
  public func delayMs(for attempt: Int) -> Int {
    let exponential = initialDelayMs * Int(pow(backoffMultiplier, Double(attempt)))
    return min(exponential, maxDelayMs)
  }
}

/// Standard job envelope for WorkQueue
public struct WorkQueueEnvelope: Codable, Sendable {
  /// Unique job ID
  public var jobId: UUID
  
  /// Idempotency key for deduplication across retries
  public var idempotencyKey: String
  
  /// Job priority (0-100)
  public var priority: JobPriority
  
  /// Job payload as inline data (for small payloads, < 1KB recommended)
  public var payload: Data?
  
  /// Retry strategy
  public var retryPolicy: RetryPolicy
  
  /// Source capability that enqueued this job
  public var sourceCapabilityId: String
  
  /// Project scope
  public var projectId: String
  
  /// Timestamp when job was enqueued
  public var enqueuedAt: Date
  
  public init(jobId: UUID = UUID(), idempotencyKey: String, priority: JobPriority = JobPriority(50),
              payload: Data? = nil, retryPolicy: RetryPolicy = RetryPolicy(),
              sourceCapabilityId: String, projectId: String, enqueuedAt: Date = Date()) {
    self.jobId = jobId
    self.idempotencyKey = idempotencyKey
    self.priority = priority
    self.payload = payload
    self.retryPolicy = retryPolicy
    self.sourceCapabilityId = sourceCapabilityId
    self.projectId = projectId
    self.enqueuedAt = enqueuedAt
  }
}

/// Job execution status
public enum JobStatus: String, Codable, Sendable {
  case pending = "pending"         // Not yet claimed
  case claimed = "claimed"         // Claimed by worker, executing
  case completed = "completed"     // Successfully completed
  case failed = "failed"           // Failed, will retry
  case deadLettered = "dead_letter" // Exhausted retries
  case cancelled = "cancelled"     // Explicitly cancelled
}

/// Lease granted to worker for exclusive job execution
public struct JobLease: Codable, Sendable {
  /// Job being leased
  public var jobId: UUID
  
  /// Unique lease ID
  public var leaseId: UUID
  
  /// Worker holding the lease
  public var workerId: WorkerId
  
  /// When lease was granted
  public var grantedAt: Date
  
  /// When lease expires (worker must complete or heartbeat before this)
  public var expiresAt: Date
  
  /// Number of attempts so far (0 on first claim)
  public var attemptNumber: Int
  
  /// The job envelope
  public var jobEnvelope: WorkQueueEnvelope
  
  public init(jobId: UUID, leaseId: UUID = UUID(), workerId: WorkerId, 
              grantedAt: Date = Date(), ttlSeconds: Int = 300,
              attemptNumber: Int = 0, jobEnvelope: WorkQueueEnvelope) {
    self.jobId = jobId
    self.leaseId = leaseId
    self.workerId = workerId
    self.grantedAt = grantedAt
    self.expiresAt = grantedAt.addingTimeInterval(TimeInterval(ttlSeconds))
    self.attemptNumber = attemptNumber
    self.jobEnvelope = jobEnvelope
  }
}

/// Result of job operation (complete, nack, cancel)
public struct JobOperationReceipt: Codable, Sendable {
  /// Job ID
  public var jobId: UUID
  
  /// Lease ID that was affected
  public var leaseId: UUID
  
  /// Operation performed
  public var operation: JobOperation
  
  /// Resulting job status
  public var status: JobStatus
  
  /// Timestamp of operation
  public var operatedAt: Date
  
  public init(jobId: UUID, leaseId: UUID, operation: JobOperation, 
              status: JobStatus, operatedAt: Date = Date()) {
    self.jobId = jobId
    self.leaseId = leaseId
    self.operation = operation
    self.status = status
    self.operatedAt = operatedAt
  }
}

/// Job operation types
public enum JobOperation: String, Codable, Sendable {
  case enqueue = "enqueue"
  case claim = "claim"
  case acknowledge = "acknowledge"
  case nack = "nack"
  case cancel = "cancel"
  case retry = "retry"
}

/// Dead-letter record for failed jobs
public struct DeadLetterRecord: Codable, Sendable {
  /// Original job ID
  public var jobId: UUID
  
  /// When job was moved to dead-letter
  public var movedAt: Date
  
  /// Reason (last error message)
  public var reason: String
  
  /// Number of attempts made
  public var attemptCount: Int
  
  /// Last worker that attempted
  public var lastWorkerId: WorkerId?
  
  /// Original job envelope
  public var jobEnvelope: WorkQueueEnvelope
  
  public init(jobId: UUID, movedAt: Date = Date(), reason: String, 
              attemptCount: Int, lastWorkerId: WorkerId? = nil,
              jobEnvelope: WorkQueueEnvelope) {
    self.jobId = jobId
    self.movedAt = movedAt
    self.reason = reason
    self.attemptCount = attemptCount
    self.lastWorkerId = lastWorkerId
    self.jobEnvelope = jobEnvelope
  }
}
