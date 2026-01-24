#ifndef ANIGMA_CAPSULE_CORE_H
#define ANIGMA_CAPSULE_CORE_H

#include "anigma_native_common.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef void* anigma_capsule_handle_t;

typedef struct {
    const char* capsule_id;
    const char* build_hash;
    const char* algo_version;
    uint32_t determinism_tier;
} anigma_capsule_identity_t;

typedef struct {
    anigma_status_t code;
    const char* message;
    const char* detail;
    uint64_t aux;
} anigma_capsule_error_t;

typedef struct {
    uint8_t* ptr;
    size_t len;
    size_t cap;
    uint32_t flags;
} anigma_capsule_buffer_t;

// Standard allocation functions for capsules to ensure memory domain safety
void* anigma_capsule_alloc_buffer(size_t size, anigma_capsule_error_t* err);
void anigma_capsule_free_buffer(void* ptr, anigma_capsule_error_t* err);
anigma_status_t anigma_capsule_copy_to_buffer(anigma_capsule_buffer_t* dst, const void* src, size_t len, anigma_capsule_error_t* err);

anigma_capsule_identity_t anigma_capsule_get_identity(void);
anigma_status_t anigma_capsule_destroy_handle(anigma_capsule_handle_t handle, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
