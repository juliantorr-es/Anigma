# Context Pipeline Audit Normalization Proof

Date: 2026-05-05

## Files Created
- `scripts/anigma_common/__init__.py`
- `scripts/anigma_common/repo.py`
- `scripts/anigma_common/ignore.py`
- `scripts/anigma_common/io.py`
- `scripts/anigma_common/findings.py`
- `scripts/anigma_common/package_graph.py`

## Files Modified
- `scripts/anigma_dead_code_audit.py`
- `scripts/anigma_executable_consolidation_audit.py`
- `scripts/anigma_build_repo_atlas.py`
- `scripts/anigma_context_query.py`
- `scripts/test_cleanup_audits.py`

## Commands Run
- `python3 -m py_compile scripts/anigma_dead_code_audit.py scripts/anigma_executable_consolidation_audit.py scripts/anigma_build_repo_atlas.py scripts/anigma_context_query.py scripts/anigma_common/*.py scripts/atlas/*.py`
- `python3 scripts/test_cleanup_audits.py`
- `python3 scripts/anigma_dead_code_audit.py --mode advisory --no-proof`
- `python3 scripts/anigma_dead_code_audit.py --mode gate --baseline Docs/baselines/dead-code-baseline.json`
- `python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --no-proof`
- `python3 scripts/anigma_executable_consolidation_audit.py --mode gate --baseline Docs/baselines/executable-consolidation-baseline.json --focus anigmad`
- `python3 scripts/anigma_build_repo_atlas.py`
- `python3 scripts/anigma_context_query.py --risk daemon_ipc_binding --target AnigmaDaemonCore --limit 10`
- `python3 scripts/anigma_context_query.py "Batch 003 socket ownership anigmad" --limit 10`
- `python3 scripts/anigma_context_query.py --entrypoint anigmad --limit 10`
- `python3 scripts/anigma_context_query.py --check`
- `python3 scripts/anigma_diagnose.py validate --task-id context-pipeline-audit-normalization --command true`

## Exit Codes
- py_compile: `0`
- test_cleanup_audits: `0`
- dead-code advisory: `0`
- dead-code gate: `1`
- executable advisory: `0`
- executable gate: `1`
- atlas build: `0`
- context query batch 003: `0`
- context query entrypoint: `0`
- context query check: `0`
- diagnose validate: `0`

## Results
- Production source changed: no
- Baselines changed: no
- Dead-code finding count: 100157
- Executable-consolidation finding count: 311
- Risk-index imported audit finding count: 100468
- Target inference rate: partial; query resolves `AnigmaDaemonCore` paths and entrypoints, but `targets.json` still needs a cleaner package-graph pass for full coverage
- Queryable Batch 003 candidates: yes, but risk list still includes non-target-filtered noise and ignored entries
- `targets.json` populated: yes, but coarse
- Audits can consume atlas: partial; atlas imports normalized findings, but audits themselves are not yet using `--use-atlas`
- Diagnostics bundle atlas metadata: no

## Example Batch 003 Query Output
- `python3 scripts/anigma_context_query.py --risk daemon_ipc_binding --target AnigmaDaemonCore --limit 10` returned `AnigmaDaemonCore`-relevant files like `AntigravityAuthManager.swift`, `CapabilityTokenManager.swift`, and `OAuthManager.swift`, plus top daemon risks from `anigma/Packages/AnigmaDaemon/main.swift`
- `python3 scripts/anigma_context_query.py --entrypoint anigmad --limit 10` still needs entrypoint filtering refinement; current output is not yet selective enough

## Remaining Limitations
- Cleanup audits still need shared `--use-atlas` consumption.
- Query risk filtering still admits ignored/dead-code noise when the atlas risk set is broad.
- Diagnostic harness still lacks atlas metadata bundling.
- Executable gate remains failing against baseline.

## Recommendation
Batch 003 can proceed with manual triage, not full automation. Take the top `daemon_ipc_binding` hits from the target-filtered query, classify them, and only implement `confirmed_risk` or `likely_risk`.
