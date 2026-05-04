# Proof of Alignment Diagnostic Matrix Workflow

## Context
The research phase of `td-backend-normalization-heterogeneous-overlap` identified several misaligned assumptions between backend consolidation and heterogeneous saturated architecture. To systematically track these, the SwiftPM diagnosis workflow has been extended to generate an **Alignment Diagnostic Matrix**.

## Artifacts Generated
1. **Rule Set**: `Docs/governance/alignment-diagnostic-rules.yaml`
   - Defines roles, native markers, sidecar patterns, and claim audit rules.
2. **Script Extension**: `Scripts/anigma_package_graph_audit.py`
   - Added `alignment-matrix` subcommand.
   - Generates JSON, CSV, and Markdown summaries.
   - Supports `--task-id` and `--label` for snapshots.
   - Ensures repo-relative paths and deterministic IDs.
3. **Outputs**:
   - `.build/anigma-graph/current/anigma-alignment-diagnostic-matrix.json`
   - `.build/anigma-graph/current/anigma-alignment-diagnostic-matrix.csv`
   - `.build/anigma-graph/current/anigma-alignment-diagnostic-summary.md`

## Review Findings
The initial baseline was generated and reviewed for false positives.

### P0 Findings: Sidecar Readiness Gap
- **Count**: 5
- **Subjects**: `AnigmaSidecar`, `SidecarOfficeService`, `SidecarPDFService`, `SidecarTranslateService`, `PDFSidecarExecutable`.
- **Assessment**: **REAL**. These sidecars are currently treated as build dependencies but lack the mandated runtime readiness receipts.
- **Ownership**: To be resolved in `td-7c0153-01` (PDF) and follow-up sidecar readiness TDs.

### P1 Findings: Samples & False Positives
- **Count**: 204
- **Native Leakage**: **REAL**. `ExecutionCore` was confirmed to reach `HardwareAuthority` via actual graph analysis.
- **Claim Overclaims**: **MIXED / HIGH NOISE**. The automated scanner flags mentions of "zero-copy" in research docs and doctrine files that are actually citing or discussing the rule (self-references).
- **Paths**: Verified repo-relative paths are used.

## Command Summary
```bash
python3 Scripts/anigma_package_graph_audit.py alignment-matrix --fail-on-p0
```
- **Exit Code 1**: Correctly fails if P0 diagnostics exist.
- **Snapshot Support**: Verified with `--task-id` snapshots.

## Follow-up Recommended
1. **Calibration TD**: Calibrate `alignment-diagnostic-rules.yaml` to exclude meta-mentions of zero-copy in Docs/governance and research folders.
2. **Readiness Implementation**: Resolve the 5 P0 readiness gaps.

## Compliance
- alignment-matrix subcommand implemented.
- outputs JSON, CSV, and Markdown.
- generated matrix is canonical review evidence.
- initial baseline is diagnostic, not automatically confirmed defects.
- no production code changed.
- no Package.swift architecture changes made.
