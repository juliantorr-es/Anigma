CHarfBuzz package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/CHarfBuzz/Sources`

Public surface:
- SwiftPM target `CHarfBuzz` (see `Package.swift`).

Build/test:
- `swift build --target CHarfBuzz`

Related docs:
- `../../llmdocs/08-capsules.md`
- `../../llmdocs/18-build-and-release.md`
