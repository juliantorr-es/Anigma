# Polytropos Unified Media Substrate — Phase 0 Architecture

**Date**: 2026-04-26  
**Status**: 🔴 CRITICAL FOUNDATION REVISION (UNIFIED MEDIA)  
**Scope**: Media-wide substrate (Phase 0) — Video, Audio, Images  

---

## The Unified Doctrine

Anigma governs the memory lifecycle, transforms, and fallback policies. Apple owns the codec engines.

- **Video**: True Zero-Copy (Surface continuity).
- **Audio**: Bounded-Copy / Copy-Accounted (Buffer continuity).
- **Images**: Zero-copy or Low-copy (Surface/Texture continuity).

---

## Phase 0: Media-Wide Substrate

**This must be built FIRST, before any MediaDecodeContract or executor.**

### Core Types

```swift
// === REFERENCES ===

public enum MediaReference: Codable, Sendable, Hashable {
    case videoFrame(FrameReference)
    case audioBuffer(AudioBufferReference)
    case imageSurface(ImageSurfaceReference)
    case packetStream(PacketStreamReference)
    case artifact(ArtifactReference)
}

/// Durable file/blob artifact (long-lived, versioned, auditable)
public struct ArtifactReference: Codable, Sendable, Hashable {
    public let id: ArtifactID
    public let mediaType: String
    public let size: UInt64
    public let hash: SHA256Digest
    public let createdAt: Timestamp
}

/// Live zero-copy video frame surface
public struct FrameReference: Codable, Sendable, Hashable {
    public let id: FrameID
    public let memoryClass: VideoMemoryClass
    public let pixelFormat: PixelFormat
    public let dimensions: Dimensions
    public let colorSpace: ColorSpaceDescriptor
    public let timebase: Timebase
    public let pts: Int64
    public let surfaceToken: SurfaceToken
    public let lifetime: MediaLifetime
    public let materializationPolicy: MaterializationPolicy
}

/// Live audio buffer reference (bounded-copy accounted)
public struct AudioBufferReference: Codable, Sendable, Hashable {
    public let id: AudioBufferID
    public let memoryClass: AudioMemoryClass
    public let sampleFormat: AudioSampleFormat
    public let sampleRate: Double
    public let channelLayout: ChannelLayoutDescriptor
    public let frameCount: UInt64
    public let timeRange: MediaTimeRange
    public let lifetime: MediaLifetime
    public let materializationPolicy: MaterializationPolicy
}

/// Live still-image surface reference
public struct ImageSurfaceReference: Codable, Sendable, Hashable {
    public let id: ImageSurfaceID
    public let memoryClass: ImageMemoryClass
    public let pixelFormat: PixelFormat
    public let dimensions: Dimensions
    public let colorSpace: ColorSpaceDescriptor
    public let orientation: ImageOrientation
    public let materializationPolicy: MaterializationPolicy
}

// === MEMORY CLASSES ===

public enum VideoMemoryClass: String, Codable, Sendable {
    case ioSurface        // Cross-framework pixel surface
    case cvPixelBuffer    // VideoToolbox/CoreVideo frame buffer
    case metalTexture     // MTLTexture (GPU-resident)
}

public enum AudioMemoryClass: String, Codable, Sendable {
    case compressedPacketStream
    case avAudioPCMBuffer
    case audioBufferList
    case ringBuffer
    case mmapPCM
    case metalBuffer
}

public enum ImageMemoryClass: String, Codable, Sendable {
    case cgImage
    case ciImage
    case cvPixelBuffer
    case ioSurface
    case metalTexture
}

// === LIFETIME & POLICY ===

public enum MediaLifetime: String, Codable, Sendable {
    case transient        // Operation-local
    case cached           // Reusable
    case persistent       // Cross-boundary
}

public enum MaterializationPolicy: String, Codable, Sendable {
    case preferInPlace    // Keep in managed memory
    case allowCopy       // Bounded copy allowed
    case mustMaterialize // Force CAS blob creation
}

// === PROOFS ===

public struct MediaCopyProof: Codable, Sendable {
    public let mediaID: String
    public let kind: MediaKind
    public let copiedBytes: UInt64
    public let materializationEvents: [MaterializationEvent]
    public let fences: [FenceReceipt]
    
    public var isSaturated: Bool {
        copiedBytes == 0 && materializationEvents.isEmpty
    }
}
```

### SaturatedMemoryAuthority (The Keystone)

The overarching governor for all media memory.

#### SurfaceAuthority (Video/Images)
Owns `CVPixelBuffer`, `IOSurface`, and `MTLTexture` views.

#### AudioBufferAuthority (Audio)
Owns `AVAudioPCMBuffer`, `AudioBufferList`, and ring buffers.

```swift
public actor AudioBufferAuthority: Sendable {
    public func registerPCMBuffer(
        _ buffer: AVAudioPCMBuffer,
        descriptor: AudioMetadata,
        owner: ExecutorID
    ) async throws -> AudioBufferReference
    
    public func makeBufferLease(
        for buffer: AudioBufferReference
    ) async throws -> AudioBufferLease
}
```

### MaterializationGate

Governs all forced copies across all media types.

---

## Revised Implementation Order (WITH PHASE 0)

### Phase 0: Media-Wide Substrate (FIRST)

**Milestones**:
- **Phase 0A**: Types and linter only (MediaReference, Authority interfaces).
- **Phase 0B**: SaturatedMemoryAuthority in-memory registry (Universal IOSurface slabs).
- **Phase 0C**: Real CVPixelBuffer and AudioBuffer registration and assertion.
- **Phase 0D**: CVMetalTextureCache and AudioBuffer lease proofs.

**Acceptance**:
- ✓ No raw `Data/[UInt8]/[Float]` media payloads in hot path (linter enforced).
- ✓ Video: Decode produces IOSurface-backed CVPixelBuffer.
- ✓ Audio: Decode produces managed PCM buffer (no unapproved array copies).
- ✓ Every copy passes MaterializationGate.
- ✓ MediaCopyProof reports copiedBytes accurately.
- ✓ FFmpeg/Subprocess fallback is materialization boundary.
- ✓ Tests pass.

### Phase 1: Unified Contracts & Registry

**Deliverables**:
- [ ] Unified `MediaContract` protocol.
- [ ] Video, Audio, and Image contract families.
- [ ] MediaBackendRegistry selector logic (MediaKind-aware).
- [ ] Mock executors for testing.

... [Rest of phases remain consistent with comprehensive spec] ...
act families.
- [ ] MediaBackendRegistry selector logic (MediaKind-aware).
- [ ] Mock executors for testing.

... [Rest of phases remain consistent with comprehensive spec] ...
