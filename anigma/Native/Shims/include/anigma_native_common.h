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
    ANIGMA_ERR_INVALID_ARG = 1,
    ANIGMA_ERR_BUDGET_EXCEEDED = 2,
    ANIGMA_ERR_INTERNAL = 3,
    ANIGMA_ERR_NOT_IMPLEMENTED = 4,
    ANIGMA_ERR_IO = 5,
    ANIGMA_ERR_CORRUPT_DATA = 6,
    
    // Capsule-specific status codes (starting from 100)
    ANIGMA_ERR_BUFFER_TOO_SMALL = 100,  // Output buffer too small, aux contains required size
    ANIGMA_ERR_NOT_INITIALIZED = 101,   // Capsule not initialized
    ANIGMA_ERR_VERSION_MISMATCH = 102,  // Version mismatch
    ANIGMA_ERR_DETERMINISM_VIOLATION = 103 // Determinism requirement violated
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

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_NATIVE_COMMON_H
