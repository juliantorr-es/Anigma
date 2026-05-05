# Publishing Health Dashboard

This dashboard reflects the health and configuration of the Anigma Notion Documentation Publisher.

## Infrastructure Status
- **Sync Model**: Stable Page ID / Opt-In Block Diffing
- **Diagnostic Engine**: Active (`--report-json`)
- **Tombstone Logging**: Active (`Docs/publishing/tombstones.jsonl`)

## Capability Matrix
| Feature | Status | Notes |
| :--- | :--- | :--- |
| Page Creation | ✅ Supported | Reuses existing IDs based on title matching. |
| Page Overwrite | ✅ Supported | Fallback path via `clear_page_blocks`. |
| Block Updates | ✅ Supported | Paragraph, Heading, Code, Lists, Table Cells. |
| Block Deletion | ✅ Gated | Requires dual-flag opt-in (`--block-diff --allow-block-archive`). |
| Structural Mut. | ❌ Blocked | Table resizing, row deletion, list restructuring are prevented. |
