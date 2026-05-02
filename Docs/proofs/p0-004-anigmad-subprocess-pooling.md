# P0-004: anigmad Subprocess Pooling

**Task:** P0-004 — anigmad Subprocess Pooling  
**Epic:** td-12f9d2 (Unify Under anigmad with Warm Subprocess Pooling)  
**Canonical Proof Path:** `Docs/proofs/p0-004-anigmad-subprocess-pooling.md`  
**Date:** 2026-05-02  
**Status:** PREREQUISITES COMPLETE — Runtime implementation already existed

---

## Classification

**P0-004 prerequisite/tier registration completed; runtime implementation remains as pre-existing.**

The P0-004 lane work performed was **validator configuration and dependency metadata alignment only** — not runtime subprocess pooling implementation. The SubprocessPooling package with its full runtime implementation (SubprocessManager, ProcessPool, MLWorker, MCPWorker, etc.) **already existed before P0-004 work began** and was **not modified** during this lane.

---

## Objective
Complete prerequisite setup for P0-004 lane: register SubprocessPooling modules in governance validators and correct dependency metadata.

## Context
P0-004 corresponds to epic **td-12f9d2** "Unify Under anigmad with Warm Subprocess Pooling" comprising 6 phases.  

The **runtime implementation** of SubprocessPooling was already present in the codebase prior to this lane, including:
- `SubprocessManager.swift` with `ProcessPool<W>` and `SubprocessManager` singleton
- `MLWorker.swift` with UMA buffer pools and model caching
- `MCPWorker.swift` with Unix domain socket communication
- `PDFSidecarWorker.swift` for PDF processing
- `BenchmarkWorker.swift` for benchmark execution
- IPC implementations (stdio, Unix domain sockets)
- LLM provider adapters (Claude, Gemini, Mistral, OpenAI, OpenCode, Test)

**This lane addressed only the governance/validator prerequisites for P0-004.**

---

## Lane Work Performed

### 1. Validator Configuration Alignment
Added missing modules to tier definitions to enable governance validation:

**tools/governance/scripts/validate_tiers.py:**
```python
# Before
TIER_1 = {..., "SecurityEventsManager", ...}
TIER_2 = {...}
TIER_3 = {...}

# After  
TIER_1 = {...}  # SecurityEventsManager moved to TIER_2 (P1 work)
TIER_2 = {..., "SecurityEventsManager", "SubprocessPooling"}
TIER_3 = {..., "AnigmaDaemonCore", "AnigmaDaemon"}
```

**Rationale:**
- **SubprocessPooling** → TIER_2: Platform/Substrate infrastructure for process pooling
- **AnigmaDaemonCore** → TIER_3: Capability daemon depending on TIER_3 modules
- **AnigmaDaemon** → TIER_3: Main daemon executable depending on AnigmaDaemonCore

### 2. Package Dependency Correction
Fixed stale dependency declaration:

**anigma/Package.swift:**
```swift
// Before
.target(
    name: "SubprocessPooling", 
    dependencies: ["AnigmaPrimitives"],  // Stale: no actual imports of AnigmaPrimitives
    path: "Packages/SubprocessPooling/Sources",
    swiftSettings: strictConcurrencySettings)

// After
.target(
    name: "SubprocessPooling",
    dependencies: [],  // SubprocessPooling has its own AnyCodable in Utilities/
    path: "Packages/SubprocessPooling/Sources",
    swiftSettings: strictConcurrencySettings)
```

**Verification:** SubprocessPooling only imports system frameworks (Foundation, Metal, OSLog, System). Its `Utilities/AnyCodable.swift` provides independent type-erased Codable.

### 3. Documentation Update
**README.md:** Updated validator status to reflect `validate_tiers.py` now passing.

---

## Runtime Source Changes

### Files Modified in This Lane
```
Docs/diagrams/*                         # Documentation diagrams
Docs/manifests/*                       # Documentation manifests  
Docs/proofs/*                          # Proof artifacts
Docs/schemas/*                          # Schema definitions
README.md                              # Validator status
anigma/Package.swift                    # Dependency metadata
tools/governance/scripts/validate_tiers.py  # Tier configuration
```

**Result: ZERO runtime source file modifications.**

### Pre-existing Runtime Implementation
The SubprocessPooling package (23 source files) existed **unchanged** at HEAD:
```
anigma/Packages/SubprocessPooling/Sources/
├── BenchmarkWorker.swift
├── MLWorker.swift
├── MCPWorker.swift
├── PDFSidecarWorker.swift
├── SubprocessManager.swift
├── IPC/
│   ├── StdIOIPC.swift
│   └── UnixDomainSocketIPC.swift
├── LLMProviders/
│   ├── ClaudeProvider.swift
│   ├── GeminiProvider.swift
│   ├── MistralProvider.swift
│   ├── OpenAICodexProvider.swift
│   ├── OpenCodeProvider.swift
│   └── TestProvider.swift
└── Utilities/
    └── AnyCodable.swift
```

** git diff HEAD -- anigma/Packages/SubprocessPooling/ = **EMPTY** (no modifications)

---

## Verification Results

### Governance Validators: ALL GREEN
| Validator | Exit Code | Result | Working Directory |
|-----------|-----------|--------|-------------------|
| `validate_tiers.py` | **0** | ✅ Architecture is clean. All tier boundaries respected. | `anigma/` |
| `validate_no_cycles.py` | **0** | ✅ No dependency cycles detected. | `anigma/` |
| `validate_exported_imports.py` | **0** | ✅ No non-allowlisted @_exported imports found. | `anigma/` |

### Build Verification
```bash
swift build --target SubprocessPooling    # ✅ Already builds (pre-existing)
```

---

## Tier Boundaries (Post-Lane)

| Tier | Modules |
|------|---------|
| **TIER_1** | GovernanceCore, DoctrineCore, AnigmaPrimitives, ContractsCore, TelemetryCore |
| **TIER_2** | AnigmaCore, PlatformCore, DatabaseCore, StorageCore, ExecutionCore, InferenceCore, CathedralModule, CapabilityCore, AnigmaSystemSpine, GovernedMigrationCore, SecurityEventsManager, **SubprocessPooling** |
| **TIER_3** | HarmoniaModule, DiaplasionModule, AccessumModule, OutlineumModule, PragmaModule, ConexusModule, CodexModule, TranscriptumModule, ObservatoriumModule, PolytroposModule, VectorumModule, PraxisModule, **AnigmaDaemonCore**, **AnigmaDaemon** |

---

## Architecture Integrity

- ✅ **No runtime source changes** — Lane modified only validator config, Package.swift metadata, and docs
- ✅ **No validator weakening** — Configuration alignment only
- ✅ **Tier boundaries maintained** — All dependencies follow TIER_3 → TIER_2 → TIER_1
- ✅ **All governance validators pass** — Exit code 0
- ✅ **No regression** — SubprocessPooling still builds

---

## Corrected Lane Status

**P0-004: PREREQUISITES COMPLETE — NOT RUNTIME IMPLEMENTATION**

The work performed in this lane was **setup/tier-registration** for the SubprocessPooling architecture:
1. ✅ Validator configuration updated to track SubprocessPooling, AnigmaDaemonCore, AnigmaDaemon
2. ✅ Stale Package.swift dependency corrected
3. ✅ Documentation updated

**The runtime subprocess pooling implementation already existed and was not touched.**

---

## Runtime Implementation Status

| Component | Status | Location |
|-----------|--------|----------|
| SubprocessManager foundation | **Pre-existing** | `Packages/SubprocessPooling/Sources/SubprocessManager.swift` |
| ProcessPool generic pool | **Pre-existing** | Same file |
| SubprocessManager singleton | **Pre-existing** | Same file |
| MLWorker UMA pool | **Pre-existing** | `Packages/SubprocessPooling/Sources/MLWorker.swift` |
| MCPWorker Unix socket pool | **Pre-existing** | `Packages/SubprocessPooling/Sources/MCPWorker.swift` |
| PDFSidecarWorker | **Pre-existing** | `Packages/SubprocessPooling/Sources/PDFSidecarWorker.swift` |
| BenchmarkWorker | **Pre-existing** | `Packages/SubprocessPooling/Sources/BenchmarkWorker.swift` |
| IPC implementations | **Pre-existing** | `Packages/SubprocessPooling/Sources/IPC/` |
| LLM provider adapters | **Pre-existing** | `Packages/SubprocessPooling/Sources/LLMProviders/` |

---

## Upstream Dependencies

### AnigmaDaemonCore → SubprocessPooling
AnigmaDaemonCore (TIER_3) imports SubprocessPooling (TIER_2) in:
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+LLM.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Session.swift`
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Services.swift`

This dependency is **valid**: TIER_3 → TIER_2 is allowed.

---

## Recommended Next TD Transition

**Next lane should be the actual runtime implementation work for td-12f9d2 phases 1-5** if they are not complete, OR **the next P0 epic** if td-12f9d2 runtime phases are already implemented (which appears to be the case based on the pre-existing code).

**Status:** 
- P1 Architecture Debt: ✅ CLEARED
- P0-004 Prerequisites: ✅ COMPLETE
- P0-004 Runtime Implementation: **Status unclear — code exists, TD tasks show in_review/in_progress**

**Action required:** Review td-12f9d2 child task status (td-a84da2, td-80575e, td-bfe7a3, td-0dfb09, td-73aea8, td-ce4439) to determine if runtime implementation is complete or if additional work is needed.

---
*ADR Reference: ADR-0006-three-tier-runtime-architecture.md*  
*Epic: td-12f9d2 (Unify Under anigmad with Warm Subprocess Pooling)*  
*Proof Path: Docs/proofs/p0-004-anigmad-subprocess-pooling.md*  
*Prerequisites: P0-003 (Verified), P1 Architecture Debt (Cleared)*
