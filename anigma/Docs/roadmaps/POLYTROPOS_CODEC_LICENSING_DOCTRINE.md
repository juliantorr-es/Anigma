# Polytropos Unified Media Doctrine

**Date**: 2026-04-26  
**Audience**: Architecture Council, Legal/Compliance  
**Topic**: Unified Doctrine for Video, Audio, and Images  

---

## The Core Decision

**Anigma owns the governed media memory runtime.**  
**The system (Apple) owns the codec engines.**

We do not write our own H.264, HEVC, ProRes, AAC, or JPEG implementations. We govern the system's implementations.

---

## Unified Media Paths

### 1. Video (Zero-Copy Surface Continuity)
- **Codecs**: H.264, HEVC, ProRes, AV1 (decode).
- **Engine**: VideoToolbox / AVFoundation.
- **Anigma ownership**: SurfaceAuthority, FrameReference, Metal transforms.

### 2. Audio (Bounded-Copy Buffer Continuity)
- **Codecs**: AAC, AC-3, ALAC, MP3, Opus (decode/encode).
- **Engine**: AudioToolbox / AVFoundation.
- **Licensing (AAC)**: Via LA administers AAC patent pool. Do not write custom engines.
- **Anigma ownership**: AudioBufferAuthority, PCMBufferReference, DSP/Mix kernels.
- **Doctrine**: Bounded-copy accounted. No raw `Data/[UInt8]/[Float]` materialization in hot contracts.

### 3. Images (Zero-copy or Low-copy Texture Continuity)
- **Codecs**: JPEG, PNG, HEIF, TIFF, RAW.
- **Engine**: ImageIO / CoreImage.
- **Anigma ownership**: SurfaceAuthority, ImageSurfaceReference, Metal/CI transforms.

---

## The Correct Architecture (Unified)

```
Tier 1: Anigma Contracts (Pure Swift, No Codecs)
│
├─ Video/Audio/Image contract families
└─ MediaReference (opaque memory handles)

Tier 2: Anigma Governance (SaturatedMemoryAuthority)
│
├─ SurfaceAuthority (video/images)
├─ AudioBufferAuthority (audio PCM/ring buffers)
├─ PacketStreamAuthority (packets)
├─ MaterializationGate (approves copies)
└─ MediaCopyProof (records evidence)

Tier 2b: Backend Executors
│
├─ VideoToolbox / AudioToolbox / ImageIO backends
├─ Metal / CoreImage / DSP transform backends
└─ Fallback executors (isolated subprocesses)

Tier 3: Apple & System Frameworks
│
├─ VideoToolbox / AudioToolbox / ImageIO
├─ Metal / CoreImage / Accelerate
└─ Fallback tools (FFmpeg, ImageMagick - sandboxed)
```

---

## What Anigma Implements (Unified)

✅ **Media-agnostic contracts** (VideoDecodeContract, AudioMixContract, etc.)  
✅ **Governed media memory** (Authorities, References, Leases)  
✅ **Copy gating** (MaterializationGate, MediaCopyProof, audit trail)  
✅ **Media transforms** (Metal kernels, DSP paths, CoreImage filters)  
✅ **Telemetry** (SaturatedHeartbeatPacket, media pipeline traces)  
✅ **Fallback isolation** (Isolated subprocesses, sandboxed, receipted)  

---

## What Anigma Does NOT Implement

❌ **Patented video codecs** (H.264, HEVC - use VideoToolbox)  
❌ **Patented audio codecs** (AAC, AC-3 - use AudioToolbox)  
❌ **Proprietary image formats** (HEIF, RAW - use ImageIO)  
❌ **Direct library linking for fallbacks** (use subprocesses)  

---

## The Secret Sauce (Unified)

Anigma's competitive advantage is NOT:

❌ "We wrote a better AAC encoder"  
❌ "We support 500 image formats"  

Anigma's competitive advantage IS:

✅ **Governed media surfaces and buffers** (nobody can copy without recording why)  
✅ **Managed memory lifecycle** (every frame/buffer tracked, every consumer declared)  
✅ **Media continuity** (Decode → Transform → Encode without intermediate copies)  
✅ **Fallback transparency** (every material copy receipted, no hidden costs)  
✅ **Apple Silicon native** (Hardware engines + Metal/DSP transforms)  
✅ **Observability** (full telemetry on every media operation)  

---

## Licensing Review Checklist (Unified)

Before Phase 2 or any production use:

- [ ] ⏳ **Legal review**: Anigma's use of VideoToolbox/AudioToolbox/ImageIO licensing (PENDING)
- [ ] ⏳ **AAC Licensing**: Confirm system-framework usage covers distribution (PENDING)
- [ ] ⏳ **Fallback subprocesses**: Verify subprocess approach for FFmpeg/ImageMagick (PENDING)
- [ ] ⏳ **Patent search**: Any Anigma-specific media analysis/metadata concerns? (PENDING)
- [ ] ⏳ **Third-party audit**: Consider codec IP review before shipping (PENDING)

---

## The Unified Verdict

**Anigma owns the governed media memory runtime.**  
**The system owns the codec engines.**

**Result**: Fast, governable, auditable, legally clean, shippable across video, audio, and images.

---

**Owner**: Architecture Council  
**Status**: ✅ APPROVED (UNIFIED)  
**Implementation**: Phase 0 kickoff (Media substrate)