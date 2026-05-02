# ⚠️ DEPRECATED: FFmpeg + Saturated + Metal — Quick Reference

**Status**: DEPRECATED — See POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md

This document is retained for historical reference only. For current quick reference, read Part 1-2 of the comprehensive spec.

---

**This is the TL;DR. For full spec, see POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md**

---

## TL;DR

**Problem**: Video processing is monolithic (opaque C++ bridge), no GPU, no visibility.

**Solution**: Decompose into Saturated contracts → executors → kernels. Add Metal acceleration, hardware lane scheduling, full telemetry.

**Result**: 2.9x faster (115ms → 40ms transcode), observable, modular, resilient.

---

## The Three Tiers

```
TIER 1: Contracts (What)
  MediaDecodeContract { input: encoded data, output: frame, policy: use ANE? }
  MediaEncodeContract { input: frame, output: encoded data, policy: use GPU? }
  ScaleFormatContract { input: frame, target size, policy: use GPU kernel? }

TIER 2: Executors (How)
  MetalVideoDecoder (ANE/GPU), MetalVideoEncoder (GPU), FFmpegExecutor (CPU)

TIER 3: Kernels (Where)
  ScaleFormatKernel.metal (YUV→RGB on GPU)
```

---

## Hardware Lane Scheduling

```
Request arrives: Decode H.264
  ├─ Check: ANE available? → Use MetalVideoDecoder (ANE)
  ├─ Check: GPU available? → Use MetalVideoDecoder (GPU)
  └─ Fallback: Use FFmpegExecutor (CPU)

Result: Automatic selection, no manual routing.
```

---

## Telemetry

Every operation emits heartbeat:
```
Decode started      → SaturatedHeartbeatPacket
GPU selected        → SaturatedHeartbeatPacket
Decode complete     → SaturatedHeartbeatPacket (12ms, GPU 45%)
```

Stored in `SaturatedLoggingRing` (lock-free).  
Consumed by: Observatorium dashboard, governance audit, performance analysis.

---

## Performance Comparison

| Operation | CPU (Old) | GPU (New) | Speedup |
|-----------|-----------|----------|---------|
| Decode H.264 | 25ms | 12ms (ANE) | 2.1x |
| Scale 1920→1280 | 50ms | 8ms | 6.3x |
| Encode VP9 | 40ms | 20ms | 2.0x |
| **Total** | **115ms** | **40ms** | **2.9x** |

---

## Code Structure (Phase 1)

```
Packages/ContractsCore/Sources/ContractsCore/Media/
├── MediaDecodeContract.swift       [Decode interface + types]
├── MediaEncodeContract.swift       [Encode interface + types]
├── ScaleFormatContract.swift       [Scale interface + types]
└── MediaTypes.swift                [PixelFormat, Codec, enums]

Tests/
└── MediaContractsTests/
    └── MediaContractTests.swift    [Contract tests + mock executor]
```

---

## Phase 1: Contracts (Week 1-2)

**Deliverables**:
- [ ] MediaDecodeContract (input schema, output schema, policy)
- [ ] MediaEncodeContract (same structure)
- [ ] ScaleFormatContract (same structure)
- [ ] MediaTypes enum (PixelFormat, Codec, etc.)
- [ ] Contract tests (mock executor, serialization)

**Acceptance**:
- ✓ Contracts compile
- ✓ Tests pass (mock executor)
- ✓ Protocols serializable (JSON/Protobuf)
- ✓ No async in contract layer

---

## Phase 2: Executors (Week 3-5)

**Deliverables**:
- [ ] MetalVideoDecoder (VideoToolbox + ANE/GPU)
- [ ] MetalVideoEncoder (GPU kernels)
- [ ] MetalScaleFormatter (Metal compute)
- [ ] FFmpegExecutor (CPU fallback)

**Acceptance**:
- ✓ Decode: 12ms (vs 25ms CPU)
- ✓ Scale: 8ms (vs 50ms CPU)
- ✓ All tests pass
- ✓ Fallback works if GPU unavailable

---

## Phase 3: Kernels (Week 6-7)

**Deliverables**:
- [ ] ScaleFormatKernel.metal (YUV420→RGB, bilinear scale)

**Acceptance**:
- ✓ GPU kernel compiles for M1/M2/M3
- ✓ Matches CPU output (golden test vectors)
- ✓ 6.3x faster than CPU

---

## Phase 4: Integration (Week 8-9)

**Deliverables**:
- [ ] Wire into ExecutionAuthority
- [ ] Hardware lane scheduling logic
- [ ] SaturatedHeartbeatPacket emission
- [ ] Governance receipts

**Acceptance**:
- ✓ Lane scheduler selects correct executor
- ✓ Telemetry appears in SaturatedLoggingRing
- ✓ Receipts recorded for governance

---

## Phase 5: Migration (Week 10)

**Deliverables**:
- [ ] Switch VideoRenderCapsule from old bridge
- [ ] Benchmark vs old bridge
- [ ] Deprecate old bridge

**Acceptance**:
- ✓ 2.9x faster transcode
- ✓ Full telemetry visible
- ✓ Zero regressions

---

## Key Files to Read

1. **FFMPEG_SATURATED_METAL_INTEGRATION.md** (Full Spec)
   - Tier 1-3 design
   - Code examples for all components
   - Integration points
   - Risk mitigation

2. **FFMPEG_SATURATED_ARCHITECTURE_DIAGRAMS.md** (Visuals)
   - Current vs proposed architecture
   - Data flow example
   - Lane decision tree
   - Metal kernel execution model

3. **FFMPEG_LINKING_ANALYSIS.md** (Why FFmpeg Is Hard)
   - Root causes of linking challenges
   - Solution options

---

## Decision Matrix

| Decision | Option A | Option B | Chosen |
|----------|----------|----------|--------|
| **GPU** | VideoToolbox | OpenGL | VideoToolbox ✓ |
| **Format conversion** | Metal kernel | swscale | Metal kernel ✓ |
| **Lane scheduling** | Automatic | Manual | Automatic ✓ |
| **Telemetry** | Heartbeats | Logging | Heartbeats ✓ |
| **Fallback** | Graceful | Fail | Graceful ✓ |

---

## What Success Looks Like

- ✅ Contracts defined, tested, documented
- ✅ Executors implemented, benchmarked
- ✅ Metal kernels compiled, verified
- ✅ Lane scheduler routing correctly
- ✅ Telemetry emitted for every operation
- ✅ 2.9x performance improvement measured
- ✅ Zero regressions
- ✅ Full observability in Observatorium dashboard
- ✅ Old bridge deprecated

---

## Blockers / Unknowns

- ⁉️ **VideoToolbox availability**: Confirmed (macOS 10.8+, public API)
- ⁉️ **Metal GPU availability**: Check at runtime; graceful fallback
- ⁉️ **Keep old bridge?**: Deprecate after Phase 5 verification
- ⁉️ **FFmpeg subprocess vs. linked?**: Design supports both; Phase 2 decision

---

## Resources

- VideoToolbox (VTDecompressionSession): https://developer.apple.com/documentation/videotoolbox
- Metal (compute kernels): https://developer.apple.com/documentation/metal
- SaturatedHeartbeatPacket: See SaturationKit sources
- ExecutionAuthority: See AnigmaCore sources
- HardwareLane: Defined in AnigmaPrimitives

---

## Contact / Questions

**Architecture**: See FFMPEG_SATURATED_METAL_INTEGRATION.md Sections 1-3  
**Design decisions**: See FFMPEG_SATURATED_ARCHITECTURE_DIAGRAMS.md (before/after comparison)  
**Why this matters**: See FFMPEG_SATURATED_EXECUTIVE_SUMMARY.md  
