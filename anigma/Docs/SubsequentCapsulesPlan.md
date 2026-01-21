# Subsequent Capsules Plan for "Swift Governs, C++ Computes"

## Executive Summary

This document outlines the roadmap for the next five capsules in the "Swift governs, C++ computes" architecture, following the successful implementation of VectorCapsule and RankFusionCapsule. The plan addresses performance-critical operations currently implemented in Swift that would benefit from native C++ implementations, while maintaining strict determinism, thread safety, and zero‑copy marshalling.

The capsules are prioritized based on impact versus complexity, with lightweight capsules scheduled before heavyweight dependency‑laden ones. Each capsule will be delivered as a self‑contained C++ library with a C ABI, wrapped by a Swift actor that enforces governance and error handling.

## 1. Capsule‑by‑Capsule Analysis

### 1.1 LayoutEngineCapsule

**Current State**  
- PDF text extraction via CPDFium wrapper (`PDFiumProvider`)  
- Raw text extraction only; no spatial indexing or layout analysis  
- No bounding‑box extraction, column detection, or table recognition  

**Requirements**  
- Extract text with bounding boxes, font metrics, and layout hierarchy  
- Build spatial index (R‑tree or uniform grid) for fast region queries  
- Detect columns, paragraphs, tables, and figures  
- Output canonical representation suitable for receipt generation  

**Priority**: High (impact on document understanding, complexity moderate)  
**Dependencies**: Extend existing CPDFium wrapper; implement spatial index in C++ (no external library).  
**Implementation Approach**:
  1. Extend CPDFium wrapper to expose `FPDFText_GetCharBox` and font info  
  2. Implement R‑tree (or simple grid) for spatial queries  
  3. Add column detection algorithm (rule‑based + geometric clustering)  
  4. Export canonical binary format with bounding boxes and hierarchy  

**Performance Target**: 5–10× speedup for layout‑aware extraction vs. Swift‑side post‑processing.  
**Determinism Tier**: Tier 1 (bitwise identical across runs).  
**Integration Points**: `PDFiumProvider`, `DocumentRenderKit`, `ContextumModule` indexing pipeline.

### 1.2 ChunkingCapsule

**Current State**  
- Naïve line‑based sliding‑window chunking in Swift (`CLIIndexManager`)  
- Fixed‑size chunks with simple overlap; no content‑defined boundaries  
- Inefficient for large documents (>1 MB)  

**Requirements**  
- Content‑defined chunking (CDC) using Rabin fingerprinting  
- Streaming API for incremental chunking of large files  
- Configurable target chunk size (e.g., 512–4096 bytes) and minimum/maximum boundaries  
- Deterministic across runs and platforms  

**Priority**: High (impact on RAG quality and indexing speed, complexity low)  
**Dependencies**: None (pure C++ implementation of Rabin fingerprinting).  
**Implementation Approach**:
  1. Implement Rabin fingerprint rolling hash with irreducible polynomial  
  2. Sliding window detection of cut points based on hash modulo target size  
  3. Streaming API that consumes bytes and emits chunk boundaries  
  4. Swift wrapper that integrates with `CLIIndexManager` and `ContextumModule`

**Performance Target**: 10–100× speedup for >1 MB documents (CDC avoids per‑line overhead).  
**Determinism Tier**: Tier 1 (chunk boundaries must be identical across runs).  
**Integration Points**: `CLIIndexManager`, `ContextumModule` auto‑indexing workflow.

### 1.3 CompressionCapsule

**Current State**  
- Mock implementation in `CompressionKit`; real algorithms not integrated  
- Uses older `anigma_compressor_*` shim API (not capsule pattern)  
- No support for streaming, dictionary training, or buffer pooling  

**Requirements**  
- Real compression libraries: zstd, brotli, lz4  
- Streaming compression/decompression with buffer pooling  
- Dictionary training for domain‑specific data  
- Canonical format for receipt‑grade compression (deterministic output)  

**Priority**: Medium (high impact but moderate complexity due to external libraries)  
**Dependencies**: zstd, brotli, lz4 system libraries (or vendored source).  
**Implementation Approach**:
  1. Create capsule‑style C ABI that wraps each library’s streaming API  
  2. Implement buffer pooling to reduce allocations  
  3. Add deterministic mode (fixed parameters, no runtime optimizations) for Tier 1  
  4. Provide Swift wrapper that replaces `NativeCompressor` in `CompressionKit`

**Performance Target**: 2–5× speedup vs. Swift‑only mock; near‑native library speed.  
**Determinism Tier**: Tier 1 for canonical compression (fixed parameters), Tier 2 for optimized.  
**Integration Points**: `CompressionKit`, receipt serialization, artifact storage.

### 1.4 TextPipelineCapsule

**Current State**  
- Swift `String` operations with built‑in Unicode normalization  
- Basic tokenization via whitespace/simple splitting  
- No advanced Unicode support (grapheme clustering, NFKC, etc.)  

**Requirements**  
- Full Unicode normalization (NFD, NFC, NFKD, NFKC) via ICU  
- Grapheme cluster boundaries, word segmentation, sentence segmentation  
- Locale‑aware case folding and diacritic stripping  
- Deterministic across ICU versions (requires version‑locking)  

**Priority**: Medium (high complexity due to ICU dependency; impact on text quality)  
**Dependencies**: ICU library (≥ 70.1).  
**Implementation Approach**:
  1. Wrap ICU’s C API in a capsule with careful memory management  
  2. Provide operations: normalize, segment, fold, strip  
  3. Ensure deterministic output by fixing ICU version and configuration  
  4. Create Swift wrapper that gradually replaces Swift `String` operations in indexing pipeline  

**Performance Target**: 3–10× speedup for heavy Unicode workloads (large documents with mixed scripts).  
**Determinism Tier**: Tier 1 (must produce identical normalized bytes across runs).  
**Integration Points**: `ContextumModule` text preprocessing, `DiaplasionPipeline` normalization.

### 1.5 MediaFingerprintCapsule

**Current State**  
- Metadata‑based fingerprinting only (file hash, EXIF)  
- No perceptual hashing (pHash, dHash) or audio fingerprinting  

**Requirements**  
- Image perceptual hashing (pHash using DCT, dHash using gradient)  
- Audio fingerprinting (chromagram, spectral peaks)  
- Video key‑frame extraction and fingerprinting  
- Fast similarity search via Hamming distance  

**Priority**: Low (high complexity, niche use cases)  
**Dependencies**: FFmpeg/libav (decoding), OpenCV or stb_image for basic image ops.  
**Implementation Approach**:
  1. Use FFmpeg for decoding video/audio frames  
  2. Implement pHash (perceptual hash) and dHash (difference hash) in C++  
  3. Extract spectral features via FFT (KissFFT or similar)  
  4. Provide similarity scoring (Hamming distance, cosine similarity)  
  5. Create Swift wrapper for media‑deduplication workflows  

**Performance Target**: 10–50× speedup vs. Swift‑side decoding and processing.  
**Determinism Tier**: Tier 2 (epsilon‑stable; minor floating‑point differences acceptable).  
**Integration Points**: `ArtifactStoreModule` deduplication, `ObservatoriumModule` media analysis.

## 2. Dependency Management Plan

### 2.1 External Libraries

| Library | Purpose | License | Integration Strategy |
|---------|---------|---------|----------------------|
| ICU | Unicode normalization, segmentation | ICU License (permissive) | System‑wide installation via `apt`/`brew`; fallback to vendored source if missing. |
| zstd | Compression | BSD | System library preferred; vendored source as fallback. |
| brotli | Compression | MIT | System library preferred; vendored source as fallback. |
| lz4 | Compression | BSD | System library preferred; vendored source as fallback. |
| FFmpeg | Media decoding | LGPL/GPL | Dynamic linking to system FFmpeg (LGPL build). |
| OpenCV | Image processing | Apache 2 | Optional; can use stb_image + custom DCT for pHash. |

### 2.2 Build‑System Integration

- **Conditional Compilation**: Use `#if HAVE_ICU` etc. to compile capsules only when dependencies are present.  
- **Fallback Mechanisms**: If a capsule’s dependency is missing, the Swift wrapper will revert to existing Swift implementation (with a warning).  
- **Package.swift Updates**: Add system‑library targets for each dependency, similar to `CPDFium` and `CHarfBuzz`.  

### 2.3 Version Pinning

- Lock ICU to a specific major version (e.g., 70.x) to ensure determinism.  
- Use stable ABI versions of compression libraries (zstd ≥ 1.5, brotli ≥ 1.0).  
- Document exact version requirements in `Docs/Dependencies.md`.

## 3. Implementation Order

### Phase 1: Lightweight, High‑Impact Capsules (4–6 weeks)

1. **ChunkingCapsule** (2 weeks)  
   - No external dependencies, pure algorithm.  
   - Immediate performance gain for indexing.  
   - Low risk, high reward.

2. **LayoutEngineCapsule** (3 weeks)  
   - Extends existing CPDFium wrapper.  
   - Adds spatial indexing and column detection.  
   - Moderate risk (PDFium API complexity).

### Phase 2: Compression Capsule (3–4 weeks)

3. **CompressionCapsule** (3 weeks)  
   - Integrates zstd, brotli, lz4.  
   - Requires careful buffer‑pooling and streaming API.  
   - Medium risk (library integration, memory management).

### Phase 3: Heavyweight Dependencies (6–8 weeks)

4. **TextPipelineCapsule** (4 weeks)  
   - ICU integration is a “dependency gravity well.”  
   - Must ensure deterministic output and thread safety.  
   - High risk (ICU API complexity, version sensitivity).

5. **MediaFingerprintCapsule** (4 weeks)  
   - FFmpeg integration adds significant complexity.  
   - Optional; can be delayed if not critical.  
   - Highest risk (decoding stability, license compliance).

### Risk Assessment

| Capsule | Technical Risk | Dependency Risk | Mitigation |
|---------|---------------|-----------------|------------|
| ChunkingCapsule | Low | None | Unit‑test with golden corpus for deterministic boundaries. |
| LayoutEngineCapsule | Medium | Low (PDFium already integrated) | Reuse existing CPDFium wrapper; test on diverse PDFs. |
| CompressionCapsule | Medium | Medium (three libraries) | Start with zstd only; add others incrementally. |
| TextPipelineCapsule | High | High (ICU) | Isolate ICU behind a narrow C API; version‑lock ICU. |
| MediaFingerprintCapsule | High | High (FFmpeg) | Implement image‑only fingerprinting first; defer audio/video. |

## 4. Resource Requirements

### Development Time

- **ChunkingCapsule**: 2 engineer‑weeks  
- **LayoutEngineCapsule**: 3 engineer‑weeks  
- **CompressionCapsule**: 3 engineer‑weeks  
- **TextPipelineCapsule**: 4 engineer‑weeks  
- **MediaFingerprintCapsule**: 4 engineer‑weeks  
- **Integration & Testing**: 2 engineer‑weeks  
- **Total**: ~18 engineer‑weeks (4.5 calendar months with one engineer).

### External Library Integration Complexity

- **Low**: ChunkingCapsule, LayoutEngineCapsule (no new external deps).  
- **Medium**: CompressionCapsule (three well‑documented libraries).  
- **High**: TextPipelineCapsule (ICU API surface large).  
- **Very High**: MediaFingerprintCapsule (FFmpeg + OpenCV).

### Testing and Validation Needs

- **Golden‑corpus tests** for Tier 1 determinism (bitwise identical outputs).  
- **Performance benchmarks** comparing Swift baseline vs. capsule.  
- **Memory‑safety validation** (ASAN, UBSAN).  
- **Integration tests** with existing Swift workflows.

## 5. Documentation Deliverables

### 5.1 Capsule Specifications (Template)

Each capsule will have a specification document (`Docs/Capsules/<Name>Capsule.md`) containing:

- **Header File Draft**: Complete C API with determinism tier and error codes.  
- **Swift Wrapper Interface**: Actor‑based wrapper using `CapsuleHandle`.  
- **Performance Requirements**: Target speedup and memory budgets.  
- **Determinism Requirements**: Tier 1 or Tier 2, with validation procedure.  
- **Integration Example**: Code snippet showing typical usage.

### 5.2 Build System Updates

- **Package.swift modifications** adding system‑library targets for new dependencies.  
- **Conditional compilation flags** (`ANIGMA_HAVE_ICU`, `ANIGMA_HAVE_ZSTD`).  
- **Fallback implementation** stubs that log warnings and fall back to Swift.

### 5.3 Integration Strategy

- **Feature Flags**: Each capsule will be gated by a runtime flag (default on).  
- **Gradual Rollout**: Capsules will be deployed first in non‑critical paths (e.g., offline indexing).  
- **Migration Paths**: Swift implementations will remain as fallbacks until capsule is proven stable.

## 6. Next Steps

1. **Approve this plan** and allocate engineering resources.  
2. **Start Phase 1** with ChunkingCapsule specification and implementation.  
3. **Update Package.swift** with conditional dependencies for ICU, zstd, etc.  
4. **Establish golden‑corpus testing** framework for Tier 1 capsules.  
5. **Weekly review** of progress and risk assessment.

---

*Last updated: 2026‑01‑12*  
*Author: opencode*  
*Status: Draft for review*