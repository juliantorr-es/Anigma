# ⚠️ DEPRECATED: FFmpeg + Saturated + Metal Architecture Diagram

**Status**: DEPRECATED — See POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md

This document is retained for historical reference only. Architecture diagrams are now included in the comprehensive spec.

---

# Original Diagrams (Archived)

## Current Architecture (Monolithic)

```
┌─────────────────────────────────────────────────────────────────┐
│ Application Layer                                               │
│  VideoRenderCapsule.swift / PolytroposModule                    │
└────────────────────────┬────────────────────────────────────────┘
                         │ (imports C++)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Opaque C++ Bridge (Monolithic)                                  │
│  VideoRenderNativeBridge.cpp                                    │
│  - All video processing logic mixed together                    │
│  - No governance/telemetry hooks                                │
│  - No hardware lane awareness                                   │
│  - Hard-coupled to FFmpeg C API                                 │
│  - Manual memory management (leak-prone)                        │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
   ┌─────────┐      ┌──────────┐    ┌──────────┐
   │ Metal   │      │ CPU FFmpeg   │ Accelerate
   │ (hidden)│      │ (implicit)  │ (ad-hoc)
   └─────────┘      └──────────┘    └──────────┘

Problems:
✗ Opaque bridge — Can't inspect operations
✗ No telemetry — No observability into decode/encode
✗ No hardware lane scheduling — Manual, inefficient
✗ Fragile FFmpeg linking — Environment-dependent
✗ No fallback strategy — One failure breaks everything
✗ Monolithic overhead — Can't reuse components
✗ Testing coupled to FFmpeg — Hard to mock
```

---

## Proposed Architecture (Saturated + Metal)

```
┌─────────────────────────────────────────────────────────────────┐
│ TIER 1: Contracts (Swift, no I/O)                               │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Governance + Hardware Lane Policies                         │ │
│ │                                                              │ │
│ │  MediaDecodeContract           HardwareLane.perception      │ │
│ │  ├─ input: DecodeInput (codec hint, target format)          │ │
│ │  ├─ output: DecodeOutput (frame data, metrics, receipt)     │ │
│ │  ├─ policy: Prefer ANE if available                         │ │
│ │  └─ telemetry: SaturatedHeartbeatPacket                     │ │
│ │                                                              │ │
│ │  MediaEncodeContract           HardwareLane.inference       │ │
│ │  ├─ input: EncodeInput (frame, codec, bitrate)              │ │
│ │  ├─ output: EncodeOutput (encoded packet, metrics)          │ │
│ │  └─ policy: Prefer GPU if available                         │ │
│ │                                                              │ │
│ │  ScaleFormatContract           HardwareLane.inference       │ │
│ │  ├─ input: ScaleInput (frame, target dims, color space)     │ │
│ │  ├─ output: ScaleOutput (scaled frame, metrics)             │ │
│ │  └─ kernel: ScaleFormatKernel.metal                         │ │
│ └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │ ExecutionAuthority routes to:       │
        ▼                  ▼                  ▼
┌─────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ TIER 2: Metal   │ │ TIER 2: Metal    │ │ TIER 2: FFmpeg   │
│ Executors       │ │ Executors        │ │ Fallback         │
│                 │ │                  │ │                  │
│ Lane: .percep   │ │ Lane: .inference │ │ Lane: .background│
├─────────────────┤ ├──────────────────┤ ├──────────────────┤
│ MetalVideo      │ │ MetalScaleFmt    │ │ FFmpegExecutor   │
│ Decoder         │ │                  │ │                  │
│                 │ │ (Metal compute)  │ │ (subprocess or   │
│ ✓ H.264 (ANE)   │ │                  │ │  linked lib)     │
│ ✓ HEVC (ANE)    │ │ ✓ YUV→RGB        │ │                  │
│ ✓ VP9 (GPU)     │ │ ✓ Scale          │ │ ✓ Any codec      │
│ ✓ AV1 (GPU)     │ │ ✓ Format convert │ │ ✓ Fallback       │
│                 │ │                  │ │                  │
│ Backend:        │ │ Backend:         │ │ Backend:         │
│ VideoToolbox    │ │ Metal Kernels    │ │ FFmpeg C libs    │
│ Metal           │ │ Accelerate       │ │ (optional)       │
└────────┬────────┘ └────────┬─────────┘ └────────┬─────────┘
         │                   │                    │
         └───────────────────┼────────────────────┘
                             │
                    ┌────────▼────────┐
                    │ SaturatedHeartbeatPacket
                    │ - mission ID
                    │ - operation type
                    │ - payload hash (Metal BLAKE3)
                    │ - GPU utilization %
                    │ - timing
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
   ┌──────────┐         ┌──────────┐         ┌────────┐
   │ SaturatedLoggingRing        │ Governance  │ Observatorium
   │ (append-only event stream)  │ Receipts    │ Dashboard
   │                             │             │
   │ ✓ Decode started    ────────┼─────────────┤ Decode latency
   │ ✓ GPU selected             │             │ GPU utilization
   │ ✓ Format converted ────────┼─────────────┤ Lane load %
   │ ✓ Decode complete   ────────┼─────────────┤ Codec distribution
   │ ✓ Memory allocated  ────────┼─────────────┤ Failure rate
   └──────────┘         └──────────┘         └────────┘
              │
              ▼
         ┌─────────────────┐
         │ SaturatedSearch │ (Reuse vector search kernel)
         │ + Batch         │
         │ Processing      │
         └─────────────────┘

Benefits:
✓ Clear contracts — Know what each layer does
✓ Full telemetry — Every operation instrumented
✓ Hardware lane scheduling — Optimal resource utilization
✓ Graceful degradation — Automatic fallback
✓ Pluggable executors — Mock for testing
✓ Metal acceleration — GPU-backed decode, format conversion
✓ Zero-copy pipeline — Metal pixelBuffers, CAS references
✓ Governance integration — Receipts, decision tracking
```

---

## Data Flow: Transcode MP4 → WebM

### Current (Monolithic)
```
Input: video.mp4
  ↓
VideoRenderNativeBridge::transcodeVideo() [opaque, 500+ lines C++]
  ├─ Demux (avformat, internal)
  ├─ Decode H.264 (avcodec, internal, no visibility)
  ├─ Scale (swscale, internal)
  ├─ Encode VP9 (avcodec, internal)
  └─ Mux (avformat, internal)
  ↓
Output: video.webm

Problems:
- No insights into each step
- No ability to parallelize
- No metrics collection
- Hard to debug failures
- No way to switch to GPU
```

### Proposed (Saturated + Metal)
```
Input: video.mp4 (CAS reference: hash:abc123)
  │
  ▼ ContractContext: ExecutionAuthority.request(
     contract: MediaDecodeContract.id,
     preferredLane: .perception
    )
  │
  ├─ Resolve lane: Check ANE availability
  │  └─ ANE available? Yes → MetalVideoDecoder
  │
  ├─ Fetch encoded data from CAS: [5 MB H.264 data]
  │  └─ HeartbeatPacket: "Decode started"
  │
  ├─ MetalVideoDecoder.execute():
  │  ├─ Create VTDecompressionSession with Metal backing
  │  │   └─ HeartbeatPacket: "GPU selected (ANE)"
  │  │
  │  ├─ Decode H.264 frame (ANE kernel)
  │  │   └─ HeartbeatPacket: "Decode complete (12ms)"
  │  │
  │  ├─ Output: YUV420 pixelBuffer in GPU memory
  │  │   └─ HeartbeatPacket: "GPU utilization: 45%"
  │  │
  │  └─ Receipt: { contractID, runID, status: satisfied, timeMs: 12 }
  │
  ├─ Store raw frame in CAS: [50 MB YUV420 data]
  │  └─ HeartbeatPacket: "Frame stored (hash:xyz789)"
  │
  ├─ ContractContext: ExecutionAuthority.request(
     contract: ScaleFormatContract.id,
     preferredLane: .inference
    )
  │
  ├─ Resolve lane: GPU available? Yes → MetalScaleFormatter
  │  └─ Metal compute kernel: convert YUV420 → RGB, scale 1920→1280
  │     └─ HeartbeatPacket: "Scale complete (8ms, GPU 67%)"
  │
  ├─ Store scaled frame in CAS: [10 MB RGB24 @ 1280x720]
  │
  ├─ ContractContext: ExecutionAuthority.request(
     contract: MediaEncodeContract.id,
     preferredLane: .inference
    )
  │
  ├─ Resolve lane: GPU available? Yes → MetalVideoEncoder
  │  └─ Encode VP9 (GPU kernel if available, else CPU)
  │     └─ HeartbeatPacket: "Encode complete (25ms)"
  │
  ├─ Store encoded video in CAS: [2 MB VP9 packets]
  │
  └─ Aggregate telemetry:
     ├─ Total time: 45ms (vs 500ms CPU)
     ├─ GPU utilization: 56% average
     ├─ Lane distribution: 60% .perception, 40% .inference
     ├─ Memory: 60 MB peak (GPU pinned)
     └─ Receipt chain: decode → scale → encode (linked evidence)

Output: video.webm (CAS reference: hash:def456)
        + Full telemetry visible in Observatorium dashboard
```

---

## Hardware Lane Scheduling Decision Tree

```
Request: encode_contract
  │
  ├─ Check policy: MediaEncodeContract.preferredLane = .inference
  │
  ├─ Check availability:
  │  ├─ Metal GPU available?
  │  │  ├─ Yes → Check GPU lane load
  │  │  │  ├─ Load < 80%? → Use MetalVideoEncoder (GPU)
  │  │  │  └─ Load ≥ 80%? → Defer to backpressure queue
  │  │  │
  │  │  └─ No → Next option
  │  │
  │  ├─ Accelerate framework available?
  │  │  ├─ Yes → Use AccelerateVideoEncoder (SIMD)
  │  │  └─ No → Next option
  │  │
  │  └─ Fallback: FFmpegExecutor (CPU subprocess)
  │     └─ Load CPU? Check thread pool
  │        ├─ Threads < max? → Queue directly
  │        └─ Threads ≥ max? → Backpressure, retry
  │
  └─ Result: Selected executor + lane affinity
     └─ Emit telemetry: "Encode routed to .inference lane"

If all lanes overloaded:
  ├─ Check priority of current request (governance)
  ├─ Compare with queued requests
  ├─ Evict lower priority if needed
  └─ Emit alert: "Lane saturation detected"
```

---

## Metal Kernel Execution Model

```
Request: Scale frame YUV420 (1920×1080) → RGB (1280×720)
  │
  ├─ Create Metal command buffer
  │
  ├─ Load kernel: convert_yuv420_to_rgba
  │  └─ Source: ScaleFormatKernel.metal (compiled .air)
  │
  ├─ Bind GPU buffers:
  │  ├─ [0] Input Y plane (1920×1080 grayscale)
  │  ├─ [1] Input U plane (960×540 subsampled)
  │  ├─ [2] Input V plane (960×540 subsampled)
  │  ├─ [3] Output RGBA (1280×720×4 bytes)
  │  ├─ [4] Input dimensions
  │  ├─ [5] Output dimensions
  │  └─ ... (other uniforms)
  │
  ├─ Dispatch kernel:
  │  └─ threadgroup: 16×16 (GPU workgroup size)
  │  └─ grid: (1280÷16, 720÷16) = (80×45) threadgroups
  │  └─ total threads: 1280×720 = 921,600 parallel operations
  │
  ├─ GPU executes in parallel:
  │  └─ Each thread processes one output pixel
  │  └─ Bilinear scale + YUV to RGB conversion
  │  └─ No synchronization needed (SIMD)
  │
  ├─ Synchronize:
  │  └─ Command buffer wait until GPU complete
  │  └─ Typical duration: 5-15ms on M1/M2/M3
  │
  └─ Result: RGB frame ready in GPU memory
     └─ No copy to CPU (stays on GPU for next kernel or upload to CAS)

Contrast: CPU version (swscale)
  └─ Sequential per-pixel conversion
     └─ 921,600 iterations × (sample + convert) ≈ 50-100ms
```

---

## Telemetry Flow: SaturatedHeartbeatPacket

```
Every major operation emits a heartbeat:

Decode started:
  ├─ missionID: 12345678-1234-5678-abcd-ef0123456789
  ├─ packetType: .start
  ├─ payloadHash: [Metal BLAKE3 of "H.264 decode start"]
  ├─ timestamp: 1700000000000000000 (ns)
  ├─ powerWatts: 8.5 (M1 GPU idle + activity)
  └─ opsPerJoule: 2400.0 (ANE efficiency estimate)

GPU selected:
  └─ payloadHash: [Metal BLAKE3 of "GPU decode ANE"]

Format converted:
  └─ payloadHash: [Metal BLAKE3 of "YUV420→RGB scale"]

Decode complete:
  ├─ packetType: .end
  ├─ payloadHash: [Metal BLAKE3 of "Decode complete 12ms"]
  └─ opsPerJoule: 2850.0 (actual power efficiency)

Stored in SaturatedLoggingRing (memory-mapped, lock-free):
  ┌─────────────────────────────────────────┐
  │ Position: 0    missionID | type | hash │
  │ Position: 1    missionID | type | hash │
  │ Position: 2    missionID | type | hash │
  │ Position: 3    missionID | type | hash │
  │ ...                                      │
  │ Position: N    (ring wraps around)      │
  └─────────────────────────────────────────┘

Consumed by:
  ├─ Observatorium Dashboard
  │  └─ Real-time decode latency sparkline
  │  └─ GPU utilization gauge
  │  └─ Lane load distribution pie chart
  │
  ├─ Governance Audit Trail
  │  └─ Proof that operation occurred
  │  └─ Hash evidence of data processed
  │  └─ Executor identity recorded
  │
  └─ Performance Analysis
     └─ Aggregate: Median decode time = 14ms
     └─ P99: Decode time = 45ms (GPU overload spike)
     └─ Efficiency: ops/joule trend over time
```

---

## Comparison: Old vs. New Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Aspect              │ Current (C++ Bridge) │ Proposed (Saturated)│
├─────────────────────────────────────────────────────────────────┤
│ Visibility          │ Opaque              │ Per-operation       │
│ Telemetry           │ None                │ Heartbeat packets   │
│ GPU Control         │ Hidden              │ Explicit            │
│ Lane Scheduling     │ None                │ Automatic           │
│ Fallback            │ None (fail)         │ Graceful            │
│ Testing             │ FFmpeg-dependent    │ Mock executors      │
│ Debugging           │ Attach debugger     │ Replay heartbeats   │
│ Performance         │ Good                │ Better (Metal+lane) │
│ Complexity (LOC)    │ Moderate (~500)     │ Distributed (clear) │
│ Maintainability     │ Fragile             │ Modular             │
│ Future: Kafka       │ N/A                 │ Easy (executor)     │
│ Future: RabbitMQ    │ N/A                 │ Easy (executor)     │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
Packages/
├── ContractsCore/
│   └── Sources/ContractsCore/Media/
│       ├── MediaDecodeContract.swift     [Tier 1: Decode interface]
│       ├── MediaEncodeContract.swift     [Tier 1: Encode interface]
│       ├── ScaleFormatContract.swift     [Tier 1: Scale interface]
│       └── MediaTypes.swift              [Shared types: PixelFormat, Codec, etc.]
│
├── AnigmaCore/
│   └── Sources/AnigmaGovernance/Media/
│       ├── Executors/
│       │   ├── MetalVideoDecoder.swift   [Tier 2: ANE/GPU decode]
│       │   ├── MetalVideoEncoder.swift   [Tier 2: GPU encode]
│       │   ├── MetalScaleFormatter.swift [Tier 2: Format conversion]
│       │   └── FFmpegExecutor.swift      [Tier 2: CPU fallback]
│       │
│       ├── Kernels/
│       │   ├── ScaleFormatKernel.metal   [Tier 3: YUV→RGB scaling]
│       │   ├── EncodeKernel.metal        [Tier 3: GPU encode (future)]
│       │   └── FilterKernel.metal        [Tier 3: Effects (future)]
│       │
│       └── MediaTypes.swift              [Pixel formats, etc.]
│
└── SaturationKit/
    └── Sources/SaturationKit/
        ├── SaturatedSearch.metal        [Reusable GPU search kernel]
        └── SaturatedHeartbeatPacket.swift [Telemetry]
```

---

## Risk Mitigation

```
Risk: VideoToolbox unavailable (older macOS)
├─ Mitigation 1: Check #if canImport(VideoToolbox) at compile time
├─ Mitigation 2: Graceful fallback to FFmpegExecutor
└─ Mitigation 3: Runtime availability check before lane selection

Risk: GPU memory exhaustion during scale
├─ Mitigation 1: Check available VRAM before dispatch
├─ Mitigation 2: Fall back to CPU swscale if GPU memory low
└─ Mitigation 3: Queue backpressure if GPU saturated

Risk: Format conversion bugs (data corruption)
├─ Mitigation 1: Golden test vectors (known input→output pairs)
├─ Mitigation 2: Frame validation (histogram check)
├─ Mitigation 3: Hash comparison (input hash ≠ output hash = error)
└─ Mitigation 4: Gradual rollout (canary testing)

Risk: Metal kernel compilation failure
├─ Mitigation 1: Compile .metal at build time (not runtime)
├─ Mitigation 2: Test on M1/M2/M3 + Intel GPU variants
└─ Mitigation 3: Fallback CPU implementation always available

Risk: Saturated telemetry overhead (slowdown)
├─ Mitigation 1: Lock-free ring buffer (no mutex)
├─ Mitigation 2: Telemetry async (non-blocking)
├─ Mitigation 3: Sampling policy (not all ops if overloaded)
└─ Mitigation 4: Benchmark: overhead < 2% of decode time
```
