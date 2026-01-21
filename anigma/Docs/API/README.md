# C++ Compute Capsules API Documentation

## Overview

C++ Compute Capsules are native modules that provide high‑performance, deterministic computations for the Anigma platform. Each capsule follows the "Swift governs, C++ computes" architecture, exposing a C API for interoperability with Swift while maintaining thread safety and determinism guarantees.

All capsules share a common core interface defined in [`anigma_capsule_core.h`](../../Native/Shims/include/anigma_capsule_core.h).

## Available Capsules

| Capsule | Header | Description | Determinism |
|---------|--------|-------------|-------------|
| [Vector Capsule](./Capsules/VectorCapsule.md) | `anigma_vector_capsule.h` | 2D vector path operations (boolean geometry, SVG import/export) | Tier 1 (bitwise identical) |
| [Compression Capsule](./Capsules/CompressionCapsule.md) | `anigma_compression_capsule.h` | High‑performance compression/decompression (zstd, brotli, lz4) with streaming and dictionary training | Tier 1 (deterministic mode) |
| [Cosine Similarity Capsule](./Capsules/CosineSimilarityCapsule.md) | `anigma_cosine_similarity_capsule.h` | Cosine similarity computation with SIMD optimizations for embedding search | Tier 1 (bitwise identical) |
| [Layout Engine Capsule](./Capsules/LayoutEngineCapsule.md) | `anigma_layout_engine_capsule.h` | PDF layout analysis (text extraction, table detection, spatial indexing) | Tier 1 (bitwise identical) |
| [Rank Fusion Capsule](./Capsules/RankFusionCapsule.md) | `anigma_rank_fusion_capsule.h` | Reciprocal rank fusion (RRF) for merging multiple ranked lists | Tier 1 (bitwise identical) |
| [Text Chunking Capsule](./Capsules/TextChunkingCapsule.md) | `anigma_text_chunking_capsule.h` | Content‑defined chunking using Rabin fingerprinting for text deduplication | Tier 1 (bitwise identical) |
| [Viz Aggregation Capsule](./Capsules/VizAggregationCapsule.md) | `anigma_viz_aggregation_capsule.h` | Chart data preparation (filtering, grouping, aggregation, binning) | Tier 1 (bitwise identical) |
| [Viz LOD Tiling Capsule](./Capsules/VizLODTilingCapsule.md) | `anigma_viz_lod_tiling_capsule.h` | Level‑of‑detail tile pyramids for interactive charts at 60fps | Tier 1 (bitwise identical) |
| [Embedding Layout Capsule](./Capsules/EmbeddingLayoutCapsule.md) | `anigma_viz_embedding_layout_capsule.h` | Dimensionality reduction for embeddings (t‑SNE, UMAP, PCA) | Tier 1 (bitwise identical) |
| [Spatial Index Capsule](./Capsules/SpatialIndexCapsule.md) | `anigma_viz_spatial_index_capsule.h` | Deterministic spatial indexes (R‑tree, quadtree) for geometric data | Tier 1 (bitwise identical) |
| [Label Layout Capsule](./Capsules/LabelLayoutCapsule.md) | `anigma_viz_label_layout_capsule.h` | Non‑overlapping label placement for visualizations | Tier 1 (bitwise identical) |

## Common Patterns

### Two‑Phase Buffer Fill
Many capsule functions use a two‑phase buffer fill pattern to handle variable‑sized output:

1. **Phase 1**: Call with output buffer set to `NULL` to query required size (returned in `err->aux`)
2. **Phase 2**: Allocate buffer of the required size and call again with the buffer

Example:
```c
anigma_capsule_buffer_t output = { .ptr = NULL, .len = 0, .cap = 0 };
anigma_status_t status = capsule_function(handle, input, &output, &err);
if (status == ANIGMA_ERR_BUFFER_TOO_SMALL) {
    size_t required = err.aux;
    output.ptr = malloc(required);
    output.cap = required;
    status = capsule_function(handle, input, &output, &err);
}
```

### Error Handling
All capsule functions return an `anigma_status_t` code and can populate an `anigma_capsule_error_t` structure with details:
- `code`: Numeric error code (e.g., `ANIGMA_ERR_INVALID_ARG`)
- `message`: Human‑readable error message
- `detail`: Optional detailed error information
- `aux`: Optional auxiliary numeric data (e.g., required buffer size)

### Thread Safety
- Each capsule handle is thread‑safe for concurrent operations with distinct handles
- Most capsules are stateless or maintain internal synchronization
- The cosine similarity capsule is fully stateless and thread‑safe even with a null handle

### Determinism Tiers
- **Tier 1 (Receipt‑grade)**: Bitwise identical output across runs, machines, and operating systems (required for receipt generation)
- **Tier 2 (Canonical boundary)**: Canonical boundaries only, allowing runtime optimizations

## Swift Integration

Capsules are designed to be wrapped in Swift actors that manage handle lifecycle and provide a type‑safe interface. Example wrapper pattern:

```swift
import AnigmaNativeShims
import CapsuleCore

public actor VectorCapsuleWrapper {
    private var handle: CapsuleHandle<AnyObject>?
    
    public init(config: VectorConfig) throws {
        var rawHandle: anigma_vector_capsule_t?
        var error = anigma_capsule_error_t()
        let status = anigma_vector_capsule_create_from_svg(
            config.svgPath,
            &rawHandle,
            &error
        )
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        self.handle = CapsuleHandle(
            rawHandle: rawHandle,
            destroyFunction: anigma_vector_capsule_destroy
        )
    }
    
    deinit {
        handle?.invalidate()
    }
    
    // ... wrapper methods
}
```

## Building and Testing

Capsules are built as part of the Anigma native shims library. Refer to the [Build System Documentation](../architecture/BUILD.md) for details on compilation and integration.

## Further Reading

- [Capsule Core API](../../Native/Shims/include/anigma_capsule_core.h) – Common types and functions
- [Capsule Integration Strategy](../CapsuleIntegrationStrategy.md) – Architectural overview
- [Capsule Marshalling Gates](../CapsuleMarshallingGates.md) – Performance and safety considerations