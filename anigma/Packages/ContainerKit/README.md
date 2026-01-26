ContainerKit package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/ContainerKit/Sources`

Public surface:
- SwiftPM target `ContainerKit` (see `Package.swift`).

Build/test:
- `swift build --target ContainerKit`

Related docs:
- `../../llmdocs/03-module-index.md`
- `../../llmdocs/18-build-and-release.md`
