#include "anigma_text_chunking_capsule.h"
#include "anigma_capsule_core.h"

#include <cstdint>
#include <cstring>
#include <vector>
#include <algorithm>

namespace {

constexpr uint64_t DEFAULT_POLYNOMIAL = 0x3DA3358B4DC173ULL;

class RabinFingerprint {
private:
    uint64_t polynomial_;
    uint64_t fingerprint_;
    std::vector<uint8_t> window_;
    size_t window_pos_;
    
public:
    RabinFingerprint(size_t window_size, uint64_t polynomial = DEFAULT_POLYNOMIAL)
        : polynomial_(polynomial)
        , fingerprint_(0)
        , window_(window_size, 0)
        , window_pos_(0)
    {
    }
    
    uint64_t update(uint8_t byte) {
        if (window_.empty()) return 0;
        uint8_t old_byte = window_[window_pos_];
        fingerprint_ ^= (static_cast<uint64_t>(old_byte) << (window_.size() * 8 - 8));
        window_[window_pos_] = byte;
        fingerprint_ = (fingerprint_ << 8) | byte;
        window_pos_ = (window_pos_ + 1) % window_.size();
        fingerprint_ %= polynomial_;
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
    
    TextChunkingState(const struct anigma_text_chunking_config_t* cfg)
        : config(*cfg)
        , fingerprint(cfg->window_size > 0 ? cfg->window_size : 48, cfg->polynomial)
        , current_offset(0)
        , bytes_since_last_boundary(0)
    {
        if (config.polynomial == 0) {
            this->config.polynomial = DEFAULT_POLYNOMIAL;
        }
    }
    
    bool processByte(uint8_t byte) {
        fingerprint.update(byte);
        current_offset++;
        bytes_since_last_boundary++;
        if (bytes_since_last_boundary < config.min_chunk_size) return false;
        if (bytes_since_last_boundary >= config.max_chunk_size) {
            boundaries.push_back(current_offset);
            bytes_since_last_boundary = 0;
            return true;
        }
        uint64_t fingerprint_value = fingerprint.get();
        if (config.target_chunk_size > 0 && (fingerprint_value % config.target_chunk_size) == (config.target_chunk_size - 1)) {
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
    if (config->min_chunk_size > config->target_chunk_size) return false;
    if (config->max_chunk_size < config->target_chunk_size) return false;
    if (config->window_size == 0) return false;
    if (config->window_size > 64) return false;
    return true;
}

} // anonymous namespace

extern "C" {

anigma_capsule_identity_t anigma_text_chunking_capsule_get_identity(void) {
    static const anigma_capsule_identity_t identity = { "text_chunking_capsule", "1.0.0-dev", "1.0", 1 };
    return identity;
}

struct anigma_text_chunking_config_t anigma_text_chunking_capsule_get_default_config(void) {
    struct anigma_text_chunking_config_t config;
    config.target_chunk_size = 1024;
    config.min_chunk_size = 512;
    config.max_chunk_size = 4096;
    config.window_size = 48;
    config.polynomial = DEFAULT_POLYNOMIAL;
    config.determinism_tier = 1;
    return config;
}

anigma_status_t anigma_text_chunking_capsule_validate_config(const struct anigma_text_chunking_config_t* config, anigma_capsule_error_t* err) {
    if (!validateConfig(config, err)) return ANIGMA_ERR_INVALID_ARG;
    return ANIGMA_OK;
}

anigma_status_t anigma_text_chunking_capsule_create(const struct anigma_text_chunking_config_t* config, anigma_text_chunking_capsule_t* out_handle, anigma_capsule_error_t* err) {
    if (!out_handle || !validateConfig(config, err)) return ANIGMA_ERR_INVALID_ARG;
    try {
        TextChunkingState* state = new TextChunkingState(config);
        *out_handle = static_cast<anigma_text_chunking_capsule_t>(state);
        return ANIGMA_OK;
    } catch (...) { return ANIGMA_ERR_INTERNAL; }
}

anigma_status_t anigma_text_chunking_capsule_destroy(anigma_text_chunking_capsule_t handle, anigma_capsule_error_t* err) {
    if (!handle) return ANIGMA_OK;
    try {
        delete static_cast<TextChunkingState*>(handle);
        return ANIGMA_OK;
    } catch (...) { return ANIGMA_ERR_INTERNAL; }
}

anigma_status_t anigma_text_chunking_capsule_process_bytes(anigma_text_chunking_capsule_t handle, const uint8_t* data, size_t data_len, anigma_capsule_error_t* err) {
    if (!handle || (!data && data_len > 0)) return ANIGMA_ERR_INVALID_ARG;
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        for (size_t i = 0; i < data_len; ++i) state->processByte(data[i]);
        return ANIGMA_OK;
    } catch (...) { return ANIGMA_ERR_INTERNAL; }
}

anigma_status_t anigma_text_chunking_capsule_finalize(anigma_text_chunking_capsule_t handle, anigma_capsule_error_t* err) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    try {
        static_cast<TextChunkingState*>(handle)->finalize();
        return ANIGMA_OK;
    } catch (...) { return ANIGMA_ERR_INTERNAL; }
}

anigma_status_t anigma_text_chunking_capsule_reset(anigma_text_chunking_capsule_t handle, anigma_capsule_error_t* err) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    try {
        static_cast<TextChunkingState*>(handle)->reset();
        return ANIGMA_OK;
    } catch (...) { return ANIGMA_ERR_INTERNAL; }
}

anigma_status_t anigma_text_chunking_capsule_get_boundary_count(anigma_text_chunking_capsule_t handle, size_t* out_count, anigma_capsule_error_t* err) {
    if (!handle || !out_count) return ANIGMA_ERR_INVALID_ARG;
    try {
        *out_count = static_cast<TextChunkingState*>(handle)->boundaries.size();
        return ANIGMA_OK;
    } catch (...) { return ANIGMA_ERR_INTERNAL; }
}

anigma_status_t anigma_text_chunking_capsule_get_boundaries(anigma_text_chunking_capsule_t handle, uint64_t* out_offsets, size_t max_offsets, size_t* out_actual, anigma_capsule_error_t* err) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        if (!out_offsets) {
            if (err) err->aux = state->boundaries.size();
            return ANIGMA_ERR_BUFFER_TOO_SMALL;
        }
        size_t count = std::min(state->boundaries.size(), max_offsets);
        for (size_t i = 0; i < count; ++i) out_offsets[i] = state->boundaries[i];
        if (out_actual) *out_actual = count;
        return ANIGMA_OK;
    } catch (...) { return ANIGMA_ERR_INTERNAL; }
}

anigma_status_t anigma_text_chunking_capsule_get_chunk_info(anigma_text_chunking_capsule_t handle, struct anigma_chunk_boundary_t* out_boundaries, size_t max_boundaries, size_t* out_actual, anigma_capsule_error_t* err) {
    if (!handle) return ANIGMA_ERR_INVALID_ARG;
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        size_t count = std::min(state->boundaries.size(), max_boundaries);
        if (!out_boundaries) {
            if (err) err->aux = state->boundaries.size();
            return ANIGMA_ERR_BUFFER_TOO_SMALL;
        }
        uint64_t prev_offset = 0;
        for (size_t i = 0; i < count; ++i) {
            uint64_t offset = state->boundaries[i];
            out_boundaries[i].offset = offset;
            out_boundaries[i].length = offset - prev_offset;
            prev_offset = offset;
        }
        if (out_actual) *out_actual = count;
        return ANIGMA_OK;
    } catch (...) { return ANIGMA_ERR_INTERNAL; }
}

anigma_status_t anigma_text_chunking_capsule_chunk_buffer(const struct anigma_text_chunking_config_t* config, const anigma_capsule_buffer_t* input, uint64_t* out_offsets, size_t max_offsets, size_t* out_actual, anigma_capsule_error_t* err) {
    if (!input || !input->ptr) return ANIGMA_ERR_INVALID_ARG;
    anigma_text_chunking_capsule_t handle = nullptr;
    struct anigma_text_chunking_config_t default_config;
    if (!config) {
        default_config = anigma_text_chunking_capsule_get_default_config();
        config = &default_config;
    }
    anigma_status_t status = anigma_text_chunking_capsule_create(config, &handle, err);
    if (status != ANIGMA_OK) return status;
    status = anigma_text_chunking_capsule_process_bytes(handle, input->ptr, input->len, err);
    if (status == ANIGMA_OK) status = anigma_text_chunking_capsule_finalize(handle, err);
    if (status == ANIGMA_OK) status = anigma_text_chunking_capsule_get_boundaries(handle, out_offsets, max_offsets, out_actual, err);
    anigma_text_chunking_capsule_destroy(handle, nullptr);
    return status;
}

} // extern "C"
