# p0-005 - Saturated Database and Heterogeneous Compute Foundation

> **Status**: Ready  
> **Type**: Epic  
> **Priority**: P0  
> **Lane**: daemon-runtime-isolation  
> **Worktree**: `anigma/`

---

## Summary

Establish the data foundation for Saturated Autonomous execution: PostgreSQL
remains the governed warm database, hot vector/tensor payloads move to
zero-copy Binary Atlas layouts, and CPU/GPU/ANE work is scheduled through
explicit saturation lanes with backpressure.

## Current Status

**READY**

## Epic Tasks

| ID | Title | Status |
|----|-------|--------|
| td-db-001 | Repair DatabaseCore PostgreSQL API and integration-test baseline | ready |
| td-db-002 | Define warm database lifecycle, retention, and partition policy | ready |
| td-db-003 | Port Contextum memory vectors to Binary Atlas references | ready |
| td-db-004 | Implement saturation lane scheduling and batch orchestration contract | ready |
| td-db-005 | Define partitionable projections and replay-safe rebuilds | ready |


## Acceptance Criteria

## Acceptance Criteria

- Warm database ownership and lifecycle policy are explicit
- Hot vector/tensor payloads have Binary Atlas (.atlas) source-of-truth layout
- Database rows reference atlas payloads by id/offset instead of storing hot blobs
- CPU/GPU/ANE lane scheduling contract exists with backpressure semantics
- Verification plan covers database lifecycle, atlas layout, and saturation behavior


## Non-Goals

## Non-Goals

- Replace PostgreSQL as system of record
- Implement model inference quality improvements
- Adopt a specialized store without measured query or throughput need


## Proof Links

## Proof

*No proof artifacts*


## Source Documentation

## Source Docs

- anigma/Docs/root-docs/research/ops-gaps/05-database-consolidation-and-memory-lifecycle.md
- anigma/Docs/root-docs/research/Hardware_Saturation_Strategies.md
- anigma/Docs/root-docs/research/Hardware_Accelerated_Compute.md
- anigma/Docs/root-docs/architecture/gpu-native-layouts.md
- anigma/Docs/status-reports/BACKEND_BLIND_SPOTS_AUDIT_2026-04-09.md


## Agent Handoff

> **For AI agents working on this epic**:
> 
> Check the `tasks/` subdirectory for individual task descriptors.
> Refer to `epic.yaml` for structured data and proofs for completion evidence.
> Preserve MaterializationGate patterns when extending.

---

*Epic ID: p0-005*  
*Created: 2026-01-01*
