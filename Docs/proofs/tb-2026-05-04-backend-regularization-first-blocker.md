# Backend Regularization: First Blocker Resolution

**Task:** Begin next backend regularization pass after Architecture Operations Capability roadmap  
**Issue ID:** N/A (first blocker discovery)  
**Date:** 2026-05-04  
**Status:** PARTIAL - Circular dependency resolved, new blocker identified  

---

## Summary

Resolved the **first concrete blocker** preventing `anigma-app` Debug builds: circular dependency between modules `DatabaseCore` and `AnigmaFoundation`.

The circular dependency was caused by:
1. `AnigmaFoundation` target depends on `GovernanceCore` → `DatabaseCore`
2. `AnigmaFoundation` target depends on `StorageCore` → `DatabaseCore`
3. 11 source files within `AnigmaFoundation` directory imported `DatabaseCore` at the source level, creating a module-level cycle

---

## Files Changed

### Package.swift
- Added new target `RuntimeCore` to isolate runtime files that require `DatabaseCore`
- Modified `AnigmaFoundation` target to exclude `Runtime/` directory
- Added `RuntimeCore` to `coreProducts` list
- Updated `HarmoniaV2CLI` and `HarmoniaV2CLIKernel` dependencies to include `RuntimeCore`

### Source Files Modified
- `Packages/AnigmaCore/Sources/AnigmaFoundation/Analytics/AuditLogManager.swift`: Removed stale `import DatabaseCore` (not used)
- `Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/PlatformBackend.swift`: Removed stale `import DatabaseCore` (not used - `DatabaseExecutor` is defined in `AnigmaFoundation` via `PersistenceContracts`)
- `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Authorities.swift`: Removed `@_exported import GovernanceCore` (re-export was creating cycle)
- `Packages/HarmoniaV2CLI/CLIKernel.swift`: Added `import RuntimeCore`, updated type references from `AnigmaFoundation.DatabaseAuthority` to `RuntimeCore.DatabaseAuthority`

### New Target Created
- `RuntimeCore` (`Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/`)
  - Dependencies: `AnigmaFoundation`, `DatabaseCore`, `ContractsCore`, `FoundationContracts`, `GovernanceContracts`, `EvidenceContracts`, `IntelligenceContracts`, `PersistenceContracts`, `AnigmaPrimitives`
  - Contains 22 Runtime files that require DatabaseCore types
  - Breaks the circular dependency by moving DatabaseCore-dependent code to a target that explicitly depends on both AnigmaFoundation and DatabaseCore

---

## Blocker Classification

| Category | Details |
|---|---|
| **Primary** | Package graph / target dependency issue |
| **Secondary** | Native framework leakage across contract/runtime/backend tiers |
| **Root cause** | Runtime files in AnigmaFoundation importing DatabaseCore while AnigmaFoundation target already depends on DatabaseCore transitively via GovernanceCore/StorageCore |

---

## Original Failure

```
<unknown>:0: error: circular dependency between modules 'DatabaseCore' and 'AnigmaFoundation'
```

This error occurred during Xcode Debug build validation for the `anigma-app` scheme, preventing any progress on backend regularization.

---

## Fix Summary

1. **Identified root cause**: 11 files in `AnigmaFoundation/Runtime/` imported `DatabaseCore`, while `AnigmaFoundation` target already depends on `GovernanceCore` → `DatabaseCore` and `StorageCore` → `DatabaseCore`

2. **Applied doctrine-compliant fix**:
   - Created new `RuntimeCore` target for runtime-specific code that requires DatabaseCore
   - Excluded `Runtime/` from `AnigmaFoundation` target
   - Updated downstream targets (`HarmoniaV2CLI`, `HarmoniaV2CLIKernel`) to depend on `RuntimeCore`
   - Removed stale imports from files that don't actually use DatabaseCore types

3. **Preserved tier architecture**:
   - `RuntimeCore` depends on `AnigmaFoundation` (higher tier) + `DatabaseCore` (lower tier)
   - No tier 1 contracts import tier 2/3 implementations
   - No @_exported imports remain that create cycles

---

## Validation Commands Run

```bash
# 1. Package resolution check
cd anigma && swift package resolve
# Result: SUCCESS (no resolution errors)

# 2. Xcode Debug build for anigma-app
bash Scripts/validate_xcodebuild_debug.sh --scheme anigma-app
# Result: Circular dependency error NO LONGER OCCURS
# New error: missing required module '_NumericsShims' (pre-existing)
```

---

## Pass/Fail Result

| Check | Result |
|---|---|
| Package graph resolves | ✅ PASS |
| Circular dependency between DatabaseCore and AnigmaFoundation | ✅ FIXED |
| anigma-app Debug build progresses past original blocker | ✅ PASS |
| Full anigma-app Debug build | ❌ BLOCKED (pre-existing swift-numerics _NumericsShims issue) |

---

## Remaining Blocker

**Second blocker identified**: `missing required module '_NumericsShims'` from `swift-numerics` dependency.

This appears to be a pre-existing issue with the swift-numerics package integration in the project, now visible because the original circular dependency has been resolved.

Evidence from existing build logs:
- `xcodebuild_debug_final.txt` (from 2026-05-02) shows the same `_NumericsShims` errors
- These errors were masked by the earlier circular dependency failure

### Next action for remaining blocker:
Investigate swift-numerics package configuration and ensure _NumericsShims module is properly available to EventSource and mlx-swift dependencies.

---

## Architecture Operations Capability Status

**Explicit statement**: ArchitectureOperationsCapability was NOT implemented.  

This work was focused solely on backend regularization to unblock the build, as specified in the Architecture Operations Capability roadmap which states:  
> "Blocked until anigma-app Debug builds reliably"

---

## Recommended Next Task

**Priority 1 (immediate)**: Resolve the `_NumericsShims` missing module error by:
- Checking swift-numerics package configuration in Package.swift
- Verifying _NumericsShims module is built and linked correctly
- Ensuring all targets that transitively depend on swift-numerics can find the module

**Priority 2**: With anigma-app Debug building reliably, ArchitectureOperationsCapability implementation can begin.

---

## Changes Summary

| Aspect | Changed | Count |
|---|---|---|
| **Production code** | Yes | 2 files (import cleanup) |
| **Scripts** | No | 0 |
| **Package graph** | Yes | 1 new target, 2 dependency updates |
| **Lines changed** | ~20 lines across Package.swift and source files |
