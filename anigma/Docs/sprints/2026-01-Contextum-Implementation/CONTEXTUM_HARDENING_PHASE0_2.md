> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# Contextum Phases 0-2 Hardening Plan

## Status: In Progress
**Date**: 2026-01-07

## Objective
Transform Phases 0-2 from "it compiles" to "production-ready with court-safe guarantees."

## Critical Gaps Identified

### Phase 0: Core Module
1. **Error Handling**: Missing comprehensive error types and recovery paths
2. **Validation**: Insufficient input validation on critical paths
3. **Idempotency**: State keys exist but enforcement is incomplete
4. **Concurrency**: No rate limiting or bounded parallelism
5. **Testing**: Missing integration tests for error conditions

### Phase 1: Embeddings + Hybrid Search
1. **MLWorker Integration**: Placeholder implementation, not actual governed execution
2. **Backpressure**: Defined but not enforced with actual queuing
3. **Provenance**: Receipt recording incomplete, no evidence head hashing
4. **Dimension Validation**: Embedding vectors not validated against model spec
5. **RRF Implementation**: Merge logic needs determinism guarantees

### Phase 2: Auto-Indexing
1. **Debouncing**: Logic sketched but not implemented with actual timers
2. **Artifact Store Bridge**: Missing actual event subscription
3. **Idempotency**: State keys defined but duplicate detection incomplete
4. **Batch Processing**: No actual batching implementation
5. **Failure Handling**: Missing graceful degradation and retry logic

## Hardening Tasks

### Task 1: Comprehensive Error Taxonomy
**File**: `Sources/ContextumModule/ContextumErrors.swift` (new)
- Define exhaustive error cases for each subsystem
- Include diagnostic payloads for forensics
- Map to HTTP/RPC error codes for XPC boundary

### Task 2: Input Validation Layer
**Files**: All Systems
- Add pre-condition validation with explicit error messages
- Validate chunk boundaries, token counts, hash formats
- Validate embedding dimensions against model spec
- Reject malformed correlation tuples

### Task 3: Idempotency Enforcement
**File**: `Sources/ContextumModule/Systems/IdempotencyGuard.swift` (new)
- Centralized idempotency key generation and checking
- State key format: `{operation}:{contentHash}:{chunkerVersion}:{modelHash}`
- Database-backed deduplication with atomic inserts
- Return existing results for duplicate requests

### Task 4: MLWorker Integration (Real)
**File**: `Sources/ContextumModule/Execution/EmbeddingJobExecutor.swift` (new)
- Replace placeholder with actual `MLWorkerClient.executeGovernedRun()` calls
- Parse NDJSON streaming responses for embeddings
- Store receiptID and evidenceHeadHash in embeddings table
- Enforce model contract validation before embedding

### Task 5: Backpressure + Resource Budgets
**File**: `Sources/ContextumModule/Execution/ResourceBudgetEnforcer.swift` (new)
- Track in-flight embedding jobs (per-run and global)
- Enforce max queue depth with explicit rejection
- Implement backoff when MLWorker is saturated
- Emit telemetry events for budget violations

### Task 6: Debouncing + Batching
**File**: `Sources/ContextumModule/Adapters/ArtifactIngestionAdapter.swift` (enhance)
- Time-window based debouncing (collect events, trigger after delay)
- Batch chunk jobs by source to avoid fan-out
- Batch embedding requests to MLWorker (max 50 chunks/batch)
- Cancel pending batches on shutdown

### Task 7: Hybrid Search Determinism
**File**: `Sources/ContextumModule/Systems/HybridSearchSystem.swift` (harden)
- Implement stable tie-breaking for RRF merge
- Record per-path ranks in search telemetry
- Add query hash validation
- Return empty result with telemetry on failure, never throw

### Task 8: Search Telemetry Completeness
**File**: `Sources/ContextumModule/Systems/HybridSearchSystem.swift`
- Record FTS rank list, semantic rank list, final merged rank
- Include model identity in telemetry when semantic is used
- Record degradation events when semantic path fails
- Hash the complete result set for replay validation

### Task 9: Integration Tests
**File**: `Tests/ContextumModuleTests/` (new directory)
- Test: Ingest → Chunk → Embed → Search (happy path)
- Test: Duplicate ingest is idempotent
- Test: MLWorker failure triggers FTS-only degradation
- Test: Backpressure rejects when queue is full
- Test: Debouncing batches multiple artifact commits

### Task 10: XPC Service Wiring
**File**: `Sources/AnigmaContextDaemonHost/` (new target)
- macOS XPC service target with entitlements
- Protocol: `ContextDaemonProtocol` with async job submission
- Route all calls through ContextumModule
- Emit receipts back to caller

## Acceptance Criteria

### Phase 0 Complete When:
- [ ] All public APIs validate inputs with typed errors
- [ ] Idempotency enforced on ingest, chunk, embed
- [ ] Integration test suite passes with 90%+ coverage
- [ ] Telemetry events include full correlation tuple
- [ ] Database migrations tested forward and backward

### Phase 1 Complete When:
- [ ] Embeddings only produced via MLWorker with receipts
- [ ] Hybrid search degrades to FTS with logged reason
- [ ] Backpressure enforces budget limits with metrics
- [ ] RRF merge is deterministic (same input = same output)
- [ ] Search telemetry allows full replay reconstruction

### Phase 2 Complete When:
- [ ] Artifact commits trigger indexing automatically
- [ ] Debouncing batches ≥5 commits in test scenario
- [ ] Duplicate commits don't create duplicate embeddings
- [ ] Indexing failure doesn't block artifact storage
- [ ] Auto-indexing integration test passes end-to-end

## Implementation Order

1. **Error Taxonomy + Validation** (foundation)
2. **Idempotency Guard** (prevents data corruption)
3. **MLWorker Integration** (critical path)
4. **Backpressure** (prevents resource exhaustion)
5. **Hybrid Search Determinism** (court-safe requirement)
6. **Search Telemetry** (forensics dependency)
7. **Debouncing + Batching** (performance + stability)
8. **Integration Tests** (proof of correctness)
9. **XPC Service** (deployment readiness)
10. **Documentation Update** (handoff readiness)

## Timeline
- Tasks 1-3: 2 hours
- Tasks 4-6: 3 hours
- Tasks 7-8: 1 hour
- Tasks 9-10: 2 hours
- **Total**: ~8 hours of focused implementation

---
*Next: Start with Task 1 (Error Taxonomy)*
