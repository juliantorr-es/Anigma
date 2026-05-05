# Proof: In-Place Documentation Sync

## Root Cause
The previous stop-gap "archive-and-recreate" approach caused page ID churn, orphaning deep links and breaking referential integrity in Notion's navigation.

## New In-Place Update Behavior
- **Lookup**: Pages are now identified by title under the target parent ID using `find_existing_page`.
- **Identity Preservation**: Existing page IDs are kept; content is refreshed by clearing and re-appending blocks.
- **Deduplication**: If duplicates exist, they should be cleaned up manually, but the publisher now targets the first-found canonical page.

## Files Modified
- `scripts/anigma_publish_notion_v2.py`: Refactored `sync_docs_site` and added helper functions.
- `scripts/notion/client.py`: Added `get_block_children` and `delete_block`.

## Validation Results
- Executed two consecutive syncs; verified page ID stability for all documentation pages.
- Confirmed content is refreshed correctly (old blocks are cleared, new ones added).

## Referential Integrity Result
- Page IDs remain stable across syncs.
- Existing internal/external links to these pages are now permanent.

## Remaining Limitations
- **Block ID Churn**: Because blocks are cleared and re-appended, block-level deep links will still churn.
- **Next Task**: Implement diff-based block updating to maintain block-level referential integrity.

## Recommended Next Task
- Transition from block-clearing to a diff-based block update engine.
