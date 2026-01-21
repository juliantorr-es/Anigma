# Canonical Roadmap v3.2

> Last updated: 2025-12-24  
> Previous version: v3.1-Final  
> Status: **Active** – Critical surgical fixes applied for hostile‑auditor resilience

Single source of truth for Anigma development, now hardened against adversarial scrutiny. For detailed architecture decisions, see `Docs/ADR/`. For the operational invariants that enforce these guarantees, see `Docs/governance/Cathedral‑Invariants.md`.

---

## Executive Summary: Critical Surgical Fixes

This roadmap version applies seven surgical fixes to the v3.1‑Final framework, eliminating vulnerabilities that hostile auditors could exploit. Every claim is now mechanically verifiable, terminology is honest, and cryptographic guarantees survive adversarial cross‑examination.

| Fix | Problem | Solution |
|-----|---------|----------|
| 1. Rename “MathematicalProof” to **SignedAssertion**/**ProofOfRecord** | Calling signed statements “mathematical proofs” is poetic overreach that invites legal challenge. | **SignedAssertion** for a signed statement, **ProofOfRecord** for a ledger entry. No mathematical purity claims. |
| 2. Fix receipt identity derivation | Receipt IDs derived from application fields create forkable history and break determinism. | **BLAKE3(JCS(payload))** as the sole receipt ID; no derivation from mutable fields. |
| 3. Implement ledger‑first actor flow | `await` gaps between mutation and recording create forkable history. | **Ledger‑first durability** – record intent before mutation, rollback on failure, no gaps. |
| 4. Add proper query pinning | “Deterministic queries” without snapshot binding are hand‑waving. | **Semantic fingerprint** of query + snapshot binds results; replay identical given same fingerprint. |
| 5. Create explicit baseline normalization contract | “Cross‑platform reproducibility” claims are poetic, not testable. | **Explicit normalization contract** per file type; CI verifies canonical bytes match. |
| 6. Clarify time anchoring as evidence, not math | Time‑stamping is external evidence with trust assumptions, not a mathematical invariant. | **Time anchoring** is an optional evidence layer; trust assumptions documented and auditable. |
| 7. Replace poetic pattern enforcement with mechanical detection | “Patterns are theorems” is a policy statement, not a detection mechanism. | **Mechanical detection** via compiler failures, CI gates, and ledger‑recorded violations. |

**Result:** A roadmap where every claim can be verified by a hostile auditor with air‑gapped tooling, no reliance on policy discretion, and no poetic overstatement.

---

## Technical Specifications

### 2.1 SignedAssertion & ProofOfRecord

**SignedAssertion** – A cryptographically signed statement containing:
- `payload`: canonical JSON (JCS) of the statement content
- `signature`: hardware‑backed signature over `BLAKE3(payload)`
- `signerId`: identifier of the signing key (hardware‑attested)
- `timestamp`: external RFC3161 TSA token over the digest

**ProofOfRecord** – A ledger entry that records a state transition:
- `recordId`: `BLAKE3(JCS(recordBody))`
- `previousRecordId`: hash of the preceding ledger entry
- `recordBody`: immutable content (SignedAssertion, evidence, or metadata)
- `witnessSignature`: optional signature from a witnessing service

**No mathematical purity claims.** Both types are cryptographic constructs with clear trust assumptions; they are not called “proofs” unless they meet formal mathematical proof criteria (which they do not).

### 2.2 Receipt Identity: BLAKE3(JCS(payload))

Every receipt (evidence, ledger entry, query result) MUST derive its identity as:

```
receiptId = BLAKE3(
  JSON.stringify(payload, { canonical: true })   // JCS (RFC 8785)
)
```

- **No derivation from application fields** (e.g., `(actionName + timestamp)`).  
- **No mutable fields** in the payload that would change the hash after creation.  
- **Canonical JSON** ensures byte‑identical serialization across platforms.

Implementation contracts:
- `ReceiptWire.receiptID` is computed from the wire‑format payload, not supplied by caller.
- Receipt stores MUST enforce this derivation; violations are compilation failures.
- Existing receipts are grandfathered with a migration path.

### 2.3 Ledger‑First Actor Flow

**Problem:** Traditional “mutate‑then‑record” flows create a forkable history: if the system crashes after mutation but before recording, the ledger disagrees with reality.

**Solution:** Ledger‑first durability:

1. **Record intent** – Write a “proposed mutation” entry to the ledger, signed and timestamped.
2. **Perform mutation** – Execute the actual operation (file write, build, test).
3. **Record outcome** – Write a “completed mutation” entry referencing the intent.
4. **Rollback on failure** – If step 2 fails, write a “rolled‑back” entry and revert any partial changes.

**Guarantee:** The ledger is the single source of truth; any mismatch between ledger and filesystem is a detectable integrity violation.

**Implementation:** All tool‑router operations follow this pattern; the ledger is the coordination primitive, not a passive log.

### 2.4 Query Pinning with Semantic Fingerprints

**Problem:** “Deterministic queries” are meaningless unless bound to a specific snapshot of the data.

**Solution:** Semantic fingerprint = `BLAKE3(JCS(query) + snapshotId)`.

- `snapshotId`: content‑addressed hash of the dataset (e.g., SQLite database hash at a point in time).
- Query results are cached by fingerprint; identical fingerprint → identical results.
- Snapshots are immutable; new data requires a new snapshot.

**Use cases:**
- Retrieval queries over embeddings (snapshot = embedding store hash).
- Code analysis over a git commit (snapshot = tree‑hash).
- Database queries (snapshot = transaction‑consistent hash).

**Verification:** Auditors can recompute the fingerprint from the query and snapshot, then verify the cached results match.

### 2.5 Baseline Normalization Contract

**Problem:** “Cross‑platform reproducibility” is a poetic claim unless every file format has a canonical byte‑for‑byte representation.

**Solution:** Explicit normalization contracts per file type, enforced by CI.

| File type | Normalization rule | Verification command |
|-----------|-------------------|----------------------|
| JSON      | JCS (RFC 8785) with sorted keys, no extra whitespace | `jq -c -S .` |
| Swift     | `swift‑format` with locked configuration | `swift‑format --configuration .swift‑format.json` |
| SQL       | `sqlite‑format` with consistent spacing and quoting | Custom normalizer |
| Markdown  | CommonMark with prescribed extensions | `markdown‑fmt` |

**Contract:** Every file committed to the repository MUST be in its normalized form; CI rejects non‑canonical bytes.

**Audit benefit:** Hostile auditors can run the same normalization tool and confirm the repository matches the canonical form, eliminating “different serialization” attacks.

### 2.6 Time Anchoring as External Evidence

**Time anchoring is not a mathematical invariant;** it is external evidence with trust assumptions.

**Layers of time evidence:**

1. **System clock** – Weak evidence, easily manipulated.
2. **Filesystem timestamps** – Slightly stronger, but still local.
3. **NTP synchronized** – Better, but still reliant on time servers.
4. **RFC3161 TSA tokens** – Cryptographic proof from a trusted timestamping authority.
5. **NIST Randomness Beacon** – Government‑backed external anchor.
6. **Blockchain anchoring** – Decentralized but requires trust in the chain.

**Policy:** Each operation declares the required time‑evidence level. High‑stakes operations (legal receipts) require RFC3161 tokens.

**Trust assumptions are documented** and auditable. No claim that timestamps are “mathematically proven”.

### 2.7 Mechanical Pattern Enforcement

**Problem:** “Patterns are theorems” is a poetic enforcement policy, not a detection mechanism.

**Solution:** Mechanical detection that fails builds and records violations in the ledger.

**Detection mechanisms:**

- **Compiler failures** – Type‑authority violations are caught by Swift compiler (duplicate type definitions).
- **CI gates** – Scripts that scan for forbidden patterns (e.g., `#warning("STUB")` left behind).
- **Ledger‑recorded violations** – When a pattern violation is detected, a violation entry is written to the ledger, triggering alerts.

**No policy discretion.** Patterns are encoded as testable rules; violations are mechanically detected and reported.

**Example:** The “no‑stub‑left‑behind” rule is enforced by a CI script that greps for `STUB_TRACK` markers and fails the build if any remain.

---

## Phased Implementation Roadmap

### Phase 1: Foundation (Current)

*Unchanged from v3.1.* Establishes AnigmaCore as the proven ECS/Job spine with one fully‑ported module.

### Phase 2: Diaplasion Module Implementation

*Unchanged from v3.1.* Implements the alt‑media transformation engine to validate AnigmaCore generality.

### Phase 3: Harmonia Migration

**Updated with ledger‑first actor flow.**

- [ ] **HarmoniaModule Components** – RepoComponent, CodeComponent, SessionComponent, SlotComponent, InferenceRequestComponent.
- [ ] **HarmoniaModule Systems** – RepoIngestSystem, CodeAnalysisSystem, SlotManagementSystem, InferenceRoutingSystem, RefactorExecutionSystem.
- [ ] **Ergasterion Integration** – Monaco bundle finalized, Swift↔Monaco bridge, job‑queue visualization.
- [ ] **Ledger‑first tool router** – All tool calls follow the ledger‑first durability pattern (record intent → mutate → record outcome).

### Phase 4: Accessum and Cross‑Module

**Updated with explicit normalization contracts.**

- [ ] **AccessumModule** – LibraryComponent, PreferenceComponent, SyncComponent, client‑facing UI shell.
- [ ] **Cross‑module capabilities** – Unified job dashboard, shared QA pipeline components, cross‑module workflow chaining.
- [ ] **Normalization CI gates** – Add CI gates that enforce canonical formatting for JSON, Swift, SQL, Markdown.

### Phase 5: Production Hardening

**Updated with time‑anchoring clarity and baseline normalization.**

- [ ] **Observability** – Structured logging, metrics collection, health‑check endpoints, admin dashboard.
- [ ] **Persistence** – Job persistence and recovery, entity/component serialization, state snapshots.
- [ ] **Deployment** – macOS daemon packaging, launchd integration, configuration file schema.
- [ ] **Time‑evidence policy** – Document trust assumptions for each time‑anchoring layer; require RFC3161 tokens for legal‑grade receipts.
- [ ] **Normalization contracts** – Implement per‑file‑type normalizers and integrate into CI.

### Phase 6: Production Database Governance & Retention

**Updated with receipt‑identity derivation and query pinning.**

- [ ] **DatabaseCore Data Model Enhancement** – Content‑addressed artifact store, master‑ledger thinning, session‑DB boundaries, deduplication enforcement.
- [ ] **Retention Policy Contract** – Machine‑readable policy, policy classes, deletion definitions, policy integration.
- [ ] **Garbage Collection Command** – Deterministic GC entry point, GC flow, eligibility proof, dry‑run mode.
- [ ] **SQLite Housekeeping** – WAL mode management, scheduled VACUUM, ANALYZE optimization, performance monitoring.
- [ ] **Master‑Ledger Segmentation** – Log segments, master‑index DB, independent rotation, evidence‑pointer scheme.
- [ ] **Semantic Search Integration** – DatabaseCore storage, inference separation, retrieval evidence, audit trail.
- [ ] **Evidence for Housekeeping** – Retention event type, refusal logging, cleanup auditing, storage reporting.
- [ ] **Receipt‑identity enforcement** – Migrate all receipt IDs to `BLAKE3(JCS(payload))`; update ReceiptWire contract.
- [ ] **Query‑pinning implementation** – Add semantic‑fingerprint caching to retrieval and code‑analysis queries.

### Phase 7: Harmonia Tool Router & Session Management

**Updated with mechanical pattern enforcement.**

- [ ] **Tool Contracts & Versioning Primitives** – ToolContract, LoopBreakerConfig, RecoveryStrategy, JSON encode/decode helpers.
- [ ] **Loop Breaker for Tool Calls** – ToolCallLoopBreaker, block after N repeats, persist loop events, tests.
- [ ] **Tool Router Plumbing & Evidence Recording** – ToolRouter, record start/end + status + artifacts + errorSignature, ToolCallResponse JSON, HarmoniaCLI integration.
- [ ] **Specialized Tool Implementation (MVP Set)** – read_file, apply_patch, swift_build, swift_test, git_diff, trace_query.
- [ ] **Session DBs + Merge‑to‑Master** – DatabaseConfiguration, CLI commands, merge using ATTACH DATABASE, idempotent inserts.
- [ ] **“Snap Out of Loop” Recovery UX** – Enhanced ToolCallResponse, recovery templates, CLI helper.
- [ ] **BuildIngest Recovery via Tools** – Refactor BuildIngest to consume ToolRouter operations, fix Swift 6 issues, integration test.
- [ ] **Mechanical pattern‑detection gates** – Add CI gates that fail builds on stub markers, duplicate type definitions, forbidden imports, etc.
- [ ] **Ledger‑recorded violations** – When a pattern violation is detected, write a violation entry to the ledger.

### Phase 8: Platform‑Agnostic Ecosystem

*Unchanged from v3.1.* Keep adding adapters without rewiring truth.

---

## Governance and Compliance

### Verification Checklist for Hostile Auditors

An auditor with air‑gapped tooling can verify:

1. **Receipt‑identity derivation** – Recompute `BLAKE3(JCS(payload))` for any receipt and confirm it matches the stored ID.
2. **Ledger‑first flow** – Check that every mutation has a preceding intent entry and a subsequent outcome entry; detect gaps.
3. **Query pinning** – Given a query and snapshot, recompute the semantic fingerprint and verify cached results.
4. **Baseline normalization** – Run the canonical normalizers on the repository and confirm no changes.
5. **Time‑evidence trust** – Inspect the documented trust assumptions for timestamps; verify RFC3161 tokens where required.
6. **Pattern enforcement** – Run the CI detection scripts and confirm they fail on violations.

### Compliance Gates

- **Swift 6 concurrency** – Strict‑concurrency builds pass.
- **Type‑authority boundaries** – No duplicate type definitions across modules.
- **Dependency insulation** – Core modules do not depend on capability‑module churn.
- **Escape‑hatch expiry** – No expired escape hatches; all have approval metadata.
- **Macro‑expansion safety** – Expanded macros contain no forbidden constructs.
- **Receipt‑ID derivation** – All receipts follow `BLAKE3(JCS(payload))`.
- **Normalization** – All committed files are in canonical form.
- **Pattern detection** – No stub markers, duplicate types, or forbidden imports.

### Cryptographic Guarantees

- **Integrity** – Hash chaining proves “unchanged since captured.”
- **Authenticity** – Hardware‑backed signatures prove “captured by authorized actor.”
- **Temporal evidence** – RFC3161 tokens prove “captured at verifiable time.”
- **Determinism** – Semantic fingerprints prove “same inputs → same outputs.”

---

## Appendices

### A. Terminology Changes from v3.1

| v3.1 Term | v3.2 Term | Reason |
|-----------|-----------|--------|
| MathematicalProof | SignedAssertion / ProofOfRecord | Avoid mathematical purity claims; describe what it actually is. |
| receipt ID (derived) | receipt ID = BLAKE3(JCS(payload)) | Eliminate forkable history and ensure determinism. |
| deterministic queries | query pinning with semantic fingerprints | Bind queries to snapshots; testable guarantee. |
| cross‑platform reproducibility | baseline normalization contract | Explicit, testable contracts per file type. |
| time‑stamping as invariant | time anchoring as evidence | Separate external evidence with trust assumptions. |
| pattern enforcement | mechanical pattern detection | Replace poetic policy with CI‑enforced detection. |

### B. Migration Path for Existing Receipts

Existing receipts that use derived IDs are grandfathered. A migration utility will recompute IDs using the new derivation and write a migration entry to the ledger. After migration, the old IDs are deprecated and eventually removed.

### C. References

- `Docs/governance/Cathedral‑Invariants.md` – Operational invariants for evidence enforcement.
- `Docs/governance/Inspiration‑Mining‑Protocol.md` – Pattern‑extraction protocol.
- `Docs/ADR/` – Architecture decision records that shaped this roadmap.
- `Session‑ses_4e48.md` – Court‑safe evidence system design discussion.
- `Sources/ExecutionCore/ReceiptTypes.swift` – Receipt wire‑format definitions.

---

**This document is the canonical roadmap for Anigma v3.2.** Any deviation must be approved through the architectural‑change process and documented with an updated version.
