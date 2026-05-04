# Publishing Capabilities

**Document ID:** PUBLISHING-INDEX-2025-001
**Version:** 1.0
**Status:** ACTIVE
**Owner:** Architecture

---

## Overview

This directory contains documentation and manifests for Anigma's publishing capabilities, including Notion integration and future publishing targets.

---

## Current Publishing Status

### Notion Publishing

**Status:** Functional (Internal Token mode)

- **Doctrine:** `Docs/publishing/notion.md` - Boundary principles for Notion publishing
- **Current Implementation:**
  - `Scripts/notion/client.py` - Notion API primitives
  - `Scripts/anigma_publish_notion_v2.py` - Publisher with schema bootstrap
- **Manifest:** `Docs/publishing/notion-docs-site-manifest.yaml` - Curated artifact list for Notion sync

**Mode:**
- Internal Integration tokens only (no OAuth yet)
- Idempotent upsert operations
- Dry-run capable (double-run safe)
- Git remains source of truth; Notion is presentation mirror

### Future Publishing Capabilities

See `Docs/roadmap/future-capabilities/architecture-operations-capability.md` for the roadmap of:
- Notion OAuth 2.0 support
- Obsidian vault publishing
- Static site generation
- Filesystem publishing
- Agent context export

---

## Documents

| Document | Purpose | Status |
|---|---|---|
| [notion.md](./notion.md) | Notion publishing doctrine | **CANONICAL** |
| [notion-docs-site-manifest.yaml](./notion-docs-site-manifest.yaml) | Notion sync manifest | **CURATED** |

---

## Quick Start

### Notion Setup

```bash
# Set environment variables
export NOTION_TOKEN="your_internal_integration_token"
export NOTION_DATABASE_ID="your_database_id"

# Run publisher (dry-run first)
python3 Scripts/anigma_publish_notion_v2.py --dry-run

# Then live run
python3 Scripts/anigma_publish_notion_v2.py
```

### Schema Bootstrap

```bash
export NOTION_COCKPIT_PARENT_PAGE_ID="your_cockpit_page_id"
python3 Scripts/anigma_publish_notion_v2.py bootstrap-schema
```

---

## Publishing Principles

1. **Presentation Only:** Notion displays the graph; Anigma owns the graph.
2. **Read-Only Mirror:** Notion pages reflect Git state, never vice-versa.
3. **No Network Bleed:** All harness execution works without NOTION_TOKEN.
4. **Non-Canonical:** If Notion disagrees with Git, Git is the truth.
5. **Idempotent:** Double-run produces same results.

---

## Future Architecture

The `ArchitectureOperationsCapability` (defined in the roadmap) will eventually provide:

- **PublishingCapability:** Governed publishing to Notion and other targets
- **IntegrationAuthCapability:** Auth management (internal tokens → OAuth)
- **DocumentationRenderCapability:** Render evidence to presentation formats
- **PublishingContracts:** Portable DTOs and protocols for all publishing

**Note:** Implementation is blocked until `anigma-app` Debug builds reliably.

---

## See Also

- [Architecture Operations Capability Roadmap](../../roadmap/future-capabilities/architecture-operations-capability.md)
- [Publishing Doctrine](./notion.md)
- [Notion Sync Proof](../../proofs/notion-current-documentation-cockpit-sync.md)
