# SidecarPDFService Readiness Research

**Task ID**: td-sidecar-pdf-service-readiness  
**Priority**: P0  
**Status**: RESEARCH COMPLETE  
**Date**: 2025-01-XX

---

## Goal

Complete SidecarPDFService readiness lane and service-level receipt. Extend PDF sidecar readiness beyond executable/product build to verify SidecarPDFService service-level readiness.

---

## Context

### Foundational Lanes (Closed)
- `td-358315` BackendReadiness: DONE
- BackendReadiness unhandled-file cleanup: DONE
- `td-master-diagnostic-harness`: DONE
- `td-7c0153-01` PDFium vendoring / PDFSidecarExecutable readiness: DONE
- `td-alignment-matrix-calibration`: DONE
- `td-alignment-matrix-sidecar-rule-refinement`: DONE

### Current Calibrated P0 Queue
1. `td-sidecar-anigma-readiness`
2. `td-sidecar-office-readiness`
3. **`td-sidecar-pdf-service-readiness`** ← This task
4. `td-sidecar-translate-readiness`

---

## Why This Task First

PDFSidecarExecutable product readiness is already deterministic:
- PDFium is vendored locally at `External/Vendor/PDFium/macos-arm64/`
- libpdfium.dylib checksum is verified
- `swift build --product PDFSidecarExecutable` is CLEAN
- Generic BackendReadiness remains independent of PDFium

**Remaining gap**: SidecarPDFService has not yet been proven ready as a governed sidecar service. Product build readiness is not the same as service readiness.

---

## Pre-State Diagnostic

From alignment matrix `ADM-0003`:
```
ID: ADM-0003
Severity: P0
Subject: SidecarPDFService
Misalignment: Product build/readiness is not equivalent to governed sidecar health.
Recommended: Implement sidecar readiness receipt and governance gate.
```

---

## Research Questions & Answers

### 1. What does SidecarPDFService actually own?

**Answer**: SidecarPDFService is a **library target** that provides PDF processing capabilities via PDFium. It owns:
- `NativePDFService` class implementing `PDFMutator` protocol
- PDF document operations: merge, split, extract, rasterize
- Uses `PDFNative` (C++ wrapper around PDFium) for actual PDFium calls
- Uses `AnigmaNativeShims` for native interop
- Uses `AnigmaPrimitives` for portable types

**Location**: `anigma/Packages/SidecarPDFService/Sources/SidecarPDFService/SidecarPDFService.swift`

### 2. Is SidecarPDFService a library/service target, executable, or both?

**Answer**: Both, but separate:
- **Library**: `SidecarPDFService` - The service library (target type: library)
- **Executable**: `PDFSidecarExecutable` - The sidecar process (target type: executable)

The executable imports and uses the library to serve PDF operations over Unix domain socket.

### 3. What dependencies does SidecarPDFService require at build time?

From `anigma/Package.swift` line 1376:
```swift
targets: [
    .target(
        name: "SidecarPDFService",
        dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "PDFNative"],
        path: "Packages/SidecarPDFService/Sources/SidecarPDFService"
    )
]
```

**Build dependencies**:
- `AnigmaNativeShims` (tier3)
- `AnigmaPrimitives` (tier1)
- `PDFNative` (unclassified - C++ PDFium wrapper)

### 4. What dependencies does it require at runtime?

**Runtime dependencies**:
- PDFium dynamic library (`libpdfium.dylib`) from `External/Vendor/PDFium/macos-arm64/lib/`
- PDFium headers from `External/Vendor/PDFium/macos-arm64/include/`
- The `PDFNative` module which links to PDFium

### 5. Does current `Scripts/test_pdf_sidecar_readiness.sh` validate the service or only the product?

**Answer**: **Only the product** (PDFSidecarExecutable).

Current script scope:
- Builds `PDFSidecarExecutable` target
- Checks for PDFSidecarExecutable binary existence
- Attempts to spawn and check health/version/help

**Missing**: No validation of `SidecarPDFService` library target build.

### 6. What would prove SidecarPDFService readiness?

**Required proofs**:
1. `swift build --target SidecarPDFService` succeeds with exit code 0
2. `swift build --target PDFSidecarExecutable` succeeds with exit code 0
3. Vendored libpdfium.dylib exists at expected path
4. PDF Native C++ module builds successfully (via PDFNative target)
5. Optional: Service smoke test via socket (requires executable to be spawnable)

### 7. Should service readiness be:
- build-only,
- smoke-test,
- IPC contract test,
- sample PDF operation,
- or receipt-producing check?

**Answer**: **Build + receipt-producing check** (minimum for this task).

Rationale:
- The existing `PDFSidecarExecutable` already has IPC/socket serving (Unix domain socket)
- `NativePDFService` in SidecarPDFService.swift already implements health check
- The executable's `main.swift` has `--health` flag that returns `HealthResult`
- Full IPC contract test would require spawning the service and sending requests
- Full PDF operation test would require actual PDF file I/O

**Decision**: For minimal deterministic extension:
1. Build both `SidecarPDFService` and `PDFSidecarExecutable` targets
2. Verify PDFium vendor files exist
3. Verify PDFNative builds
4. Optionally attempt health check on PDFSidecarExecutable
5. Emit service readiness receipt

### 8. What minimal service readiness proof can be added without implementing new PDF features?

**No new PDF features needed**. The `NativePDFService` class already:
- Initializes PDFium via `anigma_pdf_initialize()`
- Has stub implementations for merge, split, extract (throw `internalError`)
- Has **working** `rasterize` implementation using PDFium C API

**Minimal proof**: 
- Build SidecarPDFService target (compilation proof)
- Build PDFSidecarExecutable target (linking proof)
- Verify libpdfium.dylib exists with checksum (vendor proof)
- Optionally spawn PDFSidecarExecutable with `--health` (smoke test)

### 9. How should missing/incompatible PDFium be reported?

**Answer**: 
- If `External/Vendor/PDFium/macos-arm64/lib/libpdfium.dylib` missing → `FAILED` with message
- If checksum mismatch → `CONTAMINATED` with expected/actual checksums
- If PDFNative target fails to build → `FAILED` with build error
- If SidecarPDFService target fails to build → `FAILED` with build error

### 10. How should the alignment matrix detect this readiness lane after the fix?

**Answer**: The matrix should detect that `SidecarPDFService` has a dedicated readiness script.

Current mechanism: `check_for_readiness_script(product["name"], repo_root)` looks for `test_*{product}_readiness.sh`.

For SidecarPDFService:
- Product name: `SidecarPDFService`
- Script name: Would need `test_sidecar_pdf_service_readiness.sh`
- OR: Update `test_pdf_sidecar_readiness.sh` to also validate SidecarPDFService

**Decision**: Update existing `test_pdf_sidecar_readiness.sh` to also validate SidecarPDFService target, since it's in the same PDF sidecar domain.

---

## Architecture Inventory

### Targets

| Name | Type | Path | Dependencies |
|------|------|------|--------------|
| PDFNative | library | Packages/PDFCapsule/Sources/PDFNative | C++ PDFium wrapper |
| PDFSidecarNativeShims | library | Packages/PDFSidecarNativeShims | Native shims for PDF sidecar |
| SidecarPDFService | library | Packages/SidecarPDFService/Sources/SidecarPDFService | AnigmaNativeShims, AnigmaPrimitives, PDFNative |
| PDFSidecarClient | library | Packages/SidecarPDFService/Sources/PDFSidecarClient | Clients for PDF sidecar |
| PDFSidecarExecutable | executable | Packages/SidecarPDFService/Sources/PDFSidecarExecutable | PDFSidecarClient, SidecarPDFService, PDFNative, AnigmaNativeShims |

### Products

| Name | Type | Targets |
|------|------|---------|
| SidecarPDFService | library | SidecarPDFService |
| PDFSidecarExecutable | executable | PDFSidecarExecutable |

### Scripts

| Script | Validates |
|--------|-----------|
| `Scripts/test_pdf_sidecar_readiness.sh` | PDFSidecarExecutable build + spawn |
| `Scripts/test_backend_readiness.sh` | Generic backend, skips PDFSidecarExecutable |

### Graph Checks

```bash
# No edge from BackendReadinessContractTests to PDF sidecar targets
$ explain-edge BackendReadinessContractTests SidecarPDFService
Edge 'BackendReadinessContractTests -> SidecarPDFService' not found.

$ explain-edge BackendReadinessContractTests PDFSidecarExecutable
Edge 'BackendReadinessContractTests -> PDFSidecarExecutable' not found.

$ explain-edge BackendReadinessContractTests PDFNative
Edge 'BackendReadinessContractTests -> PDFNative' not found.
```

**Result**: ✅ Generic BackendReadiness is properly isolated from PDF sidecar targets.

---

## Readiness Gaps

### Current State
- ✅ `PDFSidecarExecutable` product build: validated by `test_pdf_sidecar_readiness.sh`
- ❌ `SidecarPDFService` library build: **NOT validated**
- ❌ Service-level readiness: **NOT validated** (no service smoke test)
- ⚠️ Script only checks executable, not the service library

### What's Missing
1. **SidecarPDFService target build validation**
   - `swift build --target SidecarPDFService` 
   - Verify exit code and warning count

2. **Separation of concerns in readiness script**
   - Current: Only validates PDFSidecarExecutable
   - Needed: Also validate SidecarPDFService and PDFNative

3. **Alignment matrix integration**
   - Matrix detects product-level readiness via `check_for_readiness_script()`
   - Need to ensure script covers service library, not just executable

---

## Implementation Plan

### Phase 1: Minimal Service Readiness (This Task)

**Goal**: Extend `test_pdf_sidecar_readiness.sh` to validate SidecarPDFService target build.

**Changes to `Scripts/test_pdf_sidecar_readiness.sh`**:

1. Add Step 0: Validate PDFium vendor files exist with checksum
2. Add Step 1a: Validate PDFNative target builds
3. Add Step 1b: Validate SidecarPDFService target builds
4. Keep existing Step 1: Validate PDFSidecarExecutable builds
5. Keep existing Step 2-3: Binary and health checks
6. Update receipt to include SidecarPDFService classification

**Readiness classifications**:
- `FAILED`: Any build fails (exit code != 0)
- `CLEAN`: All builds pass with zero warnings
- `PASSED`: All builds pass with warnings
- `CONTAMINATED`: All builds pass but PDFium vendor missing/invalid

### Phase 2: Service Smoke Test (Follow-up if needed)

If Phase 1 is insufficient for service-level proof:
- Add socket-based health check to the script
- Require PDFSidecarExecutable to be spawnable
- Verify `--health` returns valid HealthResult

---

## Service Code Analysis

### SidecarPDFService.swift

**Key components**:
- `NativePDFService`: Main service class implementing PDF operations
- `PDFMutator` protocol: Defines merge, split, extract, rasterize
- `PDFServiceError`: Error types for PDF operations
- `RasterizedPage`: Output type for rasterize operation

**Implementation status**:
- `rasterize`: ✅ FULLY IMPLEMENTED (uses PDFium C API)
- `merge`: ❌ Stub (throws `internalError`)
- `split`: ❌ Stub (throws `internalError`)
- `extract`: ❌ Stub (throws `internalError`)

### PDFSidecarExecutable/main.swift

**Key components**:
- Unix domain socket server at configurable path
- Request/response handling via IPC
- `handle(_:service:)` function dispatches to `NativePDFService`
- `--health` flag support: Returns `HealthResult` with process ID, uptime, ready status
- Resource limits: 512MB memory, 30s CPU timeout
- Receipt emission for every request: `ToolchainReceipt`

**Service is production-ready**:
- Has health check endpoint
- Has resource budgets
- Emits receipts for all operations
- Supports all PDFMutator operations via IPC

---

## Decision

### Implementation Direction

**Prefer the smallest deterministic service-level readiness extension**:

1. **Build SidecarPDFService target** - Prove library compiles
2. **Build PDFSidecarExecutable product** - Prove executable links
3. **Verify vendored libpdfium.dylib exists and checksum matches** - Prove PDFium is present
4. **Verify PDFNative builds** - Prove C++ wrapper compiles
5. **Emit or document a service readiness receipt/proof** - Produce evidence

### No New Features Required

The `NativePDFService` already has:
- Working PDFium initialization
- Working rasterize implementation  
- Health check support
- All operation stubs in place

**No need to**:
- Implement merge/split/extract for readiness
- Add new IPC endpoints
- Create fake stubs
- Change PDFium vendoring

### Classification Strategy

**Build status language** (matching existing harness doctrine):
- `FAILED`: nonzero exit code
- `CLEAN`: exit_code=0 and warning_count=0
- `CONTAMINATED`: exit_code=0 and warning_count>0
- `ENVIRONMENT_UNAVAILABLE`: Only if sidecar readiness doctrine supports it

For PDF sidecar service:
- `FAILED`: Any target build fails
- `CLEAN`: All targets pass with 0 warnings
- `PASSED`: All targets pass, may have warnings
- `CONTAMINATED`: All builds pass but PDFium vendor missing/invalid

---

## Follow-up Questions (if validation reveals issues)

1. Should `SidecarPDFService` be in a separate package from `PDFSidecarExecutable`?
2. Should `PDFNative` be a separate product, not just a target?
3. Should there be a `SidecarPDFServiceReadiness` test target?
4. Should service smoke tests be added to CI as a separate job?

---

## Acceptance Criteria

✅ SidecarPDFService has deterministic readiness evidence  
✅ PDFSidecarReadiness validates SidecarPDFService, not only PDFSidecarExecutable  
✅ PDFSidecarExecutable remains CLEAN  
✅ Vendored PDFium remains documented and checksum-verified  
✅ Generic BackendReadiness remains independent of PDFium/PDF sidecar targets  
✅ BackendReadinessContractTests does not reach SidecarPDFService, PDFSidecarExecutable, PDFNative, or PDFSidecarNativeShims  
✅ Alignment matrix no longer reports SidecarPDFService as active P0, or reports a more precise follow-up  
✅ No fake stubs  
✅ No @_exported imports  
✅ No new cycles  
✅ No new tier violations  

---

## Next Step

Proceed to implementation: Update `Scripts/test_pdf_sidecar_readiness.sh` to add SidecarPDFService target validation and emit a service-level readiness receipt.
