# td-db-001 - Repair DatabaseCore PostgreSQL API and integration-test baseline

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

- DatabaseCore/PostgresJobQueue API drift is repaired
- DatabaseActor PostgreSQL paths build against the current PostgresNIO API
- PostgreSQL integration tests either pass with documented environment or skip loudly
- AnigmaMCPModule and AnigmaDaemonCore are no longer blocked by DatabaseCore compile errors


## Non-Goals

## Non-Goals

*None*


## Implementation Shape

## Source Files

- Docs/proofs/p1-validate-tiers-green-gate.md
- anigma/Docs/PostgresFirstClassImplementation.md
- anigma/Docs/epics/td-89a996/Xcode_Build_Fixes_and_PostgreSQL_Test_Setup.md


## Acceptance Criteria

## Criteria

- DatabaseCore/PostgresJobQueue API drift is repaired
- DatabaseActor PostgreSQL paths build against the current PostgresNIO API
- PostgreSQL integration tests either pass with documented environment or skip loudly
- AnigmaMCPModule and AnigmaDaemonCore are no longer blocked by DatabaseCore compile errors


## Validation Commands

## Validation Commands

*None*


## Proof Requirements

## Proof

*No proof artifacts*


---

*Task ID: td-db-001*  
*Created: 2026-01-01*
