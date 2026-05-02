# Contract Artifact: MakerEngine Enhancements

This document is a fulfillment contract, not a roadmap. It is considered satisfied only when the proof surfaces pass and the evidence surfaces exist at the declared paths. Human “checked” status must match mechanical validation results.

## Purpose

MakerEngine Enhancements define a swappable execution layer that upgrades MakerEngine behavior with bounded resources, deterministic evidence emission, quarantine integration, and optional native acceleration governed by the native-deps intake system. The contract is fulfilled when enhanced paths are correct, policy-compliant, determinism-validated, and evidenced.

## Scope

In scope are adapter boundaries for diff, parsing, regex validation, and policy evaluation; receipt generation and storage; quarantine integration; parallel safety under concurrency; performance measurement and regression guards; integration tests that exercise the end-to-end MakerEngine loop.

Out of scope are changes that break public API contracts in existing modules, and any “native by default” design that blocks builds when native intake is not approved.

## Current baseline reference

The baseline MakerEngine implementation exists under the current codebase (for example, `Sources/AnigmaCore/Reasoning/MakerEngine.swift`) and contracts live under `Sources/ContractsCore/…` (for example, Maker contracts). This contract does not require a specific module name beyond a single swappable layer that is selectable by configuration.

## Definitions

“Enhanced mode” means MakerEngine selects the enhancement layer through configuration or feature flag.

“Fallback mode” means all correctness and evidence behaviors work without any native dependencies, using pure Swift implementations. Fallback mode is the default to keep builds stable.

“Deterministic receipt core” means the subset of receipt fields that must be reproducible given identical inputs and the same code version. Timing and resource-usage measurements are not part of the deterministic core.

“Observational envelope” means optional measurements that are allowed to vary across runs, and are excluded from determinism assertions.

“Quarantine” means the engine refuses to reuse outputs and stores all associated artifacts and receipts in a quarantine area when a quarantinable event occurs.

## Preconditions and governance constraints

Any native dependency used by the enhancement layer must be approved through the native-deps intake flow and registered in the native dependency registry. If the intake is not approved, the native implementation must not be enabled, and fallback mode must remain fully functional.

Receipt formats and ledgers must align with existing Anigma evidence patterns. The contract assumes deterministic JSONL-style ledgers are a first-class evidence primitive and that receipts have stable wire formats (for example those already present under ExecutionCore).

## Evidence locations

Receipts for MakerEngine enhanced execution must be written under a stable artifacts path. The canonical location for payload receipts is:

`Artifacts/maker/receipts/<run-id>/<step-id>.json`

The command ledger (if used) records pointers and hashes for those receipts rather than duplicating their content. If the repository uses `.opencode/ledger/` for deterministic ledgers, the Maker run must append a summary record containing the receipt pointers and hashes.

Quarantine payloads must be written under:

`Artifacts/maker/quarantine/<quarantine-id>/…`

## Acceptance criteria and trace matrix

Each criterion below is satisfied only when the “Proof” passes and the “Evidence” exists. The “Status” checkbox is for humans and must be consistent with validation.

| Status | Criterion | Implementation surface | Proof surface | Evidence surface |
|---:|---|---|---|---|
| - [ ] | Native library contracts satisfied | Enhancement layer defines adapter protocols and optional native implementations gated by native-deps approval; fallback paths remain functional | Native-deps intake record(s) exist; gated build path passes; adapter unit tests cover both fallback and native when enabled | Native-deps IDR(s) and registry entry; build logs in CI artifacts; receipt shows adapter id/version and indicates native vs fallback |
| - [ ] | Parallel safety with 10+ concurrent agents | Adapters are actor-isolated or use per-task contexts; no shared mutable native state | Concurrency stress test runs 10+ concurrent operations and asserts stable outputs and stable receipt cores | Receipts for each task; determinism comparison report stored as an artifact |
| - [ ] | Evidence generation compliant | Every enhanced adapter call emits a receipt with deterministic core fields and optional observational envelope | Integration test captures receipts and validates schema | Receipts written under `Artifacts/maker/receipts/…`; ledger pointer record includes hashes |
| - [ ] | Performance meets or exceeds baseline, realistically | Baseline is measured; enhanced path produces benchmark artifacts; CI enforces regression guards using relative thresholds | Benchmark job produces artifacts with hardware disclosure; CI regression guard fails on significant regressions | Benchmark artifact bundle under `Artifacts/maker/bench/…` including hardware metadata |
| - [ ] | Integration tests cover existing workflows | End-to-end MakerEngine run exercises candidate generation, policy gate, evidence receipts, and quarantine behavior | Placeholder MakerEngine test is replaced with a real integration test that passes in CI | Integration test receipts and logs; ledger pointer record |
| - [ ] | Audit trail for native operations | Native adapter calls produce receipts with adapter version identifiers and pointers; audit linkage recorded via ledger | Receipt schema test asserts required identity fields exist | Receipt payloads + ledger pointer record; stable adapter ids and versions |
| - [ ] | Resource limits enforced and monitored | Each adapter receives time/size budgets; enforcement triggers deterministic flags and quarantine when applicable | Unit test triggers resource limit and asserts correct failure, receipt core flags, and quarantine decision | Receipt includes limits and exceeded flag; quarantine directory exists for triggered case |
| - [ ] | Policy compliance validated via gates | Quality gates include Maker enhanced-path checks; policy flags are verified | Gate test or CI job runs quality gates plus Maker assertions confirming policy decisions are recorded | Gate output artifact; receipts and ledger pointer record |
| - [ ] | Quarantine integration complete | Quarantine triggers on policy violation, resource overrun, and nondeterminism detection; quarantined outputs are blocked from reuse | Quarantine tests induce each trigger and verify quarantine artifacts and reuse-block behavior | Quarantine payload directory plus receipts showing quarantineDecision and reason |
| - [ ] | Receipt generation recorded in ledger and stable path | Receipts written to artifacts path; ledger stores pointers and hashes; stable receipt core is hash-stable | Determinism test reruns the same step and compares stable receipt core hashes | `Artifacts/maker/receipts/…` plus ledger pointer entries with hashes |
| - [ ] | Git diff performance target evidenced | Diff adapter has benchmark with controlled-runner artifact; CI enforces relative regression guard | Benchmark artifact exists and regression guard passes | `Artifacts/maker/bench/diff/…` plus hardware disclosure |
| - [ ] | Incremental parsing performance target evidenced | Parsing adapter has benchmark artifact and regression guard | Benchmark artifact exists and regression guard passes | `Artifacts/maker/bench/parse/…` plus hardware disclosure |
| - [ ] | Regex validation performance target evidenced | Regex validator benchmark artifact and regression guard | Benchmark artifact exists and regression guard passes | `Artifacts/maker/bench/regex/…` plus hardware disclosure |
| - [ ] | Policy evaluation performance target evidenced | Policy evaluator benchmark artifact and regression guard | Benchmark artifact exists and regression guard passes | `Artifacts/maker/bench/policy/…` plus hardware disclosure |
| - [ ] | Candidate quality improves by 2x+ on a defined metric | A specific quality metric is defined and measured on a fixed corpus; enhanced path meets the target | Quality comparison job produces artifact and passes threshold | `Artifacts/maker/bench/quality/…` including corpus identifier, metric definition, and results |

## Receipt schema requirements

Receipts must include a deterministic core and may include an observational envelope. The deterministic core must be reproducible for identical inputs and code version. The observational envelope may vary and must not be part of the determinism hash.

The deterministic core must include, at minimum: input digest, output digest, adapter identifier, adapter version identifier, configured resource limits, policy decision, quarantine decision, a deterministic step identifier, and a code-version identifier sufficient to distinguish behavior changes.

The observational envelope may include: duration, CPU time, memory estimates, and environment metadata. These are useful but not used to assert determinism.

## Determinism detection and quarantine trigger

Nondeterminism quarantine requires a detection mechanism. Enhanced mode must provide a determinism-check execution mode that runs the same step twice with the same inputs and seed, compares outputs and stable receipt core, and quarantines if they diverge. Quarantine must store artifacts for both runs and record the nondeterminism reason.

## Native dependency intake requirements

Each native library used by enhanced adapters requires an intake decision record and registry entry, with license review and build/link strategy. Native implementations must be selectable but not required for correctness. If native intake is not approved, native paths must remain disabled and fallback must continue to satisfy correctness and evidence behaviors.

## CI and gates

Contract validation must be part of the governed gate flow. The repo must run the governance contract validation command against this file and must run the test suites that provide the proof surfaces. Performance enforcement must be regression-based in CI, with absolute numbers documented via controlled-runner artifacts rather than brittle caps on noisy runners.

## Fulfillment workflow

This contract is fulfilled by implementing the enhancement layer boundary, adding evidence and quarantine behaviors, proving concurrency safety and determinism, producing benchmark artifacts and regression guards, replacing placeholder tests with real integration coverage, and wiring gates so proof and evidence are mechanically enforced. Once each row’s proof passes and evidence exists, the status checkbox may be updated to checked with a brief note in the associated PR description and receipts referenced by hash.
