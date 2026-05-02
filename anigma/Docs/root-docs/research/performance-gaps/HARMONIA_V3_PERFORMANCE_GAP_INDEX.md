> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Harmonia V3 Performance Gap Index

**Status:** Drafted from research  
**Purpose:** Turn architectural performance gaps into actionable design docs  

## Gap documents

1. `01-performance-envelope-and-slo-budget.md`
2. `02-global-batching-and-lane-scheduling.md`
3. `03-backpressure-and-load-shedding.md`
4. `04-partitioned-rebuild-and-work-ownership.md`
5. `05-unified-buffer-pool-and-data-locality.md`
6. `06-deterministic-accelerated-compute.md`
7. `07-benchmark-and-regression-gates.md`

## Source stack used

- **Industry standards:** Google SRE SLI/SLO and error budgets, OpenTelemetry sampling, Reactive Streams back pressure
- **Official docs:** Apple Core ML, Apple Metal Performance Shaders, PostgreSQL RLS/partitioning/query planner/resource config
- **Repo research:** `High_Performance_Inference.md`, `Hardware_Saturation_Gap_Analysis.md`, `Hardware_Saturation_Strategies.md`, `sli-slo-error-budget-best-practices.md`, `telemetry-and-trace-patterns.md`, `deployment-and-cutover-patterns.md`

## Design intent

These documents define the missing performance control plane for Harmonia V3:

- explicit performance budgets
- lane-based batching and routing
- bounded queues and load shedding
- partition-aware rebuilds
- unified memory/buffer management
- deterministic accelerated compute
- benchmark and regression gates

## Next step

Use these documents as inputs to the Design Phase epics for performance, observability, storage, and hardware saturation.