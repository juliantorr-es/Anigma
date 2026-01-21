# ADR-0010: ExecutionCore Rails Without Policy

## Context
Anigma had overlapping execution/orchestration mechanisms across PraxisCore, PraxisModule, and HarmoniaSpine. Execution behavior (phase transitions, command ledger, receipts) risked becoming entangled with policy evaluation (doctrine checks, trust tier decisions) in HarmoniaModule.

We need a single execution spine that produces deterministic, auditable receipts and supports transport abstractions, while preserving a hard boundary: policy decisions remain owned by HarmoniaModule.

Telemetry is required for observability, but must remain privacy-safe and must not become a side-channel for user data.

## Problem Statement
Create an execution rails system that unifies execution primitives (receipts, phase gates, command ledger, transport abstractions) without introducing governance drift (policy logic inside the execution layer), and with deterministic wire formats suitable for auditing and evidence workflows.

## Decision
Introduce a new module, `ExecutionCore`, implementing execution primitives only:
- Receipt generation and storage interfaces via `ReceiptEngine` and `ReceiptWire`
- Phase transition mechanical validation via `PhaseGateEngine` (structural invariants only)
- Deterministic command ledger (`CommandLedger`) with JSONL output
- Transport abstractions (`Transport`) without policy logic

Policy evaluation is not implemented in ExecutionCore. ExecutionCore defines a protocol boundary:
- `PolicyEvaluator` (or equivalent) is defined in ExecutionCore and implemented by HarmoniaModule.
- ExecutionCore records policy outcomes in receipts but does not compute them.

Observability is performed through `TelemetryCore` only, using privacy-by-construction telemetry values.

## Alternatives Considered
1. **Keep orchestration spread across PraxisCore/PraxisModule/HarmoniaSpine**  
   *Rejected*: duplicates mechanisms, increases risk of divergent receipt formats and bypassable chokepoints.

2. **Move policy logic into ExecutionCore for convenience**  
   *Rejected*: creates governance drift by making execution the policy brain. Violates authority boundaries and increases risk of bypass paths.

3. **Keep existing rails and only add receipts**  
   *Rejected*: still leaves multiple orchestration paths and does not enforce a single deterministic receipt/phase/ledger architecture.

## Consequences
### Positive
- **Single execution spine** reduces duplicate mechanisms and reduces governance failure surface.
- **Deterministic wire formats** enable reproducible audit trails.
- **Protocol boundary** keeps HarmoniaModule as the sole policy brain.
- **ExecutionCore becomes the natural host** for future unified tool execution spine (e.g. MCP) without policy drift.

### Negative
- **Requires a migration period** with shims/forwarding targets to preserve existing imports.
- **Some call sites must be refactored** to route decisions through HarmoniaModule and record via ExecutionCore.

## Security and Privacy Posture
ExecutionCore must not evaluate doctrine, trust tiers, or permissions. It may only:
- Accept decisions from HarmoniaModule
- Record those decisions with receipts and audit events
- Emit privacy-safe telemetry via TelemetryCore

Telemetry values in ExecutionCore are limited to safe types (numeric, boolean, whitelisted limited tags, cryptographic hashes/tokens). No raw user strings are permitted.

## Audit and Evidence Story
ExecutionCore produces `ReceiptWire` as the canonical, deterministic wire representation:
- `timestampMs` is an `Int64` for deterministic encoding
- JSON encoding is stable (sorted keys) for reproducible logs
- Signature fields are supported via injected signers; ExecutionCore does not hardcode signing authority

Receipt emission is paired with telemetry events (privacy-safe) such as:
- `receipt_created`
- `phase_transition_attempted` / `phase_transition_completed`
- `ledger_append_failed`

Allowed and denied decisions are both recorded. ExecutionCore records what happened, not why it was allowed.

## Provenance Note
This design is derived by interpretation and redesign from observed orchestration patterns across multiple systems. No upstream code is copied or imported.

## Status
Accepted and implemented in Phase H.2.

## Implementation Notes
- ExecutionCore does not import HarmoniaModule.
- HarmoniaModule implements `PolicyEvaluator` and supplies policy decisions.
- PraxisCore/PraxisModule/HarmoniaSpine are migrated to forwarding shims.
- Tests must assert:
  - deterministic receipt encoding
  - no HarmoniaModule import from ExecutionCore
  - telemetry payloads contain no raw strings and remain within TelemetryCore safe types

## Open Questions
- Should ExecutionCore provide built-in signer/transport implementations for testing, or keep them injectable only? (Current design: injectable only)
- Should we provide migration utilities for existing receipt/ledger formats, or keep compatibility only through shims? (Current design: shims only)

## Success Criteria
- [x] ExecutionCore builds successfully
- [x] No policy evaluation logic in ExecutionCore
- [x] ReceiptWire uses Int64 timestamps and sorted JSON encoding
- [x] TelemetryCore integration uses only safe telemetry values
- [x] PolicyEvaluator protocol boundary is respected
- [x] Tests prove invariants and demonstrate non-drift