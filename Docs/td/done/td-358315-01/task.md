# TD-358315-01: Resolve PDFLayoutExtractWrapper compilation errors blocking BackendReadinessContractTests

**TD ID:** td-358315-01  
**Parent TD:** td-358315  
**Priority:** P0  
**Status:** DONE
**Completed:** 2026-05-03  
**Created:** 2026-05-03  
**Unblocked by:** td-358315-02

---

## Problem

**REJECTED APPROACH:** The previous attempt to fix compilation errors by adding PDFLayoutExtractWrapper.swift to AnigmaPipeline is rejected because it preserves/moves PDF/layout implementation **into** the generic AnigmaPipeline target.

**ROOT FINDING:** There is a package graph path that violated architecture constraints:

```
BackendReadinessContractTests 
  → AnigmaCore 
  → AnigmaPipeline 
  → LayoutEngineCapsule 
  → PDFNative
```


---

## Problem

**REJECTED APPROACH:** The previous attempt to fix compilation errors by adding PDFLayoutExtractWrapper.swift to AnigmaPipeline is rejected because it preserves/moves PDF/layout implementation **into** the generic AnigmaPipeline target.

**ROOT FINDING:** There is a package graph path that violated architecture constraints:

```
BackendReadinessContractTests 
  → AnigmaCore 
  → AnigmaPipeline 
  → LayoutEngineCapsule 
  → PDFNative
```

This means generic BackendReadiness **can reach** PDFNative through AnigmaPipeline's dependency on LayoutEngineCapsule. This violates the requirement that generic BackendReadiness must NOT depend on PDFNative, PDFSidecarNativeShims, PDFSidecarExecutable, or PDFium-owned targets.

**Therefore:** td-358315-01 cannot be fixed correctly by editing PDFLayoutExtractWrapper in AnigmaPipeline. The correct prerequisite is the architecture repair defined in **td-358315-02**.

BackendReadinessContractTests **target build is CLEAN** (exit_code=0, warning_count=0), but the **test FAILED** (exit_code=1, warning_count=9) due to compilation errors in `PDFLayoutExtractWrapper.swift`.

**This is NOT related to PDFium linker contamination** (td-7c0153 Phase 2 has architecturally isolated PDFium linkage). These are symptoms of the architectural ownership problem.

**Exact Errors:**
```
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:37:51: error: 'PageLayout' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:21:43: error: cannot find type 'Data' in scope
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:40:59: error: 'LayoutEngineConfig' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:31:44: error: cannot find type 'Data' in scope
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:38:52: error: 'TextSegment' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:39:52: error: 'BoundingBox' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:41:58: error: 'LayoutEngineError' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:32:47: error: type 'LayoutEngineCapsuleWrapper' has no member 'extractText'
```

**Missing Types:**
- `PageLayout`
- `TextSegment`
- `BoundingBox`
- `LayoutEngineConfig`
- `LayoutEngineError`
- `extractText` on `LayoutEngineCapsuleWrapper`
- `Data` (import missing)

---

## Goal

Classify and fix PDFLayoutExtractWrapper ownership/API errors so BackendReadinessContractTests can proceed.

---

## Required First Step

Run graph audit and classify whether PDFLayoutExtractWrapper belongs in:
- PDFLayoutExtract target
- PDFSidecarReadiness lane
- Generic BackendReadiness
- Or should be excluded from generic readiness

**Command:**
```bash
python3 Scripts/anigma_package_graph_audit.py find-owners --file Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift
```

---

## Non-Goals

- Do NOT reintroduce PDFSidecarExecutable into generic BackendReadiness
- Do NOT link PDFium into BackendReadiness
- Do NOT move PDF-specific implementation into generic contracts or AnigmaPipeline

---

## Architecture Constraints

- Do NOT link PDFium into AnigmaFoundation, AnigmaCore, AnigmaPrimitives, or generic BackendReadiness
- Do NOT expose PDFium types in contract modules
- Do NOT create @_exported imports
- Do NOT create fake stubs
- Do NOT make PDFSidecarExecutable part of generic BackendReadiness

---

## Options to Investigate

### Option 1: PDFLayoutExtract Target Dependency
If PDFLayoutExtractWrapper belongs to the PDFLayoutExtract target, ensure:
1. PDFLayoutExtract target is properly defined in Package.swift
2. PDFLayoutExtract is a dependency of the target that contains PDFLayoutExtractWrapper.swift
3. All required types (PageLayout, TextSegment, etc.) are accessible from PDFLayoutExtract

### Option 2: LayoutEngineCapsule Contract
If the types are from LayoutEngineCapsule, ensure:
1. LayoutEngineCapsuleContract or similar contract module exports these types
2. PDFLayoutExtractWrapper.swift properly imports the contract
3. The contract is a dependency of AnigmaPipeline or AnigmaCore

### Option 3: Data Type Import
The `Data` type errors suggest missing `import Foundation` or `import Data` - check if this is a Swift Foundation type that needs explicit import.

### Option 4: Wrong Ownership
PDFLayoutExtractWrapper.swift may be in the wrong target. It should potentially be in:
- A PDF-specific target (not generic BackendReadiness)
- Or a target that has PDFLayoutExtract as a dependency

---

## Acceptance Criteria

- [ ] PDFLayoutExtractWrapper.swift compiles without errors
- [ ] BackendReadinessContractTests target build is CLEAN
- [ ] BackendReadinessContractTests test passes (or fails only on other, unrelated issues)
- [ ] PDFLayoutExtractWrapper is in the correct target with correct dependencies
- [ ] All referenced types (PageLayout, TextSegment, BoundingBox, LayoutEngineConfig, LayoutEngineError) are accessible
- [ ] No PDFium linkage in generic BackendReadiness
- [ ] No PDFium types leak into contract modules
- [ ] No new dependency cycles introduced
- [ ] No new tier violations introduced

---

## Files Likely Affected

- `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift` - Fix ownership/imports
- `anigma/Package.swift` - Potentially update target dependencies
- Possibly: `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/PDFLayoutExtract/` targets
- Possibly: `anigma/Packages/PDFLayoutExtract/` if it exists

---

## Validation Commands

```bash
# Verify PDFLayoutExtractWrapper compiles
swift build --target AnigmaPipeline  # Or whichever target contains PDFLayoutExtractWrapper.swift

# Verify BackendReadinessContractTests passes
swift test BackendReadinessContractTests  # Should pass or fail on different errors

# Verify no PDFium linkage in BackendReadiness
swift build --target BackendReadinessContractTests  # Should be CLEAN, no PDFium errors

# Verify reachability constraints still hold
python3 Scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFNative  # Should not exist

# Verify no new violations
python3 tools/governance/scripts/validate_tiers.py  # No new violations
python3 tools/governance/scripts/validate_no_cycles.py .build/anigma-package.json  # No cycles
```

---

## Dependencies

**Blocks:** td-358315 (BackendReadiness Test Triage)

**Blocked by:** td-358315-02 (Architecture repair: Extract portable layout/PDF contract surface to break AnigmaPipeline → LayoutEngineCapsule → PDFNative path)

**Related TDs:**
- td-358315-02 - Architecture blocker (MUST complete before td-358315-01 implementation)
- td-7c0153 - Phase 2 architecture accepted (PDFium isolation complete, NOT blocking this TD)
- td-7c0153-01 - PDFium installation/discovery (separate concern, NOT blocking)

---

## Notes

This TD should be **prioritized over td-7c0153-01** because:
1. BackendReadinessContractTests is blocked by PDFLayoutExtractWrapper errors
2. The PDFium environment problem (td-7c0153-01) belongs to the sidecar readiness lane
3. Generic BackendReadiness should NOT depend on sidecar readiness unless explicitly required
4. PDFLayoutExtractWrapper errors are a separate ownership/API issue, not related to PDFium linker isolation

The PDFium environment problem from td-7c0153-01 should **not** block generic BackendReadiness unless the parent task (td-358315) explicitly requires sidecar readiness to pass.
