Rendering and platform bridge adapters.
Invariants: keep adapters stateless, thread-safe, and deterministic per frame.

Entry points:
- `PlatformAdapters/MetalRenderAdapter.swift`
- `PlatformAdapters/Shaders.metal`

Public surface:
- Metal renderer and platform-specific adapter APIs.

Build/test:
- `swift build --target PlatformAdapters`

Related docs:
- `../llmdocs/07-render-pipeline.md`
- `../llmdocs/06-mac-app.md`
