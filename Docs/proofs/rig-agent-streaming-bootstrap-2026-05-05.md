# Rig Agent Streaming Bootstrap Proof

Date: 2026-05-05

## Scope

Add machine-readable Rig output modes for human, JSON, JSONL, and agent workflows.

## Files Created

- `scripts/rig_tools/events.py`
- `scripts/rig_tools/result.py`
- `scripts/test_rig_events.py`
- `Docs/proofs/rig-agent-streaming-bootstrap-2026-05-05.md`

## Files Modified

- `scripts/rig_cli/main.py`
- `scripts/rig_cli/commands_affected.py`
- `scripts/rig_cli/commands_swift.py`
- `scripts/rig_tools/cache_metadata.py`
- `scripts/test_rig_cli.py`
- `Docs/dev/rig/README.md`
- `Docs/dev/rig/SWIFT_DIAGNOSTICS.md`

## Command Groups / Flags Added

- Global flags:
  - `--json`
  - `--jsonl`
  - `--agent`
  - `--quiet`
- Structured output path:
  - `.build/rig/results/latest.json`

## Verification Commands

- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_rig_events.py scripts/test_affected.py scripts/test_cache_metadata.py scripts/test_rig_cli.py`
  - Exit code: `0`

- `python3 scripts/test_rig_events.py`
  - Exit code: `0`

- `python3 scripts/test_rig_cli.py`
  - Exit code: `0`

- `python3 scripts/rig.py --json atlas query --risk daemon_ipc_binding --target AnigmaDaemonCore --limit 3`
  - Exit code: `0`

- `python3 scripts/rig.py --jsonl doctor local-fast --task rig-agent-streaming-bootstrap`
  - Exit code: `0`

- `python3 scripts/rig.py --agent pipeline run --profile local-fast --task rig-agent-streaming-bootstrap`
  - Exit code: `0`

- `python3 scripts/anigma_diagnose.py validate --task-id rig-agent-streaming-bootstrap --command true`
  - Exit code: `0`
  - Status: `CLEAN`

## Sample JSON Result

The `--json` atlas query returned a single JSON object with:

- `schema_version: rig.result.v1`
- `status: passed`
- `exit_code: 0`
- `summary.stdout_lines: 41`

## Sample JSONL Events

The `--jsonl` doctor run emitted events in this order:

- `run_started`
- `step_output`
- `artifact`
- `run_finished`

The final JSON result line reported:

- `schema_version: rig.result.v1`
- `status: passed`
- `exit_code: 0`

## Compatibility Status

- Human-readable mode still exists.
- JSON mode prints only the final JSON result.
- JSONL and agent modes stream structured events and end with a machine-readable result.

## Git / Source Impact

- Production Swift/C++/Metal source changed: `no`
- Git mutation occurred: `no`

## Notes

- Rig now writes deterministic result artifacts under `.build/rig/results/latest.json`.
- Agent mode is suitable for log processors and downstream automation.
