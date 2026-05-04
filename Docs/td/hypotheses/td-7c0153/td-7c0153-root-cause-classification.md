# TD-7c0153: Root Cause Classification - PDFSidecarExecutable Architecture

**TD ID:** td-7c0153  
**Status:** ROOT CAUSE CLASSIFICATION (Research Phase)  
**Severity:** BLOCKER (blocks td-358315 BackendReadiness direct test execution)  
**Created:** 2026-05-03  
**Classification Date:** 2026-05-03  

---

## Executive Summary

**Root Cause Classification: OPTION C + OPTION A** (Mixed Cause)

1. **Overbroad test script** (IMMEDIATE ISSUE - ALREADY PARTIALLY FIXED): `swift test` without `--skip PDFSidecarExecutable` attempts to build the PDF sidecar executable as part of the test suite.

2. **Architecture modeling gap** (STRUCTURAL ISSUE - REQUIRESD IMPLEMENTATION): PDFSidecarExecutable is not properly modeled as a daemon-spawnable sidecar subprocess. It's just an executable target without proper governance isolation.

**Correction from initial hypothesis:** There is NO directed target dependency path from BackendReadinessContractTests to PDFSidecarExecutable. The two share `AnigmaNativeShims` as a common dependency, but PDFSidecarExecutable and PDFNative are NOT reachable from BackendReadinessContractTests.

---

## Evidence Commands and Findings

### Command 1: Explain BackendReadinessContractTests
```bash
python3 Scripts/anigma_package_graph_audit.py explain-target BackendReadinessContractTests
```
**Finding:**
- Type: test
- Dependencies: AnigmaCore [tier2]
- Reachable from: 30 targets
- **PDFSidecarExecutable in reachable set? NO**
- **PDFNative in reachable set? NO**
- **AnigmaNativeShims in reachable set? YES**

### Command 2: Explain PDFSidecarExecutable
```bash
python3 Scripts/anigma_package_graph_audit.py explain-target PDFSidecarExecutable
```
**Finding:**
- Type: executable
- Dependencies: PDFSidecarClient, SidecarPDFService, PDFNative, AnigmaNativeShims
- Path: Packages/SidecarPDFService/Sources/PDFSidecarExecutable
- Reachable from: 5 targets (AnigmaNativeShims, AnigmaPrimitives, PDFNative, PDFSidecarClient, SidecarPDFService)

### Command 3: Explain Edge (Both Directions)
```bash
python3 Scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFSidecarExecutable
python3 Scripts/anigma_package_graph_audit.py explain-edge PDFSidecarExecutable BackendReadinessContractTests
```
**Finding:** Both edge queries return "not found" - confirming **NO DIRECTED REACHABILITY** between these targets.

### Command 4: Why Builds PDFSidecarExecutable
```bash
python3 Scripts/anigma_package_graph_audit.py why-builds PDFSidecarExecutable
```
**Finding:**
- Direct dependents: 0
- All dependents: 0
- Reachable from: AnigmaNativeShims, AnigmaPrimitives, PDFNative, PDFSidecarClient, SidecarPDFService

## Package.swift Evidence

### BackendReadinessContractTests Target
```swift
.testTarget(
    name: "BackendReadinessContractTests",
    dependencies: ["AnigmaCore"],
    path: "Packages/AnigmaCore/Tests/BackendReadinessTests/ContractTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
)
```
- Depends ONLY on AnigmaCore
- Does NOT directly or transitively depend on PDFNative or PDFSidecarExecutable

### PDFSidecarExecutable Target
```swift
.target(
    name: "PDFSidecarExecutable",
    dependencies: ["PDFSidecarClient", "SidecarPDFService", "PDFNative", "AnigmaNativeShims"],
    path: "Packages/SidecarPDFService/Sources/PDFSidecarExecutable"
),
```
- Direct dependencies: PDFSidecarClient, SidecarPDFService, PDFNative, AnigmaNativeShims
- **PDFNative is the PDFium-specific target**

### PDFNative Target
```swift
.target(
    name: "PDFNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/PDFCapsule/Sources/PDFNative",
    cxxSettings: [.headerSearchPath("../../../../Vendor/include")],
    linkerSettings: [.linkedLibrary("pdfium")] + vendorLinkerSettings
),
```
- **Carries `.linkedLibrary("pdfium")`** - This is the PDFium linkage point
- Also carries `vendorLinkerSettings` which adds `-L{VENDOR_LIB_PATH}`

### AnigmaNativeShims Target
```swift
.target(
    name: "AnigmaNativeShims",
    path: "Packages/AnigmaNativeShims",
    cSettings: [...],
    cxxSettings: [...],
    linkerSettings: vendorLinkerSettings  // <-- Vendor lib search path
),
```
- **Carries `vendorLinkerSettings`** which adds `-L{VENDOR_LIB_PATH}`
- Does NOT directly link pdfium
- Is a dependency of BOTH BackendReadinessContractTests (transitively) and PDFSidecarExecutable (directly)

### Test Script Evidence (Scripts/test_backend_readiness.sh)
```bash
# Line 29: Build the test target and its dependencies
swift build --target "$TEST_FILTER"

# Line 31: Run tests with skip for PDFSidecarExecutable
swift test --filter "$TEST_FILTER" --skip PDFSidecarExecutable
```

**Finding:** The `swift build --target BackendReadinessContractTests` command builds BackendReadinessContractTests AND all its transitive dependencies. However, since PDFNative and PDFSidecarExecutable are NOT in the transitive dependency chain, this should NOT build them.

**However:** If `swift test` is run without a specific target filter, it may attempt to build all test targets in the package, which could include tests that depend on PDF-sidecar related modules.

---

## Root Cause Classification

### Option A: Target/Product Reachability Leak
**Classification: PARTIALLY TRUE**
- BackendReadinessContractTests does NOT have a directed path to PDFSidecarExecutable
- However, PDFSidecarExecutable is an executable product in the same package
- Test runner may attempt to build all executables unless explicitly skipped

### Option B: Shared Native Shim Contamination
**Classification: TRUE**
- AnigmaNativeShims carries `vendorLinkerSettings` (search path for Vendor/lib)
- PDFNative carries `.linkedLibrary("pdfium") + vendorLinkerSettings`
- AnigmaNativeShims is a transitive dependency of BackendReadinessContractTests
- **Contamination:** BackendReadiness tests get the vendor library search path, and when combined with other targets that link pdfium, the linker looks for pdfium

**But:** This contamination alone shouldn't cause a linker error unless pdfium is actually being linked.

### Option C: Overbroad Test Script
**Classification: TRUE (Already partly fixed)**
- The test script adds `--skip PDFSidecarExecutable` to the `swift test` command
- This addresses the immediate build failure
- **But:** This is a workaround, not proper architecture

### Option D: Mixed Cause
**Classification: CONFIRMED**
This is a combination of:
1. **Option C** (immediate): Overbroad test script building too many products - PARTIALLY FIXED
2. **Option A** (structural): PDFSidecarExecutable needs proper lane separation as daemon-spawnable sidecar

---

## Refined Hypothesis

### The Real Problem

PDFSidecarExecutable is **not currently modeled as a daemon-spawnable sidecar subprocess**. It's just an executable target alongside other Anigma executables. This means:

1. It appears in the same build context as other executables
2. Test runners may attempt to build it unless explicitly skipped
3. There's no governance boundary preventing generic readiness lanes from depending on sidecar-specific infrastructure

### What "Daemon-Spawnable Governed Sidecar Subprocess" Means

- **Daemon-spawnable:** The executable is launched by a daemon/process manager, not directly by user code
- **Governed:** The sidecar has explicit governance: lifecycle management, health checks, readiness validation
- **Sidecar:** It's a companion process that provides specialized capabilities (PDF rendering) to a main process
- **Subprocess:** It runs in its own process space, isolated from the main Anigma process

### Current State vs Desired State

| Aspect | Current | Desired |
|--------|---------|---------|
| Modeling | Regular executable target | Daemon-spawnable sidecar target |
| Governance | None | Explicit sidecar governance (health, readiness, lifecycle) |
| Isolation | Target in same package | Separate governance lane |
| Test validation | Generic BackendReadiness (with skip) | Dedicated PDFSidecarReadiness |
| Dependencies | AnigmaNativeShims (shared) | PDF-specific native shims only |

---

## Proposed Fix

### Phase 1: Lane Separation (Recommended)
1. Create `PDFSidecarReadiness` test target for sidecar-specific validation
2. Move PDFSidecarExecutable validation to this dedicated target
3. Remove `--skip PDFSidecarExecutable` from generic BackendReadiness test script
4. Update CI/test scripts to run PDFSidecarReadiness separately from BackendReadiness

### Phase 2: Shim Separation (Cleanup)
1. Extract PDF-specific native shims from AnigmaNativeShims into `PDFSidecarNativeShims`
2. Move `.linkedLibrary("pdfium")` from PDFNative to PDFSidecarNativeShims
3. Make PDFSidecarExecutable depend on PDFSidecarNativeShims instead of AnigmaNativeShims
4. Keep AnigmaNativeShims for generic (non-PDF) native shims
5. BackendReadiness continues to depend on AnigmaNativeShims (without PDFium contamination)

### Phase 3: Daemon Modeling (Enhancement)
1. Model PDFSidecarExecutable as a proper daemon-spawnable sidecar
2. Add sidecar lifecycle management (start/stop/monitor)
3. Add health check endpoints
4. Add readiness validation in PDFSidecarReadiness

---

## Implementation Priority

| Phase | Priority | Effort | Impact |
|-------|----------|--------|--------|
| Phase 1: Lane Separation | HIGH | Medium | Immediate - unblocks td-358315 |
| Phase 2: Shim Separation | HIGH | Medium | Preventsfuture contamination |
| Phase 3: Daemon Modeling | MEDIUM | High | Long-term architecture |

**Recommendation:** Implement Phase 1 + Phase 2 together as a single change to fully resolve the contamination issue.

---

## Validation Plan

### Pre-Change State (Captured)
```
.build/anigma-graph/td-7c0153-pre/swiftpm-package-description.json
.build/anigma-graph/td-7c0153-pre/swiftpm-package-dependencies.json
```

### Root Cause Confirmed
- [x] No directed path from BackendReadinessContractTests to PDFSidecarExecutable
- [x] Shared dependency: AnigmaNativeShims carries vendorLinkerSettings
- [x] PDFNative carries .linkedLibrary("pdfium") + vendorLinkerSettings
- [x] Test script workaround: --skip PDFSidecarExecutable already applied
- [x] Architectural gap: PDFSidecarExecutable not modeled as governed sidecar

### Post-Change Requirements
- [ ] PDFSidecarReadiness test target exists
- [ ] PDFSidecarExecutable validation moved to PDFSidecarReadiness
- [ ] BackendReadinessContractTests does NOT depend on PDFSidecar-related targets
- [ ] AnigmaNativeShims does NOT carry PDFium-specific linkage
- [ ] PDFSidecarNativeShims exists (optional for Phase 2)
- [ ] No upward tier violations introduced
- [ ] No new dependency cycles introduced

### Post-Change Validation
```bash
# Capture post-change snapshot
python3 Scripts/anigma_package_graph_audit.py \
  --output-dir .build/anigma-graph/td-7c0153-post snapshot

# Verify PDFSidecarReadiness exists
python3 Scripts/anigma_package_graph_audit.py explain-target PDFSidecarReadiness

# Verify BackendReadiness no longer needs skip flag
python3 Scripts/anigma_package_graph_audit.py explain-target BackendReadinessContractTests

# Verify no contamination
# Check AnigmaNativeShims doesn't carry PDFium linkage
# (/manual Package.swift inspection)

# Full audit
python3 Scripts/anigma_package_graph_audit.py --fail-on-violation
# Expected: Exit code 0 (no errors)
```

---

## Acceptance Criteria for Research Phase

- [x] Directed reachability proven/disproven: DISPROVEN - No directed path exists
- [x] Shared AnigmaNativeShims contamination identified: CONFIRMED - carries vendorLinkerSettings
- [x] Package.swift evidence cited: BackendReadinessContractTests, PDFSidecarExecutable, PDFNative, AnigmaNativeShims
- [x] Test script evidence cited: Scripts/test_backend_readiness.sh with --skip workaround
- [x] Root cause classified: MIXED (Option C + partial Option A)
- [x] Implementation option selected: Phase 1 + Phase 2 (Lane Separation + Shim Separation)

---

## Files and References

| File | Purpose |
|------|---------|
| `anigma/Package.swift` | Package definitions with current target/dependency structure |
| `Scripts/test_backend_readiness.sh` | Test script with current --skip workaround |
| `Docs/governance/package-graph-rules.yaml` | Planned rule with research artifact reference |
| `.build/anigma-graph/td-7c0153-pre/` | Pre-change evidence snapshots |
| `Docs/proofs/td-358315-backend-readiness-triage.md` | Parent TD triage |

---

## Related TDs

- **td-358315** (Parent) - BackendReadiness Test Triage - BLOCKED by this
- **td-ebd744** (Reference) - RendererBackend Contract Extraction - RESOLVED
- **td-d65648** (Reference) - ReceiptSigner Extraction - RESOLVED

---

## Conclusion

The **immediate blocker** for td-358315 is that PDFSidecarExecutable is not properly isolated as a daemon-spawnable sidecar. While the test script workaround (--skip) addresses the build failure, the architectural issue remains:

- Generic BackendReadiness tests should NOT be responsible for validating PDF sidecar executables
- PDF-specific functionality should be in a dedicated readiness lane
- Native shim linkage should be properly scoped to avoid contamination

**Implementation:** Execute Phase 1 (Lane Separation) to unblock td-358315, then Phase 2 (Shim Separation) to prevent future contamination.
