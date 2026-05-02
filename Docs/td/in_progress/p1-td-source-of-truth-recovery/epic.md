# p1-td-source-of-truth-recovery - P1 — TD Source-of-Truth Recovery and Docs Sync

> **Status**: In_Progress  
> **Type**: Epic  
> **Priority**: P1  
> **Lane**: documentation-infrastructure  
> **Worktree**: `anigma/`

---

## Summary

After TD database reset on 2026-05-02, establish Docs/ as the durable
source of truth and TD as the local execution queue. Create bootstrap
and validation scripts to make TD reconstructible from Docs/.

## Current Status

**IN_PROGRESS**

## Epic Tasks

*No child tasks*


## Acceptance Criteria

## Acceptance Criteria

- TD source-of-truth doctrine exists and is canonical
- TD task registry exists with active lanes defined
- Bootstrap script emits reproducible td commands from registry
- Sync validator passes on registry and TD state
- Proof artifact exists documenting the recovery
- Existing architecture validators still pass
- No runtime source changes


## Non-Goals

## Non-Goals

- Implement P0-004 runtime work
- Rewrite roadmap content broadly
- Recreate every historical task
- Depend on stale local TD database contents
- Make TD the canonical source of truth
- Mutate runtime source
- Weaken existing validators


## Proof Links

## Proof

*No proof artifacts*


## Source Documentation

## Source Docs

- Docs/governance/TD_SOURCE_OF_TRUTH_DOCTRINE.md
- Docs/td/td-task-registry.yaml


## Agent Handoff

> **For AI agents working on this epic**:
> 
> Check the `tasks/` subdirectory for individual task descriptors.
> Refer to `epic.yaml` for structured data and proofs for completion evidence.
> Preserve MaterializationGate patterns when extending.

---

*Epic ID: p1-td-source-of-truth-recovery*  
*Created: 2026-01-01*
