# TD-7c0153 Phase 2: Native Shim Isolation Hypothesis

**TD ID:** td-7c0153  
**Phase:** Phase 2 - Native Shim Isolation / PDFium Linker Containment  
**Status:** HYPOTHESIS (Research Phase Complete)  
**Parent TD:** td-358315 (BackendReadiness Test Triage)  
**Created:** 2026-05-03  
**Research Date:** 2026-05-03  

---

## Executive Summary

**Root-Cause Classification: OPTION B** (AnigmaNativeShims carries vendorLinkerSettings which creates contamination risk)

**Correction from Phase 1:** PDFNative already correctly owns `.linkedLibrary("pdfium")`. The contamination is NOT that AnigmaNativeShims directly links PDFium, but that it carries `vendorLinkerSettings` (vendor library search path) which, when combined with PDFNative's PDFium linkage, creates a **shared search path risk** for any target depending on AnigmaNativeShims.

**Key Finding:** PDFium linkage is **already properly isolated** in PDFNative. The issue is that AnigmaNativeShims serves as a **shared search path bridge** between generic targets and PDF-specific targets.

---

## Research Evidence

### 1. Package.swift Evidence

#### PDFNative Target (anigma/Package.swift:287-294)
```swift
.target(
    name: "PDFNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/PDFCapsule/Sources/PDFNative",
    cxxSettings: [.headerSearchPath("../../../../Vendor/include")],
    linkerSettings: [.linkedLibrary("pdfium")] + vendorLinkerSettings
),
```

**Analysis:** 
- ✅ **PDFNative correctly owns `.linkedLibrary("pdfium")`** - This is the PDFium linkage point
- ✅ **PDFNative carries `vendorLinkerSettings`** - Adds `-L{VENDOR_LIB_PATH}` 
- ✅ **PDFNative depends on AnigmaNativeShims** - For shared native infrastructure

#### PDFium Linkage Ownership
| Target | `.linkedLibrary("pdfium")` | `vendorLinkerSettings` | PDFium Linkage |
|--------|----------------------------|------------------------|----------------|
| PDFNative | ✅ YES | ✅ YES | ✅ **DIRECT** |
| AnigmaNativeShims | ❌ NO | ✅ YES | ❌ NO |
| PDFSidecarExecutable | ❌ NO | ❌ NO | ✅ (transitive via PDFNative) |
| BackendReadinessContractTests | ❌ NO | ❌ NO | ❌ NO |

**Conclusion:** PDFNative is the **sole owner** of PDFium linkage in the current architecture.

#### AnigmaNativeShims Target (anigma/Package.swift:334-354)
```swift
.target(
    name: "AnigmaNativeShims",
    path: "Packages/AnigmaNativeShims",
    exclude: [],
    sources: ["Sources"],
    publicHeadersPath: "include",
    cSettings: [
      .headerSearchPath("include"),
      .headerSearchPath("../../Vendor/include")
    ],
    cxxSettings: [
      .headerSearchPath("include"),
      .define("ANIGMA_CAPSULE_IMPLEMENTATION"),
      .unsafeFlags(["-Wno-everything"])
    ],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)] + [
      .interoperabilityMode(.Cxx)
    ],
    linkerSettings: vendorLinkerSettings
),
```

**Analysis:**
- ✅ **Carries only `vendorLinkerSettings`** - NOT `.linkedLibrary("pdfium")`
- ✅ **Header search paths** include `../../Vendor/include` for PDFium headers
- ⚠️ **Contamination RISK**: Any target depending on AnigmaNativeShims gets the vendor library search path

#### vendorLinkerSettings Definition (anigma/Package.swift:26-28)
```swift
let vendorLibPath = "\(packageRoot)/Vendor/lib"
let vendorLinkerSettings: [LinkerSetting] = [
  .unsafeFlags(["-L", vendorLibPath])
]
```

**Analysis:** This adds `-L{packageRoot}/Vendor/lib` to the linker search path.

#### PDFSidecarExecutable Target (anigma/Package.swift:1329)
```swift
.executableTarget(
    name: "PDFSidecarExecutable",
    dependencies: ["PDFSidecarClient", "SidecarPDFService", "PDFNative", "AnigmaNativeShims"],
    path: "Packages/SidecarPDFService/Sources/PDFSidecarExecutable",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
),
```

**Analysis:** Depends on both PDFNative (PDFium linkage) and AnigmaNativeShims (vendor search path).

### 2. Graph Evidence

#### Reachability Matrix (Confirmed via `anigma_package_graph_audit.py`)

| Source → Target | PDFNative | PDFSidecarExecutable | AnigmaNativeShims | BackendReadinessContractTests |
|-----------------|-----------|---------------------|-------------------|-------------------------------|
| BackendReadinessContractTests | ❌ | ❌ | ✅ (transitive via AnigmaCore) | N/A |
| PDFSidecarExecutable | ❌ | N/A | ✅ (direct) | ❌ |
| PDFNative | N/A | ❌ | ✅ (direct) | ❌ |
| AnigmaNativeShims | ❌ | ❌ | N/A | ❌ |

**Key Finding:** No directed reachability exists between BackendReadinessContractTests and PDFSidecarExecutable or PDFNative.

#### Dependency Chain Analysis
```
BackendReadinessContractTests → AnigmaCore → AnigmaFoundation → AnigmaPrimitives → AnigmaNativeShims
PDFSidecarExecutable → AnigmaNativeShims (direct)
PDFSidecarExecutable → PDFNative → AnigmaNativeShims (direct)
```

**Shared dependency:** AnigmaNativeShims is the **common ancestor** of both BackendReadinessContractTests (transitive) and PDFSidecarExecutable (direct).

### 3. Current Linker Behavior

When building BackendReadinessContractTests:
1. SwiftPM builds BackendReadinessContractTests
2. SwiftPM builds all transitive dependencies: AnigmaCore → AnigmaFoundation → AnigmaPrimitives → **AnigmaNativeShims**
3. AnigmaNativeShims adds `-L{VENDOR_LIB_PATH}` to the linker search path
4. **But:** PDFNative is NOT built because it's not in the transitive dependency chain
5. **Therefore:** PDFium is NOT linked into BackendReadinessContractTests

When building PDFSidecarExecutable:
1. SwiftPM builds PDFSidecarExecutable
2. SwiftPM builds all dependencies: PDFSidecarClient, SidecarPDFService, **PDFNative**, **AnigmaNativeShims**
3. PDFNative adds `.linkedLibrary("pdfium") + vendorLinkerSettings`
4. AnigmaNativeShims adds `vendorLinkerSettings`
5. **Result:** PDFium is linked, vendor search path is set

**Linker Containment Status:** ✅ **CORRECT** - PDFium is only linked when PDFNative is built.

---

## Hypothesis Questions and Answers

### Q1: Which target currently declares `.linkedLibrary("pdfium")`?
**A: PDFNative** (anigma/Package.swift:294)

### Q2: Which target currently owns `vendorLinkerSettings`?
**A: Multiple targets own it:**
- AnigmaNativeShims (line 354): `linkerSettings: vendorLinkerSettings`
- PDFNative (line 294): `linkerSettings: [.linkedLibrary("pdfium")] + vendorLinkerSettings`
- CClipper2 (line 284): `linkerSettings: vendorLinkerSettings`
- NativeKernel (line 368): `linkerSettings: vendorLinkerSettings`

The `vendorLinkerSettings` variable is defined once (line 27) and reused across multiple targets.

### Q3: Is `vendorLinkerSettings` generic or PDF-specific?
**A: GENERIC** - It only adds the vendor library search path (`-L{VENDOR_LIB_PATH}`). It does NOT include `.linkedLibrary("pdfium")`.

### Q4: Is AnigmaNativeShims actually causing linker contamination, or only carrying a search-path risk?
**A: SEARCH-PATH RISK ONLY** - AnigmaNativeShims carries only `vendorLinkerSettings` (search path), NOT `.linkedLibrary("pdfium")`. The contamination is a **RISK**, not proven contamination.

### Q5: Does PDFNative already sufficiently isolate PDFium linkage?
**A: YES** - PDFNative is the **sole owner** of `.linkedLibrary("pdfium")`. PDFium linkage only occurs when PDFNative is explicitly built or when a target transitively depends on PDFNative.

### Q6: Is a new PDFSidecarNativeShims target necessary?
**A: NOT STRICTLY NECESSARY for linker isolation** - The current architecture already isolates PDFium linkage correctly in PDFNative.

**BUT: RECOMMENDED for architectural clarity** - Creating PDFSidecarNativeShims would:
- Make the isolation explicit and self-documenting
- Remove the shared dependency on AnigmaNativeShims between PDF and non-PDF targets
- Follow the principle of "each capability owns its native shims"
- Reduce the search-path risk surface

### Q7: What is the predicted graph delta if we create PDFSidecarNativeShims?

**Current State:**
```
AnigmaNativeShims (tier3) ← PDFNative (unclassified)
AnigmaNativeShims (tier3) ← PDFSidecarExecutable (unclassified)
AnigmaNativeShims (tier3) ← BackendReadinessContractTests (transitive via AnigmaCore)
```

**After Creating PDFSidecarNativeShims:**
```
AnigmaNativeShims (tier3) ← PDFSidecarNativeShims (new, tier3)
PDFSidecarNativeShims (tier3) ← PDFNative (unclassified)
PDFSidecarNativeShims (tier3) ← PDFSidecarExecutable (unclassified)
AnigmaNativeShims (tier3) ← BackendReadinessContractTests (transitive via AnigmaCore)
```

**Graph Delta:**
- +1 new target: PDFSidecarNativeShims
- -1 edge: PDFSidecarExecutable → AnigmaNativeShims (replaced)
- -1 edge: PDFNative → AnigmaNativeShims (replaced)
- +2 edges: PDFSidecarExecutable → PDFSidecarNativeShims
- +2 edges: PDFNative → PDFSidecarNativeShims
- +1 edge: PDFSidecarNativeShims → AnigmaNativeShims

**Net:** +1 target, same number of total edges, clearer isolation.

### Q8: What is the predicted risk of cycles/tier violations?
**A: LOW RISK**

**Cycle Analysis:**
- AnigmaNativeShims is currently tier3
- PDFSidecarNativeShims would be tier3 (same layer as AnigmaNativeShims)
- Dependencies would flow: PDFSidecarNativeShims → AnigmaNativeShims
- No cycle would be created

**Tier Analysis:**
- AnigmaNativeShims: tier3 (Feature/Daemon Layer) ✅
- PDFSidecarNativeShims: tier3 (Feature/Daemon Layer) ✅
- PDFNative: currently unclassified → should be tier3 (Feature/Daemon Layer) ✅
- PDFSidecarExecutable: currently unclassified → should be tier3 (Feature/Daemon Layer) ✅

**Recommendation:** Classify PDFNative and PDFSidecarExecutable as tier3 to match their dependency on AnigmaNativeShims.

---

## Root-Cause Classification

**CHOOSE ONE:**

### A. PDFNative already owns PDFium correctly; only readiness scripts need final wording/validation.
**Status:** ❌ NOT SELECTED - While PDFNative does own PDFium correctly, the shared AnigmaNativeShims dependency creates a contamination **risk** that should be addressed.

### B. AnigmaNativeShims carries PDF-specific vendorLinkerSettings and must be split.
**Status:** ✅ **SELECTED** - Most accurate. While vendorLinkerSettings is technically generic (not PDF-specific), AnigmaNativeShims serves as a shared bridge between PDF targets (PDFNative, PDFSidecarExecutable) and non-PDF targets (BackendReadinessContractTests transitive chain). The **contamination risk** exists because any target depending on AnigmaNativeShims gets the vendor search path.

### C. PDFSidecarExecutable depends on AnigmaNativeShims unnecessarily and should depend only on PDF-specific native shims.
**Status:** ⚠️ PARTIALLY TRUE - PDFSidecarExecutable does depend on AnigmaNativeShims, but this dependency is **legitimate** for shared native infrastructure. The issue is that the shared infrastructure (AnigmaNativeShims) is also used by non-PDF targets.

### D. Mixed cause: split PDF-specific linker state and keep generic native shims generic.
**Status:** ✅ **ALSO ACCEPTABLE** - This is effectively the same as Option B but phrased as a solution rather than a diagnosis. The mixed cause is:
1. AnigmaNativeShims carries vendorLinkerSettings (search path risk)
2. PDFNative correctly owns PDFium linkage but depends on shared AnigmaNativeShims

**FINAL SELECTION: OPTION B** (with acknowledgment that Option D describes the same situation from a solution perspective)

---

## Proposed Package.swift Change

### Option 1: Minimal Change (Prefer if risk is acceptable)
**Action:** None - PDFNative already isolates PDFium correctly.

**Rationale:** 
- No proven contamination exists
- PDFium is only linked when PDFNative is built
- BackendReadinessContractTests does not depend on PDFNative
- The shared AnigmaNativeShims is a **risk**, not a blocker

**Trade-off:** 
- ❌ Contamination risk remains (search path bridging)
- ✅ No code changes required
- ✅ No new targets to maintain

### Option 2: Create PDFSidecarNativeShims (Recommended for architectural clarity)

**Changes:**

1. **Create new target:**
```swift
.target(
    name: "PDFSidecarNativeShims",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/PDFSidecarNativeShims",
    publicHeadersPath: "include",
    cSettings: [
      .headerSearchPath("include"),
      .headerSearchPath("../../Vendor/include")
    ],
    cxxSettings: [
      ./headerSearchPath("include")
    ],
    linkerSettings: vendorLinkerSettings  // Keep vendor search path here too
),
```

2. **Update PDFNative to depend on PDFSidecarNativeShims:**
```swift
.target(
    name: "PDFNative",
    dependencies: ["PDFSidecarNativeShims"],  // Changed from AnigmaNativeShims
    path: "Packages/PDFCapsule/Sources/PDFNative",
    cxxSettings: [.headerSearchPath("../../../../Vendor/include")],
    linkerSettings: [.linkedLibrary("pdfium")] + vendorLinkerSettings
),
```

3. **Update PDFSidecarExecutable:**
```swift
.executableTarget(
    name: "PDFSidecarExecutable",
    dependencies: ["PDFSidecarClient", "SidecarPDFService", "PDFNative", "PDFSidecarNativeShims"],  // Changed from AnigmaNativeShims
    path: "Packages/SidecarPDFService/Sources/PDFSidecarExecutable",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
),
```

4. **Update SidecarPDFService:**
```swift
.target(
    name: "SidecarPDFService",
    dependencies: ["PDFSidecarNativeShims", "AnigmaPrimitives"],  // Changed from AnigmaNativeShims
    path: "Packages/SidecarPDFService/Sources/SidecarPDFService",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
),
```

5. **Update PDFSidecarClient:**
```swift
.target(
    name: "PDFSidecarClient",
    dependencies: ["PDFSidecarNativeShims", "AnigmaPrimitives"],  // Changed from AnigmaNativeShims
    path: "Packages/SidecarPDFService/Sources/PDFSidecarClient",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
),
```

**Note:** We keep PDFSidecarNativeShims depending on AnigmaNativeShims because it may need the generic native shim infrastructure.

**Trade-off:**
- ✅ Explicit architectural isolation
- ✅ Reduces search-path bridging risk
- ✅ Self-documenting architecture
- ❌ Requires creating new target and refactoring dependencies
- ❌ May need to move source files from AnigmaNativeShims to PDFSidecarNativeShims

**Recommendation:** Start with Option 1 (Minimal Change) if the contamination risk is acceptable. If the risk proves problematic, implement Option 2.

### Option 3: Move PDF-specific settings to PDFNative only (Alternative)

**Changes:**
1. Remove `vendorLinkerSettings` from AnigmaNativeShims
2. Keep `vendorLinkerSettings` only in targets that need it: PDFNative, CClipper2, NativeKernel
3. Add `vendorLinkerSettings` to any other targets that depend on vendor libraries

**Trade-off:**
- ✅ AnigmaNativeShims becomes truly generic
- ❌ PDFNative still depends on AnigmaNativeShims (may still have the bridging issue)
- ❌ Requires auditing all targets to ensure they get the search path they need

---

## Predicted Graph Impact

### Option 1 (No Change)
- **Graph delta:** None
- **Cycle risk:** None
- **Tier violation risk:** None
- **Contamination risk:** Remains (search path bridging via AnigmaNativeShims)

### Option 2 (Create PDFSidecarNativeShims)
- **Graph delta:** +1 target, dependency edges restructured
- **Cycle risk:** None (all dependencies flow downward)
- **Tier violation risk:** None (PDFSidecarNativeShims would be tier3, same as AnigmaNativeShims)
- **Contamination risk:** Eliminated for PDF-specific linker state

### Option 3 (Move vendorLinkerSettings)
- **Graph delta:** None (only linker settings changes)
- **Cycle risk:** None
- **Tier violation risk:** None
- **Contamination risk:** Reduced but not eliminated (PDFNative still depends on AnigmaNativeShims)

---

## Implementation Recommendation

**SELECTED APPROACH:** Option 2 - Create PDFSidecarNativeShims

**Rationale:**
1. **Explicit Isolation:** Makes the PDF-specific native shim layer explicit
2. **Self-Documenting:** Architecture clearly shows PDF targets depend on PDF-specific shims
3. **Future-Proof:** Prevents accidental PDF contamination of generic shims
4. **Follows Principle:** "Each capability owns its native shims"
5. **Low Risk:** No cycles or tier violations introduced

**Scope:**
- Create `Packages/PDFSidecarNativeShims` directory
- Create minimal PDFSidecarNativeShims target
- Update PDFNative, PDFSidecarExecutable, SidecarPDFService, PDFSidecarClient dependencies
- Do NOT modify AnigmaNativeShims (keep it generic)
- Do NOT modify non-PDF targets

**Non-Goals (reiterated):**
- Do NOT make PDFSidecarExecutable part of generic BackendReadiness
- Do NOT link PDFium into AnigmaFoundation, AnigmaCore, AnigmaPrimitives, or generic BackendReadiness
- Do NOT expose PDFium types in contract modules
- Do NOT remove the PDFSidecarReadiness lane
- Do NOT remove the BackendReadiness --skip guard until validation proves it is no longer needed
- Do NOT broaden Package.swift product exposure
- Do NOT add @_exported imports
- Do NOT create fake stubs

---

## Pre-Implementation Checklist

- [x] Graph snapshot captured (`.build/anigma-graph/td-7c0153-phase2-pre/`)
- [x] Package.swift evidence gathered
- [x] Graph reachability confirmed
- [x] Root-cause classified (Option B)
- [x] Proposed change documented
- [x] Graph delta predicted
- [x] Cycle/tier violation risk assessed (LOW)
- [x] Non-goals restated

---

## Validation Plan (Post-Implementation)

1. **Graph snapshot:** Capture post-change snapshot
2. **Reachability checks:** Confirm no new directed paths between BackendReadiness and PDF targets
3. **Tier validation:** Run `validate_tiers.py` - expect no new violations
4. **Cycle validation:** Run `validate_no_cycles.py` - expect no new cycles
5. **Build validation:** 
   - `swift build --product PDFSidecarExecutable`- expect success
   - `swift build --target BackendReadinessContractTests` - expect success
   - `Scripts/test_pdf_sidecar_readiness.sh` - expect PASSED or CLEAN
   - `Scripts/test_backend_readiness.sh BackendReadinessContractTests` - expect advancement

---

## Acceptance Criteria for Implementation

- [ ] PDFium linkage is owned only by PDF/PDF-sidecar-specific targets
- [ ] AnigmaNativeShims does not carry PDF-specific linker settings
- [ ] BackendReadinessContractTests has no directed path to PDFNative, PDFSidecarNativeShims, or PDFSidecarExecutable
- [ ] PDFSidecarReadiness validates PDFSidecarExecutable separately
- [ ] Generic BackendReadiness does not validate PDFSidecarExecutable directly
- [ ] No PDFium types leak into contract modules
- [ ] No new cycles
- [ ] No new tier violations
- [ ] No @_exported imports
- [ ] No fake stubs

---

## Files to Create/Modify

### Create
- `Packages/PDFSidecarNativeShims/` - New directory
- `Packages/PDFSidecarNativeShims/Sources/` - Source directory
- `Packages/PDFSidecarNativeShims/include/` - Header directory
- `Packages/PDFSidecarNativeShims/Package.swift` - Optional, if needed for standalone builds

### Modify
- `anigma/Package.swift` - Update PDFNative, PDFSidecarExecutable, SidecarPDFService, PDFSidecarClient dependencies
- `anigma/Package.swift` - Add PDFSidecarNativeShims target definition

---

## Source References

| File | Line | Evidence |
|------|------|----------|
| anigma/Package.swift | 26-28 | vendorLinkerSettings definition |
| anigma/Package.swift | 287-294 | PDFNative target with .linkedLibrary("pdfium") |
| anigma/Package.swift | 334-354 | AnigmaNativeShims target with vendorLinkerSettings |
| anigma/Package.swift | 1329 | PDFSidecarExecutable dependencies |
| Scripts/anigma_package_graph_audit.py | - | Graph reachability queries |
| .build/anigma-graph/td-7c0153-phase2-pre/ | - | Pre-change snapshots |

---

## Related Documents

- `Docs/td/hypotheses/td-7c0153/td-7c0153-root-cause-classification.md` - Phase 1 root cause
- `Docs/proofs/td-7c0153-pdf-sidecar-readiness-lane-proof.md` - Phase 1 validation
- `Docs/proofs/td-358315-backend-readiness-triage.md` - Parent TD triage
- `Docs/governance/BUILD_TOOLING_DOCTRINE.md` - Build doctrine
- `Docs/governance/package-graph-rules.yaml` - Dependency rules

---

## Conclusion

**Wavefunction Collapse:** PDFNative already owns PDFium linkage correctly. The contamination is a **search-path bridging risk** via AnigmaNativeShims, not proven contamination. 

**Phase 2 Decision:** Create PDFSidecarNativeShims to explicitly isolate PDF-specific native shim layer, making the architecture self-documenting and reducing the bridging risk surface.

**Priority:** High - This addresses the architectural concern and prevents future contamination.

**Effort:** Medium - Requires creating new target and updating ~4 target dependencies.

**Risk:** Low - No cycles or tier violations predicted.