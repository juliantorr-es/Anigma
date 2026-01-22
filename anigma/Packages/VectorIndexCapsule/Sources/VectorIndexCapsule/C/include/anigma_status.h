#ifndef ANIGMA_STATUS_H
#define ANIGMA_STATUS_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// --- Status Codes ---
typedef enum {
    ANIGMA_OK = 0,
    ANIGMA_ERR_INVALID_ARG = 1,
    ANIGMA_ERR_BUDGET_EXCEEDED = 2,
    ANIGMA_ERR_INTERNAL = 3,
    ANIGMA_ERR_NOT_IMPLEMENTED = 4,
    ANIGMA_ERR_IO = 5,
    ANIGMA_ERR_CORRUPT_DATA = 6,
    ANIGMA_ERR_ALREADY_EXISTS = 7,
    
    // Capsule-specific status codes
    ANIGMA_ERR_BUFFER_TOO_SMALL = 100,
    ANIGMA_ERR_NOT_INITIALIZED = 101,
    ANIGMA_ERR_VERSION_MISMATCH = 102,
    ANIGMA_ERR_DETERMINISM_VIOLATION = 103
} anigma_status_t;

// --- Capsule Error Structure ---
typedef struct {
    anigma_status_t code;
    const char* message;
    const char* detail;
    uint64_t aux;
} anigma_capsule_error_t;

// --- Capsule Buffer ---
typedef struct {
    uint8_t* ptr;
    size_t len;
    size_t cap;
} anigma_capsule_buffer_t;

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_STATUS_H
