# Phase 1: Semantic Foundations — Detailed Specification

**Phase ID**: `phase-msg-1`  
**Epic**: Messaging & Coordination Foundations  
**Target Duration**: 2-3 weeks  
**Status**: Ready for kickoff  

---

## Overview

Phase 1 establishes the protocols, envelopes, IDs, and validation rules for all three messaging subsystems without any runtime persistence. All types live in ContractsCore (Tier 1) and use in-memory test doubles for validation.

This phase produces zero external dependencies while establishing all semantic contracts.

---

## Deliverables

### 1. ContractsCore — Event Streaming Types

**File**: `Packages/ContractsCore/Sources/ContractsCore/Messaging/EventEnvelope.swift`

```swift
import Foundation

/// Unique identifier for an event stream
public protocol EventStreamId: Hashable, Codable {
  /// Topic/category name (e.g., "daemon_events", "agent_traces", "iot_telemetry")
  var topic: String { get }
  
  /// Optional partition key for future multi-shard deployments
  /// If nil, stream is single-partition (local implementation ignores)
  var partitionKey: String? { get }
  
  /// Project scope (for multi-tenant governance)
  var projectId: String { get }
  
  /// Display name for dashboards
  var displayName: String { get }
}

/// Position in an event stream
/// Comparable for replay range queries
public protocol EventCursor: Comparable, Codable, Hashable {
  /// Absolute position in stream (0-indexed)
  var position: UInt64 { get }
  
  /// Stream this cursor refers to
  var streamId: EventStreamId { get }
  
  /// Optional checkpoint label (for recovery)
  var checkpointId: UUID? { get }
}

/// Metadata about event provenance
public struct EventProvenance: Codable {
  /// Source that emitted this event (e.g., "daemon", "agent:summarizer", "device:sensor-123")
  public var source: String
  
  /// Source capability ID (for governance linkage)
  public var sourceCapabilityId: SourceCapabilityId?
  
  /// Optional causality chain (parent event ID)
  public var parentEventId: UUID?
  
  /// Hardware lane if applicable ("cpu", "gpu", "ane")
  public var hardwareLane: String?
  
  /// Timestamp when event was created (UTC)
  public var createdAt: Date
  
  public init(source: String, sourceCapabilityId: SourceCapabilityId? = nil, 
              parentEventId: UUID? = nil, hardwareLane: String? = nil, 
              createdAt: Date = Date()) {
    self.source = source
    self.sourceCapabilityId = sourceCapabilityId
    self.parentEventId = parentEventId
    self.hardwareLane = hardwareLane
    self.createdAt = createdAt
  }
}

/// Standard event envelope for all EventLog subsystem messages
public struct EventEnvelope: Codable {
  /// Unique event ID
  public var eventId: UUID
  
  /// Stream this event belongs to
  public var streamId: EventStreamId
  
  /// Position in stream (assigned by EventLog)
  public var cursor: EventCursor?
  
  /// Event creation timestamp (UTC)
  public var timestamp: Date
  
  /// Schema version for payload compatibility (e.g., "daemon.event.v1", "agent.trace.v2")
  public var schemaVersion: String
  
  /// Provenance: source, capability, causality
  public var provenance: EventProvenance
  
  /// Indirect reference to actual payload (not inline)
  public var payloadReference: PayloadReference
  
  /// Governance context: decision ID, principal, scope
  public var governanceContext: GovernanceContext
  
  /// Optional backpressure hint for high-frequency ingest
  public var backpressureHint: BackpressureHint?
  
  public init(eventId: UUID = UUID(), streamId: EventStreamId, schemaVersion: String,
              provenance: EventProvenance, payloadReference: PayloadReference,
              governanceContext: GovernanceContext, timestamp: Date = Date()) {
    self.eventId = eventId
    self.streamId = streamId
    self.timestamp = timestamp
    self.schemaVersion = schemaVersion
    self.provenance = provenance
    self.payloadReference = payloadReference
    self.governanceContext = governanceContext
    self.cursor = nil
    self.backpressureHint = nil
  }
}

/// Backpressure hint for subscribers
public struct BackpressureHint: Codable {
  public var queueDepth: Int
  public var estimatedDelayMs: Int
  public var recommendedBackoffMs: Int
  
  public init(queueDepth: Int, estimatedDelayMs: Int, recommendedBackoffMs: Int) {
    self.queueDepth = queueDepth
    self.estimatedDelayMs = estimatedDelayMs
    self.recommendedBackoffMs = recommendedBackoffMs
  }
}

/// Stream retention policy metadata
public struct StreamRetentionPolicy: Codable {
  /// How many days to retain events (0 = infinite)
  public var retentionDays: Int
  
  /// Maximum event count before pruning (0 = no limit)
  public var maxEventCount: Int
  
  /// Backpressure policy (drop behavior when full)
  public var backpressurePolicy: BackpressurePolicy
  
  public init(retentionDays: Int = 90, maxEventCount: Int = 0,
              backpressurePolicy: BackpressurePolicy = .block) {
    self.retentionDays = retentionDays
    self.maxEventCount = maxEventCount
    self.backpressurePolicy = backpressurePolicy
  }
}

/// Backpressure drop behavior
public enum BackpressurePolicy: String, Codable {
  /// Block subscribers (wait for drain)
  case block
  /// Drop newest events silently
  case dropNewest
  /// Drop oldest events (FIFO eviction)
  case dropOldest
  /// Raise error to subscriber
  case error
}

/// Checkpoint for cursor recovery
public struct EventCheckpoint: Codable {
  /// Unique checkpoint ID
  public var checkpointId: UUID
  
  /// Stream this checkpoint refers to
  public var streamId: EventStreamId
  
  /// Last successfully processed cursor
  public var cursor: EventCursor
  
  /// Human-readable label (e.g., "last_observatorium_dashboard_update")
  public var label: String
  
  /// When checkpoint was created
  public var createdAt: Date
  
  /// When checkpoint was last updated
  public var updatedAt: Date
  
  public init(checkpointId: UUID = UUID(), streamId: EventStreamId, cursor: EventCursor,
              label: String, createdAt: Date = Date()) {
    self.checkpointId = checkpointId
    self.streamId = streamId
    self.cursor = cursor
    self.label = label
    self.createdAt = createdAt
    self.updatedAt = createdAt
  }
}

/// Receipt emitted when event is successfully appended
public struct EventAppendReceipt: Codable {
  /// The appended event's ID
  public var eventId: UUID
  
  /// The assigned cursor position
  public var cursor: EventCursor
  
  /// Stream ID
  public var streamId: EventStreamId
  
  /// Timestamp of append
  public var appendedAt: Date
  
  /// Signature for audit trail
  public var signature: String
  
  public init(eventId: UUID, cursor: EventCursor, streamId: EventStreamId,
              appendedAt: Date = Date(), signature: String = "") {
    self.eventId = eventId
    self.cursor = cursor
    self.streamId = streamId
    self.appendedAt = appendedAt
    self.signature = signature
  }
}
```

---

### 2. ContractsCore — Work Queue Types

**File**: `Packages/ContractsCore/Sources/ContractsCore/Messaging/WorkQueueEnvelope.swift`

```swift
import Foundation

/// Unique identifier for a worker
public struct WorkerId: Hashable, Codable {
  public var id: String
  
  public init(_ id: String) {
    self.id = id
  }
}

/// Priority level for job execution (0-100, higher = sooner)
public struct JobPriority: Comparable, Codable {
  public var level: Int
  
  public init(_ level: Int) {
    self.level = max(0, min(100, level))
  }
  
  public static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
    lhs.level < rhs.level
  }
}

/// Retry strategy for failed jobs
public struct RetryPolicy: Codable {
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
public struct WorkQueueEnvelope: Codable {
  /// Unique job ID
  public var jobId: UUID
  
  /// Idempotency key for deduplication across retries
  public var idempotencyKey: String
  
  /// Job priority (0-100)
  public var priority: JobPriority
  
  /// Indirect reference to job payload
  public var payloadReference: PayloadReference
  
  /// Retry strategy
  public var retryPolicy: RetryPolicy
  
  /// Governance decision that authorized this job
  public var governanceDecisionId: GovernanceDecisionId?
  
  /// Source capability that enqueued this job
  public var sourceCapabilityId: SourceCapabilityId
  
  /// Project scope
  public var projectId: String
  
  /// Timestamp when job was enqueued
  public var enqueuedAt: Date
  
  /// Governance context for execution
  public var governanceContext: GovernanceContext
  
  public init(jobId: UUID = UUID(), idempotencyKey: String, priority: JobPriority = JobPriority(50),
              payloadReference: PayloadReference, retryPolicy: RetryPolicy = RetryPolicy(),
              governanceDecisionId: GovernanceDecisionId? = nil,
              sourceCapabilityId: SourceCapabilityId,
              projectId: String, enqueuedAt: Date = Date(),
              governanceContext: GovernanceContext) {
    self.jobId = jobId
    self.idempotencyKey = idempotencyKey
    self.priority = priority
    self.payloadReference = payloadReference
    self.retryPolicy = retryPolicy
    self.governanceDecisionId = governanceDecisionId
    self.sourceCapabilityId = sourceCapabilityId
    self.projectId = projectId
    self.enqueuedAt = enqueuedAt
    self.governanceContext = governanceContext
  }
}

/// Lease granted to worker for exclusive job execution
public struct JobLease: Codable {
  /// Job being leased
  public var jobId: UUID
  
  /// Worker holding the lease
  public var workerId: WorkerId
  
  /// Unique lease ID
  public var leaseId: UUID
  
  /// When lease expires (worker must acknowledge or NACk before this)
  public var expiresAt: Date
  
  /// Visibility timeout (how long job hidden from other workers)
  public var visibilityTimeout: TimeInterval
  
  /// When lease was acquired
  public var claimedAt: Date
  
  /// Number of times this job has been claimed
  public var attemptNumber: Int
  
  public init(jobId: UUID, workerId: WorkerId, leaseId: UUID = UUID(),
              expiresAt: Date, visibilityTimeout: TimeInterval = 30,
              claimedAt: Date = Date(), attemptNumber: Int = 1) {
    self.jobId = jobId
    self.workerId = workerId
    self.leaseId = leaseId
    self.expiresAt = expiresAt
    self.visibilityTimeout = visibilityTimeout
    self.claimedAt = claimedAt
    self.attemptNumber = attemptNumber
  }
}

/// Status of a job in queue
public enum JobStatus: String, Codable {
  case pending = "pending"        // Not yet claimed
  case claimed = "claimed"        // Leased to worker
  case acknowledged = "acknowledged"  // Completed successfully
  case failed = "failed"          // Failed, will retry
  case deadLettered = "dead_letter"   // Abandoned, requires manual review
  case cancelled = "cancelled"    // Cancelled by user
}

/// Dead-letter record for poison pill jobs
public struct DeadLetterRecord: Codable {
  /// Original job ID
  public var jobId: UUID
  
  /// Reason for dead-letter (e.g., "max_attempts_exceeded", "worker_crashed", "unknown_error")
  public var reason: String
  
  /// Final payload reference (for debugging)
  public var finalPayloadReference: PayloadReference?
  
  /// Stack trace or error message from final attempt
  public var errorTrace: String?
  
  /// When job was dead-lettered
  public var archivedAt: Date
  
  /// Receipt from final execution attempt
  public var lastExecutionReceipt: ExecutionReceipt?
  
  public init(jobId: UUID, reason: String, finalPayloadReference: PayloadReference? = nil,
              errorTrace: String? = nil, archivedAt: Date = Date()) {
    self.jobId = jobId
    self.reason = reason
    self.finalPayloadReference = finalPayloadReference
    self.errorTrace = errorTrace
    self.archivedAt = archivedAt
    self.lastExecutionReceipt = nil
  }
}

/// Receipt emitted for job operations
public struct JobOperationReceipt: Codable {
  /// Job ID
  public var jobId: UUID
  
  /// Operation type
  public var operation: JobOperation
  
  /// Lease ID if applicable
  public var leaseId: UUID?
  
  /// Worker ID if applicable
  public var workerId: WorkerId?
  
  /// Timestamp of operation
  public var operatedAt: Date
  
  /// Signature for audit trail
  public var signature: String
  
  public init(jobId: UUID, operation: JobOperation, leaseId: UUID? = nil,
              workerId: WorkerId? = nil, operatedAt: Date = Date(), signature: String = "") {
    self.jobId = jobId
    self.operation = operation
    self.leaseId = leaseId
    self.workerId = workerId
    self.operatedAt = operatedAt
    self.signature = signature
  }
}

/// Job operation types
public enum JobOperation: String, Codable {
  case enqueue = "enqueue"
  case claim = "claim"
  case acknowledge = "acknowledge"
  case nack = "nack"
  case retry = "retry"
  case deadLetter = "dead_letter"
  case cancel = "cancel"
}
```

---

### 3. ContractsCore — Coordination Types

**File**: `Packages/ContractsCore/Sources/ContractsCore/Messaging/CoordinationEnvelope.swift`

```swift
import Foundation

/// Lease for exclusive resource access
public struct CoordinatorLease: Codable {
  /// Unique lease ID
  public var leaseId: UUID
  
  /// Resource key (e.g., "worker:123", "rate_limit:api_call")
  public var key: String
  
  /// Current holder of lease
  public var holder: WorkerId
  
  /// When lease expires
  public var expiresAt: Date
  
  /// When lease was last refreshed (heartbeat)
  public var refreshed: Date
  
  /// TTL when originally acquired
  public var ttlSeconds: Int
  
  public init(leaseId: UUID = UUID(), key: String, holder: WorkerId,
              expiresAt: Date, ttlSeconds: Int = 30, refreshed: Date = Date()) {
    self.leaseId = leaseId
    self.key = key
    self.holder = holder
    self.expiresAt = expiresAt
    self.ttlSeconds = ttlSeconds
    self.refreshed = refreshed
  }
}

/// Rate limit policy variants
public enum RateLimitAlgorithm: String, Codable {
  case slidingWindow = "sliding_window"
  case tokenBucket = "token_bucket"
  case leakyBucket = "leaky_bucket"
}

/// Rate limit policy for request throttling
public struct RateLimitPolicy: Codable {
  /// Requests allowed per second
  public var requestsPerSecond: Int
  
  /// Burst capacity (how many requests above steady state allowed briefly)
  public var burstCapacity: Int
  
  /// Algorithm variant
  public var algorithm: RateLimitAlgorithm
  
  public init(requestsPerSecond: Int, burstCapacity: Int = 0,
              algorithm: RateLimitAlgorithm = .tokenBucket) {
    self.requestsPerSecond = requestsPerSecond
    self.burstCapacity = burstCapacity
    self.algorithm = algorithm
  }
}

/// Rate limit decision for a request
public struct RateLimitDecision: Codable {
  /// Is request allowed?
  public var allowed: Bool
  
  /// How many tokens/quota remain
  public var remainingTokens: Int
  
  /// If denied, how long to wait (milliseconds)
  public var retryAfterMs: Int
  
  /// Policy applied
  public var policy: RateLimitPolicy
  
  public init(allowed: Bool, remainingTokens: Int = 0, retryAfterMs: Int = 0,
              policy: RateLimitPolicy) {
    self.allowed = allowed
    self.remainingTokens = remainingTokens
    self.retryAfterMs = retryAfterMs
    self.policy = policy
  }
}

/// Worker presence status
public enum PresenceStatus: String, Codable {
  case alive = "alive"        // Heartbeat recent
  case stale = "stale"        // Heartbeat stale (>30s)
  case dead = "dead"          // Heartbeat not found or explicitly exited
  case unknown = "unknown"    // Never seen
}

/// Worker presence record
public struct WorkerPresence: Codable {
  /// Worker ID
  public var workerId: WorkerId
  
  /// Current status
  public var status: PresenceStatus
  
  /// Timestamp of last heartbeat
  public var lastHeartbeat: Date
  
  /// When this record was created
  public var registeredAt: Date
  
  public init(workerId: WorkerId, status: PresenceStatus = .alive,
              lastHeartbeat: Date = Date(), registeredAt: Date = Date()) {
    self.workerId = workerId
    self.status = status
    self.lastHeartbeat = lastHeartbeat
    self.registeredAt = registeredAt
  }
}

/// Receipt for coordination operations
public struct CoordinationReceipt: Codable {
  /// Operation type
  public var operation: CoordinationOperation
  
  /// Resource key
  public var key: String
  
  /// Lease ID if applicable
  public var leaseId: UUID?
  
  /// Timestamp of operation
  public var operatedAt: Date
  
  /// Signature for audit trail
  public var signature: String
  
  public init(operation: CoordinationOperation, key: String, leaseId: UUID? = nil,
              operatedAt: Date = Date(), signature: String = "") {
    self.operation = operation
    self.key = key
    self.leaseId = leaseId
    self.operatedAt = operatedAt
    self.signature = signature
  }
}

/// Coordination operation types
public enum CoordinationOperation: String, Codable {
  case acquireLease = "acquire_lease"
  case refreshLease = "refresh_lease"
  case releaseLease = "release_lease"
  case checkPresence = "check_presence"
  case heartbeat = "heartbeat"
  case rateLimit = "rate_limit"
}
```

---

### 4. ExecutionAuthority — Protocol Definitions

**File**: `Packages/AnigmaCore/Sources/AnigmaFoundation/ExecutionAuthority/Messaging/MessagingProtocols.swift`

```swift
import Foundation

// MARK: - EventLog Protocol

/// Protocol for append-only event log (Kafka-like semantics)
public protocol EventLog: Sendable {
  /// Append an event to stream
  func append(_ envelope: EventEnvelope) async throws -> EventAppendReceipt
  
  /// Subscribe to events from cursor (returns async sequence)
  /// Backpressure: subscriber can slow down, log applies policy
  func subscribe(to streamId: EventStreamId, from cursor: EventCursor?) 
    async -> AsyncThrowingSequence<EventEnvelope, Error>
  
  /// Replay events in range
  func replay(streamId: EventStreamId, from startCursor: EventCursor?, to endCursor: EventCursor?) 
    async throws -> [EventEnvelope]
  
  /// Save checkpoint for recovery
  func saveCheckpoint(_ checkpoint: EventCheckpoint) async throws
  
  /// Load checkpoint by ID
  func loadCheckpoint(id: UUID) async throws -> EventCheckpoint?
  
  /// Get stream metadata
  func getStreamMetadata(streamId: EventStreamId) async throws -> StreamMetadata
}

public struct StreamMetadata: Codable {
  public var streamId: EventStreamId
  public var eventCount: UInt64
  public var oldestCursor: EventCursor?
  public var newestCursor: EventCursor?
  public var retentionPolicy: StreamRetentionPolicy
  
  public init(streamId: EventStreamId, eventCount: UInt64 = 0,
              oldestCursor: EventCursor? = nil, newestCursor: EventCursor? = nil,
              retentionPolicy: StreamRetentionPolicy = StreamRetentionPolicy()) {
    self.streamId = streamId
    self.eventCount = eventCount
    self.oldestCursor = oldestCursor
    self.newestCursor = newestCursor
    self.retentionPolicy = retentionPolicy
  }
}

// MARK: - WorkQueue Protocol

/// Protocol for durable work queue (RabbitMQ-like semantics)
public protocol WorkQueue: Sendable {
  /// Enqueue a job
  func enqueue(_ envelope: WorkQueueEnvelope) async throws -> UUID  // Returns jobId
  
  /// Claim available jobs for execution
  func claim(workerId: WorkerId, maxJobs: Int) async throws -> [JobLease]
  
  /// Acknowledge successful completion of job
  func acknowledge(leaseId: UUID) async throws -> JobOperationReceipt
  
  /// Negative acknowledge: retry job later
  func nack(leaseId: UUID, delay: TimeInterval) async throws -> JobOperationReceipt
  
  /// Cancel a job (from any state)
  func cancel(jobId: UUID, reason: String) async throws -> Bool
  
  /// Get job status
  func getStatus(jobId: UUID) async throws -> JobStatus
  
  /// Get job details
  func getJob(jobId: UUID) async throws -> WorkQueueEnvelope?
  
  /// Recover expired leases (internal, called by scheduler)
  func recoverExpiredLeases() async throws -> Int
}

// MARK: - EphemeralCoordinator Protocol

/// Protocol for ephemeral coordination (Valkey/Redis-like semantics)
public protocol EphemeralCoordinator: Sendable {
  /// Acquire a lease with TTL
  func acquireLease(key: String, holder: WorkerId, ttlSeconds: Int) async throws -> CoordinatorLease
  
  /// Refresh lease before expiry (heartbeat)
  func refreshLease(leaseId: UUID, ttlSeconds: Int) async throws -> CoordinatorLease
  
  /// Release lease explicitly
  func releaseLease(leaseId: UUID) async throws -> CoordinationReceipt
  
  /// Check if worker is alive
  func checkPresence(workerId: WorkerId) async throws -> PresenceStatus
  
  /// Heartbeat to indicate worker is alive
  func heartbeat(workerId: WorkerId, ttlSeconds: Int) async throws -> WorkerPresence
  
  /// Check rate limit
  func checkRateLimit(clientId: String, policy: RateLimitPolicy) async throws -> RateLimitDecision
  
  /// Get current lease
  func getLease(leaseId: UUID) async throws -> CoordinatorLease?
}
```

---

### 5. InMemory Test Doubles (ExecutionAuthority)

**File**: `Packages/AnigmaCore/Sources/AnigmaFoundation/ExecutionAuthority/Messaging/InMemoryImplementations.swift`

```swift
import Foundation

// MARK: - InMemoryEventLog

public actor InMemoryEventLog: EventLog {
  private var events: [EventStreamId: [EventEnvelope]] = [:]
  private var cursors: [EventStreamId: UInt64] = [:]
  private var checkpoints: [UUID: EventCheckpoint] = [:]
  
  public init() {}
  
  public func append(_ envelope: EventEnvelope) async throws -> EventAppendReceipt {
    let streamId = envelope.streamId
    let position = cursors[streamId, default: 0]
    cursors[streamId] = position + 1
    
    var mutableEnvelope = envelope
    let cursor = SimpleEventCursor(position: position, streamId: streamId)
    mutableEnvelope.cursor = cursor
    
    if events[streamId] == nil {
      events[streamId] = []
    }
    events[streamId]?.append(mutableEnvelope)
    
    return EventAppendReceipt(eventId: envelope.eventId, cursor: cursor, 
                              streamId: streamId)
  }
  
  public func subscribe(to streamId: EventStreamId, from cursor: EventCursor?) 
    async -> AsyncThrowingSequence<EventEnvelope, Error> {
    let startPos = cursor?.position ?? 0
    let allEvents = events[streamId] ?? []
    let filtered = allEvents.filter { $0.cursor?.position ?? 0 >= startPos }
    
    return filtered.async
  }
  
  public func replay(streamId: EventStreamId, from startCursor: EventCursor?, 
                     to endCursor: EventCursor?) async throws -> [EventEnvelope] {
    let allEvents = events[streamId] ?? []
    let startPos = startCursor?.position ?? 0
    let endPos = endCursor?.position ?? UInt64.max
    
    return allEvents.filter { event in
      guard let pos = event.cursor?.position else { return false }
      return pos >= startPos && pos <= endPos
    }
  }
  
  public func saveCheckpoint(_ checkpoint: EventCheckpoint) async throws {
    checkpoints[checkpoint.checkpointId] = checkpoint
  }
  
  public func loadCheckpoint(id: UUID) async throws -> EventCheckpoint? {
    return checkpoints[id]
  }
  
  public func getStreamMetadata(streamId: EventStreamId) async throws -> StreamMetadata {
    let allEvents = events[streamId] ?? []
    let position = cursors[streamId] ?? 0
    
    return StreamMetadata(
      streamId: streamId,
      eventCount: UInt64(allEvents.count),
      oldestCursor: allEvents.first?.cursor,
      newestCursor: allEvents.last?.cursor
    )
  }
}

// MARK: - InMemoryWorkQueue

public actor InMemoryWorkQueue: WorkQueue {
  private var jobs: [UUID: WorkQueueEnvelope] = [:]
  private var leases: [UUID: JobLease] = [:]
  private var statuses: [UUID: JobStatus] = [:]
  private var deadLetters: [UUID: DeadLetterRecord] = [:]
  
  public init() {}
  
  public func enqueue(_ envelope: WorkQueueEnvelope) async throws -> UUID {
    jobs[envelope.jobId] = envelope
    statuses[envelope.jobId] = .pending
    return envelope.jobId
  }
  
  public func claim(workerId: WorkerId, maxJobs: Int) async throws -> [JobLease] {
    let available = jobs.filter { _, job in statuses[job.jobId] == .pending }
      .sorted { $0.value.priority.level > $1.value.priority.level }
      .prefix(maxJobs)
    
    var claims: [JobLease] = []
    for (jobId, _) in available {
      let lease = JobLease(jobId: jobId, workerId: workerId,
                          expiresAt: Date(timeIntervalSinceNow: 30))
      leases[lease.leaseId] = lease
      statuses[jobId] = .claimed
      claims.append(lease)
    }
    return claims
  }
  
  public func acknowledge(leaseId: UUID) async throws -> JobOperationReceipt {
    guard let lease = leases[leaseId], let job = jobs[lease.jobId] else {
      throw WorkQueueError.leaseNotFound
    }
    statuses[lease.jobId] = .acknowledged
    leases.removeValue(forKey: leaseId)
    return JobOperationReceipt(jobId: lease.jobId, operation: .acknowledge,
                              leaseId: leaseId, workerId: lease.workerId)
  }
  
  public func nack(leaseId: UUID, delay: TimeInterval) async throws -> JobOperationReceipt {
    guard let lease = leases[leaseId] else {
      throw WorkQueueError.leaseNotFound
    }
    statuses[lease.jobId] = .pending
    leases.removeValue(forKey: leaseId)
    return JobOperationReceipt(jobId: lease.jobId, operation: .nack,
                              leaseId: leaseId, workerId: lease.workerId)
  }
  
  public func cancel(jobId: UUID, reason: String) async throws -> Bool {
    guard jobs[jobId] != nil else { return false }
    statuses[jobId] = .cancelled
    return true
  }
  
  public func getStatus(jobId: UUID) async throws -> JobStatus {
    return statuses[jobId] ?? .pending
  }
  
  public func getJob(jobId: UUID) async throws -> WorkQueueEnvelope? {
    return jobs[jobId]
  }
  
  public func recoverExpiredLeases() async throws -> Int {
    let now = Date()
    let expired = leases.filter { $0.value.expiresAt < now }
    
    for (leaseId, lease) in expired {
      statuses[lease.jobId] = .pending
      leases.removeValue(forKey: leaseId)
    }
    
    return expired.count
  }
}

// MARK: - InMemoryCoordinator

public actor InMemoryEphemeralCoordinator: EphemeralCoordinator {
  private var leases: [UUID: CoordinatorLease] = [:]
  private var presence: [WorkerId: WorkerPresence] = [:]
  private var rateLimitTokens: [String: Int] = [:]
  
  public init() {}
  
  public func acquireLease(key: String, holder: WorkerId, ttlSeconds: Int) 
    async throws -> CoordinatorLease {
    let lease = CoordinatorLease(key: key, holder: holder,
                                expiresAt: Date(timeIntervalSinceNow: TimeInterval(ttlSeconds)),
                                ttlSeconds: ttlSeconds)
    leases[lease.leaseId] = lease
    return lease
  }
  
  public func refreshLease(leaseId: UUID, ttlSeconds: Int) 
    async throws -> CoordinatorLease {
    guard var lease = leases[leaseId] else {
      throw CoordinatorError.leaseNotFound
    }
    lease.expiresAt = Date(timeIntervalSinceNow: TimeInterval(ttlSeconds))
    lease.refreshed = Date()
    leases[leaseId] = lease
    return lease
  }
  
  public func releaseLease(leaseId: UUID) async throws -> CoordinationReceipt {
    guard let lease = leases[leaseId] else {
      throw CoordinatorError.leaseNotFound
    }
    leases.removeValue(forKey: leaseId)
    return CoordinationReceipt(operation: .releaseLease, key: lease.key, leaseId: leaseId)
  }
  
  public func checkPresence(workerId: WorkerId) async throws -> PresenceStatus {
    guard let presence = presence[workerId] else {
      return .unknown
    }
    let elapsed = Date().timeIntervalSince(presence.lastHeartbeat)
    return elapsed > 30 ? .stale : .alive
  }
  
  public func heartbeat(workerId: WorkerId, ttlSeconds: Int) 
    async throws -> WorkerPresence {
    let presence = WorkerPresence(workerId: workerId, status: .alive,
                                 lastHeartbeat: Date())
    self.presence[workerId] = presence
    return presence
  }
  
  public func checkRateLimit(clientId: String, policy: RateLimitPolicy) 
    async throws -> RateLimitDecision {
    let tokens = rateLimitTokens[clientId, default: policy.burstCapacity]
    let allowed = tokens > 0
    
    if allowed {
      rateLimitTokens[clientId] = tokens - 1
    }
    
    return RateLimitDecision(allowed: allowed, remainingTokens: max(0, tokens - 1),
                            policy: policy)
  }
  
  public func getLease(leaseId: UUID) async throws -> CoordinatorLease? {
    return leases[leaseId]
  }
}

// MARK: - Test Errors

public enum WorkQueueError: Error {
  case leaseNotFound
  case jobNotFound
}

public enum CoordinatorError: Error {
  case leaseNotFound
}

// MARK: - Helper: Simple Event Cursor

struct SimpleEventCursor: EventCursor {
  let position: UInt64
  let streamId: EventStreamId
  let checkpointId: UUID? = nil
  
  static func < (lhs: SimpleEventCursor, rhs: SimpleEventCursor) -> Bool {
    lhs.position < rhs.position
  }
}

// MARK: - Helper: Simple Event Stream ID

struct SimpleEventStreamId: EventStreamId {
  let topic: String
  let partitionKey: String?
  let projectId: String
  let displayName: String
  
  init(topic: String, projectId: String = "default", partitionKey: String? = nil) {
    self.topic = topic
    self.projectId = projectId
    self.partitionKey = partitionKey
    self.displayName = topic
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(topic)
    hasher.combine(projectId)
  }
  
  static func == (lhs: SimpleEventStreamId, rhs: SimpleEventStreamId) -> Bool {
    lhs.topic == rhs.topic && lhs.projectId == rhs.projectId
  }
}

// MARK: - Array Async Extension

extension Array {
  var async: AsyncSequence<Element> {
    return ArrayAsyncSequence(elements: self)
  }
}

struct ArrayAsyncSequence<Element>: AsyncSequence {
  let elements: [Element]
  
  struct AsyncIterator: AsyncIteratorProtocol {
    var iterator: IndexingIterator<[Element]>
    
    mutating func next() async -> Element? {
      return iterator.next()
    }
  }
  
  func makeAsyncIterator() -> AsyncIterator {
    return AsyncIterator(iterator: elements.makeIterator())
  }
}
```

---

## Testing Strategy

### Unit Tests (ContractsCore)

**File**: `Tests/ContractsCoreTests/MessagingProtocolsTests.swift`

Tests verify:
- EventEnvelope codec compliance (round-trip JSON)
- WorkQueueEnvelope priority ordering
- RetryPolicy delay calculations
- JobLease expiry logic
- CoordinatorLease TTL semantics
- RateLimitPolicy token calculations

### Protocol Tests (ExecutionAuthority)

**File**: `Tests/AnigmaCoreTests/MessagingProtocolTests.swift`

Tests verify through protocols (not implementation-specific):
- EventLog: append, subscribe, replay, checkpoint
- WorkQueue: enqueue, claim, acknowledge, nack, retry, dead-letter, expire recovery
- EphemeralCoordinator: acquire, refresh, release, presence, rate-limit

All tests use in-memory test doubles.

---

## Acceptance Checklist

- [ ] All contract types defined in ContractsCore
- [ ] All protocols defined in ExecutionAuthority
- [ ] In-memory test doubles implement all protocols
- [ ] 100+ unit tests for codecs and policies
- [ ] 50+ protocol tests for all three subsystems
- [ ] No runtime dependencies on external brokers
- [ ] Documentation complete and examples provided
- [ ] Phase 1 deliverables ready for Phase 2

---

## Next Phase

Once Phase 1 is complete, proceed to Phase 2 (Local Durable Implementation) to add SQLite/Postgres persistence and scheduler integration.

---

**Status**: Ready for implementation  
**Owner**: Anigma Architecture Council  
**Last Updated**: 2026-04-24
