# Data-Oriented Backend Design Policy

Status: planning and execution policy. TD remains the source of truth for live task state, priority, dependencies, and approval.

Last reviewed: 2026-04-11

Baseline: local DOD audit of `AnigmaCore` ECS, app spine objects, and manager-heavy state ownership.

## Summary

Anigma already has a real data-oriented foundation:

- `AnigmaCore` owns the canonical ECS primitives: `World`, `Component`, `System`, and `AsyncSystem`.
- `World` separates entity identity, component data, and system logic.
- Component queries support multi-component joins, which is the right architectural shape for ingestion, indexing, memory, governance, and observability pipelines.
- App-side spine structs such as `AnigmaSource`, `IntakeItem`, `AnigmaJob`, and `AnigmaArtifact` are flat `Codable`, `Hashable`, `Sendable` value types.

The gap is not "adopt ECS". The gap is making data-oriented design a measured backend discipline instead of a loose pattern.

## Current Gaps

### 1. Dictionary AoS Storage

`ComponentStorage<C>` currently stores components as `[EntityId: C]`.

This is a pragmatic baseline:

- easy lookup
- simple mutation semantics
- actor-isolated through `World`
- good enough for low-volume orchestration state

It is not optimal for hot batch paths where systems scan thousands or millions of entities and only need one primitive field such as status, timestamp, embedding model, or retry count.

Policy:

- Keep dictionary storage for general ECS state until benchmarks prove it is a bottleneck.
- Do not introduce unsafe SoA storage globally.
- Add SoA or contiguous-buffer storage only for measured hot components with clear scan-heavy access patterns.

### 2. Manager Bottlenecks

The app and backend still contain large `Store` and `Manager` types that combine ownership, mutation, orchestration, and side effects.

Examples include:

- app-side `AppStore`
- app-side `JobManager`
- app-side `IntakeManager`
- backend managers for model, cache, session, retention, and resource coordination

Policy:

- UI stores may remain presentation state owners.
- Backend work-state should move toward components plus systems.
- Managers should become adapters, gateways, or composition roots, not the primary place where batch logic lives.

### 3. High-Volume Pipeline Fit

DOD should be applied first where Anigma actually has data volume:

- document ingestion
- OCR/layout extraction
- chunking and embedding requests
- vector-index maintenance
- citation/entity extraction
- replayable assistant evidence
- telemetry and observability rollups
- agent trace/event projection and detection findings

Do not spend DOD effort on low-volume control-plane objects until hot paths are stable.

### 4. Metal And Native Buffer Boundaries

Data-oriented layout can reduce CPU/GPU marshalling cost, but Swift-to-Metal zero-copy is not automatic.

Policy:

- Define explicit buffer contracts before adding Metal-facing SoA storage.
- Treat alignment, lifetime, storage mode, synchronization, and ownership as part of the contract.
- Do not pass arbitrary Swift object graphs into native kernels.
- Prefer contiguous primitive payloads for vector, layout, and signal-processing paths.

### 5. Determinism And Replay

DOD supports Anigma's truth-focused architecture because component state can be snapshotted and replayed independently from system logic.

Policy:

- Systems that mutate durable backend state should be replayable from component snapshots plus event receipts.
- High-volume systems should declare read/write component sets.
- Replay evidence should include system name, input component versions, output component versions, and receipt IDs.

### 6. Server-Authoritative Event Projection

For agent runtimes, ECS should be a high-throughput projection layer over immutable backend-owned events rather than the only truth store.

Policy:

- AgentEvidenceEvent is the durable source of truth.
- ECS components are rebuildable projections for query, rollup, detection, and UI/operator surfaces.
- Projection systems must track last applied sequence and support replay from a snapshot plus event tail.
- Provider-specific runtime events must be normalized by an adapter before they reach ECS projection systems.
- High-cardinality identifiers and payload references belong in event/span attributes, not metric labels.

### 7. Memory Residency And Working Sets

DOD does not mean keeping every refined signal resident. Data-oriented systems only stay fast when the active working set is deliberate and bounded.

Policy:

- Hot ECS state should be thin: IDs, references, hashes, offsets, status, counters, timestamps, scores, and compact summaries.
- Large documents, prompt/context/tool payloads, OCR pages, model outputs, diffs, and trace payloads should live behind artifact or payload references.
- Systems that need heavy payloads should acquire load tickets and release pins when finished.
- Residency must support load, pin, unpin, evict, spill, and reload semantics.
- Memory pressure should be observable and should trigger explicit behavior rather than silent growth.
- Specialized SoA/vector storage is allowed only for measured hot data-plane paths with a declared memory budget.

### 8. Agent Impact, Policy, And Feedback Data

The agent engine hardening track should use data-oriented records instead of free-form summaries wherever the records drive policy, scheduling, eval, or review.

Policy:

- Agent action proposals should declare read/write file sets, read/write component sets, required capabilities, affected targets, and rollback status before execution.
- Policy decisions, eval runs, review outcomes, detector findings, and rollback receipts should be structured records that can be projected, queried, and replayed.
- Feedback loops should promote repeated failures into candidate policy/eval records rather than unstructured memory alone.
- Scheduler systems should consume structured risk, impact, budget, and quality outcome records when deciding how much agent work to run in parallel.

## Design Rules

1. `AnigmaCore` remains the only ECS implementation.
2. Components are pure data. Business logic belongs in systems, services, or explicit adapters.
3. Use manager classes only for UI presentation state, external service adapters, lifecycle orchestration, or composition roots.
4. Prefer small components for hot scanned state: status, timestamps, counters, queue priority, embedding metadata, and retry/idempotency keys.
5. Keep rich aggregate structs at API, UI, or persistence boundaries where readability matters.
6. Use SoA or contiguous buffers only after measuring a specific hot path.
7. Do not expose unsafe buffer storage through general `World` APIs.
8. Every optimized storage path needs a correctness test, a benchmark, and a fallback path.
9. Systems that can run in parallel must declare read/write component sets.
10. Durable systems must support deterministic replay or explain why replay is not applicable.
11. Large payloads must not become hot ECS component fields unless a benchmarked exception and eviction policy exist.
12. Every high-volume path needs a declared memory budget before it is treated as production-ready.
13. Systems that load heavy payloads must expose residency behavior: what they load, how much they pin, and when they release.
14. Agent action proposals, policy decisions, eval results, feedback records, and rollback receipts should be modeled as structured data before they are rendered as prose.
15. Parallel agent systems must use declared write sets and impact records before running mutating work concurrently.

## Where DOD Should Apply First

| Area | Current shape | DOD target |
| --- | --- | --- |
| Document ingestion | mixed managers, systems, and database actors | intake/source/chunk/status components processed by ingestion systems |
| OCR and layout | capability systems plus sidecar/native paths | flat layout blocks, OCR spans, confidence, and provenance components |
| Embeddings | database/vector manager paths | embedding request/result/status components with batch-oriented systems |
| Retrieval evidence | manager/service-oriented paths | query, candidate, score, provenance, and answer-support components |
| Agent observability | partial logs, receipts, and per-module telemetry | immutable agent evidence events plus trace, tool, payload, and detection projection systems |
| Telemetry rollups | manager/log aggregation | append-only event components plus rollup systems |
| Job execution | job queues and managers | job state, lease, retry, idempotency, and receipt components |
| Memory residency | implicit caches and full payload structs | budgeted load tickets, payload references, pin/unpin/evict systems, and pressure telemetry |
| Agent hardening | prose rules, ad hoc review memory, manual risk judgment | structured action proposals, policy verdicts, eval records, impact records, rollback receipts, and feedback projections |

## Where DOD Should Not Be Forced

- UI-only presentation state that SwiftUI needs to observe directly.
- Low-volume configuration objects.
- External service clients.
- Composition roots and plugin/feature registries.
- Security-sensitive wrappers where nominal type clarity matters more than layout density.

## Migration Plan

### Phase 1: Classify Hot Paths

- Inventory systems/managers that scan or mutate high-volume data.
- Record entity counts, component counts, payload size, mutation rate, and latency budget.
- Mark each area as control-plane, batch-plane, or hot data-plane.

### Phase 2: Move Batch Logic Out Of Managers

- Pick one high-volume backend path.
- Define components for state and receipts.
- Move processing logic into an `AsyncSystem`.
- Keep the old manager as an adapter or composition root until callers are migrated.

### Phase 3: Benchmark Current ECS Storage

- Measure dictionary-based component storage for the selected path.
- Include query time, mutation time, memory use, and actor contention.
- Do not optimize storage until this measurement exists.

### Phase 4: Prototype Specialized SoA Storage

- Add a specialized storage path for one hot component family only.
- Keep the public `World` contract stable.
- Compare against dictionary storage with the same workload.

### Phase 5: Define Native Buffer Contracts

- For Metal/native paths, define buffer schemas for vector, layout, and OCR payloads.
- Add conversion and ownership tests.
- Measure marshalling cost before and after.

### Phase 6: Add Replay Evidence

- Add snapshot and replay fixtures for the selected system.
- Verify deterministic outputs from the same component state and receipts.
- Wire failures into observability surfaces.

### Phase 7: Add Sequence-Aware Subscriber Recovery

- Give high-volume event streams monotonic sequence cursors.
- Store projection `last_applied_sequence`.
- Add gap handling semantics for live subscribers: apply, defer, or recover.
- Test replay after dropped live events.

### Phase 8: Add Memory Residency Gates

- Define hot/warm/cold data residency rules for the selected path.
- Add budget classes for resident bytes, loaded payload bytes, active pins, and spill behavior.
- Add tests that reject accidental raw large payload residency in hot ECS components.
- Benchmark peak resident memory and growth curve under a representative workload.

## Relationship To Current Backend Stabilization

DOD is not the next blocker ahead of compilation-surface reduction.

Current ordering:

1. Finish compilation-surface stabilization and contract cleanup.
2. Complete static plugin architecture boundaries.
3. Unblock backend builds and remove critical stubs.
4. Land the Agent Observability Spine track (`td-16ca40`) as the canonical high-volume observability/replay path.
5. Land Tiered Truth Storage memory residency gates (`td-40d410`) so hot ECS state, payload loading, and projection caches are bounded.
6. Land Agent Engine Hardening (`td-e5142b`) so evals, policy, trust labels, feedback, impact modeling, reversibility, scheduling, and operator review consume structured evidence rather than free-form logs.
7. Apply measured DOD to remaining high-volume backend paths.

DOD should not be used as justification for broad unsafe refactors while the build is still unstable.

It should be used as a production-readiness track for ingestion, retrieval, observability, jobs, and replay once backend contracts and build boundaries are stable enough to measure.
