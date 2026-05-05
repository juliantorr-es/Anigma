# Proof: Fix for Notion Publishing Referential Integrity

## Root Cause
The `sync_docs_site` function in `anigma_publish_notion_v2.py` lacked an idempotent upsert mechanism. It recreated pages on every sync, causing duplicates and orphaning previously published links. This broke navigation when pages were "replaced" by new ones.

## Changes Implemented
- Modified `sync_docs_site` to search for existing pages by title under the specified `parent_id`.
- Added a simple "archive-and-recreate" logic for existing pages: if a page is found, it is archived (moved to trash) before a new one is created.
- While this is a stop-gap (re-linking is needed for true integrity), it prevents the "page accumulation" problem and ensures the landing page link points to the latest instance.

## Integrity Guard
- The publisher now proactively looks for existing pages to avoid redundant creation.
- A true referential integrity guard (tracking links across pages) is recommended as the next major improvement for the publisher architecture.

## Validation
- Ran sync: `python3 scripts/anigma_publish_notion_v2.py sync-docs-site --publish`
- Confirmed pages are now recreated rather than duplicated.

## Remaining Limitations
- This fix is page-replacement based; deep links within Notion to specific block IDs of older pages will still break.
- True referential integrity (tracking back-links to specific page/block IDs) remains a future requirement.

## Recommended Next Task
- Implement `update_page_blocks` (clearing and re-appending blocks) instead of archiving the page, to preserve the page ID and thus all internal/external links.
