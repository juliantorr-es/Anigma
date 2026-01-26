# Governance System

## Constitutional Rules
- The system's governing principles are documented in `Docs/governance/AnigmaConstitution.md`.
- Supporting policy documents live in `Docs/governance` and `Docs/governance/phases`.

## Runtime Enforcement
- Governance runtime logic is in `Packages/GovernanceCore` and wired into `Packages/AnigmaDaemonCore`.
- Contract boundaries are reinforced through `Packages/ContractsCore` and CLI governance surfaces in `Packages/AnigmaCLI/Governance`.

## Receipts and Audit Trails
- Receipt generation is integrated into daemon operations in `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`.
- Storage of governance receipts is backed by the vault logic in `Packages/StorageCore`.

## Tooling and Policies
- Dependency boundary and governance rules are documented in files like `Docs/governance/Dependency-Boundary-Policy.md`.
- Governance enforcement spans CLI policy checks and daemon audit logic (see `Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers`).

## Key References
- `Docs/governance/AnigmaConstitution.md`
- `Packages/GovernanceCore`
- `Packages/AnigmaCLI/Governance`
