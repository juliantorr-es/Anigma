# Polytropos Saturated Media Backend — Comprehensive Specification

**Epic**: P0 Polytropos Saturated Media Backend Architecture  
**Status**: ✅ Phase 0 Substrate Architected; Phases 1-5 Planned  
**Duration**: 8-12 weeks (Phase 0: 2-3w blocker; Phases 1-5: 6-9w)  
**Owner**: Anigma Media Infrastructure  

---

## Executive Summary

**Problem**: Current media processing is monolithic (opaque C++ bridge), fragile (FFmpeg linked across 9 targets), slow (CPU-only), and blind (no telemetry). Video, audio, and images are handled inconsistently with hidden data copies.

**Solution**: Polytropos Saturated Media Backend—a governed, unified media architecture for Video, Audio, and Images:
- **Phase 0**: Media-wide substrate (`SaturatedMemoryAuthority`: replacing SurfaceAuthority, AudioBufferAuthority, PacketStreamAuthority)
- **Phases 1-5**: Contracts, executors, kernels, integration, migration
- **Primary path**: Apple-native (VideoToolbox, AudioToolbox, ImageIO, CoreImage, Metal)
- **Fallback**: FFmpeg/Isolated subprocesses (isolated, sandboxed, cost-recorded)
- **Observability**: Saturated telemetry on every operation
- **Guarantee**: Zero-copy (video/image) or bounded-copy (audio) proofs with explicit copy justification

**Impact**:
- Video Decode: 25ms (CPU) → 12ms (VideoToolbox media engine / hardware codec path) = 2.1x faster
- Video Scale: 50ms (CPU) → 8ms (metalGPU) = 6.3x faster
- Audio/Image processing: Bounded-copy accounting, hardware-accelerated transforms
- Architecture: Unified, modular, observable, maintainable
- Resilience: Automatic fallback (lane scheduling)

---

## Part 1: The Problem (Why We Need This)

### Current State (Copy-Heavy, Opaque, Segmented)

```
MediaRenderCapsule.swift
  ↓
MediaRenderNativeBridge.cpp (monolithic)
  ├─ All media logic (video, audio, image) mixed together
  ├─ No unified governance/telemetry
  ├─ No hardware lane awareness
  ├─ Hard-coupled to FFmpeg C API or ImageMagick
  ├─ Manual memory management (leak-prone)
  └─ Hidden copying (no visibility)
  ↓
FFmpeg / ImageMagick libs (fragile linking)
```

**Problems**:
- ❌ Opaque bridge (can't inspect operations)
- ❌ No telemetry (no observability into decode/encode/mix)
- ❌ No hardware lane scheduling (manual, inefficient)
- ❌ Fragile linking (environment-dependent gates)
- ❌ No fallback strategy (one failure breaks everything)
- ❌ Monolithic overhead (can't reuse components)
- ❌ Testing coupled to external libs (hard to mock)

---

## Part 2: The Solution Architecture

### Three-Tier Design

```
┌─────────────────────────────────────────────────┐
│ Tier 1: Contracts (Swift, Pure Semantics)      │
│ • VideoDecodeContract, AudioMixContract, etc.   │
│ • FrameReference, AudioBufferReference          │
│ • ImageSurfaceReference, PacketStreamReference  │
│ • ArtifactReference (durable, storable)         │
│                                                  │
│ POLICY: No I/O, no FFmpeg symbols, pure Swift  │
└────────────────────┬────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
┌──────────────────┐       ┌─────────────────┐
│ Tier 2: Backend  │       │ Tier 2:         │
│ Registry         │       │ Authorities     │
├──────────────────┤       ├─────────────────┤
│ Selects executor │       │ MediaMemoryAuth │
│ based on:        │       │ (Keystone)      │
│ • Media Kind     │       ├─────────────────┤
│ • Codec support  │       │ SurfaceAuth     │
│ • Hardware avail │       │ (video/images)  │
│ • Lane policy    │       │                 │
│ • Memory budget  │       │ AudioBufferAuth │
│                  │       │ (audio buffers) │
│ No external      │       │                 │
│ imports outside  │       │ MaterializGate  │
│ executor         │       │ (approves copy) │
└──────────────────┘       └─────────────────┘
        │
        ├─────────────────────────────────┐
        ▼                                  ▼
┌─────────────────────────────┐  ┌──────────────────────────┐
│ Tier 2b: Executors          │  │ Tier 2c: Leasables       │
│ (Swappable implementations) │  │                          │
├─────────────────────────────┤  ├──────────────────────────┤
│ MockMediaBackend (testing)  │  │ PixelBufferLease         │
│ VideoToolboxExecutor        │  │ AudioBufferLease         │
│ AudioToolboxExecutor        │  │ TextureLease             │
│ ImageIO/CoreImageExecutor   │  │                          │
│ MetalTransformExecutor      │  │ (time-bound, governed)   │
│ FFmpegSubprocessBackend     │  │                          │
│                             │  │ Only obtainable from     │
│ Receive:                    │  │ MediaMemoryAuthority     │
│ • MediaReference (handle)   │  └──────────────────────────┘
│ • Leases                    │
│                             │
│ Return:                     │
│ • MediaReference (new)      │
│ • MediaCopyProof            │
│ • Receipt                   │
└─────────────────────────────┘
        │
        ▼
┌─────────────────────────────┐
│ Tier 3: Platform APIs       │
│ • VideoToolbox, AudioToolbox│
│ • ImageIO, CoreImage        │
│ • Metal compute kernels     │
│ • CVPixelBuffer / IOSurface │
│ • AVAudioPCMBuffer          │
│ • FFmpeg subprocess         │
│ • Accelerate SIMD           │
│                             │
│ Only Tier 2 can call these  │
└─────────────────────────────┘
```

---

## Part 3: Media-Wide Substrate (Phase 0)

### The Core Insight

**Governance and memory lifecycles are unified. Primitives are specialized.**

Anigma governs the memory lifecycle, transforms, and fallback policies. Apple owns the codec engines.

**Universal IOSurface Substrate:** To guarantee absolute zero-copy movement across isolated processors (CPU, GPU, Hardware Media Engines) and isolated process boundaries (e.g. FFmpeg subprocess fallback), the memory substrate dictates that all `CVPixelBuffer`s MUST be explicitly backed by `IOSurface`. This means memory sits rigidly in one location while only references (`IOSurfaceID`s) are passed between the daemon, VideoToolbox, Metal shaders, and sandboxed FFmpeg delegates.

### Unified Reference Model

```swift
public enum MediaReference: Codable, Sendable, Hashable {
    case videoFrame(FrameReference)
    case audioBuffer(AudioBufferReference)
    case imageSurface(ImageSurfaceReference)
    case packetStream(PacketStreamReference)
    case artifact(ArtifactReference)
}
```

### Specialized Paths

#### 1. Video Path (Zero-Copy Surface Continuity)
`ArtifactReference` → `VideoToolboxDecodeExecutor` → `CVPixelBuffer/IOSurface` → `MetalTransformExecutor` → `VideoToolboxEncodeExecutor` → `ArtifactReference`.

#### 2. Audio Path (Bounded-Copy Buffer Continuity)
`ArtifactReference` → `AudioToolboxDecodeExecutor` → `PCMBufferReference` → `AudioMixExecutor/DSP` → `AudioToolboxEncodeExecutor` → `ArtifactReference`.
- **Note**: Audio "zero-copy" is less absolute than video due to smaller size, but all copies are still accounted and no raw `Data` payloads are allowed in hot contracts.

#### 3. Image Path (Zero-Copy or Low-Copy Surface/Texture Continuity)
`ArtifactReference` → `ImageIODecodeExecutor` → `ImageSurfaceReference` → `CoreImage/Metal` → `ImageIOEncodeExecutor` → `ArtifactReference`.

---

## Part 4: The Implementation Roadmap

### Phase 0: Media Substrate (BLOCKER)

**Duration**: 2-3 weeks  
**Milestones**:
- **Phase 0A**: Types and linter only (MediaReference, Authority interfaces).
- **Phase 0B**: SaturatedMemoryAuthority in-memory registry (Surface + Audio + Packet).
- **Phase 0C**: Real CVPixelBuffer and AudioBuffer registration/assertion.
- **Phase 0D**: CVMetalTextureCache and AudioBuffer lease proofs.

**Acceptance Gates**:
1. No raw `Data/[UInt8]/[Float]` media payloads in hot path (linter enforced).
2. Video: Decode produces an explicitly `IOSurface`-backed `CVPixelBuffer`.
3. Audio: Decode produces managed PCM buffer (no unapproved array copies).
4. Every copy passes MaterializationGate.
5. MediaCopyProof reports copiedBytes accurately.
6. FFmpeg/Subprocess fallback is materialization boundary. *Exception:* If the subprocess delegates decoded video to the daemon, it must write the frame to an `IOSurface` and pass the `IOSurfaceID` across the IPC boundary to maintain zero-copy into the Metal compute fabric.

**Status**: 🔴 BLOCKER (all other phases depend on this)

---

### Phase 1: Contracts & Backend Registry

**Duration**: 2-3 weeks  
**Depends on**: Phase 0  
**Deliverables**:
- Unified MediaContract protocol.
- Video, Audio, and Image contract families.
- MediaBackendRegistry selector logic (MediaKind-aware).
- Mock executors for testing.

---

### Phase 2: Apple-Native Backends

**Duration**: 2-3 weeks  
**Depends on**: Phase 1  
**Deliverables**:
- VideoToolbox video backend.
- AudioToolbox/AVFoundation audio backend.
- ImageIO/CoreImage image backend.
- AV1 capability probe.

---

### Phase 3: Transform Engines & DSP

**Duration**: 2-3 weeks  
**Depends on**: Phase 2  
**Deliverables**:
- Metal video scale/format kernels.
- Metal/CoreImage image transforms.
- Audio DSP/resample/mix path.
- Benchmark suite.

---

### Phase 4: Observability & Execution Integration

**Duration**: 1-2 weeks  
**Depends on**: Phase 3  
**Deliverables**:
- ExecutionAuthority wiring.
- SaturatedHeartbeatPacket / media traces.
- Observatorium dashboards for media telemetry.

---

### Phase 5: Fallbacks & Migration

**Duration**: 1-2 weeks  
**Depends on**: Phase 4  
**Deliverables**:
- FFmpeg subprocess for video/audio.
- Isolated image/PDF fallback subprocesses.
- Deprecate old bridges.

---

## Part 5: Codec Support Tiers

### Tier S: Saturated (Apple-Native)
- **Video**: H.264, HEVC, ProRes, AV1 (decode).
- **Audio**: AAC, ALAC, MP3 (decode via AudioToolbox).
- **Image**: PNG, JPEG, HEIF, TIFF.

### Tier F: Fallback (Isolated Subprocess)
- **Video/Audio**: VP8, VP9, MPEG-2, Vorbis, etc. (FFmpeg).
- **Image**: Legacy or complex formats (ImageMagick/Isolated path).

---

## Part 6: Hardware Units

Explicit hardware units for lane scheduling:

```swift
public enum HardwareUnit: String, Codable, Sendable {
    case videoDecodeEngine
    case videoEncodeEngine
    case audioDSP
    case imageCodecEngine
    case metalGPU
    case neuralEngine
    case cpuSIMD
    case cpuGeneral
    case fallbackSubprocess
}
```

---

## Part 7: Codec Licensing & Ownership (CRITICAL)

**Anigma owns governed media memory, transforms, routing, and fallback boundaries.**  
**Apple/System owns the codec engines (VideoToolbox, AudioToolbox, ImageIO, etc.).**

- **Audio**: Anigma does not implement AAC/AC-3 (patent pools like Via LA). Use AudioToolbox.
- **Images**: Anigma does not implement JPEG/HEIF. Use ImageIO.
- **Video**: Anigma does not implement H.264/HEVC. Use VideoToolbox.

---

**Owner**: Anigma Architecture  
**Status**: 🟢 UNIFIED MEDIA SPEC COMPLETE  
**Approval Required**: Architecture Council (before Phase 0 kickoff)
