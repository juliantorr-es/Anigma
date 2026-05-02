# Backend Consolidation Checklist

This checklist is the final backend-hardening layer that ties together build recovery, database consolidation, personal context, long-run runtime state, observability, and operability.

`td` remains the source of truth for order and live status. This document defines the readiness gates.

Execution policy for satisfying these gates lives in [BACKEND_EXECUTION_HARDENING_FRAMEWORK.md](./BACKEND_EXECUTION_HARDENING_FRAMEWORK.md). The broader quality bar for what counts as enterprise-grade backend foundation lives in [ENTERPRISE_BACKEND_FOUNDATION_STANDARD.md](./ENTERPRISE_BACKEND_FOUNDATION_STANDARD.md). The gates below should be treated as incomplete until they have implementation, verification, operations, and review evidence.

## Readiness Gates

### Build Truth

- Main blocked binaries build cleanly.
- Rebuild tasks are complete for `harmonia`, `anigmad`, and `anigma-app`.
- Build docs and `td` agree on what is blocked.

### Contract Truth

- Critical module seams are verified for semantic compatibility.
- Request, event, and artifact payloads have canonical ownership.
- Simulated paths are either removed or made loudly non-production.

### State Truth

- Execution state has a canonical owner.
- Plans, jobs, retries, receipts, and resume state are not spread across incompatible stores.
- Compaction checkpoints and resume semantics are defined.

### Persistence Truth

- Database files and stores have clear ownership.
- Schema and migration owners are explicit.
- Canonical-vs-legacy persistence paths are documented.
- Contextum database behavior is real and not hidden behind a silent stub path.

### Runtime Truth

- Retry and idempotency behavior is explicit and enforced.
- Backpressure policy is explicit and unified.
- Long-run tasks can survive compaction, replan, and resume boundaries.

### Memory Truth

- Personal context has freshness and supersession rules.
- Profile memory is evidence-backed.
- Retrieval is freshness-aware and source-aware.
- Stale or conflicting memory can trigger abstention.
- Hot ECS state is thin and reference-based; large payloads are not resident by default.
- Memory budgets exist for hot ECS state, retrieval packages, active agent context, trace/event buffers, projection caches, model/session caches, document refinement working sets, and concurrent payload loads.
- Residency supports explicit load, pin, unpin, evict, spill, reload, and pressure-state behavior.
- Content-addressed payload references prevent duplicate documents, prompts, tool outputs, model outputs, diffs, and trace payloads from multiplying resident memory.
- Memory pressure, cache hit/miss, active pins, evictions, spills, and over-budget events are visible through backend observability.
- Representative benchmarks prove resident memory remains within declared budgets under document, retrieval, trace, projection, and long-run agent workloads.

### Verification Truth

- Verifier lanes exist for stale state, retrieval sufficiency, and resume safety.
- Integration tests prove useful backend work, not just startup or mocks.
- Long-run evaluation exists for continuity, compaction, and replan quality.
- Replayable coding-agent evals exist for build repair, review-finding resolution, architecture-claim grounding, regression rate, unnecessary churn, evidence coverage, and runtime/tool cost per useful change.
- Eval runs record task id, model/runtime/tool versions, input artifact hashes, retrieved context references, mutation receipts, build/test/review outcome, resource cost, and reviewer verdict.

### Authority Truth

- Every agent context artifact carries source kind, authority level, freshness, lineage, and conflict state.
- Generated summaries and agent memory are not ranked equal to TD state, current code, build evidence, direct user instruction, or canonical ADRs.
- Retrieval and prompt packaging preserve trust metadata through the full agent run.
- Conflicting source claims trigger abstention, review, or explicit tie-break rules rather than silent synthesis.

### Policy Truth

- High-risk agent actions pass through executable policy gates before execution.
- Policy decisions are durable evidence events with receipts.
- Initial policy rules cover no self-approval, canonical type ownership, source-of-truth precedence, payload access, build-status claims, foundation API changes, and high-risk file/network operations.
- Policy tests cover allowed, denied, and needs-human-review paths.

### Reversibility Truth

- Supported mutations record preconditions, touched files/entities/artifacts, forward action, inverse action or compensation path, actor, policy verdict, and validation command.
- Code edits, memory writes, TD/task-state transitions where supported, and generated docs have tested rollback or compensation paths.
- Non-reversible actions are labeled before execution and require stronger approval.

### Feedback Truth

- Rejected TD reviews, failed builds, policy denials, detector findings, and incidents produce structured feedback records.
- Feedback records link to task, trace, policy, build/test artifact, review finding, payload references, and root-cause labels.
- Repeated failure patterns can be promoted into candidate eval cases, policy rules, retrieval warnings, or documentation updates.

### Data Quality Truth

- Memory, eval corpora, summaries, embeddings, source chunks, and generated docs have lineage back to source artifact, transform, model/tool version, and derived record.
- Quality gates reject or flag duplicate records, stale embeddings, conflicting summaries, malformed payload references, incomplete handoffs, missing provenance, and low-fidelity extraction.
- Failed quality gates emit evidence and block promotion into trusted memory or trusted eval datasets.

### Operability Truth

- Correlation IDs, timings, and minimum metrics are available.
- Operators can inspect queue depth, retries, failures, and current run state.
- There is a supported path to answer "what happened?" for a given run.
- Agent/tool/model/context activity is reconstructable through the Agent Observability Spine, using trace metadata, immutable evidence events, governed payload artifact references, and ECS projections.
- Detection findings are linked back to trace, run, tool call, payload, receipt, and security event evidence.
- Agent runtime providers are isolated behind a backend-owned adapter boundary rather than leaking provider-specific events into every consumer.
- Live subscribers track sequence cursors and recover missed events through replay.
- Local NDJSON trace/evidence artifacts exist for completed spans and evidence records when OTLP/SIEM export is unavailable or disabled.
- Async backend tests use deterministic runtime receipts or drainable workers instead of sleep-based timing.
- Operators can inspect evidence coverage, policy decisions, risk, rollback availability, payload permissions, unresolved questions, and the recommended next task for an agent run.

### Scheduling Truth

- Agent workload scheduling accounts for task risk, evidence needs, model/tool cost, build/test cost, hardware pressure, memory budget, and duplicate work.
- Scheduler decisions record expected cost, actual cost, quality outcome, and resource-pressure impact.
- Parallel agent work respects impact-model write sets and defers or rejects overlapping high-risk changes.

## Exit Condition

The backend should be treated as meaningfully consolidated only when all readiness gates above are satisfied, not merely when the package graph compiles.
