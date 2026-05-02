# SURFACE.HarmoniaAPIStability

Contract to realign Harmonia/ExecutionCore/Database/Telemetry public surfaces and restore the full governed test suite after API drift.

## Scope & Authority
- **Scope:** HarmoniaModule (Phase9 kernels, ToolRouter, LoopBreaker, EvidenceRecorder), ExecutionCore receipts/phase transitions, TelemetryCore tag/value constraints, DatabaseCore content-addressed store + retention, Praxis session index, Graphene pipeline runner, Accessum system flows.
- **Authority boundary:** No new cores; reuse existing components. Changes must be additive or compatible with published types in `Sources/*` and existing governance/telemetry constraints.
- **Out of scope:** New tool binaries, new storage backends, or altering harmonia entrypoints.

## Surface & API Expectations
- **Phase9 verification:** `VerificationInputs` immutability/semantics, Phase9LoopKernel required params (`irStore`, `scoringPolicy`, `budgetPolicy`, `stopCondition`), deterministic log parsing (GovernanceEventLogParser), StageBoundaryValidator semantics.
- **Tooling:** ToolRouter + ToolCallLoopBreaker status enums and EvidenceRecorder recording (no fatal unwraps, correct block/warn counts, stable fingerprints).
- **ExecutionCore:** ReceiptWire/PhaseTransitionWire creation via factory methods (no fatal deprecations), deterministic JSON, ReceiptDecision cases preserved, telemetry emission uses safe `TelemetryValue` tagging.
- **TelemetryCore:** Tag whitelist/length enforced; hashed tokens for sensitive data; event names prefixed per policy.
- **DatabaseCore:** Content-addressed dedupe, retention policy application, housekeeping queries schema-safe.
- **PraxisCore:** PraxisSessionIndex parsing workflow ledger JSON deterministically.
- **Graphene/Pipeline:** Node registry resolves known nodes; pipeline runner caching semantics preserved; profiling optional but non-fatal.
- **Accessum:** OCR/TTS pipeline state transitions deterministic and complete.

## Acceptance Tests (to re-enable incrementally)
1) **Phase9 determinism:** Restore real assertions in `Phase9DeterminismTests`, `Phase9FailureFixturesTests`, `Phase9Stage0Tests`, `Phase9ConcurrencyDeterminismTests`; add canonical event-log fixture to parse without JSON errors.
2) **Tooling:** Reinstate ToolRouter/LoopBreaker tests with correct status enums and evidence counts; ensure EvidenceRecorder mock API matches production protocol.
3) **ExecutionCore:** Re-enable ExecutionIntegration tests using ReceiptWire/PhaseTransitionWire create helpers; telemetry metadata must use allowed tags.
4) **Telemetry:** Reinstate SimpleTelemetry/Privacy tests with updated prefixes and hash policies.
5) **Database:** Reintroduce ContentAddressedStore/Housekeeping/Retention tests with schema-safe queries and nullability fixes.
6) **Praxis:** Reinstate PraxisCore ledger parsing with valid fixtures (no malformed JSON).
7) **Graphene/Pipeline:** Re-enable Graphene tests and PipelineRunner caching/profiling expectations after registry seeding restored.
8) **Accessum:** Re-enable AccessumSystems OCR/TTS assertions once state machine is fixed.

## Migration Plan (three phases)
- **Phase A (Contracts & Fixtures):** Restore canonical fixtures for each domain; adjust deprecated init usage to factory helpers; ensure logs/ledgers are valid JSON. No behavior changes yet.
- **Phase B (API Hardening):** Update implementations to satisfy fixtures (e.g., UUID parsing safety, telemetry tag builders, database schema defaults). Remove placeholder skips per domain in order above; run governed tests per domain.
- **Phase C (Consolidation):** Remove deprecated inits; enforce deterministic encoders; add regression coverage for fatal unwraps; align docs and examples.

## Stop Conditions
- All acceptance tests pass under `Scripts/harmonia.sh cmd run swift6 --arg target=<suite>` for each domain and full suite green.
- No fatalError/force-unwrap in hot paths reachable by tests.
- Telemetry and receipt outputs deterministic and tag-safe.

## Rollback / Quarantine
- If a domain fails, revert only that domain’s test reinstatement (keep placeholders) and record the failure in this artifact under “Known Issues.”
- For database schema regressions, quarantine by skipping migrations and restoring prior fixture set.

## Known Issues (initial)
- Multiple suites currently skipped due to API drift (placeholders in HarmoniaModuleTests, DatabaseCoreTests, TelemetryCoreTests, PraxisCoreTests, AnigmaCoreTests/Pipeline, AccessumModuleTests). This contract tracks their restoration.

## Validation Commands (governed)
- Contract lint: `Scripts/harmonia.sh cmd run governance-contract-validate --arg path=Docs/governance/contract-artifacts/SURFACE.HarmoniaAPIStability.md`
- Phase test runs (examples):
  - Phase9 domain: `Scripts/harmonia.sh cmd run swift6 --arg target=HarmoniaModuleTests`
  - Database domain: `Scripts/harmonia.sh cmd run swift6 --arg target=DatabaseCoreTests`
  - Telemetry domain: `Scripts/harmonia.sh cmd run swift6 --arg target=TelemetryCoreTests`

## Status
- Draft created to gate API stabilization and test reinstatement. Update this section as domains are restored (Planned → In Progress → Done per acceptance item).
