SwiftPM packages and module boundaries.
Invariants: do not cross authority boundaries without governance; keep targets deterministic and modular.

Entry points:
- Package targets under `Packages/*/Sources`.

Public surface:
- Libraries, executables, and support modules.

Build/test:
- `swift build --target <TargetName>`
- `swift test --filter <TargetName>` (if tests exist)

Related docs:
- `../llmdocs/03-module-index.md`
- `../llmdocs/18-build-and-release.md`
