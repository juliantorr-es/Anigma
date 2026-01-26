LayoutEngineCapsule package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/LayoutEngineCapsule/Sources`

Public surface:
- SwiftPM target `LayoutEngineCapsule` (see `Package.swift`).

Build/test:
- `swift build --target LayoutEngineCapsule`

Related docs:
- `../../llmdocs/08-capsules.md`
- `../../llmdocs/07-render-pipeline.md`
