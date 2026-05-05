# Rig Affected Analysis

Rig can analyze a change set and answer:

- which files changed
- which targets are directly affected
- which risks are touched
- which validation profiles are most relevant

## Modes

- `python3 scripts/rig.py affected files`
- `python3 scripts/rig.py affected files --base main --head HEAD`
- `python3 scripts/rig.py affected files --stdin`
- `python3 scripts/rig.py affected targets --base main --head HEAD`
- `python3 scripts/rig.py affected risks --base main --head HEAD`
- `python3 scripts/rig.py affected profiles --task td-cleanup-005`
- `python3 scripts/rig.py affected summary --task td-cleanup-005`

## Inputs

Rig affected analysis reads:

- `git diff --name-only`
- `git status --porcelain`
- `Docs/atlas/repo-map.json`
- `Docs/atlas/targets.json`
- `Docs/atlas/risk-index.json`
- `Docs/atlas/state-map.json` when present
- `Docs/pipeline/profiles/*.yaml`

## Outputs

All outputs are written under:

- `.build/rig/affected/`

Files:

- `files.json`
- `targets.json`
- `risks.json`
- `profiles.json`
- `summary.md`

## Notes

- Rig affected analysis is deterministic and read-only.
- It is advisory only.
- `--affected` pipeline wiring is planned, not mandatory yet.
