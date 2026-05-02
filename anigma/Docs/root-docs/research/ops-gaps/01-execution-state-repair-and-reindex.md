> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Architectural Gap: Execution State Repair and Reindex

**Gap ID:** execution-state-repair  
**Severity:** High  
**Scope:** Projections, indexes, schema drift, orphan cleanup

## Gap statement

The research covers event sourcing and snapshots, but not the operational repair loop around them. Harmonia V3 still needs a formal plan for index corruption, partial rebuilds, schema drift, and orphaned state.

## Research evidence

### Industry / official
- PostgreSQL supports `REINDEX`, `ANALYZE`, `CREATE INDEX`, and query-planner tuning for recovery and optimization.
- Repo research already documents repair/reindex workflows, schema validation, and migration repair steps.

### Academic / systems basis
- Self-healing storage systems consistently rely on detect → isolate → repair → validate loops.
- Event-sourced systems need deterministic replay and resumable rebuilds to avoid full-cluster pauses.

## What industry does

Common production pattern:

1. Detect corruption or drift with periodic integrity checks.
2. Route the affected table/index into a repair queue.
3. Rebuild on a replica or in a maintenance window.
4. Validate row counts, plans, and query results.
5. Promote the repaired object only after checks pass.

## Recommended solution

Create a **Repair Authority** with three repair lanes:

| Lane | Scope | Action |
|---|---|---|
| Index lane | indexes, statistics | `REINDEX`, `ANALYZE`, plan validation |
| Schema lane | migrations, drift | version check, staged migration, rollback |
| Data lane | orphaned rows, derived state | cleanup + replay + checksum verification |

Add a repair manifest containing:

- object ID
- owner
- last good snapshot
- validation query
- rollback target

## Design constraints

- Repairs must be resumable.
- Repair jobs must be isolated from live user traffic.
- Reindex and replay must be visible in telemetry.

## Acceptance criteria

- Repair jobs are queued and tracked.
- Index/schema/data repairs use distinct playbooks.
- Validation is mandatory before promotion.
- Failures produce actionable incident metadata.