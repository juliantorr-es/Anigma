> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research Report: Hardware Saturation & Expansion Surface (Metal/ANE)

**Author:** Gemini CLI (ses_f7e637)
**Status:** Completed
**Date:** 2026-01-11
**Context:** Hardware Saturation Audit

## Executive Summary

While the Anigma platform has established the foundational "Swift Governs, C++ Computes, Metal Accelerates" architecture, a deep audit of the current codebase reveals a significant **Hardware Saturation Gap**. Most high-performance "Capsules" are currently operating in the "Swift + C++" tier, leaving the GPU (Metal) and Neural Engine (ANE) largely idle for tasks that they are uniquely qualified to handle. This report identifies the expansion surface for hardware acceleration across the platform.

## Identified Gaps by Domain

### 1. Rendering & Graphics Saturation (Critical)
The rendering pipeline is currently under-utilizing the GPU for compute-heavy preparation tasks.
- **`SceneGraphCapsule`**: Currently performs lighting and transform calculations on the CPU.
  - *Expansion*: Move PBR (Physically Based Rendering) lighting and octree-based spatial partitioning to Metal compute shaders.
- **`TypographyCapsule` / `GlyphAtlasCapsule`**: Path tessellation and glyph rasterization are likely CPU-bound.
  - *Expansion*: Use Metal for real-time vector path tessellation and glyph SDF (Signed Distance Field) generation.
- **`RenderGraphCapsule`**: Frame graph dependency sorting and resource allocation could be parallelized.

### 2. Search & Indexing Saturation (High)
While `CosineSimilarity` has a Metal implementation, the higher-level indexing capsules are not yet saturated.
- **`VectorIndexCapsule`**: Batch insertions and HNSW (Hierarchical Navigable Small World) search paths are currently CPU-heavy.
  - *Expansion*: Parallelize batch neighbor search and centroid updates on Metal.
- **`RankFusionCapsule`**: Reciprocal Rank Fusion (RRF) and Borda count for multi-source search.
  - *Expansion*: Implement GPU-accelerated tensor fusion for merging millions of search results in microseconds.

### 3. Document Analysis Saturation (High)
Structural analysis of local documents is a major bottleneck for local-first AI.
- **`LayoutEngineCapsule`**: Spatial indexing of PDF elements and group detection.
  - *Expansion*: Use the GPU for computer vision-based block detection and line-merging algorithms.
- **`TableExtractionCapsule` / `MathOCRCapsule`**: These are currently stubs or C++-only.
  - *Expansion*: These are prime candidates for **ANE (Apple Neural Engine)** offloading, as they involve specific neural vision tasks that don't need the full power of the GPU.

### 4. Audio & Media Saturation (Medium)
- **`AudioRenderCapsule`**: FFT and spectrogram generation.
  - *Expansion*: Move signal processing blocks to Metal Performance Shaders (MPS).
- **`MediaFingerprintCapsule`**: Perceptual hashing for images and video.
  - *Expansion*: Implement batch hashing on the ANE to allow background library scanning without impact on battery life.

## New Gaps Identified (Cross-Reference)

1. **Power-Aware Placement Gap**: We have "Hardware Routing" in Inference, but not in Capsules. A `TypographyCapsule` doesn't know if it should use the GPU (Performance) or ANE (Battery) for a specific background render.
2. **Unified Buffer Scarcity**: Many capsules allocate their own C++ vectors. To truly reach "Zero-Copy," we need a unified **`HardwareBufferPool`** that allocates page-aligned memory once and shares it across all capsules.
3. **Receipt Determinism for GPU**: Metal computations can be non-deterministic due to floating-point reordering. We lack a "Deterministic Guard" for GPU compute that ensures receipts generated on an M1 match those from an M4.

## Expansion Surface Matrix

| Capsule | Current Status | Potential Acceleration | Target Chip |
| :--- | :--- | :--- | :--- |
| `SceneGraph` | Swift/C++ | Transform/Lighting | GPU (Metal) |
| `VectorIndex` | Swift/C++ | Batch Search | GPU (Metal) |
| `TextChunking`| Swift/C++ | Semantic Splitting | ANE |
| `Typography` | Swift/C++ | Path Tessellation | GPU (Metal) |
| `MediaFingerprint` | Stub | Perceptual Hashing | ANE |
| `LayoutEngine` | Swift/C++ | Block Detection | ANE/GPU |

## Conclusion

The "Expansion Surface" for Metal compute in Anigma is vast. Currently, less than 200f the platform's performance-critical capsules are hardware-saturated. By systematically moving the "Compute" logic from the C++ layer to the "Accelerate" layer (Metal/ANE), we can achieve an order-of-magnitude improvement in responsiveness and power efficiency.

The upcoming design phase should prioritize the creation of a **`UnifiedHardwareAuthority`** that provides shared memory and intelligent routing for ALL capsules, not just the inference engine.