# TD-7c0153-01: Make PDFSidecarExecutable product readiness environment-aware

**TD ID:** td-7c0153-01  
**Parent TD:** td-7c0153  
**Priority:** P0-adjacent  
**Status:** PENDING  
**Created:** 2026-05-03

---

## Problem

PDFSidecarExecutable target builds **CLEAN** (exit_code=0, warning_count=0), but the **product build FAILED** (exit_code=1, warning_count=1) because PDFium is not installed or not discoverable.

The graph/native-shim isolation from td-7c0153 Phase 2 is **correct** - PDF/PDFium linker ownership is properly isolated to PDF-owned targets. However, sidecar readiness cannot close until PDFium availability is handled deterministically.

**Current State:**
- PDFSidecarNativeShims target: CONTAMINATED (exit_code=0, warning_count=6)
- PDFNative target: CLEAN (exit_code=0, warning_count=0)
- PDFSidecarExecutable target: CLEAN (exit_code=0, warning_count=0)
- PDFSidecarExecutable product: FAILED (exit_code=1, warning_count=1, missing PDFium)

---

## Goal

Make PDFSidecarExecutable product readiness **deterministic across environments**.

---

## Options to Evaluate

### Option 1: PDFium System Library Target
If PDFium is expected to be host-installed (e.g., via package manager like `brew install pdfium` or system package), create a SwiftPM system library target:
```swift
.systemLibrary(
    name: "PDFium",
    pkgConfig: "pdfium",
    providers: [.brew(["pdfium"])]
)
```
This is the **recommended approach** if PDFium is an external/system-installed dependency, as SwiftPM system library targets are specifically designed for adapting host-installed libraries.

### Option 2: Explicit PDFium Discovery
Add explicit PDFium discovery checks to `Scripts/test_pdf_sidecar_readiness.sh`:
- Check for PDFium library at expected paths (`/usr/local/lib/libpdfium.dylib`, `/usr/lib/libpdfium.so`, etc.)
- Check for PDFium headers at expected paths
- Provide clear error messages about what's missing and how to install

### Option 3: Optional PDFium Classification
If PDFium is **optional** for local development (e.g., only required for PDF rendering but not for all Anigma functionality), classify missing PDFium as **ENVIRONMENT_UNAVAILABLE** or **SKIPPED** in the sidecar lane instead of ambiguous FAILED.

### Option 4: Required PDFium with Documentation
If PDFium is **required** for sidecar readiness, document installation/discovery requirements and fail clearly with actionable error messages.

### Option 5: Ensure BackendReadiness Independence
Ensure generic BackendReadiness remains completely independent of PDFium availability. The `--skip PDFSidecarExecutable` flag in `test_backend_readiness.sh` should remain until PDFSidecarReadiness is stable.

---

## Acceptance Criteria

- [ ] PDFSidecarReadiness clearly distinguishes between classification states:
  - **CLEAN** - All checks pass, PDFium available
  - **CONTAMINATED** - Build succeeds with warnings
  - **FAILED** - Build fails for reasons other than missing PDFium
  - **ENVIRONMENT_UNAVAILABLE** / **SKIPPED** - PDFium not installed (if adopted)
- [ ] PDFSidecarExecutable product build **passes** when PDFium is available
- [ ] Missing PDFium produces an **explicit, deterministic** readiness classification
- [ ] Generic BackendReadiness remains **independent** of PDFium availability
- [ ] No PDFium types leak into contract modules
- [ ] No new dependency cycles introduced
- [ ] No new tier violations introduced

---

## Architecture Constraints

- Do NOT link PDFium into AnigmaFoundation, AnigmaCore, AnigmaPrimitives, or generic BackendReadiness
- Do NOT expose PDFium types in contract modules
- Do NOT create @_exported imports
- Do NOT create fake stubs
- Do NOT remove the PDFSidecarReadiness lane
- Do NOT remove the `--skip PDFSidecarExecutable` guard until validation proves it is no longer needed

---

## Non-Goals

- Do NOT touch ReceiptSigner, RendererBackend, AnigmaGovernance, or AnigmaPipeline work unless errors directly reference them
- Do NOT broaden Package.swift product exposure
- Do NOT make PDFSidecarExecutable part of generic BackendReadiness

---

## Files Likely Affected

- `Scripts/test_pdf_sidecar_readiness.sh` - Add PDFium discovery checks
- `anigma/Package.swift` - Potentially add system library target for PDFium
- `Docs/proofs/td-7c0153-pdf-sidecar-native-shim-isolation-proof.md` - Update with follow-up results
- `.build/anigma-graph/td-7c0153-phase2-post/` - Updated snapshots after changes

---

## Validation Commands

```bash
# Verify PDFium is not linked into generic targets
swift build --target BackendReadinessContractTests  # Should be CLEAN, no PDFium errors

# Verify PDFSidecarExecutable product builds when PDFium is available
swift build --product PDFSidecarExecutable  # Should be CLEAN when PDFium installed

# Verify reachability constraints
python3 Scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFSidecarExecutable  # Should not exist
python3 Scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFSidecarNativeShims  # Should not exist
python3 Scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFNative  # Should not exist

# Verify no new violations
python3 tools/governance/scripts/validate_tiers.py  # No new violations
python3 tools/governance/scripts/validate_no_cycles.py .build/anigma-package.json  # No cycles
```

---

## Dependencies

**Blocks:** None (this is a follow-up to td-7c0153 Phase 2)

**Blocked by:** None

**Related TDs:**
- td-7c0153 (parent) - Phase 2 architecture accepted, product readiness incomplete
- td-358315 - BackendReadiness, blocked by PDFLayoutExtractWrapper.swift errors (separate issue)

---

## Notes

SwiftPM's `.linkedLibrary("pdfium")` in PDFNative is the correct mechanism for declaring linkage to a system library. However, for external/system-installed dependencies, SwiftPM's system library target model may provide cleaner semantics:

- System library targets declare dependencies on host-installed libraries
- They can specify pkg-config files for discovery
- They can specify package manager providers (brew, apt, etc.)
- They make the external dependency explicit in the package graph

This should be evaluated as part of this TD.
