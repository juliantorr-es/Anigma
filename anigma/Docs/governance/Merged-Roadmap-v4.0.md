# Merged Roadmap v4.0: Canonical + Sigma

> Last updated: 2025-12-29
> Previous versions: Canonical v3.2 + Sigma Release Roadmap
> Status: **Active** – Sigma Phases 0-6 complete; Phase 7 in progress

Single source of truth for Anigma development, combining canonical architectural guarantees with concrete Sigma release implementation phases. For detailed architecture decisions, see `Docs/ADR/`. For operational invariants, see `Docs/governance/Cathedral‑Invariants.md`.

---

## Executive Summary: Canonical Guarantees + Sigma Implementation

This roadmap unifies two threads:

1. **Canonical v3.2** – Architectural principles that survive adversarial scrutiny: SignedAssertion/ProofOfRecord, ledger-first durability, query pinning, baseline normalization, time anchoring as evidence, and mechanical pattern enforcement.

2. **Sigma Release Roadmap** – Concrete implementation roadmap with 6 phases completed and 2 phases planned, each with acceptance criteria and measurable completion.

| Phase | Name | Canonical Principle | Status |
|-------|------|-------------------|--------|
| 0 | Repo hygiene guardrails | Mechanical pattern enforcement | ✅ COMPLETED |
| 1 | Outlineum deterministic zine | Baseline normalization contract | ✅ COMPLETED |
| 2 | Diaplasion happy-path spine | Deterministic queries + evidence | ✅ COMPLETED |
| 3 | Harmonia deterministic surface | SignedAssertion for state transitions | ✅ COMPLETED |
| 4 | Accessum operator shell | ProofOfRecord for runs | ✅ COMPLETED |
| 5 | Production hardening | Time anchoring + ledger-first durability | ✅ COMPLETED (2025-12-29) |
| 6 | Database governance & retention | Content-addressed storage, retention policy, GC, WAL management, segmentation, semantic search, governance invariants | ✅ COMPLETED |
| 7 | Harmonia Tool Router & Session Management | Ledger-first actor flow, mechanical loop breaker, session DBs | 🟡 IN PROGRESS |
| 8 | Platform-Agnostic Ecosystem | Renderer and inference backend adapters | 📋 PLANNED |

---

## Phase 0: Repo Hygiene Guardrails

**Canonical Principle:** Mechanical pattern enforcement replaces poetic policy.

**Status:** ✅ COMPLETED

**What was done:**
- Gitignore and CI enforcement for corpora (Inspiration/INBOX) and vendored node_modules
- Scanning for forbidden patterns in builds
- Agent snapshot verification

**Definition of Done:**
- CI fails if stray corpora or node_modules leak into tracked paths
- Deterministic snapshots for all agent-facing codebases

---

## Phase 1: Outlineum Deterministic Zine Pipeline

**Canonical Principle:** Baseline normalization contract – every file type has explicit canonical representation.

**Status:** ✅ COMPLETED

**What was done:**
- Deterministic Outlineum runner producing zine PDF + provenance
- Artifact template: `Artifacts/outlineum/zine/{pipelineVersion}/{inputHash}/`
- Provenance includes pipeline version, input hash, git commit, normalized metadata

**Definition of Done:**
- One command runs the runner and produces stable PDF + provenance JSON
- Replay can verify identical hashes from the recorded metadata

---

## Phase 2: Diaplasion Happy-Path Spine

**Canonical Principle:** Deterministic queries pinned to snapshots; retrieval evidence recorded.

**Status:** ✅ COMPLETED

**What was done:**
- Ingest → OCR → normalize → export pipeline
- Searchable PDF, plain text, trace, and replay metadata
- Trace captures input hash, pipeline version, OCR configuration, normalized text hash

**Definition of Done:**
- Replay command reuses recorded metadata to regenerate artifacts and compare hashes
- Vision OCR → normalized text → searchable PDF records OCR knobs and all hashes

---

## Phase 3: Harmonia Deterministic Surface

**Canonical Principle:** SignedAssertion for every state transition; no [[String: Any]] across actor boundaries.

**Status:** ✅ COMPLETED

**What was done:**
- Minimal Harmonia systems registered (slot, session, request)
- Database queries return typed row structs (Sendable-safe)
- Smoke harness asserts deterministic state

**Definition of Done:**
- Slot/session/request systems register and tick deterministically
- Swift 6 concurrency rejects actor boundary violations at compile time
- Deterministic state capture in report.json

---

## Phase 4: Accessum Operator Shell

**Canonical Principle:** ProofOfRecord for runs; cross-module workflows with evidence pointers.

**Status:** ✅ COMPLETED

**What was done:**
- AccessumFlow orchestrates Diaplasion → Outlineum pipelines
- One trace per run with per-step hashes
- Shared CLI envelope for all outputs
- Support for `accessum flow --replay` on same runId

**Definition of Done:**
- Cross-module demo: Diaplasion output feeds Outlineum with handoff recorded
- Trace records both sides of the handoff with deterministic hashes
- Replay proves identical pipeline produces identical outcome

---

## Phase 5: Production Hardening

**Canonical Principles:** Time anchoring as evidence; ledger-first durability; normalization contracts.

**Status:** ✅ COMPLETED (2025-12-29)

**Completion Criteria Met:**
- ✅ Accessum daemon with launchd integration
- ✅ Persistent run ledger with admin command
- ✅ Replay and verdict recording in accessum.db
- ✅ Log rotation and lifecycle management
- ✅ Governed patch helper scripts
- ✅ Production-hardening acceptance criteria met

**What was done:**
- AccessumFlow writes every run/step/artifact record into accessum.db
- Observability, retention, and replay decisions live in one ledger
- Retention-cleanup is part of the daemon (manual or scheduled)
- Daemon packaging guidance covers Application Support paths, launchd plist, log rotation
- Machine-readable stdout/stderr throughout

**Definition of Done:**
- Runs/steps/artifacts live in `Artifacts/accessum/accessum.db` plus trace exports
- Replay and retention decisions write back to the ledger
- Admin command returns the same envelope as the CLI
- Admin reports stuck runs and retention stats, honors `--retention-days` policies

---

## Phase 6: Production Database Governance & Retention

**Canonical Principles:** Receipt-identity derivation (BLAKE3(JCS(payload))); query pinning with semantic fingerprints; ledger-first flow for all mutations.

**Status:** ✅ COMPLETED

**What was implemented:**

### 6A: DatabaseCore Data Model Enhancement
- ✅ Content-addressed artifact store with strong hash keys and deduplication
- ✅ Master ledger thinning with hash references instead of embedded payloads
- ✅ Session DB boundaries enforced architecturally
- ✅ Deduplication enforcement (one artifact row with multiple references)

### 6B: Retention Policy Contract
- ✅ Machine-readable policy file loaded alongside existing policy packs
- ✅ Policy classes: Session DB TTL, verbose payload TTL, artifact TTL by type
- ✅ Deletion definitions: Hard delete for bytes, tombstone for references
- ✅ Policy integration with unified governance

### 6C: Garbage Collection Command
- ✅ Deterministic GC entry point in Harmonia CLI
- ✅ GC flow: Load policy → enumerate deletions → delete → record retention events
- ✅ Eligibility proof: Safe to delete = unreferenced OR referenced only by expirable events
- ✅ Dry-run mode with deterministic reporting (counts, bytes, policy rule triggers)

### 6D: SQLite Housekeeping
- ✅ WAL mode management with regular checkpointing
- ✅ Scheduled VACUUM for payload DBs and rotated segments
- ✅ ANALYZE optimization after major churn
- ✅ Performance monitoring (file sizes, WAL sizes, query performance)

### 6E: Master Ledger Segmentation
- ✅ Time-based hourly segmentation strategy
- ✅ Ledger rotation triggered by event count or age thresholds
- ✅ Archival process for old segments
- ✅ Cross-segment querying with transparent query interface
- ✅ Master index DB with stable canonical event index

### 6F: Semantic Search Integration
- ✅ SemanticSearchManager with vector embedding storage
- ✅ Audit trail recording for all search queries
- ✅ LedgerEventIndexer for automatic indexing of new events
- ✅ Integration with MasterLedgerStore (automatic indexing on event record)

### 6G: Evidence for Housekeeping
- ✅ Retention event type in ledger recording policy version, deletions performed, bytes freed
- ✅ Refusal logging (when GC refuses deletion due to retained references)
- ✅ Cleanup auditing with ledger-recorded violations
- ✅ Storage reporting by category

### Comprehensive Testing & Governance Invariants
- ✅ Tests for retention policies, GC, housekeeping, segmentation compliance
- ✅ WAL checkpointing tests
- ✅ Search audit trail verification
- ✅ GovernanceInvariantChecker enforcing:
  - Content integrity (no orphaned or missing artifacts)
  - Retention policy compliance
  - Segmentation consistency
  - Complete search audit trail
  - Maintenance operation tracking

**Technical Artifacts:**
- `Sources/DatabaseCore/DatabaseHousekeeping.swift` – WALManager, DatabaseMaintenance
- `Sources/DatabaseCore/DatabaseMaintenanceScheduler.swift` – Maintenance scheduling
- `Sources/DatabaseCore/DatabaseActor+Maintenance.swift` – Schema and helpers
- `Sources/HarmoniaCLI/MaintainCommand.swift` – CLI for maintenance
- `Sources/HarmoniaCLI/GCCommand.swift` – Updated with housekeeping
- `Tests/DatabaseCoreTests/` – Comprehensive test suite
- `Docs/database-governance/DatabaseArchitecture.md` – Full documentation

**Definition of Done:**
- ✅ WAL checkpointing triggers automatically based on size threshold
- ✅ VACUUM and ANALYZE can be scheduled and triggered manually with audit logging
- ✅ Outputs visible in CLI commands (gc, maintain) with JSON/text reporting
- ✅ Database schema supports `maintenance_history` for operation audit
- ✅ CLI commands fully integrated and executable
- ✅ Integration testing confirmed no regression on garbage collection

---

## Phase 7: Harmonia Tool Router & Session Management

**Canonical Principles:** Ledger-first actor flow (record intent → mutate → record outcome); mechanical loop breaker; session DBs with merge-to-master.

**Status:** 🟡 IN PROGRESS

**Acceptance Criteria:**
- [ ] Tool contracts with versioning primitives in AnigmaPrimitives/ToolContracts/
- [ ] Loop breaker for tool calls with deterministic blocking and recovery strategies
- [ ] Tool router plumbing with evidence recording and JSON response format
- [ ] Specialized tool implementation (read_file, apply_patch, swift_build, swift_test, git_diff, trace_query)
- [ ] Session DBs with merge-to-master capability using ATTACH DATABASE
- [ ] Snap out of loop recovery UX with deterministic next action templates
- [ ] BuildIngest recovery via ToolRouter operations
- [ ] Constraints compliance: no external runtime deps, JSON-first, no string-match edit APIs

**Implementation Phases:**
- [ ] **7.1:** Tool contracts + versioning primitives
- [ ] **7.2:** Loop breaker for tool calls (harness-side enforcement)
- [ ] **7.3:** ToolRouter plumbing + evidence recording
- [ ] **7.4:** Specialized tools implementation (MVP set)
- [ ] **7.5:** Session DBs + merge-to-master (safe, append-only)
- [ ] **7.6:** Snap out of loop recovery UX (agent-facing)
- [ ] **7.7:** BuildIngest recovery via tools
- [ ] **7.8:** Constraints & quality gates compliance

**Canonical Guarantees:**
- **Ledger-first flow**: Every tool call records intent before execution, outcome after
- **Loop breaker**: Deterministic block on repeated calls; returns recovery instruction
- **Session DBs**: Disposable per-agent scratch; merge-to-master idempotent
- **No string-match edits**: Favor unified diff or byte-range patch with precondition hash
- **Evidence recording**: Every tool call becomes tamper-evident

---

## Phase 8: Platform-Agnostic Ecosystem

**Canonical Principle:** Keep adding adapters without rewiring truth.

**Status:** 📋 PLANNED

**UI Renderers:**
- [ ] Implement renderer targets (COSMIC/libcosmic, WinUI/Avalonia, Compose)
- [ ] Surface platform perks (Keychain, share sheets, pickers) through host adapters
- [ ] Confine renderer code to presentation; governance stays in Harmonia

**Inference Backends:**
- [ ] Maintain Harmonia ML Runtime Bridge connectors (MLX, llama.cpp/MLC, ONNX, Core ML)
- [ ] Validate every cache artifact against reuse gate before reuse
- [ ] Log capability decisions for SecretStore, notifications, network actions

---

## Governance and Compliance

### Canonical Guarantees Checklist

An auditor with air-gapped tooling can verify:

1. **Receipt-identity derivation** – Recompute `BLAKE3(JCS(payload))` for any receipt
2. **Ledger-first flow** – Check that every mutation has preceding intent entry and subsequent outcome entry
3. **Query pinning** – Given query and snapshot, recompute semantic fingerprint and verify cached results
4. **Baseline normalization** – Run canonical normalizers and confirm no changes
5. **Time-evidence trust** – Inspect documented trust assumptions for timestamps
6. **Pattern enforcement** – Run CI detection scripts and confirm they fail on violations
7. **Segment referential integrity** – Cross-segment queries return consistent results
8. **Housekeeping evidence** – Every GC/VACUUM/ANALYZE operation recorded in ledger with full context

### Compliance Gates

- **Swift 6 concurrency** – Strict-concurrency builds pass
- **Type-authority boundaries** – No duplicate type definitions
- **Dependency insulation** – Core modules independent of capability churn
- **Escape-hatch expiry** – No expired escape hatches
- **Macro-expansion safety** – Expanded macros contain no forbidden constructs
- **Receipt-ID derivation** – All receipts follow `BLAKE3(JCS(payload))`
- **Normalization** – All committed files in canonical form
- **Pattern detection** – No stub markers, duplicate types, or forbidden imports
- **Ledger-first ops** – All mutations recordable with intent/outcome/rollback
- **Governance invariants** – Database integrity, retention compliance, segmentation consistency

### Cryptographic Guarantees

- **Integrity** – Hash chaining proves "unchanged since captured"
- **Authenticity** – Hardware-backed signatures prove "captured by authorized actor"
- **Temporal evidence** – RFC3161 tokens prove "captured at verifiable time"
- **Determinism** – Semantic fingerprints prove "same inputs → same outputs"
- **Auditability** – Ledger-first flow proves "complete decision trail"

---

## Architecture Principles (Canonical v3.2)

### Technical Specifications

#### SignedAssertion & ProofOfRecord

**SignedAssertion** – Cryptographically signed statement:
- `payload`: canonical JSON (JCS) of statement content
- `signature`: hardware-backed signature over `BLAKE3(payload)`
- `signerId`: identifier of signing key (hardware-attested)
- `timestamp`: external RFC3161 TSA token over digest

**ProofOfRecord** – Ledger entry recording state transition:
- `recordId`: `BLAKE3(JCS(recordBody))`
- `previousRecordId`: hash of preceding ledger entry
- `recordBody`: immutable content
- `witnessSignature`: optional signature from witnessing service

**No mathematical purity claims.** Both are cryptographic constructs with clear trust assumptions.

#### Receipt Identity: BLAKE3(JCS(payload))

Every receipt (evidence, ledger entry, query result) MUST derive identity as:
```
receiptId = BLAKE3(JSON.stringify(payload, { canonical: true }))
```

- No derivation from application fields
- No mutable fields in payload
- Canonical JSON ensures byte-identical serialization across platforms

#### Ledger-First Actor Flow

**Problem:** Traditional "mutate-then-record" creates forkable history.

**Solution:** Ledger-first durability:
1. **Record intent** – Write proposed mutation to ledger (signed, timestamped)
2. **Perform mutation** – Execute actual operation
3. **Record outcome** – Write completed mutation entry
4. **Rollback on failure** – Write rolled-back entry and revert changes

**Guarantee:** Ledger is single source of truth; any mismatch is detectable integrity violation.

#### Query Pinning with Semantic Fingerprints

**Problem:** "Deterministic queries" meaningless unless bound to specific snapshot.

**Solution:** Semantic fingerprint = `BLAKE3(JCS(query) + snapshotId)`

- `snapshotId`: content-addressed hash of dataset
- Query results cached by fingerprint; identical fingerprint → identical results
- Snapshots immutable; new data requires new snapshot

#### Baseline Normalization Contract

**Problem:** "Cross-platform reproducibility" poetic unless every file type has canonical representation.

**Solution:** Explicit normalization contracts per file type, enforced by CI:

| File type | Normalization rule | Verification command |
|-----------|-------------------|----------------------|
| JSON | JCS (RFC 8785) with sorted keys, no extra whitespace | `jq -c -S .` |
| Swift | `swift-format` with locked configuration | `swift-format --configuration .swift-format.json` |
| SQL | `sqlite-format` with consistent spacing/quoting | Custom normalizer |
| Markdown | CommonMark with prescribed extensions | `markdown-fmt` |

#### Time Anchoring as External Evidence

**Time anchoring is not a mathematical invariant;** it is external evidence with trust assumptions.

**Layers of time evidence:**
1. System clock – Weak evidence
2. Filesystem timestamps – Slightly stronger
3. NTP synchronized – Better
4. RFC3161 TSA tokens – Cryptographic proof from trusted TSA
5. NIST Randomness Beacon – Government-backed
6. Blockchain anchoring – Decentralized but requires chain trust

**Policy:** Each operation declares required time-evidence level. High-stakes (legal receipts) require RFC3161 tokens.

#### Mechanical Pattern Enforcement

**Problem:** "Patterns are theorems" is poetic policy, not detection mechanism.

**Solution:** Mechanical detection that fails builds and records violations in ledger.

**Detection mechanisms:**
- **Compiler failures** – Type-authority violations caught by Swift compiler
- **CI gates** – Scripts scanning for forbidden patterns (e.g., `#warning("STUB")`)
- **Ledger-recorded violations** – When violation detected, write entry to ledger triggering alerts

---

## Integration Points

### Current System State

**Completed subsystems:**
- ECS & job model (AnigmaCore)
- Harmonia surface (slot, session, request systems)
- Diaplasion pipeline (OCR → normalize → export)
- Outlineum pipeline (deterministic zine generation)
- Accessum daemon with persistent ledger
- Database governance & retention with GC, WAL management, segmentation, semantic search
- Testing suite with governance invariant enforcement

**Active development:**
- Phase 7: Tool router with loop breaker and session management

**Future phases:**
- Phase 8: Platform-agnostic ecosystem with renderers and inference backends

### Cross-Module Dependencies

- **DatabaseCore**: Central store for all ledger data, retention policies, query results
- **HarmoniaModule**: Orchestrates governance, policy enforcement, tool routing
- **Capability modules**: Diaplasion, Outlineum, Accessum flow through governed pipelines
- **HarmoniaCLI**: Exposes tools, queries, admin commands with JSON envelope

---

## Success Metrics

**Sigma Release Complete When:**

✅ Phase 0-6: Canonical guarantees mechanically enforced
✅ Phase 5: Production-ready Accessum daemon
✅ Phase 6: Database governance without unbounded growth
🟡 Phase 7: Tool router with loop prevention and session management
📋 Phase 8: Multiple UI renderers and inference backends functional

**Architectural Quality When:**
- All receipts follow `BLAKE3(JCS(payload))` derivation
- All mutations follow ledger-first flow
- All queries pinned to snapshots with semantic fingerprints
- All files in canonical form per normalization contract
- All time assumptions documented with evidence layers
- All patterns detected mechanically with CI failures + ledger recording

---

## Appendices

### A. Terminology (Canonical v3.2)

| v3.1 Term | v3.2 Term | Reason |
|-----------|-----------|--------|
| MathematicalProof | SignedAssertion / ProofOfRecord | Avoid math purity claims |
| receipt ID (derived) | receipt ID = BLAKE3(JCS(payload)) | Eliminate forkable history |
| deterministic queries | query pinning with semantic fingerprints | Bind to snapshots |
| cross-platform reproducibility | baseline normalization contract | Explicit, testable |
| time-stamping as invariant | time anchoring as evidence | Separate trust assumptions |
| pattern enforcement | mechanical pattern detection | Replace policy with CI |

### B. References

- `Docs/governance/Cathedral-Invariants.md` – Operational invariants for evidence enforcement
- `Docs/governance/Inspiration-Mining-Protocol.md` – Pattern-extraction protocol
- `Docs/ADR/` – Architecture decision records
- `Docs/DatabaseGovernancePlan.md` – Implementation plan for Phase 6
- `Docs/database-governance/DatabaseArchitecture.md` – Full Phase 6 documentation
- `Docs/status/status.json` – Current project status and phase tracking
- `Sources/DatabaseCore/` – Artifact store, GC, WAL management, segmentation
- `Sources/HarmoniaCLI/` – Tool contracts, router, and admin commands

### C. Migration Paths

**From Canonical v3.1 to v3.2:**
- Existing receipts with derived IDs grandfathered with migration utility
- Recompute IDs using new derivation; write migration entry to ledger
- Old IDs deprecated and eventually removed

**From Sigma Phase 6 to Phase 7:**
- Tool router extends existing DatabaseCore actor boundaries
- Session DBs merge-to-master using existing ATTACH DATABASE pattern
- Loop breaker uses existing tool_call_blocks table
- No breaking changes to ledger schema; additive only

---

**This document is the merged canonical roadmap for Anigma v4.0, unifying Canonical v3.2 architectural guarantees with Sigma release implementation phases and completion status.** Any deviation must be approved through the architectural-change process and documented with an updated version.

Last updated: 2025-12-29
