RendererKit package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/RendererKit/Sources`

Public surface:
- SwiftPM target `RendererKit` (see `Package.swift`).

Build/test:
- `swift build --target RendererKit`

Related docs:
- `../../llmdocs/07-render-pipeline.md`
- `../../llmdocs/18-build-and-release.md`
