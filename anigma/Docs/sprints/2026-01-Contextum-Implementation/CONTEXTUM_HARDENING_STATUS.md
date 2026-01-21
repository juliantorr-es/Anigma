# Contextum Phases 0-2 Hardening Status

**Date**: 2026-01-07  
**Session**: Rock-solid implementation review

## Completed Hardening

### ✅ Task 1: Comprehensive Error Taxonomy
**File**: `Sources/ContextumModule/ContextumErrors.swift`
- Exhaustive error cases for validation, state, resources, execution, provenance
- Diagnostic payloads for every error type
- Error codes for RPC/XPC boundary
- Recoverable vs non-recoverable classification
- Degradation error marking

### ✅ Task 2: Idempotency Guard
**File**: `Sources/ContextumModule/Systems/IdempotencyGuard.swift`
- Centralized state key generation (ingest, chunk, embed, index)
- Database-backed deduplication with atomic operations
- Idempotency check results (should proceed vs already done)
- State recording and completion tracking
- Database extensions for state queries

## In-Progress Hardening

### 🔄 Task 3: Input Validation Layer
**Status**: Needs integration into all Systems
**Next Steps**:
1. Add validation to `IngestNormalizeSystem.process()`
2. Add validation to `ChunkingSystem.process()`
3. Add validation to `HybridSearchSystem.search()`
4. Add validation to embedding execution paths

### 🔄 Task 4: Real MLWorker Integration
**Status**: Placeholder exists, needs replacement
**Current Gap**: `EmbeddingRequestSystem` uses mock execution
**Next Steps**:
1. Create `EmbeddingJobExecutor` with actual `MLWorkerClient` calls
2. Parse NDJSON streaming responses
3. Extract and store `receiptID` and `evidenceHeadHash`
4. Enforce model contract validation before embedding

### 🔄 Task 5: Backpressure + Resource Budgets
**Status**: Types defined, enforcement missing
**Next Steps**:
1. Create `ResourceBudgetEnforcer` actor
2. Track in-flight jobs (per-run + global counters)
3. Implement queue depth limits with rejection
4. Emit telemetry on budget violations

### 🔄 Task 6: Debouncing + Batching
**Status**: Logic sketched, not implemented
**Next Steps**:
1. Add time-window debouncing to `ArtifactIngestionAdapter`
2. Implement batch collection and trigger logic
3. Add batch size limits (max 50 chunks/request)
4. Handle shutdown gracefully (cancel pending batches)

### 🔄 Task 7: Hybrid Search Determinism
**Status**: RRF exists, needs hardening
**Next Steps**:
1. Add stable tie-breaking in `HybridSearchSystem`
2. Record per-path ranks in telemetry
3. Add query hash validation
4. Never throw on search failure, return empty + telemetry

### 🔄 Task 8: Search Telemetry Completeness
**Status**: Basic telemetry exists, needs enrichment
**Next Steps**:
1. Record FTS ranks, semantic ranks, final ranks
2. Include model identity when semantic is used
3. Record degradation events explicitly
4. Hash result set for replay validation

## Not Started

### ⏳ Task 9: Integration Tests
**File**: `Tests/ContextumModuleTests/` (new directory)
**Required Coverage**:
- Ingest → Chunk → Embed → Search (happy path)
- Duplicate ingest is idempotent
- MLWorker failure triggers FTS-only degradation
- Backpressure rejects when queue is full
- Debouncing batches multiple artifact commits

### ⏳ Task 10: XPC Service Wiring
**File**: `Sources/AnigmaContextDaemonHost/` (new target)
**Deliverables**:
- macOS XPC service target with entitlements
- `ContextDaemonProtocol` with async job submission
- Route all calls through `ContextumModule`
- Emit receipts back to caller

## Critical Gaps Remaining

### 1. MLWorker Integration (BLOCKER for Phase 1 completion)
**Impact**: Embeddings are not actually governed without this
**Effort**: ~2 hours
**Priority**: P0

### 2. Backpressure Enforcement (BLOCKER for production readiness)
**Impact**: System can be resource-starved without this
**Effort**: ~1.5 hours
**Priority**: P0

### 3. Validation Layer (BLOCKER for court-safe claims)
**Impact**: Invalid data can corrupt provenance chain
**Effort**: ~1 hour
**Priority**: P0

### 4. Debouncing (BLOCKER for performance)
**Impact**: Repo checkout causes embedding explosion
**Effort**: ~1.5 hours
**Priority**: P1

### 5. Search Determinism (BLOCKER for replay)
**Impact**: Forensics can't reconstruct search results
**Effort**: ~1 hour
**Priority**: P1

### 6. Integration Tests (BLOCKER for confidence)
**Impact**: Can't prove system works end-to-end
**Effort**: ~2 hours
**Priority**: P1

## Revised Timeline

### Immediate (Next 4 hours)
1. MLWorker Integration (2 hrs)
2. Backpressure Enforcement (1.5 hrs)
3. Validation Layer (0.5 hrs)

### Short-term (Next 4 hours after that)
4. Debouncing + Batching (1.5 hrs)
5. Search Determinism (1 hr)
6. Search Telemetry (0.5 hrs)
7. Integration Tests (1 hr)

### Later (Phase 3+)
8. XPC Service (Phase 3 dependency)
9. Full test coverage expansion
10. Performance benchmarking

## Acceptance Criteria Updates

### Phase 0 Hardened When:
- [x] Comprehensive error taxonomy with diagnostics
- [x] Idempotency guard with state key generation
- [ ] Input validation on all public APIs ← **IN PROGRESS**
- [ ] Integration test suite passing ← **NOT STARTED**
- [x] Database schema with proper indexes

### Phase 1 Hardened When:
- [ ] Embeddings via MLWorker only (no mocks) ← **BLOCKER**
- [ ] Backpressure enforced with metrics ← **BLOCKER**
- [ ] Hybrid search deterministic with telemetry ← **IN PROGRESS**
- [ ] RRF merge stable and replayable ← **IN PROGRESS**

### Phase 2 Hardened When:
- [ ] Auto-indexing from artifact commits ← **PLACEHOLDER**
- [ ] Debouncing batches commits ← **NOT IMPLEMENTED**
- [ ] Idempotency prevents duplicates ← **FOUNDATION DONE**
- [ ] Integration test proves end-to-end ← **NOT STARTED**

## Recommendations

1. **Prioritize MLWorker integration immediately** - this is the foundation of "governed embeddings"
2. **Add backpressure before any load testing** - without this, the system will fall over
3. **Validation can be incremental** - start with the most critical paths (ingest, embed)
4. **Defer XPC service until Phase 3** - not a blocker for core functionality
5. **Write integration tests as you harden** - they'll catch gaps faster than manual testing

## Next Action

Execute Tasks 3-4-5 in parallel:
- Integrate validation into `IngestNormalizeSystem` and `ChunkingSystem`
- Replace `EmbeddingRequestSystem` mock with real `MLWorkerClient` execution
- Implement `ResourceBudgetEnforcer` and wire into embedding path

Estimated time to "Phase 0-2 actually hardened": **6-8 hours of focused work**.

---
*Updated: 2026-01-07T20:28Z*
