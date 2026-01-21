# ADR: Anigma CLI Surface and Receipts (2025-12-30)

## Context
- The repo lacks a governed contract artifact for the Anigma CLI surface; existing Praxis/RepoIdentity gates and Harmonia CLI patterns must remain authoritative.
- Runs require deterministic receipts (run-level and tool-level) to satisfy governance, auditing, and offline verification.
- Interactive and non-interactive modes must align on semantics (plan vs exec, stop conditions, receipt emission) without introducing new binaries.

## Decision
- Adopt SURFACE.AnigmaCLI as the canonical contract for CLI verbs (interactive TUI, run-mode, session/housekeeping/index commands) and receipt semantics.
- All commands execute via the orchestrator; agents only request capabilities.
- Default receipt locations: persisted in the session DB and mirrored under `.artifacts/runs/<runId>/` (configurable via `ANIGMA_ARTIFACT_ROOT`, default `.artifacts`).
- Required receipt fields (run-level): runId, RunSpec hash, input hash, RepoIdentity verdict, worktree lease id, index snapshot id, start/stop timestamps, stop reason.
- Required receipt fields (tool-level): request hash, response hash, tool name/version, parameters schema id, approval decision, sandbox flags, wall time, token/spend usage, retrieval hashes, model/binary hash where applicable.
- Dry-run behavior: plan-only runs emit receipts but must not mutate git, filesystem, or network; default exit code reflects success/failure of planning.
- Stop conditions (see SURFACE contract): stop receipts must be emitted when limits trip (steps, tools, wall time, repeated calls, no novelty).
- Defaults are overridable via policy config (e.g., budgets, approval levels) but cannot disable receipt emission.

## Consequences
- The SURFACE contract becomes the single reference for CLI behavior; design docs and implementations must align to it.
- Tool authors must provide schema/version metadata to keep receipts stable.
- Operators gain deterministic receipt locations suitable for downstream evidence pipelines.
- Additional validation is needed in Praxis/Surface suites to assert receipt fields and stop-reason emission.

## Compatibility and migration
- Existing Harmonia CLI flows continue; new receipts integrate with DatabaseCore without schema duplication.
- Migration path: add receipt persistence where absent and redirect prior ad-hoc logs to the governed artifact directory.
- RepoIdentity/Stack gates remain required and are not bypassed by this ADR.

## Acceptance and rollback criteria
- Acceptance: Praxis/Surface suites validate receipt emission (run/tool), dry-run non-mutation, and stop-reason coverage; SURFACE contract referenced from HarmoniaCLI-Overhaul.md.
- Rollback: revert to prior CLI surface only if receipt persistence or gate alignment cannot be satisfied without breaking policy; must preserve existing receipts to avoid audit gaps.
