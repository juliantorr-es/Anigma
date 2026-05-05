# ModelRegistry Access Control Fix

## Starting Error Summary
**Before:** 6 errors, all in ModelRegistry module
- ModelRegistryTypedQueries.swift:101 - `'database' is inaccessible due to 'private' protection level`
- ModelRegistryTypedQueries.swift:105 - `'decodeEntry' is inaccessible due to 'private' protection level`
- ModelRegistryTypedQueries.swift:117 - `'database' is inaccessible due to 'private' protection level`

All errors originated from `ModelRegistryTypedQueries.swift` trying to access symbols declared `private` in `ModelRegistryStore.swift`.

## Call-Site Classification
Both files are in the same module and target:
- `anigma/Packages/ModelRegistry/Sources/ModelRegistryStore.swift` - defines `database` and `decodeEntry`
- `anigma/Packages/ModelRegistry/Sources/ModelRegistryTypedQueries.swift` - extends ModelRegistryStore with typed query methods

Both files belong to the `ModelRegistry` target in Package.swift. Therefore, cross-file access within the same module requires at least `internal` access level, not `private`.

## Access Level Chosen

### For `database`
- **Before:** `private let database: any DatabaseExecutor`
- **After:** `internal let database: any DatabaseExecutor`
- **Rationale:** `internal` is the narrowest scope that allows access from other files in the same module (ModelRegistryTypedQueries.swift). `private` restricts to the same file only.

### For `decodeEntry(from:)`
- **Before:** `private func decodeEntry(from row: DatabaseRow) throws -> ModelRegistryEntry?`
- **After:** `internal func decodeEntry(from row: DatabaseRow) throws -> ModelRegistryEntry?`
- **Rationale:** Same as `database` - `internal` allows access from ModelRegistryTypedQueries.swift which is in the same module.

## Files Modified
1. `anigma/Packages/ModelRegistry/Sources/ModelRegistryStore.swift`
   - Line 23: `private let database` → `internal let database`
   - Line 297: `private func decodeEntry` → `internal func decodeEntry`

## Public API Surface Changed
**No.** `internal` access is module-private, not public. The symbols remain invisible outside the ModelRegistry module. Only the intra-module visibility was adjusted.

## Package Graph Changes
**None.** No dependencies added, removed, or modified. Both files were already in the same target.

## Validation Commands and Results

### Build validation
```bash
swift build 2>&1 | tee /tmp/anigma-modelregistry-access-after.log
```
Result: ModelRegistry compiles successfully. No ModelRegistry-related errors in output.

### Cycle validation
```bash
swift package describe --type json > .build/anigma-package.json
python3 tools/governance/scripts/validate_no_cycles.py .build/anigma-package.json
```
Result: **No dependency cycles detected.**

### Tier validation
```bash
python3 tools/governance/scripts/validate_tiers.py
```
Result: **Architecture is clean. All tier boundaries respected.**

### Exported imports validation
No new @_exported imports were added.

## Error-Count Delta
- **Starting:** 6 errors (all ModelRegistry access-control)
- **After:** ModelRegistry errors = 0, new errors exposed in other modules = ~24 more (total ~30)
- **Delta for ModelRegistry:** -6 errors (all resolved)
- **Net build:** 6 → 30 (increase due to previously masked errors in AnigmaCore, HarmoniaV2, etc. now being visible)

## Remaining Blocker
30 errors across multiple modules, primarily:
- AnigmaCore: `RuntimeWriteGateAPI` not found, `PolicyEnforcementEngineAPI` not found, `SecurityInfrastructure` not found
- HarmoniaV2: `HarmoniaError` not found

These are unrelated to ModelRegistry and represent the next blockers.

## Architecture Statement
✅ **Access widened only to the narrowest necessary scope:** Changed from `private` (file-private) to `internal` (module-private), the minimal change needed for cross-file access within the same module.
✅ **No dependency changes introduced:** Both files were already in the same target. No Package.swift changes.
✅ **No dependency cycles introduced:** Validated with cycle detection script.
✅ **No @_exported imports introduced:** No new re-exports added.
✅ **No package swelling introduced:** No new targets, dependencies, or public API surface.

## Proof Artifacts
- Before log: `/tmp/anigma-modelregistry-access-before.log`
- After log: `/tmp/anigma-modelregistry-access-after.log`
- Package JSON: `.build/anigma-package.json`
