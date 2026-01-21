# Phase 9 Deterministic Loop Completion Checklist

## Context
- Contract reference: `Docs/governance/contract-artifacts/ROADMAP.Phase7-9-Completion.md` (Phase 9 deliverables and acceptance).
- Governance surface only: run validation via `Scripts/harmonia.sh ...` and `Scripts/harmonia-surface.sh ...` (no direct `swift test`/`swift build`).
- Validation commands called out in the contract remain the target: `Scripts/harmonia.sh cmd run governance-contract-validate --arg path=Docs/governance/contract-artifacts/ROADMAP.Phase7-9-Completion.md`, `Scripts/harmonia.sh cmd run swift6 --arg target=HarmoniaModuleTests --arg filter=Phase9ReplayVerifier`, and the replay/concurrency harnesses.

## Acceptance Baseline (Phase 9)
- Stage 0 deterministic enumeration yields canonical event logs suitable for replay verification.
- Replay verifier is a merge gate for canonical fixtures and live session traces.
- Concurrency hardening preserves determinism under defined scheduling constraints with stable replay hashes.
- Policy evolution staging includes evidence-backed propose/validate/adopt lifecycle and explicit stop conditions.
- Evidence hooks for autonomous loop steps remain offline-verifiable and consistent with tool-step evidence.
- Single-commit invariant for autonomous proposals with deterministic identity and rollback hooks.

## Current Readiness
- Replay verifier and diagnostics are implemented (`Sources/HarmoniaModule/Phase9/Phase9ReplayVerifier.swift`) with coverage in `Tests/HarmoniaModuleTests/Phase9DeterminismTests.swift` (core determinism cases running; artifact index check skipped).
- Orchestrators and stage definitions exist for Phase 9.0/9.1/9.2 (`Sources/HarmoniaModule/Phase9/Phase90Orchestrator.swift`, `Sources/HarmoniaModule/Phase9/Phase92Orchestrator.swift`, `Sources/HarmoniaModule/Phase9/Stages.swift`), and concurrency scaffolding is present (`ParallelScoringPipeline.swift`, `DeterministicMerge.swift`).
- CI harness stub is in place for dual-run and concurrency verification (`Scripts/ci-phase9-verifier.sh`), and design docs are present (`Docs/phase9-stage0-determinism.md`, `Docs/phase9-2-concurrency-hardening.md`, `Docs/Phase9ReplayVerifierSummary.md`).
- Canonical replay fixture added at `Artifacts/phase9-fixtures/canonical-fixture.json` with a verifier test (`Tests/HarmoniaModuleTests/Phase9FixtureReplayTests.swift`) wired into `Scripts/ci-phase9-verifier.sh`.
- Canonical stage artifact fixture at `Artifacts/phase9-fixtures/stage-artifacts.json` with comparator coverage (`Tests/HarmoniaModuleTests/Phase9StageArtifactFixtureTests.swift`) gated in `Scripts/ci-phase9-verifier.sh`.

## Critical Blockers Before Completion
- CI verifier needs canonical stage fixtures when invoking the replay verifier (`Scripts/ci-phase9-verifier.sh`) to serve as a merge gate. (Added fixtures and comparator tests.)
- Governed harness runs needed to confirm deterministic IDs/timestamps in IRSchema and Stage 0 enumerators under `Scripts/harmonia.sh swift6 --test --filter Phase9...` with canonical fixtures.

## Suggested Next Steps
- Generate canonical Stage 0 fixtures and run Phase 9 test filters via `Scripts/harmonia.sh swift6 --test --filter Phase9...` to validate deterministic IDs/timestamps.
- Wire `Scripts/ci-phase9-verifier.sh` to call `Phase9ReplayVerifier.verify` on recorded artifacts and persist hash-based fixtures for gate comparisons.
- Document evidence hooks and stop-condition enforcement per contract in `Docs/governance/contract-artifacts/ROADMAP.Phase7-9-Completion.md` once the above gates are green.
