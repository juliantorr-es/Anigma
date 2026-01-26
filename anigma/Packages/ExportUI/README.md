ExportUI package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/ExportUI/Sources`

Public surface:
- SwiftPM target `ExportUI` (see `Package.swift`).

Build/test:
- `swift build --target ExportUI`

Related docs:
- `../../llmdocs/17-export-and-artifacts.md`
- `../../llmdocs/18-build-and-release.md`
