# TD Followup: Runtime Lifecycle and Resource Ownership Projection

## Projection: ProcessLifecycleTerminationProjection
- **Current Shape**: Modules call `exit()` or `fatalError()` when they encounter unrecoverable errors. `RuntimeAuthority` has a `shutdown(exitCode:)` that calls `exit()` directly.
- **Recommended Shape**: 
  - Modules throw a `LifecycleError` or return a `TerminatingResult` to the `DaemonServer` or their parent owner.
  - `RuntimeAuthority` acts only as the final "system exit" seam that allows for registered cleanup hooks to execute.
  - Direct `exit()` calls are banned from non-daemon-main entrypoints.
- **Boundaries**: `RuntimeAuthority` is the exit seam. `DaemonServer` orchestrates hooks. Modules own their own error-to-signal conversion.

## Projection: DaemonResourceOwnershipProjection
- **Current Shape**: Implicit process-wide ownership using `FileManager.default.currentDirectoryPath`, environment-based config, and shared static singletons.
- **Recommended Shape**:
  - `DaemonServer` initializes explicit resource handles (e.g., `daemonTempDir`, `daemonLogCategory`) and passes them down via dependency injection.
  - Modules do not use static shared instances; they are owned by the `DaemonServer` or their relevant manager.
- **Boundaries**: `DaemonConfiguration` is the ingress. Modules receive handles, not raw environment values.

## Future Tasks
- Implement `LifecycleHookRegistry` inside `DaemonServer` or a specific `DaemonLifecycleManager` that `RuntimeAuthority` calls during `shutdown()`.
- Implement a `ConfigurationAuthority` that translates the `DaemonConfiguration` into specific per-worker resource handles before passing them to the workers.
- Audit the remaining high-risk `exit()` sites identified in `Docs/proofs/executable-consolidation-audit-2026-05-05.md`.
