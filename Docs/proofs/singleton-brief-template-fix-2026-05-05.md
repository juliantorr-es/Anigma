# Singleton Brief Template Fix Proof

Date: 2026-05-05

## Files Modified
- `scripts/task_brief_templates/cleanup_singleton_triage.md`
- `scripts/anigma_generate_task_brief.py`
- `scripts/test_task_brief_generator.py`
- `Docs/td/briefs/td-cleanup-005-batch-004-singleton-triage.md`

## Commands Run
1. `python3 -m py_compile scripts/anigma_generate_task_brief.py scripts/test_task_brief_generator.py`
   - Exit code: `0`
2. `python3 scripts/anigma_generate_task_brief.py --task td-cleanup-005 --template cleanup_singleton_triage --risk singleton_global_state --target AnigmaDaemonCore --limit 10 --write Docs/td/briefs/td-cleanup-005-batch-004-singleton-triage.md`
   - Exit code: `0`
3. `python3 scripts/test_task_brief_generator.py`
   - Exit code: `0`
4. `grep -R "{{" Docs/td/briefs/td-cleanup-005-batch-004-singleton-triage.md`
   - Exit code: `1` when run after regeneration, confirming no unreplaced placeholders remained
5. `python3 scripts/anigma_diagnose.py validate --task-id singleton-brief-template-fix --command true`
   - Exit code: `0`

## What Changed
- Replaced the singleton template placeholder `{{proposed_change_map}}` with the generator-supported `{{change_map}}`.
- Updated singleton template validation commands to use `singleton_global_state` rather than `daemon_ipc_binding`.
- Updated singleton acceptance criteria to allow production Swift changes only for selected confirmed/likely singleton risks in `AnigmaDaemonCore`.
- Updated singleton final report format to track remaining `singleton_global_state` findings.
- Added generator support for `proposed_change_map` as an alias to `change_map`.
- Added generator validation that fails if unreplaced `{{...}}` placeholders remain in the rendered brief.
- Added test coverage for singleton brief rendering, placeholder removal, singleton-specific wording, and avoidance of unrelated `daemon_ipc_binding` wording.

## Rendered Brief Checks
- The regenerated brief at `Docs/td/briefs/td-cleanup-005-batch-004-singleton-triage.md` no longer contains unreplaced `{{...}}` placeholders.
- The brief contains singleton-specific proposed change map entries.
- The brief contains singleton-specific acceptance criteria and final report language.
- The brief keeps `target=None` on the selected findings, which is a known atlas inference limitation and does not block triage.

## Production Source
- No production Swift/C++/Metal source changed.

## Remaining Limitation
- The selected singleton findings still have `target=None` from atlas inference. That remains a known limitation in the generated context and is acceptable for triage-first review.

