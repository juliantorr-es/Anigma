# td-master-diagnostic-harness - Create master Anigma diagnostic harness for baseline, validation, review, and diff artifacts

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P1  
> **Lane**: tooling-governance

## Purpose
Create a single deterministic diagnostic script that agents must use at the beginning, validation, and review phases of architecture-sensitive TDs. The script should capture SwiftPM graph evidence, alignment diagnostics, git diffs, build/test logs, validation summaries, and proof-ready artifact manifests.

## Core Problem
Anigma currently has several diagnostic tools and artifact patterns (`anigma_package_graph_audit.py`, alignment-matrix, SwiftPM snapshots, build logs, etc.), but agents still improvise the workflow. This causes inconsistent evidence, missing diffs, stale blocker claims, and unclear review boundaries.

## Goal
Standardize:
1. **Baseline capture** before implementation.
2. **Validation capture** after implementation.
3. **Review bundle generation** before marking a TD done.
4. **Diff audit** between file states.
5. **Artifact manifest generation**.
6. **Build status classification** (CLEAN, CONTAMINATED, FAILED, PASSED).

## Proposed Script: `Scripts/anigma_diagnose.py`

### Required Modes
1. **`baseline`**: Used before implementation. Captures git status, diffs, graph snapshot, alignment matrix, and unclassified targets.
2. **`validate`**: Used after implementation. Runs a command, captures output, warnings, errors, and determines build status. Captures graph/alignment after changes.
3. **`review`**: Used before task closure. Generates a full artifact bundle, diff against baseline, and risk findings (categorized by production code, docs, schemas, etc.).
4. **`diff`**: Explicit file-state comparison between phases.
5. **`full`**: Runs baseline, validate, and review in a single workflow.

## Required Outputs
Output root: `.build/anigma-diagnostics/tasks/<task-id>/<commit-hash>/<phase>/`

### Required Files (per phase)
- `artifact-manifest.json`
- `diagnostic-summary.json / .md`
- `git-status.txt`
- `git-diff.patch`
- `changed-files.json`
- `package-graph/` (normalized JSONs)
- `alignment/` (matrix results)
- `logs/` (if command provided)
- `review-bundle.md` (review phase only)

## Required Behavior
1. **Determinism**: Sorted JSON keys, stable IDs, repo-relative paths, no timestamps by default.
2. **Safety**: Read-only by default, no production code or `Package.swift` changes, no automatic commits.
3. **Build Status**:
   - **FAILED**: Nonzero exit code.
   - **CLEAN**: Exit code 0, warning count 0.
   - **CONTAMINATED**: Exit code 0, warning count > 0.
   - **PASSED**: Exit code 0, warning status unknown.
4. **Diff Risk Classification**:
   - **Low**: Docs/proofs.
   - **Medium**: Scripts/tooling/tests.
   - **High**: Package.swift, production Swift, validators, schemas.
   - **Critical**: Contracts, native shims, sidecars, security/governance code.

## Acceptance Criteria
- `Scripts/anigma_diagnose.py` exists and supports all mandated modes.
- Script produces deterministic artifact bundles.
- Diagnostic bundle JSON validates against schema.
- Review mode generates `review-bundle.md` with risk analysis and forbidden change checks.
- Doctrine updated in `BUILD_TOOLING_DOCTRINE.md`.
- No production Swift or `Package.swift` changes.
