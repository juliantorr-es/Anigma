Primary Swift source tree for the root package.
Invariants: keep modules governed, avoid direct IO, and preserve determinism in capsule wrappers.

Entry points:
- `Sources/AnigmaAppMac`
- `Sources/AnigmaMCPModule`
- `Sources/ContextumModule`

Public surface:
- Root package targets and executables.

Build/test:
- `swift build`
- `swift test`

Related docs:
- `../llmdocs/01-architecture-overview.md`
- `../llmdocs/06-mac-app.md`
