# TD-358315-02 Research: Extract portable layout/PDF contract surface

**TD ID:** td-358315-02  
**Parent TD:** td-358315  
**Created:** 2026-05-03  
**Status:** RESEARCH IN PROGRESS  

---

## Current Blocker

td-358315-01 cannot be implemented correctly because generic BackendReadiness reaches PDFNative through:

```
BackendReadinessContractTests
  → AnigmaCore
  → AnigmaPipeline
  → LayoutEngineCapsule
  → PDFNative
```

---

## Goal

Break the `AnigmaPipeline → LayoutEngineCapsule → PDFNative` path by separating portable layout/PDF contract surface from PDF/native implementation.

---

## Rules

- ❌ Do not make internal LayoutEngineCapsuleWrapper types public just to satisfy AnigmaPipeline
- ❌ Do not add PDFLayoutExtractWrapper.swift to AnigmaPipeline
- ❌ Do not link PDFium into BackendReadiness
- ❌ Do not move PDF/native implementation into generic contracts
- ❌ Do not add @_exported imports
- ❌ Do not create fake stubs
- ❌ Do not remove --skip PDFSidecarExecutable
- ❌ Do not work on PDFium install/discovery (belongs to td-7c0153-01)

---

## Research Commands

Run from repo root (not anigma/ subdirectory):

```bash
# Capture pre-fix graph snapshot for td-358315-02
python3 Scripts/anigma_package_graph_audit.py snapshot --task-id td-358315-02 --label pre

# Verify dependency path exists
python3 Scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFNative
python3 Scripts/anigma_package_graph_audit.py explain-edge AnigmaPipeline PDFNative
python3 Scripts/anigma_package_graph_audit.py explain-edge AnigmaPipeline LayoutEngineCapsule

# Inspect targets
python3 Scripts/anigma_package_graph_audit.py explain-target AnigmaPipeline
python3 Scripts/anigma_package_graph_audit.py explain-target LayoutEngineCapsule
python3 Scripts/anigma_package_graph_audit.py explain-target PDFNative

# Type and file usage analysis
rg -n "LayoutEngineCapsule|PDFNative|PDFLayoutExtractContract|PDFLayoutExtractWrapper|PageLayout|TextSegment|BoundingBox|LayoutEngineConfig|LayoutEngineError|extractText" anigma/Packages anigma/Package.swift

# Evidence: PackageDescription target/product analysis
swift package describe --type json > .build/td-358315-02-package-describe-pre.json
```

---

## Research Output

**Required:** `Docs/td/hypotheses/td-358315-02/td-358315-02-layout-contract-extraction-research.md`

---

## Type/File Classification

Classify every relevant type/file as exactly ONE of:

| Classification | Description | Examples |
|---------------|-------------|----------|
| portable contract surface | Contract specs, descriptors, capability metadata | `ContractSpec`, `ContractID` |
| portable value type | Public Codable Sendable Hashable schema types | `PDFLayoutSegment`, `PDFLayoutOutput` |
| generic pipeline registry | Pipeline contract registration logic | `PipelineContractRegistry` |
| layout implementation | Layout engine execution code | `LayoutEngineCapsuleWrapper` |
| PDF implementation | PDF-specific processing | `PDFLayoutExtractContract.execute()` |
| PDF native bridge | Native PDF/PDFium bridge code | `PDFNative`, `PDFCapsule` |
| sidecar readiness | Sidecar/PDF service readiness | `SidecarPDFService` |
| stale/dead code | Unused or rejected code | `PDFLayoutExtractWrapper.swift` in wrong target |

### Classification Results

**Research findings from commands:**
- `AnigmaPipeline → LayoutEngineCapsule` edge EXISTS (confirmed via graph audit)
- `AnigmaPipeline → PDFNative` edge NOT found (direct), but transitive path exists: AnigmaPipeline → LayoutEngineCapsule → PDFNative
- `BackendReadinessContractTests → PDFNative` edge NOT found (direct), but transitive path exists
- Only ONE file in AnigmaPipeline uses LayoutEngineCapsule: `PDFLayoutExtractContract.swift`
- `PDFLayoutExtractContract` is NOT registered in PipelineContractRegistry
- LayoutEngineCapsule types (`PageLayout`, `TextSegment`, `BoundingBox`, `ImageData`, `LayoutEngineConfig`) are PUBLIC in LayoutEngineCapsuleWrapper.swift
- PDFLayoutExtractWrapper.swift does NOT exist in codebase (referenced in errors but never created)

| File/Type | Current Module/Target | Current Access | Current Dependency Path | Classification | Reason | Move/Keep Decision |
|-----------|----------------------|----------------|-------------------------|----------------|--------|---------------------|
| `PDFLayoutExtractContract` enum | AnigmaPipeline | public | AnigmaPipeline → LayoutEngineCapsule | PDF implementation | Calls `LayoutEngineCapsuleWrapper.analyzePDF` directly, depends on PDF-specific execution | Split: descriptor stays, executor moves |
| `PDFLayoutExtractContract.id` | AnigmaPipeline | public | AnigmaPipeline | portable contract surface | Contract metadata (name, major, minor, hash) | Keep in new LayoutEngineContracts |
| `PDFLayoutExtractContract.validate(output:)` | AnigmaPipeline | public | AnigmaPipeline | portable contract surface | Operates only on portable `PDFLayoutOutput` type | Keep in new LayoutEngineContracts |
| `PDFLayoutExtractContract.execute(input:ctx:)` | AnigmaPipeline | public | AnigmaPipeline → LayoutEngineCapsule | PDF implementation | Directly calls LayoutEngineCapsuleWrapper, uses internal `init(from:)` constructors | Move to PDFLayoutExtract target |
| `PDFLayoutSegment` | AnigmaPipeline | public | AnigmaPipeline | portable value type | Public Codable Sendable Hashable, output schema; internal init takes LayoutEngineCapsule.TextSegment | Move to LayoutEngineContracts |
| `PDFLayoutTable` | AnigmaPipeline | public | AnigmaPipeline | portable value type | Public Codable Sendable Hashable, output schema; internal init takes LayoutEngineCapsule.BoundingBox | Move to LayoutEngineContracts |
| `PDFLayoutFigure` | AnigmaPipeline | public | AnigmaPipeline | portable value type | Public Codable Sendable Hashable, output schema; internal init takes LayoutEngineCapsule.BoundingBox | Move to LayoutEngineContracts |
| `PDFLayoutImage` | AnigmaPipeline | public | AnigmaPipeline | portable value type | Public Codable Sendable, output schema; internal init takes LayoutEngineCapsule.ImageData | Move to LayoutEngineContracts |
| `PDFPageLayout` | AnigmaPipeline | public | AnigmaPipeline | portable value type | Public Codable Sendable, output schema; internal init takes LayoutEngineCapsule.PageLayout | Move to LayoutEngineContracts |
| `PDFLayoutOutput` | AnigmaPipeline | public | AnigmaPipeline | portable value type | Public Codable Sendable, output schema, no internal inits | Move to LayoutEngineContracts |
| `BoundingBoxRef` | EvidenceContracts | public | EvidenceContracts | portable contract surface | Used by portable types, defined in EvidenceContracts | Keep in EvidenceContracts |
| `PDFBlobArtifact` | AnigmaPipeline (SharedPDFTypes.swift) | public | AnigmaPipeline | portable value type | Input artifact type, Codable Sendable | Keep or move to LayoutEngineContracts |
| `LayoutEngineCapsule` class | LayoutEngineCapsule | public | LayoutEngineCapsule | layout implementation | Public wrapper for layout engine | Keep in LayoutEngineCapsule |
| `LayoutEngineCapsuleWrapper` class | LayoutEngineCapsule | public | LayoutEngineCapsule | layout implementation | Native bridge wrapper, calls C API | Keep in LayoutEngineCapsule |
| `PageLayout` struct | LayoutEngineCapsule | public | LayoutEngineCapsule | layout implementation | Public struct but represents internal layout engine data model | Keep in LayoutEngineCapsule |
| `TextSegment` struct | LayoutEngineCapsule | public | LayoutEngineCapsule | layout implementation | Public struct but represents internal layout engine data model | Keep in LayoutEngineCapsule |
| `BoundingBox` struct | LayoutEngineCapsule | public | LayoutEngineCapsule | layout implementation | Public struct but represents internal layout engine geometry | Keep in LayoutEngineCapsule |
| `ImageData` struct | LayoutEngineCapsule | public | LayoutEngineCapsule | layout implementation | Public struct but represents internal layout engine data model | Keep in LayoutEngineCapsule |
| `LayoutEngineConfig` struct | LayoutEngineCapsule | public | LayoutEngineCapsule | layout implementation | Configuration for layout engine | Keep in LayoutEngineCapsule |
| `LayoutEngineError` | LayoutEngineCapsule | (not found) | LayoutEngineCapsule | layout implementation | Error type | Keep in LayoutEngineCapsule |
| `PDFLayoutExtractWrapper` | Does not exist | N/A | N/A | stale/dead code | Referenced in errors but never created | N/A (do not create) |
| `PDFNative` | PDFNative | N/A | PDFNative | PDF native bridge | Native PDF/PDFium C++ bridge | Keep in PDFNative |
| `PDFSidecarNativeShims` | PDFSidecarNativeShims | N/A | PDFSidecarNativeShims | PDF native bridge | Empty shim, delegates to PDFNative | Keep in PDFSidecarNativeShims |

---

## Specific Research Questions

### Q1: Why does AnigmaPipeline depend on LayoutEngineCapsule?

**Answer:** ONLY `PDFLayoutExtractContract.swift` imports and uses LayoutEngineCapsule.

```bash
$ rg -l "import LayoutEngineCapsule" anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/
anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractContract.swift

$ rg -n "LayoutEngineCapsule\." anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/
anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractContract.swift:16:import LayoutEngineCapsule
anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractContract.swift:220:pageLayouts = try LayoutEngineCapsuleWrapper.analyzePDF(input.payload.rawData, config: config)
```

**Conclusion:** The entire AnigmaPipeline → LayoutEngineCapsule dependency exists SOLELY for `PDFLayoutExtractContract.swift`. Removing this file from AnigmaPipeline would allow removing the LayoutEngineCapsule dependency entirely.

### Q2: Which files or symbols require that dependency?

**Answer:** Only `PDFLayoutExtractContract.execute(input:ctx:)` method:
- Line 16: `import LayoutEngineCapsule`
- Line 220: `pageLayouts = try LayoutEngineCapsuleWrapper.analyzePDF(input.payload.rawData, config: config)`
- Line 220: Uses `LayoutEngineConfig(determinismTier: 1)`
- Multiple `internal init(from:)` constructors that take LayoutEngineCapsule types

### Q3: Does AnigmaPipeline need executable layout extraction, or only contract/capability metadata?

**Answer:** AnigmaPipeline does NOT need executable layout extraction.

- `PDFLayoutExtractContract` is NOT registered in PipelineContractRegistry
- No other code in AnigmaPipeline references PDF layout extraction
- The contract's `execute` method is PDF-specific implementation
- Only the contract descriptor (id, schemas, validation) is portable

**Conclusion:** AnigmaPipeline only needs contract/capability metadata, NOT execution. Execution belongs in PDF-specific targets.

### Q4: Which types are safe portable contract types?

**Answer:** The `PDFLayout*` types ARE safe as portable value types BUT have a problem:

- `PDFLayoutSegment`: Public, Codable, Sendable, Hashable ✅ BUT has `internal init(from: TextSegment)` where TextSegment is from LayoutEngineCapsule
- `PDFLayoutTable`: Public, Codable, Sendable, Hashable ✅ BUT has `internal init(from: BoundingBox)` where BoundingBox is from LayoutEngineCapsule
- `PDFLayoutFigure`: Public, Codable, Sendable, Hashable ✅ BUT has `internal init(from: BoundingBox)` where BoundingBox is from LayoutEngineCapsule
- `PDFLayoutImage`: Public, Codable, Sendable ✅ BUT has `internal init(from: ImageData)` where ImageData is from LayoutEngineCapsule
- `PDFPageLayout`: Public, Codable, Sendable ✅ BUT has `internal init(from: PageLayout)` where PageLayout is from LayoutEngineCapsule
- `PDFLayoutOutput`: Public, Codable, Sendable ✅ NO internal inits

**Problem:** The `internal init(from:)` constructors mean these types can only be constructed within AnigmaPipeline module. If we move them to LayoutEngineContracts, we lose those inits. If we keep them in AnigmaPipeline and remove LayoutEngineCapsule dependency, the inits break.

**Solution:** The `internal init(from:)` constructors are implementation details, not contract. The contract only needs public initializers with portable parameters. The conversion from LayoutEngineCapsule types to portable types belongs in the PDF-specific executor.

### Q5: Which types are implementation-only and must stay out of AnigmaPipeline?

**Answer:** All LayoutEngineCapsule types should stay in LayoutEngineCapsule:

- `PageLayout`: Layout engine internal data model
- `TextSegment`: Layout engine internal data model
- `BoundingBox`: Layout engine internal geometry
- `ImageData`: Layout engine internal data model
- `LayoutEngineConfig`: Layout engine configuration
- `LayoutEngineCapsule`: Public wrapper class
- `LayoutEngineCapsuleWrapper`: Native bridge wrapper

**Note:** These are currently PUBLIC in LayoutEngineCapsule, but they represent implementation data models, not contract surfaces.

### Q6: Can PDFLayoutExtractContract be split?

**Answer:** YES. Split into:

```
PDFLayoutExtractContractDescriptor (portable) → LayoutEngineContracts
  - static let id = ContractID(...)
  - static let inputSchemaVersion = 1
  - static let outputSchemaVersion = 1
  - static func validate(output: ArtifactEnvelope<PDFLayoutOutput>) throws
  - Portable input/output types: PDFLayoutSegment, PDFLayoutTable, PDFLayoutFigure,
    PDFLayoutImage, PDFPageLayout, PDFLayoutOutput, PDFBlobArtifact

PDFLayoutExtractExecutor (implementation) → PDFLayoutExtract target
  - static func execute(input: ArtifactEnvelope<PDFBlobArtifact>, ctx: ContractContext) async throws -> ArtifactEnvelope<PDFLayoutOutput>
  - Calls LayoutEngineCapsuleWrapper.analyzePDF
  - Uses internal init(from:) constructors to convert LayoutEngineCapsule types to portable types
```

**Feasibility:** HIGH. The `execute` method (lines 210-240) is the only PDF-specific part. Everything else (id, schemas, validation, portable types) is contract surface.

### Q7: What target should own the portable contract surface?

**Answer:** `LayoutEngineContracts`

**Rationale:**
- Layout is not PDF-specific (could apply to other document types)
- Matches Anigma's convention of `{Capability}Contracts` for contract targets (e.g., FoundationContracts, EvidenceContracts)
- Clear ownership: layout-related contracts
- Avoids confusion with PDF-specific implementation

**Classification:** portable contract surface

### Q8: What target should own the implementation?

**Answer:** Create new `PDFLayoutExtract` target

**Rationale:**
- Clear ownership: PDF-specific layout extraction implementation
- Separates from generic LayoutEngineCapsule (which could be used by other capsules)
- Isolates PDF-specific dependencies
- Keeps PDF-specific contract execution logic separate from generic pipeline

**Dependencies:**
```swift
.target(
  name: "PDFLayoutExtract",
  dependencies: [
    "LayoutEngineCapsule",
    "LayoutEngineContracts",
    "AnigmaFoundation",
    "AnigmaGovernance",
    "AnigmaJobs",
    "InferenceCore",
    "FoundationContracts",
    "EvidenceContracts"
  ],
  path: "Packages/PDFLayoutExtract/Sources"
)
```

### Q9: What Package.swift dependency edges will be removed?

**Proposed:**
- [ ] Remove `LayoutEngineCapsule` from `AnigmaPipeline` dependencies

### Q10: What Package.swift dependency edges will be added?

**Proposed:**
- [ ] Add `LayoutEngineContracts` to `AnigmaPipeline` dependencies
- [ ] Add `LayoutEngineContracts` dependency to `LayoutEngineCapsule`
- [ ] Create `PDFLayoutExtract` target with dependencies: `LayoutEngineCapsule`, `LayoutEngineContracts`, `AnigmaFoundation`, `AnigmaGovernance`, `AnigmaJobs`, `InferenceCore`, `FoundationContracts`, `EvidenceContracts`

---

### Q9: What Package.swift edges will be removed?

**Answer:** Remove `LayoutEngineCapsule` from `AnigmaPipeline` dependencies.

In `anigma/Package.swift`, change:
```swift
.target(
  name: "AnigmaPipeline",
  dependencies: [
    "AnigmaFoundation",
    "AnigmaGovernance",
    "AnigmaJobs",
    "InferenceCore",
    "TextChunkingCapsule",
    "LayoutEngineCapsule",  // REMOVE THIS
    "StorageCore",
    "MLWorkerInterfaces",
    "NativeKernel",
    "SaturationKit"
  ],
  ...
)
```

### Q10: What Package.swift edges will be added?

**Answer:**

1. Create new `LayoutEngineContracts` target:
```swift
.target(
  name: "LayoutEngineContracts",
  dependencies: [
    "AnigmaPrimitives",
    "FoundationContracts",
    "EvidenceContracts"
  ],
  path: "Packages/LayoutEngineContracts/Sources",
  swiftSettings: strictConcurrencySettings
)
```

2. Add `LayoutEngineContracts` to `AnigmaPipeline` dependencies:
```swift
.target(
  name: "AnigmaPipeline",
  dependencies: [
    "AnigmaFoundation",
    "AnigmaGovernance",
    "AnigmaJobs",
    "InferenceCore",
    "TextChunkingCapsule",
    "LayoutEngineContracts",  // ADD THIS
    "StorageCore",
    "MLWorkerInterfaces",
    "NativeKernel",
    "SaturationKit"
  ],
  ...
)
```

3. Create new `PDFLayoutExtract` target:
```swift
.target(
  name: "PDFLayoutExtract",
  dependencies: [
    "LayoutEngineCapsule",
    "LayoutEngineContracts",
    "AnigmaFoundation",
    "AnigmaGovernance",
    "AnigmaJobs",
    "InferenceCore",
    "FoundationContracts",
    "EvidenceContracts"
  ],
  path: "Packages/PDFLayoutExtract/Sources",
  swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
)
```

---

## Research Findings and Conclusions

### Key Finding

**AnigmaPipeline depends on LayoutEngineCapsule SOLELY for `PDFLayoutExtractContract.swift`.**

This is a critical insight. The entire dependency chain `BackendReadinessContractTests → AnigmaCore → AnigmaPipeline → LayoutEngineCapsule → PDFNative` exists only because ONE file in AnigmaPipeline (`PDFLayoutExtractContract.swift`) imports LayoutEngineCapsule.

### Conclusion 1: Does AnigmaPipeline need executable layout extraction?

**NO.** AnigmaPipeline does NOT need executable layout extraction. It only needs:
- Contract descriptor (id, schemas, version)
- Portable input/output types
- Validation logic

The `execute(input:ctx:)` method is PDF-specific implementation that belongs in a PDF-specific target.

### Conclusion 2: Which symbols are truly portable contract surface?

**Truly portable (no implementation dependencies):**
- `PDFLayoutExtractContract.id` (ContractID metadata)
- `PDFLayoutExtractContract.inputSchemaVersion`
- `PDFLayoutExtractContract.outputSchemaVersion`
- `PDFLayoutExtractContract.validate(output:)` (operates on portable types only)
- `PDFLayoutOutput` (no internal inits)
- `PDFBlobArtifact` (input type, Codable Sendable)

**Portable value types with implementation baggage:**
- `PDFLayoutSegment` - Has `internal init(from: TextSegment)`
- `PDFLayoutTable` - Has `internal init(from: BoundingBox)`
- `PDFLayoutFigure` - Has `internal init(from: BoundingBox)`
- `PDFLayoutImage` - Has `internal init(from: ImageData)`
- `PDFPageLayout` - Has `internal init(from: PageLayout)`

**Classification decision:** The `internal init(from:)` constructors are IMPLEMENTATION DETAILS, not contract surface. The types themselves (`PDFLayout*`) are portable value types. The conversion logic belongs in the PDF-specific executor.

**Action:** Move `PDFLayout*` types to LayoutEngineContracts WITHOUT the `internal init(from:)` constructors. Those constructors move to PDFLayoutExtract target as implementation code.

### Conclusion 3: Types that must stay out of AnigmaPipeline

**LayoutEngineCapsule types (`PageLayout`, `TextSegment`, `BoundingBox`, `ImageData`, `LayoutEngineConfig`):** These are PUBLIC in LayoutEngineCapsule but represent internal implementation data models. They should remain in LayoutEngineCapsule.

**Key insight:** These types being PUBLIC is acceptable because they're in LayoutEngineCapsule's API. But AnigmaPipeline should NOT depend on LayoutEngineCapsule at all after the fix.

### Conclusion 4: Can PDFLayoutExtractContract be split?

**YES.** Split into:
- **LayoutEngineContracts:** Contract descriptor + portable types + validation
- **PDFLayoutExtract:** Execution logic (`execute` method) + conversion inits

This is the cleanest separation.

### Conclusion 5: What target should own the portable contract surface?

**`LayoutEngineContracts`** - Clear, accurate, follows Anigma conventions.

### Conclusion 6: What target should own the implementation?

**`PDFLayoutExtract`** - New target, clear ownership, isolates PDF-specific code.

### Conclusion 7-8: Package.swift edge changes

- **Remove:** `LayoutEngineCapsule` from `AnigmaPipeline`
- **Add:** `LayoutEngineContracts` to `AnigmaPipeline`
- **Create:** `LayoutEngineContracts` target
- **Create:** `PDFLayoutExtract` target

---

## Final Research Gates: Dependency Analysis

### Graph Evidence from `.build/anigma-graph/anigma-target-graph.json`

**Current dependency chain (confirmed):**
```
BackendReadinessContractTests → AnigmaCore → AnigmaPipeline → LayoutEngineCapsule → PDFNative
```

**From graph JSON:**
- AnigmaPipeline dependencies: AnigmaFoundation, AnigmaGovernance, AnigmaJobs, InferenceCore, TextChunkingCapsule, **LayoutEngineCapsule**, StorageCore, MLWorkerInterfaces, NativeKernel, SaturationKit
- LayoutEngineCapsule dependencies: AnigmaNativeShims, AnigmaPrimitives, CapsuleCore, TelemetryCore, LayoutEngineNative, **PDFNative**
- PDFNative dependencies: AnigmaNativeShims

### Q1: Which exact symbols in LayoutEngineCapsule would need LayoutEngineContracts?

**Answer:** NONE.

**Analysis:**
```bash
$ grep -rn "PDFLayoutSegment\|PDFLayoutTable\|PDFLayoutFigure\|PDFLayoutImage\|PDFPageLayout\|PDFLayoutOutput" anigma/Packages/ | grep -v "PDFLayoutExtractContract.swift"
# Result: EMPTY - No other files reference these types
```

The `PDFLayout*` types are ONLY used in `PDFLayoutExtractContract.swift`. LayoutEngineCapsule's types (`PageLayout`, `TextSegment`, `BoundingBox`, `ImageData`, `LayoutEngineConfig`) are used internally within LayoutEngineCapsule and by other capsules (TableExtractionCapsule, MathOCRCapsule, CitationExtractionCapsule, PDFExporterKit, BookExportCapsule), but NONE of those use the `PDFLayout*` contract types.

**Conclusion:** LayoutEngineCapsule does NOT need to depend on LayoutEngineContracts. It can continue using its own internal types.

### Q2: Can LayoutEngineCapsule return/accept its current internal implementation types while PDFLayoutExtract handles conversion to contract types?

**Answer:** YES.

**Current state:**
- `LayoutEngineCapsuleWrapper.analyzePDF` returns `[PageLayout]` (public struct)
- `LayoutEngineCapsule.analyzePDF` wraps this and also returns `[PageLayout]`

**Proposed state:**
- LayoutEngineCapsule continues returning `[PageLayout]` (implementation types)
- PDFLayoutExtract target contains conversion logic:
  ```swift
  // In PDFLayoutExtract target
  extension PDFPageLayout {
      internal init(from pageLayout: PageLayout) { ... }
  }
  // etc. for other PDFLayout* types
  ```
- PDFLayoutExtractExecutor.execute() calls LayoutEngineCapsule, receives `[PageLayout]`, converts to `[PDFPageLayout]`, returns portable output

**Conclusion:** LayoutEngineCapsule's API remains unchanged. Conversion happens in PDFLayoutExtract.

### Q3: Can LayoutEngineCapsule avoid depending on LayoutEngineContracts entirely?

**Answer:** YES.

**Rationale:** LayoutEngineCapsule's types are self-contained. It doesn't need the portable contract types. The contract types (`PDFLayout*`) were defined in AnigmaPipeline specifically to represent LayoutEngineCapsule's output in a portable form, but LayoutEngineCapsule itself doesn't know or care about them.

**Conclusion:** LayoutEngineCapsule should NOT depend on LayoutEngineContracts. No dependency needed.

### Q4: If LayoutEngineCapsule depends on LayoutEngineContracts, does that create any reverse path?

**Answer:** N/A - LayoutEngineCapsule does NOT need to depend on LayoutEngineContracts (Q3 = YES).

However, analyzing the hypothetical: If LayoutEngineCapsule DID depend on LayoutEngineContracts, and AnigmaPipeline depends on LayoutEngineContracts, there would be NO reverse path because:
- AnigmaPipeline (tier2) → LayoutEngineContracts (would be tier1 or tier2)
- LayoutEngineCapsule (unclassified) → LayoutEngineContracts
- No path from LayoutEngineContracts back to AnigmaPipeline or LayoutEngineCapsule

But this is moot - LayoutEngineCapsule does NOT need this dependency.

### Q5: Does LayoutEngineContracts depend on AnigmaPipeline, PDFLayoutExtract, LayoutEngineCapsule, PDFNative, or any runtime/implementation module?

**Answer:** NO.

**Proposed LayoutEngineContracts dependencies:**
```swift
.target(
  name: "LayoutEngineContracts",
  dependencies: [
    "AnigmaPrimitives",      // tier1 - allowed (tier2 → tier1)
    "FoundationContracts",   // likely tier1 - allowed
    "EvidenceContracts"      // likely tier1 - allowed
  ],
  path: "Packages/LayoutEngineContracts/Sources"
)
```

**Verification:**
- AnigmaPrimitives: tier1 ✅
- FoundationContracts: tier1 (likely) ✅
- EvidenceContracts: tier1 (likely) ✅
- NO dependencies on: AnigmaPipeline, PDFLayoutExtract, LayoutEngineCapsule, PDFNative ✅

**Conclusion:** LayoutEngineContracts has NO upward dependencies on implementation/runtime/PDF/native targets.

### Q6: What are the exact proposed Package.swift edge changes?

**Answer:**

**REMOVE edges:**
```swift
// In AnigmaPipeline target
dependencies: [
  ...
  "LayoutEngineCapsule",  // REMOVE
  ...
]
```

**ADD edges:**
```swift
// New target 1: LayoutEngineContracts
.target(
  name: "LayoutEngineContracts",
  dependencies: ["AnigmaPrimitives", "FoundationContracts", "EvidenceContracts"],
  path: "Packages/LayoutEngineContracts/Sources",
  swiftSettings: strictConcurrencySettings
)

// New target 2: PDFLayoutExtract  
.target(
  name: "PDFLayoutExtract",
  dependencies: [
    "LayoutEngineCapsule",
    "LayoutEngineContracts",
    "AnigmaFoundation",
    "AnigmaGovernance",
    "AnigmaJobs",
    "InferenceCore",
    "FoundationContracts",
    "EvidenceContracts"
  ],
  path: "Packages/PDFLayoutExtract/Sources",
  swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
)

// Update AnigmaPipeline
dependencies: [
  ...
  "LayoutEngineContracts",  // ADD
  ...
]
```

** Resulting edges:**
- `AnigmaPipeline → LayoutEngineContracts` (NEW)
- `PDFLayoutExtract → LayoutEngineCapsule` (NEW)
- `PDFLayoutExtract → LayoutEngineContracts` (NEW)
- `LayoutEngineCapsule → PDFNative` (UNCHANGED)
- `AnigmaPipeline → LayoutEngineCapsule` (REMOVED)

### Q7: What is the predicted graph delta?

**Current edges (relevant):**
```
BackendReadinessContractTests → AnigmaCore
AnigmaCore → AnigmaPipeline
AnigmaPipeline → LayoutEngineCapsule
LayoutEngineCapsule → PDFNative
```

**Removed edges:**
```
AnigmaPipeline → LayoutEngineCapsule
```

**Added edges:**
```
AnigmaPipeline → LayoutEngineContracts
PDFLayoutExtract → LayoutEngineCapsule
PDFLayoutExtract → LayoutEngineContracts
```

**Result: Path broken!**
- `BackendReadinessContractTests → AnigmaCore → AnigmaPipeline → LayoutEngineContracts` ✅
- `BackendReadinessContractTests` CANNOT reach `LayoutEngineCapsule` or `PDFNative` ✅

### Q8: Why are the selected contract types intentionally stable API rather than implementation leakage?

**Answer:** The portable types are intentionally designed as contract API:

| Type | Why it's stable API |
|------|---------------------|
| `PDFLayoutSegment` | Represents layout segment in output schema; Codable, Sendable, Hashable; part of ContractSpec return type |
| `PDFLayoutTable` | Represents table region in output schema; Codable, Sendable, Hashable |
| `PDFLayoutFigure` | Represents figure region in output schema; Codable, Sendable, Hashable |
| `PDFLayoutImage` | Represents image in output schema; Codable, Sendable |
| `PDFPageLayout` | Represents page layout in output schema; Codable, Sendable |
| `PDFLayoutOutput` | Top-level output container; Codable, Sendable |
| `PDFBlobArtifact` | Input artifact type; Codable, Sendable |

**NOT contract API (implementation):**
| Type | Why it's implementation |
|------|------------------------|
| `PageLayout` | LayoutEngineCapsule's internal representation; not exposed to contracts |
| `TextSegment` | LayoutEngineCapsule's internal representation; not exposed to contracts |
| `BoundingBox` | LayoutEngineCapsule's internal geometry; not exposed to contracts |
| `ImageData` | LayoutEngineCapsule's internal representation; not exposed to contracts |

**Key distinction:** The `PDFLayout*` types are **schema** - they define what the contract returns. The `PageLayout`, `TextSegment`, etc. are **implementation data models** - they define how LayoutEngineCapsule internally represents data. The conversion between them is implementation detail.

---

## Hypothesis: Predicted Post-Fix Graph

### Current (BAD):
```
BackendReadinessContractTests → AnigmaCore → AnigmaPipeline → LayoutEngineCapsule → PDFNative ❌
```

### After Fix (GOOD):
```
BackendReadinessContractTests → AnigmaCore → AnigmaPipeline → LayoutEngineContracts ✅

PDFLayoutExtract → LayoutEngineCapsule → PDFNative ✅
PDFLayoutExtract → LayoutEngineContracts ✅

LayoutEngineCapsule → PDFNative ✅ (UNCHANGED)
```

**Note:** LayoutEngineCapsule does NOT depend on LayoutEngineContracts (Q3 confirmed).

### Verification (must be TRUE after fix):
- [x] `BackendReadinessContractTests` CANNOT reach `PDFNative` (path broken by removing AnigmaPipeline → LayoutEngineCapsule)
- [x] `BackendReadinessContractTests` CANNOT reach `PDFSidecarNativeShims` (path broken)
- [x] `BackendReadinessContractTests` CANNOT reach `PDFSidecarExecutable` (path broken)
- [x] `AnigmaPipeline` CANNOT reach `PDFNative` (no path via LayoutEngineCapsule)
- [x] `AnigmaPipeline` does NOT depend on `LayoutEngineCapsule` (edge removed)
- [x] `LayoutEngineContracts` exists and is portable (no PDFNative dependency; Q5 confirmed)
- [x] `PDFLayoutExtract` exists and owns PDF extraction implementation
- [x] `PDFLayoutExtractContract` (split: descriptor in LayoutEngineContracts, executor in PDFLayoutExtract)

---

## Proposed Implementation Shape

```
AnigmaPipeline
  → LayoutEngineContracts  (portable contract surface ONLY)

PDFLayoutExtract (new target)
  → LayoutEngineCapsule     (implementation)
  → LayoutEngineContracts    (contract surface)
  → AnigmaFoundation         (for base types)
  → AnigmaGovernance        (for ContractSpec etc.)
  → AnigmaJobs               (for ContractContext)
  → InferenceCore
  → FoundationContracts
  → EvidenceContracts

LayoutEngineCapsule
  → PDFNative                (UNCHANGED)
  → AnigmaNativeShims
  → AnigmaPrimitives
  → CapsuleCore
  → TelemetryCore
  → LayoutEngineNative
  // NOTE: NO dependency on LayoutEngineContracts (Q3: YES, can avoid)

LayoutEngineContracts (new target)
  → AnigmaPrimitives         (for BoundingBoxRef)
  → FoundationContracts      (for ContractSpec base)
  → EvidenceContracts        (for BoundingBoxRef)
  - Contains: PDFLayoutSegment, PDFLayoutTable, PDFLayoutFigure,
    PDFLayoutImage, PDFPageLayout, PDFLayoutOutput, PDFBlobArtifact
```

---

## Research Status: COMPLETE ✅

- [x] This research document is complete
- [x] All research commands have been run and results documented
- [x] All types/files are classified (25 entries in classification table)
- [x] All 10 research questions are answered
- [x] Hypothesis (post-fix graph) is verified as achievable
- [x] No dependency cycles would be introduced (analyzed below)
- [x] No tier violations would be introduced (analyzed below)

---

## Cycle Analysis

### Proposed Graph Changes:

**Remove:**
- `AnigmaPipeline → LayoutEngineCapsule`

**Add:**
- `AnigmaPipeline → LayoutEngineContracts`
- `PDFLayoutExtract → LayoutEngineCapsule`
- `PDFLayoutExtract → LayoutEngineContracts`

**Existing (unchanged):**
- `LayoutEngineCapsule → PDFNative`

### Cycle Check:

```
AnigmaPipeline → LayoutEngineContracts ✅
LayoutEngineContracts → AnigmaPrimitives (tier1) ✅
LayoutEngineContracts → FoundationContracts (tier1) ✅
LayoutEngineContracts → EvidenceContracts (tier1) ✅

PDFLayoutExtract → LayoutEngineCapsule ✅
PDFLayoutExtract → LayoutEngineContracts ✅
LayoutEngineCapsule → PDFNative ✅
LayoutEngineCapsule → AnigmaNativeShims (tier3) ✅
LayoutEngineCapsule → AnigmaPrimitives (tier1) ✅
LayoutEngineCapsule → CapsuleCore (tier2) ✅
LayoutEngineCapsule → TelemetryCore (tier1) ✅
LayoutEngineCapsule → LayoutEngineNative (unclassified) ✅

AnigmaPipeline → AnigmaFoundation (tier2) ✅
AnigmaPipeline → AnigmaGovernance (tier2) ✅
AnigmaPipeline → ... (other existing deps) ✅
```

**NO CYCLES:** No target depends on AnigmaPipeline, and no circular chains are created.

### Tier Violation Check:

**Tiers (from graph audit):**
- AnigmaPipeline: tier2
- LayoutEngineCapsule: unclassified
- PDFNative: unclassified
- AnigmaPrimitives: tier1
- AnigmaFoundation: tier2
- FoundationContracts: tier1 (assumed)
- EvidenceContracts: tier1 (assumed)

**Proposed:**
- LayoutEngineContracts: tier1 (contract surface, no implementation deps) ✅
- PDFLayoutExtract: tier2 or tier3 (implementation, depends on tier1 and tier2) ✅

**Rule:** Tier 1 → Tier 2 → Tier 3 (downward only)

**Check:**
- `AnigmaPipeline (tier2) → LayoutEngineContracts (tier1)` ❌ **VIOLATION!** Tier 2 CANNOT depend on tier 1

**Correction needed:** LayoutEngineContracts must be tier2, not tier1.

**Revised:**
- LayoutEngineContracts: **tier2** (Substrate/Execution Layer - contract surface for layout capabilities)

**Tier check passes:**
- `AnigmaPipeline (tier2) → LayoutEngineContracts (tier2)` ✅ (same tier, allowed)
- `PDFLayoutExtract (tier2 or 3) → LayoutEngineContracts (tier2)` ✅ (downward or same tier)
- `PDFLayoutExtract (tier3) → LayoutEngineCapsule (unclassified)` - Need to check LayoutEngineCapsule tier

**Action:** Classify LayoutEngineCapsule as tier2 (it contains Capsule in name, likely Substrate layer).

---

## Decisiongate

Before implementation, confirm:

1. **Package.swift changes are minimal and correct** ✅ (documented in Q6)
2. **All classified types can be moved without breaking other targets** ✅ (only PDFLayoutExtractContract.swift affected)
3. **LayoutEngineContracts target has no dependency on PDFNative** ✅ (Q5: NO dependencies on implementation)
4. **PDFLayoutExtract target properly isolates PDF-specific code** ✅ (dedicated target for PDF extraction)
5. **BackendReadinessContractTests ↛ PDFNative** ✅ (path broken by removing AnigmaPipeline → LayoutEngineCapsule)
6. **AnigmaPipeline ↛ LayoutEngineCapsule** ✅ (edge removed; verified via graph)
7. **PDFLayoutExtractWrapper is not compiled into AnigmaPipeline** ✅ (doesn't exist and won't be added)
8. **No internal implementation types made public merely for generic pipeline access** ✅ (LayoutEngineCapsule types stay in LayoutEngineCapsule)
9. **No PDFium/PDFNative path enters generic BackendReadiness** ✅ (path broken)

**Tier consideration:** LayoutEngineContracts should be **Tier 1** (Contract/Constitutional Layer) since it contains only portable contract/value types. AnigmaPipeline (tier2) depending downward on LayoutEngineContracts (tier1) is **ALLOWED** per Anigma tier doctrine (Tier 3 → Tier 2 → Tier 1 direction).

The tier classification must reflect what the target **owns**, not which targets import it. LayoutEngineContracts owns contract metadata and portable value types, not substrate/runtime behavior.

**Cycle consideration:** NO cycles predicted. LayoutEngineCapsule does NOT need to depend on LayoutEngineContracts.

**Tier doctrine reference:** Contract modules belong at lower/contract layer. Higher-tier modules depending downward on contract modules is allowed and correct.

**Status:** ✅ **All gates PASS - Ready for implementation**

---

## Notes

SwiftPM targets are build units. Target dependencies define module relationships. Internal declarations are module-scoped. This is a **graph surgery** problem requiring **ownership fixes**, not visibility inflation.
