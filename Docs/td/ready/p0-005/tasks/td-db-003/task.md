# td-db-003 - Port Contextum memory vectors to Binary Atlas references

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P0  
> **Lane**: daemon-runtime-isolation  
> **Epic**: [p0-005](../)  
> **Worktree**: `anigma/`

---

## Goal

See acceptance criteria

## Context

No description available.

## Scope

## Acceptance Criteria

- Contextum memory vector payloads use .atlas files for hot data
- Warm database rows store atlas id, offset, dimension, type, and governance metadata
- No JSON/BLOB hot-vector path remains on the critical retrieval path
- Atlas writer/reader fixtures prove alignment and zero-copy mapping assumptions


## Non-Goals

## Non-Goals

*None*


## Implementation Shape

## Source Files

- anigma/Docs/root-docs/architecture/gpu-native-layouts.md
- anigma/Docs/root-docs/research/memory-backend-options.md
- anigma/Docs/status-reports/BACKEND_BLIND_SPOTS_AUDIT_2026-04-09.md


## Acceptance Criteria

## Criteria

- Contextum memory vector payloads use .atlas files for hot data
- Warm database rows store atlas id, offset, dimension, type, and governance metadata
- No JSON/BLOB hot-vector path remains on the critical retrieval path
- Atlas writer/reader fixtures prove alignment and zero-copy mapping assumptions


## Validation Commands

## Validation Commands

*None*


## Proof Requirements

## Proof

*No proof artifacts*


---

*Task ID: td-db-003*  
*Created: 2026-01-01*
