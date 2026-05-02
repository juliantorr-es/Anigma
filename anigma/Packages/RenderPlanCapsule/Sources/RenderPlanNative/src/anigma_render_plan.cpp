#include "anigma_render_plan.h"
#include <cstring>
#include <cstdlib>
#include <new>

namespace {

struct anigma_render_plan_builder_impl_t {
    uint32_t op_capacity;
    uint32_t resource_capacity;
    uint32_t op_count;
    uint32_t resource_count;
};

static anigma_status_t create_empty_plan(anigma_render_plan_t* out_handle) {
    if (!out_handle) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    auto* plan = static_cast<anigma_plan_header_t*>(std::malloc(sizeof(anigma_plan_header_t)));
    if (!plan) {
        return ANIGMA_ERR_INTERNAL;
    }

    std::memset(plan, 0, sizeof(anigma_plan_header_t));
    plan->magic = ANIGMA_PLAN_MAGIC;
    plan->version = ANIGMA_PLAN_VERSION;
    *out_handle = reinterpret_cast<anigma_render_plan_t>(plan);
    return ANIGMA_OK;
}

} // namespace

extern "C" {

anigma_status_t anigma_render_plan_create(anigma_render_plan_t* out_handle, anigma_capsule_error_t* err) {
    return create_empty_plan(out_handle);
}

anigma_status_t anigma_render_plan_destroy(anigma_render_plan_t handle, anigma_capsule_error_t* err) {
    if (handle) free(handle);
    return ANIGMA_OK;
}

anigma_status_t anigma_render_plan_compute_hash(anigma_render_plan_t handle) {
    return handle ? ANIGMA_OK : ANIGMA_ERR_INVALID_ARG;
}

anigma_status_t anigma_render_plan_builder_create(
    anigma_render_plan_builder_t* out_handle,
    uint32_t op_capacity,
    uint32_t resource_capacity,
    anigma_capsule_error_t* err
) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;

    auto* builder = new anigma_render_plan_builder_impl_t{
        op_capacity,
        resource_capacity,
        0,
        0,
    };
    if (!builder) return ANIGMA_ERR_INTERNAL;

    *out_handle = reinterpret_cast<anigma_render_plan_builder_t>(builder);
    return ANIGMA_OK;
}

anigma_status_t anigma_render_plan_builder_destroy(anigma_render_plan_builder_t handle) {
    delete reinterpret_cast<anigma_render_plan_builder_impl_t*>(handle);
    return ANIGMA_OK;
}

anigma_status_t anigma_render_plan_builder_add_clear(
    anigma_render_plan_builder_t handle,
    uint32_t layer_id,
    anigma_resource_ref_t color
) {
    auto* builder = reinterpret_cast<anigma_render_plan_builder_impl_t*>(handle);
    if (!builder) return ANIGMA_ERR_INVALID_ARG;
    (void)layer_id;
    (void)color;
    builder->op_count += 1;
    return ANIGMA_OK;
}

anigma_status_t anigma_render_plan_builder_add_rect(
    anigma_render_plan_builder_t handle,
    uint32_t layer_id,
    const anigma_rect_t* rect,
    const anigma_affine_i32_t* transform,
    const anigma_resource_ref_t* material
) {
    auto* builder = reinterpret_cast<anigma_render_plan_builder_impl_t*>(handle);
    if (!builder || !rect || !transform || !material) return ANIGMA_ERR_INVALID_ARG;
    (void)layer_id;
    builder->op_count += 1;
    builder->resource_count += 1;
    return ANIGMA_OK;
}

anigma_status_t anigma_render_plan_build(
    anigma_render_plan_builder_t handle,
    anigma_render_plan_t* out_plan
) {
    auto* builder = reinterpret_cast<anigma_render_plan_builder_impl_t*>(handle);
    if (!builder || !out_plan) return ANIGMA_ERR_INVALID_ARG;

    auto status = create_empty_plan(out_plan);
    if (status != ANIGMA_OK) return status;

    auto* plan = reinterpret_cast<anigma_plan_header_t*>(*out_plan);
    plan->op_count = builder->op_count;
    plan->resource_count = builder->resource_count;
    return ANIGMA_OK;
}

anigma_status_t anigma_generate_render_plan(
    anigma_scene_graph_t scene,
    const anigma_render_plan_request_t* request,
    anigma_render_plan_t* out_plan,
    anigma_capsule_error_t* err
) {
    (void)scene;
    (void)request;
    (void)err;
    return create_empty_plan(out_plan);
}

} // extern "C"
