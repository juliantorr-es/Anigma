#include "anigma_compression_capsule.h"
#include "anigma_capsule_core.h"

#include <cstdint>
#include <cstring>
#include <vector>
#include <memory>

// ============================================================================
// Internal Implementation Details
// ============================================================================

namespace {

// Compression capsule internal state
struct CompressionCapsuleState {
    struct anigma_compression_config_t config;
    std::vector<uint8_t> buffer_pool;
    
    explicit CompressionCapsuleState(const struct anigma_compression_config_t* config)
        : config(*config)
    {
        if (config->buffer_pool_size > 0) {
            buffer_pool.reserve(config->buffer_pool_size);
        }
    }
};

// Mock compression implementation (to be replaced with real zstd/brotli/lz4)
size_t mockCompress(
    enum anigma_compression_algo_t algorithm,
    enum anigma_compression_mode_t mode,
    const uint8_t* input,
    size_t input_size,
    uint8_t* output,
    size_t output_capacity
) {
    // Simple mock: add algorithm-specific header
    size_t header_size = 8;
    
    if (output_capacity < input_size + header_size) {
        return 0; // Not enough space
    }
    
    // Write mock header
    output[0] = 'C';
    output[1] = 'M';
    output[2] = 'P';
    output[3] = static_cast<uint8_t>(algorithm);
    output[4] = static_cast<uint8_t>(mode);
    output[5] = (input_size >> 16) & 0xFF;
    output[6] = (input_size >> 8) & 0xFF;
    output[7] = input_size & 0xFF;
    
    // Copy data (mock compression - no actual compression)
    std::memcpy(output + header_size, input, input_size);
    
    return input_size + header_size;
}

size_t mockDecompress(
    enum anigma_compression_algo_t algorithm,
    const uint8_t* input,
    size_t input_size,
    uint8_t* output,
    size_t output_capacity
) {
    if (input_size < 8) {
        return 0; // Invalid header
    }
    
    // Check mock header
    if (input[0] != 'C' || input[1] != 'M' || input[2] != 'P') {
        return 0; // Invalid magic
    }
    
    uint8_t header_algo = input[3];
    if (header_algo != static_cast<uint8_t>(algorithm)) {
        return 0; // Algorithm mismatch
    }
    
    // Extract original size from header
    size_t original_size = (input[5] << 16) | (input[6] << 8) | input[7];
    
    if (output_capacity < original_size) {
        return 0; // Not enough space
    }
    
    // Copy data (mock decompression)
    size_t data_size = input_size - 8;
    if (data_size != original_size) {
        return 0; // Size mismatch
    }
    
    std::memcpy(output, input + 8, data_size);
    return data_size;
}

// Validate configuration parameters
bool validateConfig(const struct anigma_compression_config_t* config, anigma_capsule_error_t* err) {
    if (!config) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Configuration pointer is null";
        }
        return false;
    }
    
    if (config->algorithm > ANIGMA_COMPRESSION_ALGO_LZ4) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid compression algorithm";
        }
        return false;
    }
    
    if (config->mode > ANIGMA_COMPRESSION_MODE_OPTIMIZED) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid compression mode";
        }
        return false;
    }
    
    if (config->level > ANIGMA_COMPRESSION_LEVEL_BEST) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid compression level";
        }
        return false;
    }
    
    return true;
}

} // anonymous namespace

// ============================================================================
// Public API Implementation
// ============================================================================

anigma_capsule_identity_t anigma_compression_capsule_get_identity(void) {
    static const char* capsule_id = "compression_capsule";
    static const char* build_hash = "1.0.0-dev";
    static const char* algo_version = "1.0";
    
    return anigma_capsule_identity_t{
        capsule_id,
        build_hash,
        algo_version,
        ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

struct anigma_compression_config_t anigma_compression_capsule_get_default_config(
    enum anigma_compression_algo_t algorithm
) {
    return anigma_compression_config_t{
        .algorithm = algorithm,
        .mode = ANIGMA_COMPRESSION_MODE_STREAMING,
        .level = ANIGMA_COMPRESSION_LEVEL_DEFAULT,
        .buffer_pool_size = 64 * 1024,  // 64KB buffer pool
        .determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

anigma_status_t anigma_compression_capsule_validate_config(
    const struct anigma_compression_config_t* config,
    anigma_capsule_error_t* err
) {
    if (!validateConfig(config, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_create(
    const struct anigma_compression_config_t* config,
    anigma_compression_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!out_handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output handle pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!validateConfig(config, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        CompressionCapsuleState* state = new CompressionCapsuleState(config);
        *out_handle = static_cast<anigma_compression_capsule_t>(state);
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate compression capsule state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_compression_capsule_destroy(
    anigma_compression_capsule_t handle,
    anigma_capsule_error_t* err
) {
    (void)err;
    
    if (!handle) {
        return ANIGMA_OK;  // Destroying null handle is a no-op
    }
    
    try {
        CompressionCapsuleState* state = static_cast<CompressionCapsuleState*>(handle);
        delete state;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to destroy compression capsule state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_compression_capsule_compress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!input || !input->ptr) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Input buffer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!output) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output buffer descriptor is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        CompressionCapsuleState* state = static_cast<CompressionCapsuleState*>(handle);
        
        // Estimate required size (input size + header)
        size_t estimated_size = input->len + 64;  // Conservative estimate
        
        // Two-phase pattern: if output buffer too small, return required size
        if (!output->ptr || output->cap < estimated_size) {
            if (err) {
                err->code = ANIGMA_ERR_BUFFER_TOO_SMALL;
                err->aux = estimated_size;
                err->message = "Output buffer too small";
            }
            return ANIGMA_ERR_BUFFER_TOO_SMALL;
        }
        
        // Perform mock compression
        size_t compressed_size = mockCompress(
            state->config.algorithm,
            state->config.mode,
            input->ptr,
            input->len,
            output->ptr,
            output->cap
        );
        
        if (compressed_size == 0) {
            if (err) {
                err->code = ANIGMA_ERR_INTERNAL;
                err->message = "Compression failed";
            }
            return ANIGMA_ERR_INTERNAL;
        }
        
        output->len = compressed_size;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Compression operation failed";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_compression_capsule_decompress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!input || !input->ptr) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Input buffer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!output) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output buffer descriptor is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        CompressionCapsuleState* state = static_cast<CompressionCapsuleState*>(handle);
        
        // For decompression, we need to parse header to know required size
        if (input->len < 8) {
            if (err) {
                err->code = ANIGMA_ERR_CORRUPT_DATA;
                err->message = "Input too short for compression header";
            }
            return ANIGMA_ERR_CORRUPT_DATA;
        }
        
        // Extract size from mock header (last 3 bytes)
        size_t original_size = (input->ptr[5] << 16) | (input->ptr[6] << 8) | input->ptr[7];
        
        // Two-phase pattern: if output buffer too small, return required size
        if (!output->ptr || output->cap < original_size) {
            if (err) {
                err->code = ANIGMA_ERR_BUFFER_TOO_SMALL;
                err->aux = original_size;
                err->message = "Output buffer too small";
            }
            return ANIGMA_ERR_BUFFER_TOO_SMALL;
        }
        
        // Perform mock decompression
        size_t decompressed_size = mockDecompress(
            state->config.algorithm,
            input->ptr,
            input->len,
            output->ptr,
            output->cap
        );
        
        if (decompressed_size == 0) {
            if (err) {
                err->code = ANIGMA_ERR_CORRUPT_DATA;
                err->message = "Decompression failed - corrupt data";
            }
            return ANIGMA_ERR_CORRUPT_DATA;
        }
        
        output->len = decompressed_size;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Decompression operation failed";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

// ============================================================================
// Stub Implementations for Other Functions
// ============================================================================

anigma_status_t anigma_compression_capsule_begin_compress_stream(
    anigma_compression_capsule_t handle,
    anigma_capsule_handle_t* out_stream_handle,
    anigma_capsule_error_t* err
) {
    (void)handle;
    (void)out_stream_handle;
    
    if (err) {
        err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
        err->message = "Streaming compression not yet implemented";
    }
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

anigma_status_t anigma_compression_capsule_compress_stream(
    anigma_capsule_handle_t stream_handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    bool flush,
    anigma_capsule_error_t* err
) {
    (void)stream_handle;
    (void)input;
    (void)output;
    (void)flush;
    
    if (err) {
        err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
        err->message = "Streaming compression not yet implemented";
    }
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

anigma_status_t anigma_compression_capsule_end_compress_stream(
    anigma_capsule_handle_t stream_handle,
    anigma_capsule_error_t* err
) {
    (void)stream_handle;
    
    if (err) {
        err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
        err->message = "Streaming compression not yet implemented";
    }
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

anigma_status_t anigma_compression_capsule_begin_decompress_stream(
    anigma_compression_capsule_t handle,
    anigma_capsule_handle_t* out_stream_handle,
    anigma_capsule_error_t* err
) {
    (void)handle;
    (void)out_stream_handle;
    
    if (err) {
        err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
        err->message = "Streaming decompression not yet implemented";
    }
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

anigma_status_t anigma_compression_capsule_decompress_stream(
    anigma_capsule_handle_t stream_handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
) {
    (void)stream_handle;
    (void)input;
    (void)output;
    
    if (err) {
        err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
        err->message = "Streaming decompression not yet implemented";
    }
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

anigma_status_t anigma_compression_capsule_end_decompress_stream(
    anigma_capsule_handle_t stream_handle,
    anigma_capsule_error_t* err
) {
    (void)stream_handle;
    
    if (err) {
        err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
        err->message = "Streaming decompression not yet implemented";
    }
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

anigma_status_t anigma_compression_capsule_train_dictionary(
    anigma_compression_capsule_t handle,
    const struct anigma_compression_dict_config_t* config,
    const anigma_capsule_buffer_t* samples,
    size_t sample_count,
    anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err
) {
    (void)handle;
    (void)config;
    (void)samples;
    (void)sample_count;
    (void)dictionary;
    
    if (err) {
        err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
        err->message = "Dictionary training not yet implemented";
    }
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

anigma_status_t anigma_compression_capsule_load_dictionary(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err
) {
    (void)handle;
    (void)dictionary;
    
    if (err) {
        err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
        err->message = "Dictionary loading not yet implemented";
    }
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

anigma_status_t anigma_compression_capsule_acquire_buffer(
    anigma_compression_capsule_t handle,
    size_t size,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err
) {
    (void)handle;
    
    if (!buffer) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Buffer descriptor pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Simple allocation (no pooling yet)
    try {
        uint8_t* ptr = new uint8_t[size];
        buffer->ptr = ptr;
        buffer->len = 0;
        buffer->cap = size;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate buffer";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_compression_capsule_release_buffer(
    anigma_compression_capsule_t handle,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err
) {
    (void)handle;
    
    if (!buffer || !buffer->ptr) {
        return ANIGMA_OK;  // Nothing to release
    }
    
    try {
        delete[] buffer->ptr;
        buffer->ptr = nullptr;
        buffer->len = 0;
        buffer->cap = 0;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to release buffer";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_compression_capsule_estimate_compressed_size(
    anigma_compression_capsule_t handle,
    size_t input_size,
    size_t* out_estimated_size,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!out_estimated_size) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output size pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        CompressionCapsuleState* state = static_cast<CompressionCapsuleState*>(handle);
        
        // Conservative estimate: input size + overhead
        // Real implementation would use algorithm-specific estimation
        *out_estimated_size = input_size + 64;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to estimate compressed size";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}