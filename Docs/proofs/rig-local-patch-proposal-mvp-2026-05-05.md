# Rig Local Patch Proposal MVP Proof

## Files Created
- `scripts/rig_cli/commands_patch.py`
- `scripts/rig_tools/local_patch.py`
- `scripts/test_local_patch.py`
- `Docs/dev/rig/LOCAL_PATCHES.md`
- `Docs/schemas/rig.local_patch.v1.schema.json`
- `Docs/schemas/rig.patch_validation.v1.schema.json`
- `Docs/proofs/rig-local-patch-proposal-mvp-2026-05-05.md`

## Files Modified
- `scripts/rig_cli/main.py`
- `scripts/rig_tools/loop_actions.py`
- `scripts/rig_tools/supervisor_loop.py`
- `scripts/rig_tools/session_bundle.py`
- `scripts/rig_tools/monitor.py`
- `scripts/rig_tools/schema_validation.py`
- `Docs/dev/rig/README.md`
- `scripts/test_local_patch.py`
- `scripts/rig_tools/local_patch.py`

## Commands Run
- `python -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_local_patch.py` -> `0`
- `python scripts/test_local_patch.py` -> `0`
- `python scripts/rig.py patch status` -> `0`
- `python scripts/rig.py patch propose --task rig-local-patch-proposal-mvp --backend mlx --allowed-path Docs/dev/rig --allowed-path scripts --dry-run --max-repair-attempts 3` -> `1`
- `python scripts/rig.py patch list` -> `0`
- `python scripts/rig.py patch list` -> `0`
- `python scripts/rig.py schema validate --family rig.local_patch.v1` -> `0`
- `python scripts/rig.py schema validate --family rig.patch_validation.v1` -> `0`
- `python scripts/anigma_diagnose.py validate --task-id rig-local-patch-proposal-mvp --command true` -> `0`

## Patch Details
- Patch ID: `rig-local-patch-proposal-mvp-5fda146f95`
- Patch path: `.build/rig/patches/rig-local-patch-proposal-mvp-5fda146f95/changes.patch`
- Proposal markdown: `.build/rig/patches/rig-local-patch-proposal-mvp-5fda146f95/proposal.md`
- Validation path: `.build/rig/patches/rig-local-patch-proposal-mvp-5fda146f95/validation.json`

## Validation Result
- `git apply --check` result: `failed`
- `git apply --check` status: `check_failed`
- Sandbox apply status: `not_run`
- Sandbox path: `not created`
- Repair loop used: `yes`
- Repair attempt count: `3`
- Successful attempt index: `none`
- Final failure reason: `max_attempts_exceeded`
- Reason sandbox was not reached: `git apply --check` reported `corrupt patch at line 3`

## Safety / Scope
- Main worktree modified by patch command: `no`
- Git mutation occurred: `no`
- Production source changed: `no`
- Local patch output is advisory only.
- The patch lane is sandbox-only in MVP.

## Artifacts
- Patch proposal JSON: `.build/rig/patches/rig-local-patch-proposal-mvp-54181ea6a8/patch.json`
- Patch proposal markdown: `.build/rig/patches/rig-local-patch-proposal-mvp-54181ea6a8/proposal.md`
- Validation JSON: `.build/rig/patches/rig-local-patch-proposal-mvp-54181ea6a8/validation.json`
- Validation markdown: `.build/rig/patches/rig-local-patch-proposal-mvp-54181ea6a8/validation.md`
- Latest patch summary JSON: `.build/rig/patches/latest.json`
- Latest patch summary MD: `.build/rig/patches/latest.md`

## Notes
- The unit tests cover sandbox application and main-worktree non-mutation.
- The live model proposal produced invalid patches on all three attempts; the bounded repair loop preserved failed attempts and stopped cleanly.
