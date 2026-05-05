# Implement td-cleanup-005: cleanup_singleton_triage

Task ID: td-cleanup-005

## Source of Truth
- Docs/atlas/risk-index.json
- Docs/atlas/targets.json
- Docs/atlas/entrypoints.json
- Docs/atlas/authority-map.json
- Docs/governance/CLEANUP_ALIGNMENT_DOCTRINE.md
- Docs/proofs/td-cleanup-002-batch-001-post-review.md
- Docs/proofs/td-cleanup-003-batch-002-process-configuration-alignment.md
- Docs/proofs/context-pipeline-audit-normalization-2026-05-05.md

## Context Summary
Selected 3 focused risks for risk='singleton_global_state' target='AnigmaDaemonCore'.

## Selected Findings
1. 3bb6966bb0fd9a168bddbf9d1d9d92bb83f9c2163086370ab6d60cb85ee0633e | singleton.global.state | medium | low_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Jobs/DaemonWorkerRegistry.swift:27 | target=None | symbol=None | snippet= | rationale=Former process-local singleton state may collide when multiple capabilities share one daemon.
2. 6a2eeccdf11e39ab14d7f1f58642030e2ba34784274be33f1b49b58eb3472910 | singleton.global.state | medium | low_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Jobs/JobWorker.swift:13 | target=None | symbol=None | snippet= | rationale=Former process-local singleton state may collide when multiple capabilities share one daemon.
3. e8049a9818819c6fb2fce0b066cef8950e4e02a87f7df0383f3452c5874f2a90 | singleton.global.state | medium | low_confidence | /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/JobQueueCompatibility.swift:22 | target=None | symbol=None | snippet= | rationale=Former process-local singleton state may collide when multiple capabilities share one daemon.

## Proposed Change Map
1. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Jobs/DaemonWorkerRegistry.swift
   current assumption/risk: Former process-local singleton state may collide when multiple capabilities share one daemon.
   desired alignment: route singleton_global_state through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
2. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Jobs/JobWorker.swift
   current assumption/risk: Former process-local singleton state may collide when multiple capabilities share one daemon.
   desired alignment: route singleton_global_state through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding
3. /Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/JobQueueCompatibility.swift
   current assumption/risk: Former process-local singleton state may collide when multiple capabilities share one daemon.
   desired alignment: route singleton_global_state through daemon-owned boundary
   allowed change shape: narrow ownership/lifecycle refactor with typed errors and explicit boundary ownership
   validation command: python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
   expected audit effect: reduce or eliminate this finding

## Triage Classifications
Singleton findings are high false-positive territory. Distinguish findings into:
- `acceptable_authority_singleton`: True process-wide authorities (e.g. `RuntimeAuthority.shared`).
- `dangerous_mutable_global`: State that can be mutated concurrently or needs tenant/lifecycle isolation.
- `test_only_singleton`: Used purely for verification harnesses.
- `legacy_process_local_state`: Leftovers from sidecar splits (e.g. `shared` workers).
- `cache_actor_ownership`: State that needs actor-isolation.
- `false_positive`: Unrelated regex matches.

## Non-Goals
- Do not delete all shared instances.
- Do not turn everything into dependency injection.
- Do not refresh baselines unless explicitly justified.
- Do not suppress findings instead of repairing them.

## Approved Repair Shapes
- Only repair singleton/global state that is mutable, daemon-reachable, and unsafe under consolidated process lifetime.
- Convert dangerous mutable globals to `actor` or route through proper dependency injection.
- Mark immutable global state as `Sendable` and leave it.

## Implementation Sequence
1. Inspect each selected source file.
2. Classify findings into the triage categories above.
3. Repair ONLY mutable, daemon-reachable, unsafe singletons.
4. Re-run executable-consolidation audit.
5. Rebuild atlas.
6. Verify query output and gate state.

## Validation Commands
- python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json
- python3 scripts/anigma_executable_consolidation_audit.py --mode gate --baseline Docs/baselines/executable-consolidation-baseline.json --focus anigmad
- python3 scripts/anigma_dead_code_audit.py --mode gate --baseline Docs/baselines/dead-code-baseline.json
- python3 scripts/anigma_build_repo_atlas.py
- python3 scripts/anigma_context_query.py --risk singleton_global_state --target AnigmaDaemonCore --limit 10
- swift build --target AnigmaDaemonCore
- python3 scripts/anigma_diagnose.py validate --task-id td-cleanup-004 --command true

## Proof Requirements
- Document selected finding statuses.
- Document audit deltas.
- Document build/test results.
- Note whether production Swift changed.

## Acceptance Criteria
Production Swift changes are allowed only for selected confirmed/likely singleton risks in AnigmaDaemonCore.
- Query remains focused.
- Repair scope limited to confirmed/likely risks.
- Proof artifact exists.

## Final Report Format
- files modified
- each selected finding status
- audit deltas
- build/test results
- remaining singleton_global_state findings
- whether production Swift changed

## Warning
Scanner findings require source inspection before modification. Source remains canonical.
