# Cosine Similarity Capsule API Reference

**Header**: `anigma_cosine_similarity_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Thread Safety**: Thread-safe (stateless operations)

## Overview

The Cosine Similarity Capsule computes cosine similarity between vectors with high-performance SIMD optimizations. It supports single vector comparisons, batch operations (single query vs. multiple candidates), matrix operations (all-to-all similarity), and early stopping with threshold-based filtering. The capsule is designed for embedding similarity search in vector databases.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_cosine_similarity_capsule_t;
```

### Operation Mode Flags
```c
enum anigma_cosine_mode_t {
    ANIGMA_COSINE_MODE_SINGLE = 0,           // Single query, single candidate
    ANIGMA_COSINE_MODE_BATCH_QUERY = 1,      // Single query, multiple candidates
    ANIGMA_COSINE_MODE_BATCH_PAIRS = 2,      // Multiple query-candidate pairs
    ANIGMA_COSINE_MODE_SIMILARITY_MATRIX = 3 // All-to-all similarity matrix
};
```

### Precision Control Flags
```c
enum anigma_cosine_precision_t {
    ANIGMA_COSINE_PRECISION_SINGLE = 0,      // Single-precision (32-bit) floats
    ANIGMA_COSINE_PRECISION_DOUBLE = 1,      // Double-precision (64-bit) floats
    ANIGMA_COSINE_PRECISION_MIXED = 2        // Mixed precision (query FP32, candidates FP16/BF16)
};
```

### SIMD Optimization Flags
```c
enum anigma_cosine_simd_t {
    ANIGMA_COSINE_SIMD_AUTO = 0,             // Auto-detect best available
    ANIGMA_COSINE_SIMD_SSE = 1,              // SSE 4.2 (128-bit)
    ANIGMA_COSINE_SIMD_AVX2 = 2,             // AVX2 (256-bit)
    ANIGMA_COSINE_SIMD_AVX512 = 3,           // AVX-512 (512-bit)
    ANIGMA_COSINE_SIMD_NEON = 4,             // ARM NEON (128-bit)
    ANIGMA_COSINE_SIMD_SVE = 5,              // ARM SVE (scalable)
    ANIGMA_COSINE_SIMD_NONE = 6              // Scalar fallback
};
```

### Vector Layout Description
```c
struct anigma_cosine_vector_layout_t {
    size_t dimension;               // Vector dimension (must be > 0)
    size_t stride;                  // Stride between vector elements (in elements, not bytes)
    size_t alignment;               // Required alignment (0 = no specific alignment)
    enum anigma_cosine_precision_t precision; // Element precision
};
```

### Batch Operation Descriptor
```c
struct anigma_cosine_batch_descriptor_t {
    size_t count;                   // Number of vectors in batch
    const void* vectors;            // Pointer to first vector
    struct anigma_cosine_vector_layout_t layout; // Layout of vectors in batch
};
```

## Core Functions

### `anigma_cosine_similarity_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_cosine_similarity_capsule_get_identity(void);
```
Returns capsule identity information.

### `anigma_cosine_similarity_capsule_create`
```c
anigma_status_t anigma_cosine_similarity_capsule_create(
    anigma_cosine_similarity_capsule_t* out_handle,
    anigma_capsule_error_t* err
);
```
Creates a cosine similarity capsule context (future extensibility). For now, returns a placeholder handle; all functions work with null handle.

### `anigma_cosine_similarity_capsule_destroy`
```c
anigma_status_t anigma_cosine_similarity_capsule_destroy(
    anigma_cosine_similarity_capsule_t handle,
    anigma_capsule_error_t* err
);
```
Destroys a cosine similarity capsule context.

## Single Vector Operations

### `anigma_cosine_similarity_compute_single`
```c
anigma_status_t anigma_cosine_similarity_compute_single(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const void* candidate,
    const struct anigma_cosine_vector_layout_t* layout,
    float* out_similarity,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);
```
Computes cosine similarity between two single vectors.

**Parameters**:
- `handle`: Capsule handle (can be null for stateless operations)
- `query`: Query vector pointer
- `candidate`: Candidate vector pointer
- `layout`: Vector layout (both vectors must have same layout)
- `out_similarity`: Output similarity score [-1.0, 1.0]
- `simd`: SIMD optimization hint (use `ANIGMA_COSINE_SIMD_AUTO` for auto)
- `err`: Error output

**Determinism**: Tier 1 (bitwise identical across runs)  
**Thread safety**: Thread-safe (stateless)

## Batch Operations (Single Query, Multiple Candidates)

### `anigma_cosine_similarity_compute_batch`
```c
anigma_status_t anigma_cosine_similarity_compute_batch(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float* out_similarities,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);
```
Computes cosine similarities between one query vector and multiple candidates.

**Parameters**:
- `handle`: Capsule handle (can be null for stateless operations)
- `query`: Query vector pointer
- `candidates`: Batch descriptor for candidate vectors
- `out_similarities`: Output array of similarity scores (size = candidates.count)
- `simd`: SIMD optimization hint
- `err`: Error output

**Performance**: Optimized for SIMD vectorization across candidates  
**Memory**: Candidates can be stored with stride > dimension for packed arrays  
**Determinism**: Tier 1

### `anigma_cosine_similarity_compute_batch_threshold`
```c
anigma_status_t anigma_cosine_similarity_compute_batch_threshold(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float min_similarity,
    float* out_similarities,
    size_t* out_passed_count,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);
```
Computes cosine similarities with early stopping (top-k threshold). Similar to `compute_batch` but stops processing candidates below threshold.

**Parameters**:
- `min_similarity`: Minimum similarity threshold (candidates below threshold can be skipped)
- `out_similarities`: Output array (size = candidates.count, untested candidates set to -2.0)
- `out_passed_count`: Number of candidates passing threshold (optional, can be null)

**Optimization**: May use approximate early-exit optimizations

## Optimized Batch Operations with Precomputed Query Norm

### `anigma_cosine_similarity_precompute_query_norm`
```c
anigma_status_t anigma_cosine_similarity_precompute_query_norm(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const struct anigma_cosine_vector_layout_t* layout,
    float* out_query_norm,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);
```
Precomputes query norm for repeated batch operations. Useful when same query is compared against many candidate batches.

### `anigma_cosine_similarity_compute_batch_with_norm`
```c
anigma_status_t anigma_cosine_similarity_compute_batch_with_norm(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    float query_norm,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float* out_similarities,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);
```
Computes batch similarities using precomputed query norm. More efficient than `compute_batch` when query is reused.

## Matrix Operations (All-to-All Similarity)

### `anigma_cosine_similarity_compute_matrix`
```c
anigma_status_t anigma_cosine_similarity_compute_matrix(
    anigma_cosine_similarity_capsule_t handle,
    const struct anigma_cosine_batch_descriptor_t* queries,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float* out_matrix,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);
```
Computes similarity matrix between two sets of vectors. Result is row-major matrix [queries.count x candidates.count].

**Memory layout**: `out_matrix[i * candidates.count + j] = similarity(queries[i], candidates[j])`  
**Optimization**: Uses blocked matrix multiplication for cache efficiency

## Utility Functions

### `anigma_cosine_similarity_query_best_simd`
```c
enum anigma_cosine_simd_t anigma_cosine_similarity_query_best_simd(void);
```
Queries optimal SIMD level for current hardware. Returns best available SIMD capability.

### `anigma_cosine_similarity_query_performance`
```c
anigma_status_t anigma_cosine_similarity_query_performance(
    size_t dimension,
    size_t batch_size,
    enum anigma_cosine_simd_t simd,
    double* out_estimated_ops,
    anigma_capsule_error_t* err
);
```
Queries performance characteristics for given parameters. Returns estimated operations per second (approximate).

### `anigma_cosine_similarity_validate_layout`
```c
anigma_status_t anigma_cosine_similarity_validate_layout(
    const struct anigma_cosine_vector_layout_t* layout,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);
```
Validates vector layout and alignment. Returns `ANIGMA_OK` if layout is valid for given SIMD level.

## Error Handling

All functions return `anigma_status_t` with `ANIGMA_OK` (0) on success. Common error codes:

- `ANIGMA_ERR_INVALID_ARG`: Invalid argument (e.g., null pointer, zero dimension)
- `ANIGMA_ERR_MISALIGNED`: Memory not properly aligned for SIMD operations
- `ANIGMA_ERR_UNSUPPORTED`: Requested SIMD level not supported on current hardware

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Compute similarity between two vectors
func computeSimilarity(query: [Float], candidate: [Float]) throws -> Float {
    var similarity: Float = 0.0
    var error = anigma_capsule_error_t()
    
    let layout = anigma_cosine_vector_layout_t(
        dimension: query.count,
        stride: 1,
        alignment: 16,
        precision: ANIGMA_COSINE_PRECISION_SINGLE
    )
    
    let status = anigma_cosine_similarity_compute_single(
        nil, // stateless operation
        query,
        candidate,
        &layout,
        &similarity,
        ANIGMA_COSINE_SIMD_AUTO,
        &error
    )
    
    guard status == ANIGMA_OK else {
        throw CapsuleError(status: status, error: error)
    }
    
    return similarity
}

// Batch similarity search
func findTopMatches(query: [Float], candidates: [[Float]], topK: Int) throws -> [(index: Int, score: Float)] {
    var error = anigma_capsule_error_t()
    
    // Flatten candidates array
    let flatCandidates = candidates.flatMap { $0 }
    let candidateCount = candidates.count
    let dimension = query.count
    
    let layout = anigma_cosine_vector_layout_t(
        dimension: dimension,
        stride: dimension, // each candidate is contiguous
        alignment: 16,
        precision: ANIGMA_COSINE_PRECISION_SINGLE
    )
    
    let batchDescriptor = anigma_cosine_batch_descriptor_t(
        count: candidateCount,
        vectors: flatCandidates,
        layout: layout
    )
    
    var similarities = [Float](repeating: 0.0, count: candidateCount)
    
    let status = anigma_cosine_similarity_compute_batch(
        nil,
        query,
        &batchDescriptor,
        &similarities,
        ANIGMA_COSINE_SIMD_AUTO,
        &error
    )
    
    guard status == ANIGMA_OK else {
        throw CapsuleError(status: status, error: error)
    }
    
    // Find top-K matches
    let sorted = similarities.enumerated().sorted { $0.element > $1.element }
    return sorted.prefix(topK).map { (index: $0.offset, score: $0.element) }
}
```