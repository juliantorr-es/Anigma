# TD Followup: anigmad Consolidation Cleanup Batch 001

## Task Description
Perform the first targeted cleanup of confirmed high-risk architectural assumptions in the `anigmad` and daemon-core components identified during the 2026-05-05 triage pass.

## Cleanup Items (Targeted)

1. **`AnigmaDaemonControl/main.swift`**
   - **Problem**: 3 calls to `exit(1)` in library/initialization code.
   - **Fix**: Replace with `DaemonError` throws.
   - **Rationale**: Prevent library code from unexpectedly killing the daemon process.

2. **`anigmad/main.swift`**
   - **Problem**: `fatalError` when Application Support is missing.
   - **Fix**: Replace with a clean diagnostic message and a controlled shutdown via `RuntimeAuthority`.
   - **Rationale**: Improve observability and graceful failure.

3. **`AnigmaDaemon/main.swift`**
   - **Problem**: Direct `exit(0)` and `exit(1)` calls.
   - **Fix**: Route through `DaemonLifecycle.shutdown()`.
   - **Rationale**: Ensure resource cleanup (PID files, sockets) happens before process exit.

4. **`AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`**
   - **Problem**: `exit(0)` call.
   - **Fix**: Replace with `server.stop()`.
   - **Rationale**: Use standard lifecycle hooks.

5. **`AnigmaDaemonControl/main.swift`**
   - **Problem**: Direct `CommandLine.arguments` access.
   - **Fix**: Inject arguments through `DaemonConfiguration`.
   - **Rationale**: Improve testability and decoupling from the OS process environment.

6. **`AnigmaDaemonCore/Utils/DaemonInferenceAuthority.swift`**
   - **Problem**: Assumption that `currentDirectoryPath` is stable.
   - **Fix**: Use `RuntimeAuthority.shared.workingDirectory`.
   - **Rationale**: Ensure paths are correct when running as a daemon.

## Acceptance Criteria
- Modified files build cleanly.
- `anigma_executable_consolidation_audit.py --mode gate` passes after baseline update (if applicable).
- No change in existing test pass rates.
- No new regressions in `validate_xcodebuild_debug.sh`.

## Verification Commands
```bash
# Run audit to confirm findings are gone
python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad

# Standard validation
bash scripts/validate_xcodebuild_debug.sh
```
