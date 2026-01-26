Test suites and fixtures.
Invariants: keep fixtures deterministic, avoid external network, and track governance expectations.

Entry points:
- `Tests/` targets in `Package.swift`.

Public surface:
- Unit, integration, and governance tests.

Build/test:
- `swift test`
- `swift test --filter <TargetName>`

Related docs:
- `../llmdocs/19-testing-and-quality.md`
