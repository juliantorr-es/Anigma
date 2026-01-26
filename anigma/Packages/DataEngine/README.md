DataEngine package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/DataEngine/Sources`

Public surface:
- SwiftPM target `DataEngine` (see `Package.swift`).

Build/test:
- `swift build --target DataEngine`

Related docs:
- `../../llmdocs/16-data-engine-and-ui.md`
- `../../llmdocs/18-build-and-release.md`
