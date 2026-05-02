# p0-004 - anigmad Subprocess Pooling

> **Status**: Ready  
> **Type**: Epic  
> **Priority**: P0  
> **Lane**: daemon-runtime-isolation  
> **Worktree**: `anigma/`

---

## Summary

Unify under anigmad with warm subprocess pooling for parallel execution.

## Current Status

**READY**

## Epic Tasks

| ID | Title | Status |
|----|-------|--------|
| td-a84da2 | Phase 1: Implement SubprocessManager foundation with pool lifecycle | ready |
| td-80575e | Phase 2: Direct integration of HarmoniaV2CLI and AnigmaCLIExecutable | ready |
| td-bfe7a3 | Phase 3: Implement MLWorker warm pool with UMA shared memory | ready |
| td-0dfb09 | Phase 4: Implement anigma-mcp warm pool with Unix domain sockets | ready |
| td-73aea8 | Phase 5: On-demand subprocesses for PDF, Gem, and benchmarks | ready |
| td-ce4439 | Phase 6: Decide AnigmaGeminiBridge fate - eliminate or keep | ready |


## Acceptance Criteria

## Acceptance Criteria

- anigmad subprocess pool lifecycle is implemented
- worker lease checkout/checkin is tested
- crashed workers are detected and recycled or retired
- shutdown reaps child processes deterministically
- governance validators pass


## Non-Goals

## Non-Goals

- Runtime implementation (already existed pre-P0-004)
- New CLIs beyond anigmad consolidation


## Proof Links

## Proof
- [p0-004-anigmad-subprocess-pooling.md](../../Docs/proofs/p0-004-anigmad-subprocess-pooling.md)


## Source Documentation

## Source Docs

- Docs/td/TD_PRIORITY_REORGANIZATION_20260430.md
- Docs/td/TD_PHASE6_UPDATE.md
- Docs/proofs/p0-004-anigmad-subprocess-pooling.md


## Agent Handoff

> **For AI agents working on this epic**:
> 
> Check the `tasks/` subdirectory for individual task descriptors.
> Refer to `epic.yaml` for structured data and proofs for completion evidence.
> Preserve MaterializationGate patterns when extending.

---

*Epic ID: p0-004*  
*Created: 2026-01-01*
