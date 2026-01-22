#ifndef ANIGMA_RANK_FUSION_CAPSULE_H
#define ANIGMA_RANK_FUSION_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Rank Fusion Capsule Types
// ============================================================================

// Opaque handle for rank fusion context
typedef anigma_capsule_handle_t anigma_rank_fusion_capsule_t;

// ============================================================================
// Rank Fusion Types
// ============================================================================

// Fusion strategy types
typedef enum {
    ANIGMA_FUSION_STRATEGY_RRF = 1,           // Reciprocal Rank Fusion
    ANIGMA_FUSION_STRATEGY_WEIGHTED_SUM = 2, // Weighted sum normalization
    ANIGMA_FUSION_STRATEGY_HYBRID = 3          // Hybrid dense+sparse fusion
} anigma_fusion_strategy_t;

// Normalization methods
typedef enum {
    ANIGMA_NORMALIZATION_NONE = 1,               // No normalization
    ANIGMA_NORMALIZATION_MIN_MAX = 2,            // Min-max normalization to [0,1]
    ANIGMA_NORMALIZATION_Z_SCORE = 3,             // Z-score normalization
    ANIGMA_NORMALIZATION_RANK_BASED = 4,          // Rank-based normalization
} anigma_normalization_method_t;

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get rank fusion capsule identity.
 * Overrides the weak default implementation.
 */
anigma_capsule_identity_t anigma_rank_fusion_capsule_get_identity(void);

/**
 * Create a rank fusion capsule handle.
 */
anigma_status_t anigma_rank_fusion_capsule_create(
    anigma_rank_fusion_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a rank fusion capsule handle.
 */
anigma_status_t anigma_rank_fusion_capsule_destroy(
    anigma_rank_fusion_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Rank Fusion Operations
// ============================================================================

/**
 * Add a rank list to the fusion context.
 * 
 * @param handle Capsule handle
 * @param ids Array of chunk IDs (64-bit integers)
 * @param ranks Array of ranks (0-based positions)
 * @param count Number of items in arrays
 * @param err Error output
 * @return Status code
 */
anigma_status_t anigma_rank_fusion_capsule_add_rank_list(
    anigma_rank_fusion_capsule_t handle,
    const uint64_t* ids,
    const uint32_t* ranks,
    size_t count,
    anigma_capsule_error_t* err
);

/**
 * Perform reciprocal rank fusion (RRF) with k=60 parameter.
 * 
 * @param handle Capsule handle
 * @param k RRF constant (typically 60)
 * @param out_scores Buffer for output scores (caller-allocated)
 * @param out_ids Buffer for output IDs (caller-allocated)
 * @param max_results Maximum number of results to return
 * @param err Error output
 * @return Status code
 */
anigma_status_t anigma_rank_fusion_capsule_fuse(
    anigma_rank_fusion_capsule_t handle,
    uint32_t k,
    double* out_scores,
    uint64_t* out_ids,
    size_t max_results,
    anigma_capsule_error_t* err
);

/**
 * Perform reciprocal rank fusion and get top-K results.
 * This is a convenience function that combines fusion and top-K selection.
 * 
 * @param handle Capsule handle
 * @param k RRF constant (typically 60)
 * @param top_k Number of top results to return
 * @param out_scores Buffer for output scores (caller-allocated)
 * @param out_ids Buffer for output IDs (caller-allocated)
 * @param err Error output
 * @return Status code
 */
anigma_status_t anigma_rank_fusion_capsule_fuse_top_k(
    anigma_rank_fusion_capsule_t handle,
    uint32_t k,
    size_t top_k,
    double* out_scores,
    uint64_t* out_ids,
    anigma_capsule_error_t* err
);

/**
 * Perform advanced rank fusion with configurable strategy and normalization.
 */
anigma_status_t anigma_rank_fusion_capsule_fuse_advanced(
    anigma_rank_fusion_capsule_t* handle,
    anigma_fusion_strategy_t strategy,
    anigma_normalization_method_t normalization,
    uint32_t rrf_k,
    double* out_scores,
    uint64_t* out_ids,
    size_t max_results,
    anigma_capsule_error_t* err
);

/**
 * Clear all rank lists from the fusion context.
 */
anigma_status_t anigma_rank_fusion_capsule_clear(
    anigma_rank_fusion_capsule_t* handle,
    anigma_capsule_error_t* err
);

/**
 * Get the number of unique IDs across all rank lists.
 */
anigma_status_t anigma_rank_fusion_capsule_get_unique_count(
    anigma_rank_fusion_capsule_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_RANK_FUSION_CAPSULE_H