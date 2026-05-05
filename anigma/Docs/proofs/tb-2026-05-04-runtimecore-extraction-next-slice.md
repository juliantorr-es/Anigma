# RuntimeCore Extraction: Next Slice

**Task ID**: tb-2026-05-04-runtimecore-extraction-next-slice  
**Status**: RESOLVED  
**Date**: 2026-05-04  
**Parent**: tb-2026-05-04-security-event-query-codable

---

## Starting Blocker Summary

After resolving `_NumericsShims` and `SecurityEventQuery` Codable issues, 486 pre-existing errors were exposed. Classification of the first 30-60 errors revealed:

| Bucket | Count | Description |
|--------|-------|-------------|
| 1. Runtime-owned type outside RuntimeCore | 20+ | Files in AnigmaFoundation/Integration and AnigmaFoundation/Identity reference types from Runtime/GovernanceTypes.swift and Runtime/SecurityTypes.swift |
| 2. Import visibility/access-control | 2+ | ModelRegistryTypedQueries.swift cannot access private/internal members in ModelRegistryStore |
| 3. Contract-owned type extraction needed | 0 | N/A for this slice |
| 4. Stale path/target membership | 0 | N/A for this slice |
| 5. Unrelated pre-existing | Remaining | Will emerge after slice 1 is resolved |

## Chosen Bucket and Rationale

**Bucket 1: Runtime-owned files outside RuntimeCore**

The largest coherent cluster was **AnigmaPlatform.swift** and **SecuredWorld.swift** in `Packages/AnigmaCore/Sources/AnigmaFoundation/Integration/`. These files reference multiple Runtime/ types:
- `OperatingMode`, `AccessPrincipal`, `DataSensitivity`, `GovernanceStatus`, `GoverningController` (from Runtime/GovernanceTypes.swift)
- `ComplianceReport`, `RestrictedDataPolicy`, `RoleBasedPolicy` (from Runtime/SecurityTypes.swift)
- `SecurityInfrastructure` (protocol from Runtime/SecurityProtocols.swift)

These are **runtime orchestration files** that create and manage the governed platform world. They belong in RuntimeCore, not AnigmaFoundation. The first slice moves these 2 files.

Additionally, **PlatformBackend.swift** was already partially moved in the previous task but had import issues. This slice completes that move.

Finally, the **ModelRegistry access control** issue (decodeEntry inaccessible) is a small fix to enable the existing ModelRegistryTypedQueries extension.

## Files Moved

1. `Packages/AnigmaCore/Sources/AnigmaFoundation/Integration/AnigmaPlatform.swift` → `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Integration/AnigmaPlatform.swift`
2. `Packages/AnigmaCore/Sources/AnigmaFoundation/Integration/SecuredWorld.swift` → `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Integration/SecuredWorld.swift`
3. `Packages/AnigmaCore/Sources/AnigmaFoundation/Backend/PlatformBackend.swift` → `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Backend/PlatformBackend.swift`

## Files Modified

1. `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Backend/PlatformBackend.swift`
   - Updated imports: `import BackendReadinessContracts` (for BackendId, BackendCapabilityContract)
   - Removed `import DatabaseCore` (not needed, DatabaseExecutor is in same module)

2. `Packages/ContractsCore/Sources/SecurityEventsContracts/SecurityEventStore.swift`
   - Added `DateRange` struct to replace `(from: Date, to: Date)?` tuple
   - Changed `SecurityEventQuery.dateRange` type

3. `Packages/ModelRegistry/Sources/ModelRegistryStore.swift`
   - Changed `private let database` → `internal let database`
   - Changed `private func decodeEntry` → `internal func decodeEntry`

4. `Packages/SecurityEventsManager/DoctrineSecurityLogger.swift`
   - Added `import SecurityEventsContracts`

5. `Packages/SecurityEventsManager/ThreatSecurityLogger.swift`
   - Added `import SecurityEventsContracts`

## Package Graph Changes

**None.** No Package.swift changes required. The files are moved within the existing RuntimeCore target path (`Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/`), which is already configured in Package.swift as the RuntimeCore target.

## Validation Results

### Cycle Validation
```
$ cd /Users/user/Developer/GitHub/Anigma_clean
$ python3 tools/governance/scripts/validate_no_cycles.py anigma/.build/anigma-package.json
No dependency cycles detected.
```

### Error Count Delta
- **Before**: 486 errors
- **After**: 189 errors  
- **Reduction**: 297 errors (61% decrease)

### Specific Blocker Resolution
```
$ swift build 2>&1 | grep -E "AnigmaPlatform|SecuredWorld"
# No output - resolved
```

## Architecture Statement

- **RuntimeCore remains separate**: ✅ RuntimeCore is a separate target with its own path
- **AnigmaFoundation does not depend on RuntimeCore**: ✅ Confirmed in Package.swift - AnigmaFoundation has no RuntimeCore dependency
- **DatabaseCore ↔ AnigmaFoundation cycle remains absent**: ✅ No cycle detected by validate_no_cycles.py
- **No dependency cycles**: ✅ Validated
- **No package swelling introduced**: ✅ No new umbrella modules or consolidated targets
- **No new @_exported imports**: ✅ Only third-party deps use @_exported

## Remaining Blockers

189 errors remain, organized into similar buckets:
- **Primary**: Files in AnigmaFoundation/Tenant/ (Tenant.swift) and AnigmaFoundation/Identity/ (Identity.swift) reference Runtime/ types (OperatingMode, DataSensitivity, etc.)
- **Secondary**: Files in AnigmaFoundation/Updates/ (UpdateIntegration.swift) reference GoverningController from Runtime/
- **Tertiary**: Files in AnigmaFoundation/Updates/ reference additional Runtime/ types

These are the **next slice** for RuntimeCore extraction.

## Proof Artifacts

- Previous: `Docs/proofs/tb-2026-05-04-swift-numerics-shims-build-blocker.md`
- Previous: `Docs/proofs/tb-2026-05-04-security-event-query-codable.md`
- Current: `Docs/proofs/tb-2026-05-04-runtimecore-extraction-next-slice.md`

## Recommended Next Task

Complete the next narrow slice: Identify the smallest coherent group of remaining files that are runtime-owned but still located in AnigmaFoundation (Tenant.swift, Identity.swift, Updates/ directory), move them into RuntimeCore, and update imports. Focus on **Tenant.swift** and **Identity.swift** as the next cluster, as they reference `DataSensitivity`, `OperatingMode`, and `AccessPrincipal` from Runtime/GovernanceTypes.swift.
