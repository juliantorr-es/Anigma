Runtime core support modules and low-level orchestration.
Invariants: preserve authority boundaries and deterministic execution paths.

Entry points:
- Runtime sources under `RuntimeCore/`.

Public surface:
- Runtime helpers used by core services.

Build/test:
- `swift build --target RuntimeCore` (if target exists)

Related docs:
- `../llmdocs/01-architecture-overview.md`
- `../llmdocs/09-governance.md`
