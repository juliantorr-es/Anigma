# td-arch-003 - Add architecture tests for runtime authority bypasses

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P1  
> **Lane**: architecture-governance  
> **Epic**: [p1-runtime-architecture-lockdown](../)  
> **Worktree**: `anigma/`

---

## Goal

See acceptance criteria

## Context

No description available.

## Scope

## Acceptance Criteria

- Validator detects direct DatabaseActor usage outside approved authority layers
- Validator detects capability modules importing DatabaseCore directly where forbidden
- Validator detects direct evidence writes outside EvidenceAuthority
- CI/profile command documents expected pass result


## Non-Goals

## Non-Goals

*None*


## Implementation Shape

## Source Files

- anigma/Docs/ADR/0006-three-tier-runtime-architecture.md
- Docs/schemas/tier-boundary-violations.schema.md
- Docs/proofs/p1-validate-tiers-green-gate.md


## Acceptance Criteria

## Criteria

- Validator detects direct DatabaseActor usage outside approved authority layers
- Validator detects capability modules importing DatabaseCore directly where forbidden
- Validator detects direct evidence writes outside EvidenceAuthority
- CI/profile command documents expected pass result


## Validation Commands

## Validation Commands

*None*


## Proof Requirements

## Proof

*No proof artifacts*


---

*Task ID: td-arch-003*  
*Created: 2026-01-01*
