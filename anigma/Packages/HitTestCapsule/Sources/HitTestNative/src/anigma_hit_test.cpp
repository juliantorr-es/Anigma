#include "anigma_hit_test.h"
#include <cstdlib>
#include <string.h>

extern "C" {

anigma_status_t anigma_hit_test_perform(anigma_scene_graph_t scene, float x, float y, anigma_entity_id_t* out_entity, anigma_capsule_error_t* err) {
    if (!out_entity) return ANIGMA_ERR_INVALID_ARG;
    out_entity->high = 0;
    out_entity->low = 0;
    return ANIGMA_OK;
}

anigma_status_t anigma_hit_test_create_buffer(anigma_hit_result_buffer_t* buffer, size_t capacity, void* arena) {
    (void)arena;
    if (!buffer) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    buffer->count = 0;
    buffer->capacity = static_cast<uint32_t>(capacity);
    buffer->results = nullptr;

    if (capacity == 0) {
        return ANIGMA_OK;
    }

    buffer->results = static_cast<anigma_hit_test_result_t*>(
        calloc(capacity, sizeof(anigma_hit_test_result_t)));
    if (!buffer->results) {
        buffer->capacity = 0;
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }

    return ANIGMA_OK;
}

void anigma_hit_test_destroy_buffer(anigma_hit_result_buffer_t* buffer) {
    if (!buffer) {
        return;
    }

    free(buffer->results);
    buffer->results = nullptr;
    buffer->count = 0;
    buffer->capacity = 0;
}

anigma_status_t anigma_hit_test_point(
    anigma_scene_graph_t scene,
    anigma_point_t point,
    uint32_t flags,
    uint32_t max_results,
    const uint64_t* exclude_ids,
    uint32_t exclude_count,
    anigma_hit_result_buffer_t* out_results,
    void* arena) {
    (void)scene;
    (void)point;
    (void)flags;
    (void)max_results;
    (void)exclude_ids;
    (void)exclude_count;
    (void)arena;
    if (!out_results) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    out_results->count = 0;
    return ANIGMA_OK;
}

anigma_status_t anigma_hit_test_rect(
    anigma_scene_graph_t scene,
    anigma_rect_t rect,
    uint32_t flags,
    anigma_hit_result_buffer_t* out_results,
    void* arena) {
    (void)scene;
    (void)rect;
    (void)flags;
    (void)arena;
    if (!out_results) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    out_results->count = 0;
    return ANIGMA_OK;
}

anigma_status_t anigma_get_node_bounds(
    anigma_scene_graph_t scene,
    uint64_t node_id,
    anigma_geometry_bounds_t* out_bounds) {
    (void)scene;
    (void)node_id;
    if (!out_bounds) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    memset(out_bounds, 0, sizeof(*out_bounds));
    return ANIGMA_OK;
}

} // extern "C"
