#ifndef ANIGMA_COMPRESSION_CAPSULE_H
#define ANIGMA_COMPRESSION_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Compression Capsule Types
// ============================================================================

// Opaque handle for compression capsule context
typedef anigma_capsule_handle_t anigma_compression_capsule_t;

// Compression algorithm
enum anigma_compression_algo_t {
    ANIGMA_COMPRESSION_ALGO_ZSTD = 0,
    ANIGMA_COMPRESSION_ALGO_BROTLI = 1,
    ANIGMA_COMPRESSION_ALGO_LZ4 = 2
};

// Compression mode (determinism tier)
enum anigma_compression_mode_t {
    ANIGMA_COMPRESSION_MODE_STREAMING = 0,
    ANIGMA_COMPRESSION_MODE_DETERMINISTIC = 1,  // Tier 1 for receipts (fixed parameters)
    ANIGMA_COMPRESSION_MODE_OPTIMIZED = 2       // Tier 2 for performance
};

// Compression level (0 = default, higher = better compression but slower)
enum anigma_compression_level_t {
    ANIGMA_COMPRESSION_LEVEL_DEFAULT = 0,
    ANIGMA_COMPRESSION_LEVEL_FAST = 1,
    ANIGMA_COMPRESSION_LEVEL_BEST = 9
};

// Compression configuration
struct anigma_compression_config_t {
    enum anigma_compression_algo_t algorithm;
    enum anigma_compression_mode_t mode;
    enum anigma_compression_level_t level;
    size_t buffer_pool_size;           // Size of buffer pool (0 = no pooling)
    uint32_t determinism_tier;         // ANIGMA_DETERMINISM_TIER_* value
};

// Dictionary training configuration
struct anigma_compression_dict_config_t {
    size_t dictionary_size;            // Target dictionary size
    size_t min_sample_size;            // Minimum sample size
    size_t max_sample_size;            // Maximum sample size
    size_t max_samples;                // Maximum number of samples
};

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get compression capsule identity.
 * Overrides the weak default implementation.
 */
anigma_capsule_identity_t anigma_compression_capsule_get_identity(void);

/**
 * Create a compression capsule context with given configuration.
 */
anigma_status_t anigma_compression_capsule_create(
    const struct anigma_compression_config_t* config,
    anigma_compression_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a compression capsule context.
 */
anigma_status_t anigma_compression_capsule_destroy(
    anigma_compression_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Compression/Decompression Operations
// ============================================================================

/**
 * Compress data using streaming API.
 * Uses two-phase buffer fill pattern.
 * 
 * @param handle Capsule handle
 * @param input Input buffer descriptor
 * @param output Output buffer descriptor (caller-allocated with sufficient capacity)
 * @param err Error output
 * 
 * @return ANIGMA_OK on success, ANIGMA_ERR_BUFFER_TOO_SMALL if output buffer too small
 */
anigma_status_t anigma_compression_capsule_compress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);

/**
 * Decompress data using streaming API.
 * Uses two-phase buffer fill pattern.
 * 
 * @param handle Capsule handle
 * @param input Input buffer descriptor
 * @param output Output buffer descriptor (caller-allocated with sufficient capacity)
 * @param err Error output
 * 
 * @return ANIGMA_OK on success, ANIGMA_ERR_BUFFER_TOO_SMALL if output buffer too small
 */
anigma_status_t anigma_compression_capsule_decompress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);

// ============================================================================
// Streaming API (for Large Files)
// ============================================================================

/**
 * Begin a streaming compression operation.
 * Returns a stream handle for subsequent operations.
 */
anigma_status_t anigma_compression_capsule_begin_compress_stream(
    anigma_compression_capsule_t handle,
    anigma_capsule_handle_t* out_stream_handle,
    anigma_capsule_error_t* err
);

/**
 * Continue streaming compression.
 * 
 * @param stream_handle Stream handle from begin_compress_stream
 * @param input Input buffer descriptor (can be partial data)
 * @param output Output buffer descriptor (compressed data if any)
 * @param flush Whether to flush internal buffers
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_compression_capsule_compress_stream(
    anigma_capsule_handle_t stream_handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    bool flush,
    anigma_capsule_error_t* err
);

/**
 * End a streaming compression operation.
 */
anigma_status_t anigma_compression_capsule_end_compress_stream(
    anigma_capsule_handle_t stream_handle,
    anigma_capsule_error_t* err
);

/**
 * Begin a streaming decompression operation.
 */
anigma_status_t anigma_compression_capsule_begin_decompress_stream(
    anigma_compression_capsule_t handle,
    anigma_capsule_handle_t* out_stream_handle,
    anigma_capsule_error_t* err
);

/**
 * Continue streaming decompression.
 */
anigma_status_t anigma_compression_capsule_decompress_stream(
    anigma_capsule_handle_t stream_handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);

/**
 * End a streaming decompression operation.
 */
anigma_status_t anigma_compression_capsule_end_decompress_stream(
    anigma_capsule_handle_t stream_handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Dictionary Training
// ============================================================================

/**
 * Train a compression dictionary from sample data.
 * Useful for domain-specific compression optimization.
 * 
 * @param handle Capsule handle
 * @param config Dictionary training configuration
 * @param samples Array of sample buffers
 * @param sample_count Number of samples
 * @param dictionary Output dictionary buffer (caller-allocated with sufficient capacity)
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_compression_capsule_train_dictionary(
    anigma_compression_capsule_t handle,
    const struct anigma_compression_dict_config_t* config,
    const anigma_capsule_buffer_t* samples,
    size_t sample_count,
    anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err
);

/**
 * Load a compression dictionary for use with subsequent operations.
 */
anigma_status_t anigma_compression_capsule_load_dictionary(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err
);

// ============================================================================
// Buffer Pool Management
// ============================================================================

/**
 * Acquire a buffer from the capsule's buffer pool.
 * Reduces allocation overhead for repeated operations.
 * 
 * @param handle Capsule handle
 * @param size Requested buffer size
 * @param buffer Output buffer descriptor (pooled buffer)
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_compression_capsule_acquire_buffer(
    anigma_compression_capsule_t handle,
    size_t size,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err
);

/**
 * Release a buffer back to the capsule's buffer pool.
 */
anigma_status_t anigma_compression_capsule_release_buffer(
    anigma_compression_capsule_t handle,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err
);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Get default configuration for an algorithm.
 */
struct anigma_compression_config_t anigma_compression_capsule_get_default_config(
    enum anigma_compression_algo_t algorithm
);

/**
 * Estimate compressed size for given input.
 * Useful for buffer preallocation.
 * 
 * @param handle Capsule handle
 * @param input_size Input size in bytes
 * @param out_estimated_size Estimated compressed size
 * @param err Error output
 * 
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_compression_capsule_estimate_compressed_size(
    anigma_compression_capsule_t handle,
    size_t input_size,
    size_t* out_estimated_size,
    anigma_capsule_error_t* err
);

/**
 * Validate configuration parameters.
 * Returns ANIGMA_OK if configuration is valid.
 */
anigma_status_t anigma_compression_capsule_validate_config(
    const struct anigma_compression_config_t* config,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_COMPRESSION_CAPSULE_H