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
- **CLEAN**: Exit code 0 and zero warnings.
- **CONTAMINATED**: Exit code 0 but with one or more warnings.
- **PASSED**: Exit code 0 but warning status is unknown or unverified.

## 6. Curated Proofs
While `.build` contains the raw evidence, `Docs/proofs/` should contain **curated summaries** and pointers to the raw data. Do not dump multi-megabyte log files into the `Docs/` directory.