MediaContainerCapsule package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/MediaContainerCapsule/Sources`

Public surface:
- SwiftPM target `MediaContainerCapsule` (see `Package.swift`).

Build/test:
- `swift build --target MediaContainerCapsule`

Related docs:
- `../../llmdocs/08-capsules.md`
- `../../llmdocs/17-export-and-artifacts.md`
