# Proof: td-cleanup-002-batch-001-post-review

**Date:** 2026-05-05  
**Task:** td-cleanup-002 Batch 001 Post-Implementation Review  
**Status:** SUCCESS / IN_REVIEW

## Files Reviewed
- `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/System/RuntimeAuthority.swift` (New Authority)
- `anigma/Sources/anigmad/main.swift` (Menu Bar App entry points)
- `anigma/Sources/anigmad/UI.swift` (Menu Bar App UI and @main)
- `anigma/Packages/AnigmaDaemon/main.swift` (Sidecar Daemon entry points)
- `anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift` (Daemon Coordinator)
- `anigma/Packages/AnigmaDaemonControl/main.swift` (Control CLI)
- `anigma/Packages/AnigmaDaemonCore/Utils/DaemonInferenceAuthority.swift` (Path resolution)

## Files Modified during Review
- `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/System/RuntimeAuthority.swift`: 
  - Moved from `RuntimeCore` target (excluded) to `AnigmaFoundation` target.
  - Hardened `workingDirectory` to capture `initialWorkingDirectory` at startup for stability.
  - Added documentation regarding library vs executable usage of `shutdown`.
- `scripts/anigma_executable_consolidation_audit.py`:
  - Excluded `RuntimeAuthority.swift` from the audit to prevent false positives on its `exit()` and `currentDirectoryPath` usage.

## Review Analysis

### 1. RuntimeAuthority Placement
- **Decision:** `AnigmaFoundation` is the correct module.
- **Rationale:** It is the most foundational library target that is common to all services. Placing it in `RuntimeCore` (as originally done) would have limited its visibility or introduced dependency bloat since `RuntimeCore` depends on `AnigmaFoundation` but not vice versa.
- **Verification:** Target `AnigmaFoundation` successfully compiles `RuntimeAuthority.swift`.

### 2. RuntimeAuthority Shape
- **API Surface:** Narrow and focused.
  - `shutdown(exitCode:) -> Never`: Single point of process exit.
  - `workingDirectory: String`: Governed access to CWD.
  - `initialWorkingDirectory: String`: Immutable snapshot of CWD at startup.
- **Safety:** Marked as `final` and `Sendable`.

### 3. Shutdown Semantics
- **Call-site Classification:**
  - `AnigmaDaemon/main.swift`: `top_level_ok`. Handles signals, stops services, then exits.
  - `anigmad/main.swift`: `top_level_ok`. Used in static config loading where failure is terminal.
  - `DaemonServer.swift`: `top_level_ok` (but sensitive). In `handleGracefulShutdown`, which is currently unused and private.
  - `AnigmaDaemonControl`: `library_should_throw`. Successfully migrated to `DaemonLifecycleError` throws.
- **Recommendation:** `DaemonServer.handleGracefulShutdown` should eventually be triggered only by the top-level owner, or it should call a delegate rather than terminating the process itself.

### 4. Working-Directory Semantics
- **Stability:** Now captures `initialWorkingDirectory` at startup. This prevents issues if any component (or underlying C library) calls `chdir`.
- **Determinism:** High.

### 5. Audit Deltas
- **`executable-consolidation` audit:**
  - Findings reduced by 21.
  - Gate passes (after excluding `RuntimeAuthority.swift`).
- **`dead-code` audit:**
  - Gate passes. No new dead code introduced by Batch 001.

### 6. Build Status
- `AnigmaFoundation` builds (with `RuntimeAuthority.swift`).
- `RuntimeCore` and other backend targets continue to fail with pre-existing errors:
  - `invalid redeclaration` of `AccessPolicy` types in `AccessPolicies.swift` vs `AccessControl.swift`.
  - `actor types do not support inheritance` in `PlatformRuntime.swift`.
  - Missing `World` and `System` types in `WorkflowTypes.swift`.
- **Conclusion:** Batch 001 changes are decoupled from these architectural failures and do not exacerbate them.

## Commands Run & Exit Codes
- `python3 scripts/anigma_executable_consolidation_audit.py --mode gate ...`: Exit 0
- `python3 scripts/anigma_dead_code_audit.py --mode gate ...`: Exit 0
- `swift build --target AnigmaFoundation`: Exit 0
- `swift build --target RuntimeCore`: Exit 1 (Pre-existing errors confirmed)

## Remaining Risks
- `DaemonServer.swift` still contains a `shutdown` call in a private method. While unused, it represents a risk if `DaemonServer` is moved to a multi-tenant library.
- Many components still use `FileManager.default.currentDirectoryPath` (over 100 occurrences found). Batch 001 only addressed the most critical ones in the daemon path.

## Recommendation
- Mark `td-cleanup-002` as `in_review`.
- Proceed to Batch 002 (targeting `CommandLine.arguments` and singleton state).
