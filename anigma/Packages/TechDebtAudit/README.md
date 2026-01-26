TechDebtAudit package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/TechDebtAudit/Sources`

Public surface:
- SwiftPM target `TechDebtAudit` (see `Package.swift`).

Build/test:
- `swift build --target TechDebtAudit`

Related docs:
- `../../llmdocs/11-jobs-and-workflows.md`
- `../../llmdocs/18-build-and-release.md`
