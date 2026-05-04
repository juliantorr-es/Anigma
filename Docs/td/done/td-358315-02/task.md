# TD-358315-02: Extract portable layout/PDF contract surface to break AnigmaPipeline → LayoutEngineCapsule → PDFNative path

**TD ID:** td-358315-02  
**Parent TD:** td-358315  
**Priority:** P0  
**Status:** DONE
**Completed:** 2026-05-03
**Unblocks:** td-358315-01  
**Created:** 2026-05-03  
**Blocks:** td-358315-01
**Research:** COMPLETE - Docs/td/hypotheses/td-358315-02/td-358315-02-layout-contract-extraction-research.md  

---

## Problem

Generic BackendReadiness reaches PDFNative through the following SwiftPM target dependency path:

```
BackendReadinessContractTests 
  → AnigmaCore 
  → AnigmaPipeline 
  → LayoutEngineCapsule 
  → PDFNative
```

This violates the architectural requirement that generic BackendReadiness **must not** depend on:
- PDFNative
- PDFSidecarNativeShims
- PDFSidecarExecutable
- PDFium-owned targets

The SwiftPM target dependencies are **actual module/build relationships**. This graph path is not theoretical; it represents the package boundary doing exactly what the dependency graph dictates.

### Evidence

From Package.swift analysis:
- `BackendReadinessContractTests` depends on `AnigmaCore`
- `AnigmaCore` targets include `AnigmaPipeline`
- `AnigmaPipeline` depends on `LayoutEngineCapsule`
- `LayoutEngineCapsule` depends on `PDFNative`

From `PDFLayoutExtractContract.swift` (currently in AnigmaPipeline):
- Direct call to `LayoutEngineCapsuleWrapper.analyzePDF` (line 220)
- Uses internal types from LayoutEngineCapsule: `PageLayout`, `TextSegment`, `ImageData`, `BoundingBox`
- Internal `init(from:)` methods on contract structs reference LayoutEngineCapsule types

### Why Previous Attempts Failed

The rejected implementation (td-358315-01) attempted to add `PDFLayoutExtractWrapper.swift` to AnigmaPipeline. This preserved/moved PDF/layout implementation **into** the generic AnigmaPipeline target, which:

1. Did not solve the type visibility problem (internal types from LayoutEngineCapsule remain inaccessible from AnigmaPipeline module boundary)
2. Deepened the architectural violation (PDF-specific implementation in generic pipeline)
3. Perpetuated the dependency path to PDFNative

---

## Goal

Separate portable layout/PDF contract surface from PDF/native implementation so AnigmaPipeline can **register or reference** PDF layout extraction capability **without** depending on LayoutEngineCapsule or PDFNative.

The correct shape:
```
AnigmaPipeline
  → portable layout/PDF contract surface ONLY

PDFLayoutExtract / LayoutEngineCapsule implementation
  → PDFNative / PDFSidecarNativeShims / PDFium-owned targets
```

---

## Non-Goals

- ❌ Do NOT make LayoutEngineCapsule internal types public merely to satisfy AnigmaPipeline
- ❌ Do NOT add PDFLayoutExtractWrapper.swift to AnigmaPipeline
- ❌ Do NOT link PDFium into BackendReadiness
- ❌ Do NOT move PDF/native implementation into generic contracts
- ❌ Do NOT add @_exported imports
- ❌ Do NOT create fake stubs
- ❌ Do NOT remove --skip PDFSidecarExecutable
- ❌ Do NOT work on PDFium installation/discovery (belongs to td-7c0153-01)

---

## Architecture Constraints

- Must respect SwiftPM module boundary: internal declarations are only visible within their own module
- Target dependencies in Package.swift define actual compile-time module relationships
- SwiftPM's build settings (cSettings, cxxSettings, swiftSettings, linkerSettings) are target-level, supporting isolation of PDF/native linker state at the correct target boundary
- Must not create dependency cycles
- Must not create tier violations (Tier 1 → Tier 2 → Tier 3 direction only)

---

## Proposed Solution

### Option 1: Extract LayoutEngineContracts (Recommended)

Create new Tier-safe contract target:
```
LayoutEngineContracts
  - Contains portable value/contract definitions only
  - Request/response shapes
  - Schema/version identifiers  
  - Capability descriptors
  - Stable portable layout structs ONLY if they are truly contract API
```

Move implementation to implementation targets:
```
LayoutEngineCapsule (implementation)
  → LayoutEngineContracts (dependency)
  → PDFNative (dependency)
  - Contains LayoutEngineCapsuleWrapper
  - Contains PDF-specific execution

PDFLayoutExtract (implementation)
  → LayoutEngineCapsule (dependency)
  → LayoutEngineContracts (dependency)
  - Contains PDFLayoutExtractWrapper
  - Contains PDFLayoutExtractContract execution logic
```

Update AnigmaPipeline:
```
AnigmaPipeline
  → LayoutEngineContracts (dependency - REPLACES LayoutEngineCapsule)
  - Registry registers contract/capability descriptor, not implementation wrapper
```

**Predicted graph after fix:**
- `BackendReadinessContractTests → AnigmaCore → AnigmaPipeline → LayoutEngineContracts` ✅ (no PDFNative)
- `PDFLayoutExtract → LayoutEngineCapsule → PDFNative` ✅ (isolated)
- `BackendReadinessContractTests` can NO LONGER reach PDFNative ✅

### Option 2: Split PDFLayoutExtractContract

Split into:
1. **Contract descriptor/metadata** (portable) - stays in AnigmaPipeline or new contract target
2. **Executor/wrapper implementation** (PDF-specific) - moves to PDFLayoutExtract or LayoutEngineCapsule

**Problem:** The current `PDFLayoutExtractContract` `execute` method directly calls `LayoutEngineCapsuleWrapper.analyzePDF`. This is implementation, not contract.

### Option 3: Move PDFLayoutExtractContract to LayoutEngineCapsule Target

Move both PDFLayoutExtractContract.swift and its dependencies into LayoutEngineCapsule target. This gives access to internal types but:
- May require adding AnigmaFoundation, AnigmaGovernance, AnigmaJobs dependencies to LayoutEngineCapsule
- Risk of creating cycles if AnigmaPipeline also depends on those

---

## Research Phase

### 1. Capture Current Graph State

```bash
cd anigma
python3 scripts/anigma_package_graph_audit.py snapshot
```

### 2. Confirm Dependency Path

```bash
# Confirm the path exists
python3 scripts/anigma_package_graph_audit.py explain-target AnigmaPipeline
python3 scripts/anigma_package_graph_audit.py explain-target LayoutEngineCapsule
python3 scripts/anigma_package_graph_audit.py explain-target PDFNative
```

### 3. Inspect Ownership and Type Usage

```bash
# Find all references to LayoutEngineCapsule types
rg -n "LayoutEngineCapsule\.|PageLayout|TextSegment|BoundingBox|LayoutEngineConfig|LayoutEngineError|ImageData" anigma/Packages anigma/Package.swift

# Classify files into categories
# portable contract surface:
# layout/PDF implementation:
# PDF native bridge:
# generic pipeline registry:
# test/readiness-only code:
```

### 4. Required Classification Questions

- Which types are portable enough for contract surface?
- Which types are implementation-only and must remain out of AnigmaPipeline?
- Does AnigmaPipeline need to depend on any layout engine target at all?
- Should PDFLayoutExtractContract be split into contract descriptor vs executor implementation?

---

## Implementation Direction (After Research)

### Phase 1: Create LayoutEngineContracts Target

1. Create new target in Package.swift:
   ```swift
   .target(
     name: "LayoutEngineContracts",
     dependencies: [
       "AnigmaPrimitives",
       "FoundationContracts"
     ],
     path: "Packages/LayoutEngineCapsule/Sources/LayoutEngineContracts"
   )
   ```

2. Move portable types to LayoutEngineContracts:
   - Request/response value types
   - Schema identifiers
   - Capability descriptors
   - Portable layout structs (if justified as contract API)

### Phase 2: Split PDFLayoutExtractContract

1. Extract contract metadata (id, schemas, version) to LayoutEngineContracts or AnigmaPipeline
2. Move execution logic (using LayoutEngineCapsule) to PDFLayoutExtract or LayoutEngineCapsule target
3. Use protocol-based abstraction for PDF layout extraction capability

### Phase 3: Update AnigmaPipeline

1. Remove direct dependency on LayoutEngineCapsule
2. Add dependency on LayoutEngineContracts
3. Registry registers contract descriptor (not implementation wrapper)

### Phase 4: Update LayoutEngineCapsule

1. Add dependency on LayoutEngineContracts
2. Keep internal implementation types (PageLayout, TextSegment, etc.) internal
3. Export public contract types from LayoutEngineContracts

### Phase 5: Create/Update PDFLayoutExtract Target

1. Own PDFLayoutExtractWrapper
2. Depend on LayoutEngineCapsule
3. Provide executor implementation outside generic BackendReadiness

---

## Validation Commands

```bash
# Build verification
swift build --target BackendReadinessContractTests

# Test verification  
Scripts/test_backend_readiness.sh BackendReadinessContractTests

# Graph verification
python3 scripts/anigma_package_graph_audit.py snapshot --label post
python3 scripts/anigma_package_graph_audit.py diff --from pre --to post

# Edge verification (must NOT exist after fix)
python3 scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFNative
python3 scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFSidecarNativeShims
python3 scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFSidecarExecutable
python3 scripts/anigma_package_graph_audit.py explain-edge AnigmaPipeline LayoutEngineCapsule

# Governance verification
python3 tools/governance/scripts/validate_tiers.py
python3 scripts/validate_no_cycles.py .build/anigma-package.json
```

---

## Acceptance Criteria

- [ ] `BackendReadinessContractTests ↛ PDFNative` (no reachable path via graph audit)
- [ ] `AnigmaPipeline ↛ LayoutEngineCapsule` if LayoutEngineCapsule still depends on PDFNative (no reachable path via graph audit)
- [ ] PDFLayoutExtractWrapper is not compiled into AnigmaPipeline (verified via target inspection)
- [ ] No internal implementation types made public merely for generic pipeline access (verified via code review)
- [ ] No PDFium/PDFNative path enters generic BackendReadiness (verified via graph audit)
- [ ] Portable contract types, if public, are justified as contract API
- [ ] No new cycles introduced
- [ ] No new tier violations introduced
- [ ] No @_exported imports added
- [ ] No fake stubs created
- [ ] `swift package describe --type json` shows correct architecture

---

## Dependencies

**Blocks:** td-358315-01 (Wait for this architecture repair before implementation)

**Blocked by:** None

**Related TDs:**
- td-358315 - BackendReadiness Test Triage (parent)
- td-7c0153 - PDF Sidecar Native Shim Isolation (Phase 2 complete, NOT blocking)
- td-7c0153-01 - PDFium installation/discovery (separate concern, NOT blocking)

---

## Notes

This is a **graph surgery** problem, not a code patch problem. Patching PDFLayoutExtractWrapper in place may result in a green build while preserving the bad graph:

```
Generic readiness → generic pipeline → layout engine → PDFNative
```

This is exactly the kind of "it compiles but the architecture is lying" problem that Anigma's graph audit is designed to prevent.

**The correct fix is graph surgery first, code patch second.**

---

## Next Action

Run research phase commands to classify types and confirm proposed solution before implementation.
