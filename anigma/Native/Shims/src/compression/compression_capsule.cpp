#include "anigma_compression_capsule_impl.h"
#include <cstring>
#include <algorithm>
#include <chrono>

// ============================================================================
// Helper Functions
// ============================================================================

static void set_error(anigma_capsule_error_t* err, anigma_status_t code, const char* message) {
    if (!err) return;
    err->code = code;
    err->message = message;
    err->detail = nullptr;
    err->aux = 0;
}

static void set_error_with_detail(anigma_capsule_error_t* err, anigma_status_t code, 
                              const char* message, const char* detail, uint64_t aux = 0) {
    if (!err) return;
    err->code = code;
    err->message = message;
    err->detail = detail;
    err->aux = aux;
}

// Convert compression level to algorithm-specific level
static int get_algorithm_level(enum anigma_compression_algo_t algo, 
                           enum anigma_compression_level_t level) {
    switch (algo) {
#ifdef HAVE_ZSTD
        case ANIGMA_COMPRESSION_ALGO_ZSTD:
            switch (level) {
                case ANIGMA_COMPRESSION_LEVEL_FAST: return 1;
                case ANIGMA_COMPRESSION_LEVEL_DEFAULT: return 3;
                case ANIGMA_COMPRESSION_LEVEL_BEST: return 15;
                default: return 3;
            }
#endif
#ifdef HAVE_BROTLI
        case ANIGMA_COMPRESSION_ALGO_BROTLI:
            switch (level) {
                case ANIGMA_COMPRESSION_LEVEL_FAST: return 1;
                case ANIGMA_COMPRESSION_LEVEL_DEFAULT: return 4;
                case ANIGMA_COMPRESSION_LEVEL_BEST: return 11;
                default: return 4;
            }
#endif
#ifdef HAVE_LZ4
        case ANIGMA_COMPRESSION_ALGO_LZ4:
            switch (level) {
                case ANIGMA_COMPRESSION_LEVEL_FAST: return 1;
                case ANIGMA_COMPRESSION_LEVEL_DEFAULT: return 9;
                case ANIGMA_COMPRESSION_LEVEL_BEST: return 12;
                default: return 9;
            }
#endif
        default:
            return 0;
    }
}

// ============================================================================
// Buffer Pool Implementation
// ============================================================================

static uint64_t get_timestamp() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

static anigma_status_t acquire_from_pool(struct buffer_pool* pool, size_t size, 
                                     uint8_t** out_ptr) {
    std::lock_guard<std::mutex> lock(pool->mutex);
    
    // Try to find a suitable buffer
    for (auto& entry : pool->entries) {
        if (entry.size >= size) {
            *out_ptr = entry.ptr;
            entry.last_used = get_timestamp();
            return ANIGMA_OK;
        }
    }
    
    // Allocate new buffer if within pool limits
    if (pool->max_pool_size > 0 && 
        pool->total_allocated + size > pool->max_pool_size) {
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    uint8_t* ptr = static_cast<uint8_t*>(std::malloc(size));
    if (!ptr) {
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    // Add to pool
    buffer_pool::pool_entry entry;
    entry.ptr = ptr;
    entry.size = size;
    entry.last_used = get_timestamp();
    pool->entries.push_back(entry);
    pool->total_allocated += size;
    
    *out_ptr = ptr;
    return ANIGMA_OK;
}

static void release_to_pool(struct buffer_pool* pool, uint8_t* ptr) {
    if (!ptr) return;
    
    std::lock_guard<std::mutex> lock(pool->mutex);
    // Don't actually free - keep in pool for reuse
    // In a full implementation, we might implement LRU eviction
}

// ============================================================================
// anigma_compression_context Implementation
// ============================================================================

anigma_compression_context::anigma_compression_context()
    : algorithm(ANIGMA_COMPRESSION_ALGO_ZSTD)
    , mode(ANIGMA_COMPRESSION_MODE_STREAMING)
    , level(ANIGMA_COMPRESSION_LEVEL_DEFAULT)
    , determinism_tier(1)
    , buffer_pool_size(0)
#ifdef HAVE_ZSTD
    , zstd_cctx(nullptr)
    , zstd_dctx(nullptr)
    , zstd_cdict(nullptr)
    , zstd_ddict(nullptr)
#endif
#ifdef HAVE_BROTLI
    , brotli_enc(nullptr)
#endif
#ifdef HAVE_LZ4
    , lz4_stream(nullptr)
    , lz4hc_stream(nullptr)
#endif
{
    buffer_pool.entries.clear();
    buffer_pool.max_pool_size = buffer_pool_size;
    buffer_pool.total_allocated = 0;
}

anigma_compression_context::~anigma_compression_context() {
    cleanup();
}

anigma_status_t anigma_compression_context::initialize(
    const anigma_compression_config_t* config, 
    anigma_capsule_error_t* err) {
    
    if (!config) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Configuration is null");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    algorithm = config->algorithm;
    mode = config->mode;
    level = config->level;
    determinism_tier = config->determinism_tier;
    buffer_pool.max_pool_size = config->buffer_pool_size;
    
    // Initialize algorithm-specific contexts
    switch (algorithm) {
#ifdef HAVE_ZSTD
        case ANIGMA_COMPRESSION_ALGO_ZSTD: {
            zstd_cctx = ZSTD_createCCtx();
            zstd_dctx = ZSTD_createDCtx();
            
            if (!zstd_cctx || !zstd_dctx) {
                set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create ZSTD contexts");
                return ANIGMA_ERR_OUT_OF_MEMORY;
            }
            
            // Set compression parameters based on determinism tier
            int algo_level = get_algorithm_level(algorithm, level);
            if (determinism_tier == 1) {
                // Use deterministic parameters for Tier 1
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_compressionLevel, algo_level);
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_checksumFlag, 1);
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_contentSizeFlag, 1);
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_dictIDFlag, 1);
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_enableLongDistanceMatching, 0);
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_enableDedicatedDictSearch, 0);
            } else {
                // Use optimized parameters for Tier 2
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_compressionLevel, algo_level);
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_checksumFlag, 0);
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_enableLongDistanceMatching, 1);
            }
            break;
        }
#endif

#ifdef HAVE_BROTLI
        case ANIGMA_COMPRESSION_ALGO_BROTLI: {
            brotli_enc = BrotliEncoderCreateInstance(nullptr, nullptr, nullptr);
            if (!brotli_enc) {
                set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create Brotli encoder");
                return ANIGMA_ERR_OUT_OF_MEMORY;
            }
            
            int algo_level = get_algorithm_level(algorithm, level);
            BrotliEncoderSetParameter(brotli_enc, BROTLI_PARAM_QUALITY, algo_level);
            BrotliEncoderSetParameter(brotli_enc, BROTLI_PARAM_LGWIN, 22);
            BrotliEncoderSetParameter(brotli_enc, BROTLI_PARAM_SIZE_HINT, 0);
            
            if (determinism_tier == 1) {
                // Deterministic settings
                BrotliEncoderSetParameter(brotli_enc, BROTLI_PARAM_MODE, BROTLI_MODE_GENERIC);
                BrotliEncoderSetParameter(brotli_enc, BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING, 1);
            }
            break;
        }
#endif

#ifdef HAVE_LZ4
        case ANIGMA_COMPRESSION_ALGO_LZ4: {
            if (level == ANIGMA_COMPRESSION_LEVEL_BEST) {
                lz4hc_stream = LZ4_createStreamHC();
                if (!lz4hc_stream) {
                    set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create LZ4HC stream");
                    return ANIGMA_ERR_OUT_OF_MEMORY;
                }
            } else {
                lz4_stream = LZ4_createStream();
                if (!lz4_stream) {
                    set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create LZ4 stream");
                    return ANIGMA_ERR_OUT_OF_MEMORY;
                }
            }
            break;
        }
#endif

        default:
            set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "Unsupported compression algorithm");
            return ANIGMA_ERR_UNSUPPORTED_FORMAT;
    }
    
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_context::cleanup() {
    // Cleanup algorithm-specific contexts
#ifdef HAVE_ZSTD
    if (zstd_cctx) ZSTD_freeCCtx(zstd_cctx);
    if (zstd_dctx) ZSTD_freeDCtx(zstd_dctx);
    if (zstd_cdict) ZSTD_freeCDict(zstd_cdict);
    if (zstd_ddict) ZSTD_freeDDict(zstd_ddict);
    zstd_cctx = nullptr;
    zstd_dctx = nullptr;
    zstd_cdict = nullptr;
    zstd_ddict = nullptr;
#endif

#ifdef HAVE_BROTLI
    if (brotli_enc) BrotliEncoderDestroyInstance(brotli_enc);
    brotli_enc = nullptr;
#endif

#ifdef HAVE_LZ4
    if (lz4_stream) LZ4_freeStream(static_cast<LZ4_stream_t*>(lz4_stream));
    if (lz4hc_stream) LZ4_freeStreamHC(static_cast<LZ4_streamHC_t*>(lz4hc_stream));
    lz4_stream = nullptr;
    lz4hc_stream = nullptr;
#endif

    // Cleanup buffer pool
    for (auto& entry : buffer_pool.entries) {
        std::free(entry.ptr);
    }
    buffer_pool.entries.clear();
    buffer_pool.total_allocated = 0;
    
    return ANIGMA_OK;
}

// ============================================================================
// anigma_compression_stream Implementation
// ============================================================================

anigma_compression_stream::anigma_compression_stream()
    : base_context(nullptr)
    , algorithm(ANIGMA_COMPRESSION_ALGO_ZSTD)
    , is_compressing(true)
#ifdef HAVE_ZSTD
    , zstd_cctx(nullptr)
    , zstd_dctx(nullptr)
#endif
#ifdef HAVE_BROTLI
    , brotli_enc(nullptr)
#endif
#ifdef HAVE_LZ4
    , lz4_stream(nullptr)
#endif
{
}

anigma_compression_stream::~anigma_compression_stream() {
    cleanup();
}

anigma_status_t anigma_compression_stream::initialize(
    anigma_compression_context* ctx,
    bool compress_mode,
    anigma_capsule_error_t* err) {
    
    base_context = ctx;
    algorithm = ctx->algorithm;
    is_compressing = compress_mode;
    
    switch (algorithm) {
#ifdef HAVE_ZSTD
        case ANIGMA_COMPRESSION_ALGO_ZSTD: {
            if (compress_mode) {
                zstd_cctx = ZSTD_createCCtx();
                if (!zstd_cctx) {
                    set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create ZSTD compression stream");
                    return ANIGMA_ERR_OUT_OF_MEMORY;
                }
                // Copy parameters from base context
                int level = get_algorithm_level(algorithm, ctx->level);
                ZSTD_CCtx_setParameter(zstd_cctx, ZSTD_c_compressionLevel, level);
            } else {
                zstd_dctx = ZSTD_createDCtx();
                if (!zstd_dctx) {
                    set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create ZSTD decompression stream");
                    return ANIGMA_ERR_OUT_OF_MEMORY;
                }
            }
            break;
        }
#endif

#ifdef HAVE_BROTLI
        case ANIGMA_COMPRESSION_ALGO_BROTLI: {
            if (compress_mode) {
                brotli_enc = BrotliEncoderCreateInstance(nullptr, nullptr, nullptr);
                if (!brotli_enc) {
                    set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create Brotli compression stream");
                    return ANIGMA_ERR_OUT_OF_MEMORY;
                }
                int level = get_algorithm_level(algorithm, ctx->level);
                BrotliEncoderSetParameter(brotli_enc, BROTLI_PARAM_QUALITY, level);
            }
            // Brotli decompression is stateless, no special context needed
            break;
        }
#endif

#ifdef HAVE_LZ4
        case ANIGMA_COMPRESSION_ALGO_LZ4: {
            if (compress_mode) {
                if (ctx->level == ANIGMA_COMPRESSION_LEVEL_BEST) {
                    lz4_stream = LZ4_createStreamHC();
                    if (!lz4_stream) {
                        set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create LZ4HC compression stream");
                        return ANIGMA_ERR_OUT_OF_MEMORY;
                    }
                } else {
                    lz4_stream = LZ4_createStream();
                    if (!lz4_stream) {
                        set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to create LZ4 compression stream");
                        return ANIGMA_ERR_OUT_OF_MEMORY;
                    }
                }
            }
            // LZ4 decompression is stateless
            break;
        }
#endif

        default:
            set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "Unsupported algorithm for streaming");
            return ANIGMA_ERR_UNSUPPORTED_FORMAT;
    }
    
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_stream::cleanup() {
#ifdef HAVE_ZSTD
    if (zstd_cctx) ZSTD_freeCCtx(zstd_cctx);
    if (zstd_dctx) ZSTD_freeDCtx(zstd_dctx);
    zstd_cctx = nullptr;
    zstd_dctx = nullptr;
#endif

#ifdef HAVE_BROTLI
    if (brotli_enc) BrotliEncoderDestroyInstance(brotli_enc);
    brotli_enc = nullptr;
#endif

#ifdef HAVE_LZ4
    if (lz4_stream) {
        if (base_context && base_context->level == ANIGMA_COMPRESSION_LEVEL_BEST) {
            LZ4_freeStreamHC(static_cast<LZ4_streamHC_t*>(lz4_stream));
        } else {
            LZ4_freeStream(static_cast<LZ4_stream_t*>(lz4_stream));
        }
        lz4_stream = nullptr;
    }
#endif

    return ANIGMA_OK;
}

// ============================================================================
// Core API Implementation
// ============================================================================

extern "C" {

anigma_capsule_identity_t anigma_compression_capsule_get_identity(void) {
    return anigma_capsule_identity_t{
        "compression_capsule",
        "1.0.0",
        1,  // Tier 1 deterministic
        __DATE__ " " __TIME__,
        "Production-ready compression with zstd, brotli, lz4"
    };
}

anigma_status_t anigma_compression_capsule_create(
    const struct anigma_compression_config_t* config,
    anigma_compression_capsule_t* out_handle,
    anigma_capsule_error_t* err) {
    
    if (!out_handle) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Output handle is null");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = new anigma_compression_context();
    if (!ctx) {
        set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to allocate compression context");
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    anigma_status_t status = ctx->initialize(config, err);
    if (status != ANIGMA_OK) {
        delete ctx;
        return status;
    }
    
    *out_handle = static_cast<anigma_compression_capsule_t>(ctx);
    return ANIGMA_OK;
}

anigma_status_t anigma_compression_capsule_destroy(
    anigma_compression_capsule_t handle,
    anigma_capsule_error_t* err) {
    
    if (!handle) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Handle is null");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* ctx = static_cast<anigma_compression_context*>(handle);
    ctx->cleanup();
    delete ctx;
    
    return ANIGMA_OK;
}

struct anigma_compression_config_t anigma_compression_capsule_get_default_config(
    enum anigma_compression_algo_t algorithm) {
    
    struct anigma_compression_config_t config;
    config.algorithm = algorithm;
    config.mode = ANIGMA_COMPRESSION_MODE_DETERMINISTIC;
    config.level = ANIGMA_COMPRESSION_LEVEL_DEFAULT;
    config.buffer_pool_size = 64 * 1024 * 1024;  // 64MB buffer pool
    config.determinism_tier = 1;  // Tier 1 by default
    
    return config;
}

anigma_status_t anigma_compression_capsule_validate_config(
    const struct anigma_compression_config_t* config,
    anigma_capsule_error_t* err) {
    
    if (!config) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Configuration is null");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Validate algorithm
    switch (config->algorithm) {
        case ANIGMA_COMPRESSION_ALGO_ZSTD:
#ifndef HAVE_ZSTD
            set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "ZSTD support not compiled in");
            return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
            break;
        case ANIGMA_COMPRESSION_ALGO_BROTLI:
#ifndef HAVE_BROTLI
            set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "Brotli support not compiled in");
            return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
            break;
        case ANIGMA_COMPRESSION_ALGO_LZ4:
#ifndef HAVE_LZ4
            set_error(err, ANIGMA_ERR_UNSUPPORTED_FORMAT, "LZ4 support not compiled in");
            return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
            break;
        default:
            set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid algorithm");
            return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Validate level
    switch (config->level) {
        case ANIGMA_COMPRESSION_LEVEL_DEFAULT:
        case ANIGMA_COMPRESSION_LEVEL_FAST:
        case ANIGMA_COMPRESSION_LEVEL_BEST:
            break;
        default:
            set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid compression level");
            return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Validate mode
    switch (config->mode) {
        case ANIGMA_COMPRESSION_MODE_STREAMING:
        case ANIGMA_COMPRESSION_MODE_DETERMINISTIC:
        case ANIGMA_COMPRESSION_MODE_OPTIMIZED:
            break;
        default:
            set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid compression mode");
            return ANIGMA_ERR_INVALID_ARG;
    }
    
    return ANIGMA_OK;
}

} // extern "C"