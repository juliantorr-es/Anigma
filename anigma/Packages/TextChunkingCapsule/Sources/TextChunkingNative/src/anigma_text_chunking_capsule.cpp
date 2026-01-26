#include "anigma_text_chunking_capsule.h"
#include "anigma_capsule_core.h"

#include <cstdint>
#include <cstring>
#include <vector>
#include <algorithm>

// ============================================================================
// Internal Implementation Details
// ============================================================================

namespace {

// Default Rabin polynomial (irreducible polynomial for fingerprinting)
constexpr uint64_t DEFAULT_POLYNOMIAL = 0x3DA3358B4DC173ULL;

/**
 * Rabin Fingerprint rolling hash.
 */
class RabinFingerprint {
private:
    uint64_t polynomial_;
    size_t window_size_;
    uint64_t fingerprint_;
    std::vector<uint8_t> window_;
    size_t window_pos_;
    uint64_t power_msb_; 

    void precompute() {
        // Precompute power_msb = x^(8*(window_size-1)) mod polynomial
        // This is a simplified version for CDC
        power_msb_ = 1;
        for (size_t i = 0; i < window_size_ - 1; i++) {
            power_msb_ = (power_msb_ << 8) % polynomial_;
        }
    }

public:
    RabinFingerprint(size_t window_size, uint64_t polynomial = DEFAULT_POLYNOMIAL)
        : polynomial_(polynomial)
        , window_size_(window_size)
        , fingerprint_(0)
        , window_(window_size, 0)
        , window_pos_(0)
    {
        if (polynomial_ == 0) polynomial_ = DEFAULT_POLYNOMIAL;
        precompute();
    }
    
    uint64_t update(uint8_t byte) {
        uint8_t old_byte = window_[window_pos_];
        window_[window_pos_] = byte;
        window_pos_ = (window_pos_ + 1) % window_size_;

        // fingerprint = (fingerprint - old_byte * power_msb) * x^8 + new_byte
        uint64_t head = (static_cast<uint64_t>(old_byte) * power_msb_) % polynomial_;
        if (fingerprint_ >= head) {
            fingerprint_ = (fingerprint_ - head);
        } else {
            fingerprint_ = (fingerprint_ + polynomial_ - head);
        }
        
        fingerprint_ = ((fingerprint_ << 8) | byte) % polynomial_;
        
        return fingerprint_;
    }
    
    void reset() {
        std::fill(window_.begin(), window_.end(), 0);
        fingerprint_ = 0;
        window_pos_ = 0;
    }
    
    uint64_t get() const {
        return fingerprint_;
    }
};

struct TextChunkingState {
    struct anigma_text_chunking_config_t config;
    RabinFingerprint fingerprint;
    std::vector<uint64_t> boundaries;
    uint64_t current_offset;
    size_t bytes_since_last_boundary;
    
    TextChunkingState(const struct anigma_text_chunking_config_t* config)
        : config(*config)
        , fingerprint(config->window_size, config->polynomial)
        , current_offset(0)
        , bytes_since_last_boundary(0)
    {
    }
    
    bool processByte(uint8_t byte) {
        fingerprint.update(byte);
        current_offset++;
        bytes_since_last_boundary++;
        
        if (bytes_since_last_boundary < config.min_chunk_size) {
            return false;
        }
        
        if (bytes_since_last_boundary >= config.max_chunk_size) {
            boundaries.push_back(current_offset);
            bytes_since_last_boundary = 0;
            return true;
        }
        
        uint64_t hash = fingerprint.get();
        if ((hash % config.target_chunk_size) == (config.target_chunk_size - 1)) {
            boundaries.push_back(current_offset);
            bytes_since_last_boundary = 0;
            return true;
        }
        
        return false;
    }
    
    void finalize() {
        if (bytes_since_last_boundary > 0) {
            boundaries.push_back(current_offset);
            bytes_since_last_boundary = 0;
        }
    }
    
    void reset() {
        fingerprint.reset();
        boundaries.clear();
        current_offset = 0;
        bytes_since_last_boundary = 0;
    }
};

bool validateConfig(const struct anigma_text_chunking_config_t* config, anigma_capsule_error_t* err) {
    if (!config) return false;
    if (config->target_chunk_size == 0) return false;
    if (config->min_chunk_size == 0) return false;
    if (config->max_chunk_size == 0) return false;
    if (config->min_chunk_size > config->max_chunk_size) return false;
    if (config->window_size == 0 || config->window_size > 1024) return false;
    return true;
}

} // anonymous namespace

extern "C" {

anigma_capsule_identity_t anigma_text_chunking_capsule_get_identity(void) {
    return {
        "text_chunking_capsule",
        "v1.0.1",
        "1.1",
        ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

anigma_status_t anigma_text_chunking_capsule_create(
    const struct anigma_text_chunking_config_t* config,
    anigma_text_chunking_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!out_handle || !validateConfig(config, err)) return ANIGMA_ERR_INVALID_ARG;
    try {
        *out_handle = new TextChunkingState(config);
        return ANIGMA_OK;
    } catch (...) {
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_chunking_capsule_destroy(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_OK;
    delete static_cast<TextChunkingState*>(handle);
    return ANIGMA_OK;
}

anigma_status_t anigma_text_chunking_capsule_process_bytes(
    anigma_text_chunking_capsule_t handle,
    const uint8_t* data,
    size_t data_len,
    anigma_capsule_error_t* err
) {
    if (!handle || (!data && data_len > 0)) return ANIGMA_ERR_INVALID_ARG;
    auto state = static_cast<TextChunkingState*>(handle);
    for (size_t i = 0; i < data_len; ++i) {
        state->processByte(data[i]);
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_text_chunking_capsule_finalize(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    static_cast<TextChunkingState*>(handle)->finalize();
    return ANIGMA_OK;
}

anigma_status_t anigma_text_chunking_capsule_reset(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    static_cast<TextChunkingState*>(handle)->reset();
    return ANIGMA_OK;
}

anigma_status_t anigma_text_chunking_capsule_get_boundary_count(
    anigma_text_chunking_capsule_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_count) return ANIGMA_ERR_INVALID_ARG;
    *out_count = static_cast<TextChunkingState*>(handle)->boundaries.size();
    return ANIGMA_OK;
}

anigma_status_t anigma_text_chunking_capsule_get_chunk_info(
    anigma_text_chunking_capsule_t handle,
    struct anigma_chunk_boundary_t* out_boundaries,
    size_t max_boundaries,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    auto state = static_cast<TextChunkingState*>(handle);
    size_t count = state->boundaries.size();
    
    if (!out_boundaries) {
        if (err) {
            err->code = ANIGMA_ERR_BUFFER_TOO_SMALL;
            err->aux = count;
        }
        return ANIGMA_ERR_BUFFER_TOO_SMALL;
    }
    
    size_t to_copy = std::min(count, max_boundaries);
    uint64_t last_offset = 0;
    for (size_t i = 0; i < to_copy; ++i) {
        uint64_t current = state->boundaries[i];
        out_boundaries[i].offset = last_offset;
        out_boundaries[i].length = current - last_offset;
        last_offset = current;
    }
    
    if (out_actual) *out_actual = to_copy;
    return ANIGMA_OK;
}

anigma_status_t anigma_text_chunking_capsule_get_boundaries(
    anigma_text_chunking_capsule_t handle,
    uint64_t* out_offsets,
    size_t max_offsets,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    auto state = static_cast<TextChunkingState*>(handle);
    size_t count = state->boundaries.size();
    if (!out_offsets) {
        if (err) { err->code = ANIGMA_ERR_BUFFER_TOO_SMALL; err->aux = count; }
        return ANIGMA_ERR_BUFFER_TOO_SMALL;
    }
    size_t to_copy = std::min(count, max_offsets);
    for (size_t i = 0; i < to_copy; ++i) out_offsets[i] = state->boundaries[i];
    if (out_actual) *out_actual = to_copy;
    return ANIGMA_OK;
}

anigma_status_t anigma_text_chunking_capsule_chunk_buffer(
    const struct anigma_text_chunking_config_t* config,
    const anigma_capsule_buffer_t* input,
    uint64_t* out_offsets,
    size_t max_offsets,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    anigma_text_chunking_capsule_t handle;
    struct anigma_text_chunking_config_t default_config = { 1024, 512, 4096, 48, DEFAULT_POLYNOMIAL, 1 };
    if (!config) config = &default_config;
    
    anigma_status_t status = anigma_text_chunking_capsule_create(config, &handle, err);
    if (status != ANIGMA_OK) return status;
    
    status = anigma_text_chunking_capsule_process_bytes(handle, input->ptr, input->len, err);
    if (status == ANIGMA_OK) status = anigma_text_chunking_capsule_finalize(handle, err);
    if (status == ANIGMA_OK) status = anigma_text_chunking_capsule_get_boundaries(handle, out_offsets, max_offsets, out_actual, err);
    
    anigma_text_chunking_capsule_destroy(handle, err);
    return status;
}

struct anigma_text_chunking_config_t anigma_text_chunking_capsule_get_default_config(void) {
    return { 1024, 512, 4096, 48, DEFAULT_POLYNOMIAL, 1 };
}

anigma_status_t anigma_text_chunking_capsule_validate_config(
    const struct anigma_text_chunking_config_t* config,
    anigma_capsule_error_t* err
) {
    return validateConfig(config, err) ? ANIGMA_OK : ANIGMA_ERR_INVALID_ARG;
}

} // extern "C"
