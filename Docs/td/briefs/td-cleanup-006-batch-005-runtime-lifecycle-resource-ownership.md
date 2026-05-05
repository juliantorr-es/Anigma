# TD Cleanup Brief: Batch 005 - Runtime Lifecycle and Resource Ownership

## Overview
This batch addresses process-identity and resource-ownership assumptions introduced by the consolidation of formerly standalone executable sidecars into the centralized `anigmad` daemon process.

## Batch Goals
1. **Lifecycle Triage**: Identify and classify direct `exit()` / `fatalError()` calls that are daemon-reachable.
2. **Resource Triage**: Identify and classify implicit global/process-local resource assumptions (CWD, PID files, lock files, singleton state).
3. **Boundary Projection**: Define the interface for `RuntimeAuthority` to serve as a gateway for process lifecycle, rather than an arbitrary registry.
4. **Targeted Repair**: Perform narrow repairs only on daemon-reachable findings to ensure daemon stability.

## Governance Doctrines
- **RuntimeAuthority** defines the process-boundary: (working directory snapshot, final exit seam). It is not a service locator or task registry.
- **DaemonServer** composes lifecycle owners, but does not own every module's individual cleanup.
- Modules must signal termination via errors/results, never by calling `exit()` or `abort()`.
- **Injected Resources**: Workers should receive their temp paths, logs, and config via injection/configuration, not via implicit global discovery (`NSTemporaryDirectory`, `FileManager.default.currentDirectoryPath`).

## Projections
- **ProcessLifecycleTerminationProjection**: Defines the seam where module-level termination requests are converted into daemon-level lifecycle events.
- **DaemonResourceOwnershipProjection**: Defines the pattern for passing explicit resource handles (temp directories, log handles) to modules via `DaemonConfiguration` rather than having them discover it via environment variables.

## Risks
- **Over-Consolidation**: `DaemonServer` becoming a god object.
- **Ambiguous Ownership**: Singleton state (`static let shared`) colliding after process merger.
- **Unexpected Termination**: Modules killing the daemon process because they assume they are still standalone helper binaries.

## Batch Status
- Status: `in_progress`
- Focus: `anigmad`
- Rig Task: `td-cleanup-006`
