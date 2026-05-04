# Research: Rich Markdown Rendering for TD Artifacts

## Overview
This research explores enhancing the `anigma_artifact_render.py` tool to support rich Markdown features (YAML frontmatter, Mermaid diagrams, tables) in generated TD artifacts, enabling better human readability in GitHub, Obsidian, and Quartz without making these views canonical.

## Capability Mapping
| Feature | Implementation | Notes |
|---|---|---|
| YAML Frontmatter | `---` blocks at top of Markdown | Add fields for `task_id`, `status`, `build_status`, `tags`. |
| Mermaid Diagrams | ````mermaid ... ```` blocks | Use JSON `diagrams` array to store `type`, `title`, `content`. |
| Validation Tables | Markdown grid tables | Use `validationResults` JSON data. |
| Changed-File Tables | Markdown grid tables | Use `changedFiles` JSON data. |
| Status Blocks | Plain Markdown / Callouts | Use `buildStatus` to emit simple indicators. |
| Artifact Backlinks | Markdown links | Generate links to canonical JSON and bundle paths. |

## Implementation Strategy
1.  **Schema Update**: Extend `td-proof-artifact.schema.json` to include optional fields for `frontmatter`, `diagrams`, and improved rendering metadata.
2.  **Renderer Enhancement**: Update `render_proof` in `Scripts/anigma_artifact_render.py` to:
    - Emit YAML frontmatter.
    - Render tables from JSON lists.
    - Render mermaid blocks if diagrams are provided.
    - Link back to canonical files.
3.  **Smoke Proof Artifact**: Update smoke JSON to include a Mermaid diagram, frontmatter, and extended metadata.
4.  **Validation**: Verify rendered Markdown against requirements (frontmatter, mermaid, generated-from notice).

## Risk Assessment
- **Low**: Deterministic Markdown rendering.
- **Medium**: Breaking compatibility with existing proof files if renderer logic is too rigid.
- **Critical**: Must NOT modify production code or Package.swift.

## Implementation Sequence
1.  Extend schema.
2.  Update renderer.
3.  Update smoke JSON.
4.  Smoke test generation and verify output.
