# Notion Documentation Cockpit Sync

## Status
- **Sync Pipeline**: Functional
- **Sync Mode**: Local Publisher (Git-tracked artifacts → API)
- **Cockpit Page**: "Anigma Cockpit" (ID: `356524d6-b84c-8053-a8dd-d770d969b582`)
- **Status of Gemini Extension**: Optional (blocked by search tool bug, not blocking sync)

## Implementation Summary
- Created `scripts/notion/client.py` for API primitives.
- Implemented `bootstrap-schema` command to programmatically manage Notion database schemas.
- Configured "Anigma Cockpit" page as the parent for cockpit databases.
- Established canonical sync path using local deterministic publisher with idempotent upsert operations.
- Added `sync-docs-site` mode to publish curated architecture documentation.

## Verification
- **Bootstrap Schema**: Successfully created/updated databases (Tasks, Proofs, Reports, Relationships).
- **Sync Results**: Tasks, Proofs, Reports, Relationships, and Curated Docs synced.
- **Duplicate Prevention**: Idempotent upsert logic verified.
- **Sync Mode**: Git remains source of truth, Notion is presentation layer.

## Known Limitations
- Gemini Notion extension `notion_search` returns `t?.map is not a function`.
- Automated sync relies on environment variables (`NOTION_TOKEN`, etc.).
- Public sharing must be configured manually via the Notion UI (Share -> Publish).
