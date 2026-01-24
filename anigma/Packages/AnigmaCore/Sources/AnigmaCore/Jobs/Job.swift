//
//  Job.swift
//  AnigmaCore
//
//  Generic job model for background task execution.
//  Jobs represent units of work that can be queued, scheduled, and tracked.
//
//  This implementation consolidates patterns from:
//  - Harmonia: OrchestrumCore/Jobs/JobQueue.swift (HarmoniaJob, JobRecord, etc.)
//
//  Key design decisions:
//  - Jobs are domain-agnostic (no Harmonia-specific fields)
//  - Domain modules define their own job types using the generic Job struct
//  - JobType is a protocol, not an enum, for extensibility
//
//  Migration notes:
//  - Harmonia's HarmoniaJob should wrap AnigmaCore.Job or use JobAdapter
//  - Domain-specific fields (projectId, sessionId, etc.) become metadata
//

import Foundation
import AnigmaPrimitives

// MARK: - Core Job Types

/// Unique identifier for a job.
public struct JobId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: String

    public init() {
        self.raw = UUID().uuidString
    }

    public init(raw: String) {
        self.raw = raw
    }

    public var description: String {
        "Job(\(raw.prefix(8)))"
    }
}

extension JobId: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.raw = value
    }
}

// MARK: - Job Status

/// Current state of a job in its lifecycle.
public enum JobStatus: String, Codable, Sendable, CaseIterable {
    /// Waiting in queue to be executed.
    case pending

    /// Has a future scheduled time; not ready yet.
    case scheduled

    /// Currently being executed.
    case running

    /// Finished successfully.
    case completed

    /// Failed after all retries exhausted.
    case failed

    /// Cancelled by user or policy.
    case cancelled

    /// Deadline passed before execution could complete.
    case expired

    /// Waiting due to external constraints (throttling, budget, etc.).
    case deferred

    /// Automatically re-queued after a transient failure.
    case retrying

    /// Whether this status represents a terminal state.
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .expired:
            return true
        case .pending, .scheduled, .running, .deferred, .retrying:
            return false
        }
    }

    /// Whether this status represents an active (non-terminal) state.
    public var isActive: Bool {
        !isTerminal
    }
}

// MARK: - Job Priority

/// Priority level for job scheduling.
public enum JobPriority: Int, Codable, Sendable, Comparable, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Job Type Protocol

/// Protocol for defining job types.
/// Each domain module can define its own job types.
///
/// ## Example
/// ```swift
/// struct OcrJobType: JobType {
///     static let identifier = "ocr"
///     static let displayName = "OCR Processing"
/// }
/// ```
public protocol JobType: Sendable {
    /// Unique identifier for this job type.
    static var identifier: String { get }

    /// Human-readable name for display.
    static var displayName: String { get }
}

// MARK: - Built-in Job Types

/// Generic/freeform job type for untyped jobs.
public struct GenericJobType: JobType {
    public static let identifier = "generic"
    public static let displayName = "Generic Job"
}

// MARK: - Timeout Policy

/// Configuration for job timeout behavior.
public struct TimeoutPolicy: Codable, Sendable, Equatable {
    /// Default timeout duration in seconds.
    public let defaultTimeout: TimeInterval
    
    /// Maximum timeout duration in seconds.
    public let maxTimeout: TimeInterval
    
    /// Grace period before cancellation (for cleanup).
    public let gracePeriod: TimeInterval
    
    /// Whether to extend timeout for progress.
    public let allowProgressExtension: Bool
    
    /// Progress extension factor (multiplier of base timeout).
    public let progressExtensionFactor: Double
    
    public init(
        defaultTimeout: TimeInterval = 300, // 5 minutes
        maxTimeout: TimeInterval = 3600, // 1 hour
        gracePeriod: TimeInterval = 10, // 10 seconds
        allowProgressExtension: Bool = true,
        progressExtensionFactor: Double = 1.5
    ) {
        self.defaultTimeout = defaultTimeout
        self.maxTimeout = maxTimeout
        self.gracePeriod = gracePeriod
        self.allowProgressExtension = allowProgressExtension
        self.progressExtensionFactor = progressExtensionFactor
    }
    
    /// No timeout policy.
    public static let noTimeout = TimeoutPolicy(defaultTimeout: .infinity, maxTimeout: .infinity, gracePeriod: 0, allowProgressExtension: false, progressExtensionFactor: 1.0)
    
    /// Default timeout policy (5 minutes, 1 hour max, with progress extension).
    public static let `default` = TimeoutPolicy()
    
    /// Quick timeout policy (30 seconds, 5 minutes max, no extension).
    public static let quick = TimeoutPolicy(
        defaultTimeout: 30,
        maxTimeout: 300,
        gracePeriod: 5,
        allowProgressExtension: false,
        progressExtensionFactor: 1.0
    )
    
    /// Long-running policy (30 minutes, 4 hours max, with extension).
    public static let longRunning = TimeoutPolicy(
        defaultTimeout: 1800,
        maxTimeout: 14400,
        gracePeriod: 30,
        allowProgressExtension: true,
        progressExtensionFactor: 2.0
    )
    
    /// Calculate effective timeout for a specific job, considering any job-specific override.
    public func effectiveTimeout(jobTimeout: TimeInterval?) -> TimeInterval {
        let base = jobTimeout ?? defaultTimeout
        return min(base, maxTimeout)
    }
    
    /// Calculate extended timeout if progress is detected.
    public func extendedTimeout(baseTimeout: TimeInterval) -> TimeInterval {
        guard allowProgressExtension else { return baseTimeout }
        return min(baseTimeout * progressExtensionFactor, maxTimeout)
    }
}

// MARK: - Retry Policy

/// Configuration for job retry behavior.
public struct RetryPolicy: Codable, Sendable, Equatable {
    /// Maximum number of retry attempts.
    public let maxRetries: Int

    /// Base backoff duration in seconds.
    public let backoffSeconds: TimeInterval

    /// Multiplier for exponential backoff.
    public let backoffMultiplier: Double

    public init(
        maxRetries: Int = 3,
        backoffSeconds: TimeInterval = 30,
        backoffMultiplier: Double = 2.0
    ) {
        self.maxRetries = maxRetries
        self.backoffSeconds = backoffSeconds
        self.backoffMultiplier = backoffMultiplier
    }

    /// No retries policy.
    public static let noRetry = RetryPolicy(maxRetries: 0)

    /// Default retry policy (3 retries, 30s base, 2x multiplier).
    public static let `default` = RetryPolicy()

    /// Aggressive retry policy (5 retries, 10s base, 1.5x multiplier).
    public static let aggressive = RetryPolicy(maxRetries: 5, backoffSeconds: 10, backoffMultiplier: 1.5)

    /// Calculates backoff duration for a given attempt number.
    public func backoff(attempt: Int) -> TimeInterval {
        backoffSeconds * pow(backoffMultiplier, Double(attempt))
    }
}

// MARK: - Job

/// A generic job that can be queued for background execution.
/// Jobs are owned by the system, not by any specific client.
///
/// ## Usage
/// ```swift
/// let job = Job(
///     typeId: "ocr",
///     inputRefs: [docEntityId],
///     metadata: ["language": "en"]
/// )
/// ```
public struct Job: Codable, Sendable, Identifiable {
    /// Unique identifier for this job.
    public let id: JobId

    /// Type identifier (matches a JobType.identifier).
    public let typeId: String

    /// Priority for scheduling.
    public let priority: JobPriority

    /// When the job was created.
    public let createdAt: Date

    /// When the job should be executed (nil = immediately).
    public let scheduledFor: Date?

    /// Deadline for completion (nil = no deadline).
    public let deadline: Date?

    /// Timeout for execution (nil = no timeout).
    public let timeoutDuration: TimeInterval?

    /// Timeout policy for this job type.
    public let timeoutPolicy: TimeoutPolicy?

    /// Retry configuration.
    public let retryPolicy: RetryPolicy

    /// Entity IDs that serve as inputs to this job.
    public let inputRefs: [EntityId]

    /// Entity IDs that will receive outputs from this job.
    public var outputRefs: [EntityId]

    /// Key-value metadata for job-specific data.
    public var metadata: [String: String]

    /// Optional human-readable label.
    public var label: String?

    /// Tags for filtering and grouping.
    public var tags: [String]

    public init(
        id: JobId = JobId(),
        typeId: String = GenericJobType.identifier,
        priority: JobPriority = .normal,
        createdAt: Date = Date(),
        scheduledFor: Date? = nil,
        deadline: Date? = nil,
        timeoutDuration: TimeInterval? = nil,
        timeoutPolicy: TimeoutPolicy? = nil,
        retryPolicy: RetryPolicy = .default,
        inputRefs: [EntityId] = [],
        outputRefs: [EntityId] = [],
        metadata: [String: String] = [:],
        label: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.typeId = typeId
        self.priority = priority
        self.createdAt = createdAt
        self.scheduledFor = scheduledFor
        self.deadline = deadline
        self.timeoutDuration = timeoutDuration
        self.timeoutPolicy = timeoutPolicy
        self.retryPolicy = retryPolicy
        self.inputRefs = inputRefs
        self.outputRefs = outputRefs
        self.metadata = metadata
        self.label = label
        self.tags = tags
    }

    /// Whether this job is ready to run (scheduled time has passed or none set).
    public var isReady: Bool {
        guard let scheduled = scheduledFor else { return true }
        return Date() >= scheduled
    }

    /// Whether this job has expired (deadline passed).
    public var isExpired: Bool {
        guard let deadline = deadline else { return false }
        return Date() > deadline
    }
}

// MARK: - Job Record

/// A job with its current execution state.
/// Used by the job queue to track job lifecycle.
public struct JobRecord: Codable, Sendable, Identifiable {
    /// The underlying job.
    public let job: Job

    /// Current status.
    public var status: JobStatus

    /// Number of execution attempts.
    public var attempts: Int

    /// Timestamp of last attempt.
    public var lastAttemptAt: Date?

    /// Timestamp when job completed (success or failure).
    public var completedAt: Date?

    /// Result of execution (if completed).
    public var result: JobResult?

    /// Error message (if failed).
    public var error: String?

    /// Reason for deferral (if deferred).
    public var deferralReason: String?

    /// When the deferral expires.
    public var deferredUntil: Date?

    public var id: JobId { job.id }

    public init(
        job: Job,
        status: JobStatus = .pending,
        attempts: Int = 0,
        lastAttemptAt: Date? = nil,
        completedAt: Date? = nil,
        result: JobResult? = nil,
        error: String? = nil,
        deferralReason: String? = nil,
        deferredUntil: Date? = nil
    ) {
        self.job = job
        self.status = status
        self.attempts = attempts
        self.lastAttemptAt = lastAttemptAt
        self.completedAt = completedAt
        self.result = result
        self.error = error
        self.deferralReason = deferralReason
        self.deferredUntil = deferredUntil
    }

    /// Whether this job can be retried.
    public var canRetry: Bool {
        status == .failed && attempts < job.retryPolicy.maxRetries
    }

    /// Whether deferral has expired and job is ready.
    public var isDeferralExpired: Bool {
        guard status == .deferred, let until = deferredUntil else { return false }
        return Date() >= until
    }

    /// Next retry time based on backoff policy.
    public var nextRetryAt: Date? {
        guard canRetry, let lastAttempt = lastAttemptAt else { return nil }
        let backoff = job.retryPolicy.backoff(attempt: attempts)
        return lastAttempt.addingTimeInterval(backoff)
    }
}

// MARK: - Job Result

/// Result of a completed job execution.
public struct JobResult: Codable, Sendable {
    /// Outcome classification.
    public let outcome: JobOutcome

    /// Optional summary of what was done.
    public let summary: String?

    /// Number of actions/operations performed.
    public let actionsApplied: Int

    /// Duration of execution in milliseconds.
    public let durationMs: Int64

    /// Timeout duration applied during execution (nil if no timeout).
    public let timeoutDuration: TimeInterval?

    /// Whether the job was cancelled due to timeout.
    public let timedOut: Bool

    /// Output entity IDs created or modified.
    public let outputRefs: [EntityId]

    public init(
        outcome: JobOutcome,
        summary: String? = nil,
        actionsApplied: Int = 0,
        durationMs: Int64 = 0,
        timeoutDuration: TimeInterval? = nil,
        timedOut: Bool = false,
        outputRefs: [EntityId] = []
    ) {
        self.outcome = outcome
        self.summary = summary
        self.actionsApplied = actionsApplied
        self.durationMs = durationMs
        self.timeoutDuration = timeoutDuration
        self.timedOut = timedOut
        self.outputRefs = outputRefs
    }
}

/// Outcome classification for job execution.
public enum JobOutcome: String, Codable, Sendable {
    case success
    case partialSuccess
    case error
    case denied
    case requiresInput
}

// MARK: - Job Errors

/// Errors related to job operations.
public enum JobError: Error, LocalizedError, Sendable {
    case jobNotFound(JobId)
    case invalidState(current: JobStatus, expected: JobStatus)
    case queueFull(limit: Int)
    case executionFailed(String)
    case executionTimeout(JobId, TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .jobNotFound(let id):
            return "Job not found: \(id)"
        case .invalidState(let current, let expected):
            return "Invalid job state: expected \(expected.rawValue), got \(current.rawValue)"
        case .queueFull(let limit):
            return "Job queue is full (limit: \(limit))"
        case .executionFailed(let message):
            return "Job execution failed: \(message)"
        case .executionTimeout(let id, let duration):
            return "Job \(id) timed out after \(duration) seconds"
        }
    }

    /// Whether this error represents a timeout.
    public var isTimeout: Bool {
        if case .executionTimeout = self { return true }
        return false
    }
}
