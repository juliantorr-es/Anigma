# App Store Sidecar Risk Review

## Overview
This document defines the formal App Store-safe build profile for Anigma. It addresses the distribution and licensing risks associated with sidecar architectures—specifically focusing on **FFmpeg** and **PDFium**.

*Policy Clarification:* Sidecar isolation provides architectural crash boundaries but does not erase licensing obligations. If a sidecar binary is bundled inside the final `.app` submitted to the App Store, it is legally distributed. Its license terms apply to the whole product distribution.

## Dependency Review Findings

### 1. FFmpeg (`libav*`)
- **Usage:** Optional media processing backend, conditionally linked via `ENABLE_FFMPEG_LINKING=1`.
- **Licensing:** Generally LGPL 2.1-or-later, but can easily become GPL if compiled with specific non-free or GPL-only codecs (e.g., x264).
- **App Store Risk:** **HIGH / BLOCKER**. Even if built strictly as LGPL and placed in a sidecar, App Store distribution conflicts with LGPL dynamic linking requirements. Furthermore, any accidental GPL configuration would violate App Store TOS completely.
- **Native Replacement:** `AVFoundation`, `VideoToolbox`, `CoreVideo`, `CoreAudio`, and `CoreMedia`. These are already utilized by the `MediaCore` target.
- **Resolution:** **FFmpeg must be strictly excluded from all official App Store release builds.** The `ENABLE_FFMPEG_LINKING` environment variable must not be set during CI/CD App Store build phases.

### 2. PDFium (`libpdfium.dylib`)
- **Usage:** Used by `PDFSidecarExecutable` for advanced PDF operations.
- **Licensing:** Permissive (BSD 3-Clause / Apache 2.0).
- **App Store Risk:** **MODERATE / MANAGEABLE**. Permissive licenses are App Store compatible, provided that proper notices (including transitive dependencies bundled within PDFium) are included in the app's about page or notice file.
- **Native Replacement:** `PDFKit` (Apple native).
- **Resolution:** `PDFium` may be safely bundled in App Store builds as a sidecar IF AND ONLY IF full binary provenance and all transitive notices are aggregated and presented to the user. For a default App Store profile, falling back to `PDFKit` is preferred to minimize attack surface and binary size, but `PDFium` is not a strict legal blocker like FFmpeg.

## App Store Build Profile

To guarantee a compliant App Store release, the build system must enforce the following profile:

1. **Excluded Flags:**
   - `ENABLE_FFMPEG_LINKING` must be unset or explicitly `0`.
2. **Excluded Sidecars:**
   - `PDFSidecarExecutable` (Optional. If bundled, notices MUST be verified).
   - Any sidecar wrapping FFmpeg.
3. **Required Native Backends:**
   - Media: `AVFoundation`, `VideoToolbox`, `Metal`
   - PDF: `PDFKit` (if PDFSidecar is excluded)
4. **Validation:**
   - The build pipeline must run `Scripts/validate_app_store_dependency_boundaries.py` before code signing.

This profile guarantees that no copyleft code accidentally taints the proprietary iOS/macOS commercial release.
