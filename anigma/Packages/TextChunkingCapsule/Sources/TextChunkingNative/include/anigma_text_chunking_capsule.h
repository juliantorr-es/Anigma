#ifndef ANIGMA_TEXT_CHUNKING_CAPSULE_H
#define ANIGMA_TEXT_CHUNKING_CAPSULE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef anigma_capsule_handle_t anigma_text_chunking_capsule_t;

typedef struct anigma_text_chunking_config_t {
    uint32_t target_chunk_size;
    uint32_t min_chunk_size;
    uint32_t max_chunk_size;
    uint32_t window_size;
    uint64_t polynomial;
    uint32_t determinism_tier;
} anigma_text_chunking_config_t;

typedef struct anigma_chunk_boundary_t {
    uint64_t offset;
    uint64_t length;
} anigma_chunk_boundary_t;

anigma_capsule_identity_t anigma_text_chunking_capsule_get_identity(void);
struct anigma_text_chunking_config_t anigma_text_chunking_capsule_get_default_config(void);
anigma_status_t anigma_text_chunking_capsule_validate_config(const struct anigma_text_chunking_config_t* config, anigma_capsule_error_t* err);
anigma_status_t anigma_text_chunking_capsule_create(const struct anigma_text_chunking_config_t* config, anigma_text_chunking_capsule_t* out_handle, anigma_capsule_error_t* err);
anigma_status_t anigma_text_chunking_capsule_destroy(anigma_text_chunking_capsule_t handle, anigma_capsule_error_t* err);
anigma_status_t anigma_text_chunking_capsule_process_bytes(anigma_text_chunking_capsule_t handle, const uint8_t* data, size_t data_len, anigma_capsule_error_t* err);
anigma_status_t anigma_text_chunking_capsule_finalize(anigma_text_chunking_capsule_t handle, anigma_capsule_error_t* err);
anigma_status_t anigma_text_chunking_capsule_reset(anigma_text_chunking_capsule_t handle, anigma_capsule_error_t* err);
anigma_status_t anigma_text_chunking_capsule_get_boundary_count(anigma_text_chunking_capsule_t handle, size_t* out_count, anigma_capsule_error_t* err);
anigma_status_t anigma_text_chunking_capsule_get_boundaries(anigma_text_chunking_capsule_t handle, uint64_t* out_offsets, size_t max_offsets, size_t* out_actual, anigma_capsule_error_t* err);
anigma_status_t anigma_text_chunking_capsule_get_chunk_info(anigma_text_chunking_capsule_t handle, struct anigma_chunk_boundary_t* out_boundaries, size_t max_boundaries, size_t* out_actual, anigma_capsule_error_t* err);
anigma_status_t anigma_text_chunking_capsule_chunk_buffer(const struct anigma_text_chunking_config_t* config, const anigma_capsule_buffer_t* input, uint64_t* out_offsets, size_t max_offsets, size_t* out_actual, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
