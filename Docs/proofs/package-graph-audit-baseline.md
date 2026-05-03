# Anigma Package Graph Audit Baseline

## Overview

This document establishes the baseline for Anigma package graph auditing using `Scripts/anigma_package_graph_audit.py`. It documents the execution of the script, its outputs, and the current state of the package dependency graph.

## Source of Truth

- `Docs/governance/BUILD_TOOLING_DOCTRINE.md`
- `Docs/governance/CODE_DOCTRINE.md`
- `Docs/governance/REPO_HYGIENE_DOCTRINE.md`
- `Docs/proofs/swift-tooling-research-doctrine-update.md`
- `Package.swift`

## Script Details

- **Path**: `scripts/anigma_package_graph_audit.py`
- **Subcommands Implemented**:
  - `full`: Run full audit with all outputs
  - `snapshot`: Capture SwiftPM JSON snapshots
  - `violations`: Check violations only
  - `suggest-classifications`: Suggest tier classifications
  - `list-targets`: List all targets
  - `explain-target`: Explain a target
  - `explain-edge`: Explain a dependency edge
  - `why-builds`: Show why a target builds

### Generated Outputs
The script generates the following exact output files in `.build/anigma-graph/`:
- `swiftpm-package-description.json`
- `swiftpm-package-dependencies.json`
- `anigma-target-graph.json`
- `anigma-product-graph.json`
- `anigma-external-package-graph.json`
- `anigma-dependency-violations.json`
- `anigma-unclassified-targets.json`
- `package-graph-classification-suggestions.yaml`
- `anigma-package-graph-audit.md`

## Baseline Execution Results

### Commands Run
```bash
cd /Users/user/Developer/GitHub/Anigma_clean/anigma
python3 ../scripts/anigma_package_graph_audit.py
python3 ../scripts/anigma_package_graph_audit.py --fail-on-violation
```

### Results

| Metric | Value |
|--------|-------|
| Target Count | 223 |
| Product Count | 131 |
| External Package Count | 13 |
| Violation Count | 183 |
| Error Count | 24 |
| Warning Count | 159 |
| Classification Coverage | 28.7% |
| Classified Targets | 64 |
| Unclassified Targets | 159 |
| `--fail-on-violation` Exit Code | 1 |

### Violation Summary

The graph audit now detects **24 error-severity architecture violations** and **159 warning-severity violations**. These are baseline findings and must be triaged separately.

**Top Error Classes**:
- `no_upward_tier_dependency`: e.g. Tier 2 runtime targets depending on Tier 3 NativeShims.
- `no_contract_to_runtime_dependency`: e.g. Tier 1 contract targets depending on Tier 2 runtime.

**Top Warning Classes**:
- `no_unclassified_target`: Currently 159 targets lack an explicit classification in `package-graph-rules.yaml`.

## Validation Commands

### Basic Execution (non-failing mode)
```bash
python3 scripts/anigma_package_graph_audit.py
```
**Expected Exit Code**: 0 (Always exits 0 in default mode, writes outputs)

### Fail-on-Violation Mode
```bash
python3 scripts/anigma_package_graph_audit.py --fail-on-violation
```
**Expected Exit Code**: 1 (Fails because 24 error-severity baseline violations exist)

### JSON Validation
```bash
python3 -m json.tool .build/anigma-graph/anigma-target-graph.json >/dev/null
python3 -m json.tool .build/anigma-graph/anigma-dependency-violations.json >/dev/null
```
**Expected Exit Code**: 0 (valid JSON)

## Tier Inference Rules

Tier classification is **declarative** via `Docs/governance/package-graph-rules.yaml`:

1. **Tier 1 (Contract / Constitutional Layer)**: Portable types, protocols, and policy
   - No dependencies on Tier 2 or Tier 3
   - Only Foundation types and other Tier 1 contracts

2. **Tier 2 (Substrate / Execution Layer)**: Platform capabilities and infrastructure
   - May depend on Tier 1
   - Must NOT depend on Tier 3

3. **Tier 3 (Feature / Daemon / Application Layer)**: End-user capabilities
   - May depend on Tier 1 and Tier 2
   - Must NOT depend on other Tier 3 targets (except via PlatformCore)

## Architecture Preservation

The script **does not modify production code**. It:
- Reads SwiftPM outputs (read-only)
- Parses JSON into normalized graphs (read-only)
- Classifies targets using declarative rules (read-only)
- Reports violations (read-only)
- Emits JSON and markdown outputs (write-only to `.build/`)
