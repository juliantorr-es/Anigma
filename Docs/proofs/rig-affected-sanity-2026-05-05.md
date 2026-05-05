# Rig Affected Sanity Proof

Date: 2026-05-05

## Scope

Verify `rig affected` on two controlled change sets:

- docs/scripts-only
- AnigmaDaemonCore production

## Files Created

- `scripts/rig_cli/commands_affected.py`
- `scripts/rig_tools/affected.py`
- `scripts/test_affected.py`
- `Docs/dev/rig/AFFECTED.md`
- `scripts/fixtures/affected/docs_scripts_change.txt`
- `scripts/fixtures/affected/daemon_core_change.txt`
- `Docs/proofs/rig-affected-sanity-2026-05-05.md`

## Files Modified

- `scripts/rig_cli/main.py`
- `scripts/rig_cli/commands_affected.py`
- `scripts/test_rig_cli.py`
- `Docs/dev/rig/README.md`

## Verification Commands

- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_affected.py scripts/test_rig_cli.py`
  - Exit code: `0`

- `python3 scripts/test_affected.py`
  - Exit code: `0`

- `python3 scripts/rig.py affected files --stdin`
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

## Sample Recommendations

### Docs / scripts-only change

Input fixture:

- `scripts/rig.py`
- `scripts/test_rig_cli.py`
- `Docs/dev/rig/README.md`
- `Docs/dev/rig/AFFECTED.md`

Result:

- Direct targets: `[]`
- Recommended profiles: `local-fast`
- Affected risks: `0`

### AnigmaDaemonCore change

Input fixture:

- `anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonServer.swift`
- `anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonCompatibility.swift`
- `anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Services/HTTPServer.swift`
- `anigma/Package.swift`

Result:

- Direct targets: `AnigmaDaemonCore`
- Recommended profiles:
  - `daemon-runtime`
  - `cleanup-review`
  - `backend-regularization`
- Affected risks: `37`

## Artifact Paths

- `.build/rig/affected/files.json`
- `.build/rig/affected/targets.json`
- `.build/rig/affected/risks.json`
- `.build/rig/affected/profiles.json`
- `.build/rig/affected/summary.md`

## Compatibility Status

- `rig affected` is deterministic and read-only.
- `--stdin` is the cleanest precise mode when the worktree is dirty.
- Existing Rig commands remain directly runnable.

## Git / Source Impact

- Production Swift/C++/Metal source changed: `no`
- Git mutation occurred: `no`

## Notes

- Default git mode is broad in the current dirty worktree and surfaces many unrelated files.
- The fixture-based sanity checks show that docs/scripts-only and AnigmaDaemonCore changes recommend different profiles, which is the intended behavior.
