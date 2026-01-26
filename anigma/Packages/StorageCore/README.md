StorageCore package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/StorageCore/Sources`

Public surface:
- SwiftPM target `StorageCore` (see `Package.swift`).

Build/test:
- `swift build --target StorageCore`

Related docs:
- `../../llmdocs/10-storage.md`
- `../../llmdocs/18-build-and-release.md`
