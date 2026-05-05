# Rig Affected Bootstrap Proof

Date: 2026-05-05

## Scope

Add `rig affected` to the repo-local Rig harness so changed files can be mapped to affected targets, risks, and validation profiles using git plus atlas context.

## Files Created

- `scripts/rig_cli/commands_affected.py`
- `scripts/rig_tools/affected.py`
- `scripts/test_affected.py`
- `Docs/dev/rig/AFFECTED.md`
- `Docs/proofs/rig-affected-bootstrap-2026-05-05.md`

## Files Modified

- `scripts/rig_cli/main.py`
- `scripts/test_rig_cli.py`
- `Docs/dev/rig/README.md`

## Command Groups Added

- `rig.py affected files`
- `rig.py affected targets`
- `rig.py affected risks`
- `rig.py affected profiles`
- `rig.py affected summary`

## Verification Commands

### Static validation

- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_affected.py scripts/test_rig_cli.py`
  - Exit code: `0`

- `python3 scripts/test_affected.py`
  - Exit code: `0`

- `python3 scripts/test_rig_cli.py`
  - Exit code: `0`

### Rig affected commands

- `printf '%s\n' 'scripts/rig.py' 'anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift' 'anigma/Package.swift' | python3 scripts/rig.py affected files --stdin`
  - Exit code: `0`
  - Output artifact: `.build/rig/affected/files.json`

- `python3 scripts/rig.py affected targets --base HEAD --head HEAD`
  - Exit code: `0`
  - Output artifact: `.build/rig/affected/targets.json`

- `python3 scripts/rig.py affected risks --base HEAD --head HEAD`
  - Exit code: `0`
  - Output artifact: `.build/rig/affected/risks.json`

- `python3 scripts/rig.py affected profiles --task td-cleanup-005`
  - Exit code: `0`
  - Output artifact: `.build/rig/affected/profiles.json`

- `python3 scripts/rig.py affected summary --task td-cleanup-005`
  - Exit code: `0`
  - Output artifact: `.build/rig/affected/summary.md`

- `python3 scripts/anigma_diagnose.py validate --task-id rig-affected-bootstrap --command true`
  - Exit code: `0`
  - Status: `CLEAN`

## Artifact Paths

- `.build/rig/affected/files.json`
- `.build/rig/affected/targets.json`
- `.build/rig/affected/risks.json`
- `.build/rig/affected/profiles.json`
- `.build/rig/affected/summary.md`

## Sample Outputs

### Affected files

The stdin-mode sample included:

- `scripts/rig.py`
- `anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
- `anigma/Package.swift`

### Affected targets

The stdin-mode sample inferred:

- `AnigmaDaemonCore`

### Affected profiles

The task-scoped sample recommended:

- `local-fast`
- `daemon-runtime`
- `cleanup-review`
- `backend-regularization`

### Affected risks

The generated `risks.json` reported:

- `affected_risk_count`: `61`

## Behavior

- `rig affected files` supports stdin and git modes.
- `rig affected targets` maps files to targets using atlas target/source-path data and path heuristics.
- `rig affected risks` filters atlas risks by changed file or affected target.
- `rig affected profiles` recommends deterministic validation profiles from the affected area.
- Outputs are deterministic JSON and Markdown under `.build/rig/affected/`.

## Compatibility Status

- Existing Rig commands remain directly runnable.
- Rig remains a repo-local harness, not product/runtime code.
- `--affected` pipeline wiring is documented as planned, not required for this bootstrap.

## Git / Source Impact

- Production Swift/C++/Metal source changed: `no`
- Git mutation occurred: `no`

## Notes

- Default git mode is broad in the current dirty worktree, so repo-wide runs surface many unrelated atlas/doc/proof files.
- `--stdin` is the cleanest way to provide an explicit change set for affected analysis today.
- `HEAD..HEAD` is a valid smoke test for the command surface even though it produces no diff.
