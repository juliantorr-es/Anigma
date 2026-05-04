# Research: Diagnostic Harness CLI Integration

## Overview
This document details the findings from the research phase of integrating local CLI tools into the Anigma diagnostic harness (`Scripts/anigma_diagnose.py`).

## Current State
- **Harness:** `Scripts/anigma_diagnose.py` (85 lines) is a minimal wrapper for `baseline`, `validate`, and `review` modes.
- **Graph Audit:** `Scripts/anigma_package_graph_audit.py` is mature and provides `snapshot` and `alignment-matrix` commands.
- **Readiness Scripts:** Bash scripts like `test_backend_readiness.sh` use simple grep for error detection and emit custom JSON receipts.
- **Doctrine:** `DIAGNOSTIC_ARTIFACT_DOCTRINE.md` defines the requirement for deterministic evidence bundles.
- **Schema:** `anigma-diagnostic-bundle.schema.json` provides a target for bundle validation.

## Tool Availability
| Tool | Status | Path | Required? |
|---|---|---|---|
| git | FOUND | /usr/bin/git | Yes |
| swift | FOUND | /usr/bin/swift | Yes |
| python3 | FOUND | /usr/bin/python3 | Yes |
| jq | FOUND | /usr/bin/jq | Yes |
| rg | FOUND | /opt/homebrew/bin/rg | Yes |
| fd | FOUND | /opt/homebrew/bin/fd | No |
| shellcheck | FOUND | /opt/homebrew/bin/shellcheck | No |
| td | FOUND | /Users/user/go/bin/td | No |

## Capability Mapping
| Capability | Current State | Desired State | Tool(s) | Required? | Fallback | Implementation Plan |
|---|---|---|---|---|---|---|
| git status capture | Partial | Full log | git | Yes | - | capture `git status` output |
| git diff patch capture | Missing | Full patch | git | Yes | - | capture `git diff HEAD` |
| git diff stat capture | Missing | Summary stat | git | Yes | - | capture `git diff --stat HEAD` |
| changed files JSON | Missing | Categorized JSON | git, python3 | Yes | - | use `git diff --name-only` + python categorization |
| build command log | Basic | Full with timing | python3 | Yes | - | improve `run_cmd` to capture timing and stdout/stderr |
| warning extraction | Ad hoc grep | Standardized rg | rg, python3 | Yes | python grep | use `rg -i "warning:"` |
| error extraction | Ad hoc grep | Standardized rg | rg, python3 | Yes | python grep | use `rg -i "error:"` |
| build status | Binary (P/F) | CLEAN/FAILED/CONTAMINATED | python3 | Yes | - | categorize based on exit code and warning count |
| graph snapshot | Integrated | Hardened pathing | python3 | Yes | - | call `anigma_package_graph_audit.py snapshot` |
| alignment matrix | Integrated | Hardened pathing | python3 | Yes | - | call `anigma_package_graph_audit.py alignment-matrix` |
| forbidden pattern scan| Missing | rg-based scan | rg | Yes | python scan | scan for TD artifacts, forbidden imports, native handles |
| script validation | Missing | shellcheck/py_compile | shellcheck, python3 | Yes | informational | hook into `validate` and `review` modes |

## Risk Assessment
- **Low Risk:** Changing diagnostic output formats.
- **Medium Risk:** Refactoring `anigma_diagnose.py` to be more robust.
- **Critical Requirement:** Do NOT modify production Swift code or `Package.swift` architecture.

## Validation Plan
1. Smoke test all modes: `baseline`, `validate`, `review`, `diff`.
2. Verify artifact bundle structure against `anigma-diagnostic-bundle.schema.json`.
3. Check `build-status.json` for correct classification.
4. Verify forbidden findings detection.
