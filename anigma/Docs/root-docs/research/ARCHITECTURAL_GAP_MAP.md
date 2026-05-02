> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Harmonia V3 Architectural Gap Map

**Status:** Consolidated from research  
**Purpose:** Show what is still missing, what depends on what, and what to do first

## What this map means

The research now covers the main architecture, performance control plane, and the remaining reliability/operations/lifecycle gaps. This map is the prioritized view of what still needs design work before implementation.

## Priority legend

- **P0**: blocks safe production design
- **P1**: needed for stable design and scale
- **P2**: important, but can follow after the foundation

## Top-level priority map

| Pri | Gap | Category | Why it matters | Depends on |
|---|---|---|---|---|
| P0 | Backup, restore, PITR under load | Reliability | recovery is only real if it is tested under live pressure | none |
| P0 | Performance envelope + SLO budget | Performance | without budgets, no design can be judged “fast enough” | none |
| P0 | Identity and authority propagation | Operations/Security | every action needs a verifiable principal trail | none |
| P0 | Deterministic audit security | Security | receipts/audits must be reproducible and explainable | identity propagation |
| P1 | Global batching + lane scheduling | Performance | keeps CPU/GPU/ANE saturated instead of merely busy | performance budgets |
| P1 | Backpressure + load shedding | Performance/Reliability | prevents queue blowups and cascade failures | performance budgets |
| P1 | Config and deployment cutover edge cases | Operations | avoids rollout failures and rollback asymmetry | identity + backups |
| P1 | Execution-state repair and reindex | Reliability/Operations | corruption and drift need a repair loop | backups + identity |
| P1 | Database consolidation + memory lifecycle | Lifecycle | controls growth, compaction, and backend choice | performance budgets |
| P2 | Partitioned rebuild + work ownership | Coordination | makes replay and rebuild scale horizontally | backpressure + identity |
| P2 | Multi-agent + sidecar transport | Coordination | prevents coordination from becoming the bottleneck | identity + transport |
| P2 | Unified buffer pool + locality | Performance/Lifecycle | reduces copy tax and memory churn | lane scheduling |
| P2 | Benchmark + regression gates | Operations | ensures performance does not regress silently | performance budgets |

## Dependency chain

1. **Backup / PITR** and **identity propagation** are the trust base.
2. **Performance budgets** define what “good” means.
3. **Deterministic audit** makes receipts and policy decisions defensible.
4. **Cutover safety** and **repair/reindex** make change management survivable.
5. **Lane scheduling**, **backpressure**, and **buffer pools** unlock throughput.
6. **Partitioned rebuilds** and **multi-agent transport** scale the system out.
7. **Benchmark gates** keep the architecture from drifting over time.

## Overlooked sub-gaps this map captures

- Restore drills and DR testing
- Backup pressure policies during live load
- Principal-aware async propagation
- Runtime transport selection
- Blackboard consistency for agent coordination
- Memory compaction and embedding refresh policy
- Schema drift lifecycle and migration symmetry
- Partition retention and hot-partition split policy
- Deterministic accelerated compute receipts
- Rollout validation and rollback symmetry

## Recommended work order

1. Backup, restore, and PITR under load
2. Identity and authority propagation
3. Performance envelope and SLO budget
4. Configuration and deployment cutover edge cases
5. Deterministic audit security
6. Execution-state repair and reindex
7. Global batching and lane scheduling
8. Backpressure and load shedding
9. Database consolidation and memory lifecycle
10. Partitioned rebuild and work ownership
11. Multi-agent and sidecar transport
12. Unified buffer pool and locality
13. Benchmark and regression gates

## Existing doc sets

- `performance-gaps/` — the seven performance-control-plane docs
- `ops-gaps/` — the seven reliability/operations/lifecycle docs

## Bottom line

The obvious gaps are already documented. The overlooked gaps are mostly the ones that turn “works in theory” into “survives real load, real rollouts, and real recovery.”