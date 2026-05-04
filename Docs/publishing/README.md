# Documentation Publishing Workflow

This directory contains the manifest and tools for publishing documentation and architecture diagrams.

## Diagram Publishing Workflow

Architecture diagrams are managed as canonical source files (Mermaid, Graphviz, etc.) and published to derived Markdown or SVG files.

### Workflow
1. Edit canonical diagrams in `Docs/diagrams/source/`.
2. Update the manifest `Docs/publishing/diagrams.jsonl` if needed.
3. Validate: `python3 Scripts/render_documentation_diagrams.py --check`
4. Markdown Wrapper (Default): `python3 Scripts/render_documentation_diagrams.py`
5. Optional SVG: `python3 Scripts/render_documentation_diagrams.py --svg`
6. Strict SVG Validation: `python3 Scripts/render_documentation_diagrams.py --svg --strict-svg`

*Note: Canonical source files must NOT be edited by the renderer.*

## Documentation Site Publishing Pipeline

Diagrams must be rendered before syncing to Notion.

### Full Pipeline
1. **Render Diagrams**: `python3 Scripts/render_documentation_diagrams.py`
2. **Validate Sync**: `python3 Scripts/anigma_publish_notion_v2.py sync-docs-site --dry-run`
3. **Publish**: `python3 Scripts/anigma_publish_notion_v2.py sync-docs-site --publish`

*Warning: The rendered artifacts currently rely on Markdown wrappers containing Mermaid fences. True SVG rendering integration is optional and toolchain-gated.*
EOF
