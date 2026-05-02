# Messaging & Coordination Foundations — Quick Reference

**Epic ID**: `epic-msg-coord`  
**Status**: Planning → Ready for Phase 1  
**Documentation Location**: `Docs/roadmaps/`

---

## What is This?

Architectural foundations for three core messaging subsystems:
- **EventLog**: Append-only event streams (Kafka-like, no Kafka required)
- **WorkQueue**: Durable job broker (RabbitMQ-like, no RabbitMQ required)
- **EphemeralCoordinator**: Transient coordination (Valkey-like, no Redis required)

**Goal**: Define contracts and governance rules in Tier 1, implement locally in Tier 2, optionally adapt to external systems in Phase 5.

---

## Core Principle

> Postgres is the ledger, not the nervous system.

External brokers are optional adapters. Anigma owns the semantics and governance.

---

## Three First-Class Ports

### 1. EventLog (Kafka-like)
**Use cases**: Daemon events, agent traces, IoT ingest, workflow history, audit trails

**Key methods**:
- `append(envelope) -> cursor`
- `subscribe(streamId, cursor) -> AsyncSequence<EventEnvelope>`
- `replay(streamId, startCursor, endCursor) -> [EventEnvelope]`
- `saveCheckpoint(checkpoint)` / `loadCheckpoint(id)`

**Initial**: Local append-only (SQLite/Postgres), no Kafka dependency

---

### 2. WorkQueue (RabbitMQ-like)
**Use cases**: Daemon jobs, indexing, OCR/PDF, rendering, agent execution

**Key methods**:
- `enqueue(envelope) -> jobId`
- `claim(workerId, maxJobs) -> [JobLease]`
- `acknowledge(leaseId) -> receipt`
- `nack(leaseId, delay) -> receipt`
- `recoverExpiredLeases() -> count`

**Initial**: Postgres/SQLite durable table, no RabbitMQ dependency

---

### 3. EphemeralCoordinator (Valkey-like)
**Use cases**: Worker leases, presence, rate limits, transient locks

**Key methods**:
- `acquireLease(key, holder, ttlSeconds) -> CoordinatorLease`
- `refreshLease(leaseId, ttlSeconds) -> CoordinatorLease`
- `releaseLease(leaseId) -> receipt`
- `checkPresence(workerId) -> PresenceStatus`
- `checkRateLimit(clientId, policy) -> RateLimitDecision`

**Initial**: In-process Swift actor or SQLite, no Redis/Valkey dependency

---

## Six-Phase Roadmap

| Phase | Title | Duration | Status |
|-------|-------|----------|--------|
| 1 | Semantic Foundations | 2-3w | 🔄 Ready |
| 2 | Local Durable Implementation | 2-3w | 📋 Queued |
| 3 | Observability Integration | 1-2w | 📋 Queued |
| 4 | IoT/Ingest Readiness | 1w | 📋 Queued |
| 5 | External Adapter Readiness | 1w | 📋 Queued |
| 6 | Deployment Decision | Ongoing | 📋 Queued |

---

## Architecture Constraints

### Tier Separation
- **Tier 1** (ContractsCore): Protocols, envelopes, validation only. Zero I/O.
- **Tier 2** (ExecutionAuthority): Runtime enforcement, persistence, receipts.
- **Tier 3+** (Features): Request through Tier 2 only. No direct database access.

### Governance
- All messages carry: schema version, provenance, source capability, project scope, governance context
- All operations emit receipts with signatures
- Externally-backed adapters emit Toolchain/Infrastructure receipts

### Payload Management
- Use `PayloadReference` or `IndirectPayloadReference` when size/performance matters
- Large payloads in Vault/CAS, not in messages
- Messages are metadata + references only

### No Direct Broker Import
- No Tier 3 module imports Kafka, RabbitMQ, Redis, Valkey, or client libraries
- External systems are adapter implementations behind Anigma protocols only
- Adapters are feature-flagged, not default build

---

## Phase 1: Semantic Foundations

**Deliverable Types** (no persistence, all in ContractsCore):

### EventLog Types
```
EventEnvelope
EventStreamId
EventCursor
EventCheckpoint
EventProvenance
StreamRetentionPolicy
BackpressurePolicy
EventAppendReceipt
```

### WorkQueue Types
```
WorkQueueEnvelope
WorkerId
JobPriority
RetryPolicy
JobLease
JobStatus
DeadLetterRecord
JobOperationReceipt
```

### Coordination Types
```
CoordinatorLease
RateLimitPolicy
RateLimitAlgorithm
RateLimitDecision
PresenceStatus
WorkerPresence
CoordinationReceipt
```

### Protocols (ExecutionAuthority)
```
protocol EventLog { append, subscribe, replay, checkpoint }
protocol WorkQueue { enqueue, claim, acknowledge, nack, recover }
protocol EphemeralCoordinator { acquire, refresh, release, presence, rateLimit }
```

### Test Doubles (in-memory, no persistence)
```
InMemoryEventLog (channel-based)
InMemoryWorkQueue (dictionary-based)
InMemoryEphemeralCoordinator (actor-based)
```

---

## Phase 2: Local Durable Implementation

**SQLite/Postgres tables**:
```
events(event_id, stream_id, cursor, timestamp, schema_version, provenance_json, payload_ref, governance_context)
event_checkpoints(checkpoint_id, stream_id, cursor, label, created_at, updated_at)
stream_retention(stream_id, retention_days, backpressure_policy)

jobs(job_id, idempotency_key, priority, status, payload_ref, retry_policy, created_at, next_run_at, attempts)
job_leases(lease_id, job_id, worker_id, expires_at, visibility_timeout, claimed_at, acknowledged_at)
dead_letters(job_id, reason, final_payload_ref, archived_at)

leases(lease_id, key, holder_id, expires_at, refreshed_at)
worker_presence(worker_id, status, last_heartbeat, registered_at)
```

**Scheduler integration**:
- Claim expired leases every 10 seconds
- Check retry delays, move to dead-letter
- Emit job operation receipts for all state changes

---

## Phase 3: Observability

**Observatorium subscriptions**:
- System EventLog streams (daemon_started, job_claimed, worker_heartbeat, etc.)
- Event timeline dashboards filtered by source, project, operation
- Worker heartbeat status page
- Dead-letter queue review interface
- Job claim → acknowledge latency heatmaps

---

## Phase 4: IoT/Ingest Readiness

**EventLog enhancements**:
- Partition key support for future multi-shard
- Retention policy enforcement with cleanup loop
- Backpressure metadata (drop/block behavior)
- Batch append API
- Cursor offset caching

**WorkQueue enhancements**:
- Batch enqueue API
- Stream job status updates through EventLog
- Priority inheritance for dependent jobs

---

## Phase 5: External Adapters

**Feature-flagged adapters** (no required runtime dependency):

| System | Target | Feature Flag |
|--------|--------|--------------|
| Kafka | EventLog | `msg-kafka` |
| RabbitMQ | WorkQueue | `msg-rabbitmq` |
| Valkey | EphemeralCoordinator | `msg-valkey` |

**Adapter pattern**:
```swift
#if MSG_KAFKA
import Kafka
struct KafkaEventLogAdapter: EventLog { ... }
#endif
```

All adapters implement same protocol. Switch at runtime, no code changes needed.

---

## Phase 6: Deployment Decision

**Decision matrix**:
- **Local only**: Dev/test, single machine → use local implementations
- **Hybrid**: Some external, some local → mix adapters
- **Full external**: Multi-machine cluster → all external adapters
- **Kafka only**: Event observability only → EventLog adapter only

**Promotion rule**: External adapter becomes required dependency only when:
1. Local workload exceeds measured durability/throughput limits, OR
2. Multi-machine deployment requires cross-node coordination

---

## Acceptance Criteria (All Phases)

✅ **WorkQueue**:
- Job enqueue → claim → acknowledge → completion flow
- Lease expiry → job returns to claimable state
- Retry with exponential backoff
- Dead-letter for poison pills
- All operations emit receipts

✅ **EventLog**:
- Events append with schema versioning
- Replay from checkpoint
- Retention metadata stored
- All appends emit EventAppendReceipt

✅ **EphemeralCoordinator**:
- Lease acquire/refresh/release with TTL
- Worker presence tracking
- Rate limit decisions
- Graceful degradation when unavailable

✅ **Governance**:
- No Tier 3 direct database access to queue/event tables
- All operations carry governance context
- Every append/enqueue/claim emits receipt
- Tests verify through protocols, not SQL

✅ **No External Dependencies**:
- No Kafka/RabbitMQ/Redis/Valkey required for local build
- Adapters optional (feature flags)
- Postgres allowed for durability; not required

---

## Key Files

| File | Purpose | Phase |
|------|---------|-------|
| `MESSAGING_AND_COORDINATION_FOUNDATIONS.md` | Epic overview, 6-phase roadmap | All |
| `PHASE_1_SEMANTIC_FOUNDATIONS.md` | Phase 1 detailed spec with code | 1 |
| `Packages/ContractsCore/Messaging/*.swift` | Type definitions | 1 |
| `Packages/AnigmaCore/ExecutionAuthority/Messaging/MessagingProtocols.swift` | Protocol definitions | 1 |
| `Packages/AnigmaCore/ExecutionAuthority/Messaging/InMemoryImplementations.swift` | Test doubles | 1 |
| `Tests/ContractsCoreTests/MessagingProtocolsTests.swift` | Unit tests | 1 |
| `Tests/AnigmaCoreTests/MessagingProtocolTests.swift` | Protocol tests | 1 |

---

## Success Metrics

- **Zero external broker required** for default local build ✅
- **100% test coverage** for all three subsystems
- **Job claim → acknowledge latency < 1ms** (in-process)
- **Event append latency < 10ms** (SQLite/Postgres)
- **Zero Tier 3 direct database access** to job/event tables
- **All operations emit governance receipts**

---

## Canonical Doctrine (Remember This!)

1. **Postgres is the ledger, not the nervous system**
   - Postgres can persist; Anigma owns semantics

2. **Three first-class subsystems**
   - EventLog, WorkQueue, EphemeralCoordinator
   - All three need explicit ports, not conflated

3. **External systems are optional adapters**
   - Kafka → KafkaEventLogAdapter (feature flag)
   - RabbitMQ → RabbitMQWorkQueueAdapter (feature flag)
   - Valkey → ValkeyCoordinatorAdapter (feature flag)
   - All implement same protocol

4. **Governance everywhere**
   - Every message/job/lease carries context
   - Every operation emits receipt
   - Tier 1 defines contracts; Tier 2 enforces; Tier 3+ consumes

5. **Payloads are references**
   - Large data in Vault/CAS
   - Messages carry metadata + pointers
   - Backpressure policies explicit

---

## How to Contribute

1. **Phase 1**: Define ContractsCore types + in-memory test doubles
2. **Phase 2**: Implement SQLite/Postgres persistence + scheduler integration
3. **Phase 3**: Subscribe to events, build dashboards
4. **Phase 4**: Add batch APIs, partition support, retention enforcement
5. **Phase 5**: Write adapter plugins (Kafka, RabbitMQ, Valkey)
6. **Phase 6**: Deploy decision based on measured workload

Each phase is independent. Phase N does not depend on external N+1 work.

---

## FAQ

**Q: Do I need Kafka?**  
A: No. EventLog has local implementation. Kafka is optional Phase 5 adapter.

**Q: Can I put large payloads in messages?**  
A: No. Use PayloadReference to Vault/CAS. Messages carry metadata + pointers only.

**Q: Can Tier 3 modules import RabbitMQ?**  
A: No. Only Tier 2 imports WorkQueue; Tier 3 uses it through protocol.

**Q: What if I want to replace EventLog with Kafka later?**  
A: Implement KafkaEventLogAdapter (Phase 5). All Tier 3 code stays unchanged.

**Q: Is Postgres still the system of record?**  
A: Yes. Postgres persists receipts, audit logs, governance decisions. WorkQueue state also stored there. Anigma owns the semantics.

**Q: When should I promote an adapter to required dependency?**  
A: Only when local workload exceeds measured limits or multi-machine deployment requires cross-node coordination (Phase 6 decision).

---

## Next Action

Start Phase 1 implementation:
1. Create `Packages/ContractsCore/Sources/ContractsCore/Messaging/` directory
2. Implement all type definitions (EventEnvelope, WorkQueueEnvelope, CoordinatorLease, etc.)
3. Implement ExecutionAuthority protocols
4. Create in-memory test doubles
5. Write 150+ unit and protocol tests
6. Move to Phase 2 (persistence) when Phase 1 complete

---

**Last Updated**: 2026-04-24  
**Owner**: Anigma Architecture Council  
**Status**: Ready for Phase 1 kickoff
