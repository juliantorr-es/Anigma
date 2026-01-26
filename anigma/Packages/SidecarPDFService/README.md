SidecarPDFService package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/SidecarPDFService/Sources`

Public surface:
- SwiftPM target `SidecarPDFService` (see `Package.swift`).

Build/test:
- `swift build --target SidecarPDFService`

Related docs:
- `../../llmdocs/14-sidecar-and-bridge.md`
- `../../llmdocs/18-build-and-release.md`
