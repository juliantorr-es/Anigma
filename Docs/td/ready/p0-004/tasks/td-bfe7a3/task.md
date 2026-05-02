# td-bfe7a3 - Phase 3: Implement MLWorker warm pool with UMA shared memory

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P0  
> **Lane**: daemon-runtime-isolation  
> **Epic**: [p0-004](../)  
> **Worktree**: `anigma/`

---

## Goal

See acceptance criteria

## Context

No description available.

## Scope

## Acceptance Criteria

- MLWorkerPool with round-robin workload balancing
- UMABufferPool for zero-copy tensor data transfer
- ModelCache for GPU model caching and reuse
- Multi-GPU support with per-GPU worker pools
- MLPoolMetrics for observability


## Non-Goals

## Non-Goals

- Actual CoreML/MLX model loading
- Production model inference


## Implementation Shape

## Source Files

- anigma/Packages/SubprocessPooling/Sources/MLWorker.swift
- anigma/Packages/SubprocessPooling/Tests/MLWorkerPoolIntegrationTests.swift
- Docs/proofs/p0-004-anigmad-subprocess-pooling.md


## Acceptance Criteria

## Criteria

- MLWorkerPool with round-robin workload balancing
- UMABufferPool for zero-copy tensor data transfer
- ModelCache for GPU model caching and reuse
- Multi-GPU support with per-GPU worker pools
- MLPoolMetrics for observability


## Validation Commands

## Validation Commands

*None*


## Proof Requirements

## Proof

*No proof artifacts*


---

*Task ID: td-bfe7a3*  
*Created: 2026-01-01*
