# td-db-002 - Define warm database lifecycle, retention, and partition policy

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

- Canonical stack is documented: PostgreSQL, Redis/ephemeral cache where justified, pgvector only where needed, DuckDB only for analytics
- Retention tiers define short-term, long-term, persistent, and regenerated embedding data
- Partition keys for runs, sessions, tenants, and evidence are documented
- Slow-query and growth guardrails have validator or proof commands


## Non-Goals

## Non-Goals

*None*


## Implementation Shape

## Source Files

- anigma/Docs/root-docs/research/ops-gaps/05-database-consolidation-and-memory-lifecycle.md
- anigma/Docs/architecture/database-housekeeping.md
- anigma/Docs/guides/database/DatabaseOptimizationGuide.md


## Acceptance Criteria

## Criteria

- Canonical stack is documented: PostgreSQL, Redis/ephemeral cache where justified, pgvector only where needed, DuckDB only for analytics
- Retention tiers define short-term, long-term, persistent, and regenerated embedding data
- Partition keys for runs, sessions, tenants, and evidence are documented
- Slow-query and growth guardrails have validator or proof commands


## Validation Commands

## Validation Commands

*None*


## Proof Requirements

## Proof

*No proof artifacts*


---

*Task ID: td-db-002*  
*Created: 2026-01-01*
