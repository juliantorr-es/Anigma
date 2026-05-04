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
3. **Outputs**:
   - `.build/anigma-graph/current/anigma-alignment-diagnostic-matrix.json`
   - `.build/anigma-graph/current/anigma-alignment-diagnostic-matrix.csv`
   - `.build/anigma-graph/current/anigma-alignment-diagnostic-summary.md`

## Diagnostic Classes Verified
- [x] **Sidecar Readiness Gap**: P0 findings for sidecar executables lacking receipts.
- [x] **Native Linker Leakage**: P1 findings for generic targets reaching native executors.
- [x] **Zero-copy Overclaim**: Captures unverified performance claims in Docs and Packages.
- [x] **Deterministic Snapshotting**: Verified compatible with TD task snapshots.

## Command Summary
```bash
python3 Scripts/anigma_package_graph_audit.py alignment-matrix
```
Output:
- P0: 5 (Sidecar gaps)
- P1: 201 (Native leaks / zero-copy claims)
- P2: 0
- Informational: 0

## Findings Summary
- **Critical Misalignment**: Sidecar products (PDFSidecarExecutable, anigma-mcp) are treated as build dependencies rather than governed capabilities with readiness receipts.
- **Widespread Leakage**: Many Tier 2 targets carry native dependency paths that must be isolated.
- **Doctrine Enforcement**: Casually used "zero-copy" terminology has been captured and flagged for downgrade.

## Compliance
- No production Swift code changes.
- No `Package.swift` changes.
- No architecture repairs were performed (diagnostics only).
- Doctrine updated in `BUILD_TOOLING_DOCTRINE.md`.
