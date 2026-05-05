# Rig Queue

The Rig queue provides a small durable checkpoint layer for bounded supervisor-loop work.

## Purpose

- Store bounded jobs in `.build/rig/queue/queue.json`.
- Persist checkpoints after each step in `.build/rig/queue/checkpoints/<job_id>.json`.
- Persist per-job runs in `.build/rig/queue/runs/<job_id>/`.
- Keep the supervisor loop bounded and resumable without a resident daemon.

## Commands

- `python scripts/rig.py queue add --task <task> --mode read-only --max-steps 5`
- `python scripts/rig.py queue list`
- `python scripts/rig.py queue status`
- `python scripts/rig.py queue run --max-jobs 1`
- `python scripts/rig.py queue pause --job-id <job_id>`
- `python scripts/rig.py queue resume --job-id <job_id>`
- `python scripts/rig.py queue cancel --job-id <job_id>`
- `python scripts/rig.py queue show --job-id <job_id>`

## Doctrine

- Queue jobs are advisory and bounded.
- No Git mutation occurs in the MVP.
- No confirmed external agent launch occurs in the MVP.
- Checkpoints capture the last safe resume point and the next allowed actions.

## Stop Reasons

- `completed`
- `max_steps_reached`
- `needs_human_approval`
- `planner_malformed_json`
- `action_validation_failed`
- `external_agent_not_available`
- `codex_quota_exhausted`
- `swift_known_blocker`
- `dirty_worktree_scope_too_broad`
- `missing_context`
- `timeout`
- `cancelled`

## Integration

- Monitor shows queue status and latest checkpoint when present.
- Session bundles include queue jobs, checkpoints, and per-job runs when present.
- Notifications may fire on completed/blocked jobs when enabled.
