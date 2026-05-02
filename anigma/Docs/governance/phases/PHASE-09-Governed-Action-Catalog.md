# Phase 9: Governed Action Catalog

## Context
With Concurrency (Phase 8) complete, the ecosystem is thread-safe. Now we must ensure it is *logic-safe*. Phase 9 establishes the **Governed Action Catalog**, a declarative registry where all sensitive operations are defined, and the **Authority**, which enforces these definitions.

## Contracts

### 1. Action Definition
Every sensitive action (e.g., "ReadFile", "NetworkRequest") must be defined in the `ActionCatalog`.
- **Name**: Unique identifier (e.g., `filesystem.read`).
- **Parameters**: Schema defining required inputs (e.g., `path`, `allow_recursive`).
- **Policy**: default `allow` or `deny`, or reference to a more complex policy.

### 2. The Authority
The `AnigmaAuthority` (HostKit) is the sole arbiter of action execution.
- It MUST consult the `ActionCatalog` to validate parameter structure.
- It MUST consult the `Governance` system to check permissions.
- It MUST log every decision to the `AuditLog`.

### 3. Verification
routing logic must be verified by `SmokeTestRenderer`, ensuring that:
- Allowed actions proceed.
- Denied actions are blocked with a clear reason.
- Malformed actions (invalid parameters) are rejected.

## Implementation Details
The `ActionCatalog` is implemented as a singleton in `ContractsCore`.
- **Registry**: `ActionCatalog.shared.actions`
- **Validation codes**:
  - `SCHEMA_UNREACHABLE`: Action not found in catalog.
  - `INVALID_PARAMETERS`: Parameter types do not match schema.
  - `SCOPE_VIOLATION`: Permission denied by `CapabilityToken`.

## Acceptance Criteria
- [x] `ActionCatalog` is implemented in `ContractsCore` and populated with core actions.
- [x] `AnigmaAuthority` enforces catalog validation before execution.
- [x] `SmokeTestRenderer` demonstrates a "Denied" action flow invoked via CLI or test harness.
