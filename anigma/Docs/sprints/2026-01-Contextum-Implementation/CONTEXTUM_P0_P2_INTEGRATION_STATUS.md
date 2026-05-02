> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# Contextum P0-P2 Integration Status

> Historical sprint snapshot. This file reflects an earlier Contextum implementation view and is not the source of truth for current integration status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`

## Summary

This document tracks the implementation status of Contextum Phases 0-2, focusing on rock-solid foundations before proceeding to advanced features.

## Phase 0: Core Module ✅ (Complete)

**Status**: Implemented with ECS architecture and job-based API

### Components Created
- `ContextumModule` - Main capability module with ECS registration
- `ContextumDatabase` - DatabaseActor-backed persistence
- Database schema with migrations:
  - `events` - Structured telemetry with correlation
  - `chunks` - Chunk metadata + content hash
  - `fts_chunks` - FTS5 virtual table for full-text search
  - `embeddings` - Vector storage keyed by (chunkHash + modelHash)
  - `agent_stats` - Factual execution metrics

### Job Surface
- `context.ingest` - Ingest document/event reference
- `context.chunk` - Chunk content for indexing
- `context.search` - Query with FTS baseline
- `context.recordOutcome` - Record tool-call/agent execution

### Integration Points
- Orchestrator preflight (context retrieval before execution)
- Orchestrator postflight (outcome recording after execution)
- Correlation environment variables propagated to CLI agents

## Phase 1: Governed Embeddings + Hybrid Search ⚠️ (Partially Complete)

**Status**: Architecture defined, MLWorker wiring incomplete

### What Exists
- `MLWorkerEmbeddingExecutor` - Embedding execution bridge (created)
- Embedding database schema with provenance columns
- Hybrid search design (FTS + semantic with RRF merge)
- Resource budgets and backpressure design

### P0 Blockers 🔴

#### 1. MLWorker Execution Path Not Wired
**Problem**: `MLWorkerEmbeddingExecutor` is implemented but not connected to actual Contextum job execution.

**Fix Required**:
- Wire `EmbeddingRequestSystem` to call `MLWorkerEmbeddingExecutor.execute()`
- Inject `ContextumIntegration.createEmbeddingExecutor()` into Contextum workflow
- Implement embedding job enqueue/execute pipeline

**File**: `Sources/ContextumModule/Systems/EmbeddingRequestSystem.swift`

#### 2. Model Registry Integration Incomplete
**Problem**: `ModelRegistry` exists but not wired to Contextum for model resolution.

**Fix Required**:
- Add `ModelRegistry` dependency to `ContextumModule.register()`
- Wire model resolution in embedding workflow
- Validate embedding model is registered before execution

**Files**:
- `Sources/ContextumModule/ContextumModule.swift`
- `Sources/AnigmaAppMac/AppStore.swift` (initialization)

#### 3. Embedding Persistence Not Implemented
**Problem**: `EmbeddingRow` type exists but database write path missing.

**Fix Required**:
- Implement `insertEmbeddings()` in `ContextumDatabase`
- Add `EmbeddingComponent` to ECS registry
- Wire embedding results to database after MLWorker execution

**File**: `Sources/ContextumModule/Database/ContextumDatabase.swift`

### P1 Blockers 🟡

#### 4. Semantic Search Not Implemented
**Problem**: Cosine similarity scan and semantic retrieval missing.

**Fix Required**:
- Implement `searchSemantic()` in `HybridSearchSystem`
- Add brute-force cosine scan with candidate limits
- Record query embedding provenance in telemetry

**File**: `Sources/ContextumModule/Systems/HybridSearchSystem.swift`

#### 5. RRF Merge Not Implemented
**Problem**: Reciprocal Rank Fusion merge logic not written.

**Fix Required**:
- Implement `mergeWithRRF()` in `HybridSearchSystem`
- Record per-path ranks and final ranks in telemetry
- Make merge parameters configurable (k constant)

**File**: `Sources/ContextumModule/Systems/HybridSearchSystem.swift`

## Phase 2: Auto-Indexing + MLWorker Wiring ⚠️ (Architecture Only)

**Status**: Design complete, implementation missing

### What Exists
- `ArtifactStoreEventBridge` - Auto-indexing bridge (created)
- `ArtifactCommitEvent` - Event type for materialization
- Debouncing logic for batch commits

### P0 Blockers 🔴

#### 6. Artifact Store Not Emitting Events
**Problem**: No artifact store integration to trigger indexing.

**Fix Required**:
- Identify artifact commit points in codebase
- Emit `ArtifactCommitEvent` on materialization
- Wire to `ContextumIntegration.recordArtifactCommit()`

**Investigation Required**: Where does artifact persistence happen?

#### 7. Job Enqueue Not Wired
**Problem**: `ArtifactStoreEventBridge.enqueueIndexingJobs()` is a stub.

**Fix Required**:
- Implement job enqueue via Contextum workflow system
- Create dependency chain: ingest → chunk → embed
- Record `IndexPlanEvent` to telemetry

**File**: `Sources/ContextumModule/Integration/ArtifactStoreEventBridge.swift`

### P1 Blockers 🟡

#### 8. Index State Tracking Missing
**Problem**: No persistent tracking of indexing state.

**Fix Required**:
- Add `index_state` table to schema
- Implement `IndexStateComponent` ECS component
- Check state before enqueuing redundant jobs

**Files**:
- `Sources/ContextumModule/Database/ContextumDatabase.swift`
- `Sources/ContextumModule/Components/IndexStateComponent.swift` (create)

#### 9. Chunker Version Not Enforced
**Problem**: Chunking changes will break indexing without versioning.

**Fix Required**:
- Add `chunker_version` column to chunks table migration
- Store version in `ChunkComponent`
- Support multiple chunk generations per contentHash

**File**: `Sources/ContextumModule/Database/ContextumDatabase.swift`

## Phase 3-6: Advanced Features ❌ (Not Started)

**Status**: Implementation attempted but incomplete, needs Phase 0-2 solid first.

### Deferred Until P0-P2 Complete
- Phase 3: Analytics rollups and anomaly detection
- Phase 4: Forensics and failure reports
- Phase 5: Feedback loops and recommendations
- Phase 6: Retention, redaction, compaction

## Action Plan

### Immediate Focus (P0 Blockers)

1. **Wire MLWorker Embedding Execution**
   - Connect `EmbeddingRequestSystem` to `MLWorkerEmbeddingExecutor`
   - Test end-to-end: chunk → embed job → MLWorker → receipt

2. **Implement Embedding Persistence**
   - Add database write path for `EmbeddingRow`
   - Validate provenance fields are stored correctly

3. **Wire Model Registry to Contextum**
   - Pass `ModelRegistry` to `ContextumModule` initialization
   - Validate model exists and is embedding-capable before execution

4. **Implement Artifact Event Emission**
   - Find artifact store commit points
   - Emit `ArtifactCommitEvent` with proper hashing

5. **Wire Job Enqueue Pipeline**
   - Implement `enqueueIndexingJobs()` with real workflow calls
   - Create job dependency chain

### Next Steps (P1 Blockers)

6. **Implement Semantic Search**
   - Cosine scan with candidate limits
   - Query embedding provenance

7. **Implement RRF Merge**
   - Combine FTS + semantic ranks
   - Record merge telemetry

8. **Add Index State Tracking**
   - Persistent state to avoid redundant work
   - Idempotency guarantees

9. **Enforce Chunker Versioning**
   - Multi-generation chunk storage
   - Safe re-chunking path

## Test Coverage Needed

### P0 Tests (Required)
- [ ] Embedding job executes via MLWorker with receipt
- [ ] Embedding rows persist with provenance
- [ ] Model not found fails loudly with telemetry
- [ ] MLWorker unavailable degrades search to FTS-only
- [ ] Artifact commit triggers indexing jobs
- [ ] Debouncing prevents fan-out during batch commit

### P1 Tests (Required)
- [ ] Semantic search returns ranked results
- [ ] Hybrid search merges FTS + semantic with RRF
- [ ] Index state prevents duplicate indexing
- [ ] Chunker version change doesn't corrupt existing chunks

## Integration Checklist

- [x] `ContextumModule` created with ECS architecture
- [x] `ContextumDatabase` uses `DatabaseActor`
- [x] FTS5 search implemented
- [x] Orchestrator preflight/postflight hooks exist
- [ ] MLWorker embedding execution wired
- [ ] Model Registry integrated
- [ ] Embedding persistence implemented
- [ ] Artifact store events wired
- [ ] Auto-indexing job enqueue implemented
- [ ] Semantic search implemented
- [ ] RRF merge implemented
- [ ] Index state tracking added
- [ ] Chunker versioning enforced

## Notes

- **Architecture is solid**: ECS components, job-based API, DatabaseActor persistence
- **Foundation is incomplete**: Wiring between layers missing
- **Do NOT proceed to Phase 3-6** until P0-P2 blockers resolved
- **Focus on boring correctness**: Provenance, idempotency, determinism

---

*Last Updated: 2026-01-07*
*Status: Phase 0 complete, Phase 1-2 partially implemented, P0 blockers identified*
