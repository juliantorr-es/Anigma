# App Store Build Profile

## Purpose
This document defines the canonical build profile for packaging Anigma for App Store or proprietary commercial distribution. It guarantees that no copyleft code (GPL, AGPL, LGPL) accidentally taints the proprietary release while ensuring that all distributable sidecars (e.g., PDFium) meet strict notice requirements.

## Required Environment
- `ENABLE_FFMPEG_LINKING=0` (or strictly unset).

## Forbidden Runtime Inclusions
- FFmpeg libraries (`libavcodec`, `libavformat`, `libavutil`, `libswscale`, `libswresample`).
- `ffmpeg` or `ffprobe` executable binaries.
- Any GPL/AGPL licensed runtime sidecars or dependencies.
- PDFium library (`libpdfium`) and `PDFSidecarExecutable` (excluded from App Store alpha profile).

## PDFium Policy
- PDFium is **excluded by default** from the App Store alpha profile.
- PDFKit is the supported App Store PDF backend.
- PDFium remains optional for non-App-Store or advanced builds, and may be reviewed for App Store inclusion later ONLY when exact binary provenance and transitive notices are complete.

## Preferred Native Backends
The App Store profile expects the following Apple-native frameworks to handle tasks that might otherwise fall to C/C++ sidecars:
- **Media & Audio:** `AVFoundation`, `VideoToolbox`, `AudioToolbox`, `CoreMedia`, `Metal`, `MetalPerformanceShaders`.
- **Image & PDF:** `CoreGraphics`, `PDFKit`, `ImageIO`.
- **Compute:** `Accelerate`.

## Validation
Before any alpha, TestFlight, or App Store distribution, the build environment must successfully pass:
```bash
python3 Scripts/validate_release_readiness.py
```

## Failure Conditions
A release candidate is INVALID and MUST NOT BE SIGNED if:
- `ENABLE_FFMPEG_LINKING` evaluates to true.
- `THIRD_PARTY_INVENTORY.yaml` marks a GPL/AGPL dependency as `distributed_in_app_store_build: true` without an explicit, approved separate commercial license.
- PDFium is bundled but still marked as `needs_review` regarding its version or missing transitive notices.
