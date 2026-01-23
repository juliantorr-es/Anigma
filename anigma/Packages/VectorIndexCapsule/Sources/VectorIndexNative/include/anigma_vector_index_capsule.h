#ifndef ANIGMA_VECTOR_INDEX_CAPSULE_H
#define ANIGMA_VECTOR_INDEX_CAPSULE_H

#include <stddef.h>
#include <stdint.h>
#include "anigma_status.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque handle to a vector index capsule instance.
typedef struct anigma_vector_index_capsule_t anigma_vector_index_capsule_t;

/// Configuration for the vector index.
typedef struct {
    uint32_t dimension;
    uint32_t max_elements;
    uint32_t M;               // HNSW M parameter
    uint32_t ef_construction; // HNSW ef_construction
    uint32_t ef_search;       // HNSW ef_search
    uint32_t allow_replace_deleted;
    const char* mmap_path;    // Path for memory-mapped storage
} anigma_vector_index_config_t;

/// Create a new vector index capsule.
anigma_status_t anigma_vector_index_capsule_create(
    const anigma_vector_index_config_t* config,
    anigma_vector_index_capsule_t** handle,
    anigma_capsule_error_t* error
);

/// Destroy a vector index capsule.
void anigma_vector_index_capsule_destroy(anigma_vector_index_capsule_t* handle);

/// Add a vector to the index.
anigma_status_t anigma_vector_index_capsule_add_vector(
    anigma_vector_index_capsule_t* handle,
    uint64_t id,
    const float* vector,
    anigma_capsule_error_t* error
);

/// Batch add vectors to the index.
anigma_status_t anigma_vector_index_capsule_add_vectors(
    anigma_vector_index_capsule_t* handle,
    const uint64_t* ids,
    const float* vectors,
    size_t count,
    anigma_capsule_error_t* error
);

/// Search for nearest neighbors.
anigma_status_t anigma_vector_index_capsule_search(
    anigma_vector_index_capsule_t* handle,
    const float* query_vector,
    uint32_t k,
    uint64_t* out_ids,
    float* out_distances,
    uint32_t* out_count,
    anigma_capsule_error_t* error
);

/// Search for nearest neighbors within a candidate pool (Two-stage funnel).
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

/// Save index state to disk (if mmap_path was provided, this is handled automatically).
anigma_status_t anigma_vector_index_capsule_save(
    anigma_vector_index_capsule_t* handle,
    const char* path,
    anigma_capsule_error_t* error
);

/// Load index state from disk.
anigma_status_t anigma_vector_index_capsule_load(
    anigma_vector_index_capsule_t* handle,
    const char* path,
    anigma_capsule_error_t* error
);

/// Get current element count.
uint32_t anigma_vector_index_capsule_get_count(anigma_vector_index_capsule_t* handle);

/// Clear all vectors from the index.
anigma_status_t anigma_vector_index_capsule_clear(
    anigma_vector_index_capsule_t* handle,
    anigma_capsule_error_t* error
);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_VECTOR_INDEX_CAPSULE_H
