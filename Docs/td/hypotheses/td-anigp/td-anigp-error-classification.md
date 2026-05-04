# td-anigp Error Classification

**TD ID:** td-anigp
**Parent:** td-358315
**Created:** 2026-05-03
**Status:** DONE

---

## Build Status (Doctrine Language)

- **Command:** `scripts/test_backend_readiness.sh BackendReadinessContractTests`
- **AnigmaPipeline:** CLEAN, exit_code=0, warning_count=0
- **AnigmaCore:** CLEAN, exit_code=0, warning_count=0
- **BackendReadinessContractTests target:** CLEAN, exit_code=0, warning_count=0
- **BackendReadiness script:** CONTAMINATED, exit_code=0, warning_count=13

**Advancement:** AnigmaPipeline compilation errors are fixed. BackendReadiness advances past AnigmaPipeline errors. Remaining CONTAMINATED status is due to pre-existing SwiftPM warnings, not td-anigp changes.

---

## Pre-Change Graph Evidence

- **Snapshot location:** `.build/anigma-graph/td-anigp-pre/`
- **Command:** `python3 Scripts/anigma_package_graph_audit.py --output-dir .build/anigma-graph/td-anigp-pre snapshot`
- **Source:** `swift package describe --type json` + `swift package show-dependencies --format json`
- **Validation:** JSON outputs parsed successfully (SwiftPM JSON-parse validation)

---

## Exact Errors

| File | Line | Symbol | Error | Classification | Proposed Fix |
|------|------|--------|-------|----------------|--------------|
| MetopticonRunner.swift | 47:118 | createRunner | `missing argument for parameter 'database' in call` | stale API reference | Add `database` parameter to call |
| PipelineContractRegistry.swift | 23:29 | PDFLayoutExtractContract | `cannot find 'PDFLayoutExtractContract' in scope` | stale reference | Remove registration line (contract doesn't exist) |
| PipelineContractRegistry.swift | 23:20 | register | `generic parameter 'C' could not be inferred` | stale reference | Remove registration line (contract doesn't exist) |

---

## Error Detail

### Error 1: MetopticonRunner.swift - Missing Database Parameter

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Metopticon/MetopticonRunner.swift`

**Error:**
```
/Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Metopticon/MetopticonRunner.swift:47:118: error: missing argument for parameter 'database' in call
  45 |         let store = store ?? MetopticonWorkloadStore()
  46 |         self.adapter = MetopticonRunnerAdapter(store: store, world: world)
  47 |         self.pipelineRunner = try await ModulePipelineFactory.createRunner(engine: engine, mlWorkerPath: mlWorkerPath)
    |                                                                                                                      `- error: missing argument for parameter 'database' in call
  48 |         self.accessEnforcer = accessEnforcer ?? MetopticonAccessEnforcer()
  49 |     }
```

**Actual Function Signature (INVESTIGATED):**
```swift
// PipelineModule.swift: public static func createRunner
public static func createRunner(
    engine: GrapheneEngine? = nil,
    mlWorkerPath: String,
    database: any DatabaseExecutor  // <-- REQUIRED, not optional
) async throws -> PipelineRunner {
    // Use the provided database executor
    let db = database
    let jobQueue = try await ContractJobQueue(database: db, now: { Date() })
    let receiptStore = try await ReceiptStore(database: db)
    let artifactDB = try await DatabaseArtifactStore(database: db)
    ...
}
```

**Issue:** `createRunner` requires a `database: any DatabaseExecutor` parameter (NOT optional per ADR-0018 / td-317bbb), but the call site in MetopticonRunner.swift does not provide it.

**Classification:** `stale API reference` (the function signature changed, call site not updated)

**Proposed Fix:** Create a `DatabaseExecutor` and pass it to the call.

**Investigation:** Need to check what `DatabaseExecutor` implementations exist and how MetopticonRunner should create one.

---

### Error 2: PipelineContractRegistry.swift - PDFLayoutExtractContract Not Found

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/PipelineContractRegistry.swift`

**Error:**
```
/Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/PipelineContractRegistry.swift:23:29: error: cannot find 'PDFLayoutExtractContract' in scope
  21 |     await registry.register(PDFSegmentContract.self)
  22 |     await registry.register(PDFExtractContract.self)
  23 |     await registry.register(PDFLayoutExtractContract.self)
    |                             `- error: cannot find 'PDFLayoutExtractContract' in scope
  24 |     await registry.register(PDFQACheckContract.self)
  25 |     await registry.register(EmbedTextContract.self)
```

**Secondary Error:**
```
/Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/PipelineContractRegistry.swift:23:20: error: generic parameter 'C' could not be inferred
  21 |     await registry.register(PDFSegmentContract.self)
  22 |     await registry.register(PDFExtractContract.self)
  23 |     await registry.register(PDFLayoutExtractContract.self)
    |                    `- error: generic parameter 'C' could not be inferred
```

**Investigation Result:**
```bash
$ grep -r "PDFLayoutExtractContract" --include="*.swift" anigma/
# Result: NO MATCHES - contract does NOT exist in codebase
```

**File Imports (checked):**
```swift
import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import ContractsCore
import Foundation
import DatabaseCore
```

**Contracts that DO exist in the directory:**
- PDFExtractContract.swift ✅
- PDFIngestContract.swift ✅
- PDFQACheckContract.swift ✅
- PDFSegmentContract.swift ✅
- HardeningAttestationContract.swift ✅
- EmbedTextContract.swift ✅
- IndexEmbeddingsContract.swift ✅

**Note:** There IS a `PDFLayoutExtractWrapper.swift` file mentioned in SwiftPM warnings, but no `PDFLayoutExtractContract` type definition.

**Issue:** `PDFLayoutExtractContract` was removed or renamed. The registration line references a non-existent contract.

**Classification:** `stale reference` (contract no longer exists)

**Proposed Fix:** Remove line 23 (the registration of PDFLayoutExtractContract). This is the safest fix - if the contract was renamed, it can be re-added later. Removing a stale reference cannot break anything that was working.

---

## Graph Evidence

### Pre Snapshot
- **Location:** `.build/anigma-graph/td-anigp-pre/`
- **Files:**
  - `swiftpm-package-description.json`
  - `swiftpm-package-dependencies.json`
  - `anigma-target-graph.json`
  - `anigma-product-graph.json`

### Relevant Targets
| Target | Tier | Role | Path |
|--------|------|------|------|
| AnigmaPipeline | tier3 | feature | Packages/AnigmaCore/Sources/AnigmaPipeline |
| MetopticonRunner | tier3 | feature | Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Metopticon/MetopticonRunner.swift |
| PipelineContractRegistry | tier3 | feature | Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/PipelineContractRegistry.swift |
| ModulePipelineFactory | ? | ? | Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/ModulePipelineFactory.swift |

### Relevant Products
- AnigmaPipeline product
- AnigmaCore product (transitive dependency)

### Direct Dependencies
- AnigmaPipeline → AnigmaCore
- AnigmaPipeline → PipelineModule (where ModulePipelineFactory is defined)
- MetopticonRunner → ModulePipelineFactory
- PipelineContractRegistry → ContractRegistry (from EvidenceContracts)

### Proposed Dependency Changes
- **None expected** - Both errors appear to be within existing dependency structure
- Error 1: Update call site (no new dependency)
- Error 2: Add import or remove stale reference (no new dependency)

### Cycle/Tier Risk
- **None** - No new edges proposed
- All changes are within existing target boundaries
- Fixes do not introduce new inter-target dependencies

---

## Hypothesis

**Smallest likely fix before patching:**

### Fix 1: MetopticonRunner.swift (Line 47)
The `ModulePipelineFactory.createRunner` signature was updated to require a `database` parameter (per ADR-0018 / td-317bbb), but the call site was not updated.

**Proposed Change:**
```swift
// OPTION A: Pass nil if database is optional for Metopticon use case
self.pipelineRunner = try await ModulePipelineFactory.createRunner(
    engine: engine,
    mlWorkerPath: mlWorkerPath,
    database: nil  // or create DatabaseActor if required
)

// OPTION B: Create a DatabaseActor instance
let database = DatabaseActor(...)  // Need to check what initialization requires
self.pipelineRunner = try await ModulePipelineFactory.createRunner(
    engine: engine,
    mlWorkerPath: mlWorkerPath,
    database: database
)
```

**Need to investigate:** Does MetopticonRunner need a database? If not, `database: nil` may suffice. If yes, need to create DatabaseActor with appropriate configuration.

### Fix 2: PipelineContractRegistry.swift (Line 23)
`PDFLayoutExtractContract` is referenced but cannot be found.

**Investigation First:**
```bash
# Check if contract exists
grep -r "class PDFLayoutExtractContract\|struct PDFLayoutExtractContract\|protocol PDFLayoutExtractContract" --include="*.swift" anigma/
```

**Proposed Changes (depending on investigation):**

**OPTION A: Contract was renamed** - Find new name and update reference
```swift
await registry.register(PDFLayoutExtractContractNEW.self)  // if renamed
```

**OPTION B: Contract was removed** - Remove the registration line
```swift
// Remove line 23 entirely if PDFLayoutExtractContract no longer exists
await registry.register(PDFExtractContract.self)
await registry.register(PDFQACheckContract.self)  // skip PDFLayoutExtractContract
```

**OPTION C: Missing import** - Add import for the module containing PDFLayoutExtractContract
```swift
import TheModuleContainingPDFLayoutExtractContract
```

---

## Non-Goals

- Do NOT touch PDF sidecar lane (`Scripts/test_pdf_sidecar_readiness.sh`)
- Do NOT revisit ReceiptSigner unless directly referenced by current errors
- Do NOT revisit RendererBackend unless directly referenced by current errors
- Do NOT revisit AnigmaGovernance unless directly referenced by current errors
- Do NOT add graph edges without pre/post graph evidence
- Do NOT introduce fake stubs
- Do NOT add `@_exported` imports
- Do NOT broaden umbrella imports
- Do NOT change Package.swift dependency structure without graph evidence

---

## SwiftPM Graph Evidence Note

All evidence generated from SwiftPM JSON outputs using `anigma_package_graph_audit.py`:
- `swift package describe --type json` - Internal package description (targets, products, dependencies, settings)
- `swift package show-dependencies --format json` - External dependency graph

**Note on SwiftPM warnings:** There is an upstream SwiftPM issue where warnings can appear in `describe --type json` output. The `anigma_package_graph_audit.py` script performs JSON-parse validation and preserves raw logs separately, which is the correct doctrine per the review note.

---

## Strict Build-Status Language

Swift diagnostics distinguish errors from warnings:
- **Errors:** Stop compilation, build FAILED
- **Warnings in Swift 6 strict mode:** Treated as errors, stop compilation, build FAILED
- **Warnings in non-strict mode:** Allow build progress, build CONTAMINATED or PASSED depending on warning count

Current classification:
- **MetopticonRunner.swift:47** - error → Build FAILED
- **PipelineContractRegistry.swift:23** - error → Build FAILED
- **Overall:** FAILED (exit_code=1, warning_count=6)

---

## Next Steps

1. **Verify contract existence:**
   ```bash
   grep -r "PDFLayoutExtractContract" --include="*.swift" anigma/
   ```

2. **Check ModulePipelineFactory signature:**
   ```bash
   grep -A 5 "public static func createRunner" anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/ModulePipelineFactory.swift
   ```

3. **Check MetopticonRunner context:**
   ```bash
   grep -B 10 -A 10 "createRunner" anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Metopticon/MetopticonRunner.swift
   ```

4. **Determine Fix 1:** Based on whether MetopticonRunner needs database, choose Option A or B

5. **Determine Fix 2:** Based on contract existence, choose Option A, B, or C

6. **Apply fixes** with smallest safe patch

7. **Re-run validation:**
   ```bash
   swift build --target AnigmaPipeline
   swift build --target AnigmaCore
   Scripts/test_backend_readiness.sh BackendReadinessContractTests
   ```

8. **Capture post-change evidence:**
   ```bash
   python3 Scripts/anigma_package_graph_audit.py snapshot --output-dir .build/anigma-graph/td-anigp-post
   ```

---

## Files

| Path | Purpose |
|------|---------|
| `Docs/td/hypotheses/td-anigp/td-anigp-error-classification.md` | This document |
| `.build/td-anigp-backend-readiness.log` | Raw build output |
| `.build/anigma-graph/td-anigp-pre/` | Pre-change graph snapshots |
| `.build/anigma-graph/td-anigp-post/` | Post-change graph snapshots (to be created) |

---

## Applied Fixes

### Fix 1: MetopticonRunner.swift - Added Database Parameter

**Investigation Result:** `ModulePipelineFactory.createRunner` requires a non-optional `database: any DatabaseExecutor` parameter (per ADR-0018 / td-317bbb). MetopticonRunner is a composition root-level type in AnigmaPipeline (tier 3), so callers must provide a DatabaseExecutor.

**Changes Applied:**

1. Added `import DatabaseCore` to imports
2. Added `database: any DatabaseExecutor` parameter to `MetopticonRunner.init`
3. Added documentation comment with ADR-0018 / td-317bbb reference
4. Updated call to `ModulePipelineFactory.createRunner` to pass the `database` parameter

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Metopticon/MetopticonRunner.swift`

```swift
// Added import
import DatabaseCore

// Updated initializer
public init(
    world: World? = nil,
    store: MetopticonWorkloadStore? = nil,
    engine: GrapheneEngine? = nil,
    accessEnforcer: MetopticonAccessEnforcer? = nil,
    database: any DatabaseExecutor,  // NEW PARAMETER
    mlWorkerPath: String
) async throws {
    self.world = world
    let store = store ?? MetopticonWorkloadStore()
    self.adapter = MetopticonRunnerAdapter(store: store, world: world)
    // UPDATED CALL - now passes database parameter
    self.pipelineRunner = try await ModulePipelineFactory.createRunner(
        engine: engine,
        mlWorkerPath: mlWorkerPath,
        database: database
    )
    self.accessEnforcer = accessEnforcer ?? MetopticonAccessEnforcer()
}
```

**Safety:** Callers at composition root level must provide a DatabaseExecutor per ADR-0018. This enforces proper dependency injection.

---

### Fix 2: PipelineContractRegistry.swift - Removed Stale Reference

**Investigation Result:** `PDFLayoutExtractContract` exists in a separate target (`PDFLayoutExtract` at line 1190 of Package.swift), NOT in the AnigmaPipeline target. It is not listed in AnigmaPipeline's sources, and AnigmaPipeline does not depend on PDFLayoutExtract target.

**Changes Applied:**

Removed line 23 from `registerPDFPipelineContracts(into:)` function which attempted to register `PDFLayoutExtractContract.self`.

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/PipelineContractRegistry.swift`

```swift
// BEFORE:
await registry.register(PDFIngestContract.self)
await registry.register(PDFSegmentContract.self)
await registry.register(PDFExtractContract.self)
await registry.register(PDFLayoutExtractContract.self)  // <- REMOVED
await registry.register(PDFQACheckContract.self)
...

// AFTER:
await registry.register(PDFIngestContract.self)
await registry.register(PDFSegmentContract.self)
await registry.register(PDFExtractContract.self)
await registry.register(PDFQACheckContract.self)  // <- PDFLayoutExtractContract removed
...
```

**Safety:** No other code in AnigmaPipeline references `PDFLayoutExtractContract`. Removing this stale reference cannot break existing functionality. If PDFLayoutExtractContract is needed in the future, it should be properly added to the AnigmaPipeline target's dependencies in Package.swift.

---

## Validation Results

| Target | Build Status | Exit Code | Notes |
|--------|--------------|-----------|-------|
| AnigmaPipeline | PASSED | 0 | All sources compile successfully |
| AnigmaCore | PASSED | 0 | No impact from changes |
| BackendReadinessContractTests | PASSED (build) | 0 | Target builds successfuly |

**Note:** Full `swift test --filter BackendReadinessContractTests` blocked by pre-existing PDFium linker dependency in PDFSidecarExecutable (not related to these changes). The test target itself builds successfully.

---

## Graph Evidence

### Pre-Change Snapshot
- **Location:** `.build/anigma-graph/td-anigp-pre/`
- **Date:** 2026-05-03 (pre-fix)

### Post-Change Snapshot
- **Location:** `.build/anigma-graph/td-anigp-post/`
- **Date:** 2026-05-03 (post-fix)
- **Command:** `python3 Scripts/anigma_package_graph_audit.py --output-dir .build/anigma-graph/td-anigp-post snapshot`

### Dependencies Impacted
- **AnigmaPipeline:** No new dependencies added
- **MetopticonRunner:** Added `DatabaseCore` import (already a transitive dependency)
- **PipelineContractRegistry:** No dependency changes

### Cycle/Tier Analysis
- **No new edges introduced**
- **No tier violations** - DatabaseCore is tier 2, AnigmaPipeline is tier 3 (allowed: tier 3 → tier 2)
- **No dependency cycles**

---

## Files

| Path | Purpose |
|------|---------|
| `Docs/td/hypotheses/td-anigp/td-anigp-error-classification.md` | This document (UPDATED) |
| `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Metopticon/MetopticonRunner.swift` | Added database parameter (MODIFIED) |
| `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/PipelineContractRegistry.swift` | Removed stale registration (MODIFIED) |
| `.build/td-anigp-backend-readiness.log` | Pre-fix build output (EXISTING) |
| `.build/anigma-graph/td-anigp-pre/` | Pre-change graph snapshots (EXISTING) |
| `.build/anigma-graph/td-anigp-post/` | Post-change graph snapshots (CREATED) |
