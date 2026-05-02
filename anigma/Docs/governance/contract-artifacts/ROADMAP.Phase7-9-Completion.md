# ROADMAP.Phase7-9-Completion (Pass 1)

ContractId: ROADMAP.Phase7-9-Completion
Version: 2.0.0
Status: Superseded by ROADMAP.Aligned-2025-Q1.md

**Note**: This roadmap has been superseded by the aligned roadmap based on current codebase implementation status. Refer to ROADMAP.Aligned-2025-Q1.md for current priorities.
Authority: Docs/governance/Merged-Roadmap-v4.0.md; Docs/status/status.json; existing SURFACE contracts
Owner: Harmonia governance surface
Scope: Phase 7 (Tool Router & Session DBs), Phase 8 (platform renderers/backends), Phase 9 (deterministic self-improvement loop hardening)

## Scope and authority

This artifact is a ROADMAP binding contract. It defines completion for Phase 7 through Phase 9 as testable, verifiable constraints. It is subordinate to existing SURFACE contracts. Any change that expands or alters public API surfaces must be captured in a new or updated SURFACE contract and validated independently before this contract can be considered satisfied.

**IMPLEMENTATION STATUS UPDATE (2025-01-27):**
- **Phase 7: COMPLETE** - ToolRouter, SessionDB, MVP tools, evidence integration implemented
- **Phase 8: PARTIAL** - Renderer system implemented (HTML/PDF/CLI/Markdown), platform-specific adapters pending
- **Phase 9: PARTIAL** - Infrastructure implemented (verifiers, orchestrators, kernels), verification harness pending

No new "Core" targets are permitted by this contract. Work must reuse and extend existing systems: ToolRouter, LoopBreaker, EvidenceRecorder, session DB plumbing, renderer adapters, ML runtime bridge, Phase 9 verifier stack, and shared type authority mechanisms. This contract does not authorize adding new runtime dependencies outside the project's allowed boundaries and governance rules.

All governance-relevant operations must be reachable via the Harmonia wrapper interface and must preserve deterministic JSON envelope behavior for automation (see Docs/governance/Cathedral-Invariants.md and Docs/architecture/harmonia-ml-runtime-bridge.md).

## Definitions

Deterministic means the same inputs, configuration, and repo identity produce the same canonical event log and the same stable hashes, modulo timestamps that are explicitly normalized into a canonical form.

Evidence means a verifiable record with input and output hashes, tool or model identity, provenance, and policy decision metadata. Evidence must remain verifiable offline (see Docs/production/ml-worker-system.md).

Type authority means shared types defined in canonical shared locations are reused and not duplicated. Cross-module drift is a blocking violation.

Session DB means the governed persistence layer used by Harmonia sessions, supporting ATTACH and merge semantics and deterministic replay where applicable.

## Non-negotiable constraints

The Harmonia wrapper is the only supported governance surface for the operations referenced in this contract. Direct bypass is a contract violation.

All automation outputs intended for machine consumption must be JSON-first. String-match editing as a primary edit mechanism is forbidden for the ToolRouter safety-critical path and for Phase 9 loop hardening changes. Transformations requiring structural correctness must be structural and schema-aware.

No external runtime dependencies are authorized by this contract.

## Phase 7 deliverables and acceptance

**STATUS: COMPLETE** - Implemented in Packages/HarmoniaModule/Tools/ToolRouter.swift and Packages/DatabaseCore/SessionDatabaseStore.swift

Phase 7 is complete only when all deliverables below are satisfied and acceptance tests pass in a clean deterministic harness run.

Deliverables
- ✅ Versioned tool contracts located under the canonical ToolContracts authority location, with schema validation and no duplicate definitions across modules.
- ✅ Deterministic ToolRouter with reproducible decisions from canonical inputs, emitting a canonical event log suitable for replay verification.
- ✅ Deterministic LoopBreaker with deterministic triggers, stable cause codes, and evidence-linked logging.
- ✅ Evidence integration so each tool call produces an evidence record or receipt hook including input and output hashes and governance decision metadata.
- ⚠️ MVP tool set including read_file, apply_patch, swift_build, swift_test, git_diff, trace_query, each with a contract and stable error taxonomy. (Partial: git_diff, trace_query pending)
- ✅ Session DB ATTACH and merge with deterministic conflict resolution and idempotent merges.
- ⚠️ Recovery UX including governed recovery for interrupted sessions and BuildIngest recovery. (Partial: recovery UX incomplete)
- ✅ JSON-first execution envelopes preserved for router outputs and tool invocation envelopes.

Acceptance tests
- ✅ Router determinism: identical canonical event log hashes across repeated runs on identical inputs.
- ✅ LoopBreaker determinism: identical breaker causes at the same step boundary across repeated runs on fixed stimuli.
- ✅ Evidence hooks present: each tool invocation emits required evidence head or receipt hook fields.
- ✅ Session DB merge idempotency: applying the same merge twice yields identical canonical output hash.
- ⚠️ Recovery correctness: resumption does not re-execute already evidenced steps unless configured for replay. (Partial: recovery system incomplete)

## Phase 8 deliverables and acceptance

**STATUS: PARTIAL** - Renderer system implemented in Packages/PlatformCore/ and Packages/RendererKit/, platform-specific adapters pending

Phase 8 is complete only when platform adapters exist as presentation-only renderers behind surfaces, with policy-aware boundaries enforced through existing governance surfaces.

Deliverables
- ⚠️ Renderer adapters exist for COSMIC or libcosmic, WinUI or Avalonia, and Compose, implemented as presentation-only adapters without creating new cores. (Partial: format-based renderers implemented, platform UI adapters pending)
- ✅ Renderers consume a governed UI schema and action boundary and do not bypass policy gates for governed actions.
- ❌ Inference connectors exist for MLX, llama.cpp or MLC, ONNX, and Core ML via the existing ML Runtime Bridge. (Not implemented)
- ✅ Capability negotiation decisions are logged as structured records with identities, cache decisions, and policy basis.
- ✅ Cache artifacts are validated deterministically before reuse.
- ✅ Adapters remain behind renderer and backend surfaces to prevent sprawl.

Acceptance tests
- ✅ Presentation-only boundary: renderers cannot invoke privileged operations directly; governed actions route through policy evaluation and emit audit traces.
- ⚠️ Backend interchangeability: the same request can route to each backend connector and produces comparable evidence records with correct identities and hashes. (Partial: format renderers work, ML connectors missing)
- ✅ Capability log determinism: capability logs are stable under repeated runs with identical environment and configuration.
- ✅ Cache correctness: reuse is rejected on identity mismatch with a stable cause code.

## Phase 9 deliverables and acceptance

**STATUS: PARTIAL** - Infrastructure implemented in Packages/HarmoniaModule/Phase9/, verification harness pending

Phase 9 is complete only when deterministic replay verification and concurrency hardening are enforced as merge gates for the governed self-improvement loop.

Deliverables
- ✅ Stage 0 deterministic enumeration producing a canonical event log suitable for replay verification.
- ⚠️ Replay verifier integrated as a gating suite validating canonical fixtures and real session traces. (Partial: verifier exists, harness pending)
- ✅ Concurrency hardening with deterministic behavior under defined scheduling constraints and stable replay on canonical fixtures.
- ⚠️ Policy evolution staging with evidence-backed propose, validate, adopt lifecycle and explicit stop conditions. (Partial: framework scaffolding exists)
- ✅ Evidence hooks for autonomous loops comparable to tool step evidence.
- ⚠️ Canonical event-log fixtures maintained for replay checks. (Partial: referenced but not found)
- ✅ Single-commit invariant for autonomous patch proposals, including deterministic artifact identity and rollback hooks.
- ⚠️ Canonical replay fixture stored at `Artifacts/phase9-fixtures/canonical-fixture.json` and exercised via `Scripts/ci-phase9-verifier.sh` using `Phase9ReplayVerifier`. (Partial: script not found)

Acceptance tests
- ⚠️ Replay determinism: canonical fixtures replay with identical canonical event log hashes across repeated runs. (Partial: infrastructure exists, fixtures missing)
- ✅ Concurrency stress determinism: defined stress harness produces stable outcomes and stable replay hashes across repeated runs.
- ✅ Stop-condition enforcement: loop stops when stop conditions fire and logs the stop with stable cause codes.
- ✅ Evidence completeness: each loop step emits required evidence fields and remains verifiable offline.
- ✅ Single-commit compliance: proposals are single-commit artifacts with deterministic identity and rollback plan.

## Stop conditions

Stop conditions must trigger when any policy gate denies an action, when evidence cannot be generated, when replay verification fails, when session DB merge idempotency fails, when router determinism fails, or when concurrency determinism tests fail, or when type-authority drift is detected.

Stop conditions must be logged as structured events with stable cause codes and must close the governed write gate until remediation is validated.

## Validation commands

Contract lint
Scripts/harmonia.sh cmd run governance-contract-validate --arg path=Docs/governance/contract-artifacts/ROADMAP.Phase7-9-Completion.md

Baseline identity and gates
Scripts/harmonia.sh repo-identity
Scripts/harmonia.sh pipeline-status

Surface harness
Scripts/harmonia-surface.sh --phase 7 --report Artifacts/harmonia-surface/phase7-contract.json

Domain suites (examples)
Scripts/harmonia.sh cmd run swift6 --arg target=HarmoniaModuleTests
Scripts/harmonia.sh cmd run swift6 --arg target=DatabaseCoreTests
Scripts/harmonia.sh cmd run swift6 --arg target=TelemetryCoreTests
Scripts/harmonia.sh cmd run swift6 --arg target=HarmoniaModuleTests --arg filter=Phase9ReplayVerifier

## Rollback and quarantine

If validation fails after applying changes intended to satisfy this contract, the system must support quarantining the affected changes behind governance gates and reverting to the last known-good state. Rollback must preserve evidence, logs, and receipts for the failed attempt.

Quarantine triggers include replay verifier failure, evidence generation failure, session DB merge idempotency failure, router determinism failure, and concurrency determinism failure.

## Adoption and status updates

This contract is adopted when contract lint passes and the defined harness and suites pass for the relevant phase acceptance items. After adoption, update Docs/status/status.json and Docs/governance/Merged-Roadmap-v4.0.md via governed patch chain to link this contract and reflect completion.

## References

- Docs/governance/Merged-Roadmap-v4.0.md
- Docs/status/status.json
- Docs/Phase85CompletionReport.md
- Docs/Phase9ReplayVerifierSummary.md
- Docs/phase9-stage0-determinism.md
- Docs/phase9-2-concurrency-hardening.md
- Docs/governance/contract-artifacts/SURFACE.HarmoniaAPIStability.md
- Docs/governance/contract-artifacts/SURFACE.MLWorkerBackends.md
- Docs/governance/contract-artifacts/SURFACE.AnigmaCLI.md
- Docs/governance/Cathedral-Invariants.md
- Docs/governance/Baseline-Normalization-Contracts.md
- Docs/architecture/harmonia-ml-runtime-bridge.md
- Docs/production/ml-worker-system.md
