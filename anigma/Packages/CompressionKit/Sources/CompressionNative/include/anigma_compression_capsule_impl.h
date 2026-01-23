#ifndef ANIGMA_COMPRESSION_CAPSULE_IMPL_H
#define ANIGMA_COMPRESSION_CAPSULE_IMPL_H

#include "anigma_capsule_core.h"
#include "anigma_compression_capsule.h"
#include <memory>
#include <vector>
#include <unordered_map>
#include <mutex>

#ifdef HAVE_ZSTD
#include <zstd.h>
#include <zdict.h>
#endif

#ifdef HAVE_BROTLI
#include <brotli/encode.h>
#include <brotli/decode.h>
#endif

#ifdef HAVE_LZ4
#include <lz4.h>
#include <lz4hc.h>
#endif

#if defined(__cplusplus)
extern "C" {
#endif

// Internal compression context structure
struct anigma_compression_context {
    enum anigma_compression_algo_t algorithm;
    enum anigma_compression_mode_t mode;
    enum anigma_compression_level_t level;
    uint32_t determinism_tier;
    size_t buffer_pool_size;
    
    // Algorithm-specific contexts
#ifdef HAVE_ZSTD
    ZSTD_CCtx* zstd_cctx;
    ZSTD_DCtx* zstd_dctx;
    ZSTD_CDict* zstd_cdict;
    ZSTD_DDict* zstd_ddict;
#endif

#ifdef HAVE_BROTLI
    brotli_encoder_state_t* brotli_enc;
    brotli_decoder_state_t* brotli_dec;
#endif

#ifdef HAVE_LZ4
    void* lz4_stream;  // LZ4_stream_t*
    void* lz4hc_stream; // LZ4_streamHC_t*
#endif
    
    // Buffer pool
    struct buffer_pool {
        struct pool_entry {
            uint8_t* ptr;
            size_t size;
            uint64_t last_used;
        };
        std::vector<pool_entry> entries;
        std::mutex mutex;
        size_t max_pool_size;
        size_t total_allocated;
    } buffer_pool;
    
    // Dictionary data
    std::vector<uint8_t> dictionary;
    
    // Constructor/Destructor
    anigma_compression_context();
    ~anigma_compression_context();
    
    // Helper methods
    anigma_status_t initialize(const anigma_compression_config_t* config, anigma_capsule_error_t* err);
    anigma_status_t cleanup();
};

// Streaming context structure
struct anigma_compression_stream {
    anigma_compression_context* base_context;
    enum anigma_compression_algo_t algorithm;
    bool is_compressing;  // true for compression, false for decompression
    
    // Algorithm-specific stream contexts
#ifdef HAVE_ZSTD
    ZSTD_CCtx* zstd_cctx;
    ZSTD_DCtx* zstd_dctx;
#endif

#ifdef HAVE_BROTLI
    brotli_encoder_state_t* brotli_enc;
    brotli_decoder_state_t* brotli_dec;
#endif

#ifdef HAVE_LZ4
    void* lz4_stream;
#endif
    
    anigma_compression_stream();
    ~anigma_compression_stream();
    
    anigma_status_t initialize(
        anigma_compression_context* ctx,
        bool compress_mode,
        anigma_capsule_error_t* err
    );
    anigma_status_t cleanup();
};

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_COMPRESSION_CAPSULE_IMPL_H