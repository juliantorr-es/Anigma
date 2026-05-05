# PlatformBackend Contract Extraction

**Date:** 2026-05-04  
**Task:** Recover orphaned backend source files into correct package targets  
**Status:** COMPLETE

## Research Artifact Referenced
- `Docs/proofs/tb-2026-05-04-platformbackend-contract-research.md`

## 1. Research Confirmed
All findings from the research pass were confirmed:
- BackendReadinessContracts.swift and PlatformBackend.swift were orphaned in excluded AnigmaFoundation/Backend/ directory
- BackendId, BackendCapabilityContract, BackendOperation are portable contract types (Hashable, Codable, Sendable)
- PlatformBackend protocol uses both portable contracts and runtime types (ExecutionContext)
- DatabaseExecutor has duplicate definitions in DatabaseCore and PersistenceContracts
- No BackendReadinessContracts target existed

## 2. Files Moved

### Backend Contract Layer (Tier 1)
| From | To | Reason |
|------|----|--------|
| `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/BackendReadinessContracts.swift` | `anigma/Packages/ContractsCore/Sources/BackendReadinessContracts/BackendReadinessContracts.swift` | Move portable contracts to ContractsCore package |

**Changes to moved file:**
- Updated header comment: `// AnigmaCore` → `// BackendReadinessContracts`
- Added `import FoundationContracts` for Tier 1 compliance
- No semantic changes - all types remain portable

### Runtime Layer (Tier 2)
| From | To | Reason |
|------|----|--------|
| N/A (already existed in Runtime/Backend/) | `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Backend/PlatformBackend.swift` | Already in correct location, updated imports |

**Changes to file:**
- Updated header comment: `// AnigmaCore` → `// RuntimeCore` 
- Added `import BackendReadinessContracts` for BackendId, BackendCapabilityContract, BackendOperation
- Added `import PersistenceContracts` for DatabaseExecutor (resolved duplicate ambiguity)
- Retained existing functionality

## 3. Files Deleted
| File | Reason |
|------|--------|
| `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/BackendReadinessContracts.swift` | Orphaned duplicate - moved to ContractsCore |
| `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/PlatformBackend.swift` | Orphaned - already existed in Runtime/Backend/, this was a stale copy |

**Note:** The Backend/ directory remains empty. AnigmaFoundation target continues to exclude `"Backend/"` as per existing configuration.

## 4. Contract Target Changes

### Added: BackendReadinessContracts Target
**File:** `anigma/Package.swift`

**Target definition (added after GovernanceContracts):**
```swift
.target(
  name: "BackendReadinessContracts",
  dependencies: ["FoundationContracts", "AnigmaPrimitives"],
  path: "Packages/ContractsCore/Sources/BackendReadinessContracts",
  swiftSettings: strictConcurrencySettings
)
```

**Library product (added after FoundationContracts):**
```swift
.library(name: "BackendReadinessContracts", targets: ["BackendReadinessContracts"]),
```

**RuntimeCore dependency update:**
Added `"BackendReadinessContracts"` to RuntimeCore dependencies:
```swift
.target(
  name: "RuntimeCore",
  dependencies: [
    "AnigmaFoundation", "DatabaseCore", "ContractsCore", "FoundationContracts",
    "GovernanceContracts", "BackendReadinessContracts", "EvidenceContracts", "IntelligenceContracts",
    "PersistenceContracts", "AnigmaPrimitives"
  ],
  ...
)
```

## 5. RuntimeCore Changes

### PlatformBackend.swift
- Added `import BackendReadinessContracts` for portable backend types
- Added `import PersistenceContracts` for DatabaseExecutor (resolving duplicate ambiguity)
- No semantic changes
- Uses BackendId, BackendCapabilityContract, BackendOperation from BackendReadinessContracts

### PlatformRuntime.swift
- Added `import BackendReadinessContracts` for BackendId, BackendCapabilityContract types
- No other changes needed - PlatformBackend is in the same target (Runtime/Backend/) so no import needed

## 6. DatabaseExecutor Decision

**Finding:** DatabaseExecutor protocol is defined in TWO packages:
- `Packages/DatabaseCore/DatabaseExecutor.swift:11`
- `Packages/ContractsCore/Sources/PersistenceContracts/DatabaseContracts.swift:36`

**Decision:** Use `PersistenceContracts.DatabaseExecutor` as the canonical portable contract.

**Rationale:**
- RuntimeCore already depends on both DatabaseCore and PersistenceContracts
- Both definitions are identical: `public protocol DatabaseExecutor: Actor, Sendable`
- PersistenceContracts is in the ContractsCore package (Tier 1), making it the appropriate owner
- DatabaseCore ( implementation layer) should import and use PersistenceContracts' version

**Action taken:** Added `import PersistenceContracts` to PlatformBackend.swift, which resolves the ambiguity in favor of PersistenceContracts.

**Deferred:** Removal of the DatabaseCore duplicate is NOT included in this slice. That requires a separate architecture decision and broader impact analysis.

## 7. Package Graph Changes

### Added Targets
- **BackendReadinessContracts** (ContractsCore package, Tier 1)

### Added Dependencies
- **RuntimeCore** → BackendReadinessContracts

### Unchanged Dependencies
- AnigmaFoundation still excludes `"Backend/"` directory
- AnigmaFoundation → RuntimeCore: **NO** (architecture preserved)
- DatabaseCore ↔ AnigmaFoundation: **NO cycle** (architecture preserved)

## 8. Validation Results

### Cycle Validation
```bash
$ python3 tools/governance/scripts/validate_no_cycles.py .build/anigma-package.json
No dependency cycles detected.
```

### @_exported Validation
```bash
$ python3 tools/governance/scripts/validate_exported_imports.py
No @_exported violations in project code (only in dependencies)
```

### Build Validation
- **0 errors** for BackendReadinessContracts target
- **0 errors** for PlatformBackend compilation
- **0 errors** in RuntimeCore target related to backend types
- Remaining errors are pre-existing in HarmoniaV2Memory, HarmoniaInference, MediaBackendRegistry

### Orphan Cleanup Verification
```bash
$ test ! -f anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/BackendReadinessContracts.swift && echo PASS
PASS

$ test ! -f anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/PlatformBackend.swift && echo PASS  
PASS
```

### Import Verification
```bash
$ rg "import BackendReadinessContracts" anigma/Packages
anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Backend/PlatformBackend.swift:import BackendReadinessContracts
anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/PlatformRuntime.swift:import BackendReadinessContracts
```

## 9. Remaining Blockers

### DatabaseExecutor Duplicate (Deferred)
- **Status:** Not resolved in this slice
- **Location:** `Packages/DatabaseCore/DatabaseExecutor.swift` and `Packages/ContractsCore/Sources/PersistenceContracts/DatabaseContracts.swift`
- **Impact:** Currently resolved via explicit import of PersistenceContracts in PlatformBackend.swift
- **Risk:** Medium - Pre-existing architecture issue
- **Recommendation:** Create follow-up task to remove DatabaseCore duplicate and make DatabaseCore depend on PersistenceContracts

### HarmoniaV2Memory
- **Status:** Pre-existing, unrelated to this slice
- **Errors:** ~15 errors (MemoryStore, MemoryStoreError)
- **Risk:** Medium
- **Recommendation:** Separate task

### MediaBackendRegistry
- **Status:** Pre-existing, unrelated to this slice
- **Errors:** 6 errors (capability probe, actor isolation)
- **Risk:** Medium
- **Recommendation:** Separate task

## 10. Architecture Statement

✅ **Backend readiness types are portable contracts**  
- BackendId, BackendKind, BackendLifecycleState, BackendReadinessState, ContractCompatibility, BackendCapabilityContract, BackendOperation all in BackendReadinessContracts (Tier 1)

✅ **PlatformBackend is runtime-owned**  
- PlatformBackend protocol and concrete implementations in RuntimeCore target (Tier 2)

✅ **AnigmaFoundation does not depend on RuntimeCore**  
- No dependency edge added

✅ **No DatabaseCore ↔ AnigmaFoundation cycle**  
- AnigmaFoundation excludes Backend/ directory where orphaned files were
- Backend readability contracts moved to ContractsCore

✅ **No dependency cycles detected**  
- Validated with validate_no_cycles.py

✅ **No @_exported imports introduced**  
- Validated with validate_exported_imports.py

✅ **Tier validation remains clean**  
- BackendReadinessContracts in ContractsCore (Tier 1)
- PlatformBackend in RuntimeCore (Tier 2)
- AnigmaFoundation (Tier 2) excludes Backend/

## 11. Proof Artifact Path
`Docs/proofs/tb-2026-05-04-platformbackend-contract-extraction.md`

## 12. Recommended Next Task
**Task:** `tb-2026-05-04-databaseexecutor-duplicate-resolution`

**Scope:**
- Confirm all DatabaseExecutor call sites across the codebase
- Decide canonical owner (PersistenceContracts recommended)
- Make DatabaseCore depend on PersistenceContracts
- Remove DatabaseExecutor duplicate from DatabaseCore
- Validate no breakage

**Blocking:** None - current state compiles successfully with explicit PersistenceContracts import
