SidecarOfficeService package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/SidecarOfficeService/Sources`

Public surface:
- SwiftPM target `SidecarOfficeService` (see `Package.swift`).

Build/test:
- `swift build --target SidecarOfficeService`

Related docs:
- `../../llmdocs/14-sidecar-and-bridge.md`
- `../../llmdocs/18-build-and-release.md`
