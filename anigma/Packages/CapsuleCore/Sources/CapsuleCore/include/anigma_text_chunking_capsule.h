#ifndef ANIGMA_TEXT_CHUNKING_CAPSULE_H
#define ANIGMA_TEXT_CHUNKING_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Text Chunking Capsule Types
// ============================================================================

// Opaque handle for text chunking context
typedef anigma_capsule_handle_t anigma_text_chunking_capsule_t;

// Configuration structure
struct anigma_text_chunking_config_t {
    size_t target_chunk_size;   // Target chunk size in bytes (e.g., 512-4096)
    size_t min_chunk_size;      // Minimum allowed chunk size
    size_t max_chunk_size;      // Maximum allowed chunk size  
    size_t window_size;         // Rabin sliding window size (e.g., 48)
    uint64_t polynomial;        // Irreducible polynomial for Rabin fingerprinting
    uint32_t determinism_tier;  // ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
};

// Chunk boundary information
struct anigma_chunk_boundary_t {
    uint64_t offset;           // Start offset in bytes
    uint64_t length;           // Length in bytes
};

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get text chunking capsule identity.
 * Overrides the weak default implementation.
 */
anigma_capsule_identity_t anigma_text_chunking_capsule_get_identity(void);

/**
 * Create a text chunking capsule context with given configuration.
 */
anigma_status_t anigma_text_chunking_capsule_create(
    const struct anigma_text_chunking_config_t* config,
    anigma_text_chunking_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a text chunking capsule context.
 */
anigma_status_t anigma_text_chunking_capsule_destroy(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Streaming API
// ============================================================================

/**
 * Process bytes through the chunking capsule.
 * This is a streaming operation that maintains internal state.
 * 
 * @param handle Capsule handle
 * @param data Input data bytes
 * @param data_len Length of input data
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_text_chunking_capsule_process_bytes(
    anigma_text_chunking_capsule_t handle,
    const uint8_t* data,
    size_t data_len,
    anigma_capsule_error_t* err
);

/**
 * Finalize chunking and compute remaining boundaries.
 * Must be called after all input data has been processed.
 * 
 * @param handle Capsule handle
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_text_chunking_capsule_finalize(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
);

/**
 * Reset the chunking capsule state.
 * Allows reuse of the same handle for new input.
 * 
 * @param handle Capsule handle
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_text_chunking_capsule_reset(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Boundary Retrieval (Two-Phase Buffer Fill)
// ============================================================================

/**
 * Get the number of chunk boundaries detected so far.
 * 
 * @param handle Capsule handle
 * @param out_count Output count of boundaries
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_text_chunking_capsule_get_boundary_count(
    anigma_text_chunking_capsule_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
);

/**
 * Get chunk boundaries (offsets within the processed data).
 * Uses two-phase buffer fill pattern.
 * 
 * Phase 1: Call with out_offsets = NULL to get required size (in err->aux)
 * Phase 2: Allocate buffer and call again
 * 
 * @param handle Capsule handle
 * @param out_offsets Output array of start offsets (caller-allocated)
 * @param max_offsets Maximum number of offsets that can be stored
 * @param out_actual Actual number of offsets written
 * @param err Error output
 * 
 * @return ANIGMA_OK on success, ANIGMA_ERR_BUFFER_TOO_SMALL if buffer too small
 */
anigma_status_t anigma_text_chunking_capsule_get_boundaries(
    anigma_text_chunking_capsule_t handle,
    uint64_t* out_offsets,
    size_t max_offsets,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Get complete chunk information (offsets and lengths).
 * Similar two-phase pattern as get_boundaries.
 * 
 * @param handle Capsule handle
 * @param out_boundaries Output array of boundaries (caller-allocated)
 * @param max_boundaries Maximum number of boundaries that can be stored
 * @param out_actual Actual number of boundaries written
 * @param err Error output
 * 
 * @return ANIGMA_OK on success, ANIGMA_ERR_BUFFER_TOO_SMALL if buffer too small
 */
anigma_status_t anigma_text_chunking_capsule_get_chunk_info(
    anigma_text_chunking_capsule_t handle,
    struct anigma_chunk_boundary_t* out_boundaries,
    size_t max_boundaries,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

// ============================================================================
// One-Shot Convenience Functions
// ============================================================================

/**
 * One-shot chunking of a complete buffer.
 * Convenience function for small buffers that don't need streaming.
 * 
 * @param config Configuration (can be NULL for defaults)
 * @param input Input buffer descriptor
 * @param out_offsets Output array of offsets (caller-allocated)
 * @param max_offsets Maximum number of offsets that can be stored
 * @param out_actual Actual number of offsets written
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_text_chunking_capsule_chunk_buffer(
    const struct anigma_text_chunking_config_t* config,
    const anigma_capsule_buffer_t* input,
    uint64_t* out_offsets,
    size_t max_offsets,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

// ============================================================================
// Configuration and Utility Functions
// ============================================================================

/**
 * Get default configuration.
 * Returns recommended defaults for typical text chunking.
 */
struct anigma_text_chunking_config_t anigma_text_chunking_capsule_get_default_config(void);

/**
 * Validate configuration parameters.
 * Returns ANIGMA_OK if configuration is valid.
 */
anigma_status_t anigma_text_chunking_capsule_validate_config(
    const struct anigma_text_chunking_config_t* config,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_TEXT_CHUNKING_CAPSULE_H