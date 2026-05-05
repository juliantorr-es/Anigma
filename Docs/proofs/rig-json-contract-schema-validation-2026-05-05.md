# Rig JSON Contract and Schema Validation

## Files Created
- `scripts/rig_cli/commands_schema.py`
- `scripts/rig_tools/schema_validation.py`
- `scripts/test_schema_validation.py`
- `Docs/schemas/rig.result.v1.schema.json`
- `Docs/schemas/rig.event.v1.schema.json`
- `Docs/schemas/rig.affected.v1.schema.json`
- `Docs/schemas/rig.swift_diagnostics.v1.schema.json`
- `Docs/schemas/rig.cache_metadata.v1.schema.json`
- `Docs/proofs/rig-json-contract-schema-validation-2026-05-05.md`

## Files Modified
- `scripts/rig_cli/main.py`
- `Docs/dev/rig/README.md`
- `scripts/test_rig_cli.py`
- `scripts/rig_tools/schema_validation.py`

## Schema Families Added
- `rig.result.v1`
- `rig.event.v1`
- `rig.affected.v1`
- `rig.swift_diagnostics.v1`
- `rig.cache_metadata.v1`

## Commands Run
- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_schema_validation.py`
- `python3 scripts/test_schema_validation.py`
- `python3 scripts/rig.py --json atlas query --risk daemon_ipc_binding --target AnigmaDaemonCore --limit 3`
- `python3 scripts/rig.py schema list`
- `python3 scripts/rig.py schema validate --artifact .build/rig/results/latest.json`
- `python3 scripts/rig.py schema validate --family rig.result.v1`
- `python3 scripts/rig.py schema validate --family rig.affected.v1`
- `python3 scripts/rig.py schema validate --family rig.swift_diagnostics.v1`
- `python3 scripts/rig.py schema validate --family rig.cache_metadata.v1`
- `python3 scripts/rig.py --jsonl doctor local-fast --task rig-json-contract-schema-validation`
- `python3 scripts/rig.py schema validate --family rig.event.v1`
- `python3 scripts/anigma_diagnose.py validate --task-id rig-json-contract-schema-validation --command true`

## Exit Codes
- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_schema_validation.py` -> `0`
- `python3 scripts/test_schema_validation.py` -> `0`
- `python3 scripts/rig.py --json atlas query --risk daemon_ipc_binding --target AnigmaDaemonCore --limit 3` -> `0`
- `python3 scripts/rig.py schema list` -> `0`
- `python3 scripts/rig.py schema validate --artifact .build/rig/results/latest.json` -> `0`
- `python3 scripts/rig.py schema validate --family rig.result.v1` -> `0`
- `python3 scripts/rig.py schema validate --family rig.affected.v1` -> `0`
- `python3 scripts/rig.py schema validate --family rig.swift_diagnostics.v1` -> `0`
- `python3 scripts/rig.py schema validate --family rig.cache_metadata.v1` -> `0`
- `python3 scripts/rig.py --jsonl doctor local-fast --task rig-json-contract-schema-validation` -> `0`
- `python3 scripts/rig.py schema validate --family rig.event.v1` -> `0`
- `python3 scripts/anigma_diagnose.py validate --task-id rig-json-contract-schema-validation --command true` -> `0`

## Validation Result Counts
- `rig.result.v1`: passed `1`, failed `0`, skipped `0`
- `rig.affected.v1`: passed `4`, failed `0`, skipped `0`
- `rig.swift_diagnostics.v1`: passed `1`, failed `0`, skipped `0`
- `rig.cache_metadata.v1`: passed `3`, failed `0`, skipped `0`
- `rig.event.v1`: passed `0`, failed `0`, skipped `0` (no event artifacts discovered in this bootstrap)

## Validator
- Optional package available: `jsonschema`
- Validator used: `jsonschema`
- Built-in fallback validated in tests via `_simple_validate`

## Sample Validation Failure
- Test fixture for `rig.result.v1` missing required fields produced required-property failures in `scripts/test_schema_validation.py`

## Source / Git Status
- Production source changed: `no`
- Git mutation occurred: `no`

## Notes
- Rig validation outputs are written to `.build/rig/schema-validation/latest.json` and `.build/rig/schema-validation/latest.md`.
- Markdown and CSV remain derived views; JSON is the canonical machine artifact.
