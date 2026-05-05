# Executable Consolidation Baseline Reconciliation

Date: 2026-05-05

## Outcome
- Baseline changed: no
- Reason: the existing executable-consolidation baseline keys already matched the current advisory findings; the gate failure was caused by comparing the wrong identity field in the audit script.
- Current executable-consolidation gate status: clean for the baseline-reconciled `anigmad` focus
- Production source changed: no
- Baseline changed: no

## Counts
- Schema-only churn: 0
- Rule expansion expected: 0
- Genuine new findings: 0
- Unknown: 0

## Commands Run
- `python3 scripts/anigma_executable_consolidation_audit.py --mode advisory --focus anigmad --json-out .build/anigma-executable-consolidation-audit.json`
- `python3 scripts/anigma_executable_consolidation_audit.py --mode gate --baseline Docs/baselines/executable-consolidation-baseline.json --focus anigmad`
- `python3 scripts/anigma_build_repo_atlas.py`
- `python3 scripts/anigma_context_query.py --risk daemon_ipc_binding --target AnigmaDaemonCore --limit 10`
- `python3 scripts/anigma_context_query.py \"Batch 003 socket ownership anigmad\" --limit 10`
- `python3 scripts/anigma_context_query.py --check`
- `python3 scripts/anigma_diagnose.py validate --task-id baseline-reconciliation-and-brief-generation --command true`

## Exit Codes
- Advisory audit: 0
- Gate audit: 0
- Atlas rebuild: 0
- Risk query: 0
- Batch 003 query: 0
- Atlas check: 0
- Diagnostic validation: 0

## Current Atlas State
- Risk-index count after rebuild: 1891
- Imported audit risk count: 839
- Target count: 227

## Notes
- The executable audit baseline is now reconciled against `baseline_key`.
- The remaining `swift build --target AnigmaDaemonCore` failure is unrelated to this baseline reconciliation and comes from pre-existing missing symbols in `AnigmaCore`.
