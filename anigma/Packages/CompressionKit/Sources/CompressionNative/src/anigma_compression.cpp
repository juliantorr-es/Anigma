#include "anigma_compression_capsule.h"
#include <string.h>
#include <vector>
#include <mutex>
#include <memory>
#include <zstd.h>
#include <zdict.h>

// ============================================================================
// Internal Types
// ============================================================================

namespace {

/**
 * Handle types for internal registry.
 */
enum HandleType {
    HANDLE_TYPE_CAPSULE,
    HANDLE_TYPE_STREAM
};

/**
 * Common base for all opaque handles managed by this capsule.
 */
struct HandleBase {
    HandleType type;
    explicit HandleBase(HandleType t) : type(t) {}
    virtual ~HandleBase() = default;
};

/**
 * Represents a compression capsule instance.
 */
struct CompressionCapsule : public HandleBase {
    anigma_compression_config_t config;
    std::vector<uint8_t> dictionary;
    std::mutex mtx;

    // Buffer pool (simple implementation)
    struct PooledBuffer {
        uint8_t* ptr;
        size_t size;
    };
    std::vector<PooledBuffer> buffer_pool;

    explicit CompressionCapsule(const anigma_compression_config_t& cfg) 
        : HandleBase(HANDLE_TYPE_CAPSULE), config(cfg) {}

    ~CompressionCapsule() override {
        for (auto& buf : buffer_pool) {
            free(buf.ptr);
        }
    }
};

/**
 * Represents an active streaming operation.
 */
struct CompressionStream : public HandleBase {
    CompressionCapsule* capsule;
    bool is_compression;
    
    union {
        ZSTD_CStream* cstream;
        ZSTD_DStream* dstream;
    };

    CompressionStream(CompressionCapsule* cap, bool compress) 
        : HandleBase(HANDLE_TYPE_STREAM), capsule(cap), is_compression(compress) {
        if (is_compression) {
            cstream = ZSTD_createCStream();
            ZSTD_CCtx_setParameter(cstream, ZSTD_c_compressionLevel, cap->config.level == ANIGMA_COMPRESSION_LEVEL_BEST ? 9 : (cap->config.level == ANIGMA_COMPRESSION_LEVEL_FAST ? 1 : 3));
            if (cap->config.mode == ANIGMA_COMPRESSION_MODE_DETERMINISTIC) {
                // For Tier 1 determinism, we could set more parameters here if needed, 
                // but fixed level is usually enough for same zstd version.
            }
            if (!cap->dictionary.empty()) {
                ZSTD_CCtx_loadDictionary(cstream, cap->dictionary.data(), cap->dictionary.size());
            }
        } else {
            dstream = ZSTD_createDStream();
            if (!cap->dictionary.empty()) {
                ZSTD_DCtx_loadDictionary(dstream, cap->dictionary.data(), cap->dictionary.size());
            }
        }
    }

    ~CompressionStream() override {
        if (is_compression) {
            ZSTD_freeCStream(cstream);
        } else {
            ZSTD_freeDStream(dstream);
        }
    }
};

} // namespace

// ============================================================================
// Core Capsule Functions
// ============================================================================

extern "C" {

anigma_capsule_identity_t anigma_compression_capsule_get_identity(void) {
    return {
        "compression_capsule",
        "v1.5.7-zstd",
        "1.1.0",
        ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

anigma_status_t anigma_compression_capsule_create(
    const struct anigma_compression_config_t* config,
    anigma_compression_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!config || !out_handle) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_INVALID_ARG, "Invalid arguments", nullptr, 0);
        return ANIGMA_ERR_INVALID_ARG;
    }

    if (config->algorithm != ANIGMA_COMPRESSION_ALGO_ZSTD) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_NOT_IMPLEMENTED, "Only ZSTD is currently implemented", nullptr, 0);
        return ANIGMA_ERR_NOT_IMPLEMENTED;
    }

    auto capsule = new CompressionCapsule(*config);
    *out_handle = static_cast<anigma_compression_capsule_t>(capsule);
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_destroy(
    anigma_compression_capsule_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_OK;
    auto base = static_cast<HandleBase*>(handle);
    if (base->type != HANDLE_TYPE_CAPSULE) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_INVALID_ARG, "Handle is not a compression capsule", nullptr, 0);
        return ANIGMA_ERR_INVALID_ARG;
    }
    delete static_cast<CompressionCapsule*>(base);
    return ANIGMA_OK;
}

anigma_status_t anigma_capsule_destroy_handle(
    anigma_capsule_handle_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_OK;
    auto base = static_cast<HandleBase*>(handle);
    if (base->type == HANDLE_TYPE_STREAM) {
        delete static_cast<CompressionStream*>(base);
        return ANIGMA_OK;
    } else if (base->type == HANDLE_TYPE_CAPSULE) {
        return anigma_compression_capsule_destroy(handle, err);
    }
    
    if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_INVALID_ARG, "Unknown handle type", nullptr, 0);
    return ANIGMA_ERR_INVALID_ARG;
}

// ============================================================================
// Compression/Decompression Operations
// ============================================================================

anigma_status_t anigma_compression_capsule_compress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
) {
    if (!handle || !input || !output) return ANIGMA_ERR_INVALID_ARG;
    auto capsule = static_cast<CompressionCapsule*>(handle);

    size_t const bound = ZSTD_compressBound(input->len);
    if (output->cap < bound) {
        return anigma_capsule_query_output_size(err, bound);
    }

    int level = 3;
    if (capsule->config.level == ANIGMA_COMPRESSION_LEVEL_BEST) level = 9;
    else if (capsule->config.level == ANIGMA_COMPRESSION_LEVEL_FAST) level = 1;

    size_t cSize;
    if (capsule->dictionary.empty()) {
        cSize = ZSTD_compress(output->ptr, output->cap, input->ptr, input->len, level);
    } else {
        ZSTD_CCtx* const cctx = ZSTD_createCCtx();
        cSize = ZSTD_compress_usingDict(cctx, output->ptr, output->cap, input->ptr, input->len, capsule->dictionary.data(), capsule->dictionary.size(), level);
        ZSTD_freeCCtx(cctx);
    }

    if (ZSTD_isError(cSize)) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_PROCESSING_FAILED, ZSTD_getErrorName(cSize), nullptr, 0);
        return ANIGMA_ERR_PROCESSING_FAILED;
    }

    output->len = cSize;
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_decompress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
) {
    if (!handle || !input || !output) return ANIGMA_ERR_INVALID_ARG;
    auto capsule = static_cast<CompressionCapsule*>(handle);
    
    unsigned long long const rSize = ZSTD_getFrameContentSize(input->ptr, input->len);
    if (rSize == ZSTD_CONTENTSIZE_ERROR) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_CORRUPT_DATA, "Not a valid zstd frame", nullptr, 0);
        return ANIGMA_ERR_CORRUPT_DATA;
    }
    if (rSize != ZSTD_CONTENTSIZE_UNKNOWN && output->cap < rSize) {
        return anigma_capsule_query_output_size(err, (size_t)rSize);
    }

    size_t dSize;
    if (capsule->dictionary.empty()) {
        dSize = ZSTD_decompress(output->ptr, output->cap, input->ptr, input->len);
    } else {
        ZSTD_DCtx* const dctx = ZSTD_createDCtx();
        dSize = ZSTD_decompress_usingDict(dctx, output->ptr, output->cap, input->ptr, input->len, capsule->dictionary.data(), capsule->dictionary.size());
        ZSTD_freeDCtx(dctx);
    }

    if (ZSTD_isError(dSize)) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_PROCESSING_FAILED, ZSTD_getErrorName(dSize), nullptr, 0);
        return ANIGMA_ERR_PROCESSING_FAILED;
    }

    output->len = dSize;
    return ANIGMA_OK;
}

// ============================================================================
// Streaming API
// ============================================================================

anigma_status_t anigma_compression_capsule_begin_compress_stream(
    anigma_compression_capsule_t handle,
    anigma_capsule_handle_t* out_stream_handle,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_stream_handle) return ANIGMA_ERR_INVALID_ARG;
    auto capsule = static_cast<CompressionCapsule*>(handle);
    
    auto stream = new CompressionStream(capsule, true);
    *out_stream_handle = static_cast<anigma_capsule_handle_t>(stream);
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_compress_stream(
    anigma_capsule_handle_t stream_handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    bool flush,
    anigma_capsule_error_t* err
) {
    if (!stream_handle || !output) return ANIGMA_ERR_INVALID_ARG;
    auto stream = static_cast<CompressionStream*>(stream_handle);
    if (!stream->is_compression) return ANIGMA_ERR_INVALID_ARG;

    ZSTD_inBuffer in = { nullptr, 0, 0 };
    if (input) {
        in = { input->ptr, input->len, 0 };
    }

    ZSTD_outBuffer out = { output->ptr, output->cap, 0 };
    
    size_t const result = ZSTD_compressStream2(stream->cstream, &out, &in, flush ? ZSTD_e_end : ZSTD_e_continue);
    
    if (ZSTD_isError(result)) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_PROCESSING_FAILED, ZSTD_getErrorName(result), nullptr, 0);
        return ANIGMA_ERR_PROCESSING_FAILED;
    }

    output->len = out.pos;
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_begin_decompress_stream(
    anigma_compression_capsule_t handle,
    anigma_capsule_handle_t* out_stream_handle,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_stream_handle) return ANIGMA_ERR_INVALID_ARG;
    auto capsule = static_cast<CompressionCapsule*>(handle);
    
    auto stream = new CompressionStream(capsule, false);
    *out_stream_handle = static_cast<anigma_capsule_handle_t>(stream);
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_decompress_stream(
    anigma_capsule_handle_t stream_handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
) {
    if (!stream_handle || !output) return ANIGMA_ERR_INVALID_ARG;
    auto stream = static_cast<CompressionStream*>(stream_handle);
    if (stream->is_compression) return ANIGMA_ERR_INVALID_ARG;

    ZSTD_inBuffer in = { nullptr, 0, 0 };
    if (input) {
        in = { input->ptr, input->len, 0 };
    }

    ZSTD_outBuffer out = { output->ptr, output->cap, 0 };
    
    size_t const result = ZSTD_decompressStream(stream->dstream, &out, &in);
    
    if (ZSTD_isError(result)) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_PROCESSING_FAILED, ZSTD_getErrorName(result), nullptr, 0);
        return ANIGMA_ERR_PROCESSING_FAILED;
    }

    output->len = out.pos;
    return ANIGMA_OK;
}

// ============================================================================
// Dictionary Training
// ============================================================================

anigma_status_t anigma_compression_capsule_train_dictionary(
    anigma_compression_capsule_t handle,
    const struct anigma_compression_dict_config_t* config,
    const anigma_capsule_buffer_t* samples,
    size_t sample_count,
    anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err
) {
    if (!handle || !config || !samples || !dictionary) return ANIGMA_ERR_INVALID_ARG;
    
    std::vector<size_t> samplesSizes(sample_count);
    size_t totalSize = 0;
    for (size_t i = 0; i < sample_count; ++i) {
        samplesSizes[i] = samples[i].len;
        totalSize += samples[i].len;
    }

    std::vector<uint8_t> allSamples(totalSize);
    uint8_t* current = allSamples.data();
    for (size_t i = 0; i < sample_count; ++i) {
        memcpy(current, samples[i].ptr, samples[i].len);
        current += samples[i].len;
    }

    if (dictionary->cap < config->dictionary_size) {
        return anigma_capsule_query_output_size(err, config->dictionary_size);
    }

    size_t const dSize = ZDICT_trainFromBuffer(dictionary->ptr, dictionary->cap,
                                              allSamples.data(), samplesSizes.data(), (unsigned)sample_count);
    
    if (ZDICT_isError(dSize)) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_PROCESSING_FAILED, ZDICT_getErrorName(dSize), nullptr, 0);
        return ANIGMA_ERR_PROCESSING_FAILED;
    }

    dictionary->len = dSize;
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_load_dictionary(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err
) {
    if (!handle || !dictionary) return ANIGMA_ERR_INVALID_ARG;
    auto capsule = static_cast<CompressionCapsule*>(handle);
    
    std::lock_guard<std::mutex> lock(capsule->mtx);
    capsule->dictionary.assign(dictionary->ptr, dictionary->ptr + dictionary->len);
    return ANIGMA_OK;
}

// ============================================================================
// Buffer Pool Management
// ============================================================================

anigma_status_t anigma_compression_capsule_acquire_buffer(
    anigma_compression_capsule_t handle,
    size_t size,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err
) {
    if (!handle || !buffer) return ANIGMA_ERR_INVALID_ARG;
    auto capsule = static_cast<CompressionCapsule*>(handle);
    
    std::lock_guard<std::mutex> lock(capsule->mtx);
    for (auto it = capsule->buffer_pool.begin(); it != capsule->buffer_pool.end(); ++it) {
        if (it->size >= size) {
            buffer->ptr = it->ptr;
            buffer->len = 0;
            buffer->cap = it->size;
            capsule->buffer_pool.erase(it);
            return ANIGMA_OK;
        }
    }

    void* ptr = malloc(size);
    if (!ptr) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_OUT_OF_MEMORY, "Failed to allocate buffer", nullptr, size);
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }

    buffer->ptr = static_cast<uint8_t*>(ptr);
    buffer->len = 0;
    buffer->cap = size;
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_release_buffer(
    anigma_compression_capsule_t handle,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err
) {
    if (!handle || !buffer) return ANIGMA_ERR_INVALID_ARG;
    auto capsule = static_cast<CompressionCapsule*>(handle);
    
    std::lock_guard<std::mutex> lock(capsule->mtx);
    if (capsule->config.buffer_pool_size == 0 || capsule->buffer_pool.size() < capsule->config.buffer_pool_size) {
        capsule->buffer_pool.push_back({buffer->ptr, buffer->cap});
    } else {
        free(buffer->ptr);
    }
    
    buffer->ptr = nullptr;
    buffer->len = 0;
    buffer->cap = 0;
    return ANIGMA_OK;
}

// ============================================================================
// Utility Functions
// ============================================================================

struct anigma_compression_config_t anigma_compression_capsule_get_default_config(
    enum anigma_compression_algo_t algorithm
) {
    struct anigma_compression_config_t config;
    config.algorithm = algorithm;
    config.mode = ANIGMA_COMPRESSION_MODE_STREAMING;
    config.level = ANIGMA_COMPRESSION_LEVEL_DEFAULT;
    config.buffer_pool_size = 16;
    config.determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE;
    return config;
}

anigma_status_t anigma_compression_capsule_estimate_compressed_size(
    anigma_compression_capsule_t handle,
    size_t input_size,
    size_t* out_estimated_size,
    anigma_capsule_error_t* err
) {
    if (!out_estimated_size) return ANIGMA_ERR_INVALID_ARG;
    *out_estimated_size = ZSTD_compressBound(input_size);
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_validate_config(
    const struct anigma_compression_config_t* config,
    anigma_capsule_error_t* err
) {
    if (!config) return ANIGMA_ERR_INVALID_ARG;
    if (config->algorithm != ANIGMA_COMPRESSION_ALGO_ZSTD) {
        if (err) *err = anigma_capsule_make_error(ANIGMA_ERR_INVALID_ARG, "Unsupported algorithm", nullptr, 0);
        return ANIGMA_ERR_INVALID_ARG;
    }
    return ANIGMA_OK;
}

} // extern "C"
