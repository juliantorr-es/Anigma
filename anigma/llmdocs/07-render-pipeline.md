# Render Pipeline and UI Runtime

## Runtime Orchestrator
- The render/runtime backbone is `Sources/RuntimeOrchestrator/RuntimeOrchestrator.swift`.
- The orchestrator coordinates `SceneGraphCapsule` and `RenderPlanCapsule` for transform evaluation and frame data.

## Platform Adapters
- Platform-specific glue is defined in `Sources/PlatformAdapters` as a target in `Package.swift`.
- `Sources/AnigmaUI` builds atop the adapters and runtime orchestrator to expose UI surfaces.

## Core Pipeline Flow
- Scene nodes are attached to the scene graph and evaluated each frame.
- A `frameTick()` call serializes node data into a binary payload for downstream rendering paths.
- The runtime keeps viewport size and scale state to support macOS display handling.

## Key References
- `Sources/RuntimeOrchestrator/RuntimeOrchestrator.swift`
- `Sources/PlatformAdapters`
- `Sources/AnigmaUI`
