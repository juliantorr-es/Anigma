# MediaFingerprintCapsule

Thread-safe perceptual hashing and audio fingerprinting for images and media via Swift actor wrapper over optimized C++ implementations.

## Invariants

- **Actor-isolated**: All hashing operations are `async` and thread-safe via Swift actor isolation
- **Deterministic hashing**: Identical input always produces identical 64/256-bit hash (verified by unit tests)
- **Input validation**: Comprehensive null pointer and dimension checks on all C API calls; errors map to `MediaFingerprintError`
- **Memory safe**: RAII pattern with std::vector cleanup; audio fingerprints limited to max 256 subfingerprints

## Entry Points

- **Image hashing from encoded data**: `hash(imageData:algorithm:) async throws -> PerceptualHash64` — supports JPEG, PNG, BMP, GIF via stb_image decoder; select pHash (DCT, robust to scaling) or dHash (gradient-based, fast)
- **Raw pixel hashing**: `hash(grayscalePixels:width:height:stride:algorithm:) async throws -> PerceptualHash64` — accepts uint8_t grayscale data; useful for video frames or pre-processed images
- **256-bit extended hash**: `hash256(grayscalePixels:...) async throws -> PerceptualHash256` — higher precision matching; 4x64-bit parts with Hamming distance computation
- **Audio fingerprinting**: `fingerprint(audioSamples:sampleRate:) async throws -> AudioFingerprint` — spectral fingerprint from PCM float32; 100ms windows, 32 energy bands per window, up to 256 subfingerprints
- **Similarity search**: `findSimilar(query:in:maxDistance:maxResults:) async -> [SimilarityMatch]` — brute-force Hamming distance matching; returns index, distance, and similarity score (0.0–1.0)
- **Batch processing**: `hashBatch(images:algorithm:) async -> [PerceptualHash64?]` — parallel batch hashing using TaskGroup for multiple images

## Build & Test

```bash
# Build release binary
swift build -c release

# Run all tests
swift test

# Run specific test
swift test MediaFingerprintCapsuleTests

# Build for ARM64 (macOS/iOS)
swift build -c release --arch arm64
```

Tests verify: deterministic hashing, similarity computation, batch operations, audio fingerprinting, error handling.

## Links

- **C ABI Header**: `Sources/MediaFingerprintNative/include/anigma_media_fingerprint.h`
- **Swift Wrapper**: `Sources/MediaFingerprintCapsule/MediaFingerprintCapsule.swift` (537 lines)
- **Native Implementation**: `Sources/MediaFingerprintNative/media_fingerprint.cpp` (577 lines)
- **Unit Tests**: `Tests/MediaFingerprintCapsuleTests/`
- **Related Packages**: PolytroposModule (video ingestion), VizAggregationCapsule (rendering)
- **Minimum Platform**: macOS 14+, iOS 17+
