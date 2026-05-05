# Notion Publisher Operations Guide

The Anigma Notion Publisher provides a reliable, governed mechanism for syncing source documentation to Notion. It supports two primary operational modes: **Default Page Sync** and **Block-Diff Mutation**.

## 1. Default Page Sync (Stable IDs)
This is the default mode when running the publisher without the `--block-diff` flag.
- **Behavior**: Finds the target Notion page by title. If the page exists, its ID is preserved. Its content is refreshed by clearing all child blocks (via paginated block deletion) and appending the freshly rendered blocks.
- **Use Case**: Best for large structural changes, reordering, table resizing, or when block-level diffing is not needed.

## 2. Block-Diff Sync (Opt-In)
This mode provides high-fidelity in-place updates for blocks, preserving block IDs (which stabilizes deep links to specific sections of a document).
- **Activation**: Use the `--block-diff` flag.
- **Dry-Run**: Always run `--block-diff --dry-run` first to diagnose the planned actions. The publisher will output a structured plan without mutating Notion.
- **Live Update**: `KEEP`, `UPDATE`, and `APPEND` actions are executed safely. `UPDATE` is supported for:
  - Paragraphs
  - Headings (H1, H2, H3)
  - Code Blocks
  - Flat Bulleted and Numbered Lists
  - Table Cell Text
- **Blocked Operations**: Structural changes like list nesting modification, table resizing, row reordering, and physical block deletions are blocked to ensure system integrity. If a plan contains ambiguous or unsupported operations, the executor fails closed (or falls back depending on the policy).

## 3. Destructive Archives (Dual Opt-In)
To safely remove blocks that no longer exist in the source documentation, the publisher supports an `ARCHIVE` action.
- **Activation**: Requires both `--block-diff` AND `--allow-block-archive`.
- **Tombstones**: A structured audit log (Tombstone) is emitted to `Docs/publishing/tombstones.jsonl` for every attempted block archive, both in dry-run and live modes.
- **Safety**: Archiving is strictly gated by high-confidence matches. Ambiguous removals fail closed.

## 4. Reporting and Strict Mode
- **`--report-json <path>`**: Outputs a consolidated JSON integrity report (pages, blocks, table actions, destructives, safety result) at the end of the sync cycle.
- **`--strict`**: Instructs the publisher to fail non-zero if any blocked or fallback actions are encountered during block-diff execution, making it suitable for CI validation gates.

## 5. Recommended Workflows
### A. Safe Dry-Run Workflow
```bash
python3 scripts/anigma_publish_notion_v2.py sync-docs-site --block-diff --dry-run --report-json Docs/proofs/generated/report.json
```
*Use this to audit changes before merging a PR.*

### B. Live Update Workflow
```bash
python3 scripts/anigma_publish_notion_v2.py sync-docs-site --block-diff
```
*Use this for regular syncs where documentation has been refined without heavy structural restructuring.*

### C. Archive Workflow
```bash
python3 scripts/anigma_publish_notion_v2.py sync-docs-site --block-diff --allow-block-archive
```
*Use this when removing outdated paragraphs or code blocks.*

### D. CI Validation Workflow
```bash
python3 scripts/anigma_publish_notion_v2.py sync-docs-site --block-diff --dry-run --strict
```
*Use this in CI pipelines to assert that the source documentation changes are fully compatible with the Notion schema and stable ID requirements.*
