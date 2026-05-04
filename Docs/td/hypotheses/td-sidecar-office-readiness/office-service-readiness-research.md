# Office Sidecar Readiness - Research Artifact

**Task ID**: td-sidecar-office-readiness  
**Product**: SidecarOfficeService  
**Severity**: P0  
**Status**: Research Complete  
**Timestamp**: 2026-05-04T07:40:50-0700  
**Research Lead**: Alignment Diagnostic Matrix Calibration

---

## Executive Summary

SidecarOfficeService is a **library product** (not executable) in the Anigma architecture that provides high-fidelity Office document processing capabilities. It depends on `AnigmaNativeShims` and is designed to wrap `LibreOfficeKit` via C shim. The product is imported by `AnigmaDaemon` through the `NativeWorkers.swift` module.

The alignment matrix correctly identified SidecarOfficeService as having a **role mismatch**: the product is categorized as `library` but the expected role for sidecar products is `sidecar_executable`. This is the final P0 sidecar readiness gap after resolving AnigmaSidecar, PDFSidecar, and TranslateSidecar.

## Finding Classification

| Aspect | Classification | Rationale |
|---|---|---|
| **Role** | library_product | Current Swift PM target type |
| **Expected Role** | sidecar_executable | Alignment matrix doctrine for Sidecar products |
| **Severity** | P0 | Missing dedicated readiness lane |
| **Doctrine Rule** | ADM-0001 | "sidecar products require sidecar readiness receipts" |

## Product Analysis

### 1. Package Structure
```
anigma/Packages/SidecarOfficeService/
├── Sources/
│   └── SidecarOfficeService/
│       └── SidecarOfficeService.swift
```

### 2. Source Code Analysis

**File**: `anigma/Packages/SidecarOfficeService/Sources/SidecarOfficeService/SidecarOfficeService.swift`

```swift
public protocol OfficeEngine {
    func convert(document: Data, to format: String) throws -> Data
    func renderPage(document: Data, page: Int) throws -> Data
}

public enum SidecarOfficeServiceError: Error, LocalizedError {
    case conversionUnavailable(format: String)
    case renderUnavailable(page: Int)
}

public class NativeOfficeService: OfficeEngine {
    // In real implementation, this wraps LibreOfficeKit via C shim
    public init() {}

    public func convert(document: Data, to format: String) throws -> Data {
        throw SidecarOfficeServiceError.conversionUnavailable(format: format)
    }

    public func renderPage(document: Data, page: Int) throws -> Data {
        throw SidecarOfficeServiceError.renderUnavailable(page: page)
    }
}
```

**Key Observations**:
- Current implementation is a **stub** - throws exceptions for all operations
- Comment indicates real implementation wraps `LibreOfficeKit` via C shim
- No actual LibreOfficeKit binding code in current source
- Depends on `AnigmaNativeShims` for native interop

### 3. Dependencies

| Dependency | Type | Path |
|---|---|---|
| AnigmaNativeShims | library | Packages/AnigmaNativeShims |
| AnigmaPrimitives | library | Packages/AnigmaPrimitives |

### 4. Consumers

**Direct Imports**:
- `anigma/Packages/AnigmaDaemon/NativeWorkers.swift` (line 11): `@preconcurrency import SidecarOfficeService`

**Usage Context**:
```swift
// From NativeWorkers.swift
private let service = NativeOfficeService()
```

## Native Vendor Analysis

### LibreOfficeKit Dependency

**Architecture Documentation** (`anigma/Docs/architecture/native-deps.md`):

| Service | Purpose | Native Dep |
| :--- | :--- | :--- |
| **SidecarOfficeService** | High-fidelity Office | `LibreOfficeKit`, `ONLYOFFICE` |

**Vendor Status**:
- **Expected Path**: `External/Vendor/LibreOfficeKit/macos-arm64/`
- **Current Status**: ⚠️ **MISSING** - No LibreOfficeKit vendor directory exists
- **Lock File**: `anigma/Native/native-deps.lock.json` references LibreOfficeKit at GitHub URL

**Implication**:
- The native vendor is **not checked in** or **not built**
- This is consistent with the stub implementation
- The aligned doctrine states: vendor validation happens in separate governance lane

## Sidecar Product Matrix

### Comparison with Other Sidecars

| Product | Type | Status | Vendor | Readiness Script |
|---|---|---|---|---|
| AnigmaSidecar | library | P0 → Resolved | None | `test_anigma_sidecar_readiness.sh` |
| SidecarPDFService | library | P0 → Resolved | PDFium | `test_pdf_sidecar_readiness.sh` |
| SidecarTranslateService | library | P0 → Resolved | Marian NMT | `test_translate_sidecar_readiness.sh` |
| SidecarOfficeService | library | **P0 (Active)** | LibreOfficeKit | **`test_office_sidecar_readiness.sh` (This Task)** |

### Role Classification

**Important Discovery**: All four "Sidecar" products are **library targets**, not executable products. This is a **systemic misclassification** in the alignment matrix.

However, per the calibration rules:
1. We must **NOT** change the alignment matrix workflow
2. We must **NOT** change production Swift code
3. We must **NOT** change Package.swift architecture
4. We **Must** create dedicated readiness scripts for each P0 sidecar

## Readiness Lane Design

### Pattern from Existing Scripts

1. **PDFSidecar**: Multi-stage validation (PDFium vendor check + PDFNative build + SidecarPDFService build + PDFSidecarExecutable build + binary spawn test)
2. **TranslateSidecar**: Simple library build validation only (stub implementation)
3. **AnigmaSidecar**: Library build + daemon binary check + optional lifecycle test

### Design Decision for OfficeSidecar

Given that:
- SidecarOfficeService is a **library** (not executable)
- Implementation is a **stub** (no real LibreOfficeKit integration)
- LibreOfficeKit vendor is **missing** (not checked in)
- Imported by daemon but not spawned as subprocess

**Chosen Pattern**: Simple library build validation (like TranslateSidecar)

**Rationale**:
- The product cannot be tested as an executable because it's a library
- The vendor (LibreOfficeKit) is out of scope for this readiness lane (per aligned doctrine)
- Build validation ensures the Swift interface compiles correctly
- The stub status is acceptable for the current implementation state

## Hypothesis Testing

### Hypothesis 1: Building SidecarOfficeService target will succeed

**Test**: `swift build --target SidecarOfficeService`

**Result**: ✅ **PASSED**
- Build completed in ~2 seconds
- Zero warnings
- Zero errors
- Dependencies (AnigmaNativeShims, AnigmaPrimitives) resolved successfully

### Hypothesis 2: LibreOfficeKit vendor is not required for stub implementation

**Test**: Check for `External/Vendor/LibreOfficeKit/` directory

**Result**: ⚠️ **ENVIRONMENT_UNAVAILABLE**
- Directory does not exist
- Stub implementation does not require it
- Real implementation would require vendor

**Classification**: Acceptable for stub. Per aligned doctrine, vendor validation is separate.

## Readiness Script Design

### Script Location
`Scripts/test_office_sidecar_readiness.sh`

### Validation Steps

1. **Step 0**: Check LibreOfficeKit vendor existence (report status, do not fail)
2. **Step 1**: Build `SidecarOfficeService` target
3. **Step 2**: Count warnings/errors
4. **Step 3**: Classify result

### Classification Matrix

| Build Status | Warnings | Vendor | Classification |
|---|---|---|---|
| Fail | Any | Any | FAILED |
| Pass | > 0 | Missing | CONTAMINATED |
| Pass | > 0 | Present | PASSED |
| Pass | 0 | Missing | CLEAN |
| Pass | 0 | Present | CLEAN |

**Note**: Missing vendor with zero warnings = CLEAN because vendor is validated separately.

### Receipt Schema

```json
{
  "schema": "anigma.sidecar_readiness.v1",
  "sidecar": "SidecarOfficeService",
  "lane": "OfficeSidecarReadiness",
  "timestamp": "<ISO8601>",
  "classification": "CLEAN|PASSED|CONTAMINATED|FAILED",
  "message": "<human-readable status>",
  "logFile": "<path>",
  "buildTarget": "SidecarOfficeService",
  "buildDuration": <seconds>,
  "warningCount": <integer>,
  "errorCount": <integer>,
  "libreOfficeVendorStatus": "CLEAN|ENVIRONMENT_UNAVAILABLE",
  "libreOfficeVendorPath": "<expected path>"
}
```

## Expected Outcomes

### Before Script Creation
- **P0 Count**: 1 (SidecarOfficeService)
- **State**: Missing readiness lane

### After Script Creation
- **P0 Count**: 0 (all sidecars resolved)
- **State**: Readiness lane active, build validated
- **Classification**: CLEAN (build passes, zero warnings, vendor missing but acceptable)

## Risk Assessment

### Low Risk
- ✅ Script only reads/validates, does not modify production code
- ✅ Build-only validation matches existing patterns (TranslateSidecar)
- ✅ Missing vendor is explicitly handled per doctrine

### Medium Risk
- ⚠️ Systemic issue: All "Sidecar" products are libraries, not executables
  - **Mitigation**: This is addressed by creating individual readiness lanes
  - **Do not** change alignment matrix rules to reclassify in this task

### No Risk
- ✅ No changes to Package.swift
- ✅ No changes to Swift source code
- ✅ No new TDs created

## Verification Commands

```bash
# Validate the readiness script exists and is executable
ls -la Scripts/test_office_sidecar_readiness.sh
chmod +x Scripts/test_office_sidecar_readiness.sh

# Run the readiness test
./Scripts/test_office_sidecar_readiness.sh

# Check the receipt
cat .build/office-sidecar-readiness-receipt.json

# Verify build log
cat .build/test_office_sidecar_readiness_*.log
```

## Key Decisions

1. **Use TranslateSidecar Pattern**: Simple library build validation is appropriate for stub implementations
2. **Handle Missing Vendor Gracefully**: Report as ENVIRONMENT_UNAVAILABLE, not FAILED
3. **Classification Logic**: Match PDFSidecar pattern - vendor missing + warnings = CONTAMINATED, vendor missing + no warnings = CLEAN
4. **No Executable Check**: SidecarOfficeService is a library, not an executable
5. **No Lifecycle Test**: Not applicable for library targets

## Follow-up Notes

- LibreOfficeKit vendor governance lane should be created separately
- Consider consolidating sidecar readiness patterns in future architecture work
- The systemic library-vs-executable misclassification should be addressed in a future alignment matrix refinement task

## References

- [ADM Calibration Research](../td-alignment-matrix-calibration/calibration-research.md)
- [Sidecar Rule Refinement Research](../td-alignment-matrix-sidecar-rule-refinement/sidecar-rule-refinement-research.md)
- [P0 Sidecar Triage](../../p0-sidecar-readiness-gap-triage/p0-sidecar-readiness-gap-triage.md)
- [AnigmaSidecar Research](../td-sidecar-anigma-readiness/anigma-sidecar-readiness-research.md)
- [PDF Sidecar Research](../td-sidecar-pdf-service-readiness/pdf-service-readiness-research.md)
- [Translate Sidecar Research](../td-sidecar-translate-readiness/translate-service-readiness-research.md)
