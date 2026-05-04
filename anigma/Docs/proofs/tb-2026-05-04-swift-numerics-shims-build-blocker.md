# Build Substrate Block Removal: `_NumericsShims`

**Task ID**: tb-2026-05-04-swift-numerics-shims-build-blocker  
**Status**: RESOLVED  
**Date**: 2026-05-04  
**Parent**: tb-2026-05-04-backend-regularization-first-blocker

---

## Summary

The `_NumericsShims` module missing error was blocking `swift build` from progressing past swift-numerics dependency compilation. This was a **stale SwiftPM build cache issue**, not a dependency graph or version incompatibility problem.

## Baseline Error

```
[8/199] Compiling copy.cpp
error: emit-module command failed with exit code 1 (use -v to see invocation)
[10/210] Emitting module EventSource
<unknown>:0: error: missing required module '_NumericsShims'
```

## Root Cause

SwiftPM's incremental build cache had stale state for the `swift-numerics` package at version 1.1.1. The `_NumericsShims` C module (which provides math function shims for the `RealModule` and `ComplexModule` Swift targets) was not being compiled because SwiftPM's cached build artifacts were in an inconsistent state.

The module itself is valid:
- `_NumericsShims` is a C target in swift-numerics (`Sources/_NumericsShims/`)
- It has a proper module map (`include/module.modulemap`)
- It has the required C source file (`_NumericsShims.c`) and header (`_NumericsShims.h`)
- `RealModule` correctly depends on it in swift-numerics' `Package.swift`

## Resolution

1. Removed the swift-numerics checkout from `.build/checkouts/`
2. Re-ran `swift package resolve` to fetch fresh copies
3. The `_NumericsShims.c` module then compiled successfully on the next build attempt

No changes to `Package.swift` or `Package.resolved` were required.

## Changed Files

**None.** This was a cache cleanup resolution.

- No `Package.swift` modifications
- No `Package.resolved` modifications  
- No source code changes
- No dependency version updates

## Validation Results

### Package Resolution
```
$ swift package resolve
# Success - no output
```

### Cycle Validation
```
$ python3 tools/governance/scripts/validate_no_cycles.py anigma/.build/anigma-package.json
No dependency cycles detected.
```

### Build Progression
```
$ swift build 2>&1
# Output shows:
[18/1348] Compiling _NumericsShims _NumericsShims.c
[18/1348] Write sources
# No "missing required module '_NumericsShims'" error
```

### Architecture Fix Integrity

| Check | Status |
|-------|--------|
| RuntimeCore is its own target | ✅ Confirmed in Package.swift |
| Runtime/ excluded from AnigmaFoundation | ✅ Confirmed: `exclude: ["AnigmaFoundation.swift", "Runtime/"]` |
| DatabaseCore ↔ AnigmaFoundation cycle | ✅ No cycle detected |
| No new @_exported imports in Anigma code | ✅ Only third-party deps have @_exported |

## Remaining Blockers

The build now progresses past swift-numerics but is blocked by a separate pre-existing issue:

```
SecurityEventQuery: does not conform to protocol 'Decodable'
SecurityEventQuery: does not conform to protocol 'Encodable'
```

**This is a different issue** - the `dateRange: (from: Date, to: Date)?` tuple in `Packages/ContractsCore/Sources/SecurityEventsContracts/SecurityEventStore.swift:63` does not conform to Codable. This is **not related to the `_NumericsShims` fix** and was likely masked by the earlier build failure.

## Conclusion

The `_NumericsShims` build blocker has been resolved without regressing the prior architecture fixes. The dependency graph remains acyclic, RuntimeCore extraction is intact, and no umbrella exports were added.

**Next task**: Resolve the `SecurityEventQuery` Codable conformance issue, then proceed to verify the full anigma-app Debug build.
