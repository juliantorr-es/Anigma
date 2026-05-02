# Document Artifact Types Doctrine
Status: Canonical

## Purpose
Define how Anigma uses documentation-as-code formats beyond Markdown and CSV.

## Core Rule
Use the smallest artifact type that preserves meaning. Markdown explains, CSV tabulates, JSON structures, Schema validates, YAML manifests, Mermaid/Graphviz/Structurizr diagram architecture.

## Format Roles
- **.md**: Doctrine, rationale, handoffs, reports, proofs.
- **.csv**: Audits, inventories, validator results, benchmarks.
- **.json**: Machine-readable metadata, runtime receipts, tool manifests.
- **.schema.json**: JSON Schema Draft 2020-12 validation.
- **.yaml**: Human-edited manifests, roadmaps, configurations.
- **.mmd**: Mermaid flowcharts/workflows.
- **.dot**: Graphviz dependency/tier graphs.
- **.dsl**: Structurizr architecture models.
- **.svg**: Rendered visuals (derived from source).

## Canonical Source Rule
For diagrams: source (`.mmd`, `.dot`, `.dsl`) is canonical; `.svg` is derived.

## Directory Layout
- `Docs/governance/`: Doctrines.
- `Docs/schemas/`: Validation contracts.
- `Docs/manifests/`: Human-editable configs.
- `Docs/data/`: Stable datasets.
- `Docs/diagrams/`: Source and rendered diagrams.
- `Docs/proofs/`: Evidence artifacts.

## Git and Review Rules
Artifact changes must include:
- Source vs. Rendered status.
- Generation mechanism if derived.
- Paired Markdown explanation.
- Task/Proof reference.
