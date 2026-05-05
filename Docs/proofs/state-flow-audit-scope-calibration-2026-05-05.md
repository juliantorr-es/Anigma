# State Flow Audit Scope Calibration Proof

Date: 2026-05-05

## Commands Run
- `python3 -m py_compile scripts/anigma_state_flow_audit.py scripts/test_state_flow_audit.py scripts/anigma_context_query.py` -> `0`
- `python3 scripts/test_state_flow_audit.py` -> `0`
- `python3 scripts/anigma_state_flow_audit.py --mode advisory --target AnigmaDaemonCore --exclude-external-research --json-out .build/anigma-state-flow-audit.json --proof-out Docs/proofs/state-flow-audit-scope-calibration-2026-05-05.md` -> `0`
- `python3 scripts/anigma_state_flow_audit.py --mode advisory --scope repo --json-out .build/anigma-state-flow-audit-repo.json --proof-out Docs/proofs/state-flow-audit-repo-bootstrap-2026-05-05.md` -> `0`
- `python3 scripts/anigma_build_repo_atlas.py` -> `0`
- `python3 scripts/anigma_context_query.py --state path_constant --target AnigmaDaemonCore --limit 10` -> `0`
- `python3 scripts/anigma_context_query.py --flow ambient_process_read --target AnigmaDaemonCore --limit 10` -> `0`
- `python3 scripts/anigma_context_query.py --cohesion AnigmaDaemonCore --limit 10` -> `0`
- `python3 scripts/anigma_diagnose.py validate --task-id state-flow-audit-scope-calibration --command true` -> `0`

## Scope
- scope: `target`
- target: `AnigmaDaemonCore`
- focus: `anigmad`
- external_research_excluded: `true`
- include_tests: `false`

## Before / After Summary
- Before total records: `288200`
- Before state records: `270485`
- Before flow records: `17715`
- Before ExternalResearch source-category count: `172297`
- After total records: `106777`
- After state records: `92111`
- After flow records: `14666`
- After ExternalResearch source-category count: `0`

## After Source Category Counts
- production: `92046`
- scripts: `10`
- unknown: `55`

## After Flow Source Category Counts
- production: `14421`
- scripts: `10`
- unknown: `235`

## After Classification Counts
- actor_owned_state: `1049`
- environment_key: `149`
- immutable_domain_constant: `36225`
- mutable_global_state: `13515`
- path_constant: `446`
- static_singleton: `5`
- typealias_obscuring: `31`
- typealias_semantic: `642`
- unknown: `40049`

## After Risk Label Counts
- ambient_state_bypass: `149`
- approved: `12949`
- bypass: `543`
- global_mutable_state: `13520`
- integration_gap: `128`
- path_ownership_ambiguous: `446`
- stringly_typed_boundary: `31`
- unknown: `1174`

## Top AnigmaDaemonCore State Findings
- `anigma/Packages/AnigmaDaemonCore/Auth/AntigravityAuthManager.swift:17` `immutable_domain_constant` `AntigravityConstants`
- `anigma/Packages/AnigmaDaemonCore/Auth/AntigravityAuthManager.swift:35` `immutable_domain_constant` `AntigravityTokenSet`
- `anigma/Packages/AnigmaDaemonCore/Auth/AntigravityAuthManager.swift:51` `service_state` `AntigravityAuthManager`
- `anigma/Packages/AnigmaDaemonCore/Jobs/ContextumWorkerBootstrap.swift:323` `path_constant` `Hardcoded path-like constant`
- `anigma/Packages/AnigmaDaemonCore/Auth/AntigravityAuthManager.swift:19` `unknown`

## Top AnigmaDaemonCore Flow Findings
- `anigma/Packages/AnigmaDaemonCore/Jobs/ContextumWorkerBootstrap.swift` `ambient_process_read` `bypass` `Direct ProcessInfo environment read`
- `anigma/Packages/AnigmaDaemonCore/Jobs/IndexingWorker.swift` `ambient_process_read` `bypass` `Direct ProcessInfo environment read`
- `anigma/Packages/AnigmaDaemonCore/Jobs/MLInferWorker.swift` `ambient_process_read` `bypass` `Direct ProcessInfo environment read`
- `anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/DaemonConfigurationStub.swift` `ambient_process_read` `bypass` `Direct ProcessInfo environment read`
- `anigma/Packages/AnigmaDaemonCore/Sources/AnigmaDaemonCore/Handlers/DaemonServer+Assistant.swift` `ambient_process_read` `bypass` `Direct ProcessInfo environment read`

## Top Cohesion Bottlenecks After Filtering
- `Workflows` score `416049`
- `VizAggregationNative` score `929`

## ExternalResearch Exclusion
- Repo-wide mode includes ExternalResearch: `true`
- Target-scoped mode excludes ExternalResearch: `true`
- Repo-wide ExternalResearch source-category count: `172297`
- Target-scoped ExternalResearch source-category count: `0`

## Validation Result
- Diagnostics validation status: `CLEAN`

## Production Source
- No production source changed.

## Recommendation
- Use the target-scoped mode for AnigmaDaemonCore / anigmad architecture work.
- Keep repo-wide mode only for broad repository observation.

