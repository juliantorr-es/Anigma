# Anigma — Local-first system for turning paperwork into guided action with auditable receipts.

## Core Foundations — The runtime guarantees that make every workflow predictable and explainable.

### AnigmaCore — The ECS + workflow kernel that defines how jobs run and why.

#### ECS Primitives — The smallest pieces that make state and behavior explicit.
- **EntityId** — Stable identity so work can be traced and audited.
- **Component** — Encapsulated state with clear ownership.
- **System** — Pure behavior that transforms state deterministically.
- **World** — The actor that keeps orchestration safe and isolated.

#### Jobs & Workflows — The contract for how work starts, runs, and finishes.
- **Job** — A bounded unit of work with lifecycle guarantees.
- **Workflow** — Ordered systems with declared dependencies.
- **Scheduler** — Orchestrates execution without hidden side effects.

#### Shared Components — Cross-cutting data kept consistent and observable.
- **FileComponent** — Provenance and access to source artifacts.
- **JobComponent** — Standard job metadata for receipts.
- **QAComponent** — Quality markers for governance checks.
- **MetadataComponent** — Key/value context for traceability.

#### Utilities — The guardrails around config, logging, and errors.
- **Logging** — Structured logs designed for evidence.
- **Configuration** — Typed settings with clear defaults.
- **Errors** — Explicit error models to avoid silent failure.

### AnigmaPrimitives — Shared types that keep boundaries consistent.
### PlatformCore — Platform abstractions that normalize system behavior.
### ExecutionCore — Execution services that keep workflows reliable.
### CapabilityCore — Capability modeling for explicit permissioning.
### ContractsCore — Surface contracts that prevent boundary drift.
### GovernanceCore — Policy enforcement as a first-class runtime surface.
### SecurityEventsManager — Security events that are visible and accountable.
### ProvenanceSigning — Hardware-backed signatures for evidence integrity.
### StorageCore — Storage boundaries with clear retention semantics.
### DatabaseCore — SQLite-backed persistence that stays local.
### TelemetryCore — Observability that does not leak data.
### PraxisCore — Governance validation and rules that stay enforceable.
### DoctrineCore — Policy modeling aligned to legal and institutional needs.
### InferenceCore — Local inference runtime with transparent constraints.
### MLWorkerCommon — Shared ML worker protocols for auditability.
### MLOutputCache — Deterministic caching to avoid rework and drift.

## Capability Modules — The user-facing work performed under governance.

### HarmoniaModule — Developer workflows with governed tooling.
### HarmoniaModuleExperimental — Experimental surfaces gated by policy.
### ObservatoriumModule — Observability pipelines and reporting.
### PolytroposModule — Multi-path reasoning with explicit options.
### PragmaModule — Practical operators that connect real-world tasks.
### CathedralModule — Structured pipeline orchestration.
### ConexusModule — Integration graph and connection workflows.
### CodexModule — Tool orchestration and LLM safety surfaces.
### DiaplasionModule — Document transformation into accessible formats.
### DiaplasionPipeline — Composed pipelines for multi-format output.
### OutlineumModule — Outlines, zines, and structured layouts.
### OutlineumZine — Zine-specific layout and publishing flows.
### AccessumModule — Client-facing shells and UX integration.
### AccessumFlow — Workflow composition for user-facing surfaces.
### PraxisModule — Governance praxis workflows and checks.
### TranscriptumModule — Transcript processing and export flows.
### VectorumModule — Semantic retrieval with local vector storage.
### TechDebtAudit — Tech-debt scanning and reporting.
### SmokeTestRenderer — Snapshot rendering for regressions.
### Demo — Demonstration pipelines and samples.

## Apps & UI Shells — The interfaces people touch every day.

### AnigmaApp — Primary application shell for end users.
### AnigmaAppMac — macOS-specific shell and integrations.
### AnigmaUI — Shared design system and UI components.
### AnigmaHostKit — Embedding APIs for host systems.
### AnigmaHostMac — macOS host integration layer.
### AnigmaClientKit — Client SDK surface for integrations.

## Daemons & Services — The controlled execution boundaries.

### AnigmaDaemon — Background job execution service.
### AnigmaDaemonCore — Daemon runtime and safety boundaries.
### AnigmaDaemonControl — Control plane for daemon operations.
### AnigmaDaemonVerifier — Verification and validation services.
### AnigmaSidecar — Open-source perimeter for integrations and policy.
### AnigmaWebServer — Web server integration surface.
### HarmoniaSurface — Surface testing and harness.

## CLI Tools — Governed command-line interfaces.

### HarmoniaCLI — Governed CLI for Harmonia workflows.
### DoctrineCLI — Doctrine and policy tooling.
### AnigmaASTServicesCLI — AST services CLI surface.

## ML & Workers — Local inference with auditable outputs.

### MLWorkerExecutable — Executable ML worker runtime.
### MLWorkerCommon — Shared ML worker protocol and types.
### MLOutputCache — Local output caching for ML workflows.
### InferenceCore — On-device inference runtime.
### VectorumModule — Vector store + semantic retrieval.

## Tooling & Interop — Build-time and integration utilities.

### AnigmaASTServices — AST services for code analysis.
### BuildIngest — Build ingestion and artifact parsing.
### AnigmaTestSupport — Test helpers and fixtures.
### Swift6Harness — Swift 6 testing harness.
### CFreeType — FreeType bindings for text rendering.
### CHarfBuzz — HarfBuzz bindings for shaping.
### CPDFium — PDFium bindings for document rendering.

## Governance — The constraints that keep everything trustworthy.

### Constitution — Fundamental rules and principles.
- **ADRs** — Decision records that explain why the architecture looks this way.

### Implementation Rules — Practical do/don't guidelines.
### LLM Guidelines — Rules for autonomous agents.
### Agent Contract — Governance contract for AI workflows.

## Docs — The authoritative knowledge base.

### Roadmap — Development phases and milestones.
### TechDebt — Tracked stubs and scaffolding.
### Architecture Overview — Structural diagrams and data flow.
### Schemas — Data format specifications (placeholder).
### Runbooks — Operational procedures (placeholder).

## Tools — Build-time generators and validators.

### Atlasum — Visual atlas generator that powers this map.
- Build-time only (Node/TS)
- Generates static HTML
- Markmap-based mind map
