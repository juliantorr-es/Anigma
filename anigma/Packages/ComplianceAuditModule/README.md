ComplianceAuditModule package targets and local APIs.
Invariants: respect governance boundaries, keep outputs deterministic, avoid direct IO outside authorities.

Entry points:
- `Packages/ComplianceAuditModule/Sources`

Public surface:
- SwiftPM target `ComplianceAuditModule` (see `Package.swift`).

Build/test:
- `swift build --target ComplianceAuditModule`

Related docs:
- `../../llmdocs/09-governance.md`
- `../../llmdocs/19-testing-and-quality.md`
