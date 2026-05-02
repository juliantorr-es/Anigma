> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Architectural Gap: Partitioned Rebuild and Work Ownership

**Gap ID:** partitioned-rebuild-ownership  
**Severity:** High  
**Scope:** Event replay, projection rebuild, trace/audit reconstruction

## Gap statement

The research covers snapshots and event sourcing, but it does not yet define how large rebuild jobs are partitioned and owned. Projection rebuilds, trace reconstruction, and audit regeneration need parallel work ownership or they will become serial bottlenecks.

## Research evidence

### Industry standards
- Partitioning is a standard database and systems technique for scaling large datasets and maintenance operations.

### Official documentation
- **PostgreSQL partitioning docs:** partitioning can dramatically improve performance, reduce maintenance cost, and support dropping or detaching partitions quickly.
- **PostgreSQL planner docs:** async append, parallel append, partition pruning, and memoize are performance-oriented planner features.

### Repo research
- `03-event-sourcing-snapshot-storage-serialization.md` defines snapshot storage and rebuild behavior.
- `Hardware_Saturation_Strategies.md` explicitly identifies partitionable projections as a missing piece.

### Academic basis
- Event-sourced systems typically rely on replayable projections, snapshots, and bounded rebuild windows.
- Parallel processing research supports deterministic partition ownership when work can be isolated by key.

## Why it matters

If rebuild work is not partitioned:

- a single hot tenant can block everyone else
- replay can take longer than the release window
- audit and trace reconstruction become operationally expensive

## Recommended architectural response

Partition work by stable keys such as:

- `tenant_id`
- `run_id`
- `session_id`
- event stream prefix

Use a deterministic ownership model:

- each partition has a single active worker at a time
- workers can scale horizontally across partitions
- partition metadata is persisted so rebuilds resume safely

## Design constraints

- Partition keys must align with the natural isolation boundary.
- Rebuild order inside a partition must remain deterministic.
- Hot partitions must be able to split without reworking the entire model.

## Acceptance criteria

- Projection rebuilds can run in parallel by partition.
- Trace and audit rebuilds can be resumed from stored checkpoints.
- A single partition failure does not block the whole rebuild fleet.
- Partition ownership is visible in telemetry and recovery tooling.