# Canonical v3.2 Pending Items Analysis

> Last updated: 2025-12-29
> Status: Tracking items from Canonical v3.2 not yet completed

---

## Overview

The Canonical v3.2 roadmap introduced seven "surgical fixes" for adversarial resilience. Of these, **most have been addressed**, but several **implementation details remain pending** across Phases 3-8.

---

## Canonical Principles Status

### ✅ Completed (Fully Implemented)

1. **SignedAssertion & ProofOfRecord** – Terminology clarified; no longer claiming "mathematical proofs"
2. **Receipt Identity: BLAKE3(JCS(payload))** – Architecture defined (need migration path implementation)
3. **Ledger-First Actor Flow** – Conceptually understood; Phase 7 will implement for all tool calls
4. **Mechanical Pattern Enforcement** – Phase 0 implemented CI gates; Phase 7 will add ledger recording

### 🟡 Partially Completed

5. **Query Pinning with Semantic Fingerprints** – Semantic search integrated in Phase 6, but:
   - [ ] Semantic fingerprint caching not yet implemented
   - [ ] Code-analysis queries over git commits not yet pinned
   
6. **Baseline Normalization Contract** – Documented but:
   - [ ] CI gates for Swift, JSON, SQL, Markdown normalization not yet enforced
   - [ ] Swift format configuration not locked
   
7. **Time Anchoring as Evidence** – Documented but:
   - [ ] RFC3161 TSA token integration not yet implemented
   - [ ] Trust assumptions not yet documented per operation

---

## Phase-by-Phase Pending Items

### Phase 3: Harmonia Migration

**Canonical Requirement:** Ledger-first tool router

**Current Status:** Not started

**Pending:**
- [ ] HarmoniaModule Components (RepoComponent, CodeComponent, SessionComponent, SlotComponent, InferenceRequestComponent)
- [ ] HarmoniaModule Systems (RepoIngestSystem, CodeAnalysisSystem, SlotManagementSystem, InferenceRoutingSystem, RefactorExecutionSystem)
- [ ] Ergasterion Integration (Monaco bundle finalized, Swift↔Monaco bridge, job-queue visualization)
- [ ] **Ledger-first tool router** – All tool calls follow record intent → mutate → record outcome pattern

### Phase 4: Accessum and Cross-Module

**Canonical Requirement:** Explicit normalization contracts with CI enforcement

**Current Status:** Partially complete

**Completed:**
- ✅ AccessumModule + Cross-module capabilities operational

**Pending:**
- [ ] **Normalization CI gates** – Add CI gates that enforce canonical formatting for:
  - [ ] JSON (JCS RFC 8785 with `jq -c -S .`)
  - [ ] Swift (`swift-format` with locked configuration)
  - [ ] SQL (`sql-format` with consistent spacing/quoting)
  - [ ] Markdown (CommonMark with prescribed extensions)

### Phase 5: Production Hardening

**Canonical Requirements:** Time-anchoring clarity + baseline normalization

**Current Status:** Partially complete

**Completed:**
- ✅ Observability (structured logging, metrics, health checks, admin dashboard)
- ✅ Persistence (job persistence, entity serialization, state snapshots)
- ✅ Deployment (macOS daemon, launchd, config schema)

**Pending:**
- [ ] **Time-evidence policy** – Document trust assumptions for each time-anchoring layer:
  - [ ] System clock trust assumptions
  - [ ] Filesystem timestamp limitations
  - [ ] NTP synchronization requirements
  - [ ] RFC3161 TSA token requirements for legal-grade receipts
  - [ ] Policy enforcement (which operations require which level)
- [ ] **Normalization contract implementation** – Implement per-file-type normalizers and CI gates (see Phase 4)
- [ ] **Swift-format configuration lockdown** – Create and commit `.swift-format.json`

### Phase 6: Production Database Governance & Retention

**Canonical Requirements:** Receipt-identity derivation + query pinning

**Current Status:** Substantially complete

**Completed:**
- ✅ Receipt-identity architecture (BLAKE3(JCS(payload)) designed)
- ✅ Master ledger segmentation (semantic fingerprints for queries over snapshots)

**Pending:**
- [ ] **Receipt-identity migration path** – Utility to recompute IDs for existing receipts:
  - [ ] Migration utility code
  - [ ] Migration ledger entry recording
  - [ ] Deprecation timeline for old IDs
- [ ] **Query-pinning implementation** – Add semantic-fingerprint caching to:
  - [ ] Retrieval queries (embedding store snapshot)
  - [ ] Code-analysis queries (git tree-hash snapshot)
  - [ ] Database queries (transaction-consistent hash)
- [ ] **ReceiptWire contract update** – Enforce BLAKE3(JCS(payload)) derivation:
  - [ ] Update `Sources/ExecutionCore/ReceiptTypes.swift`
  - [ ] Add compilation failure on mismatched receipt IDs
  - [ ] Update all receipt-creation code to use new derivation

### Phase 7: Harmonia Tool Router & Session Management

**Canonical Requirement:** Mechanical pattern enforcement with ledger recording

**Current Status:** Not started

**Pending (All):**
- [ ] **Tool Contracts & Versioning Primitives**
  - [ ] ToolContract type with name, version, inputSchema, outputSchema, requiredCapabilities, loopBreakerConfig
  - [ ] LoopBreakerConfig type with threshold, windowSeconds, cooldownSeconds, requiredRecoveryStrategy
  - [ ] RecoveryStrategy enum (require_unified_diff, require_byte_range_patch, require_fresh_read_delta, escalate_to_human)
  - [ ] JSON encode/decode helpers with explicit contractVersion
  
- [ ] **Loop Breaker for Tool Calls**
  - [ ] ToolCallLoopBreaker actor
  - [ ] Signature tracking (toolName, filePath, errorSignature, contentHash)
  - [ ] Block after N repeats within time window
  - [ ] Structured BlockReason with requiredRecoveryStrategy
  - [ ] Persist loop events to ledger (tool_call_blocks table)
  - [ ] Tests for repeated blocked calls
  
- [ ] **Tool Router Plumbing & Evidence Recording**
  - [ ] ToolRouter actor
  - [ ] Validate tool call against ToolContract
  - [ ] Run loop breaker preflight
  - [ ] Record start/end + status + artifacts + errorSignature to ledger
  - [ ] ToolCallResponse JSON (success/result/error/blocked/evidenceId)
  - [ ] HarmoniaCLI integration:
    - [ ] `harmonia tool call --tool <name> --json '<params>'`
    - [ ] `harmonia tool contracts --format json`
    - [ ] `harmonia tool calls --session-id ... --limit ... --format json`
  
- [ ] **Specialized Tool Implementation (MVP Set)**
  - [ ] `read_file` – Returns content + hash + size + mtime
  - [ ] `apply_patch` – Accepts unified diff OR byte-range patch; requires preconditionHash
  - [ ] `swift_build` – Runs swift build with cache env; returns status + logs artifact
  - [ ] `swift_test` – Runs swift test with filter; returns status + logs artifact
  - [ ] `git_diff` – Returns diff artifact + summary
  - [ ] `trace_query` – Reads migration_trace_steps and tool_calls
  - [ ] Per-tool artifact capture under `Artifacts/tool-router/<sessionId>/<requestId>/`
  
- [ ] **Session DBs + Merge-to-Master**
  - [ ] DatabaseConfiguration for session entries (`ANIGMA_SESSION_ID` creates dedicated PostgreSQL session entries)
  - [ ] CLI commands:
    - [ ] `harmonia session start --id <uuid> --db <name?>`
    - [ ] `harmonia session merge --id <uuid> --into <masterDbName>`
    - [ ] `harmonia session end --id <uuid> --delete-db`
  - [ ] Merge using PostgreSQL-native patterns (append-only tables only)
  - [ ] Idempotent inserts with stable primary keys
  - [ ] Tests for create/write/merge/verify
  
- [ ] **Snap Out of Loop Recovery UX**
  - [ ] Enhanced ToolCallResponse with diagnosis string + requiredRecoveryStrategy
  - [ ] Recovery templates (e.g., "Call read_file, then submit unified diff with preconditionHash=...")
  - [ ] CLI helper: `harmonia tool explain-block --evidence-id <id> --format json`
  
- [ ] **BuildIngest Recovery via Tools**
  - [ ] Refactor BuildIngest to consume ToolRouter operations
  - [ ] Fix remaining Swift 6 issues in BuildIngest
  - [ ] Integration test for build ingestion via tools
  
- [ ] **Mechanical Pattern-Detection Gates**
  - [ ] CI gates that fail builds on:
    - [ ] Stub markers (`#warning("STUB")`, `STUB_TRACK`)
    - [ ] Duplicate type definitions across modules
    - [ ] Forbidden imports (capability modules importing other capabilities)
  - [ ] Ledger recording of violations
  - [ ] Alert mechanism for pattern violations

### Phase 8: Platform-Agnostic Ecosystem

**Current Status:** Planned only

**Pending (All):**
- [ ] **UI Renderers**
  - [ ] Implement renderer targets (COSMIC/libcosmic, WinUI/Avalonia, Compose)
  - [ ] Surface platform perks (Keychain, share sheets, pickers) through host adapters
  - [ ] Confine renderer code to presentation; governance stays in Harmonia
  
- [ ] **Inference Backends**
  - [ ] Maintain Harmonia ML Runtime Bridge connectors (MLX, llama.cpp/MLC, ONNX, Core ML)
  - [ ] Validate every cache artifact against reuse gate before reuse
  - [ ] Log capability decisions for SecretStore, notifications, network actions

---

## Compliance Gates (From v3.2 – Status Check)

| Gate | Status | Notes |
|------|--------|-------|
| **Swift 6 concurrency** | 🟡 Partial | Strict-concurrency builds mostly pass; some escapes remain |
| **Type-authority boundaries** | 🟡 Partial | No known duplicates but not formally checked |
| **Dependency insulation** | ✅ Complete | Core modules independent of capability churn |
| **Escape-hatch expiry** | 📋 Not checked | Need audit of escape hatches for expiry |
| **Macro-expansion safety** | 📋 Not checked | Need audit of expanded macros |
| **Receipt-ID derivation** | 🟡 Partial | Architecture defined, migration path pending |
| **Normalization** | 🟡 Partial | Some files canonical, CI gates not yet enforced |
| **Pattern detection** | 🟡 Partial | Phase 0 did some; Phase 7 will complete |

---

## Critical Dependencies

### High Priority (Blocking Phase 7)

1. **ReceiptWire contract update** (Phase 6 migration)
   - Blocks semantic fingerprint implementation
   - Blocks query-pinning queries
   - Needed for all ledger-first operations

2. **Normalization CI gates** (Phase 4-5)
   - Swift format lockdown
   - JSON, SQL, Markdown enforcement
   - Needed for audit verification

3. **Time-evidence policy documentation** (Phase 5)
   - RFC3161 token integration points
   - Trust assumption per operation
   - Required for legal-grade receipts

### Medium Priority (Needed for Complete Compliance)

4. **Escape-hatch audit** (Phase 5)
   - Identify all `#warning`, `MARK: TODO`, escape hatches
   - Document expiry dates and approvals
   - Remove expired ones

5. **Macro-expansion audit** (Phase 5)
   - Check all Swift macros for forbidden constructs
   - Document expansion guarantees
   - Add CI gate if needed

---

## Recommended Priority Order

1. **Immediate (next sprint):**
   - [ ] ReceiptWire contract update + migration path (Phase 6 completion)
   - [ ] Swift format lockdown + CI gate (Phase 4-5)
   - [ ] Time-evidence policy documentation (Phase 5 completion)

2. **Next sprint:**
   - [ ] Query-pinning implementation (Phase 6 completion)
   - [ ] Normalization CI gates (Phase 4-5 completion)
   - [ ] Escape-hatch audit (Phase 5 gate)

3. **Phase 7 execution:**
   - [ ] Tool router with loop breaker (Phase 7.1-7.3)
   - [ ] Specialized tools (Phase 7.4)
   - [ ] Session DBs (Phase 7.5)
   - [ ] Mechanical pattern detection (Phase 7.8)

4. **Future:**
   - [ ] Platform-agnostic ecosystem (Phase 8)

---

## Key References

- `Docs/governance/Merged-Roadmap-v4.0.md` – Current merged roadmap
- `Docs/governance/Canonical-Roadmap-v3.2.md` – Original v3.2 with all requirements
- `Sources/ExecutionCore/ReceiptTypes.swift` – Receipt wire format (needs update)
- `Docs/status/status.json` – Phase tracking

---

**This document identifies all outstanding work from Canonical v3.2 needed to achieve complete adversarial resilience.**
