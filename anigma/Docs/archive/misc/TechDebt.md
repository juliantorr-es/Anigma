# Technical Debt & Scaffolding Tracker

> Last Updated: 2025-12-31  
> Status: Post-Convergence Reality Sync

This ledger tracks real, in-repo stubs and debt. Every `STUB_TRACK:` comment should have a matching entry here; when a stub is closed, remove the comment and update this file.

## How to Use
- Add a stub: add `#warning("STUB: ...")` and `// STUB_TRACK: ...` in code, then add an entry here.
- Resolve a stub: remove warning/comment, mark the item resolved here (with commit/PR).
- Audit: `rg "STUB_TRACK"` or `rg "TODO:|FIXME:"` for untracked debt.

---

## Recently Resolved (2025-12-31 Convergence)

### ✅ Telemetry Consolidation (Stage 3) – RESOLVED
**Commit**: `c44c102a`  
**Resolution**: Deleted `AnigmaCore/Telemetry/` (3 files, ~1,400 lines), migrated to `TelemetryCore.TelemetryClient`  
**Exit Criteria**: `rg "actor TelemetryService"` → ObservatoriumModule only, `rg "import.*Telemetry" | grep -v TelemetryCore` → 0 results

### ✅ HarmoniaSpine Namespace Cleanup (Stage 4) – RESOLVED
**Commit**: `a3a5e102`  
**Resolution**: Merged `HarmoniaSpine/` → `HarmoniaModule/Spine/`, removed target from Package.swift  
**Exit Criteria**: `rg "HarmoniaSpine\."` → 0 results, `rg "import HarmoniaSpine"` → 0 results

### ✅ PDF Pipeline Contracts – RESOLVED
**Files**: `AnigmaCore/Pipeline/Contracts/PDF*.swift`  
**Status**: Contracts emit real regions/bounding boxes, extract text with evidence

### ✅ MLOutputCache Errors – RESOLVED
**File**: `Sources/DatabaseCore/MLOutputCache.swift`  
**Status**: Fixed all compilation errors

### ✅ BuildIngest ArgumentParser – RESOLVED  
**File**: `Sources/BuildIngest/ArgumentParser+Extensions.swift`  
**Status**: Resolved NameSpecification type conversion failures

### ✅ NameSpecification Type – RESOLVED
**File**: `Sources/AnigmaPrimitives/NameSpecification.swift`  
**Status**: Created reusable type-safe build specifications

### ✅ Script Runtime Execution – RESOLVED (2026-01-02)
**Location**: `Sources/AnigmaCore/Pipeline/PluginSystem.swift`  
**Resolution**: Added script runtime registry and local process runtime with sandbox gating  
**Impact**: Medium – Script nodes can now execute with permissive sandbox settings

### ✅ VectorumModule – ML Worker Integration – RESOLVED (2026-01-03)
**Location**: `Sources/VectorumModule/VectorumModule.swift`  
**Resolution**: Implemented ml-worker JSON line protocol runner with embedding decoding  
**Impact**: Medium – Embedding computations now route through ml-worker

### ✅ PolytroposModule – ML Model Provisioning – RESOLVED (2026-01-03)
**Location**: `Sources/PolytroposModule/Systems/MLModelProvisioningSystem.swift`  
**Resolution**: Implemented download, verification, installation, and health checks  
**Impact**: Medium – Model provisioning logic is now functional

---

## Active Debt

### 🔄 DatabaseCore Swift 6 Compliance
- **Files**: Various `Sources/DatabaseCore/` files
- **Status**: Needs audit for Swift 6 strict concurrency compliance
- **Priority**: High - Core dependency blocking other modules
- **Owner**: Unassigned

### 🔄 SecurityEventLogger Expansion
- **File**: `Sources/HarmoniaModule/Spine/SecurityEventLogger.swift` (was `HarmoniaSpine/`)
- **Status**: Partial implementation, needs comprehensive event types
- **Priority**: Medium
- **Owner**: Unassigned

### 🔄 Experimental Module Graduation
- **Policy**: `Docs/governance/module-graduation-policy.md`
- **Status**: Policy defined, enforcement script (`Scripts/check-experimental-policy.sh`) created
- **Action**: Review experimental modules quarterly for graduation or sunset
- **Modules**: ObservatoriumModule, PolytroposModule, TranscriptumModule, PragmaModule
- **Priority**: Quarterly governance hygiene

### ✅ VaultCommand & StorageCore – RESOLVED (2026-01-02)
- **Location**: `Sources/HarmoniaCLI/VaultCommand.swift`, `Sources/StorageCore/`
- **Status**: Fully restored and operational
- **Resolution**: 
  - Added `GovernanceCore` dependency to `StorageCore` in `Package.swift`
  - Adapted `VaultAuthority.gc()` to work with refactored `RetentionPolicy` API
  - Removed stub implementation, restored full vault functionality
- **Impact**: High - Critical storage infrastructure now available
- **Priority**: COMPLETED
- **Owner**: Completed in Phase 1 stabilization


---

## Non-Goals (Explicitly Out of Scope)

These are not debt; they are intentional design decisions:

- **ObservatoriumModule.TelemetryService**: Domain-specific service for observability UI, not legacy telemetry
- **Package.swift warning messages**: Cosmetic parsing warnings from Swift Package Manager, not blocking
- **Experimental module churn**: Experimental modules may have rapid iteration; governed by graduation policy

---

## Audit Commands

```bash
# Find all stub markers
rg "STUB_TRACK|TODO:|FIXME:" Sources/ --type swift

# Verify telemetry consolidation
rg "actor TelemetryService|import.*Telemetry" Sources/ --type swift

# Check HarmoniaSpine removal
rg "HarmoniaSpine" Sources/ Package.swift

# Experimental module policy enforcement
Scripts/check-experimental-policy.sh
```

---

## Governance

- Debt items must be mechanically verifiable (grep commands, build status)
- Resolved items stay in ledger with commit hashes for audit trail
- No "poetic debt" - only concrete, actionable items with clear exit criteria
