#include "../../include/anigma_capsule_core.h"
#include <stdlib.h>
#include <string.h>

// ============================================================================
// Default Implementations
// ============================================================================

// Default identity (should be overridden by each capsule)
__attribute__((weak))
anigma_capsule_identity_t anigma_capsule_get_identity(void) {
    static const char* capsule_id = "generic_capsule";
    static const char* build_hash = "unknown";
    static const char* algo_version = "0.0.0";
    
    return (anigma_capsule_identity_t) {
        .capsule_id = capsule_id,
        .build_hash = build_hash,
        .algo_version = algo_version,
        .determinism_tier = ANIGMA_DETERMINISM_TIER_2_CANONICAL_BOUNDARY
    };
}

// Default handle destructor
__attribute__((weak))
anigma_status_t anigma_capsule_destroy_handle(
    anigma_capsule_handle_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Handle is null";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    free(handle);
    return ANIGMA_OK;
}

// Default buffer deallocator
__attribute__((weak))
anigma_status_t anigma_capsule_free_buffer(
    void* ptr,
    anigma_capsule_error_t* err
) {
    if (!ptr) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Pointer is null";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    free(ptr);
    return ANIGMA_OK;
}

// ============================================================================
// Helper Functions
// ============================================================================

// Create a capsule-allocated buffer
void* anigma_capsule_alloc_buffer(size_t size, anigma_capsule_error_t* err) {
    if (size == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Buffer size cannot be zero";
            err->detail = NULL;
            err->aux = 0;
        }
        return NULL;
    }
    
    void* ptr = malloc(size);
    if (!ptr) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate buffer";
            err->detail = NULL;
            err->aux = size;
        }
        return NULL;
    }
    
    return ptr;
}

// Copy data into a caller-allocated buffer
anigma_status_t anigma_capsule_copy_to_buffer(
    anigma_capsule_buffer_t* buffer,
    const void* src,
    size_t size,
    anigma_capsule_error_t* err
) {
    if (!buffer || !buffer->ptr) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output buffer is null";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (buffer->cap < size) {
        return anigma_capsule_query_output_size(err, size);
    }
    
    if (src) {
        memcpy(buffer->ptr, src, size);
    } else {
        memset(buffer->ptr, 0, size);
    }
    
    buffer->len = size;
    return ANIGMA_OK;
}

// Create an error structure
anigma_capsule_error_t anigma_capsule_make_error(
    anigma_status_t code,
    const char* message,
    const char* detail,
    uint64_t aux
) {
    return (anigma_capsule_error_t) {
        .code = code,
        .message = message,
        .detail = detail,
        .aux = aux
    };
}

// ============================================================================
// String Utilities (for import/export boundaries only)
// ============================================================================

// Copy a string to a capsule-allocated buffer (for export only)
char* anigma_capsule_copy_string(const char* src, anigma_capsule_error_t* err) {
    if (!src) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Source string is null";
            err->detail = NULL;
            err->aux = 0;
        }
        return NULL;
    }
    
    size_t len = strlen(src) + 1; // Include null terminator
    char* dst = (char*)anigma_capsule_alloc_buffer(len, err);
    if (!dst) {
        return NULL;
    }
    
    memcpy(dst, src, len);
    return dst;
}

// Copy a string to a caller-allocated buffer
anigma_status_t anigma_capsule_copy_string_to_buffer(
    anigma_capsule_buffer_t* buffer,
    const char* src,
    anigma_capsule_error_t* err
) {
    if (!src) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Source string is null";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    size_t len = strlen(src) + 1; // Include null terminator
    return anigma_capsule_copy_to_buffer(buffer, src, len, err);
}