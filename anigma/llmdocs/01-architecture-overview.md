# Architecture Overview

## Product Scope
- The repository ships the Anigma macOS product stack: a GUI app, a background daemon, and multiple command-line surfaces.
- The primary entry points are the mac app at `App/MacApp/AnigmaApp.swift`, the daemon binary defined in `Packages/AnigmaDaemon/Sources/AnigmaDaemon/AnigmaDaemon.swift`, and the CLI entry in `Packages/AnigmaCLI/Executable/Main.swift`.
- Core build and architecture assumptions are summarized in `README.md`.

## Core Layers
- The system is a modular monolith organized around SwiftPM packages defined in `Package.swift`.
- Core runtime layers live in packages such as `Packages/AnigmaCore`, `Packages/AnigmaFoundation`, `Packages/ContractsCore`, `Packages/DatabaseCore`, and `Packages/StorageCore`.
- Capability and domain modules build on top of core services and are exposed via executable targets like `anigma`, `anigma-app`, and `anigmad` in `Package.swift`.

## Execution Surfaces
- Mac app shell: SwiftUI entry in `App/MacApp/AnigmaApp.swift`, view composition in `App/MacApp/RootView.swift`, and role-based shells in `App/MacApp/Roles`.
- Daemon runtime: `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift` coordinates telemetry, storage, jobs, and HTTP services.
- CLI and TUI: `Packages/AnigmaCLI/Executable/Main.swift` exposes plan/run/tui commands and uses `Packages/AnigmaCLI/Sources/TUI` for interactive sessions.

## Governance Backbone
- Governance principles are codified in `Docs/governance/AnigmaConstitution.md` and related policy docs.
- Runtime governance enforcement is implemented in `Packages/GovernanceCore` and wired through the daemon and CLI layers.

## Key References
- `README.md`
- `Package.swift`
- `Docs/governance/AnigmaConstitution.md`
