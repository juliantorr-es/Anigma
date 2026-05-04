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

## Calibration Status
**The alignment diagnostic matrix calibration is complete.**

### P0 Findings: Sidecar Readiness Gap
- **Count**: 5 (preserved through calibration)
- **Subjects**: `AnigmaSidecar`, `SidecarOfficeService`, `SidecarPDFService`, `SidecarTranslateService`, `PDFSidecarExecutable`.
- **Assessment**: **REAL**. These sidecars are currently treated as build dependencies but lack the mandated runtime readiness receipts.
- **Ownership**: To be resolved in `td-7c0153-01` (PDF) and follow-up sidecar readiness TDs.

### P1 Findings: Calibrated
- **Before Calibration**: 213 (high noise)
- **After Calibration**: 24 (actionable signal)
- **Noise Reduction**: 88.7% (189 false positives eliminated)
- **Native Leakage**: **REAL - preserved**. `ExecutionCore` reaches `HardwareAuthority` via graph analysis.
- **Claim Overclaims**: **CLEAN**. Zero-copy claim scanning now excludes doctrine/research/proof meta-discussion. Remaining 22 zero-copy findings are production Swift files with actual claims requiring receipt evidence.
- **Hardware-Resident**: **REAL - preserved**. 1 finding in `MediaGovernance.swift`.

## Command Summary
```bash
python3 Scripts/anigma_package_graph_audit.py alignment-matrix --fail-on-p0
```
- **Exit Code 1**: Correctly fails if P0 diagnostics exist.
- **Snapshot Support**: Verified with `--task-id` snapshots.
- **Deterministic**: Identical output on repeated runs.

## Calibration Mechanics
The matrix remains strict for:
- P0 sidecar readiness gaps
- Graph-backed native leakage (via `get_why_builds`)

Zero-copy claim scanning improvements:
1. **Path exclusions**: `claim_scan_exclusions.path_patterns` excludes `Docs/governance/**`, `Docs/research/**`, `Docs/proofs/**`, `Docs/schemas/**`, `Docs/td/**`, `Docs/diagrams/**`, `Docs/architecture/**`.
2. **Context filters**: `claim_context_filters.exclude_phrases` removes meta-discussion lines (future tense, conditionals, TODOs, definitions).
3. **Deduplication**: One finding per file per pattern via `deduplication.key: file_pattern`.
4. **Extension targeting**: Only `.swift` files scanned for claims in production code.

See `Docs/governance/alignment-diagnostic-rules.yaml` for full rule set.

## Next Work Queue
### P0
- Review 5 sidecar readiness gaps, ensure each has an owner TD.

### P1
- **Graph-backed**: `ExecutionCore` → `HardwareAuthority` native leakage.
- **Zero-copy claims**: 22 production Swift files flagged for claims without receipt evidence.
- **Hardware-resident claim**: `MediaGovernance.swift` requires domain proof.

### P2 / Later
- Continue improving ECS/capsule terminology only when it touches runtime/API decisions.

## Compliance
- alignment-matrix subcommand implemented.
- outputs JSON, CSV, and Markdown.
- generated matrix is canonical review evidence.
- initial baseline is diagnostic, not automatically confirmed defects.
- no production code changed.
- no Package.swift architecture changes made.
