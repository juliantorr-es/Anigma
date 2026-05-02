#ifndef ANIGMA_RENDER_PLAN_H
#define ANIGMA_RENDER_PLAN_H

#include "anigma_capsule_core.h"
#include "anigma_kernel_types.h"
#include "anigma_scene_graph.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef anigma_capsule_handle_t anigma_render_plan_t;
typedef anigma_capsule_handle_t anigma_render_plan_builder_t;

#define ANIGMA_PLAN_MAGIC 0x504C414E // "PLAN"
#define ANIGMA_PLAN_VERSION 1

// 3x2 Affine Transform (2D) using 16.16 fixed point or scaled ints
typedef struct {
    int32_t m[6];
} anigma_affine_i32_t;

typedef struct {
    uint32_t r, g, b, a;
} anigma_color_rgba_t;

typedef struct {
    anigma_color_rgba_t color;
    uint32_t flags;
} anigma_paint_t;

typedef struct {
    uint32_t magic;
    uint32_t version;
    uint32_t coord_scale;
    uint32_t tick_hz;
    
    uint32_t op_count;
    uint32_t transform_count;
    uint32_t paint_count;
    uint32_t resource_count;
    
    uint32_t ops_offset;
    uint32_t transforms_offset;
    uint32_t paints_offset;
    uint32_t resources_offset;
    uint32_t payload_offset;
    uint32_t payload_size;
} anigma_plan_header_t;

anigma_status_t anigma_render_plan_create(anigma_render_plan_t* out_handle, anigma_capsule_error_t* err);
anigma_status_t anigma_render_plan_destroy(anigma_render_plan_t handle, anigma_capsule_error_t* err);
anigma_status_t anigma_render_plan_compute_hash(anigma_render_plan_t handle);

anigma_status_t anigma_render_plan_builder_create(
    anigma_render_plan_builder_t* out_handle,
    uint32_t op_capacity,
    uint32_t resource_capacity,
    anigma_capsule_error_t* err);
anigma_status_t anigma_render_plan_builder_destroy(anigma_render_plan_builder_t handle);
anigma_status_t anigma_render_plan_builder_add_clear(
    anigma_render_plan_builder_t handle,
    uint32_t layer_id,
    anigma_resource_ref_t color);
anigma_status_t anigma_render_plan_builder_add_rect(
    anigma_render_plan_builder_t handle,
    uint32_t layer_id,
    const anigma_rect_t* rect,
    const anigma_affine_i32_t* transform,
    const anigma_resource_ref_t* material);
anigma_status_t anigma_render_plan_build(
    anigma_render_plan_builder_t handle,
    anigma_render_plan_t* out_plan);
anigma_status_t anigma_generate_render_plan(
    anigma_scene_graph_t scene,
    const anigma_render_plan_request_t* request,
    anigma_render_plan_t* out_plan,
    anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
