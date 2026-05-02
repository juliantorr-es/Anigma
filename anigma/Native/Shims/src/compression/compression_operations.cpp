// ============================================================================
// Compression/Decompression Operations
// ============================================================================

#include "anigma_compression_capsule_impl.h"
#include "anigma_capsule_core.h"
#include <cstddef>
#include <cstdint>
#include <cstdlib>

// Missing ANIGMA constants - temporary definitions
#ifndef ANIGMA_ERR_INVALID_ARG
#define ANIGMA_ERR_INVALID_ARG 1
#endif
#ifndef ANIGMA_ERR_OUT_OF_MEMORY  
#define ANIGMA_ERR_OUT_OF_MEMORY 2
#endif
#ifndef ANIGMA_ERR_PROCESSING_FAILED
#define ANIGMA_ERR_PROCESSING_FAILED 3
#endif
#ifndef ANIGMA_ERR_UNSUPPORTED_FORMAT
#define ANIGMA_ERR_UNSUPPORTED_FORMAT 4
#endif
#ifndef ANIGMA_ERR_CORRUPTED_MEDIA
#define ANIGMA_ERR_CORRUPTED_MEDIA 5
#endif
#ifndef ANIGMA_ERR_BUFFER_TOO_SMALL
#define ANIGMA_ERR_BUFFER_TOO_SMALL 100
#endif
#ifndef ANIGMA_CAPSULE_BUFFER_CALLER_ALLOCATED_OUTPUT
#define ANIGMA_CAPSULE_BUFFER_CALLER_ALLOCATED_OUTPUT 2
#endif
#ifndef ANIGMA_OK
#define ANIGMA_OK 0
#endif

extern "C" {
    anigma_result_t anigma_compressor_create(anigma_ctx_t* ctx, anigma_compression_algo_t algo, anigma_compressor_t* out_handle);
    anigma_result_t anigma_compressor_compress(anigma_compressor_t handle, anigma_ctx_t* ctx, const uint8_t* in_data, size_t in_len, uint8_t** out_data, size_t* out_len);
    anigma_result_t anigma_compressor_decompress(anigma_compressor_t handle, anigma_ctx_t* ctx, const uint8_t* in_data, size_t in_len, uint8_t** out_data, size_t* out_len);
    anigma_result_t anigma_compressor_destroy(anigma_compressor_t handle);
}

anigma_status_t anigma_compression_capsule_compress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err) {
    
    if (!handle || !input || !output) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    
    if (!input->ptr || input->len == 0) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Input buffer is empty");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!output->ptr || output->capacity == 0) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Output buffer is invalid");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    size_t compressed_size = 0;
    anigma_status_t status = ANIGMA_OK;
    
    switch (ctx->algorithm) {
#ifdef HAVE_ZSTD
        case ANIGMA_COMPRESSION_ALGO_ZSTD: {
            compressed_size = ZSTD_compressCCtx(
                ctx->zstd_cctx,
                output->ptr, output->capacity,
                input->ptr, input->len,
                get_algorithm_level(ctx->algorithm, ctx->level)
            );
            
            if (ZSTD_isError(compressed_size)) {
                set_error_with_detail(err, ANIGMA_ERR_PROCESSING_FAILED,
                    "ZSTD compression failed", ZSTD_getErrorName(compressed_size));
                return ANIGMA_ERR_PROCESSING_FAILED;
            }
            break;
        }
#endif

#ifdef HAVE_BROTLI
        case ANIGMA_COMPRESSION_ALGO_BROTLI: {
            size_t available_out = output->capacity;
            uint8_t* next_out = output->ptr;
            const uint8_t* next_in = input->ptr;
            size_t available_in = input->len;
            
            BROTLI_BOOL result = BrotliEncoderCompressStream(
                ctx->brotli_enc,
                BROTLI_OPERATION_FINISH,
                &available_in, &next_in,
                &available_out, &next_out,
                nullptr
            );
            
            if (!result || available_in > 0) {
                set_error(err, ANIGMA_ERR_PROCESSING_FAILED, "Brotli compression failed");
                return ANIGMA_ERR_PROCESSING_FAILED;
            }
            
            compressed_size = output->capacity - available_out;
            break;
        }
#endif

#ifdef HAVE_LZ4
        case ANIGMA_COMPRESSION_ALGO_LZ4: {
            int compressed_bytes = 0;
            if (ctx->level == ANIGMA_COMPRESSION_LEVEL_BEST) {
                compressed_bytes = LZ4_compress_HC(
                    static_cast<const char*>(input->ptr),
                    static_cast<char*>(output->ptr),
                    input->len,
                    output->capacity,
                    get_algorithm_level(ctx->algorithm, ctx->level)
                );
            } else {
                compressed_bytes = LZ4_compress_default(
                    static_cast<const char*>(input->ptr),
                    static_cast<char*>(output->ptr),
                    input->len,
                    output->capacity
                );
            }
            
            if (compressed_bytes <= 0) {
                set_error(err, ANIGMA_ERR_PROCESSING_FAILED, "LZ4 compression failed");
                return ANIGMA_ERR_PROCESSING_FAILED;
            }
            
            compressed_size = compressed_bytes;
            break;
        }
#endif

        default:
            set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "Unsupported algorithm");
            return ANIGMA_ERR_UNSUPPORTED_FORMAT;
    }
    
    output->len = compressed_size;
    output->owner = ANIGMA_CAPSULE_BUFFER_CALLER;
    
    // Check if output buffer was too small
    if (compressed_size > output->capacity) {
        return ANIGMA_ERR_BUFFER_TOO_SMALL;
    }
    
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_decompress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err) {
    
    if (!handle || !input || !output) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    
    if (!input->ptr || input->len == 0) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Input buffer is empty");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!output->ptr || output->capacity == 0) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Output buffer is invalid");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    size_t decompressed_size = 0;
    anigma_status_t status = ANIGMA_OK;
    
    switch (ctx->algorithm) {
#ifdef HAVE_ZSTD
        case ANIGMA_COMPRESSION_ALGO_ZSTD: {
            // Use dictionary if available
            if (ctx->zstd_ddict) {
                decompressed_size = ZSTD_decompress_usingDDict(
                    ctx->zstd_dctx,
                    output->ptr, output->capacity,
                    input->ptr, input->len,
                    ctx->zstd_ddict
                );
            } else {
                decompressed_size = ZSTD_decompressDCtx(
                    ctx->zstd_dctx,
                    output->ptr, output->capacity,
                    input->ptr, input->len
                );
            }
            
            if (ZSTD_isError(decompressed_size)) {
                set_error_with_detail(err, ANIGMA_ERR_CORRUPTED_MEDIA,
                    "ZSTD decompression failed", ZSTD_getErrorName(decompressed_size));
                return ANIGMA_ERR_CORRUPTED_MEDIA;
            }
            break;
        }
#endif

#ifdef HAVE_BROTLI
        case ANIGMA_COMPRESSION_ALGO_BROTLI: {
            size_t available_out = output->capacity;
            uint8_t* next_out = output->ptr;
            const uint8_t* next_in = input->ptr;
            size_t available_in = input->len;
            
            BROTLI_BOOL result = BrotliDecoderDecompressStream(
                ctx->brotli_dec,  // Need to create decoder context
                &available_in, &next_in,
                &available_out, &next_out,
                nullptr
            );
            
            if (result == BROTLI_DECODER_RESULT_ERROR) {
                set_error(err, ANIGMA_ERR_CORRUPTED_MEDIA, "Brotli decompression failed");
                return ANIGMA_ERR_CORRUPTED_MEDIA;
            }
            
            decompressed_size = output->capacity - available_out;
            break;
        }
#endif

#ifdef HAVE_LZ4
        case ANIGMA_COMPRESSION_ALGO_LZ4: {
            int decompressed_bytes = LZ4_decompress_safe(
                static_cast<const char*>(input->ptr),
                static_cast<char*>(output->ptr),
                input->len,
                output->capacity
            );
            
            if (decompressed_bytes < 0) {
                set_error(err, ANIGMA_ERR_CORRUPTED_MEDIA, "LZ4 decompression failed");
                return ANIGMA_ERR_CORRUPTED_MEDIA;
            }
            
            decompressed_size = decompressed_bytes;
            break;
        }
#endif

        default:
            set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "Unsupported algorithm");
            return ANIGMA_ERR_UNSUPPORTED_FORMAT;
    }
    
    output->len = decompressed_size;
    output->owner = ANIGMA_CAPSULE_BUFFER_CALLER;
    
    // Check if output buffer was too small
    if (decompressed_size > output->capacity) {
        return ANIGMA_ERR_BUFFER_TOO_SMALL;
    }
    
    return ANIGMA_OK;
}

// ============================================================================
// Buffer Pool Management
// ============================================================================

anigma_status_t anigma_compression_capsule_acquire_buffer(
    anigma_compression_capsule_t handle,
    size_t size,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err) {
    
    if (!handle || !buffer) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    
    uint8_t* ptr = nullptr;
    anigma_status_t status = acquire_from_pool(&ctx->buffer_pool, size, &ptr);
    if (status != ANIGMA_OK) {
        set_error(err, status, "Failed to acquire buffer from pool");
        return status;
    }
    
    buffer->ptr = ptr;
    buffer->len = 0;
    buffer->capacity = size;
    buffer->owner = ANIGMA_CAPSULE_BUFFER_OWNED;
    
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_release_buffer(
    anigma_compression_capsule_t handle,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err) {
    
    if (!handle || !buffer) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    
    if (buffer->ptr && buffer->owner == ANIGMA_CAPSULE_BUFFER_OWNED) {
        release_to_pool(&ctx->buffer_pool, buffer->ptr);
    }
    
    // Clear buffer descriptor
    buffer->ptr = nullptr;
    buffer->len = 0;
    buffer->capacity = 0;
    buffer->owner = ANIGMA_CAPSULE_BUFFER_CALLER;
    
    return ANIGMA_OK;
}

// ============================================================================
// Utility Functions
// ============================================================================

anigma_status_t anigma_compression_capsule_estimate_compressed_size(
    anigma_compression_capsule_t handle,
    size_t input_size,
    size_t* out_estimated_size,
    anigma_capsule_error_t* err) {
    
    if (!handle || !out_estimated_size) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    
    // Conservative estimates for worst-case compression
    size_t estimated = input_size;  // Default to no compression
    
    switch (ctx->algorithm) {
#ifdef HAVE_ZSTD
        case ANIGMA_COMPRESSION_ALGO_ZSTD:
            estimated = ZSTD_compressBound(input_size);
            break;
#endif

#ifdef HAVE_BROTLI
        case ANIGMA_COMPRESSION_ALGO_BROTLI:
            // Brotli worst case is slightly larger than input
            estimated = input_size + (input_size / 100) + 1024;
            break;
#endif

#ifdef HAVE_LZ4
        case ANIGMA_COMPRESSION_ALGO_LZ4:
            // LZ4 worst case: overhead is 8 bytes + (input_size / 255) bytes
            estimated = input_size + 8 + (input_size / 255);
            break;
#endif

        default:
            set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "Unsupported algorithm");
            return ANIGMA_ERR_UNSUPPORTED_FORMAT;
    }
    
    *out_estimated_size = estimated;
    return ANIGMA_OK;
}

// ============================================================================
// Dictionary Training (Simplified Implementation)
// ============================================================================

anigma_status_t anigma_compression_capsule_train_dictionary(
    anigma_compression_capsule_t handle,
    const struct anigma_compression_dict_config_t* config,
    const anigma_capsule_buffer_t* samples,
    size_t sample_count,
    anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err) {
    
    if (!handle || !config || !samples || !dictionary || sample_count == 0) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    
    // This is a simplified implementation
    // In a production version, we would use the actual dictionary training APIs
    if (ctx->algorithm != ANIGMA_COMPRESSION_ALGO_ZSTD) {
        set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "Dictionary training only supported for ZSTD");
        return ANIGMA_ERR_UNSUPPORTED_FORMAT;
    }
    
#ifdef HAVE_ZSTD
    // Prepare sample buffers for ZSTD
    std::vector<const void*> sample_ptrs;
    std::vector<size_t> sample_sizes;
    
    for (size_t i = 0; i < sample_count; ++i) {
        if (samples[i].ptr && samples[i].len > 0) {
            sample_ptrs.push_back(samples[i].ptr);
            sample_sizes.push_back(samples[i].len);
        }
    }
    
    if (sample_ptrs.empty()) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "No valid samples provided");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    size_t dict_buffer_size = ZDICT_trainFromBuffer(
        dictionary->ptr, dictionary->capacity,
        sample_ptrs.data(), sample_sizes.data(),
        sample_ptrs.size()
    );
    
    if (ZDICT_isError(dict_buffer_size)) {
        set_error_with_detail(err, ANIGMA_ERR_PROCESSING_FAILED,
            "Dictionary training failed", ZDICT_getErrorName(dict_buffer_size));
        return ANIGMA_ERR_PROCESSING_FAILED;
    }
    
    dictionary->len = dict_buffer_size;
    dictionary->owner = ANIGMA_CAPSULE_BUFFER_CALLER;
    
    // Store dictionary in context for later use
    ctx->dictionary.resize(dict_buffer_size);
    std::memcpy(ctx->dictionary.data(), dictionary->ptr, dict_buffer_size);
    
    return ANIGMA_OK;
#else
    set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "ZSTD support not compiled in");
    return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
}

anigma_status_t anigma_compression_capsule_load_dictionary(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err) {
    
    if (!handle || !dictionary) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    
    if (ctx->algorithm != ANIGMA_COMPRESSION_ALGO_ZSTD) {
        set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "Dictionary loading only supported for ZSTD");
        return ANIGMA_ERR_UNSUPPORTED_FORMAT;
    }
    
#ifdef HAVE_ZSTD
    // Create compression dictionary
    if (ctx->zstd_cdict) {
        ZSTD_freeCDict(ctx->zstd_cdict);
        ctx->zstd_cdict = nullptr;
    }
    
    ctx->zstd_cdict = ZSTD_createCDict(
        dictionary->ptr, dictionary->len,
        get_algorithm_level(ctx->algorithm, ctx->level)
    );
    
    if (!ctx->zstd_cdict) {
        set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create compression dictionary");
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    // Create decompression dictionary
    if (ctx->zstd_ddict) {
        ZSTD_freeDDict(ctx->zstd_ddict);
        ctx->zstd_ddict = nullptr;
    }
    
    ctx->zstd_ddict = ZSTD_createDDict(dictionary->ptr, dictionary->len);
    
    if (!ctx->zstd_ddict) {
        set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create decompression dictionary");
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    // Store dictionary for later reference
    ctx->dictionary.resize(dictionary->len);
    std::memcpy(ctx->dictionary.data(), dictionary->ptr, dictionary->len);
    
    return ANIGMA_OK;
#else
    set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "ZSTD support not compiled in");
    return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
}

// ============================================================================
// Streaming API (Simplified Implementation)
// ============================================================================

anigma_status_t anigma_compression_capsule_begin_compress_stream(
    anigma_compression_capsule_t handle,
    anigma_capsule_handle_t* out_stream_handle,
    anigma_capsule_error_t* err) {
    
    if (!handle || !out_stream_handle) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    auto* stream = new anigma_compression_stream();
    
    if (!stream) {
        set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to allocate stream context");
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    anigma_status_t status = stream->initialize(ctx, true, err);
    if (status != ANIGMA_OK) {
        delete stream;
        return status;
    }
    
    *out_stream_handle = static_cast<anigma_capsule_handle_t>(stream);
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_compress_stream(
    anigma_capsule_handle_t stream_handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    bool flush,
    anigma_capsule_error_t* err) {
    
    if (!stream_handle || !input || !output) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* stream = static_cast<anigma_compression_stream*>(stream_handle);
    
    // This is a simplified implementation
    // In a full implementation, we would handle partial data and streaming properly
    return anigma_compression_capsule_compress(
        static_cast<anigma_compression_capsule_t>(stream->base_context),
        input, output, err);
}

anigma_status_t anigma_compression_capsule_end_compress_stream(
    anigma_capsule_handle_t stream_handle,
    anigma_capsule_error_t* err) {
    
    if (!stream_handle) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid stream handle");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* stream = static_cast<anigma_compression_stream*>(stream_handle);
    stream->cleanup();
    delete stream;
    
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_begin_decompress_stream(
    anigma_compression_capsule_t handle,
    anigma_capsule_handle_t* out_stream_handle,
    anigma_capsule_error_t* err) {
    
    if (!handle || !out_stream_handle) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    auto* stream = new anigma_compression_stream();
    
    if (!stream) {
        set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to allocate stream context");
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    anigma_status_t status = stream->initialize(ctx, false, err);
    if (status != ANIGMA_OK) {
        delete stream;
        return status;
    }
    
    *out_stream_handle = static_cast<anigma_capsule_handle_t>(stream);
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_decompress_stream(
    anigma_capsule_handle_t stream_handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err) {
    
    if (!stream_handle || !input || !output) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* stream = static_cast<anigma_compression_stream*>(stream_handle);
    
    // This is a simplified implementation
    return anigma_compression_capsule_decompress(
        static_cast<anigma_compression_capsule_t>(stream->base_context),
        input, output, err);
}

anigma_status_t anigma_compression_capsule_end_decompress_stream(
    anigma_capsule_handle_t stream_handle,
    anigma_capsule_error_t* err) {
    
    if (!stream_handle) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid stream handle");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* stream = static_cast<anigma_compression_stream*>(stream_handle);
    stream->cleanup();
    delete stream;
    
    return ANIGMA_OK;
}

} // extern "C"