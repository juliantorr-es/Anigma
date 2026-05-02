#ifndef ANIGMA_NATIVE_COMMON_H
#define ANIGMA_NATIVE_COMMON_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#if defined(__cplusplus)
extern "C" {
#endif

// --- Context & Governance ---

/**
 * Standard operation context passed to all native calls.
 * Ensures strict budgeting and traceability.
 */
typedef struct {
    uint64_t operation_id;      // Unique ID for the operation (for tracing)
    uint64_t budget_cpu_ms;     // Max CPU time allowed (0 = unlimited/default)
    uint64_t budget_mem_bytes;  // Max memory allocation allowed (0 = unlimited/default)
    void* user_data;            // Opaque pointer for callbacks
} anigma_ctx_t;

// --- Error Handling ---

typedef enum {
    ANIGMA_OK = 0,
    ANIGMA_STATUS_SUCCESS = 0,
    
    ANIGMA_ERR_INVALID_ARG = 1,
    ANIGMA_STATUS_INVALID_INPUT = 1,
    
    ANIGMA_ERR_BUDGET_EXCEEDED = 2,
    ANIGMA_ERR_INTERNAL = 3,
    ANIGMA_STATUS_INTERNAL_ERROR = 3,
    
    ANIGMA_ERR_NOT_IMPLEMENTED = 4,
    ANIGMA_STATUS_UNIMPLEMENTED = 4,
    
    ANIGMA_ERR_IO = 5,
    ANIGMA_ERR_CORRUPT_DATA = 6,
    
    ANIGMA_STATUS_INVALID_SCHEMA = 7,
    ANIGMA_STATUS_VERSION_MISMATCH = 8,
    ANIGMA_STATUS_OUT_OF_BOUNDS = 9,
    ANIGMA_STATUS_ALREADY_EXISTS = 10,
    ANIGMA_STATUS_NOT_FOUND = 11,
    ANIGMA_STATUS_DETERMINISM_VIOLATION = 12,
    
    // Capsule-specific status codes (starting from 100)
    ANIGMA_ERR_BUFFER_TOO_SMALL = 100,
    ANIGMA_STATUS_BUFFER_TOO_SMALL = 100,
    
    ANIGMA_ERR_NOT_INITIALIZED = 101,
    ANIGMA_ERR_VERSION_MISMATCH = 102,
    ANIGMA_ERR_DETERMINISM_VIOLATION = 103,
    ANIGMA_ERR_UNSUPPORTED_FORMAT = 104,
    ANIGMA_ERR_OUT_OF_MEMORY = 105,
    ANIGMA_ERR_PROCESSING_FAILED = 106,
    ANIGMA_ERR_CORRUPTED_MEDIA = 107
} anigma_status_t;

/**
 * Standard result structure.
 * Wraps status and an optional error message.
 * Error messages are owned by the shim and valid until the next call.
 */
typedef struct {
    anigma_status_t status;
    const char* error_message;
} anigma_result_t;

// --- Memory Management ---

/**
 * Frees a buffer allocated by the native side (e.g., output of compression).
 */
void anigma_free_buffer(uint8_t* buf);

// --- Shared Memory ---

/**
 * Non-variadic wrapper for POSIX shm_open.
 * Used to circumvent Swift 6 variadic function limitations.
 */
int anigma_shm_open(const char* name, int oflag, uint16_t mode);

/**
 * Wrapper for POSIX shm_unlink.
 */
int anigma_shm_unlink(const char* name);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_NATIVE_COMMON_H
