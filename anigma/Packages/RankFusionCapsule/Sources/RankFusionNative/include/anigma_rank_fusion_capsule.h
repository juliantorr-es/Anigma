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
 * Clear all rank lists from the fusion context.
 */
anigma_status_t anigma_rank_fusion_capsule_clear(
    anigma_rank_fusion_capsule_t handle,
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