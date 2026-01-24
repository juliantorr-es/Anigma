#ifndef ANIGMA_CAPSULE_CORE_H
#define ANIGMA_CAPSULE_CORE_H

#include "anigma_native_common.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Capsule Core Types (ABI v1.0)
// ============================================================================

// ----------------------------------------------------------------------------
// Opaque Handle Type
// ----------------------------------------------------------------------------
typedef void* anigma_capsule_handle_t;

// ----------------------------------------------------------------------------
// Extended Error Structure
// ----------------------------------------------------------------------------
typedef struct anigma_capsule_error_t {
    anigma_status_t code;
    const char* message;     // immutable static string or capsule-owned; document which
    const char* detail;      // optional
    uint64_t aux;            // optional numeric detail (like required size)
} anigma_capsule_error_t;

// ----------------------------------------------------------------------------
// Buffer Descriptor for Zero-Copy Marshalling
// ----------------------------------------------------------------------------
typedef struct anigma_capsule_buffer_t {
    uint8_t* ptr;
    size_t len;       // for input: bytes available; for output: bytes written
    size_t cap;       // for output: total capacity
} anigma_capsule_buffer_t;

// ----------------------------------------------------------------------------
// Buffer Ownership Flags
// ----------------------------------------------------------------------------
typedef enum {
    ANIGMA_BUFFER_BORROWED_INPUT = 0,          // Caller owns, capsule reads only
    ANIGMA_BUFFER_CALLER_ALLOCATED_OUTPUT = 1, // Caller allocates, capsule writes
    ANIGMA_BUFFER_CAPSULE_ALLOCATED_OUTPUT = 2 // Capsule allocates, caller frees
} anigma_capsule_buffer_owner_t;

// ----------------------------------------------------------------------------
// Determinism Tiers
// ----------------------------------------------------------------------------
typedef enum {
    ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE = 1,   // Bitwise identical outputs
    ANIGMA_DETERMINISM_TIER_2_CANONICAL_BOUNDARY = 2 // Canonical boundary only
} anigma_capsule_determinism_tier_t;

// ----------------------------------------------------------------------------
// Capsule Identity Structure
// ----------------------------------------------------------------------------
typedef struct anigma_capsule_identity_t {
    const char* capsule_id;      // e.g., "vector_capsule", "rank_fusion_capsule"
    const char* build_hash;      // Content hash of compiled capsule binary
    const char* algo_version;    // Semantic algorithm version
    uint32_t determinism_tier;   // ANIGMA_DETERMINISM_TIER_* value
} anigma_capsule_identity_t;

// ----------------------------------------------------------------------------
// Extended Status Codes (now in anigma_native_common.h)
// ----------------------------------------------------------------------------
// Base status codes from anigma_native_common.h include:
// ANIGMA_ERR_BUFFER_TOO_SMALL = 100
// ANIGMA_ERR_NOT_INITIALIZED = 101
// ANIGMA_ERR_VERSION_MISMATCH = 102
// ANIGMA_ERR_DETERMINISM_VIOLATION = 103

// ============================================================================
// Required Capsule Core Functions
// ============================================================================

/**
 * Returns capsule identity information.
 * Strings must remain valid for process lifetime or until capsule shutdown.
 */
anigma_capsule_identity_t anigma_capsule_get_identity(void);

/**
 * Standard destructor pattern for any capsule handle.
 */
anigma_status_t anigma_capsule_destroy_handle(anigma_capsule_handle_t handle, anigma_capsule_error_t* err);

/**
 * Free capsule-allocated buffers (if any API returns owned buffers).
 */
anigma_status_t anigma_capsule_free_buffer(void* ptr, anigma_capsule_error_t* err);

// ============================================================================
// Buffer Helper Functions
// ============================================================================

/**
 * Query required output buffer size for an operation.
 * Returns ANIGMA_ERR_BUFFER_TOO_SMALL with required size in err->aux.
 * This is the first phase of two-phase buffer filling.
 */
static inline anigma_status_t anigma_capsule_query_output_size(
    anigma_capsule_error_t* err,
    size_t required_size
) {
    if (err) {
        err->code = ANIGMA_ERR_BUFFER_TOO_SMALL;
        err->aux = required_size;
        err->message = "Output buffer too small";
        err->detail = NULL;
    }
    return ANIGMA_ERR_BUFFER_TOO_SMALL;
}

/**
 * Validate buffer descriptor for writing.
 * Returns ANIGMA_OK if buffer has sufficient capacity, otherwise sets error.
 */
static inline anigma_status_t anigma_capsule_validate_output_buffer(
    const anigma_capsule_buffer_t* buf,
    size_t required_size,
    anigma_capsule_error_t* err
) {
    if (!buf || !buf->ptr) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output buffer is null";
            err->detail = NULL;
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (buf->cap < required_size) {
        return anigma_capsule_query_output_size(err, required_size);
    }
    
    return ANIGMA_OK;
}

// ============================================================================
// Marshalling Telemetry Structure (for instrumentation)
// ============================================================================
typedef struct anigma_capsule_telemetry_t {
    uint64_t bytes_in;
    uint64_t bytes_out;
    uint64_t abi_calls;
    uint64_t buffer_allocations;
    uint64_t string_conversions;  // Should be zero in hot paths
    uint64_t copy_operations;
    uint64_t total_duration_ns;
} anigma_capsule_telemetry_t;

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Allocate a buffer using capsule memory manager.
 * Returns NULL on failure, with error details in err.
 */
void* anigma_capsule_alloc_buffer(size_t size, anigma_capsule_error_t* err);

/**
 * Copy data into a caller-allocated buffer.
 */
anigma_status_t anigma_capsule_copy_to_buffer(
    anigma_capsule_buffer_t* buffer,
    const void* src,
    size_t size,
    anigma_capsule_error_t* err
);

/**
 * Create an error structure.
 */
anigma_capsule_error_t anigma_capsule_make_error(
    anigma_status_t code,
    const char* message,
    const char* detail,
    uint64_t aux
);

// ============================================================================
// String Utilities (for import/export boundaries only)
// ============================================================================

/**
 * Copy a string to a capsule-allocated buffer (for export only).
 * Returns NULL on failure, with error details in err.
 * Caller must free the returned buffer with anigma_capsule_free_buffer.
 */
char* anigma_capsule_copy_string(const char* src, anigma_capsule_error_t* err);

/**
 * Copy a string to a caller-allocated buffer.
 */
anigma_status_t anigma_capsule_copy_string_to_buffer(
    anigma_capsule_buffer_t* buffer,
    const char* src,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_CAPSULE_CORE_H