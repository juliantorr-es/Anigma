# Polytropos Media Architecture — Red-Lines Summary

**Critical corrections to the original FFmpeg + Saturated + Metal proposal**

---

## What Changed

The original proposal was architecturally sound but had six significant doctrine violations that would cause problems during implementation. Here they are, fixed.

---

## Red-Line 1: Epic Name (FFmpeg Should Not Be Co-Equal)

**Old**: "FFmpeg + Saturated + Metal Integration"  
**New**: "Polytropos Saturated Media Backend Architecture"

**Why**: The title should reflect that Saturated is primary, FFmpeg is fallback. Otherwise FFmpeg becomes the architectural anchor and linker complexity returns.

---

## Red-Line 2: Hardware Unit Names (Not Lane Names)

**Old**:
```
.perception → "ANE video decode"
.inference → "GPU compute"
.background → "CPU fallback"
```

**New**:
```
enum HardwareUnit {
    case videoDecodeEngine     // VideoToolbox hardware (not ANE)
    case videoEncodeEngine     // VideoToolbox hardware (not ANE)
    case metalGPU              // Metal compute (for scaling, etc.)
    case cpuSIMD               // Accelerate
    case cpuFFmpeg             // CPU fallback
    case neuralEngine          // Apple Neural Engine (inference)
}
```

**Why**: VideoToolbox is a media engine, not the Apple Neural Engine. Reusing `.perception` conflates them and will confuse policy decisions.

---

## Red-Line 3: Executor Names (Metal* Reserved for GPU Kernels)

**Old**:
```
MetalVideoDecoder
MetalVideoEncoder
MetalScaleFormatter  ← This one is correct
```

**New**:
```
VideoToolboxDecodeExecutor
VideoToolboxEncodeExecutor
MetalScaleFormatter           ← GPU kernel (correct)
MetalColorspaceConverter      ← GPU kernel (correct)
MetalHistogramAnalyzer        ← GPU kernel (correct)
```

**Why**: Metal* names should only be used for actual Metal compute kernels. VideoToolbox uses hardware media engines, not custom GPU code.

---

## Red-Line 4: Memory Model (Not Zero-Copy Yet)

**Old**: "Zero-copy pipeline execution"  
**New**: "Reference-only payloads (Level 0 maturity)"

Five levels of zero-copy maturity:

| Level | Name | Phase | Description |
|-------|------|-------|-------------|
| 0 | Reference-Only | Phase 1-2 | PayloadReference only; no inline Data |
| 1 | File-Backed | Phase 2-3 | mmap-friendly references |
| 2 | CVPixelBuffer-Aware | Phase 3-4 | FrameReference wraps CVPixelBuffer |
| 3 | GPU-Resident | Phase 4-5 | MTLTexture-backed frames |
| 4 | Materialization Points | Phase 5+ | Full frame graph |

**Why**: Claiming zero-copy invites pressure to expose MTLTexture/CVPixelBuffer in contracts, which violates purity and couples semantics to hardware.

---

## Red-Line 5: Governance Belongs in Execution Envelope, Not Contracts

**Old**:
```swift
public struct DecodeInput: Codable, Sendable {
    public let encodedData: PayloadReference
    public let governanceDecision: ExecutionAuthority.Decision  // ✗ Wrong layer
    public let targetFormat: PixelFormatHint
}
```

**New**:
```swift
public struct DecodeInput: Codable, Sendable {
    public let encodedData: PayloadReference
    public let codecHint: CodecHint
    public let targetFormat: PixelFormatHint
}

public struct ExecutionContext: Sendable {
    public let runID: RunID
    public let missionID: MissionID
    public let governanceReceipt: GovernanceReceipt
    public let lanePolicy: LanePolicy
}
```

**Why**: Governance is a runtime artifact, not a semantic requirement. Embedding it in the contract couples Tier 1 to Tier 2 and breaks replays.

---

## Red-Line 6: No Hardcoded Linker Paths (Build Hygiene)

**Old**:
```swift
.unsafeFlags([
    "-L/opt/homebrew/lib",
    "-L/usr/local/lib",
    "-L/usr/lib",
])
```

**New**: Three options in order of preference:

**Option A (RECOMMENDED): Subprocess**
- Call `ffmpeg` CLI via Process()
- Resolved at runtime from PATH or toolchain registry
- NO linking required
- Sandbox-able

**Option B: pkg-config**
- At build time: `pkg-config --cflags --libs libavformat`
- Portable discovery
- Fails cleanly if not installed

**Option C: Vendored**
- Signed FFmpeg artifact in toolchain bundle
- Reproducible, pinned version
- Requires build infrastructure

**Why**: Hardcoded paths are exactly the fragility the proposal identifies as a root problem. Choose subprocess for simplicity.

---

## Red-Line 7: Performance Claims Are Benchmarks, Not Facts

**Old**:
```
Total transcode: 115ms (old) → 40ms (new) = 2.9x faster
```

**New**:
```
Benchmark targets (hypothesis):
- Decode H.264: 1.5-2.5x faster (measured TBD)
- Scale: 3-8x faster (measured TBD)
- Total: 1.5-3x faster (measured TBD)

Report results in: median, p95, p99 table
Accept claims only after benchmarks reviewed by architect
```

**Why**: The architecture is good even at 1.4x. Overpromising creates pressure to cut corners.

---

## Red-Line 8: Contracts First, Kernels Last

**Old**: Phase breakdown was contracts → executors → kernels (mixed)  
**New**:

1. **Phase 1: Contracts & Registry** (Tier 1 only)
   - All types (PixelFormat, CodecDescriptor, FrameReference, etc.)
   - MediaBackendRegistry interface
   - Mock executor for testing
   - No I/O, no linking

2. **Phase 2: Backend Implementations** (Tier 2)
   - VideoToolboxMediaBackend
   - FFmpegSubprocessBackend
   - MockMediaBackend (refined)

3. **Phase 3: GPU Kernels** (Tier 3)
   - MetalScaleFormatter
   - Benchmark report

4. **Phase 4: Integration** (Tier 2+)
   - ExecutionAuthority wiring
   - Telemetry

5. **Phase 5: Migration** (Tier 1+2)
   - Switch from old bridge
   - Verify benchmarks

**Why**: Separating contracts from executors prevents mixed responsibilities and enables testing contracts in isolation.

---

## Acceptance Gates (Must Pass Before Shipping)

| Gate | Requirement | Proof |
|------|-------------|-------|
| 1 | No FFmpeg symbols outside executor | `grep -r "avcodec\|avformat" --include="*.swift" Packages/ \| grep -v FFmpegSubprocessBackend` is empty |
| 2 | Default build works without FFmpeg | `swift build` succeeds on clean system |
| 3 | Unsupported codec gracefully falls back | AV1 test → subprocess fallback, no crash |
| 4 | Telemetry emitted from hardware path | SaturatedHeartbeatPacket stream visible |
| 5 | No inline frame data in contracts | Linter rejects Data/[UInt8]/[Float] payloads |
| 6 | Build hygiene enforced | `grep -r "/opt/homebrew\|/usr/local" Package.swift` is empty |
| 7 | Benchmarks generated and reviewed | median/p95/p99 table for decode/scale/encode |
| 8 | FFmpeg subprocess sandboxed | Strace shows no Vault/DB access |

---

## Summary

**What's solid**:
- ✅ Decomposition into contracts → executors → kernels
- ✅ VideoToolbox + Metal as primary path
- ✅ FFmpeg as isolated fallback
- ✅ Saturated telemetry integration
- ✅ Rejection of monolithic C++ bridge

**What needed fixing**:
1. ❌→✅ Name: "FFmpeg + Saturated" → "Polytropos Saturated Media"
2. ❌→✅ Hardware: ANE overload → explicit HardwareUnit enum
3. ❌→✅ Executors: MetalVideoDecoder → VideoToolboxDecodeExecutor
4. ❌→✅ Memory: Zero-copy claim → Reference-only (Level 0)
5. ❌→✅ Governance: In contracts → In execution envelope
6. ❌→✅ Linking: Hardcoded paths → Subprocess first
7. ❌→✅ Performance: 2.9x claim → Benchmark targets
8. ❌→✅ Order: Mixed phases → Contracts first

**Result**: Architecturally correct, doctrinally sound, implementable.

**Status**: 🟢 READY FOR PHASE 1 KICKOFF

---

**See also**:
- POLYTROPOS_SATURATED_MEDIA_DOCTRINE.md (full doctrine with gates)
- FFMPEG_LINKING_ANALYSIS.md (revised subprocess strategy)
- Phase 1 spec in POLYTROPOS_SATURATED_MEDIA_DOCTRINE.md
