InferenceCore package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/InferenceCore/Sources`

Public surface:
- SwiftPM target `InferenceCore` (see `Package.swift`).

Build/test:
- `swift build --target InferenceCore`

Related docs:
- `../../llmdocs/15-model-registry-ml.md`
- `../../llmdocs/18-build-and-release.md`
