#ifndef ANIGMA_RENDER_PLAN_H
#define ANIGMA_RENDER_PLAN_H

#include "anigma_kernel_types.h"
#include <cstddef>

#if defined(__cplusplus)
extern "C" {
#endif

using anigma_render_flags_t = uint32_t;
using anigma_resource_type_t = uint32_t;

enum : anigma_render_flags_t {
    ANIGMA_RENDER_FLAG_VISIBLE_ONLY = 1 << 0,
    ANIGMA_RENDER_FLAG_DISABLE_CULLING = 1 << 1,
    ANIGMA_RENDER_FLAG_SHOW_BOUNDS = 1 << 2,
    ANIGMA_RENDER_FLAG_SHOW_HIT_REGIONS = 1 << 3,
    ANIGMA_RENDER_FLAG_DEBUG_LAYERS = 1 << 4,
};

enum : anigma_resource_type_t {
    ANIGMA_RESOURCE_COLOR = 0,
    ANIGMA_RESOURCE_GRADIENT = 1,
    ANIGMA_RESOURCE_IMAGE = 2,
    ANIGMA_RESOURCE_PATTERN = 3,
    ANIGMA_RESOURCE_TEXT = 4,
};

struct anigma_scene_graph_t;
struct anigma_layer_info_t;

struct anigma_render_plan_builder_t {
    anigma_draw_op_t* ops;
    uint32_t op_count;
    uint32_t op_capacity;
    anigma_resource_ref_t* resources;
    uint32_t resource_count;
    uint32_t resource_capacity;
    anigma_arena_t* arena;
};

anigma_status_t anigma_render_plan_builder_create(
    anigma_render_plan_builder_t* builder,
    uint32_t initial_op_capacity,
    uint32_t initial_resource_capacity,
    anigma_arena_t* arena
);

anigma_status_t anigma_render_plan_builder_destroy(anigma_render_plan_builder_t* builder);

anigma_status_t anigma_render_plan_builder_add_clear(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    anigma_resource_ref_t background_color
);

anigma_status_t anigma_render_plan_builder_add_rect(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    const anigma_rect_t* rect,
    const anigma_transform_t* transform,
    const anigma_resource_ref_t* material
);

anigma_status_t anigma_render_plan_builder_add_path(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    uint64_t path_id,
    const anigma_transform_t* transform,
    const anigma_resource_ref_t* fill_material,
    const anigma_resource_ref_t* stroke_material,
    anigma_coordinate_t stroke_width
);

anigma_status_t anigma_render_plan_builder_add_text(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    uint64_t text_run_id,
    anigma_point_t position,
    const anigma_resource_ref_t* text_material
);

anigma_status_t anigma_render_plan_builder_add_image(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    uint64_t image_id,
    anigma_rect_t destination,
    const anigma_transform_t* transform
);

anigma_status_t anigma_render_plan_build(
    const anigma_render_plan_builder_t* builder,
    anigma_render_plan_t** plan
);

anigma_status_t anigma_render_plan_compute_hash(anigma_render_plan_t* plan);

anigma_status_t anigma_generate_render_plan(
    const anigma_scene_graph_t* graph,
    const anigma_render_plan_request_t* request,
    anigma_render_plan_t** plan,
    anigma_arena_t* arena
);

anigma_status_t anigma_cull_invisible(
    const anigma_scene_graph_t* graph,
    const anigma_rect_t* viewport,
    anigma_entity_id_t* visible_entities,
    uint32_t* visible_count,
    uint32_t max_visible,
    anigma_arena_t* arena
);

anigma_status_t anigma_sort_by_layer(
    const anigma_scene_graph_t* graph,
    anigma_entity_id_t* sorted_entities,
    uint32_t* sorted_count,
    uint32_t max_count,
    anigma_arena_t* arena
);

#if defined(__cplusplus)
}
#endif

#endif
