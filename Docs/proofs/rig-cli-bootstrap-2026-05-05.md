# Rig CLI Bootstrap Proof

Date: 2026-05-05

## Scope

Bootstrap a repo-local `rig` front door for deterministic Anigma development workflows.

## Files Created

- `scripts/rig.py`
- `scripts/rig_cli/__init__.py`
- `scripts/rig_cli/main.py`
- `scripts/rig_cli/commands_atlas.py`
- `scripts/rig_cli/commands_audit.py`
- `scripts/rig_cli/commands_brief.py`
- `scripts/rig_cli/commands_pipeline.py`
- `scripts/rig_cli/commands_git.py`
- `scripts/rig_cli/commands_doctor.py`
- `scripts/test_rig_cli.py`
- `Docs/dev/rig/README.md`
- `Docs/proofs/rig-cli-bootstrap-2026-05-05.md`

## Files Modified

- `scripts/rig_cli/main.py`
- `scripts/rig_cli/commands_audit.py`
- `scripts/rig_cli/commands_pipeline.py`
- `scripts/test_rig_cli.py`

## Command Groups Added

- `rig.py atlas build`
- `rig.py atlas query`
- `rig.py atlas check`
- `rig.py audit dead-code`
- `rig.py audit executable-consolidation`
- `rig.py audit state-flow`
- `rig.py audit zero-copy` when `scripts/anigma_zero_copy_flow_audit.py` exists
- `rig.py brief generate`
- `rig.py brief list-templates`
- `rig.py pipeline run`
- `rig.py pipeline bundle`
- `rig.py pipeline latest-run`
- `rig.py git status`
- `rig.py git scope`
- `rig.py git diff-summary`
- `rig.py git precommit`
- `rig.py git commit-message`
- `rig.py doctor local-fast`
- `rig.py doctor cleanup-review`
- `rig.py doctor backend-regularization`
- `rig.py doctor daemon-runtime`

## Verification Commands

### Static validation

- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/test_rig_cli.py`
  - Exit code: `0`

- `python3 scripts/test_rig_cli.py`
  - Exit code: `0`

### Representative Rig commands

- `python3 scripts/rig.py --help`
  - Exit code: `0`

- `python3 scripts/rig.py atlas query --risk daemon_ipc_binding --target AnigmaDaemonCore --limit 5`
  - Exit code: `0`

- `python3 scripts/rig.py audit executable-consolidation --mode gate --focus anigmad --baseline Docs/baselines/executable-consolidation-baseline.json`
  - Exit code: `0`

- `python3 scripts/rig.py brief list-templates`
  - Exit code: `0`

- `python3 scripts/rig.py brief generate --task td-cleanup-005 --template cleanup_singleton_triage --risk singleton_global_state --target AnigmaDaemonCore --limit 3`
  - Exit code: `0`

- `python3 scripts/rig.py audit zero-copy --help`
  - Exit code: `0`

- `python3 scripts/rig.py audit zero-copy`
  - Exit code: `2`
  - Expected message: `zero-copy audit not implemented yet`

- `python3 scripts/rig.py git status`
  - Exit code: `0`

- `python3 scripts/rig.py pipeline run --profile local-fast --task rig-cli-bootstrap`
  - Exit code: `0`
  - Sample run dir: `.build/anigma-pipeline/runs/rig-cli-bootstrap/20260505T093952Z-5e28da21`

- `python3 scripts/rig.py pipeline latest-run --task rig-cli-bootstrap`
  - Exit code: `0`
  - Sample output: `.build/anigma-pipeline/runs/rig-cli-bootstrap/20260505T093952Z-5e28da21`

- `python3 scripts/rig.py pipeline bundle --task rig-cli-bootstrap --latest-run`
  - Exit code: `0`
  - Sample bundle: `.build/review-bundles/rig-cli-bootstrap-review.zip`

- `python3 scripts/rig.py doctor local-fast --task rig-cli-bootstrap`
  - Exit code: `0`

- `python3 scripts/anigma_diagnose.py validate --task-id rig-cli-bootstrap --command true`
  - Exit code: `0`
  - Status: `CLEAN`

## Compatibility Status

- Existing backend scripts remain directly runnable.
- Rig delegates to existing scripts with `subprocess.run(..., shell=False)`.
- `rig.py audit zero-copy` is intentionally conditional:
  - when `scripts/anigma_zero_copy_flow_audit.py` is absent, Rig reports `not implemented yet` cleanly.
- Rig is a repo-local development harness, not product/runtime code.

## Git / Source Impact

- Production Swift/C++/Metal source changed: `no`
- Git mutation occurred: `no`

## Notes

- `rig.py` is the new internal front door for atlas, audits, briefs, pipeline, git hygiene, and doctor workflows.
- The zero-copy command is documented as planned only until `scripts/anigma_zero_copy_flow_audit.py` exists.
