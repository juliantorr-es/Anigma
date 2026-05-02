#ifndef ANIGMA_HIT_TEST_H
#define ANIGMA_HIT_TEST_H

#include "anigma_capsule_core.h"
#include "anigma_scene_graph.h"
#include "anigma_kernel_types.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint64_t node_id;
    float distance;
    anigma_point_t local_point;
    uint32_t reason;
} anigma_hit_test_result_t;

typedef struct {
    uint32_t count;
    uint32_t capacity;
    anigma_hit_test_result_t* results;
} anigma_hit_result_buffer_t;

typedef struct {
    float min_x;
    float min_y;
    float max_x;
    float max_y;
} anigma_geometry_bounds_t;

anigma_status_t anigma_hit_test_perform(anigma_scene_graph_t scene, float x, float y, anigma_entity_id_t* out_entity, anigma_capsule_error_t* err);
anigma_status_t anigma_hit_test_create_buffer(anigma_hit_result_buffer_t* buffer, size_t capacity, void* arena);
void anigma_hit_test_destroy_buffer(anigma_hit_result_buffer_t* buffer);
anigma_status_t anigma_hit_test_point(
    anigma_scene_graph_t scene,
    anigma_point_t point,
    uint32_t flags,
    uint32_t max_results,
    const uint64_t* exclude_ids,
    uint32_t exclude_count,
    anigma_hit_result_buffer_t* out_results,
    void* arena);
anigma_status_t anigma_hit_test_rect(
    anigma_scene_graph_t scene,
    anigma_rect_t rect,
    uint32_t flags,
    anigma_hit_result_buffer_t* out_results,
    void* arena);
anigma_status_t anigma_get_node_bounds(
    anigma_scene_graph_t scene,
    uint64_t node_id,
    anigma_geometry_bounds_t* out_bounds);

#ifdef __cplusplus
}
#endif

#endif
