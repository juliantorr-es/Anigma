# Proof: App Store Build Profile Gate

## Status
- **Implementation**: Completed
- **Changes**: Defined a canonical App Store build profile, introduced an explicit YAML marker file, and created robust validation scripts to enforce dependency boundaries.
- **Goal**: Implement a deterministic local/CI validation lane that proves `FFmpeg` is excluded and `PDFium` is either excluded or fully noticed before any signed release build.

## Files Created
- `Docs/release/APP_STORE_BUILD_PROFILE.md` (Canonical policy defining the profile).
- `Docs/release/app-store-profile.yaml` (Machine-readable marker).
- `Scripts/validate_app_store_build_profile.py` (Script enforcing the profile against `THIRD_PARTY_INVENTORY.yaml` and environment variables).
- `Scripts/validate_release_readiness.py` (Wrapper script triggering all readiness validations).
- `Docs/proofs/tb-2026-05-04-app-store-build-profile-gate.md` (This proof).

## Files Modified
- None. (Validation-only implementation).

## Artifact Integrity
- Runtime Code Changed: No.
- Build/Package Behavior Changed: Validation-only addition. The build itself is untouched.

## App Store Profile Summary
- **FFmpeg (`libav*`)**: Strictly forbidden. `ENABLE_FFMPEG_LINKING` must be false/unset.
- **PDFium**: Excluded by default. Conditionally allowed only if version/source provenance is fully known and all transitive notices are included in `THIRD_PARTY_NOTICES.md`.
- **GPL/AGPL**: Strictly forbidden in runtime sidecars unless explicitly overridden in the inventory with a "separately_licensed" or "approved" status.
- **Native Backends**: `AVFoundation`, `VideoToolbox`, `Metal`, `PDFKit`, etc.

## Gate Results
- **FFmpeg Gate**: **Passed**. `ENABLE_FFMPEG_LINKING` is not forced on, and `FFmpeg` is successfully tracked as `distributed_in_app_store_build: false` in the inventory.
- **PDFium Gate**: **Failed (Expected)**. The script successfully caught that `PDFium` is marked for distribution but its version/URL is `needs_review`, and `THIRD_PARTY_NOTICES.md` still flags its transitive notices as "pending review". This proves the gate correctly blocks a non-compliant release candidate.
- **GPL/AGPL Gate**: **Passed**. No unauthorized copyleft libraries are marked for bundling.

## Validation Commands and Results
- `python3 Scripts/validate_app_store_dependency_boundaries.py` -> Passed successfully.
- `python3 Scripts/validate_public_project_readiness.py` -> Passed successfully.
- `python3 Scripts/validate_notion_publisher.py` -> Passed successfully.
- `python3 Scripts/validate_release_readiness.py` -> Failed successfully (Blocked by the `PDFium` provenance checks in `validate_app_store_build_profile.py`).

## Remaining Release Blockers
- **PDFium Provenance**: To pass the release readiness gate, the exact version and source URL for the vendored `PDFium` binary must be tracked in the inventory.
- **PDFium Notices**: All transitive dependency notices for `PDFium` must be aggregated and listed without "pending" caveats in `THIRD_PARTY_NOTICES.md`. Alternatively, `PDFium` must be marked `distributed_in_app_store_build: false` to skip the check.

## Recommended Next Task
After the App Store build profile gate passes, create an Alpha Release Readiness checklist that combines architecture validation, publisher validation, dependency/license validation, and App Store boundary validation into one pre-release command.
