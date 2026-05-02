# Anigma Governance Machine – Summary for Docs/Codex

## What Anigma is now
Anigma is a governance layer for autonomous code modification, not a fancy linter. Every non-trivial change is gated by committees: a security spine (capabilities, zones, isolation), doctrine packs (CS/statistics/law/compliance/security/research), and a research pipeline that demands literature-backed proposals before work. The system blocks by default, requires justification, and leaves a forensic trail.

## Security spine (Phase 2)
The spine is wired and blocks in practice. DoctrineGuards and ThreatModel are fixed; engines wrap through doctrine → isolation → provenance → audit. Capability-based authorization requires explicit grants (fs.read.project, net.openalex.api.read) and zones restrict requests. Trust tiers exist (bronze/silver/gold/platinum) with basic zone rules. MetricsCollector tracks blocking and effectiveness. Baseline tests showed the spine blocking unsafe operations and production zone blocking network calls.

## Research pipeline as a hard gate (Phase 3)
ResearchBundle is a first-class artifact (TopicSpec, PaperMetadata, ResearchNote, adequacy score, doctrine links, provenance). A research schema stores bundles, papers, notes, tasks, and debt. Research clients use OpenAlex/arXiv via explicit net.* capabilities. ResearchRegistry persists and reuses bundles. ResearchDoctrinePack enforces minimum papers/recency/independent sources with adequacy thresholds. ResearchGate blocks module tasks without adequate bundles and creates ResearchDebtTask. DeepResearchEngine extracts notes and links doctrine; ResearchAwareStepEngine schedules research before module work.

## Trust as control system (Phase 4)
Trust is scored (0–100) with trust_history and recalculated timestamps. TrustScoringConfig defines tier bands, event weights, decay, and asymmetric recovery. TrustScoreCalculator reads security_events, applies penalties/bonuses, maps to tiers. TrustRecalcScheduler runs batch recalcs. TrustTierManager resolves effective trust via hierarchy (engine_instance > engine_type@project > engine_type > default) and clamps by governance mode (personal/governed/paranoid). CapabilityValidator compares claimed vs resolved tiers, logs escalations, degrades trust on bad attempts. Pitfalls addressed: no double-punishment, exclude trust events from scoring, bounded moves. Experiments on Swift 6 migrations validated movement, clamps, and histories.

## Observability (CCTV)
Security_events table records capability_blocked/granted, doctrine_violation, research_inadequate, trust_degraded/promoted, trust_recalculation, mode changes with severity and metadata. SecurityEventsManager centralizes logging. CLI surfaces: harmonia security status; doctrine status/violations/rules; research status/bundles/debt; mode status/set/history; trust status/history/overrides. A governance logbook and paper scaffolding capture narrative behavior.

## Experiments and criteria (Phase 4C)
Governed Swift 6 Sendable migrations ran with spine, doctrine where wired, research gate, trust scoring, and logging. Observed bounded trust movement, reasonable block rates, and stable pipeline. Established success criteria: target block rate range, acceptable trust movement per day, doctrine/research intervention frequency, tuning guidance.

## Stable front door (Phase 5)
GovernedMigrationCore extracted as a clean target: security-aware migration engine factory, trust integration, security events, narrow governed migration API (runSwift6DiscoveryAndTaskCreation, runSwift6Steps, currentGovernanceSnapshot). Package.swift adds GovernedMigrationCore; HarmoniaCLI depends on it, not the full HarmoniaModule. GOVERNED_CORE flag quarantines unstable subsystems. HarmoniaCLI exposes swift6/security/trust/governance commands that use the governed path and show status without raw DB access.

## Rehab plan (Phase 6)
Make the spine production-ready: fix actor isolation/concurrency warnings, normalize trust CLI and event schema, add property/integration tests. Un-quarantine doctrine gradually starting with concurrency/Sendable; re-enable research gate minimally; add further doctrine domains after stability. Treat inspiration/Polytropos as untrusted subsystems behind feature flags with narrow governed APIs and independent scoring. Reduce build debt without breaking GovernedMigrationCore or HarmoniaCLI.

## Current state
Anigma now has a capability-based, doctrine-constrained, research-gated governance stack that blocks unsafe/unsupported changes, requires literature for new modules, tracks trust per subject over time, and logs everything into a queryable “CCTV” store. A minimal CLI runs governed Swift 6 migrations and surfaces security/trust/governance status. Next steps: rehab the rest of the stack under these constraints and plug in inspiration/Polytropos as governed, scored inputs.***

## Phase 6 Stage 2 verification (GovernedMigrationCore)
To verify governed doctrine integration without compiling quarantined modules:
1) Build governed-core tests only:  
   `CLANG_MODULE_CACHE_PATH=$(pwd)/.cache/clang swift build --disable-sandbox --target GovernedMigrationCoreTests -c debug`
2) Run the governed-core test bundle directly (preferred):  
   `Tools/run_governed_tests.sh`  
   This is currently a **build gate only**: it verifies `GovernedMigrationCoreTests` compile in governed-core mode. SwiftPM does not emit a standalone `.xctest` bundle for this target in the monorepo configuration, so tests are **not** run automatically by the script. Treat a successful run as “governed core still builds.” Test execution remains manual/experimental until a separate, isolated package is created for governed-core.

Rationale: SwiftPM’s `swift test` will try to build quarantined Harmonia targets. The script keeps verification limited to GovernedMigrationCoreTests and the CS-002 doctrine check fixture.

Planned clean solution: Extract `GovernedMigrationCore` + `GovernedMigrationCoreTests` into a small, separate Swift package/workspace where `swift test` can run in isolation and emit a proper `.xctest` bundle without seeing `HarmoniaModule` or other quarantined targets. That isolated package will become the canonical automated verification path for the governance spine.

### Harmonia CLI install path
`Tools/install_harmonia.sh` now builds the release `harmonia` product with repo-local SwiftPM caching, copies it to `.tools/bin/harmonia`, and prints the deterministic install path. Automation wrappers should invoke that binary (passing `--format json`) and never parse stdout themselves; stderr remains for diagnostics, and structured JSON is the contract enforced by `Tools/verify_harmonia_output.sh`.

### Harmonia CLI output contract
1. Default to `--format json`. Each subcommand now shares the same `OutputOptions` group, so automation can always request a JSON envelope with the same top-level schema: `{ status, timestamp, command, payload, governanceTrace, contractVersion }`. `contractVersion` (currently `1`) lets consumers detect intentional schema bumps, the `payload` object is command-specific, and `governanceTrace` is reserved for future action traceability.
2. JSON envelopes are written to stdout; human-readable text (with emojis/logging) only appears when `--format text` is requested. Errors still go to stderr via Swift Argument Parser's failure handling.
3. Automation can use `Tools/verify_harmonia_output.sh` to rebuild the release binary (`.build/release/harmonia`), run representative commands (`trust bounds`, `security status`) with `--format json`, and assert that the envelope includes the required keys and `"status": "ok"`.
