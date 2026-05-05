# Rig Naming and Progress Streaming Proof

Files created:
- `Docs/dev/rig/NAMING.md`
- `Docs/proofs/rig-naming-and-progress-streaming-2026-05-05.md`

Files modified:
- `scripts/rig_cli/commands_project.py`
- `scripts/rig_cli/main.py`
- `Docs/dev/rig/README.md`
- `scripts/test_architecture_projector.py`

Files moved/renamed:
- none

Compatibility wrappers preserved:
- existing `scripts/anigma_*.py` entrypoints preserved
- no wrapper deletion or breakage performed

Inventory path:
- `.build/rig/naming/rig-script-inventory.json`

Rename plan path:
- `.build/rig/naming/rig-rename-plan.json`
- `.build/rig/naming/rig-rename-plan.md`

Commands run:
- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/*.py` -> `0`
- `python3 scripts/test_rig_cli.py` -> `0`
- `python3 scripts/test_rig_events.py` -> `0`
- `python3 scripts/test_schema_validation.py` -> `0`
- `python3 scripts/test_architecture_projector.py` -> `0`
- `python3 scripts/rig.py --json monitor runs` -> `0`
- `python3 scripts/rig.py --json project architecture --target AnigmaDaemonCore` -> `0`
- `python3 scripts/rig.py --jsonl project architecture --target AnigmaDaemonCore` -> `0`
- `python3 scripts/rig.py --agent pipeline run --profile local-fast --task rig-naming-progress-streaming` -> `0`
- `python3 scripts/rig.py schema validate --family rig.event.v1` -> `0`
- `python3 scripts/rig.py schema validate --family rig.result.v1` -> `0`
- `python3 scripts/anigma_diagnose.py validate --task-id rig-naming-progress-streaming --command true` -> `0`

Exit codes:
- all validation commands returned `0`

Event count before/after for one JSONL command:
- `--jsonl project architecture --target AnigmaDaemonCore`
- event file: `.build/rig/events/e0df1f03ebc1.jsonl`
- persisted event lines: `5`
- stdout lines: `6`
- final result line present and parseable

JSON mode stayed clean:
- yes; `--json` projection output did not include progress events

Schema validation results:
- `rig.event.v1` family passed
- `rig.result.v1` family passed

Casing conflicts found/resolved/deferred:
- tracked root `scripts/` is canonical
- tracked uppercase `Scripts/` still exists for compatibility/tests
- no case-only rename performed in this pass

Production source changed:
- no

Git mutation occurred:
- no

Advisory note:
- progress events are structured Rig events, not print spam
- naming normalization is documented and inventory-backed; compatibility surfaces remain intact

