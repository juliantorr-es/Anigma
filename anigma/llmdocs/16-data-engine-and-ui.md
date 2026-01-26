# Data Engine and UI Stack

## Data Foundations
- `DataCore` provides shared data primitives in `Packages/DataCore` (declared in `Package.swift`).
- `DataEngine` extends data services in `Packages/DataEngine` and is used by the daemon and UI layers.

## Rendering and UI
- `RendererKit` provides rendering helpers for data visualization in `Packages/RendererKit`.
- UI composition is handled by `Packages/DataUI` and consumed by higher-level surfaces.

## Workflow Layer
- Workflow execution and orchestration live in `Packages/Workflows`.
- The daemon wires data engine services in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.

## Key References
- `Package.swift`
- `Packages/DataCore`
- `Packages/DataEngine`
