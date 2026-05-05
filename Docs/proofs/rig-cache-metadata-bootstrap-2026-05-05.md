# Rig Cache Metadata Bootstrap Proof

Date: 2026-05-05

## Scope

Add lightweight cache metadata recording for expensive Rig-derived artifacts without skipping work.

## Files Created

- `scripts/rig_tools/cache_metadata.py`
- `scripts/test_cache_metadata.py`
- `Docs/proofs/rig-cache-metadata-bootstrap-2026-05-05.md`

## Files Modified

- `scripts/rig_cli/main.py`
- `scripts/rig_tools/cache_metadata.py`
- `scripts/test_cache_metadata.py`

## Verification Commands

- `python3 -m py_compile scripts/rig.py scripts/rig_cli/*.py scripts/rig_tools/*.py scripts/test_cache_metadata.py`
  - Exit code: `0`

- `python3 scripts/test_cache_metadata.py`
  - Exit code: `0`

## Cache Metadata Artifacts

Created under:

- `.build/rig/cache-metadata/`

Files:

- `atlas-build.json`
- `pipeline.json`
- `state-flow-audit.json`

## Metadata Contract

Each cache metadata record includes:

- `schema_version`
- `artifact_id`
- `producer`
- `command`
- `input_files`
- `output_files`
- `cache_key`
- `status`
- `environment_fingerprint`
- `duration_seconds`

## Behavior

- Cache metadata is recorded for expensive outputs.
- Work is not skipped yet.
- Missing outputs are recorded as `missing_outputs`.
- Cache keys are stable for identical input hashes and environment fingerprints.

## Git / Source Impact

- Production Swift/C++/Metal source changed: `no`
- Git mutation occurred: `no`

## Notes

- This is groundwork only.
- The next step is to connect the metadata more broadly to atlas/state-flow/review-bundle producers and then consider cache-aware skipping later.
