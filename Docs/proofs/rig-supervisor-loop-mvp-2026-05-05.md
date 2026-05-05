# Rig Supervisor Loop MVP Bootstrap Proof

## Root Cause
Rig had the planner, agent launcher, monitor, schema validation, and bundle artifacts, but no bounded supervisor loop that could repeatedly gather compact context, ask the local MLX planner for the next safe action, validate that action, and execute only allowlisted Rig actions in read-only mode.

## Files Created
- `scripts/rig_cli/commands_loop.py`
- `scripts/rig_tools/supervisor_loop.py`
- `scripts/rig_tools/loop_actions.py`
- `scripts/test_supervisor_loop.py`
- `Docs/schemas/rig.loop_plan.v1.schema.json`
- `Docs/schemas/rig.loop_run.v1.schema.json`
- `Docs/proofs/rig-supervisor-loop-mvp-2026-05-05.md`

## Files Modified
- `scripts/rig_cli/main.py`
- `scripts/rig_tools/schema_validation.py`
- `scripts/rig_tools/monitor.py`
- `scripts/rig_tools/session_bundle.py`
- `Docs/dev/rig/README.md`
- `scripts/rig_tools/supervisor_loop.py`
- `scripts/rig_tools/loop_actions.py`

## Commands Run
- `python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_supervisor_loop.py`
- `python scripts/test_supervisor_loop.py`
- `python scripts/rig.py loop status`
- `python scripts/rig.py loop plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit`
- `python scripts/rig.py loop validate-plan --plan .build/rig/loop/plans/td-cleanup-005-loop-plan.json`
- `python scripts/rig.py loop run --task td-cleanup-005 --mode read-only --max-steps 3 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit --dry-run`
- `python scripts/rig.py schema validate --artifact .build/rig/loop/plans/td-cleanup-005-loop-plan.json`
- `python scripts/rig.py schema validate --artifact .build/rig/loop/latest.json`
- `python scripts/rig.py schema validate --family rig.loop_plan.v1`
- `python scripts/rig.py schema validate --family rig.loop_run.v1`
- `python scripts/rig.py monitor snapshot`
- `python scripts/rig.py bundle session --task td-cleanup-005 --dry-run`
- `python scripts/anigma_diagnose.py validate --task-id rig-supervisor-loop-mvp --command true`

## Exit Codes
- `python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_supervisor_loop.py` -> `0`
- `python scripts/test_supervisor_loop.py` -> `0`
- `python scripts/rig.py loop status` -> `0`
- `python scripts/rig.py loop plan --task td-cleanup-005 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit` -> `0`
- `python scripts/rig.py loop validate-plan --plan .build/rig/loop/plans/td-cleanup-005-loop-plan.json` -> `0`
- `python scripts/rig.py loop run --task td-cleanup-005 --mode read-only --max-steps 3 --backend mlx --model mlx-community/Qwen3-4B-Instruct-2507-4bit --dry-run` -> `0`
- `python scripts/rig.py schema validate --artifact .build/rig/loop/plans/td-cleanup-005-loop-plan.json` -> `0`
- `python scripts/rig.py schema validate --artifact .build/rig/loop/latest.json` -> `0`
- `python scripts/rig.py schema validate --family rig.loop_plan.v1` -> `0`
- `python scripts/rig.py schema validate --family rig.loop_run.v1` -> `0`
- `python scripts/rig.py monitor snapshot` -> `0`
- `python scripts/rig.py bundle session --task td-cleanup-005 --dry-run` -> `0`
- `python scripts/anigma_diagnose.py validate --task-id rig-supervisor-loop-mvp --command true` -> `0`

## Detected Loop Actions
- `affected_summary`
- `embeddings_query`
- `project_architecture`
- `monitor_snapshot`
- `schema_validate_results`
- `schema_validate_events`
- `swift_diagnostics`
- `agent_plan`
- `agent_dry_run`
- `bundle_session`
- `stop`

## Disabled Loop Actions
- None in this workspace. All mapped Rig actions used by the MVP were available.

## Generated Plan
- Plan path: `.build/rig/loop/plans/td-cleanup-005-loop-plan.json`
- Plan markdown: `.build/rig/loop/plans/td-cleanup-005-loop-plan.md`
- Plan validation result: passed
- MLX planner used: yes
- Fallback plan used: no
- Plan status: `generated`

## Loop Run
- Loop run path: `.build/rig/loop/runs/4a24a8c3fa51/loop-run.json`
- Event path: `.build/rig/loop/runs/4a24a8c3fa51/events.jsonl`
- Summary path: `.build/rig/loop/runs/4a24a8c3fa51/summary.md`
- Loop status: `dry_run`
- Mode tested: `read-only`
- Max steps tested: `3`
- Event count: `7`
- Actions executed: `monitor_snapshot`
- Stop reason: `dry_run`

## Validation Results
- Loop plan schema validation: passed
- Loop run schema validation: passed
- Loop family validation:
  - `rig.loop_plan.v1`: passed
  - `rig.loop_run.v1`: passed
- Monitor snapshot: passed
- Session bundle dry-run: passed

## Bundle / Monitor Integration
- Session bundle dry-run manifest included loop artifacts:
  - `rig/loop/latest.json`
  - `rig/loop/latest.md`
  - `rig/loop/plans/td-cleanup-005-loop-plan.json`
  - `rig/loop/runs/01b7fe94689d/*`
  - `rig/loop/runs/4a24a8c3fa51/*`
- Monitor state builder now surfaces loop runs.

## Safety / Authority Statement
Rig loop output is advisory only. Deterministic Rig validators, proofs, and Git/source state remain authoritative.

## Git / Source Mutation
- Production source changed: no
- Git mutation occurred: no
- Source files modified by the loop: no

