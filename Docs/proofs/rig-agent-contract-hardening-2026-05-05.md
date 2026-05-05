# Rig Agent Contract Hardening

## Files Created
- `scripts/rig_tools/schema_validation.py`
- `scripts/rig_cli/commands_schema.py`
- `scripts/test_schema_validation.py`
- `Docs/schemas/rig.result.v1.schema.json`
- `Docs/schemas/rig.event.v1.schema.json`
- `Docs/schemas/rig.affected.v1.schema.json`
- `Docs/schemas/rig.swift_diagnostics.v1.schema.json`
- `Docs/schemas/rig.cache_metadata.v1.schema.json`
- `Docs/proofs/rig-agent-contract-hardening-2026-05-05.md`

## Files Modified
- `scripts/anigma_common/repo.py`
- `scripts/rig_cli/main.py`
- `scripts/rig_cli/commands_docs.py`
- `scripts/rig_cli/commands_swift.py`
- `scripts/rig_cli/commands_affected.py`
- `scripts/rig_cli/commands_schema.py`
- `scripts/rig_tools/result.py`
- `scripts/rig_tools/events.py`
- `scripts/rig_tools/cache_metadata.py`
- `scripts/rig_tools/schema_validation.py`
- `scripts/anigma_pipeline.py`
- `Docs/dev/rig/README.md`
- `scripts/test_rig_cli.py`
- `scripts/test_schema_validation.py`

## Schema Families
- `rig.result.v1`
- `rig.event.v1`
- `rig.affected.v1`
- `rig.swift_diagnostics.v1`
- `rig.cache_metadata.v1`

## Commands Run
- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/anigma_common/*.py scripts/test_schema_validation.py scripts/test_result_index.py scripts/test_rig_cli.py scripts/test_cache_metadata.py scripts/test_rig_events.py scripts/test_affected.py`
- `python3 scripts/test_schema_validation.py`
- `python3 scripts/test_result_index.py`
- `python3 scripts/test_cache_metadata.py`
- `python3 scripts/test_rig_events.py`
- `python3 scripts/test_affected.py`
- `python3 scripts/rig.py --jsonl doctor local-fast --task rig-agent-contract-hardening`
- `python3 scripts/rig.py schema validate --family rig.event.v1`
- `python3 scripts/rig.py schema validate --artifact .build/rig/results/latest.json`
- `python3 scripts/rig.py docs index-rig-results`
- `python3 scripts/rig.py schema list`
- `python3 scripts/rig.py schema validate --family rig.result.v1`
- `python3 scripts/rig.py schema validate --family rig.affected.v1`
- `python3 scripts/rig.py schema validate --family rig.swift_diagnostics.v1`
- `python3 scripts/rig.py schema validate --family rig.cache_metadata.v1`

## Exit Codes
- `python3 -m py_compile ...` -> `0`
- `python3 scripts/test_schema_validation.py` -> `0`
- `python3 scripts/test_result_index.py` -> `0`
- `python3 scripts/test_cache_metadata.py` -> `0`
- `python3 scripts/test_rig_events.py` -> `0`
- `python3 scripts/test_affected.py` -> `0`
- `python3 scripts/rig.py --jsonl doctor local-fast --task rig-agent-contract-hardening` -> `0`
- `python3 scripts/rig.py schema validate --family rig.event.v1` -> `0`
- `python3 scripts/rig.py schema validate --artifact .build/rig/results/latest.json` -> `0`
- `python3 scripts/rig.py docs index-rig-results` -> `0`
- `python3 scripts/rig.py schema list` -> `0`
- `python3 scripts/rig.py schema validate --family rig.result.v1` -> `0`
- `python3 scripts/rig.py schema validate --family rig.affected.v1` -> `0`
- `python3 scripts/rig.py schema validate --family rig.swift_diagnostics.v1` -> `0`
- `python3 scripts/rig.py schema validate --family rig.cache_metadata.v1` -> `0`

## Validator
- Optional package available: `jsonschema`
- Validator used: `jsonschema`
- Built-in fallback is covered in tests via `_simple_validate`

## Validation Counts
- `rig.event.v1`: passed `6`, failed `0`, skipped `0`
- `rig.result.v1`: passed `1`, failed `0`, skipped `0`
- `rig.affected.v1`: passed `4`, failed `0`, skipped `0`
- `rig.swift_diagnostics.v1`: passed `1`, failed `0`, skipped `0`
- `rig.cache_metadata.v1`: passed `3`, failed `0`, skipped `0`

## Artifact History
- Per-run results exist under `.build/rig/results/<run_id>.json`
- Latest result remains at `.build/rig/results/latest.json`
- Persisted event streams exist under `.build/rig/events/<run_id>.jsonl`
- Latest event stream exists at `.build/rig/events/latest.jsonl`

## Index Counts
- `rig-run-index`: `11`
- `rig-step-index`: `267`
- `rig-swift-diagnostics-index`: `1`
- `rig-affected-index`: `1`
- `rig-cache-metadata-index`: `2`

## Sample Observations
- `schema validate --artifact .build/rig/results/latest.json` now validates a `rig.result.v1` wrapper instead of a schema-report blob.
- `schema validate --family rig.event.v1` validates persisted JSONL event files.
- `docs index-rig-results` now ingests multiple per-run result rows, not a single singleton latest row.

## Source / Git Status
- Production source changed: `no`
- Git mutation occurred: `no`

## Notes
- Importing `scripts/anigma_common/repo.py` no longer requires an active Git repo during module import.
- Review bundle hygiene now excludes `.DS_Store`, `__pycache__`, `*.pyc`, `DerivedData`, and `.git`.
- Cache metadata now hashes directory trees via directory manifests rather than treating directories as missing.
