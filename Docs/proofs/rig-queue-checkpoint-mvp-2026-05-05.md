# Rig Queue + Checkpoint MVP Proof

## Root Cause
- The queue/checkpoint MVP needed a durable job store and per-step checkpointing so supervisor-loop work could run in bounded background batches without manual steering.
- The implementation was initially blocked by a test fixture bug: the temp repo fixture did not create `.build/rig/results/` before seeding `.build/rig/results/latest.json`.

## Files Created
- `scripts/rig_cli/commands_queue.py`
- `scripts/rig_tools/work_queue.py`
- `scripts/test_work_queue.py`
- `Docs/dev/rig/QUEUE.md`
- `Docs/schemas/rig.queue.v1.schema.json`
- `Docs/schemas/rig.checkpoint.v1.schema.json`
- `Docs/proofs/rig-queue-checkpoint-mvp-2026-05-05.md`

## Files Modified
- `scripts/rig_cli/main.py`
- `scripts/rig_tools/supervisor_loop.py`
- `scripts/rig_tools/monitor.py`
- `scripts/rig_tools/session_bundle.py`
- `scripts/rig_tools/schema_validation.py`
- `Docs/dev/rig/README.md`
- `scripts/test_work_queue.py`
- `scripts/rig_tools/work_queue.py`

## Commands Run
- `python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_work_queue.py` -> `0`
- `python scripts/test_work_queue.py` -> `0`
- `python scripts/rig.py queue add --task td-cleanup-005 --mode read-only --max-steps 3` -> `0`
- `python scripts/rig.py queue list` -> `0`
- `python scripts/rig.py queue status` -> `0`
- `python scripts/rig.py queue run --max-jobs 1` -> `0`
- `python scripts/rig.py queue status` -> `0`
- `python scripts/rig.py schema validate --family rig.queue.v1` -> `0`
- `python scripts/rig.py schema validate --family rig.checkpoint.v1` -> `0`
- `python scripts/rig.py monitor snapshot` -> `0`
- `python scripts/rig.py bundle session --task td-cleanup-005 --dry-run` -> `0`
- `python scripts/anigma_diagnose.py validate --task-id rig-queue-checkpoint-mvp --command true` -> `0`

## Queue Artifacts
- Queue path: `.build/rig/queue/queue.json`
- Job id: `td-cleanup-005-e993b3d198`
- Checkpoint path: `.build/rig/queue/checkpoints/td-cleanup-005-e993b3d198.json`
- Queue run path: `.build/rig/queue/runs/td-cleanup-005-e993b3d198/queue-run.json`
- Event path: `.build/rig/queue/runs/td-cleanup-005-e993b3d198/events.jsonl`
- Summary path: `.build/rig/queue/runs/td-cleanup-005-e993b3d198/summary.md`

## Final Job State
- Final status: `blocked`
- Stop reason: `max_steps_reached`
- Latest checkpoint step index: `3`
- Latest checkpoint last action: `project_architecture`

## Monitor / Bundle Integration
- `monitor snapshot` completed successfully and included queue summary data.
- `bundle session --dry-run` included queue artifacts:
  - `rig/queue/queue.json`
  - `rig/queue/checkpoints/td-cleanup-005-e993b3d198.json`
  - `rig/queue/runs/td-cleanup-005-e993b3d198/queue-run.json`
  - `rig/queue/runs/td-cleanup-005-e993b3d198/events.jsonl`
  - `rig/queue/runs/td-cleanup-005-e993b3d198/summary.md`

## Schema Validation
- `rig.queue.v1`: passed
- `rig.checkpoint.v1`: passed

## Safety / Mutation
- Production source changed: `no`
- Git mutation occurred: `no`
- Source files modified by queue: `no`
- Confirmed external agent launch: `no`

## Notes
- The queue runner wrote a checkpoint after each step.
- The queue stopped explicitly on `max_steps_reached`.
- The queue/checkpoint artifacts are advisory orchestration state, not canonical truth.
