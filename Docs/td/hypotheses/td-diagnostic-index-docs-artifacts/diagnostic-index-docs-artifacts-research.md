# Research: Diagnostic Index and Docs Artifact Validation

## Overview
This document details the strategy for integrating a JSONL index and Docs artifact validation into the Anigma diagnostic harness (`Scripts/anigma_diagnose.py`).

## Capability Mapping
| Feature | Current State | Desired State | Implementation | Risk |
|---|---|---|---|---|
| index.jsonl | Missing | JSONL index of all bundles | Append/upsert a line in `.build/anigma-diagnostics/index.jsonl` on every harness execution. | Low |
| Docs JSON discovery | Ad hoc | Categorized discovery | Scan `Docs/` for `.json` files and categorize by subpath (schemas, proofs, etc.). | Low |
| Docs CSV discovery | Missing | Categorized discovery | Scan `Docs/` for `.csv` files and categorize. | Low |
| Docs YAML discovery | Missing | Categorized discovery | Scan `Docs/` for `.yaml`/`.yml` files and categorize. | Low |
| Docs artifact validation summary | Missing | Detailed bundle output | Emit `docs-artifacts/` folder with JSON/MD reports on validation status. | Low |
| review bundle integration | Basic | Docs section included | Add "Docs Artifact Validation" section to `review-bundle.md`. | Low |
| diff mode integration | Basic | Docs delta reporting | Report changes to Docs JSON/CSV/YAML in `diff-risk-summary.md`. | Low |
| schema update | Basic | Index and Docs fields | Create `anigma-diagnostic-index.schema.json` and update `anigma-diagnostic-bundle.schema.json`. | Low |
| doctrine update | Active | Index/Docs principles | Update `DIAGNOSTIC_ARTIFACT_DOCTRINE.md` and `BUILD_TOOLING_DOCTRINE.md`. | Low |

## Discovery Logic
- **Docs JSON**: `Docs/schemas/*.json`, `Docs/**/schemas/*.json`, `Docs/proofs/**/*.json`, `Docs/research/**/*.json`, `Docs/td/**/*.json`, `Docs/manifests/**/*.json`.
- **Docs YAML**: `Docs/td/**/*.yaml`, `Docs/manifests/**/*.yaml`, `Docs/governance/**/*.yaml`, `Docs/**/*.yml`.
- **Docs CSV**: `Docs/**/*.csv`.

## Validation Strategy
- **JSON**: `json.load`. Check for `$schema`.
- **CSV**: `csv` module. Check for headers, row counts, duplicates, ragged rows.
- **YAML**: `yaml.safe_load` if PyYAML available.

## Risk Classification Updates
- **Critical**: `Docs/td/td-task-registry.yaml`, `Docs/schemas/*.json`, `Docs/governance/*.yaml`, `Docs/manifests/*.yaml`.
- **High**: `docs_schema`, `docs_manifest`, `docs_registry`.
- **Medium**: `docs_json`, `docs_csv`, `docs_yaml`.
- **Low**: Generated `.build` artifacts.

## Implementation Sequence
1.  **Discovery Helpers**: Functions to find and categorize Docs artifacts.
2.  **Validators**: Functions for JSON/CSV/YAML parsing and sanity checks.
3.  **Bundle Output**: Logic to write to `docs-artifacts/`.
4.  **JSONL Indexing**: Logic to append records to `index.jsonl`.
5.  **Review/Diff Updates**: Integrating findings into reports.
6.  **Schemas/Doctrine**: Updating documentation and schemas.
7.  **Validation**: Smoke tests and proof artifact.
