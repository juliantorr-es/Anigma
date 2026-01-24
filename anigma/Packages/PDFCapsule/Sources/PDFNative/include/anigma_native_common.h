#ifndef ANIGMA_NATIVE_COMMON_H
#define ANIGMA_NATIVE_COMMON_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#if defined(__cplusplus)
extern "C" {
#endif

typedef struct {
    uint64_t operation_id;
    uint64_t budget_cpu_ms;
    uint64_t budget_mem_bytes;
    void* user_data;
} anigma_ctx_t;

typedef enum {
    ANIGMA_OK = 0,
    ANIGMA_STATUS_SUCCESS = 0,
    
    ANIGMA_ERR_INVALID_ARG = 1,
    ANIGMA_ERR_BUDGET_EXCEEDED = 2,
    ANIGMA_ERR_INTERNAL = 3,
    ANIGMA_ERR_NOT_IMPLEMENTED = 4,
    ANIGMA_ERR_IO = 5,
    ANIGMA_ERR_CORRUPT_DATA = 6,
    
    ANIGMA_STATUS_INVALID_INPUT = 1,
    ANIGMA_STATUS_INVALID_SCHEMA = 2,
    ANIGMA_STATUS_VERSION_MISMATCH = 3,
    ANIGMA_STATUS_OUT_OF_BOUNDS = 4,
    ANIGMA_STATUS_ALREADY_EXISTS = 5,
    ANIGMA_STATUS_NOT_FOUND = 6,
    ANIGMA_STATUS_DETERMINISM_VIOLATION = 7,
    ANIGMA_STATUS_INTERNAL_ERROR = 8,
    ANIGMA_STATUS_BUFFER_TOO_SMALL = 9,
    ANIGMA_STATUS_UNIMPLEMENTED = 10,
    
    ANIGMA_ERR_BUFFER_TOO_SMALL = 100,
    ANIGMA_ERR_NOT_INITIALIZED = 101,
    ANIGMA_ERR_VERSION_MISMATCH = 102,
    ANIGMA_ERR_DETERMINISM_VIOLATION = 103,
    ANIGMA_ERR_UNSUPPORTED_FORMAT = 104,
    ANIGMA_ERR_OUT_OF_MEMORY = 105,
    ANIGMA_ERR_PROCESSING_FAILED = 106,
    ANIGMA_ERR_CORRUPTED_MEDIA = 107
} anigma_status_t;

typedef struct {
    anigma_status_t status;
    const char* error_message;
} anigma_result_t;

void anigma_free_buffer(uint8_t* buf);

typedef struct {
    uint64_t bytes_in;
    uint64_t bytes_out;
    uint64_t abi_calls;
    uint64_t buffer_allocations;
    uint64_t string_conversions;
    uint64_t copy_operations;
    uint64_t total_duration_ns;
} anigma_capsule_telemetry_t;

#if defined(__cplusplus)
}
#endif

#endif
