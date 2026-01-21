#ifndef ANIGMA_COSINE_SIMILARITY_CAPSULE_H
#define ANIGMA_COSINE_SIMILARITY_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Cosine Similarity Capsule Types
// ============================================================================

// Opaque handle for cosine similarity context (future extensibility)
typedef anigma_capsule_handle_t anigma_cosine_similarity_capsule_t;

// Operation mode flags
enum anigma_cosine_mode_t {
    ANIGMA_COSINE_MODE_SINGLE = 0,           // Single query, single candidate
    ANIGMA_COSINE_MODE_BATCH_QUERY = 1,      // Single query, multiple candidates
    ANIGMA_COSINE_MODE_BATCH_PAIRS = 2,      // Multiple query-candidate pairs
    ANIGMA_COSINE_MODE_SIMILARITY_MATRIX = 3 // All-to-all similarity matrix
};

// Precision control flags
enum anigma_cosine_precision_t {
    ANIGMA_COSINE_PRECISION_SINGLE = 0,      // Single-precision (32-bit) floats
    ANIGMA_COSINE_PRECISION_DOUBLE = 1,      // Double-precision (64-bit) floats
    ANIGMA_COSINE_PRECISION_MIXED = 2        // Mixed precision (query FP32, candidates FP16/BF16)
};

// SIMD optimization flags
enum anigma_cosine_simd_t {
    ANIGMA_COSINE_SIMD_AUTO = 0,             // Auto-detect best available
    ANIGMA_COSINE_SIMD_SSE = 1,              // SSE 4.2 (128-bit)
    ANIGMA_COSINE_SIMD_AVX2 = 2,             // AVX2 (256-bit)
    ANIGMA_COSINE_SIMD_AVX512 = 3,           // AVX-512 (512-bit)
    ANIGMA_COSINE_SIMD_NEON = 4,             // ARM NEON (128-bit)
    ANIGMA_COSINE_SIMD_SVE = 5,              // ARM SVE (scalable)
    ANIGMA_COSINE_SIMD_NONE = 6              // Scalar fallback
};

// Vector layout description
struct anigma_cosine_vector_layout_t {
    size_t dimension;               // Vector dimension (must be > 0)
    size_t stride;                  // Stride between vector elements (in elements, not bytes)
    size_t alignment;               // Required alignment (0 = no specific alignment)
    enum anigma_cosine_precision_t precision; // Element precision
};

// Batch operation descriptor
struct anigma_cosine_batch_descriptor_t {
    size_t count;                   // Number of vectors in batch
    const void* vectors;            // Pointer to first vector
    struct anigma_cosine_vector_layout_t layout; // Layout of vectors in batch
};

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get cosine similarity capsule identity.
 * Overrides the weak default implementation.
 */
anigma_capsule_identity_t anigma_cosine_similarity_capsule_get_identity(void);

/**
 * Create a cosine similarity capsule context (future extensibility).
 * For now, returns a placeholder handle; all functions work with null handle.
 */
anigma_status_t anigma_cosine_similarity_capsule_create(
    anigma_cosine_similarity_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a cosine similarity capsule context.
 */
anigma_status_t anigma_cosine_similarity_capsule_destroy(
    anigma_cosine_similarity_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Single Vector Operations
// ============================================================================

/**
 * Compute cosine similarity between two single vectors.
 * 
 * @param handle Capsule handle (can be null for stateless operations)
 * @param query Query vector
 * @param candidate Candidate vector  
 * @param layout Vector layout (both vectors must have same layout)
 * @param out_similarity Output similarity score [-1.0, 1.0]
 * @param simd SIMD optimization hint (use ANIGMA_COSINE_SIMD_AUTO for auto)
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 * 
 * Determinism: Tier 1 (bitwise identical across runs)
 * Thread safety: Thread-safe (stateless)
 */
anigma_status_t anigma_cosine_similarity_compute_single(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const void* candidate,
    const struct anigma_cosine_vector_layout_t* layout,
    float* out_similarity,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);

// ============================================================================
// Batch Operations (Single Query, Multiple Candidates)
// ============================================================================

/**
 * Compute cosine similarities between one query vector and multiple candidates.
 * 
 * @param handle Capsule handle (can be null for stateless operations)
 * @param query Query vector
 * @param candidates Batch descriptor for candidate vectors
 * @param out_similarities Output array of similarity scores (size = candidates.count)
 * @param simd SIMD optimization hint
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 * 
 * Performance: Optimized for SIMD vectorization across candidates
 * Memory: Candidates can be stored with stride > dimension for packed arrays
 * Determinism: Tier 1
 */
anigma_status_t anigma_cosine_similarity_compute_batch(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float* out_similarities,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);

/**
 * Compute cosine similarities with early stopping (top-k threshold).
 * Similar to compute_batch but stops processing candidates below threshold.
 * 
 * @param handle Capsule handle
 * @param query Query vector
 * @param candidates Batch descriptor
 * @param min_similarity Minimum similarity threshold (candidates below threshold can be skipped)
 * @param out_similarities Output array (size = candidates.count, untested candidates set to -2.0)
 * @param out_passed_count Number of candidates passing threshold (optional, can be null)
 * @param simd SIMD optimization hint
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 * 
 * Optimization: May use approximate early-exit optimizations
 */
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

// ============================================================================
// Optimized Batch Operations with Precomputed Query Norm
// ============================================================================

/**
 * Precompute query norm for repeated batch operations.
 * Useful when same query is compared against many candidate batches.
 * 
 * @param handle Capsule handle
 * @param query Query vector
 * @param layout Vector layout
 * @param out_query_norm Output query norm (√(Σ query[i]²))
 * @param simd SIMD optimization hint
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_cosine_similarity_precompute_query_norm(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const struct anigma_cosine_vector_layout_t* layout,
    float* out_query_norm,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);

/**
 * Compute batch similarities using precomputed query norm.
 * More efficient than compute_batch when query is reused.
 * 
 * @param handle Capsule handle
 * @param query Query vector (must be same as used for precompute_query_norm)
 * @param query_norm Precomputed query norm
 * @param candidates Batch descriptor
 * @param out_similarities Output array
 * @param simd SIMD optimization hint
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_cosine_similarity_compute_batch_with_norm(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    float query_norm,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float* out_similarities,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);

// ============================================================================
// Matrix Operations (All-to-All Similarity)
// ============================================================================

/**
 * Compute similarity matrix between two sets of vectors.
 * Result is row-major matrix [queries.count x candidates.count].
 * 
 * @param handle Capsule handle
 * @param queries Batch descriptor for query vectors
 * @param candidates Batch descriptor for candidate vectors
 * @param out_matrix Output matrix (size = queries.count * candidates.count)
 * @param simd SIMD optimization hint
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 * 
 * Memory layout: out_matrix[i * candidates.count + j] = similarity(queries[i], candidates[j])
 * Optimization: Uses blocked matrix multiplication for cache efficiency
 */
anigma_status_t anigma_cosine_similarity_compute_matrix(
    anigma_cosine_similarity_capsule_t handle,
    const struct anigma_cosine_batch_descriptor_t* queries,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float* out_matrix,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Query optimal SIMD level for current hardware.
 * Returns best available SIMD capability.
 */
enum anigma_cosine_simd_t anigma_cosine_similarity_query_best_simd(void);

/**
 * Query performance characteristics for given parameters.
 * Returns estimated operations per second (approximate).
 * 
 * @param dimension Vector dimension
 * @param batch_size Number of vectors in batch
 * @param simd SIMD level to test
 * @param out_estimated_ops Output estimated operations/sec (can be null)
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_cosine_similarity_query_performance(
    size_t dimension,
    size_t batch_size,
    enum anigma_cosine_simd_t simd,
    double* out_estimated_ops,
    anigma_capsule_error_t* err
);

/**
 * Validate vector layout and alignment.
 * Returns ANIGMA_OK if layout is valid for given SIMD level.
 */
anigma_status_t anigma_cosine_similarity_validate_layout(
    const struct anigma_cosine_vector_layout_t* layout,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_COSINE_SIMILARITY_CAPSULE_H