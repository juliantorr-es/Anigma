# Alpha Release Readiness Checklist

## Overview
This document tracks the automated and manual gates required to certify an Anigma alpha release candidate for distribution (including App Store Connect, TestFlight, or public binary releases).

## Automated Gates (Unified Validator)
The following must pass via `python3 Scripts/validate_alpha_release_readiness.py`:
- [x] **Architecture & Build Profile**: Validated via `validate_app_store_build_profile.py`.
- [x] **Dependency Boundaries**: Validated via `validate_app_store_dependency_boundaries.py`.
- [x] **Public Project Readiness**: Validated via `validate_public_project_readiness.py`.
- [x] **Publisher Integrity**: Validated via `validate_notion_publisher.py`.
- [x] **Artifact Existence**: All dashboards, changelogs, profiles, inventories, and key proof tombstones must exist.

## Known Exclusions for App Store Alpha
To pass the automated boundaries, the alpha release expressly EXCLUDES:
- **FFmpeg (`libav*`)**: Forbidden due to LGPL/GPL dynamic linking conflicts. (`ENABLE_FFMPEG_LINKING=0` required).
- **PDFium**: Forbidden pending complete provenance and transitive notice aggregation.
- **GPL/AGPL Runtime Dependencies**: Forbidden unless separately approved/licensed.

*The native fallbacks for the alpha profile are `AVFoundation` and `PDFKit`.*

## Known Unsupported Features
The following features are known limitations of the current alpha baseline:
- Structural table mutations (resizing, row deletion) during Notion documentation publishing.
- Toggles, callouts, and nested list mutations during Notion documentation publishing.
- Advanced media encoding requiring FFmpeg.
- Advanced PDF operations requiring PDFium.

## Manual Review Items (Operator Task)
Before cutting the final release archive, the operator must verify:
- [ ] **Privacy Strings & Entitlements**: Ensure `Info.plist` covers all required permissions (Camera, Microphone, Photo Library, Network) accurately.
- [ ] **App Store Metadata**: Review descriptions, keywords, and categorizations.
- [ ] **Icon & Screenshots**: Ensure all App Store visual assets are present and correctly sized.
- [ ] **TestFlight Notes**: Document what to test for beta users.
- [ ] **License/Notice Review**: Verify `THIRD_PARTY_NOTICES.md` accurately reflects the final bundled artifacts.
- [ ] **Contributor Policy**: Ensure `CONTRIBUTING.md` and dual-licensing mandates are intact.

## Current Alpha Readiness Status
- **Status**: `needs_review` (Awaiting manual operator tasks; automated gates are `ready`).
