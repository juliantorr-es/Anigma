# Anigma Documentation Guides

Comprehensive guides for developing, deploying, and maintaining Anigma.

---

## Core Guides

### [Claude Integration](./claude-integration/)
Complete guide for integrating Anigma with Claude Desktop via the `anigma-mcp` Model Context Protocol server.

### [Contract Enforcement](./contract-enforcement.md)
Design principle contracts with automated enforcement, CI gates, and remediation campaigns.

### [Cathedral Module](./cathedral/)
Evidence-driven coordination with cryptographic governance and court-defensible audit trails.

### [Harmonia](./harmonia/)
AI coding assistant CLI and integration with the Anigma macOS app.

### [Agent Skill Pack](../LLM/AGENT-SKILL-PACK.md)
Shared operating skills for Copilot, Vibe/Mistral, Gemini CLI, Codex, and future agents so task intake, implementation, review, research, documentation sync, and handoff remain cohesive through TD.

---

## Technical Guides

### [Database](./database/)
Database governance, optimization, and migration guides.

### [Database Consolidation Plan](./DATABASE_CONSOLIDATION_PLAN.md)
Practical plan for moving the repo onto a canonical runtime-backed persistence contract and shrinking ad hoc database drift.

### [ML Worker](./ml-worker/)
Machine learning runtime, model registry, and inference architecture.

### [Capability System](./capability-system/)
Capability modules, provider implementation, and bootstrap examples.

---

## Operations

### [Accessibility](./accessibility/)
WCAG 2.1 AA compliance, audit reports, and remediation guidelines.

### [Backend Logging Migration Plan](./BACKEND_LOGGING_MIGRATION_PLAN.md)
Structured logging migration plan for daemon and shared backend modules, with explicit separation between operational logs and CLI/TUI stdout output.

### [Backend Observability Plan](./BACKEND_OBSERVABILITY_PLAN.md)
Plan for correlation IDs, spans, metrics, and debugging workflows needed to debug and optimize the integrated backend once logging is standardized.

### [Agent Observability Spine Stabilization](./AGENT_OBSERVABILITY_SPINE_STABILIZATION.md)
Stabilization track for investigation-grade agent traces, immutable evidence events, governed payload artifacts, provider-neutral runtime adapters, sequence-aware replay, local trace artifacts, ECS projections, deterministic runtime receipts, and detection systems.

### [Agent Engine Hardening Framework](./AGENT_ENGINE_HARDENING_FRAMEWORK.md)
Research-backed hardening track for making Anigma's agent engine measurable, source-grounded, policy-governed, reversible, feedback-driven, and operator-reviewable.

### [Backend Execution Hardening Framework](./BACKEND_EXECUTION_HARDENING_FRAMEWORK.md)
Execution policy for making backend epics complete only with implementation, verification, operations, and review evidence rather than design docs alone.

### [Backend Canonical Naming Policy](./BACKEND_CANONICAL_NAMING_POLICY.md)
Canonical backend role vocabulary and staged migration rules for replacing opaque historical names with stable facade names without destabilizing package builds.

### [Enterprise Backend Foundation Standard](./ENTERPRISE_BACKEND_FOUNDATION_STANDARD.md)
Research-backed definition of what "enterprise-grade backend foundation" should mean for Anigma without inflating the product into enterprise-scale complexity.

### [Static Plugin Architecture Stabilization](./STATIC_PLUGIN_ARCHITECTURE_STABILIZATION.md)
Second backend stabilization phase after compilation-surface reduction: keep core targets narrow while feature wiring targets statically register workers, routes, schemas, tools, and capabilities.

### [Typealias Consolidation Policy](./TYPEALIAS_CONSOLIDATION_POLICY.md)
Policy for using the typealias audit to remove semantic drift, bridge aliases, platform-alias inconsistency, and duplicate type-erasure contracts before broad backend wiring resumes.

### [Data-Oriented Backend Design Policy](./DATA_ORIENTED_BACKEND_DESIGN_POLICY.md)
Policy for using the existing AnigmaCore ECS as a measured data-oriented backend foundation for high-volume ingestion, indexing, retrieval, jobs, observability, native buffers, and replay.

### [Tiered Truth Storage ADR](../ADR/0014-tiered-truth-storage.md)
Storage and memory-residency contract for keeping hot ECS state thin while large documents, payloads, projections, and traces move through warm/cold references, budgets, load tickets, eviction, and bounded-memory benchmarks.

### [Small Business Assistant Product Model](./SMALL_BUSINESS_ASSISTANT_PRODUCT_MODEL.md)
Research-backed product model for using Anigma as a grounded business memory, obligation-tracking, and reviewable execution system for small business owners.

### [TurboQuant Local Inference Research](./TURBOQUANT_LOCAL_INFERENCE_RESEARCH.md)
Research note on TurboQuant-style KV-cache and vector-index compression, and how it should inform Anigma's local model selection and evaluation policy.

### [Personal Context Memory Model](./PERSONAL_CONTEXT_MEMORY_MODEL.md)
Research-backed model for treating personal context as an evolving memory system with source truth, episodic memory, profile memory, freshness, and abstention.

### [Long-Run Agent Runtime Model](./LONG_RUN_AGENT_RUNTIME_MODEL.md)
Runtime model for long-horizon agents that separates working context, persistent execution state, episodic memory, and profile memory.

### [Backend Consolidation Checklist](./BACKEND_CONSOLIDATION_CHECKLIST.md)
Final backend readiness checklist tying together build recovery, contracts, state, persistence, runtime behavior, memory, verification, and operability.

### [Installation](./installation/)
Mac app implementation, App Store refactoring, and troubleshooting.

### [Deployment](./deployment/)
Apple and corporate integration deployment guides.

---

## Quick Reference

| Topic | Location |
|-------|----------|
| Claude Desktop Setup | [guides/claude-integration/](./claude-integration/) |
| Contract Violations | [guides/contract-enforcement.md](./contract-enforcement.md) |
| Evidence System | [guides/cathedral/](./cathedral/) |
| Performance Budgets | [../PerformanceBudgets.md](../PerformanceBudgets.md) |
| Development | [../DEVELOPMENT_GUIDE.md](../DEVELOPMENT_GUIDE.md) |
| Roadmap | [../Roadmap.md](../Roadmap.md) |

---

*For sprint documentation, see [../sprints/](../sprints/)*  
*For architecture decisions, see [../ADR/](../ADR/)*  
*For governance policies, see [../governance/](../governance/)*
