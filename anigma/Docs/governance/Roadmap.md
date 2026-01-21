# Anigma Roadmap v4.1: Post-Convergence Reality

> Last updated: 2025-12-31  
> Previous: Merged Roadmap v4.0 (2025-12-29)  
> Status: **Active** – Sigma Phases 0-6 complete, convergence complete, Phase 7 in progress

Single source of truth for Anigma development. See `Docs/ADR/` for architecture decisions, `Docs/governance/Cathedral-Invariants.md` for operational invariants, and `Docs/TechDebt.md` for active debt tracking.

---

## Current State (2025-12-31)

**Repository**: 617 Swift files across 47 modules  
**Convergence**: Stages 0-5 complete, 2 modules eliminated, ~1,400 lines of legacy code deleted  
**Build Status**: All core modules building with Swift 6 strict concurrency

### Active Modules (13 capability modules)
- AccessumModule, CathedralModule, CodexModule, ConexusModule
- DiaplasionModule, HarmoniaModule (includes Spine/), ObservatoriumModule
- OutlineumModule, PolytroposModule, PragmaModule, PraxisModule
- TranscriptumModule, VectorumModule

### Recently Eliminated
- ~~HarmoniaSpine~~ (merged into HarmoniaModule/Spine/, commit `a3a5e102`)
- ~~AnigmaCore/Telemetry~~ (migrated to TelemetryCore, commit `c44c102a`)

---

## Completed Phases

### Phase 0: Repo Hygiene Guardrails ✅
**Canonical Principle**: Mechanical pattern enforcement  
**Completed**: 2025-12-29  
- CI enforcement for corpora/vendored code
- Forbidden pattern scanning
- Agent snapshot verification

### Phase 1: Outlineum Deterministic Zine ✅
**Canonical Principle**: Baseline normalization contract  
**Completed**: 2025-12-29  
- Deterministic runner → zine PDF + provenance
- Artifact template with input hash, pipeline version
- Replay verification via recorded metadata

### Phase 2: Diaplasion Happy-Path Spine ✅
**Canonical Principle**: Deterministic queries + retrieval evidence  
**Completed**: 2025-12-29  
- Ingest → OCR → normalize → export pipeline
- Searchable PDF, plain text, trace, replay metadata
- Vision OCR with configuration tracking

### Phase 3: Harmonia Deterministic Surface ✅
**Canonical Principle**: SignedAssertion for state transitions  
**Completed**: 2025-12-29  
- Minimal systems registered (slot, session, request)
- Typed row structs (Sendable-safe)
- Swift 6 concurrency enforcement

### Phase 4: Accessum Operator Shell ✅
**Canonical Principle**: ProofOfRecord for runs  
**Completed**: 2025-12-29  
- DSPS console scaffolded
- Document library workflow
- Accessibility preference management

### Phase 5: Production Hardening ✅
**Canonical Principle**: Time anchoring + ledger-first durability  
**Completed**: 2025-12-29  
- Structured logging/metrics
- Job persistence and recovery
- macOS daemon packaging scaffolding

### Phase 6: Database Governance & Retention ✅
**Canonical Principle**: Content-addressed storage, retention policy  
**Completed**: 2025-12-29  
- Content-addressed artifact store
- Retention policy framework
- GC command scaffolding
- WAL management, segmentation design

### Convergence Stages (Completed 2025-12-31) ✅
- **Stage 0**: Housekeeping (16 backup files deleted)
- **Stage 1**: Evidence Protocol Unification (`LoopEvidenceRecorder`)
- **Stage 2**: BoundaryTicketService Consolidation
- **Stage 3**: Telemetry Consolidation (→ `TelemetryCore.TelemetryClient`)
- **Stage 4**: HarmoniaSpine Merge (→ `HarmoniaModule/Spine/`)
- **Stage 5**: Experimental Module Policy (`module-graduation-policy.md`)

---

## Phase 7: Harmonia Tool Router & Session Management (IN PROGRESS)

**Canonical Principle**: Ledger-first actor flow, mechanical loop breaker  
**Status**: 🟡 Partially implemented  
**Target**: Q1 2026

### 7.1 Tool Contracts & Versioning ✅
- [x] `ToolContract` with input/output schema
- [x] `LoopBreakerConfig` with threshold/window/cooldown
- [x] JSON encode/decode with contract versioning

### 7.2 Loop Breaker for Tool Calls ⏳
- [x] `ToolCallLoopBreaker` tracking signatures
- [x] Block after N repeats in window
- [ ] Persist loop events to DB
- [ ] Tests for repeated blocks + DB rows

### 7.3 Tool Router Plumbing ⏳
- [ ] `ToolRouter` validates against `ToolContract`
- [ ] Record start/end/status/artifacts to SQLite
- [ ] `ToolCallResponse` JSON format
- [ ] HarmoniaCLI integration (`harmonia tool call`, `harmonia tool contracts`)

### 7.4 Specialized Tools (MVP) 📋
- [ ] `read_file` (content + hash + size + mtime)
- [ ] `apply_patch` (unified diff OR byte-range, precondition hash)
- [ ] `swift_build` (cache env, logs artifact)
- [ ] `swift_test` (filter, logs artifact)
- [ ] `git_diff` (diff artifact + summary)
- [ ] `trace_query` (migration/tool call rows)

### 7.5 Session DBs + Merge-to-Master 📋
- [ ] `ANIGMA_SESSION_ID` → session DB paths
- [ ] CLI: `session start`, `session merge`, `session end`
- [ ] Merge via `ATTACH DATABASE` (append-only tables)
- [ ] Idempotent inserts with stable IDs

### 7.6 Recovery UX ("Snap Out of Loop") 📋
- [ ] Enhanced `ToolCallResponse` with recovery strategy
- [ ] Recovery template generation
- [ ] `harmonia tool explain-block` helper

### 7.7 BuildIngest Integration 📋
- [ ] Refactor to consume `ToolRouter` operations
- [ ] Fix remaining Swift 6 issues
- [ ] Integration test with fixture

**Exit Criteria**:
- Agents mutate only through Harmonia tools
- No code path mutates repo state or DB state outside ToolRouter-mediated execution
- Edit loops blocked deterministically with recovery instructions
- Session DBs merge to master, then delete
- All outputs stable JSON

---

## Phase 8: Platform-Agnostic Ecosystem (PLANNED)

**Canonical Principle**: Keep adding adapters without rewiring truth
**Status**: 📋 Design Refinement (Mechanically Enforced)
**Target**: Q2-Q3 2026

**Architecture**: A "Tauri-v2 style" mechanical boundary where the core is the sole authority and renderers are untrusted presenters.

### 8.1 The Anigma UI Harness (Portable Truth Boundary)
- [ ] **Triangle Model**:
    - **SurfaceId**: Authorities mint unique IDs bound to window instances and capability sets.
    - **AnigmaClientKit**: The only API renderers see. Enforces intent schemas and reachability.
    - **Host Harness**: Per-platform glue providing **Host Capabilities** with forced scope enforcement.
- [ ] **Presentation IR**: A stable intermediate representation that allows the authority to compute **Deterministic Reachability** for ActionIntents.
- [ ] **Typed Scopes**: Mandatory capability scopes with **Deny-overrides-Allow** semantics enforced by the authority.
- [ ] **Governed Intents**: Forced `Evaluate → Submit → Receipt` pipeline for all mutating interactions.
- [ ] **Mechanical Isolation**: CI-enforced module boundaries (and dependency graph checks) preventing renderer cross-talk.

### 8.2 Inference Backends (Capability-with-Provenance)
- [ ] **Untrusted Backend Lens**: Treat ML engines (MLX, llama.cpp, etc.) as external capabilities with explicit manifests.
- [ ] **Read-Time Re-validation**: Cached artifacts are suspects; re-verified against current Policy/Toolchain/Backend digests at every read-time.
- [ ] **Provenance Attestation**: Automated logging of capability decisions and provenance metadata for every inference run.

---

## Active Tech Debt

See `Docs/TechDebt.md` for complete ledger. Summary:

- **DatabaseCore Swift 6 Compliance**: High priority, blocking
- **SecurityEventLogger Expansion**: Medium priority
- **Experimental Module Graduation**: Quarterly governance hygiene

**No longer debt**:
- ✅ Telemetry consolidation
- ✅ HarmoniaSpine namespace cleanup
- ✅ Evidence protocol unification

---

## Governance

### Verification Commands
```bash
# Convergence verification
rg "HarmoniaSpine\." Sources/              # → 0 results
rg "actor TelemetryService" Sources/       # → ObservatoriumModule only
rg "import HarmoniaSpine" Sources/         # → 0 results

# Tech debt audit
rg "STUB_TRACK|TODO:|FIXME:" Sources/      # Current markers
Scripts/check-experimental-policy.sh       # Experimental module enforcement
```

### Compliance Gates
- Swift 6 strict concurrency passes
- Type-authority boundaries enforced
- Receipt IDs = `BLAKE3(JCS(payload))`
- Baseline normalization for committed files
- No expired escape hatches

---

## Module Count by Category

**Core (Infrastructure)**:
- AnigmaCore, AnigmaPrimitives, ContractsCore, DatabaseCore
- DoctrineCore, ExecutionCore, SecurityCore, TelemetryCore

**Capability (User-Facing)**:
- 13 modules (see Active Modules above)

**Support**:
- HarmoniaMemory, ProvenanceSigning, BuildIngest

**Total**: 47 modules, 617 Swift files

**Governance**: Module count increases require justification in roadmap update.

---

**This document is the canonical roadmap for Anigma v4.1.** Updates require architectural-change process with version increment and changelog entry.
