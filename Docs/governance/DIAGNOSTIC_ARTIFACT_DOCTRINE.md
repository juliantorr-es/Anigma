# Diagnostic Artifact Doctrine

**Status**: Active  
**Applies to**: All Anigma diagnostic tools, agents, and automated workflows.

## 1. Core Principles
The diagnostic harness (`Scripts/anigma_diagnose.py`) is the **canonical entrypoint** for task evidence collection. It ensures that every architecture-sensitive change is backed by reproducible, deterministic evidence.

## 2. Artifact Lifecycle
Every task lifecycle must include:
1. **Baseline**: Captured before any code is modified.
2. **Validation**: Captured after implementation to prove correctness and build status.
3. **Review**: Final bundle generated to facilitate peer or agent review.

## 3. Storage and Naming
- **Location**: All raw artifacts must be stored under `.build/anigma-diagnostics/tasks/<task-id>/<commit-hash>/<phase>/`.
- **Naming**: Use stable, lowercase names (e.g., `artifact-manifest.json`, `diagnostic-summary.md`).
- **Persistence**: Generated artifacts stay in the `.build` directory unless explicitly promoted to `Docs/proofs/` for long-term record keeping.

## 4. Determinism and Safety
- **No Timestamps**: Artifacts must not contain wall-clock timestamps or nondeterministic UUIDs by default to ensure diff-ability.
- **Relative Paths**: All file paths in summaries and JSON bundles must be repo-relative.
- **Read-Only**: Diagnostic tools must not modify production Swift code or `Package.swift` unless part of an explicit repair mode.
- **No Automatic Commits**: Tools must not stage or commit files without explicit user instruction.

## 5. Build Status Classification
- **FAILED**: Nonzero exit code from validation command.
- **CLEAN**: Exit code 0 and zero warnings detected in command log.
- **CONTAMINATED**: Exit code 0 but with one or more warnings (case-insensitive "warning:" match).
- **PASSED**: Exit code 0 but warning status was not verified (legacy or external).

## 6. Local CLI Tool Integration
The diagnostic harness prioritizes fast, local CLI tools for evidence collection:
- **git**: Mandatory for status, diff, and file change detection.
- **rg**: Mandatory for efficient pattern scanning (forbidden findings).
- **python3**: Mandatory for harness execution and Python script validation (`py_compile`).
- **shellcheck**: Optional but recommended for shell script validation.
- **jq**: Optional but recommended for JSON post-processing.
- **swift**: Mandatory for package graph snapshots and build validation.

Missing required tools result in a **FAILED** diagnostic state for affected modes.

## 7. Diagnostic Index
The diagnostic harness maintains a lightweight JSONL index of diagnostic bundles at `.build/anigma-diagnostics/index.jsonl`.
- **Purpose**: Artifact locator and review aid.
- **Source of Truth**: Underling generated bundle artifacts and curated Docs proof artifacts. The index is derivative.
- **Querying**: Use `python3 Scripts/anigma_diagnose.py index` to list and filter diagnostic history.

## 8. Docs Artifact Validation
JSON, CSV, and YAML files under `Docs/` are **first-class documentation artifacts**.
- **Validation**: The harness parses and summarizes these artifacts whenever they are changed or during review mode.
- **Classification**:
    - **CLEAN**: All discovered Docs artifacts parse successfully.
    - **CONTAMINATED**: Parse succeeds but structural warnings exist (e.g., empty CSV, ragged rows).
    - **FAILED**: Any parse failure detected.
- **High-Risk**: Changes to schemas, registries, and manifests are flagged for elevated review.

## 9. Curated Proofs
While `.build` contains the raw evidence, `Docs/proofs/` should contain **curated summaries** and pointers to the raw data. Do not dump multi-megabyte log files into the `Docs/` directory.