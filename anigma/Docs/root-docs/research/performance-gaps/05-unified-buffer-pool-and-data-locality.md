> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Architectural Gap: Unified Buffer Pool and Data Locality

**Gap ID:** unified-buffer-pool  
**Severity:** High  
**Scope:** Memory management, zero-copy data movement

## Gap statement

The architecture still lets many components allocate and copy their own buffers. That creates a data-copy tax and weakens the performance gains from GPU/ANE acceleration. Harmonia V3 needs a unified buffer pool and a locality strategy.

## Research evidence

### Industry standards
- **Apple Core ML:** optimizes for CPU, GPU, and Neural Engine while minimizing memory footprint and power consumption.
- **Metal Performance Shaders:** is designed to work with Metal buffers and textures for efficient compute and graphics operations.

### Official documentation
- **Core ML docs:** emphasizes on-device performance and reduced memory footprint.
- **Metal Performance Shaders docs:** uses `MTLBuffer` and `MTLTexture` as core data structures.
- **PostgreSQL shared_buffers docs:** memory sizing matters; huge pages can reduce CPU time spent on memory management.

### Repo research
- `High_Performance_Inference.md` calls out unified memory advantages and the data copy tax.
- `Hardware_Saturation_Gap_Analysis.md` identifies unified buffer scarcity across capsules.

### Academic basis
- Cache locality and memory bandwidth are common bottlenecks in high-throughput systems.
- Zero-copy and page-aligned allocation reduce overhead when data moves across pipelines.

## Why it matters

Without a unified pool:

- every capsule pays allocation overhead
- data is copied across layers more than needed
- cache locality degrades under load
- GPU/ANE gains are canceled by host-side memory churn

## Recommended architectural response

Create a `HardwareBufferPool` / `UnifiedBufferPool` that:

- allocates page-aligned shared buffers
- tracks ownership and lifetime explicitly
- supports reuse across lanes and capsules
- avoids needless copies between Swift, C++, Metal, and ANE paths

Also define a locality policy:

- hot data stays near compute
- cold data moves to cheaper storage
- large shared buffers are reused, not reallocated

## Design constraints

- Buffer ownership must be deterministic.
- No capsule should bypass the pool for large hot-path payloads.
- The pool must be compatible with profiling and receipts.

## Acceptance criteria

- Hot-path buffers can be reused across capsules.
- Copy count is measurable and trending downward.
- Memory usage is stable under sustained load.
- GPU/ANE inputs are prepared without redundant host copies.