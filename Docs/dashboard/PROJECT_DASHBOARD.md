# Anigma Project Dashboard

Welcome to the Anigma Project Dashboard. This document provides a high-level overview of the repository's current status, ongoing work, and operational health.

## 🚀 Active Work & Priorities
- **P0**: Stabilize the Notion Documentation Publisher block-diffing engine. *(Status: Diagnostic mode complete, safe live execution implemented for table updates)*.
- **P1**: Conduct public-project readiness pass (dashboards, licensing, dependencies). *(Status: Completed)*.
- **P2**: Implement automated Alpha Release Readiness gate. *(Status: Completed)*.
- **Next Up**: Run a full local dry-run release rehearsal generating all required artifacts.

## 📈 Publisher Health
The Anigma Notion Publisher is the core infrastructure for syncing documentation to the public-facing or team-facing Notion site.
- **Current Mode**: Page-level stable sync (Default), Block-level opt-in (`--block-diff`).
- **Safety**: Empty-render guards active, dual-flag required for `ARCHIVE`, strict mode available for CI.
- **Table Support**: Cell text updates only; structural changes explicitly blocked.
- *For detailed publishing telemetry, refer to the most recent generated `report-json` artifact.*

## 🛡️ Release Readiness & Known Risks
- **App Store Viability**: Safe. **FFmpeg** and **PDFium** are explicitly excluded from the App Store alpha profile. PDFKit is the designated native fallback.
- **Licensing**: Dual-licensed under AGPL-3.0 and a Commercial License. Contribution guidelines mandate relicensing preservation.
- **Alpha Readiness**: All automated architecture, dependency, and publishing gates are passing via `Scripts/validate_alpha_release_readiness.py`. Pending manual App Store Connect metadata review.
- **Publisher Partial Sync**: The Notion API's non-transactional nature means mid-batch failures during block diffing could leave a page partially updated.

## 🔗 Quick Links
- [Changelog History](./CHANGELOG_HISTORY.md)
- [Issue Status](./ISSUE_STATUS.md)
- [Publishing Health](./PUBLISHING_HEALTH.md)
- [Operations Guide](../publishing/NOTION_PUBLISHER_OPERATIONS.md)
