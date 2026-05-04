# Proof: Diagnostic Harness CLI Integration

## Overview
This document proves the successful hardening of the master diagnostic harness (`Scripts/anigma_diagnose.py`) and its integration with local CLI tools.

## Implementation Changes
- **Toolbox Detection**: Added `check_tools()` to detect required (`git`, `swift`, `python3`, `rg`) and optional tools. Emits `tool-availability.json/md`.
- **Bundle Layout**: Standardized output under `.build/anigma-diagnostics/tasks/<task-id>/<commit-hash>/<phase>/`.
- **Git Metadata**: Every phase captures `git status`, `git diff`, and `git diff --stat`.
- **File Categorization**: Added `categorize_changes()` to classify files by risk (`low`, `medium`, `high`, `critical`) and category (`contract_module`, `native_shim`, etc.).
- **Build Status**: Implemented deterministic classification: `CLEAN`, `FAILED`, `CONTAMINATED`, `PASSED`.
- **Forbidden Findings**: Added `scan_forbidden_findings()` to detect:
    - Root-level TD/Review artifacts.
    - Unauthorized `@_exported` imports.
    - Native handles in contract modules.
    - Unverified zero-copy claims.
- **Validation Hooks**: Integrated `shellcheck` (for `.sh`), `py_compile` (for `.py`), and JSON parsing for changed files.
- **Artifact Manifest**: Every phase generates a standardized `artifact-manifest.json` complying with the updated schema.

## Validation Results

### Smoke Tests
A full suite of smoke tests was executed:
1. **Baseline**: `python3 Scripts/anigma_diagnose.py baseline --task-id smoke`
   - ✅ Captured git metadata.
   - ✅ Captured package graph and alignment matrix.
   - ✅ Generated manifest.
2. **Validate (Success)**: `python3 Scripts/anigma_diagnose.py validate --command "ls -la"`
   - ✅ Captured command log.
   - ✅ Classified as `CLEAN`.
   - ✅ Generated manifest with build stats.
3. **Validate (Failure)**: `python3 Scripts/anigma_diagnose.py validate --command "false"`
   - ✅ Captured command log.
   - ✅ Classified as `FAILED`.
4. **Review**: `python3 Scripts/anigma_diagnose.py review`
   - ✅ Scanned for forbidden findings.
   - ✅ Ran validation hooks.
   - ✅ Generated `review-bundle.md`.
5. **Diff**: `python3 Scripts/anigma_diagnose.py diff`
   - ✅ Generated `diff-risk-summary.md`.

### Artifact Manifest Verification
```json
{
  "schema": "anigma.diagnostic_bundle.v1",
  "taskId": "td-diagnostic-harness-cli-integration-smoke",
  "phase": "validate",
  "commitHash": "2679c343",
  "repoRelativeOutputPath": ".build/anigma-diagnostics/tasks/td-diagnostic-harness-cli-integration-smoke/2679c343/validate",
  "generatedArtifacts": [
    "tool-availability.json",
    "tool-availability.md",
    "git-status.txt",
    "git-diff.patch",
    "git-diff-stat.txt",
    "logs/command.log",
    "logs/warnings.txt",
    "logs/errors.txt",
    "logs/build-status.json"
  ],
  "timestamp": "2026-05-04T14:45:46Z",
  "commandResults": {
    "command": "ls -la",
    "exitCode": 0
  },
  "buildStatus": "CLEAN",
  "warningCount": 0,
  "errorCount": 0
}
```

## Doctrine Compliance
The implementation strictly follows:
- `Docs/governance/DIAGNOSTIC_ARTIFACT_DOCTRINE.md`
- `Docs/governance/BUILD_TOOLING_DOCTRINE.md`
- `Docs/schemas/anigma-diagnostic-bundle.schema.json`

## Conclusion
The diagnostic harness is now a robust, CLI-integrated tool that ensures high-quality evidence collection for all Anigma development tasks.
