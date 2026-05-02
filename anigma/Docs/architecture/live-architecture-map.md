# Live Architecture Map

> **Status:** Live snapshot
> **Date:** 2026-04-20
> **TD:** `td-0393a8`

This document is a plain-language map of the current accepted/proposed Anigma stack. TD remains source of truth for live implementation status. ADRs remain source of truth for individual design decisions.

## Thesis

Anigma is a governed, local-first, hardware-saturating runtime with strict semantic boundaries between policy, execution, storage, and product-facing capabilities.

The architecture should make illegal coupling difficult:

- policy does not execute work
- execution does not invent policy
- storage does not become runtime layout by accident
- product UI does not mutate core truth directly
- hardware paths do bounded work with explicit budgets and receipts

## Four Storage And Runtime Lanes

### Relational Truth

Owned by PostgreSQL-backed persistence and database authority.

Owns:

- registry records
- metadata
- manifests
- receipts
- policy decisions
- queryable relationships
- job/queue coordination
- searchable relational state
- artifact indexes

Does not own:

- hot GPU execution buffers
- sealed binary atlas layout
- large immutable payload bytes by default
- per-frame UI/session state

### Sealed Artifacts

Owned by content-addressed artifact storage.

Owns:

- raw source files
- immutable binary outputs
- model weights
- exported bundles
- validation reference assets
- hash-addressed payload identity

Does not own:

- relational query semantics
- mutable policy decisions
- runtime residency
- UI projection state

### Memory-Mapped Execution Atlases

Owned by substrate-specific atlas packages such as PDF Page Atlas.

Owns:

- sealed mmap-friendly binary sections
- Structure-of-Arrays hot lanes
- offsets, lengths, spans, and section hashes
- tile plans and dependency spans
- typed zero-copy or low-copy readers
- execution layout for GPU/CPU replay

Does not own:

- general relational truth
- queue semantics
- policy evaluation
- mutable annotation/product edits unless represented as explicit overlay epochs
- long-lived GPU residency cache state

### Runtime Projections

Owned by runtime, UI, GPU, and session layers.

Owns:

- visible UI state
- active ECS working sets
- GPU residency caches
- tile cache state
- overlay epochs
- interaction buffers
- session-local derived views

Does not own:

- canonical document truth
- source payload identity
- durable policy decisions
- permanent evidence receipts

## Execution Boundary

High-throughput work should be represented as bounded missions:

- explicit input references
- capability bits
- purpose and privacy classification
- resource budgets
- output contract
- fallback behavior
- evidence receipt
- verifier path

"Saturated" means bounded, budgeted, receipted hardware work. It does not mean unbounded background work.

## Doctrine Chain

Current strongest chain:

1. [ADR-0001](../ADR/0001-single-ecs-in-anigmacore.md): one ECS foundation.
2. [ADR-0004](../ADR/0004-module-boundaries.md): module boundary discipline.
3. [ADR-0009](../ADR/0009-telemetrycore-unification.md): privacy-safe telemetry consolidation.
4. [ADR-0011](../ADR/0011-evidence-protocol-unification.md): evidence protocol consolidation.
5. [ADR-0013](../ADR/0013-ui-projection-system.md): UI as projection.
6. [ADR-0014](../ADR/0014-tiered-truth-storage.md): tiered truth with explicit budgets.
7. [ADR-0015](../ADR/0015-postgresql-unified-stack.md): Postgres as relational truth and coordination layer.
8. [ADR-0017](../ADR/0017-single-master-postgresql-system.md): single master PostgreSQL system of record.
9. [ADR-0018](../ADR/0018-postgresql-connection-and-transaction-contract.md): shared PostgreSQL connection and transaction contract.
10. [ADR-0019](../ADR/0019-postgresql-schema-bootstrap-and-migration-contract.md): shared PostgreSQL schema bootstrap and migration contract.
11. [ADR-0020](../ADR/0020-postgresql-embeddings-vector-strategy.md): canonical PostgreSQL embeddings and vector strategy.
12. [ADR-0021](../ADR/0021-postgresql-boundary-and-instantiation-rule.md): composition-root-only actor instantiation rule.
13. [ADR-0016](../ADR/0016-pdf-page-atlas.md): PDF Page Atlas as hot execution substrate.
14. [ADR-0012](../ADR/ADR-0012-SEGMENT-IR-MULTIMODAL.md): Segment IR as multimodal content substrate.
15. [ADR-0042](../ADR/ADR-0042-Model-Contract-System.md): tasks, not arbitrary model repositories.

### Deep Authorities
- **`SaturatedMemoryAuthority`** (Deep Module)
  - *Leverage:* The single source of truth for all hardware-saturated memory (CPU/GPU/ANE). Mandates `IOSurface` backing for all pixel buffers and UMA shared memory for tensors. Eliminates manual allocation in executors like `MetalTransformExecutor`.
  - *Locality:* Concentrates memory budget enforcement, zero-copy safety checks, and buffer registration in one place.
- **`ArtifactIntakeAuthority`** (Deep Module)
  - *Leverage:* The universal front door for all ingestion. Inspects magic bytes and routes to isolated adapters.
  - *Locality:* Eliminates fragmented ingestion pipelines (Diaplasion, Polytropos, BuildIngest).

### Deep Ingestion & Chunking Authorities
- **`ArtifactIntakeAuthority`** (Deep Module)
  - *Locality:* The single universal front door for all ingestion (PDFs, Video, Audio, Codebases). Inspects file magic bytes, enforces governance, and routes payloads to the correct isolated parsing adapter. Eliminates fragmented ingestion pipelines.
- **`SemanticChunkingAuthority`** (Deep Module)
  - *Locality:* Sits strictly between the ingest adapters and the ML vectorization layer. Takes raw extracted text from *any* adapter and uses the active local LLM's tokenizer to perfectly pack contexts up to the model's exact token limit, ensuring unified, high-precision RAG chunking.

### Adapters (Behind the SubprocessWorker Seam)
These modules exist strictly as adapters fulfilling the `SubprocessWorker` interface. They run in isolated, sandboxed processes but are governed entirely by `anigmad`.

- **`MLWorkerExecutable`** (Adapter)
  - *Locality:* Concentrates all hardware-saturated inference logic (Metal/CoreML/Accelerate) into a single warm-pooled process per GPU. Communicates with the daemon via zero-copy UMA shared memory.
- **`anigma-mcp`** (Adapter)
  - *Locality:* Isolates the Model Context Protocol HTTP/stdio parsing. Managed as a pooled worker by `anigmad` to prevent JSON parsing crashes from taking down the core daemon.
- **`PDFSidecarExecutable`** (Adapter)
  - *Locality:* An on-demand worker spawned by `anigmad` specifically to sandbox PDFium and other C++ text-extraction libraries that lack memory safety guarantees.
- **`ASTParserWorkerExecutable`** (Adapter)
  - *Locality:* An isolated, crash-resilient worker for codebase parsing (wrapping `tree-sitter` or SourceKitten). If a malformed syntax file causes a segmentation fault, the worker dies cleanly without taking down the `anigmad` daemon.

## Client Modules
- **`AnigmaApp`** (macOS Native Client)
  - The SwiftUI thin client. Communicates with `anigmad` via XPC/REST. No business logic; purely a projection layer.
- persistence rules
- failure behavior
- verification evidence

If a phrase cannot pass that test, rewrite it as mechanics or remove it.
