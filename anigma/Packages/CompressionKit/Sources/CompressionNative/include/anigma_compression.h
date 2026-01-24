#ifndef ANIGMA_COMPRESSION_SHIM_H
#define ANIGMA_COMPRESSION_SHIM_H

#include "anigma_native_common.h"
#include "anigma_compression_capsule.h"  // for enum anigma_compression_algo_t

#if defined(__cplusplus)
extern "C" {
#endif

// Provide backward‑compatibility macros for the old constant names
#define ANIGMA_COMPRESSION_ZSTD    ANIGMA_COMPRESSION_ALGO_ZSTD
#define ANIGMA_COMPRESSION_BROTLI  ANIGMA_COMPRESSION_ALGO_BROTLI
#define ANIGMA_COMPRESSION_LZ4     ANIGMA_COMPRESSION_ALGO_LZ4

// Provide a convenient typedef (capsule header only declares the enum)
typedef enum anigma_compression_algo_t anigma_compression_algo_t;

// Opaque handle for a compressor instance (holds state, dicts, etc.)
typedef struct anigma_compressor_s* anigma_compressor_t;

/**
 * Create a compressor instance.
 */
anigma_result_t anigma_compressor_create(
    anigma_ctx_t* ctx,
    anigma_compression_algo_t algo,
    anigma_compressor_t* out_handle
);

/**
 * Destroy a compressor instance.
 */
anigma_result_t anigma_compressor_destroy(anigma_compressor_t handle);

/**
 * Compress data.
 * Output buffer (*out_data) is allocated by the shim and must be freed with anigma_free_buffer.
 */
anigma_result_t anigma_compressor_compress(
    anigma_compressor_t handle,
    anigma_ctx_t* ctx,
    const uint8_t* in_data,
    size_t in_len,
    uint8_t** out_data,
    size_t* out_len
);

/**
 * Decompress data.
 * Output buffer (*out_data) is allocated by the shim and must be freed with anigma_free_buffer.
 */
anigma_result_t anigma_compressor_decompress(
    anigma_compressor_t handle,
    anigma_ctx_t* ctx,
    const uint8_t* in_data,
    size_t in_len,
    uint8_t** out_data,
    size_t* out_len
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_COMPRESSION_SHIM_H
