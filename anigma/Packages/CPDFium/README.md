CPDFium package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/CPDFium/Sources`

Public surface:
- SwiftPM target `CPDFium` (see `Package.swift`).

Build/test:
- `swift build --target CPDFium`

Related docs:
- `../../llmdocs/08-capsules.md`
- `../../llmdocs/18-build-and-release.md`
