# PlatformBackend Contract Research

**Date:** 2026-05-04  
**Task:** Focused PlatformBackend architecture research pass  
**Status:** COMPLETE - Research Only, No Code Changes

## Starting PlatformBackend Error Count
**0 errors** currently emitted for PlatformBackend in build output.

**Reason:** `PlatformBackend.swift` is in an **excluded directory** (`AnigmaFoundation/Backend/`) and is therefore **not compiled** as part of any target. The file exists on disk but is orphaned from the build.

## Missing Symbol Classifications

### 1. BackendId
| Aspect | Finding |
|--------|---------|
| **Symbol Type** | `public struct BackendId: Hashable, Codable, Sendable, CustomStringConvertible` |
| **Classification** | 3 - Existing runtime implementation type, wrong target/file ownership |
| **Current Location** | `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/BackendReadinessContracts.swift` (excluded from AnigmaFoundation target) |
| **Current Target Ownership** | **NONE** - File in excluded Backend/ directory, not part of any target |
| **Existing Definition Found** | Yes - Full struct with rawValue, init, description |
| **Current Call Sites** | `PlatformBackend.swift:15` (var backendId: BackendId), `PlatformBackend.swift:38` (BackendId(rawValue:)), `PlatformBackend.swift:54` (BackendId.databaseBackend()) |
| **Recommended Ownership** | **BackendReadinessContracts target** - This is a portable contract type (Hashable, Codable, Sendable) and should live in its own contract target, not in AnigmaFoundation (excluded) |
| **Contract Extraction Required** | **YES** - Create `BackendReadinessContracts` target in ContractsCore package |
| **Package.swift Changes Required** | **YES** - Add BackendReadinessContracts target to ContractsCore, include BackendReadinessContracts.swift in that target |
| **Risk** | Medium - Type is portable but currently orphaned |
| **Proof** | File exists with portable conformances (Hashable, Codable, Sendable). No runtime dependencies. |

### 2. BackendCapabilityContract
| Aspect | Finding |
|--------|---------|
| **Symbol Type** | `public struct BackendCapabilityContract: Codable, Sendable` |
| **Classification** | 3 - Existing runtime implementation type, wrong target/file ownership |
| **Current Location** | `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/BackendReadinessContracts.swift` (excluded) |
| **Current Target Ownership** | **NONE** - Orphaned in excluded directory |
| **Existing Definition Found** | Yes - Full struct with backendId, kind, contractId, contractVersion, supportedOperations |
| **Current Call Sites** | `PlatformBackend.swift:18` (var contract:), `PlatformBackend.swift:56` (BackendCapabilityContract(...)), `PlatformBackend.swift:61` (BackendCapabilityContract(...)) |
| **Recommended Ownership** | **BackendReadinessContracts target** - Portable struct, belongs in contract layer |
| **Contract Extraction Required** | **YES** - Part of BackendReadinessContracts target |
| **Package.swift Changes Required** | **YES** - Same as BackendId |
| **Risk** | Medium - Portable, currently orphaned |
| **Proof** | Codable, Sendable, no runtime-only dependencies |

### 3. BackendOperation
| Aspect | Finding |
|--------|---------|
| **Symbol Type** | `public protocol BackendOperation: Sendable` |
| **Classification** | 3 - Existing runtime implementation type, wrong target/file ownership |
| **Current Location** | `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/BackendReadinessContracts.swift:363` (excluded) |
| **Current Target Ownership** | **NONE** - Orphaned in excluded directory |
| **Existing Definition Found** | Yes - Protocol with operationType property and cancellation support |
| **Current Call Sites** | `PlatformBackend.swift:22-25` (execute<Operation: BackendOperation, Result>) |
| **Recommended Ownership** | **BackendReadinessContracts target** - Protocol is portable (Sendable) |
| **Contract Extraction Required** | **YES** - Part of BackendReadinessContracts target |
| **Package.swift Changes Required** | **YES** - Same as BackendId |
| **Risk** | Medium - Portable, currently orphaned |
| **Proof** | Only requires Sendable, no runtime-only types |

### 4. DatabaseExecutor
| Aspect | Finding |
|--------|---------|
| **Symbol Type** | `public protocol DatabaseExecutor: Actor, Sendable` |
| **Classification** | **2 - Existing portable contract, missing package dependency** |
| **Current Locations** | TWO definitions found:
  - `anigma/Packages/DatabaseCore/DatabaseExecutor.swift:11` 
  - `anigma/Packages/ContractsCore/Sources/PersistenceContracts/DatabaseContracts.swift:36` |
| **Current Target Ownership** | DatabaseCore target AND PersistenceContracts target |
| **Existing Definition Found** | Yes - Duplicate definitions in two packages |
| **Current Call Sites** | `PlatformBackend.swift:59` (databaseExecutor: any DatabaseExecutor), `PlatformBackend.swift:66` (DatabasePlatformBackend uses it) |
| **Recommended Ownership** | **PersistenceContracts (ContractsCore)** - DatabaseExecutor is a portable protocol. The DatabaseCore definition creates a duplicate. |
| **Contract Extraction Required** | **NO** - Already exists in PersistenceContracts. Need to remove duplicate from DatabaseCore or make DatabaseCore import PersistenceContracts. |
| **Package.swift Changes Required** | **NO** - But may need to make DatabaseCore depend on PersistenceContracts and remove its duplicate |
| **Risk** | **HIGH** - Duplicate protocol definitions. This is a pre-existing architecture issue. |
| **Proof** | Protocol is defined twice identically in two packages. Both have the same signature: `public protocol DatabaseExecutor: Actor, Sendable` |

### 5. PlatformBackend
| Aspect | Finding |
|--------|---------|
| **Symbol Type** | `public protocol PlatformBackend: Sendable` |
| **Classification** | 3 - Existing runtime implementation type, wrong target/file ownership |
| **Current Location** | `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/PlatformBackend.swift` (excluded) |
| **Current Target Ownership** | **NONE** - Orphaned in excluded directory |
| **Existing Definition Found** | Yes - Protocol with backendId, contract, initialize, shutdown, execute |
| **Current Call Sites** | None found in codebase (internal to file only) |
| **Recommended Ownership** | **RuntimeCore target** - PlatformBackend is a runtime orchestration protocol. It depends on ExecutionContext (from RuntimeCore) and other backend contracts. |
| **Contract Extraction Required** | **NO** - This is a runtime protocol, not a portable contract. |
| **Package.swift Changes Required** | **NO** - But PlatformBackend.swift needs to be moved to a compiled target |
| **Risk** | Medium - Orphaned, uses both portable contracts and runtime types |
| **Dependencies** | ExecutionContext (RuntimeCore), BackendId (BackendReadinessContracts), BackendCapabilityContract (BackendReadinessContracts), BackendOperation (BackendReadinessContracts), DatabaseExecutor (PersistenceContracts/DatabaseCore), RendererBackendContracts |

## Existing Definitions Found

### BackendReadinessContracts.swift
**Path:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/BackendReadinessContracts.swift`

**Contains:**
- `BackendId` (struct)
- `BackendKind` (enum)
- `BackendLifecycleState` (enum)
- `BackendReadinessState` (enum)
- `ContractCompatibility` (enum)
- `BackendCapabilityContract` (struct)
- `BackendOperationContext` (struct)
- `BackendOperation` (protocol)
- Extensions for BackendCapabilityContract (inferenceContract, rendererContract, etc.)
- Extensions for BackendId (databaseBackend, inferenceBackend, etc.)

**Analysis:** All types are **portable** (Hashable, Codable, Sendable conformances where appropriate). No runtime-only dependencies. These belong in a **BackendReadinessContracts** target in the **ContractsCore** package.

### PlatformBackend.swift
**Path:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/PlatformBackend.swift`

**Contains:**
- `PlatformBackend` (protocol)
- `ConcretePlatformBackend` (struct conforming to PlatformBackend)
- `DatabasePlatformBackend` (struct conforming to PlatformBackend, wraps DatabaseExecutor)

**Analysis:** Mixed layering. The `PlatformBackend` protocol uses portable contracts (BackendId, BackendCapabilityContract, BackendOperation) AND runtime types (ExecutionContext from RuntimeCore). This should be in **RuntimeCore** target, not in AnigmaFoundation (excluded).

### DatabaseExecutor Duplicate
**Two identical protocol definitions:**
1. `Packages/DatabaseCore/DatabaseExecutor.swift:11`
2. `Packages/ContractsCore/Sources/PersistenceContracts/DatabaseContracts.swift:36`

**Both define:** `public protocol DatabaseExecutor: Actor, Sendable { ... }`

## Target Ownership Findings

### Current State
| File | Directory | Target Membership | Status |
|------|-----------|------------------|--------|
| BackendReadinessContracts.swift | AnigmaFoundation/Backend/ | **EXCLUDED** from AnigmaFoundation | Orphaned |
| PlatformBackend.swift | AnigmaFoundation/Backend/ | **EXCLUDED** from AnigmaFoundation | Orphaned |
| DatabaseExecutor (proto) | DatabaseCore/ | DatabaseCore target | Active (but duplicate) |
| DatabaseExecutor (proto) | PersistenceContracts/ | PersistenceContracts target | Active (but duplicate) |

### Recommended Ownership
| File | Recommended Target | Package | Rationale |
|------|-------------------|---------|-----------|
| BackendReadinessContracts.swift | **BackendReadinessContracts** | ContractsCore | Contains only portable contract types |
| PlatformBackend.swift | **RuntimeCore** | AnigmaCore | Uses both portable contracts + RuntimeCore types (ExecutionContext) |
| DatabaseExecutor (remove) | N/A | DatabaseCore | Remove duplicate; use PersistenceContracts version |

## Whether Code Changes Were Made
**NO** - This is a research-only pass. No code modifications were applied.

## Files Modified
**None**

## Validation Results
**N/A** - No code changes made, no regression possible.

## Recommended Implementation Slice

### Phase 1: Create BackendReadinessContracts Target (Next Slice)
1. **Create new target** in `Package.swift` (ContractsCore package):
   ```swift
   .target(
     name: "BackendReadinessContracts",
     dependencies: ["FoundationContracts"],
     path: "Packages/ContractsCore/Sources/BackendReadinessContracts",
     exclude: []
   )
   ```

2. **Move file** from orphaned location:
   - Move `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/BackendReadinessContracts.swift`
   - To: `anigma/Packages/ContractsCore/Sources/BackendReadinessContracts/BackendReadinessContracts.swift`

3. **Update imports** in the moved file:
   - Change any AnigmaFoundation imports to FoundationContracts where applicable
   - Ensure only Tier 1 dependencies

4. **Validate** tier compliance:
   - All types in BackendReadinessContracts are portable (Hashable, Codable, Sendable)
   - No runtime-only dependencies

### Phase 2: Move PlatformBackend to RuntimeCore
1. **Move file** from orphaned location:
   - Move `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/PlatformBackend.swift`
   - To: `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Backend/PlatformBackend.swift`

2. **Update PlatformBackend.swift imports:**
   - Add `import BackendReadinessContracts` (from ContractsCore)
   - Add `import PersistenceContracts` or `import DatabaseCore` (for DatabaseExecutor - resolve duplicate first)
   - Already has `import AnigmaFoundation` and `import RendererBackendContracts`

3. **Resolve DatabaseExecutor duplicate:**
   - Take one of two paths:
     a. Make DatabaseCore import PersistenceContracts and remove its DatabaseExecutor definition
     b. Make PersistenceContracts import DatabaseCore and remove its DatabaseExecutor definition
   - **Recommended:** Option (a) - DatabaseCore is more specific, should depend on PersistenceContracts

4. **Update RuntimeCore target** in Package.swift:
   - Add `"BackendReadinessContracts"` to RuntimeCore dependencies

5. **Validate** no cycles introduced

### Phase 3: Update Call Sites (if any)
- Currently no external call sites found for PlatformBackend types
- Once PlatformBackend is in a compiled target, other code can import and use it

### Risk Assessment
| Action | Risk | Mitigation |
|--------|------|------------|
| Create BackendReadinessContracts target | Low | Types are already portable, just need correct target |
| Move BackendReadinessContracts.swift | Low | File-only move, no semantic changes |
| Move PlatformBackend.swift | Medium | Need to resolve DatabaseExecutor duplicate first |
| Resolve DatabaseExecutor duplicate | Medium | Need to check all call sites for type compatibility |

## Proof Artifact Path
`Docs/proofs/tb-2026-05-04-platformbackend-contract-research.md`

## Next Implementation Task
**Task:** `tb-2026-05-04-platformbackend-contract-extraction`

**Scope:** 
- Create BackendReadinessContracts target in ContractsCore
- Move BackendReadinessContracts.swift to ContractsCore
- Move PlatformBackend.swift to RuntimeCore
- Resolve DatabaseExecutor duplicate (DatabaseCore vs PersistenceContracts)
- Update PlatformBackend.swift imports
- Validate architecture compliance

**Do not proceed until:** DatabaseExecutor duplicate resolution path is confirmed (which package owns it)
