#ifndef ANIGMA_VECTOR_INDEX_CAPSULE_H
#define ANIGMA_VECTOR_INDEX_CAPSULE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct anigma_vector_index_capsule_t anigma_vector_index_capsule_t;

typedef struct {
    uint32_t dimension;
    uint32_t max_elements;
    uint32_t M;
    uint32_t ef_construction;
    uint32_t ef_search;
    uint32_t allow_replace_deleted;
    const char* mmap_path;
} anigma_vector_index_config_t;

anigma_capsule_identity_t anigma_vector_index_capsule_get_identity(void);

anigma_status_t anigma_vector_index_capsule_create(
    const anigma_vector_index_config_t* config,
    anigma_vector_index_capsule_t** handle,
    anigma_capsule_error_t* error
);

void anigma_vector_index_capsule_destroy(anigma_vector_index_capsule_t* handle);

anigma_status_t anigma_vector_index_capsule_add_vector(
    anigma_vector_index_capsule_t* handle,
    uint64_t id,
    const float* vector,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_index_capsule_add_vectors(
    anigma_vector_index_capsule_t* handle,
    const uint64_t* ids,
    const float* vectors,
    size_t count,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_index_capsule_search(
    anigma_vector_index_capsule_t* handle,
    const float* query_vector,
    uint32_t k,
    uint64_t* out_ids,
    float* out_distances,
    uint32_t* out_count,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_index_capsule_search_pool(
    anigma_vector_index_capsule_t* handle,
    const float* query_vector,
    const uint64_t* candidate_ids,
    size_t candidate_count,
    uint32_t k,
    uint64_t* out_ids,
    float* out_distances,
    uint32_t* out_count,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_index_capsule_save(
    anigma_vector_index_capsule_t* handle,
    const char* path,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_index_capsule_load(
    anigma_vector_index_capsule_t* handle,
    const char* path,
    anigma_capsule_error_t* error
);

uint32_t anigma_vector_index_capsule_get_count(anigma_vector_index_capsule_t* handle);

anigma_status_t anigma_vector_index_capsule_clear(
    anigma_vector_index_capsule_t* handle,
    anigma_capsule_error_t* error
);

#ifdef __cplusplus
}
#endif

#endif
