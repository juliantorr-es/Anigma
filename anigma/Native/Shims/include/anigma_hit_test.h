#ifndef ANIGMA_HIT_TEST_H
#define ANIGMA_HIT_TEST_H

#include "anigma_kernel_types.h"
#include <cstddef>

#if defined(__cplusplus)
extern "C" {
#endif

using anigma_hit_reason_t = uint8_t;
using anigma_hit_flags_t = uint32_t;

enum : anigma_hit_reason_t {
    ANIGMA_HIT_BOUNDS = 0,
    ANIGMA_HIT_FILL = 1,
    ANIGMA_HIT_STROKE = 2,
    ANIGMA_HIT_TEXT = 3,
    ANIGMA_HIT_IMAGE = 4,
};

struct anigma_scene_graph_t;

struct anigma_hit_result_buffer_t {
    anigma_hit_result_t* results;
    uint32_t count;
    uint32_t capacity;
    uint32_t total_considered;
};

struct anigma_geometry_bounds_t {
    anigma_coordinate_t min_x;
    anigma_coordinate_t min_y;
    anigma_coordinate_t max_x;
    anigma_coordinate_t max_y;
};

anigma_status_t anigma_hit_test_create_buffer(
    anigma_hit_result_buffer_t* buffer,
    uint32_t max_results,
    anigma_arena_t* arena
);

anigma_status_t anigma_hit_test_destroy_buffer(anigma_hit_result_buffer_t* buffer);

anigma_status_t anigma_hit_test_point(
    const anigma_scene_graph_t* graph,
    anigma_point_t world_point,
    uint32_t flags,
    uint32_t max_results,
    const anigma_entity_id_t* exclude_ids,
    uint32_t exclude_count,
    anigma_hit_result_buffer_t* results,
    anigma_arena_t* arena
);

anigma_status_t anigma_hit_test_rect(
    const anigma_scene_graph_t* graph,
    anigma_rect_t rect,
    uint32_t flags,
    anigma_hit_result_buffer_t* results,
    anigma_arena_t* arena
);

anigma_status_t anigma_get_node_bounds(
    const anigma_scene_graph_t* graph,
    anigma_entity_id_t node_id,
    anigma_geometry_bounds_t* bounds
);

anigma_status_t anigma_world_to_local(
    const anigma_transform_t* world_transform,
    anigma_point_t world_point,
    anigma_point_t* local_point
);

int anigma_point_in_rect(anigma_point_t point, anigma_rect_t rect);

int anigma_point_in_polygon(
    anigma_point_t point,
    const anigma_point_t* polygon,
    uint32_t point_count,
    int fill_rule_even_odd
);

void anigma_hit_result_sort(
    anigma_hit_result_t* results,
    uint32_t count,
    int (*compare)(const void*, const void*)
);

#if defined(__cplusplus)
}
#endif

#endif
