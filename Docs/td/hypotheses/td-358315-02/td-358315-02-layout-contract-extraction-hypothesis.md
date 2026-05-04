# TD-358315-02: Layout Contract Extraction Hypothesis

**TD ID:** td-358315-02  
**Parent TD:** td-358315  
**Created:** 2026-05-03  
**Status:** RESEARCH PHASE  

---

## Hypothesis

**Primary Hypothesis:** The dependency path `BackendReadinessContractTests → AnigmaCore → AnigmaPipeline → LayoutEngineCapsule → PDFNative` can be broken by extracting a portable layout/PDF contract surface that AnigmaPipeline can depend on without depending on LayoutEngineCapsule or PDFNative.

**Secondary Hypothesis:** The current `PDFLayoutExtractContract` contains both contract interface (portable) and implementation (PDF-specific) concerns that should be separated.

---

## Research Questions

### Q1: Which types are portable enough for contract surface?

From `PDFLayoutExtractContract.swift` analysis, the contract defines these public types:
- `PDFLayoutSegment` - Layout segment with text and styling
- `PDFLayoutTable` - Table region bounding box
- `PDFLayoutFigure` - Figure region bounding box  
- `PDFLayoutImage` - Image data with metadata
- `PDFPageLayout` - Page layout analysis result
- `PDFLayoutOutput` - Layout extraction output containing pages
- `PDFLayoutExtractContract` - The contract spec itself

**Hypothesis:** These types appear to be portable contract types (Codable, Sendable, Hashable). They represent the **output schema** of PDF layout extraction.

**Yet to verify:** Are these types also used as input to LayoutEngineCapsule, or only as output?

### Q2: Which types are implementation-only and must remain out of AnigmaPipeline?

From the compilation errors and code analysis, `PDFLayoutExtractContract.swift` references these LayoutEngineCapsule types:
- `PageLayout` - Internal layout engine type
- `TextSegment` - Internal text segment type
- `BoundingBox` - Internal bounding box type
- `LayoutEngineConfig` - Internal configuration type
- `LayoutEngineError` - Internal error type
- `ImageData` - Internal image data type

From `PDFLayoutExtractContract.execute()`:
```swift
pageLayouts = try LayoutEngineCapsuleWrapper.analyzePDF(input.payload.rawData, config: config)
```

**Hypothesis:** `LayoutEngineCapsuleWrapper.analyzePDF` returns `[PageLayout]` - an internal type.

**Yet to verify:** Do the portable `PDFLayout*` types have `internal init(from:)` constructors that take these internal types? (Yes - confirmed in code)

### Q3: Does AnigmaPipeline need to depend on any layout engine target at all?

Current state:
- `AnigmaPipeline` depends on `LayoutEngineCapsule`
- `PDFLayoutExtractContract` is in `AnigmaPipeline` but uses `LayoutEngineCapsuleWrapper`

**Hypothesis:** If `PDFLayoutExtractContract` is the ONLY reason AnigmaPipeline depends on LayoutEngineCapsule, then the dependency can be removed by:
1. Moving PDFLayoutExtractContract to a PDF-specific target
2. OR splitting PDFLayoutExtractContract into portable contract + PDF-specific implementation

**Yet to verify:** Are there other LayoutEngineCapsule usages in AnigmaPipeline?

### Q4: Should PDFLayoutExtractContract be split?

Current `PDFLayoutExtractContract` structure:
- **Contract metadata** (id, schemas, version) - portable
- **Input/Output types** (PDFBlobArtifact, PDFLayoutOutput) - portable
- **Validation logic** (`validate(output:)`) - portable (operates on PDFLayoutOutput)
- **Execution logic** (`execute(input:ctx:)`) - PDF-specific (calls LayoutEngineCapsuleWrapper)

**Hypothesis:** Yes, split into:
1. **PDFLayoutExtractContractDescriptor** - Portable contract spec (metadata, schemas, input/output types, validation)
2. **PDFLayoutExtractExecutor** - PDF-specific implementation (calls LayoutEngineCapsuleWrapper)

**Yet to verify:** Is this split pattern used elsewhere in Anigma codebase?

---

## Type Classification

### Portable Contract Types (Candidates for LayoutEngineContracts)

| Type | Justification | Current Location | Proposed Location |
|------|--------------|-----------------|-------------------|
| `PDFLayoutSegment` | Public Codable Sendable Hashable, output schema | PDFLayoutExtractContract.swift | LayoutEngineContracts |
| `PDFLayoutTable` | Public Codable Sendable Hashable, output schema | PDFLayoutExtractContract.swift | LayoutEngineContracts |
| `PDFLayoutFigure` | Public Codable Sendable Hashable, output schema | PDFLayoutExtractContract.swift | LayoutEngineContracts |
| `PDFLayoutImage` | Public Codable Sendable Hashable, output schema | PDFLayoutExtractContract.swift | LayoutEngineContracts |
| `PDFPageLayout` | Public Codable Sendable Hashable, output schema | PDFLayoutExtractContract.swift | LayoutEngineContracts |
| `PDFLayoutOutput` | Public Codable Sendable, output schema | PDFLayoutExtractContract.swift | LayoutEngineContracts |
| `BoundingBoxRef` | Used by portable types | EvidenceContracts? | LayoutEngineContracts |

### Implementation Types (Must stay in LayoutEngineCapsule)

| Type | Reason | Current Access |
|------|--------|----------------|
| `PageLayout` | Internal layout engine type | internal |
| `TextSegment` | Internal text segment | internal |
| `ImageData` | Internal image data | internal |
| `BoundingBox` | Internal bounding box | internal |
| `LayoutEngineConfig` | Configuration | internal |
| `LayoutEngineError` | Error type | internal |
| `LayoutEngineCapsuleWrapper` | Wrapper class | public |

### Problem Types (Crossing module boundary)

The `PDFLayout*` types have `internal init(from:)` constructors that take `LayoutEngineCapsule` internal types:

```swift
internal init(from segment: TextSegment)  // TextSegment is internal to LayoutEngineCapsule
internal init(from bbox: BoundingBox)        // BoundingBox is internal to LayoutEngineCapsule
internal init(from image: ImageData)         // ImageData is internal to LayoutEngineCapsule
internal init(from pageLayout: PageLayout)  // PageLayout is internal to LayoutEngineCapsule
```

**Problem:** These inits are internal to the AnigmaPipeline module, but they reference types that are internal to LayoutEngineCapsule module. This works only because both are in the same target... but wait, they're NOT in the same target!

**Correction:** `PDFLayoutExtractContract.swift` is in AnigmaPipeline target. `TextSegment`, `BoundingBox`, `ImageData`, `PageLayout` are in LayoutEngineCapsule target. These are **different modules**. The `internal init(from:)` should NOT compile.

**Yet to verify:** Why does this currently compile? Is it because AnigmaPipeline depends on LayoutEngineCapsule and the types happen to be accessible? Or is there a different module structure?

---

## Verify Current Graph

### Command 1: Confirm dependency path

```bash
cd anigma
python3 scripts/anigma_package_graph_audit.py explain-target AnigmaPipeline
```

Expected: Shows LayoutEngineCapsule as dependency

### Command 2: Confirm LayoutEngineCapsule dependencies

```bash
cd anigma
python3 scripts/anigma_package_graph_audit.py explain-target LayoutEngineCapsule
```

Expected: Shows PDFNative as dependency

### Command 3: Confirm PDFNative dependencies

```bash
cd anigma
python3 scripts/anigma_package_graph_audit.py explain-target PDFNative
```

Expected: Shows AnigmaNativeShims as dependency

### Command 4: Check reachability

```bash
cd anigma
python3 scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFNative 2>&1
```

Expected: Should show path OR "Edge not found" (if not directly reachable but reachable through transitive dependencies)

---

## Classify File Ownership

### Files Currently in AnigmaPipeline

1. `Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractContract.swift`
   - **Classification:** Contains both contract (portable) and implementation (PDF-specific)
   - **Problem:** Uses `LayoutEngineCapsuleWrapper.analyzePDF` directly
   - **Proposed:** Split or move entirely

2. `PDFLayoutExtractWrapper.swift` (referenced but may not exist)
   - **Classification:** Implementation wrapper
   - **Proposed:** Move to PDF-specific target

### Files in LayoutEngineCapsule

1. `Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsule.swift`
   - **Classification:** Public wrapper class
   - **Access:** public

2. `Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsuleWrapper.swift`
   - **Classification:** Implementation wrapper
   - **Access:** public class, but uses internal types

3. Internal types (PageLayout, TextSegment, BoundingBox, ImageData, LayoutEngineConfig, LayoutEngineError)
   - **Classification:** Implementation details
   - **Access:** internal

---

## Proposed Solution

### Solution A: Extract LayoutEngineContracts + Move PDFLayoutExtractContract (Recommended)

1. **Create LayoutEngineContracts target**
   - New target in `Packages/LayoutEngineCapsule/Sources/LayoutEngineContracts`
   - Dependencies: AnigmaPrimitives, FoundationContracts
   - Contains portable types: `PDFLayoutSegment`, `PDFLayoutTable`, `PDFLayoutFigure`, `PDFLayoutImage`, `PDFPageLayout`, `PDFLayoutOutput`, `BoundingBoxRef`

2. **Split PDFLayoutExtractContract**
   - Move portable parts (contract spec, validation, input/output types) to LayoutEngineContracts
   - OR keep contract descriptor in AnigmaPipeline with dependency on LayoutEngineContracts
   - Move execution logic to PDF-specific target

3. **Create/Update PDFLayoutExtract target**
   - Contains PDFLayoutExtractWrapper (implementation)
   - Contains PDFLayoutExtractExecutor (execution logic)
   - Dependencies: LayoutEngineCapsule, LayoutEngineContracts

4. **Update AnigmaPipeline**
   - Remove dependency on LayoutEngineCapsule
   - Add dependency on LayoutEngineContracts
   - Registry references LayoutEngineContracts types, not LayoutEngineCapsule

5. **Update LayoutEngineCapsule**
   - No changes needed (internal types stay internal)

**Result:**
- `BackendReadinessContractTests → AnigmaCore → AnigmaPipeline → LayoutEngineContracts` (no PDFNative)
- `PDFLayoutExtract → LayoutEngineCapsule → PDFNative` (isolated)
- Clean separation of concerns ✅

### Solution B: Move PDFLayoutExtractContract to LayoutEngineCapsule

1. Move `PDFLayoutExtractContract.swift` to LayoutEngineCapsule target
2. This gives access to internal types (PageLayout, TextSegment, etc.)
3. Add dependencies to LayoutEngineCapsule: AnigmaFoundation, AnigmaGovernance, AnigmaJobs, InferenceCore, FoundationContracts, EvidenceContracts

**Risk:** Creates potential cycle if LayoutEngineCapsule now depends on AnigmaFoundation which AnigmaPipeline also depends on.

**Verdict:** ❌ Not recommended - creates complex dependency chain

### Solution C: Make LayoutEngineCapsule types public

1. Change `internal` to `public` for: PageLayout, TextSegment, BoundingBox, ImageData, LayoutEngineConfig, LayoutEngineError
2. Keep PDFLayoutExtractContract in AnigmaPipeline

**Risk:** Exposes implementation details to satisfy cross-module access

**Verdict:** ❌ Explicitly rejected by user constraints

---

## Prediction

**Predicted graph after Solution A:**

```
BackendReadinessContractTests → AnigmaCore → AnigmaPipeline → LayoutEngineContracts ✅
PDFLayoutExtract → LayoutEngineCapsule → PDFNative ✅
```

**Edge verification:**
- `BackendReadinessContractTests → PDFNative` should NOT exist
- `BackendReadinessContractTests → PDFSidecarNativeShims` should NOT exist
- `BackendReadinessContractTests → PDFSidecarExecutable` should NOT exist
- `AnigmaPipeline → LayoutEngineCapsule` should NOT exist (replaced by LayoutEngineContracts)

---

## Required Evidence

1. **Current graph snapshot** (pre-fix)
2. **Type usage analysis** - all call sites of PDFLayoutExtractContract
3. **Dependency analysis** - all LayoutEngineCapsule usages in AnigmaPipeline
4. **Post-fix graph snapshot** (post-fix)
5. **Edge verification** - confirm BackendReadinessContractTests cannot reach PDFNative

---

## Next Actions

1. ✅ Run `python3 scripts/anigma_package_graph_audit.py snapshot` to capture pre-fix state
2. ⏳ Run type usage analysis to classify all LayoutEngineCapsule types
3. ⏳ Confirm which files reference LayoutEngineCapsule in AnigmaPipeline
4. ⏳ Validate Solution A does not create dependency cycles
5. ⏳ Create LayoutEngineContracts target and migrate types
6. ⏳ Split/move PDFLayoutExtractContract
7. ⏳ Run post-fix validation

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-03 | Rejected Solution C (make types public) | Violates user constraint: "Do NOT make LayoutEngineCapsule internal types public merely to satisfy AnigmaPipeline" |
| 2026-05-03 | Rejected Solution B (move to LayoutEngineCapsule) | Risk of creating dependency cycles |
| 2026-05-03 | **Selected Solution A** (extract LayoutEngineContracts) | Clean separation, respects module boundaries, no cycles |
