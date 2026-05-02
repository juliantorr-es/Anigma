# SURFACE.PraxisModule

## Surface Definition

**Surface Name**: PraxisModule  
**Authority Boundary**: Capability Module layer compliant with Harmonia governance (AnigmaCore/Harmonia surface remains primary).  
**Implementation Location**: `Sources/PraxisModule` (rulepack, workflow spec, session index, ticket service).  
**Lease Required**: No new lease; existing Harmonia sprint tooling governs PraxisModule changes.

## Surface API

### Public Protocols
- `PraxisModule` exposes lightweight protocols for rule evaluation, workflow inspection, session reconstruction, and boundary ticket generation.
- `Rulepack` and `WorkflowSpec` parse declarative text files under `PraxisModule/Rules` and `PraxisModule/Workflows` (or provided paths) and expose hard invariant vs policy evaluation plus stop conditions.
- `PraxisSessionIndex` ingests `.opencode/ledger/workflow.jsonl`, `.opencode/ledger/quarantine.jsonl`, and existing SwiftPM log captures, reconstructing `(SessionID → PatchHash → ReceiptChain + GateOutcome)` tuples deterministically.
- `BoundaryTicketService` produces `BoundaryTicket` artifacts (JSON envelope) when a “blocked” event occurs, citing rule IDs and receipts.

### Data Contracts
- Rulepacks define `hardInvariants: [RuleID]` and `policies: [PolicyID]` with optional exceptions (`ReceiptID`).
- WorkflowSpec defines `steps` with `phaseId`, `acceptanceRefs`, and `stopStates` including `blocked`.
- Session index exposes ordered receipt chains per patch with linked acceptanceRefs, gate results, and references to `.opencode/ledger` entries.
- BoundaryTicket includes:
  - `sessionID`, `patchHash`, `blockedStep`
  - `violatedRuleIDs`, `gateName`, `gateOutcome`
  - `evidenceRefs` (list of receipt IDs or saved logs)
  - deterministic `ticketID` (hash-based)

## Concurrency Model

- PraxisModule is read-only: it never mutates repo state. It reads ledger files and log artifacts already captured by the pipeline (no new DB yet).  
- All computations happen within the AnigmaCore actor model; derived artifacts are `Sendable`, and rule evaluations avoid shared mutable state.  
- Future persistence uses `TriMemory`/`HarmoniaMemory` per existing Core helper patterns, but MVP keeps everything in-memory.

## Stop Conditions

1. Missing ledger entries (receipt gap) halts session reconstruction with a `blocked` state and produces a boundary ticket referencing the missing receipt IDs.  
2. Rule conflict (proposed action violates a hard invariant) triggers a `blocked` state and emits tickets referencing the rule ID plus gate/ledger evidence.  
3. Governance gate failure (phase contract rejection) is treated as `blocked` with ticket citing gate name, acceptanceRef, and failure receipt.

## Acceptance Criteria

1. `<phaseId: praxis.contract>`: `PraxisSessionIndex` can load ledger/quarantine files, rebuild the ordered receipt chain for a patch, and detect missing or out-of-order entries.  
2. `<phaseId: praxis.ticket>`: `BoundaryTicketService` produces a JSON artifact with deterministic `ticketID`, the session/patch, violated rule IDs, and evidence references when provided a blocking event.  
3. `<phaseId: praxis.workflow>`: `WorkflowSpec` exposes steps with stop states beyond `done` (e.g., `blocked`), and `Rulepack` distinguishes `hardInvariants` vs `policies`.  
4. `<phaseId: praxis.cli>`: `harmonia praxis diagnose` and `harmonia praxis boundary-ticket` commands exist, output JSON envelope on stdout, diagnostics/stderr, and consume PraxisModule outputs.

## Migration Plan

1. Document the PraxisModule artifact and merge this contract to satisfy the first pass before touching implementation files.  
2. Implement PraxisModule read-only primitives; store generated ticket artifacts under `Artifacts/praxis/` or similar commit-legal path.  
3. Wire `HarmoniaCLI` to call the PraxisModule APIs; ensure the CLI extension is gated behind the existing CLI tooling (no new binary).  
4. Add tests feeding ledger samples and verifying deterministic parsing and ticket content; keep receipts/gates intact.

## Evidence Hooks

- Boundary tickets include the receipt IDs or file locations (`.opencode/ledger/…`) that triggered the block.  
- CLI commands emit JSON envelopes; Harmonia handles signing/receipt creation as usual.

---

**Contract Status**: ACTIVE  
**Last Updated**: 2025-12-19  
**Authority**: Capability Module (PraxisModule) extending Harmonia governance  
