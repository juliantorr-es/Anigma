# Rig Result Ingestion Bootstrap

## Files Created
- `scripts/rig_tools/result_index.py`
- `scripts/test_result_index.py`
- `scripts/rig_cli/commands_docs.py`
- `Docs/indexes/rig-run-index.json`
- `Docs/indexes/rig-run-index.csv`
- `Docs/indexes/rig-step-index.json`
- `Docs/indexes/rig-step-index.csv`
- `Docs/indexes/rig-swift-diagnostics-index.json`
- `Docs/indexes/rig-swift-diagnostics-index.csv`
- `Docs/indexes/rig-affected-index.json`
- `Docs/indexes/rig-affected-index.csv`
- `Docs/indexes/rig-cache-metadata-index.json`
- `Docs/indexes/rig-cache-metadata-index.csv`
- `Docs/proofs/rig-result-ingestion-bootstrap-2026-05-05.md`
- `.build/rig/context-packs/td-cleanup-005-small.md`

## Files Modified
- `scripts/rig_cli/main.py`
- `scripts/test_rig_cli.py`
- `Docs/dev/rig/README.md`
- `scripts/rig_tools/result_index.py`

## Commands Run
- `python3 -m py_compile scripts/rig_tools/result_index.py scripts/test_result_index.py scripts/rig.py scripts/rig_cli/*.py`
- `python3 scripts/test_result_index.py`
- `python3 scripts/test_rig_cli.py`
- `python3 scripts/rig.py --agent pipeline run --profile local-fast --task rig-result-ingestion-bootstrap`
- `python3 scripts/rig.py --json affected summary --task td-cleanup-005`
- `python3 scripts/rig.py --json swift build --target AnigmaDaemonCore`
- `python3 scripts/rig.py docs index-rig-results`
- `python3 scripts/rig.py docs table rig-run-index`
- `python3 scripts/rig.py docs table rig-swift-diagnostics-index`
- `python3 scripts/rig.py docs table rig-affected-index`
- `python3 scripts/rig.py docs context-pack --task td-cleanup-005 --budget small`
- `python3 scripts/anigma_diagnose.py validate --task-id rig-result-ingestion-bootstrap --command true`

## Exit Codes
- `python3 -m py_compile scripts/rig_tools/result_index.py scripts/test_result_index.py scripts/rig.py scripts/rig_cli/*.py` -> `0`
- `python3 scripts/test_result_index.py` -> `0`
- `python3 scripts/test_rig_cli.py` -> `0`
- `python3 scripts/rig.py --agent pipeline run --profile local-fast --task rig-result-ingestion-bootstrap` -> `0`
- `python3 scripts/rig.py --json affected summary --task td-cleanup-005` -> `0`
- `python3 scripts/rig.py --json swift build --target AnigmaDaemonCore` -> `1`
- `python3 scripts/rig.py docs index-rig-results` -> `0`
- `python3 scripts/rig.py docs table rig-run-index` -> `0`
- `python3 scripts/rig.py docs table rig-swift-diagnostics-index` -> `0`
- `python3 scripts/rig.py docs table rig-affected-index` -> `0`
- `python3 scripts/rig.py docs context-pack --task td-cleanup-005 --budget small` -> `0`
- `python3 scripts/anigma_diagnose.py validate --task-id rig-result-ingestion-bootstrap --command true` -> `0`

## Row Counts
- `rig-run-index`: `1`
- `rig-step-index`: `243`
- `rig-swift-diagnostics-index`: `1`
- `rig-affected-index`: `1`
- `rig-cache-metadata-index`: `3`

## Sample Rows

### Run Row
- `run_id`: `e98c87212138`
- `command_group`: `docs`
- `status`: `passed`
- `exit_code`: `0`
- `artifact_count`: `10`
- `result_path`: `.build/rig/results/latest.json`

### Swift Diagnostics Row
- `target`: `AnigmaDaemonCore`
- `status`: `failed`
- `exit_code`: `1`
- `diagnostic_count`: `2`
- `categories`: `missing_import;unknown`
- `known_blocker_id`: `build-anigmacore-runtimecore-001`
- `latest_json`: `.build/rig/swift-diagnostics/latest.json`

### Affected Row
- `task`: `td-cleanup-005`
- `mode`: `git`
- `changed_file_count`: `269`
- `directly_affected_targets`: `AnigmaDaemon;AnigmaDaemonCore;AnigmaFoundation;AnigmaGovernance;ContractsCore;GovernanceContracts;HarmoniaMemory;MediaCore;ModelRegistry;SecurityEventsContracts;SecurityEventsManager`
- `affected_risk_count`: `61`
- `recommended_profiles`: `local-fast;daemon-runtime;cleanup-review;backend-regularization`

### Cache Metadata Row
- `artifact_id`: `atlas-build`
- `producer`: `anigma_build_repo_atlas`
- `status`: `fresh`
- `cache_key`: `02b676d8108b7352a7b8e460f4c3bcd45099249ce557045c0d3168e767f462b8`
- `metadata_path`: `.build/rig/cache-metadata/atlas-build.json`

## Context Pack
- Context pack written to `.build/rig/context-packs/td-cleanup-005-small.md`
- Included latest run summary, latest Swift diagnostics summary, latest affected summary, and cache freshness summary

## Source / Git Status
- Production source changed: `no`
- Git mutation occurred: `no`

## Notes
- `Docs/indexes/` contains deterministic JSON and CSV outputs.
- `.build/...` paths are preserved verbatim in the generated indexes.
- Review bundle manifests were not ingested in this bootstrap; that remains a later optional extension.
