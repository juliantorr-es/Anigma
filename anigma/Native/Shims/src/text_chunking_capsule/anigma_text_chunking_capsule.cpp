#include "anigma_text_chunking_capsule.h"
#include "anigma_capsule_core.h"

#include <cstdint>
#include <cstring>
#include <vector>

// ============================================================================
// Internal Implementation Details
// ============================================================================

namespace {

// Default Rabin polynomial (irreducible polynomial for fingerprinting)
constexpr uint64_t DEFAULT_POLYNOMIAL = 0x3DA3358B4DC173ULL;

// Rabin fingerprint rolling hash implementation
class RabinFingerprint {
private:
    uint64_t polynomial_;
    uint64_t window_mask_;
    uint64_t fingerprint_;
    std::vector<uint8_t> window_;
    size_t window_pos_;
    
public:
    RabinFingerprint(size_t window_size, uint64_t polynomial = DEFAULT_POLYNOMIAL)
        : polynomial_(polynomial)
        , window_mask_((1ULL << (window_size * 8)) - 1)
        , fingerprint_(0)
        , window_(window_size, 0)
        , window_pos_(0)
    {
    }
    
    // Update fingerprint with a byte
    uint64_t update(uint8_t byte) {
        // Remove oldest byte from window
        uint8_t old_byte = window_[window_pos_];
        fingerprint_ ^= (static_cast<uint64_t>(old_byte) << (window_.size() * 8 - 8));
        
        // Add new byte
        window_[window_pos_] = byte;
        fingerprint_ = (fingerprint_ << 8) | byte;
        
        // Move window position
        window_pos_ = (window_pos_ + 1) % window_.size();
        
        // Apply polynomial reduction
        fingerprint_ %= polynomial_;
        
        return fingerprint_;
    }
    
    // Reset fingerprint state
    void reset() {
        std::fill(window_.begin(), window_.end(), 0);
        fingerprint_ = 0;
        window_pos_ = 0;
    }
    
    uint64_t get() const {
        return fingerprint_;
    }
};

// Text chunking capsule internal state
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
        if (config->polynomial == 0) {
            this->config.polynomial = DEFAULT_POLYNOMIAL;
        }
    }
    
    // Process a byte and check for chunk boundary
    bool processByte(uint8_t byte) {
        fingerprint.update(byte);
        current_offset++;
        bytes_since_last_boundary++;
        
        // Check if we've reached minimum chunk size
        if (bytes_since_last_boundary < config.min_chunk_size) {
            return false;
        }
        
        // Check if we've exceeded maximum chunk size (force boundary)
        if (bytes_since_last_boundary >= config.max_chunk_size) {
            boundaries.push_back(current_offset - bytes_since_last_boundary);
            bytes_since_last_boundary = 0;
            return true;
        }
        
        // Check Rabin fingerprint for natural boundary
        // A boundary occurs when fingerprint mod target_size == target_size - 1
        uint64_t fingerprint_value = fingerprint.get();
        if ((fingerprint_value % config.target_chunk_size) == (config.target_chunk_size - 1)) {
            boundaries.push_back(current_offset - bytes_since_last_boundary);
            bytes_since_last_boundary = 0;
            return true;
        }
        
        return false;
    }
    
    // Finalize and add last boundary if needed
    void finalize() {
        if (bytes_since_last_boundary > 0) {
            boundaries.push_back(current_offset - bytes_since_last_boundary);
            bytes_since_last_boundary = 0;
        }
    }
    
    // Reset state for new input
    void reset() {
        fingerprint.reset();
        boundaries.clear();
        current_offset = 0;
        bytes_since_last_boundary = 0;
    }
};

// Validate configuration parameters
bool validateConfig(const struct anigma_text_chunking_config_t* config, anigma_capsule_error_t* err) {
    if (!config) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Configuration pointer is null";
        }
        return false;
    }
    
    if (config->target_chunk_size == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Target chunk size must be > 0";
        }
        return false;
    }
    
    if (config->min_chunk_size == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Minimum chunk size must be > 0";
        }
        return false;
    }
    
    if (config->max_chunk_size == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Maximum chunk size must be > 0";
        }
        return false;
    }
    
    if (config->min_chunk_size > config->target_chunk_size) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Minimum chunk size must be <= target chunk size";
        }
        return false;
    }
    
    if (config->max_chunk_size < config->target_chunk_size) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Maximum chunk size must be >= target chunk size";
        }
        return false;
    }
    
    if (config->window_size == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Window size must be > 0";
        }
        return false;
    }
    
    if (config->window_size > 64) {  // Practical limit
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Window size too large (max 64)";
        }
        return false;
    }
    
    return true;
}

} // anonymous namespace

// ============================================================================
// Public API Implementation
// ============================================================================

anigma_capsule_identity_t anigma_text_chunking_capsule_get_identity(void) {
    static const char* capsule_id = "text_chunking_capsule";
    static const char* build_hash = "1.0.0-dev";
    static const char* algo_version = "1.0";
    
    return anigma_capsule_identity_t{
        capsule_id,
        build_hash,
        algo_version,
        ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

struct anigma_text_chunking_config_t anigma_text_chunking_capsule_get_default_config(void) {
    return anigma_text_chunking_config_t{
        .target_chunk_size = 1024,     // 1KB target chunks
        .min_chunk_size = 512,         // Minimum 512 bytes
        .max_chunk_size = 4096,        // Maximum 4KB
        .window_size = 48,             // Rabin window size
        .polynomial = DEFAULT_POLYNOMIAL, // Default irreducible polynomial
        .determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

anigma_status_t anigma_text_chunking_capsule_validate_config(
    const struct anigma_text_chunking_config_t* config,
    anigma_capsule_error_t* err
) {
    if (!validateConfig(config, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_text_chunking_capsule_create(
    const struct anigma_text_chunking_config_t* config,
    anigma_text_chunking_capsule_t* out_handle,
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
        TextChunkingState* state = new TextChunkingState(config);
        *out_handle = static_cast<anigma_text_chunking_capsule_t>(state);
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate text chunking state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_chunking_capsule_destroy(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
) {
    (void)err;
    
    if (!handle) {
        return ANIGMA_OK;  // Destroying null handle is a no-op
    }
    
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        delete state;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to destroy text chunking state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_chunking_capsule_process_bytes(
    anigma_text_chunking_capsule_t handle,
    const uint8_t* data,
    size_t data_len,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!data && data_len > 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Data pointer is null but length > 0";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        
        for (size_t i = 0; i < data_len; ++i) {
            state->processByte(data[i]);
        }
        
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to process bytes";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_chunking_capsule_finalize(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        state->finalize();
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to finalize chunking";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_chunking_capsule_reset(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        state->reset();
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to reset chunking state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_chunking_capsule_get_boundary_count(
    anigma_text_chunking_capsule_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!out_count) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output count pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        *out_count = state->boundaries.size();
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to get boundary count";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_chunking_capsule_get_boundaries(
    anigma_text_chunking_capsule_t handle,
    uint64_t* out_offsets,
    size_t max_offsets,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        
        // Two-phase pattern: if out_offsets is NULL, return required size in err->aux
        if (!out_offsets) {
            if (err) {
                err->code = ANIGMA_ERR_BUFFER_TOO_SMALL;
                err->aux = state->boundaries.size();
                err->message = "Buffer too small, call with required size";
            }
            return ANIGMA_ERR_BUFFER_TOO_SMALL;
        }
        
        size_t count = state->boundaries.size();
        if (count > max_offsets) {
            if (err) {
                err->code = ANIGMA_ERR_BUFFER_TOO_SMALL;
                err->aux = count;
                err->message = "Buffer too small, call with required size";
            }
            return ANIGMA_ERR_BUFFER_TOO_SMALL;
        }
        
        for (size_t i = 0; i < count; ++i) {
            out_offsets[i] = state->boundaries[i];
        }
        
        if (out_actual) {
            *out_actual = count;
        }
        
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to get boundaries";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_chunking_capsule_get_chunk_info(
    anigma_text_chunking_capsule_t handle,
    struct anigma_chunk_boundary_t* out_boundaries,
    size_t max_boundaries,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        TextChunkingState* state = static_cast<TextChunkingState*>(handle);
        const auto& boundaries = state->boundaries;
        size_t count = boundaries.size();
        
        // Two-phase pattern
        if (!out_boundaries) {
            if (err) {
                err->code = ANIGMA_ERR_BUFFER_TOO_SMALL;
                err->aux = count;
                err->message = "Buffer too small, call with required size";
            }
            return ANIGMA_ERR_BUFFER_TOO_SMALL;
        }
        
        if (count > max_boundaries) {
            if (err) {
                err->code = ANIGMA_ERR_BUFFER_TOO_SMALL;
                err->aux = count;
                err->message = "Buffer too small, call with required size";
            }
            return ANIGMA_ERR_BUFFER_TOO_SMALL;
        }
        
        // Convert offsets to boundaries (offset, length)
        uint64_t prev_offset = 0;
        for (size_t i = 0; i < count; ++i) {
            uint64_t offset = boundaries[i];
            out_boundaries[i].offset = offset;
            out_boundaries[i].length = (i == 0) ? offset : (offset - prev_offset);
            prev_offset = offset;
        }
        
        if (out_actual) {
            *out_actual = count;
        }
        
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to get chunk info";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_chunking_capsule_chunk_buffer(
    const struct anigma_text_chunking_config_t* config,
    const anigma_capsule_buffer_t* input,
    uint64_t* out_offsets,
    size_t max_offsets,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    if (!input || !input->ptr) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Input buffer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Use default config if none provided
    struct anigma_text_chunking_config_t local_config;
    if (!config) {
        local_config = anigma_text_chunking_capsule_get_default_config();
        config = &local_config;
    }
    
    if (!validateConfig(config, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Create capsule, process, and destroy
    anigma_text_chunking_capsule_t handle = nullptr;
    anigma_status_t status = anigma_text_chunking_capsule_create(config, &handle, err);
    if (status != ANIGMA_OK) {
        return status;
    }
    
    // Process all bytes
    status = anigma_text_chunking_capsule_process_bytes(handle, input->ptr, input->len, err);
    if (status != ANIGMA_OK) {
        anigma_text_chunking_capsule_destroy(handle, nullptr);
        return status;
    }
    
    // Finalize
    status = anigma_text_chunking_capsule_finalize(handle, err);
    if (status != ANIGMA_OK) {
        anigma_text_chunking_capsule_destroy(handle, nullptr);
        return status;
    }
    
    // Get boundaries
    status = anigma_text_chunking_capsule_get_boundaries(handle, out_offsets, max_offsets, out_actual, err);
    
    // Clean up
    anigma_text_chunking_capsule_destroy(handle, nullptr);
    return status;
}