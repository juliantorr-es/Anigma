# [P1] Add documentation diagram generation scripts

**Parent**: Governance
**Status**: Ready

## Purpose
Add scripts to render Mermaid, Graphviz, and Structurizr diagrams into `Docs/diagrams/rendered/`.

## Candidate Scripts
- `Scripts/docs/render_mermaid.sh`
- `Scripts/docs/render_graphviz.sh`
- `Scripts/docs/render_structurizr.sh`
- `Scripts/docs/validate_json_schemas.sh`

## Acceptance Criteria
- Source diagrams remain canonical.
- Rendered SVGs are reproducible.
- Missing optional tools produce clear messages.
- README/docs explain how to regenerate diagrams.

## Non-goals
- No public website generation.
- No bulk architecture diagram rewrite.
- No generated SVG commit unless source + command documented.
