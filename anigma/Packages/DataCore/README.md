DataCore package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/DataCore/Sources`

Public surface:
- SwiftPM target `DataCore` (see `Package.swift`).

Build/test:
- `swift build --target DataCore`

Related docs:
- `../../llmdocs/16-data-engine-and-ui.md`
- `../../llmdocs/18-build-and-release.md`
