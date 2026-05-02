# Messaging & Coordination Foundations — Roadmap Epic

**Epic ID**: `epic-msg-coord`  
**Status**: Planning  
**Created**: 2026-04-24  
**Priority**: High  
**Owner**: Anigma Architecture Council  

---

## Vision

Anigma needs explicit, governed messaging and coordination semantics to enable:
- Replayable audit trails and IoT ingest (EventLog)
- Distributed job scheduling and worker coordination (WorkQueue)
- Transient coordination, leases, and rate limiting (EphemeralCoordinator)

**Core principle**: These are *architectural foundations*, not runtime dependencies. No Kafka, RabbitMQ, or Valkey server required locally. External systems are optional adapters behind Anigma-owned protocols.

---

## Scope: Three First-Class Foundation Ports

### 1. EventLog — Kafka-like Event Streams

**Use cases**:
- Append-only event streams for daemon events
- Replayable traces for agent/tool execution
- Observatorium event ingest
- IoT sensor/device event logs
- Workflow history and audit trails
- Hardware mission logs

**Required semantics**:
- Append event with schema versioning
- Subscribe to stream from cursor
- Replay from checkpoint
- Durable cursor/checkpoint model
- Stream/topic identity
- Partition key concept (for future multi-shard deployments)
- Retention policy metadata
- Backpressure policy
- Governance receipt reference
- Event envelope with provenance

**Initial implementation**:
- Local append-only event log (SQLite or file-backed segments)
- In-memory cursor tracking for test doubles
- No Kafka client library
- Define `KafkaAdapter` as future target only

---

### 2. WorkQueue — RabbitMQ-like Job Broker

**Use cases**:
- Daemon background jobs
- Indexing jobs
- OCR/PDF processing jobs
- Rendering and conversion jobs
- Model loading/conversion jobs
- Export and archive jobs
- Agent execution work

**Required semantics**:
- Enqueue job with idempotency key
- Claim job with lease (visibility timeout)
- Acknowledge completion
- Negative acknowledge (NACk) and retry
- Exponential backoff retry policy
- Dead-letter state for poison pills
- Job priority levels
- Worker identity tracking
- Worker heartbeat model
- Lease expiry detection and recovery
- Cancellation support
- Governance decision reference
- Execution receipt reference

**Initial implementation**:
- Postgres or SQLite-backed durable job table
- Owned by Anigma Scheduler (not external authority)
- Lease expiry recovery loop in daemon
- Retry policy enforcement in Scheduler
- No RabbitMQ client library
- Define `RabbitMQAdapter` as future target only

---

### 3. EphemeralCoordinator — Valkey-like Coordination

**Use cases**:
- Worker presence and heartbeats
- Short-lived lease/lock acquisition
- Rate limit decisions
- Request deduplication
- Hot state caching
- Local runtime coordination
- Health check metadata

**Required semantics**:
- Acquire lease with TTL
- Release lease
- Refresh lease (heartbeat)
- Worker presence check
- Rate-limit decision (sliding window, token bucket)
- Ephemeral key/value with expiry
- Atomic counter operations
- Set membership (worker roster)
- Transient pub/sub notifications
- Graceful degradation when unavailable

**Initial implementation**:
- In-process Swift actor or local SQLite lease table
- TTL enforcement with background cleanup
- No Redis/Valkey client library
- Define `ValkeyAdapter` as future target only
- Prefer Valkey over Redis for open-source compatibility

---

## Data Structure Optimizations for Foundation Efficiency

To achieve the performance required for high-frequency messaging and local-first governance, we will utilize specialized data structures to optimize core "Foundation Ports."

### 1. Bloom Filters for Ingest Gatekeeping (`td-b100m01`)
- **Integration**: `EventLog` and `VaultAuthority`.
- **Optimization**: Before checking if an event or artifact exists in the persistent ledger (Postgres/SQLite), the system will query an in-memory Bloom Filter.
- **Impact**: Eliminates unnecessary disk I/O for "No" answers, accelerating batch ingest and deduplication.

### 2. Tries for Prefix Hash Lookups (`td-7r1e02`)
- **Integration**: `AnigmaCLI` and `EventLog` topic/stream resolution.
- **Optimization**: Use a Trie (Prefix Tree) to index event stream IDs and artifact BLAKE3 hashes.
- **Impact**: Provides O(L) autocomplete for the CLI and instant stream resolution without full-string hash comparisons.

### 3. Disjoint Sets for Evidence Clustering (`td-u1n10n03`)
- **Integration**: `CathedralModule` and `EventLog` audit trails.
- **Optimization**: Track "connected components" of evidence across multiple event streams using Union-Find with path compression.
- **Impact**: Enables near-instant verification of whether two disparate event receipts belong to the same parent "Evidence Ring."

---

## High-Performance Communication Protocols

To achieve "Formula 1" performance in the Evidence Ring and inter-process communication (IPC), we will adopt the following protocol patterns:

### 1. gRPC/Protobuf for High-Frequency IPC (`td-g7pc04`)
- **Target**: Kernel <-> Daemon heartbeats.
- **Why**: JSON overhead is too high for $O(1ms)$ evidence receipts.
- **Impact**: 7-10x throughput increase for the Evidence Ring.

### 2. SSE (Server-Sent Events) for Log Streaming (`td-55e05`)
- **Target**: `Observatorium` and `Autognosis` UI.
- **Why**: Persistent HTTP stream is simpler than WebSockets for 1-way log feeds.
- **Impact**: Real-time observability with automatic reconnection and zero configuration.

### 3. MQTT-Lite for Hardware Ingest (`td-mq7706`)
- **Target**: Phase 4 IoT Ingest.
- **Why**: Optimized for low-bandwidth, battery-critical hardware sensors.
- **Impact**: Allows Anigma to ingest hardware security signals with minimal overhead.

---

## Architecture Constraints

### Tier Separation
- **Tier 1 (Contracts)**: Defines EventEnvelope, JobLease, CoordinatorLease, policies, IDs, and validation. No I/O.
- **Tier 2 (Execution)**: Owns runtime enforcement, persistence, scheduling, receipts, and lease recovery.
- **Tier 3+ (Features)**: Request events/jobs/leases only through Tier 2 authorities. Never import direct message/queue/broker tables.

### Payload Management
- All payloads use `PayloadReference` or `IndirectPayloadReference` when size or hot-path matters
- Large payloads live in Vault/CAS, not in broker messages or queue rows
- Broker payloads are metadata + references, not raw data blobs

### Governance & Provenance
- Every message/job/event carries: schema version, provenance, source capability, project/tenant scope, governance context
- All state-changing execution passes WriteGate where applicable
- Externally-backed adapters emit Toolchain/Infrastructure receipts
- Receipts link to EventLog appends, job operations, and lease transactions

### No Direct Broker Access
- No Tier 3 module imports database queue tables directly
- No feature modules import Kafka, RabbitMQ, Valkey, Redis, or client libraries
- External systems are adapter implementations behind Anigma protocols only
- Adapters are feature-flagged or in separate packages (not default build)

---

## Deliverables by Phase

### Phase 1: Semantic Foundations

**Contracts** (ContractsCore, Tier 1):
```swift
// Event streaming
protocol EventEnvelope: Codable {
  var eventId: UUID
  var streamId: EventStreamId
  var cursor: EventCursor
  var timestamp: Date
  var schemaVersion: String
  var provenance: EventProvenance
  var payload: PayloadReference
  var governanceContext: GovernanceContext
}

protocol EventStreamId: Hashable {
  var topic: String
  var partitionKey: String?  // For future multi-shard
  var projectId: String
}

protocol EventCursor: Comparable {
  var position: UInt64
  var streamId: EventStreamId
  var checkpointId: UUID?
}

// Work queue
protocol WorkQueueEnvelope: Codable {
  var jobId: UUID
  var idempotencyKey: String
  var priority: Int  // 0-100, higher = sooner
  var payload: PayloadReference
  var retryPolicy: RetryPolicy
  var governanceDecision: GovernanceDecisionId
  var sourceCapability: SourceCapabilityId
  var projectId: String
}

protocol JobLease: Codable {
  var jobId: UUID
  var workerId: WorkerId
  var leaseId: UUID
  var expiresAt: Date
  var visibilityTimeout: TimeInterval
}

protocol RetryPolicy: Codable {
  var maxAttempts: Int
  var initialDelayMs: Int
  var backoffMultiplier: Double
  var maxDelayMs: Int
  var deadLetterAfterFailed: Bool
}

// Coordination
protocol CoordinatorLease: Codable {
  var leaseId: UUID
  var key: String
  var holder: WorkerId
  var expiresAt: Date
  var refreshed: Date
}

protocol RateLimitPolicy: Codable {
  var requestsPerSecond: Int
  var burstCapacity: Int
  var algorithm: RateLimitAlgorithm  // sliding_window, token_bucket, etc.
}

protocol BackpressurePolicy: Codable {
  var maxPendingEvents: Int
  var dropBehavior: DropBehavior  // drop_newest, drop_oldest, block
}
```

**Protocols** (ExecutionAuthority, Tier 2):
```swift
protocol EventLog {
  func append(_ envelope: EventEnvelope) async throws -> EventCursor
  func subscribe(to streamId: EventStreamId, from cursor: EventCursor) async -> AsyncSequence<EventEnvelope>
  func replay(streamId: EventStreamId, from cursor: EventCursor, to endCursor: EventCursor?) async throws -> [EventEnvelope]
  func saveCheckpoint(_ checkpoint: EventCheckpoint) async throws
  func loadCheckpoint(id: UUID) async throws -> EventCheckpoint
}

protocol WorkQueue {
  func enqueue(_ job: WorkQueueEnvelope) async throws -> UUID  // jobId
  func claim(workerId: WorkerId, maxJobs: Int) async throws -> [JobLease]
  func acknowledge(leaseId: UUID) async throws
  func nack(leaseId: UUID, delay: TimeInterval) async throws
  func cancel(jobId: UUID) async throws -> Bool
  func getStatus(jobId: UUID) async throws -> JobStatus
}

protocol EphemeralCoordinator {
  func acquireLease(key: String, holder: WorkerId, ttlSeconds: Int) async throws -> CoordinatorLease
  func refreshLease(leaseId: UUID) async throws -> CoordinatorLease
  func releaseLease(leaseId: UUID) async throws
  func checkPresence(workerId: WorkerId) async throws -> PresenceStatus
  func checkRateLimit(clientId: String, policy: RateLimitPolicy) async throws -> RateLimitDecision
}
```

**Test doubles**:
- `InMemoryEventLog`: channels, no persistence
- `InMemoryWorkQueue`: dictionary of jobs, no durability
- `InMemoryCoordinator`: actor-based leases, no TTL enforcement

---

### Phase 2: Local Durable Implementation

**EventLog**:
- SQLite/Postgres append-only table: `events(event_id, stream_id, cursor, timestamp, schema_version, provenance_json, payload_ref, governance_context_json)`
- Cursor tracking: incremental position per stream
- Checkpoint persistence: `event_checkpoints(checkpoint_id, stream_id, cursor, label, created_at)`
- Replay semantics: ordered by position, filtered by stream_id
- Retention policy metadata (no pruning yet): `stream_retention(stream_id, retention_days, backpressure_policy_json)`

**WorkQueue**:
- Durable job table: `jobs(job_id, idempotency_key, priority, status, payload_ref, retry_policy_json, governance_decision_id, created_at, next_run_at, attempts)`
- Lease table: `job_leases(lease_id, job_id, worker_id, expires_at, visibility_timeout, claimed_at, acknowledged_at)`
- Dead-letter table: `dead_letters(job_id, reason, final_payload_ref, archived_at)`
- Indexes: status, priority, next_run_at, expires_at
- Scheduler loop: claim expired leases, check retry delays, move to dead-letter

**EphemeralCoordinator**:
- In-process Swift actor or SQLite lease table: `leases(lease_id, key, holder_id, expires_at, refreshed_at)`
- TTL enforcement: background task cleans expired leases every 10 seconds
- Rate limiter: memory-backed token buckets keyed by client_id
- Presence: worker heartbeat model tracking last_seen_at per worker_id

**Governance integration**:
- `event_append` operation emits EventAppendReceipt with schema version, provenance
- `job_enqueue`, `job_claim`, `job_acknowledge`, `job_retry`, `job_deadletter` each emit execution receipts
- Receipts link to source governance decision and source capability

---

### Phase 3: Observability Integration

**Observatorium**:
- Subscribe to system EventLog streams
- Render event timeline in dashboards
- Filter by source capability, project, operation type
- Latency heatmaps for job claim → acknowledge
- Worker heartbeat status page
- Dead-letter queue review interface

**Daemon**:
- Emit "daemon_started", "daemon_shutdown", "worker_claimed", "job_completed", "job_retried", "job_deadlettered" events
- Track event stream metrics in health checks

**ExecutionAuthority**:
- Record all receipt-emitting operations as EventLog appends for audit trail

---

### Phase 4: IoT/Ingest Readiness

**EventLog enhancements**:
- Partition key support for future multi-shard (topic + partitionKey → shard mapping)
- Retention policy enforcement: cleanup loop for old events
- Backpressure metadata: drop behavior (newest/oldest/block)
- Batch append API for high-frequency ingest
- Cursor offset caching for faster replay

**WorkQueue enhancements**:
- Batch enqueue API for bulk job creation
- Stream job status updates through EventLog for observability
- Priority inheritance for dependent jobs

---

### Phase 5: External Adapter Readiness

**Feature-flagged adapter packages** (no required runtime dependency):

1. **KafkaEventLogAdapter** (feature flag: `msg-kafka`):
   - Implements EventLog protocol
   - Appends to Kafka topic
   - Subscribes from Kafka consumer group
   - Checkpoint offset management
   - Compiled only when feature enabled

2. **RabbitMQWorkQueueAdapter** (feature flag: `msg-rabbitmq`):
   - Implements WorkQueue protocol
   - Enqueues to RabbitMQ queue
   - Claims via consumer prefetch + manual ack
   - DLX for dead-letters
   - Compiled only when feature enabled

3. **ValkeyCoordinatorAdapter** (feature flag: `msg-valkey`):
   - Implements EphemeralCoordinator protocol
   - Uses Redis/Valkey SET/EXPIRE for leases
   - Token bucket via Lua script
   - Pub/sub for notifications
   - Compiled only when feature enabled

**Adapter stubs**:
- Compile without external dependencies
- Log a warning: "Using local implementation; configure adapter for production deployment"
- Fall back to local implementation if adapter is not initialized

---

### Phase 6: Deployment Decision

**Decision matrix**:
- **Local only**: Anigma dev/test, single-machine deployments → use local implementations
- **Hybrid**: Some jobs external, events local → mix adapters
- **Full external**: Multi-machine cluster → all three adapters required
- **Kafka only**: Just event streams for observability → KafkaEventLogAdapter only

**Documentation**:
- "Postgres is the ledger, not the nervous system"
- "Adapters are promoted to required dependencies only when local workloads exceed measured limits or multi-machine deployment required"

---

## Acceptance Criteria

### WorkQueue
- [ ] A job can be enqueued with idempotency key
- [ ] A worker claims a job and receives a lease with expiry
- [ ] Worker acknowledges completion → job removed from queue
- [ ] Worker NACks → job retried after delay
- [ ] Lease expires → job returned to claimable state
- [ ] Max attempts exceeded → job moved to dead-letter
- [ ] Dead-letter jobs are queryable and reviewable
- [ ] Retry policy supports immediate, delayed, exponential backoff, max attempts
- [ ] All operations emit execution receipts with governance context

### EventLog
- [ ] Events can be appended with schema version and provenance
- [ ] Events can be replayed from a cursor
- [ ] Checkpoints can be saved and loaded
- [ ] Retention metadata is stored (no pruning required yet)
- [ ] All appends emit EventAppendReceipt
- [ ] Stream partitioning is defined (even if local ignores partitionKey)

### EphemeralCoordinator
- [ ] Leases can be acquired with TTL
- [ ] Leases can be refreshed before expiry
- [ ] Expired leases are released automatically
- [ ] Rate limit decisions are enforced
- [ ] Worker presence can be checked
- [ ] Coordinator gracefully degrades if unavailable (no required dependency)

### Governance & Architecture
- [ ] No Tier 3 module imports database queue/event tables directly
- [ ] No feature module imports Kafka, RabbitMQ, Valkey, Redis client libraries directly
- [ ] All job/event/lease operations carry governance context and receipts
- [ ] No Kafka/RabbitMQ/Redis/Valkey server required for local build
- [ ] Tests verify behavior through protocols, not SQL
- [ ] Documentation clearly states: "Postgres persists queue state; Anigma owns queue semantics"

---

## Implementation Order

1. **ContractsCore**: Define all protocols and envelopes (1-2 weeks)
2. **ExecutionAuthority**: Implement local EventLog, WorkQueue, EphemeralCoordinator (2-3 weeks)
3. **Scheduler + Daemon**: Integrate WorkQueue claiming and lease recovery (1-2 weeks)
4. **Observatorium**: Subscribe to EventLog and build dashboards (1-2 weeks)
5. **Adapter stubs**: Feature-flagged placeholder packages (1 week)
6. **Tests**: Comprehensive behavior tests for all three subsystems (ongoing)

---

## Canonical Doctrine

> **Postgres is the ledger, not the nervous system.**

- Postgres can persist queue state, checkpoint offsets, and job metadata.
- Postgres is not the owner of queue *semantics* (claim, lease, retry, dead-letter).
- EventLog means replayable event log semantics (append, replay from cursor, retention).
- WorkQueue means brokered work queue semantics (claim with lease, acknowledge, retry, backoff).
- EphemeralCoordinator means ephemeral coordination semantics (lease, TTL, presence, rate limit).
- Anigma owns the contracts, governance, and receipt emission.
- External systems (Kafka, RabbitMQ, Valkey) are replaceable transports behind Anigma-owned protocols.
- No external broker is required to run local Anigma.

---

## Non-Goals

- Installing or requiring Kafka, RabbitMQ, Redis, or Valkey runtime
- Distributed clustering (defer to Phase 5+)
- Exposing broker-specific concepts to feature modules
- Putting large payloads directly in messages
- Replacing Anigma Scheduler with external broker
- Cross-cluster event replication (defer to Phase 5+)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Feature modules bypass WorkQueue | Tier 2 owns all job persistence; Tier 3 has no direct query access |
| Lease expiry not detected | Recovery loop runs every 10 seconds; test with induced failures |
| Postgres becomes a bottleneck | EventLog append is async; batch APIs available in Phase 4 |
| Adapter migration too disruptive | Adapters implement same protocol; switch at runtime, no code changes |
| Dead-letter queue grows unbounded | Retention policy metadata in Phase 2; enforcement in Phase 4 |

---

## Success Metrics

- **No external broker required** for default local build ✅
- **100% test coverage** for all three subsystems ✅
- **Job claim → acknowledge latency < 1ms** (in-process) ✅
- **Event append latency < 10ms** (SQLite/Postgres) ✅
- **Zero Tier 3 direct database access** to job/event tables ✅
- **All operations emit governance receipts** ✅

---

## Related Issues

- #epic-msg-coord (this epic)
- #phase-msg-1 (Semantic foundations)
- #phase-msg-2 (Local implementation)
- #phase-msg-3 (Observability)
- #phase-msg-4 (IoT/ingest)
- #phase-msg-5 (Adapter readiness)
- #phase-msg-6 (Deployment decision)

---

## Appendix: Future Adapter Integration

### KafkaEventLogAdapter Example

```swift
#if MSG_KAFKA
import Kafka

struct KafkaEventLogAdapter: EventLog {
  private let producer: KafkaProducer
  private let consumer: KafkaConsumer
  
  func append(_ envelope: EventEnvelope) async throws -> EventCursor {
    let data = try JSONEncoder().encode(envelope)
    let topic = envelope.streamId.topic
    let partition = hashPartition(envelope.streamId.partitionKey)
    
    _ = try await producer.send(
      topic: topic,
      partition: partition,
      value: data,
      key: envelope.streamId.partitionKey
    )
    
    // Return cursor with Kafka offset
    return KafkaEventCursor(topic: topic, offset: producer.lastOffset)
  }
  
  // ... implement subscribe, replay, etc.
}
#endif
```

### RabbitMQWorkQueueAdapter Example

```swift
#if MSG_RABBITMQ
import AMQP

struct RabbitMQWorkQueueAdapter: WorkQueue {
  private let channel: AMQPChannel
  private let queueName: String
  
  func enqueue(_ job: WorkQueueEnvelope) async throws -> UUID {
    let data = try JSONEncoder().encode(job)
    try await channel.basicPublish(
      exchange: "",
      routingKey: queueName,
      properties: AMQPProperties(priority: UInt8(job.priority / 4)),
      body: data
    )
    return job.jobId
  }
  
  // ... implement claim, acknowledge, retry, etc.
}
#endif
```

---

**Status**: Ready for Phase 1 kickoff  
**Last Updated**: 2026-04-24
