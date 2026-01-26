# Sidecar and Daemon Bridge

## Sidecar Package
- The sidecar layer is implemented in `Packages/AnigmaSidecar` and exposed as a library product in `Package.swift`.
- The sidecar is responsible for managing daemon lifecycle and communication from client surfaces.

## Daemon Lifecycle
- `Packages/AnigmaSidecar/DaemonLifecycle.swift` provides start/stop/status/restart for `anigmad`.
- Socket paths and binary resolution are configured via `Packages/AnigmaSidecar/SidecarConfig.swift`.

## Guardian and Bridge
- `Packages/AnigmaSidecar/DaemonGuardian.swift` ensures daemon availability before CLI operations.
- `Packages/AnigmaSidecar/SidecarBridge.swift` provides the client API for daemon health checks and execution.

## Key References
- `Packages/AnigmaSidecar/DaemonLifecycle.swift`
- `Packages/AnigmaSidecar/DaemonGuardian.swift`
- `Packages/AnigmaSidecar/SidecarBridge.swift`
