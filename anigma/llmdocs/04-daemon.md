# Daemon Architecture

## Entry Point
- The daemon executable target is defined in `Packages/AnigmaDaemon/Sources/AnigmaDaemon/AnigmaDaemon.swift`.
- Core runtime logic lives in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.

## Core Responsibilities
- The daemon owns orchestration for storage, job execution, governance checks, telemetry, and service routing.
- `DaemonServer` initializes telemetry, the vault authority, database access, job queue, worker pool, and HTTP server.
- Integrated services include the model registry, agents, export engine, and runtime platform governance.

## Job and Service Handling
- Job submission and status endpoints are handled in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Jobs.swift`.
- Specialized request handlers are implemented as extensions under `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers`.

## Runtime Dependencies
- Governance and contracts from `Packages/GovernanceCore` and `Packages/ContractsCore` gate daemon operations.
- Storage is backed by `Packages/StorageCore` and `Packages/DatabaseCore`.
- Telemetry and observability are driven by `Packages/TelemetryCore`.

## Key References
- `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
- `Packages/AnigmaDaemon/Sources/AnigmaDaemon/AnigmaDaemon.swift`
