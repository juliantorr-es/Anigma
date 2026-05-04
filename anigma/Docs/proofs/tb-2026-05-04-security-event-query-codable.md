# Build Substrate Block Removal: SecurityEventQuery Codable

**Task ID**: tb-2026-05-04-security-event-query-codable  
**Status**: RESOLVED  
**Date**: 2026-05-04  
**Parent**: tb-2026-05-04-swift-numerics-shims-build-blocker

---

## Summary

The `SecurityEventQuery` struct in `SecurityEventsContracts` did not conform to Codable because its `dateRange` property used the tuple type `(from: Date, to: Date)?`, which does not automatically conform to Codable.

Additionally, two security logger files in SecurityEventsManager were missing the `SecurityEventsContracts` import, causing `SecurityEventSeverity` to be unresolved.

Additionally, access control issues in ModelRegistry prevented the ModelRegistryTypedQueries extension from accessing `database` and `decodeEntry`.

Additionally, PlatformBackend in AnigmaFoundation was referencing `ExecutionContext` and `DatabaseExecutor` from RuntimeCore, creating a tiering violation.

## Root Cause

1. **SecurityEventQuery**: Tuple `(from: Date, to: Date)?` cannot synthesize Codable conformance for its elements
2. **Missing imports**: DoctrineSecurityLogger and ThreatSecurityLogger use `SecurityEventSeverity` but only imported Foundation
3. **Access control**: ModelRegistryStore had `private` `database` property and `decodeEntry` method that are needed by ModelRegistryTypedQueries extension in the same module
4. **Tier violation**: PlatformBackend in AnigmaFoundation (Tier 1/2) referenced ExecutionContext from RuntimeCore (Tier 3)

## Resolution

1. **SecurityEventQuery**: Created a dedicated `DateRange` struct with `from: Date` and `to: Date` properties that conforms to Codable. Changed `SecurityEventQuery.dateRange` from `(from: Date, to: Date)?` to `DateRange?`.

2. **Missing imports**: Added `import SecurityEventsContracts` to both DoctrineSecurityLogger.swift and ThreatSecurityLogger.swift.

3. **Access control**: Changed `private let database` to `internal let database` and `private func decodeEntry` to `internal func decodeEntry` in ModelRegistryStore.swift.

4. **Tier violation**: Moved PlatformBackend.swift from `Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/` to `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Backend/` (RuntimeCore target). Updated imports to `import AnigmaFoundation` for BackendId/BackendCapabilityContract access and `import RendererBackendContracts`. ExecutionContext is in the same module (RuntimeCore) so no import needed.

## Changed Files

1. `Packages/ContractsCore/Sources/SecurityEventsContracts/SecurityEventStore.swift`
   - Added `DateRange` struct
   - Changed `SecurityEventQuery.dateRange` type from `(from: Date, to: Date)?` to `DateRange?`

2. `Packages/SecurityEventsManager/DoctrineSecurityLogger.swift`
   - Added `import SecurityEventsContracts`

3. `Packages/SecurityEventsManager/ThreatSecurityLogger.swift`
   - Added `import SecurityEventsContracts`

4. `Packages/ModelRegistry/Sources/ModelRegistryStore.swift`
   - Changed `private let database` → `internal let database`
   - Changed `private func decodeEntry` → `internal func decodeEntry`

5. `Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/PlatformBackend.swift`
   - DELETED (moved to Runtime/)

6. `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Backend/PlatformBackend.swift`
   - NEW (moved from Backend/)
   - Added `import AnigmaFoundation` for BackendId, BackendCapabilityContract
   - Added `import RendererBackendContracts`

## Validation Results

### Build Progression
```
$ swift build 2>&1 | grep -E "_NumericsShims|SecurityEventQuery"
# No output - both issues resolved
```

### Cycle Validation
```
$ python3 tools/governance/scripts/validate_no_cycles.py anigma/.build/anigma-package.json
No dependency cycles detected.
```

### Architecture Fix Integrity

| Check | Status |
|-------|--------|
| RuntimeCore is its own target | ✅ Confirmed in Package.swift |
| Runtime/ excluded from AnigmaFoundation | ✅ Confirmed: `exclude: ["AnigmaFoundation.swift", "Runtime/"]` |
| DatabaseCore ↔ AnigmaFoundation cycle | ✅ No cycle detected |
| No new @_exported imports in Anigma code | ✅ Only third-party deps have @_exported |
| PlatformBackend now in RuntimeCore | ✅ Moved to Runtime/Backend/ |

## Remaining Blockers

Build now progresses past the SecurityEventQuery and _NumericsShims issues. New errors exposed:

1. `GoverningController` not found in UpdateIntegration.swift
2. `CoreReceipt`, `RuntimeServices` not found in DocumentExportSystem.swift  
3. `EvidenceBundleExport` Decodable/Encodable conformance

These are separate pre-existing issues that were masked by the earlier build failures.

## Conclusion

SecurityEventQuery Codable blocker resolved without regressing the prior architecture fixes. The dependency graph remains acyclic, RuntimeCore extraction is intact, and PlatformBackend is now properly located in RuntimeCore.

**Next task**: Resolve the remaining exposed build errors (GoverningController, CoreReceipt, EvidenceBundleExport).
