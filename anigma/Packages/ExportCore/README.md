ExportCore package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/ExportCore/Sources`

Public surface:
- SwiftPM target `ExportCore` (see `Package.swift`).

Build/test:
- `swift build --target ExportCore`

Related docs:
- `../../llmdocs/17-export-and-artifacts.md`
- `../../llmdocs/18-build-and-release.md`
