ModelRegistry package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/ModelRegistry/Sources`

Public surface:
- SwiftPM target `ModelRegistry` (see `Package.swift`).

Build/test:
- `swift build --target ModelRegistry`

Related docs:
- `../../llmdocs/15-model-registry-ml.md`
- `../../llmdocs/18-build-and-release.md`
