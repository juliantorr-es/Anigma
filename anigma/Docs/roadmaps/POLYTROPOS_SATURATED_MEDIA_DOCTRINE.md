# Polytropos Saturated Media Backend Architecture — Doctrine & Red-Lines

**Date**: 2026-04-26  
**Status**: ⚠️ REVISED DOCTRINE (See corrections below)  
**Scope**: Backend architecture, not FFmpeg integration  

---

## The Problem This Solves

Current state:
- VideoRenderCapsule.swift → VideoRenderNativeBridge.cpp → FFmpeg C libs
- Opaque bridge; no telemetry, no lane scheduling, no fallback
- FFmpeg linking spread across 9 targets, fragile and environment-dependent
- No hardware-accelerated path for Apple platforms (ANE / VideoToolbox)
- No observability; can't debug or instrument

Desired state:
- Contracts define media operations (decode, encode, scale) in Swift
- Backend registry selects implementation based on capabilities and policy
- Primary path: Apple-native (VideoToolbox + Metal)
- Fallback path: FFmpeg subprocess (NOT linked library)
- Every operation produces telemetry and receipts
- UI and contract layer have zero FFmpeg dependencies

---

## Core Doctrine

**Polytropos media processing uses a governed backend registry.**

The primary execution path is Apple-native and saturated:
- **VideoToolbox** for hardware-accelerated decode/encode (media engine, not ANE)
- **Metal** for compute transforms (scaling, colorspace conversion, analysis)
- **PayloadReference / FrameReference** for memory discipline (no inline data)
- **Saturated telemetry** for observability (heartbeat packets, receipts)

**FFmpeg is not the renderer of record.**

FFmpeg is a contained compatibility backend for:
- Unsupported codecs
- Legacy containers
- Reference renders (validation, debugging)
- CPU fallback when hardware unavailable

**No application, UI, or Tier 1 contract layer links FFmpeg.**

Only an isolated FFmpeg executor may invoke it, preferably as a subprocess.

**Every invocation produces:**
- Toolchain receipt (what was invoked, success/failure)
- Artifact receipt (input/output hashes, timing)
- Command digest (reproducibility)
- SaturatedHeartbeatPacket (telemetry)

---

## Architecture: Three Tiers

```
┌─────────────────────────────────────────────────────────┐
│ Tier 1: Contracts (Swift, no I/O, no FFmpeg)           │
├─────────────────────────────────────────────────────────┤
│ • MediaDecodeContract                                   │
│ • MediaEncodeContract                                   │
│ • ScaleFormatContract                                   │
│ • TranscodeContract                                     │
│ • PixelFormat, CodecDescriptor, FrameReference enums  │
│ • MediaBackendCapabilities, MediaBackendRegistry      │
│                                                         │
│ Policy: No FFmpeg symbols, no I/O, serializable       │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
┌─────────────────────┐   ┌─────────────────────┐
│ Tier 2: Executors   │   │ Backend Registry    │
├─────────────────────┤   ├─────────────────────┤
│ • MockMediaBackend  │   │ Selects executor    │
│ • VideoToolbox...   │   │ based on:           │
│   Decode/Encode     │   │ • Codec support     │
│ • MetalScale        │   │ • Hardware avail.   │
│   Formatter         │   │ • Lane policy       │
│ • FFmpeg...         │   │ • Performance       │
│   SubprocessBackend │   │ • Memory budget     │
│                     │   │                     │
│ Policy: Sendable,   │   │ No FFmpeg imports   │
│ actor-isolated,     │   │ outside executor   │
│ receipts mandatory  │   │                     │
└────────────┬────────┘   └─────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────┐
│ Tier 3: Platform APIs                                   │
├─────────────────────────────────────────────────────────┤
│ • VideoToolbox.VTDecompressionSession                  │
│ • Metal compute kernels (MTLComputePipeline)          │
│ • FFmpeg subprocess (isolated, sandbox-able)          │
│ • Accelerate SIMD                                      │
│                                                         │
│ Policy: Sandbox constraint, no DB access              │
└─────────────────────────────────────────────────────────┘
```

---

## Red-Line Corrections

### Red-Line 1: Hardware Unit Names (NOT Lane Names)

**Old (Incorrect)**:
```
.perception → "ANE video decode"
.inference → "GPU compute"
.background → "CPU fallback"
```

**New (Correct)**:
```
enum HardwareUnit: Codable, Sendable {
    case videoDecodeEngine      // VideoToolbox hardware decoder
    case videoEncodeEngine      // VideoToolbox hardware encoder
    case metalGPU               // Metal compute (MLX, scaling, etc.)
    case cpuSIMD                // Accelerate SIMD
    case cpuFFmpeg              // CPU FFmpeg fallback
    case neuralEngine           // Apple Neural Engine (for inference)
}

// In MediaDecodeContract:
public struct MediaDecodeContract: Sendable {
    public let input: DecodeInput
    public let preferredHardwareUnit: HardwareUnit = .videoDecodeEngine
    // Not .perception; that is for inference, not decode
}
```

**Why**: VideoToolbox is a dedicated media engine, not the Apple Neural Engine. Reusing `.perception` conflates two separate hardware categories and will confuse policy decisions.

---

### Red-Line 2: Executor Names (Reserved Metal* for Actual GPU Kernels)

**Old (Incorrect)**:
```
MetalVideoDecoder
MetalVideoEncoder
MetalScaleFormatter  // ✓ This one is correct
```

**New (Correct)**:
```
VideoToolboxDecodeExecutor
VideoToolboxEncodeExecutor
MetalScaleFormatter           // ✓ Correct: actual Metal compute kernel
MetalColorspaceConverter      // ✓ GPU kernel
MetalHistogramAnalyzer        // ✓ GPU kernel
MetalMotionVectorExtractor    // ✓ GPU kernel
```

**Why**: Metal* names should be reserved for actual Metal compute kernels that run custom code on the GPU. VideoToolbox uses hardware media engines, not custom kernels. Conflating them makes it impossible to distinguish GPU-accelerated operations from hardware-assisted operations.

---

### Red-Line 3: Memory Model (NOT Zero-Copy in Phase 1)

**Old (Incorrect)**:
```
"Zero-copy pipeline execution with SIMD/GPU coordination"
"Metal pixelBuffers, CAS references"
```

**New (Correct)**:

Define five levels of zero-copy maturity:

| Level | Name | Phase | Description |
|-------|------|-------|-------------|
| 0 | Reference-Only | Phase 1 | Inline Data forbidden. All payloads by PayloadReference. |
| 1 | File-Backed | Phase 1-2 | mmap-friendly PayloadReference for CPU streaming. |
| 2 | CVPixelBuffer-Aware | Phase 2-3 | FrameReference can wrap CVPixelBuffer/IOSurface. |
| 3 | GPU-Resident | Phase 3-4 | FrameReference backed by MTLTexture; transient. |
| 4 | Materialization Points | Phase 4+ | Frame graph with explicit GPU↔CPU boundaries. |

**Phase 1 target**: Level 0 (Reference-only)
- Decode: Read encoded PayloadReference from CAS → VideoToolbox → Write decoded FrameReference to CAS
- Scale: Read FrameReference from CAS → MetalScaleFormatter → Write scaled FrameReference to CAS
- Encode: Read FrameReference from CAS → VideoToolbox → Write encoded PayloadReference to CAS

**Not zero-copy, but governed-copy**: Every buffer movement is explicit, traced, and receipted.

**Why**: Claiming zero-copy now invites pressure to expose MTLTexture/CVPixelBuffer in contracts, which violates Tier 1 purity and couples semantics to hardware implementation. Explicit levels prevent over-claiming and enable measured progress.

---

### Red-Line 4: Governance in Execution Envelope, NOT Contract Payload

**Old (Incorrect)**:
```swift
public struct DecodeInput: Codable, Sendable {
    public let encodedData: PayloadReference
    public let codecHint: CodecHint
    public let governanceDecision: ExecutionAuthority.Decision  // ✗ WRONG
    public let targetFormat: PixelFormatHint
}
```

**New (Correct)**:
```swift
// Tier 1 Contract: Pure semantics
public struct DecodeInput: Codable, Sendable {
    public let encodedData: PayloadReference
    public let codecHint: CodecHint
    public let targetFormat: PixelFormatHint
    public let targetDimensions: Dimensions?
    public let timing: DecodeTimingHint?
}

// Execution Envelope: Governance + policy (Tier 2)
public struct ExecutionContext: Sendable {
    public let runID: RunID
    public let missionID: MissionID
    public let governanceReceipt: GovernanceReceipt
    public let lanePolicy: LanePolicy
    public let backend: MediaBackendRegistry.Selection
}
```

**Why**: Governance state is a runtime execution artifact, not part of the media operation schema. Embedding it in the contract couples Tier 1 (semantics) to Tier 2 (policy), making it impossible to replay or analyze operations without governance metadata.

---

### Red-Line 5: Build Hygiene (NOT Hardcoded Linker Paths)

**Old (Incorrect)**:
```swift
.unsafeFlags([
    "-L/opt/homebrew/lib",
    "-L/usr/local/lib",
    "-L/usr/lib",
])
```

This violates Anigma's build hygiene doctrine and is exactly the fragility root cause.

**New (Correct)**: Three options, in order of preference:

**Option A: Subprocess (RECOMMENDED)**
```swift
// FFmpegSubprocessBackend calls CLI ffmpeg via Process()
// Resolved by toolchain registry (where is ffmpeg CLI?)
// Receipt logs: exit code, stderr, timing
// No linking required; ffmpeg installed via Homebrew or package manager
```

**Option B: pkg-config Discovery**
```swift
// At build time: pkg-config --cflags --libs libavformat
// Captures system-discovered paths
// Fails cleanly if FFmpeg not installed
// Portable across Homebrew, MacPorts, system installs
```

**Option C: Vendored / Prebuilt Artifact**
```swift
// Signed FFmpeg binary in Anigma toolchain bundle
// Reproducible, pinned version
// Controlled distribution
// Required for CI/CD repeatability
```

**For Anigma Phase 1**: Choose subprocess. It:
- Eliminates FFmpeg linking entirely
- Simplifies build hygiene
- Sandboxes FFmpeg (can't access Vault or DB)
- Allows version pinning via PATH
- Easy to disable or replace

---

### Red-Line 6: Performance Claims → Benchmark Targets

**Old (Incorrect)**:
```
Benchmark target:
- Decode H.264: 25ms (CPU) → 12ms (GPU/ANE) = 2.1x faster
- Scale 1920→1280: 50ms (CPU) → 8ms (GPU) = 6.3x faster
- Encode VP9: 40ms (CPU) → 20ms (GPU) = 2.0x faster
- Total transcode: 115ms (old) → 40ms (new) = 2.9x faster
```

These are asserted as facts, not hypotheses.

**New (Correct)**:
```
Benchmark targets (hypothesis):
- VideoToolbox hardware decode vs. FFmpeg CPU decode
  • Sample: H.264 1080p @ 60fps
  • Metric: median, p95, p99 frame time
  • Expected range: 1.5-2.5x faster (actual TBD)

- MetalScaleFormatter vs. swscale
  • Sample: 1920×1080 → 1280×720
  • Metric: kernel time, memory bandwidth
  • Expected range: 3-8x faster (actual TBD)

- Total transcode end-to-end
  • Sample: MP4 H.264 → WebM VP9 (5 min clip)
  • Metric: wall time, peak memory, energy (if available)
  • Expected range: 1.5-3x faster (actual TBD)
```

Report results before accepting performance claims.

**Why**: The architecture is sound even if it delivers 1.4x instead of 2.9x. The bigger win is isolation, observability, and fallback resilience. Overpromising benchmarks creates pressure to cut corners.

---

## Implementation Order (Revised)

### Phase 1: Contracts & Registry

**Deliverables**:
- [ ] MediaAssetReference (PayloadReference wrapper for media)
- [ ] FrameReference (PayloadReference with format metadata)
- [ ] PacketReference (PayloadReference for encoded data)
- [ ] PixelFormat enum (RGB8, YUV420, NV12, RGBA16F, etc.)
- [ ] CodecDescriptor (codec family, profile, level)
- [ ] ColorSpaceDescriptor (Rec.709, Rec.2020, sRGB, P3, etc.)
- [ ] MediaProbeContract (detect codec from file)
- [ ] MediaDecodeContract (input: PayloadReference, output: FrameReference)
- [ ] ScaleFormatContract (input: FrameReference, output: FrameReference)
- [ ] MediaEncodeContract (input: FrameReference, output: PacketReference)
- [ ] TranscodeContract (chained: probe → decode → scale → encode)
- [ ] MediaBackendCapabilities (which executors handle which codecs)
- [ ] MediaBackendRegistry (selector logic)

**Acceptance**:
- ✓ All types serialize/deserialize (JSON, Protobuf)
- ✓ No inline Data payloads (rejected by linter)
- ✓ No FFmpeg symbols imported
- ✓ Tests pass with mock executor

### Phase 2: Three Reference Backends

**Deliverables**:
- [ ] MockMediaBackend (in-memory mock for testing)
- [ ] VideoToolboxMediaBackend (VideoToolbox + Metal)
- [ ] FFmpegSubprocessBackend (subprocess executor)

**Acceptance**:
- ✓ Default build succeeds without FFmpeg installed
- ✓ Unsupported codec falls back to FFmpeg without crash
- ✓ VideoToolbox path emits SaturatedHeartbeatPacket
- ✓ FFmpeg subprocess cannot access Vault or DB (sandbox test)
- ✓ No FFmpeg symbols outside FFmpegSubprocessBackend (grep check)

### Phase 3: GPU Kernels

**Deliverables**:
- [ ] MetalScaleFormatter (YUV420 → RGB, bilinear)
- [ ] MetalColorspaceConverter (between all supported spaces)

**Acceptance**:
- ✓ Golden test vectors (known input → output)
- ✓ Matches CPU reference (histogram comparison)
- ✓ Benchmark report generated

### Phase 4: Integration

**Deliverables**:
- [ ] Wire into ExecutionAuthority
- [ ] Emit governance receipts
- [ ] Lane scheduling logic

**Acceptance**:
- ✓ Backend selector routes to correct executor
- ✓ Telemetry stream visible in SaturatedLoggingRing
- ✓ Receipts linked in audit trail

### Phase 5: Bridge Migration

**Deliverables**:
- [ ] Switch VideoRenderCapsule from old C++ bridge
- [ ] Benchmark vs. old bridge
- [ ] Deprecate old bridge

**Acceptance**:
- ✓ Measured performance (median/p95/p99)
- ✓ Zero regressions
- ✓ Full telemetry visible

---

## Acceptance Gates (REQUIRED)

Gate 1: **No FFmpeg symbols outside executor**
- Proof: `grep -r "avcodec\|avformat\|avutil" --include="*.swift" Packages/ | grep -v FFmpegSubprocessBackend` must be empty
- CI: Automated check before merge

Gate 2: **Default build succeeds without FFmpeg**
- Proof: `swift build` on clean system with no FFmpeg installed
- CI: Run in container without FFmpeg

Gate 3: **Unsupported codec gracefully falls back**
- Proof: Integration test with AV1 (unsupported by VideoToolbox) → subprocess fallback
- CI: Test must not crash UI

Gate 4: **VideoToolbox path emits telemetry**
- Proof: SaturatedHeartbeatPacket stream contains decode start/complete events
- CI: Log inspection test

Gate 5: **No inline frame payloads in contracts**
- Proof: Contract linter rejects `Data`, `[UInt8]`, `[Float]` for media payloads
- CI: Linter runs on all contract definitions

Gate 6: **Build hygiene rejects hardcoded paths**
- Proof: `grep -r "/opt/homebrew\|/usr/local" Package.swift` must be empty
- CI: Automated check before merge

Gate 7: **Benchmark report generated before performance claims**
- Proof: Report file with median/p95/p99 for decode/scale/encode/transcode
- Gate: Architect review required before accepting 2.9x claim

Gate 8: **FFmpeg subprocess cannot access Vault or DB**
- Proof: Sandbox profile denies filesystem access outside temp
- CI: strace check on FFmpeg subprocess invocation

---

## Revised Phase 1 Scope

**Start date**: Ready when approved  
**Duration**: 2-3 weeks  
**Team**: 1 architect, 1-2 engineers  

**NOT in Phase 1**:
- ✗ Metal kernels (Phase 3)
- ✗ VideoToolbox integration (Phase 2)
- ✗ FFmpeg linking (Phase 2, and only as subprocess)
- ✗ Performance benchmarks (Phase 3+)
- ✗ Lane scheduling (Phase 4)

**IN Phase 1**:
- ✓ All contract types
- ✓ Backend registry design
- ✓ Mock executor for testing
- ✓ Acceptance tests

**Completion criteria**:
- ✓ All types defined, serializable, documented
- ✓ Mock executor passes 30+ unit tests
- ✓ No FFmpeg symbols imported
- ✓ Ready for Phase 2 (backend implementations)

---

## Success Criteria (Updated)

**Phase 1-5 completion**:
- ✅ Contracts layer pure Swift, no FFmpeg
- ✅ Only FFmpegSubprocessBackend links FFmpeg (as subprocess, not library)
- ✅ VideoToolbox path primary, Metal GPU kernels for transforms
- ✅ Every operation produces SaturatedHeartbeatPacket + receipt
- ✅ UI has zero FFmpeg dependencies
- ✅ 9 current FFmpeg linker settings reduced to 1 (FFmpegSubprocessBackend only)
- ✅ Build succeeds on clean system without FFmpeg
- ✅ Unsupported codecs gracefully fall back
- ✅ Benchmark report generated (actual performance measured)
- ⚠️ Performance claim accepted only after benchmarks reviewed by architect

---

## References

- Revised epic name: **Polytropos Saturated Media Backend Architecture**
- Contracts first, kernels last (not vice versa)
- FFmpeg is fallback, not primary path
- No hardcoded linker paths; use subprocess
- Benchmarks before claims
- Gates before shipping

---

**Owner**: Anigma Architecture  
**Status**: 🔧 DOCTRINE REVISED  
**Next**: Approve revised scope, then Phase 1 kickoff
