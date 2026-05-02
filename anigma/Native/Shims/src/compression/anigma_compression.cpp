#include "anigma_compression.h"
#include <stdlib.h>
#include <string.h>

// Mock implementation for Phase 1 - simulating zstd/lz4 wrapping
// In a real implementation, this would link against libzstd.a / liblz4.a

struct anigma_compressor_s {
    anigma_compression_algo_t algo;
};

anigma_result_t anigma_compressor_create(
    anigma_ctx_t* ctx,
    anigma_compression_algo_t algo,
    anigma_compressor_t* out_handle
) {
    if (!out_handle) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Output handle pointer is null"};
    }
    
    struct anigma_compressor_s* comp = (struct anigma_compressor_s*) (void*)malloc(sizeof(struct anigma_compressor_s));
    if (!comp) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "Allocation failed"};
    }
    
    comp->algo = algo;
    *out_handle = comp;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_compressor_destroy(anigma_compressor_t handle) {
    if (handle) {
        free(handle);
    }
    return (anigma_result_t){ANIGMA_OK, NULL};
}

// Simple passthrough + header mock for demonstration
// Real impl would call ZSTD_compress, etc.
anigma_result_t anigma_compressor_compress(
    anigma_compressor_t handle,
    anigma_ctx_t* ctx,
    const uint8_t* in_data,
    size_t in_len,
    uint8_t** out_data,
    size_t* out_len
) {
    if (!handle || !in_data || !out_data || !out_len) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid arguments"};
    }
    
    // Simulate compression by adding a header
    size_t header_size = 4;
    size_t mock_compressed_len = in_len + header_size; // "Mock" so it grows
    
    uint8_t* buf = (uint8_t*) (void*)malloc(mock_compressed_len);
    if (!buf) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "Allocation failed"};
    }
    
    // Mock header
    buf[0] = 'M'; buf[1] = 'O'; buf[2] = 'C'; buf[3] = 'K';
    memcpy(buf + header_size, in_data, in_len);
    
    *out_data = buf;
    *out_len = mock_compressed_len;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_compressor_decompress(
    anigma_compressor_t handle,
    anigma_ctx_t* ctx,
    const uint8_t* in_data,
    size_t in_len,
    uint8_t** out_data,
    size_t* out_len
) {
    if (!handle || !in_data || !out_data || !out_len) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid arguments"};
    }
    
    if (in_len < 4) {
        return (anigma_result_t){ANIGMA_ERR_CORRUPT_DATA, "Data too short"};
    }
    
    // Check mock header
    if (in_data[0] != 'M' || in_data[1] != 'O' || in_data[2] != 'C' || in_data[3] != 'K') {
        return (anigma_result_t){ANIGMA_ERR_CORRUPT_DATA, "Invalid magic header"};
    }
    
    size_t header_size = 4;
    size_t decompressed_len = in_len - header_size;
    
    uint8_t* buf = (uint8_t*) (void*)malloc(decompressed_len);
    if (!buf) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "Allocation failed"};
    }
    
    memcpy(buf, in_data + header_size, decompressed_len);
    
    *out_data = buf;
    *out_len = decompressed_len;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}
