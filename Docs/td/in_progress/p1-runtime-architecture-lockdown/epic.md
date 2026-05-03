# p1-runtime-architecture-lockdown - Runtime Architecture Violation Lockdown

> **Status**: In Progress  
> **Type**: Epic  
> **Priority**: P1  
> **Lane**: architecture-governance  
> **Worktree**: `anigma/`

---

## Summary

Close the known architecture gaps where modules can bypass PlatformRuntime,
DatabaseAuthority, EvidenceAuthority, and governance gates. This replaces
fragmented runtime behavior with enforceable authority boundaries.

## Current Status

**READY**

## Epic Tasks

| ID | Title | Status |
|----|-------|--------|
| td-arch-001 | Enforce DatabaseAuthority mutation gates | in_progress |
| td-arch-002 | Unify fragmented evidence systems behind EvidenceAuthority | done |
| td-arch-003 | Add architecture tests for runtime authority bypasses | ready |
| td-arch-004 | Migrate one capability module through PlatformRuntime as proof | ready |
| td-arch-005 | Define backend readiness gates for lifecycle, contracts, retries, and operability | ready |


## Acceptance Criteria

## Acceptance Criteria

- Database mutations route through DatabaseAuthority
- Evidence recording routes through EvidenceAuthority
- Capability modules cannot directly bypass PlatformRuntime boundaries
- Architecture tests catch direct DatabaseCore/DatabaseActor/evidence bypasses


## Non-Goals

## Non-Goals

- Rewrite every capability module in one change
- Remove rollback paths before Phase 2-4 are proven


## Proof Links

## Proof

*No proof artifacts*


## Source Documentation

## Source Docs

- anigma/Docs/ADR/0006-three-tier-runtime-architecture.md
- anigma/Docs/architecture-guides/THREE_TIER_MIGRATION_ROADMAP.md
- anigma/Docs/status-reports/BACKEND_BLIND_SPOTS_AUDIT_2026-04-09.md
- anigma/Docs/status-reports/BACKEND_READINESS_AUDIT_2026-04-09.md


## Agent Handoff

> **For AI agents working on this epic**:
> 
> Check the `tasks/` subdirectory for individual task descriptors.
> Refer to `epic.yaml` for structured data and proofs for completion evidence.
> Preserve MaterializationGate patterns when extending.

---

*Epic ID: p1-runtime-architecture-lockdown*  
*Created: 2026-01-01*
