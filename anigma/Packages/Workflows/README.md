Workflows package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/Workflows/Sources`

Public surface:
- SwiftPM target `Workflows` (see `Package.swift`).

Build/test:
- `swift build --target Workflows`

Related docs:
- `../../llmdocs/11-jobs-and-workflows.md`
- `../../llmdocs/18-build-and-release.md`
