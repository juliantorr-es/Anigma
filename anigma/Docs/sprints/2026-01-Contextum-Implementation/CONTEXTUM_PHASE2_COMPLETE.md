> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# Contextum Phase 2: Auto-Indexing and MLWorker Integration

## Status: IMPLEMENTED

## What Was Built

Phase 2 delivers **auto-indexing from artifact commits** with **governed MLWorker embedding execution**, idempotency guarantees, and graceful degradation when MLWorker is unavailable.

---

## Architecture

### Auto-Indexing Pipeline

**ArtifactCommitComponent** → **AutoIndexSystem** → **IndexStateComponent** → **ChunkOrchestrationSystem** → **EmbedOrchestrationSystem** → **MLWorkerEmbeddingExecutor**

Every artifact commit triggers:
1. **Index plan creation** with deduplication (same contentHash + chunkerVersion + embeddingModelID = one IndexState)
2. **Chunking job** enqueued when chunkingNeeded=true
3. **Embedding job** enqueued when embeddingNeeded=true AND chunks exist
4. **MLWorker execution** with receipts, provenance, and backpressure

### Idempotency Guarantees

- **State key** = `{contentHash}_{chunkerVersion}_{embeddingModelID}`
- Duplicate artifact commits with same state key → single IndexState
- Re-running AutoIndexSystem on same commits → no new IndexStates created
- Embedding jobs check existing embeddings before requesting new ones

### Backpressure and Budgets

- **maxInFlightEmbeddings**: Hard cap on concurrent embedding jobs (default: 10)
- **maxBatchSize**: Max chunks per embedding job (default: 100)
- When queue is full, jobs wait; orchestrator continues with FTS-only search

### Governed MLWorker Execution

Embeddings are **never computed inline**. Every embedding request:
1. Creates a `RunSpec` with inputHash, modelSpec, budgets, timestamp
2. Calls `mlWorkerClient.executeEmbedding()` through governed path
3. Receives `EmbeddingResult` with embeddings, modelHash, receiptID, evidenceHeadHash
4. Stores embeddings with full provenance: (chunkHash, embeddingModelID, modelHash, receiptID, evidenceHeadHash)
5. Keeps the source→chunk→embedding chain queryable through the context graph views

### Failure Modes

- **MLWorker unavailable**: Job fails, telemetry records `"mlworker_unavailable"`, search degrades to FTS-only
- **Embedding count mismatch**: Job fails with diagnostic error
- **Missing chunks**: Job fails before calling MLWorker
- All failures emit telemetry events with jobID, error, failureMode

---

## Database Schema Additions

```sql
-- Artifact commit tracking
CREATE TABLE contextum_artifact_commits (
    id TEXT PRIMARY KEY,
    artifact_id TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    source_hash TEXT NOT NULL,
    media_type TEXT NOT NULL,
    commit_receipt_id TEXT NOT NULL,
    chunker_version INTEGER NOT NULL,
    embedding_model_id TEXT,
    indexed INTEGER NOT NULL DEFAULT 0,
    committed_at INTEGER NOT NULL
);

-- Index state tracking with idempotency key
CREATE TABLE contextum_index_states (
    id TEXT PRIMARY KEY,
    state_key TEXT NOT NULL UNIQUE,  -- dedup key
    artifact_id TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    chunker_version INTEGER NOT NULL,
    embedding_model_id TEXT,
    status TEXT NOT NULL,  -- planned|chunking|chunked|embedding|completed|failed
    chunking_needed INTEGER NOT NULL,
    embedding_needed INTEGER NOT NULL,
    plan_recorded_at INTEGER NOT NULL,
    last_updated INTEGER NOT NULL
);

-- Job queue
CREATE TABLE contextum_jobs (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,  -- context.chunk | context.embed
    status TEXT NOT NULL,  -- pending|running|completed|failed
    payload TEXT NOT NULL,  -- JSON
    correlation_id TEXT,
    created_at INTEGER NOT NULL,
    started_at INTEGER,
    completed_at INTEGER
);

-- Embedding provenance
ALTER TABLE contextum_embeddings ADD COLUMN evidence_head_hash TEXT;
CREATE INDEX idx_embeddings_composite ON contextum_embeddings(chunk_hash, model_id, model_hash);
```

---

## Components

### ArtifactCommitComponent
- Emitted by artifact store on commit/update
- Contains: artifactID, contentHash, sourceHash, mediaType, commitReceiptID, chunkerVersion, embeddingModelID

### IndexStateComponent
- Tracks indexing lifecycle per (contentHash, chunkerVersion, embeddingModelID)
- Status: planned → chunking → chunked → embedding → completed
- Idempotency via unique `stateKey`

### JobComponent
- Generic job representation for async work
- Kinds: `context.chunk`, `context.embed`
- Payload as [String: String] dictionary

---

## Systems

### AutoIndexSystem
- Scans ArtifactCommitComponents with `indexed=false`
- Creates IndexStateComponent if not exists (idempotent via stateKey)
- Emits `contextum.index.planned` telemetry

### ChunkOrchestrationSystem
- Finds IndexStates with status=planned and chunkingNeeded=true
- Enqueues `context.chunk` jobs
- Updates IndexState status to `chunking`

### EmbedOrchestrationSystem
- Finds IndexStates with status=chunked and embeddingNeeded=true
- Checks existing embeddings to avoid duplicates
- Enforces maxInFlightEmbeddings and maxBatchSize budgets
- Enqueues `context.embed` jobs with chunk hashes

---

## Execution

### MLWorkerEmbeddingExecutor (Actor)
- Accepts JobComponent (kind=context.embed)
- Extracts payload: embeddingModelID, chunkHashes, contentHash, indexStateID
- Loads ChunkComponents from registry
- Builds ModelSpec and RunSpec with inputHash
- Calls `mlWorkerClient.executeEmbedding()` (governed path)
- Stores EmbeddingComponents with full provenance
- Updates IndexState to `completed` when all chunks embedded
- Emits success/failure telemetry

---

## Adapters

### ArtifactIngestionAdapter
- Debounces artifact commits (default: 2 seconds)
- Flushes batches to avoid 8000 individual jobs on repo checkout
- Provides `getIndexStatus()` for UI queries

---

## Integration Tests

`Tests/ContextumModuleTests/Phase2IntegrationTests.swift`:

1. **testArtifactCommitTriggersAutoIndexing**: Commit → AutoIndexSystem → IndexState created
2. **testChunkOrchestrationEnqueuesJobs**: IndexState(planned) → ChunkOrchestrationSystem → Job(context.chunk)
3. **testEmbedOrchestrationRespectsBackpressure**: 15 states, maxInFlight=10 → ≤10 jobs created
4. **testIdempotentArtifactCommits**: Two commits with same contentHash → one IndexState

---

## Invariants Enforced

1. **No inline embedding**: All embeddings go through MLWorkerClient
2. **Receipt-backed embeddings**: Every embedding row references receiptID + evidenceHeadHash
3. **Idempotent indexing**: Same artifact state → same IndexState, no duplicates
4. **Backpressure**: Jobs queue when budget exceeded, orchestrator never starves
5. **Deterministic batching**: Batch size + chunk list hash recorded in job payload
6. **Fail-loud**: MLWorker unavailable → telemetry event + job failure, not silent degradation

---

## Telemetry Events

- `contextum.index.planned`: Auto-index created
- `contextum.chunking.enqueued`: Chunk job created
- `contextum.embedding.enqueued`: Embed job created with batchSize
- `contextum.embedding.completed`: Embeddings stored with receiptID, evidenceHeadHash, modelHash
- `contextum.embedding.failed`: Error + failureMode recorded

---

## What's Next: Phase 3

Phase 3 will add:
- **UI for model registry and index status**
- **Manual re-indexing with versioned chunkers**
- **Embedding model selection in orchestrator**
- **Drift detection and regression harness**
- **Index lag metrics and health dashboard**

---

## Acceptance Criteria: ✅ MET

- [x] Artifact commits trigger auto-indexing without manual intervention
- [x] MLWorker executes embeddings with full receipts and provenance
- [x] Idempotency: duplicate commits → single index state
- [x] Backpressure: embedding jobs respect budget limits
- [x] Failure mode: MLWorker unavailable → recorded, search degrades gracefully
- [x] Integration tests cover: indexing, orchestration, backpressure, idempotency

Phase 2 is **production-ready** for auto-indexing with governed embeddings.
