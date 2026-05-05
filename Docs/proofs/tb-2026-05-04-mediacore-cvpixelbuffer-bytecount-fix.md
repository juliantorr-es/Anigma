# MediaCore CVPixelBufferGetByteCount Fix - tb-2026-05-04

## Starting CVPixelBuffer Error Count
2 errors identified:
1. SurfaceRegistry.swift:60 - cannot find 'CVPixelBufferGetByteCount' in scope
2. MediaSubstrateOrchestrator.swift:243 - cannot find 'CVPixelBufferGetByteCount' in scope

## Error Classification

**CoreVideo API Error**: `CVPixelBufferGetByteCount` is not a valid CoreVideo framework function.

The correct CoreVideo function for retrieving the total data size of a pixel buffer is `CVPixelBufferGetDataSize(pixelBuffer)` which returns a `size_t` representing the total size in bytes.

## Files Modified

1. `anigma/Sources/MediaCore/Substrate/SurfaceRegistry.swift`
2. `anigma/Sources/MediaCore/Orchestrator/MediaSubstrateOrchestrator.swift`

## Chosen Fix

Replaced incorrect `CVPixelBufferGetByteCount(pixelBuffer)` with correct `CVPixelBufferGetDataSize(pixelBuffer)` in both locations.

**Changes**:
```swift
// Before (incorrect API)
let byteCount = CVPixelBufferGetByteCount(pixelBuffer)

// After (correct CoreVideo API)
let byteCount = CVPixelBufferGetDataSize(pixelBuffer)
```

**Rationale**:
- `CVPixelBufferGetByteCount` does not exist in the CoreVideo framework
- The standard CoreVideo API for total pixel buffer size is `CVPixelBufferGetDataSize`
- Both functions return the same type (`size_t`/`Int`) and semantic meaning (total bytes)
- This preserves zero-copy behavior - the function returns metadata, not materialized data

## Package Graph Changes
None. No dependency changes required - CoreVideo is already linked to MediaCore target.

## Validation Commands and Results

```bash
swift build 2>&1 | grep -E "CVPixelBufferGetByteCount|CVPixelBufferGetDataSize"
# Result: No matches - errors resolved

swift build 2>&1 | grep -E "SurfaceRegistry\.swift.*error:|MediaSubstrateOrchestrator\.swift.*error:"
# Result: No matches - files compile cleanly
```

## Remaining Blockers

After this fix, MediaCore compiles past the CVPixelBuffer byte-count errors. Remaining MediaCore errors:
- CoreImageTransformExecutor.swift:3x `ImageSurfaceReference` → `FrameReference` conversion errors (classification: type mismatch between surface reference types)

These are separate from the CVPixelBufferGetByteCount blocker and require different fixes.

## Architecture Statement

- **Native CoreVideo usage remains in allowed media implementation layer**: MediaCore is a Tier 2 media substrate implementation target; CoreVideo usage is appropriate here
- **Portable contracts remain native-type-free**: MediaPipelineContracts, MediaSurface types can remain portable; only MediaCore implementation uses native CoreVideo APIs
- **Zero-copy behavior unchanged**: `CVPixelBufferGetDataSize` returns metadata (size_t) without materializing data; zero-copy semantics preserved
- **No dependency cycles introduced**: No new dependencies added; CoreVideo already linked to MediaCore
- **No @_exported imports introduced**: Only corrected API usage
- **Tier validation remains clean**: Changes stay within Tier 2 MediaCore implementation

## Reference

Apple CoreVideo Framework Documentation:
- `CVPixelBufferGetDataSize(CVPixelBufferRef)` - Returns the total size in bytes of the pixel buffer's data
- `CVPixelBufferGetWidth(CVPixelBufferRef)` - Returns the width in pixels
- `CVPixelBufferGetHeight(CVPixelBufferRef)` - Returns the height in pixels
- `CVPixelBufferGetBytesPerRow(CVPixelBufferRef)` - Returns the bytes per row

All Native CoreVideo calls remain in MediaCore implementation files with proper `import CoreVideo` declarations.
