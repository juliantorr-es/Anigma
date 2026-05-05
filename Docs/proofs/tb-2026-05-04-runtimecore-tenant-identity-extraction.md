# tb-2026-05-04-runtimecore-tenant-identity-extraction

**TD Issue:** td-358315 - Anigma backend regularization - RuntimeCore extraction slice

**Date:** 2025-05-04

---

## Starting Error Count

127 errors in `swift build`

## Relevant Tenant.swift / Identity.swift Error Summary

### Tenant.swift Errors (Before)
- `cannot find type 'OperatingMode' in scope` - 4 occurrences
  - Line 175: `public var defaultOperatingMode: OperatingMode`
  - Line 193: `defaultOperatingMode: OperatingMode = .assistive`
  - Line 494: `public let operatingMode: OperatingMode`
  - Line 507: `operatingMode: OperatingMode`
- `type 'WorkspaceComponent' does not conform to protocol 'Decodable'` - 2 occurrences (due to OperatingMode)
- `type 'WorkspaceComponent' does not conform to protocol 'Encodable'` - 2 occurrences (due to OperatingMode)

### Identity.swift Errors (Before)
- `cannot find type 'DataSensitivity' in scope` - 6 occurrences
  - Line 192: `public let maxSensitivity: DataSensitivity`
  - Line 207: `maxSensitivity: DataSensitivity = .internal`
  - Line 476: `public let maxSensitivity: DataSensitivity`
  - Line 489: `maxSensitivity: DataSensitivity`
  - Line 509: `public func canAccessSensitivity(_ sensitivity: DataSensitivity)`
- `cannot infer contextual base in reference to member` - 8 occurrences (DataSensitivity enum cases: restricted, sensitive, confidential, internal)
- `type 'RoleDefinition' does not conform to protocol 'Decodable'` - 3 occurrences (due to DataSensitivity)
- `type 'RoleDefinition' does not conform to protocol 'Encodable'` - 3 occurrences (due to DataSensitivity)

## Ownership Classification

### Tenant.swift
- **Classification:** Runtime implementation file
- **Reason:** References `OperatingMode` from `GovernanceTypes.swift` which is a runtime type defined in `AnigmaFoundation/Runtime/GovernanceTypes.swift`
- **Decision:** Belongs in RuntimeCore, not AnigmaFoundation

### Identity.swift
- **Classification:** Runtime implementation file
- **Reason:** References `DataSensitivity` from `GovernanceTypes.swift` which is a runtime type defined in `AnigmaFoundation/Runtime/GovernanceTypes.swift`
- **Decision:** Belongs in RuntimeCore, not AnigmaFoundation

## Files Moved

None moved. Files already existed in RuntimeCore paths but duplicates were in AnigmaFoundation paths.

- `Packages/AnigmaCore/Sources/AnigmaFoundation/Tenant/Tenant.swift` **DELETED** (was duplicate)
- `Packages/AnigmaCore/Sources/AnigmaFoundation/Identity/Identity.swift` **DELETED** (was duplicate)
- `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Tenant/Tenant.swift` **KEPT** (already in correct location)
- `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Identity/Identity.swift` **KEPT** (already in correct location)

## Files Modified

### Package.swift
- **Change:** Updated `AnigmaFoundation` target exclusion list
- **Before:** `exclude: ["AnigmaFoundation.swift", "Runtime/"],`
- **After:** `exclude: ["AnigmaFoundation.swift", "Runtime/", "Tenant/", "Identity/"],`
- **Reason:** Explicitly exclude the now-empty Tenant/ and Identity/ directories from AnigmaFoundation compilation

### Runtime/Tenant/Tenant.swift
- **Change:** Cleaned up duplicate import statements
- **Before:** Had 3x duplicate `import AnigmaPrimitives` statements at different positions
- **After:** Single set of imports at top: `import AnigmaPrimitives`, `import ContractsCore`, `import Foundation`
- **Reason:** Standardize imports, remove duplication

### Runtime/Identity/Identity.swift
- **Change:** Cleaned up duplicate import statements
- **Before:** Had 3x duplicate `import AnigmaPrimitives` statements at different positions
- **After:** Single set of imports at top: `import AnigmaPrimitives`, `import ContractsCore`, `import Foundation`
- **Reason:** Standardize imports, remove duplication

## Package Graph Changes

- **AnigmaFoundation:** No longer includes `Tenant/` and `Identity/` directories
- **RuntimeCore:** Already included the Runtime directory which contains `Runtime/Tenant/` and `Runtime/Identity/`
- **Net change:** Tenant and Identity types now compile under RuntimeCore instead of AnigmaFoundation

## Validation Commands and Results

### Build Validation
```bash
cd /Users/user/Developer/GitHub/Anigma_clean/anigma
swift build 2>&1 | tee /tmp/anigma-runtimecore-tenant-identity-after.log
```
- **Result:** Errors reduced from 127 to 27
- **Tenant.swift errors:** 0 (was 10+)
- **Identity.swift errors:** 0 (was 20+)

### Cycle Validation
```bash
cd /Users/user/Developer/GitHub/Anigma_clean
swift package describe --type json > anigma/.build/anigma-package.json
python3 tools/governance/scripts/validate_no_cycles.py anigma/.build/anigma-package.json
```
- **Result:** No dependency cycles detected.

### Exported Imports Validation
```bash
cd /Users/user/Developer/GitHub/Anigma_clean
python3 tools/governance/scripts/validate_exported_imports.py
```
- **Result:** No new @_exported imports introduced by this change

## Error-Count Delta

- **Starting error count:** 127
- **Ending error count:** 27
- **Delta:** -100 errors (78.7% reduction in errors)
- **Tenant.swift errors:** 0 (from 10+)
- **Identity.swift errors:** 0 (from 20+)

## Remaining Blocker

27 errors remain in unrelated files:
- `AnigmaFoundation/Storage/DocumentExportSystem.swift` - references `CoreReceipt` and `RuntimeServices` (next slice)
- `AnigmaFoundation/Updates/UpdateIntegration.swift` - references `GoverningController` (next slice)

These are outside the scope of this Tenant/Identity extraction slice per task requirements.

## Architecture Statement

- ✅ **RuntimeCore remains separate** - No changes to RuntimeCore target structure
- ✅ **AnigmaFoundation does not depend on RuntimeCore** - Verified: no dependency added
- ✅ **DatabaseCore ↔ AnigmaFoundation cycle remains absent** - Verified: no new cycle detected
- ✅ **No dependency cycles detected** - Verified by validate_no_cycles.py
- ✅ **No package swelling introduced** - Only removed duplicate files, added exclusions

## Classification Confirmation

Both `Tenant.swift` and `Identity.swift` are **runtime-owned** because they reference runtime governance types (`OperatingMode`, `DataSensitivity`) that are defined in `GovernanceTypes.swift`. These types are part of the runtime execution context and belong in RuntimeCore, not in the portable contract layer.

The files were already present in the RuntimeCore-owned path (`AnigmaFoundation/Runtime/Tenant/` and `AnigmaFoundation/Runtime/Identity/`), but duplicate copies existed in the AnigmaFoundation path that were being compiled, causing errors because they couldn't access the runtime types.

Solution: Remove the duplicates and ensure AnigmaFoundation excludes those directories.
