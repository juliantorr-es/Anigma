# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Alpha Release Readiness**: Implemented a unified `validate_alpha_release_readiness.py` gate that aggregates architecture, publisher, dependency, and App Store boundary checks.
- **App Store Build Profile**: Added a strict boundary policy (`APP_STORE_BUILD_PROFILE.md`) ensuring high-risk dependencies like FFmpeg and PDFium are explicitly excluded from App Store builds to guarantee licensing compliance.
- **Public-Project Readiness**: Established dependency tracking, dashboard reporting, and dual-licensing contributor policies.
- **Governance & Reporting**: Added structured JSON reports (`SyncReport`) and tombstone logging for all destructive actions to ensure an auditable publishing pipeline. Added `--report-json` and `--strict` flags.

### Changed
- **Notion Publisher Stabilization**: Transitioned the documentation publisher from page recreation to in-place page updating with block-diffing capabilities. Granular ID stability is now preserved for Paragraphs, Headings, Code, Lists, and Table Cells.
- **Publisher Safety**: Structural table mutations, list restructuring, and unverified deletions are now strictly blocked to preserve referential integrity.

### Known Limitations
- Notion API's non-transactional batching means publisher interruptions may result in partially updated pages.
- Structural edits inside tables (append row, delete row, change column count) currently require a page-level fallback sync.
