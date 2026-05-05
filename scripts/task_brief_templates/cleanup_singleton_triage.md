# {{title}}

Task ID: {{task_id}}

## Source of Truth
{{source_of_truth}}

## Context Summary
{{context_summary}}

## Selected Findings
{{selected_findings}}

## Proposed Change Map
{{change_map}}

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
{{validation_commands}}

## Proof Requirements
{{proof_requirements}}

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
