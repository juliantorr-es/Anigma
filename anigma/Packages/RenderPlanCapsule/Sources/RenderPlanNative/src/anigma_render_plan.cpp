#include "anigma_render_plan.h"
#include <cstring>
#include <cstdlib>
#include <new>

extern "C" {

anigma_status_t anigma_render_plan_create(anigma_render_plan_t* out_handle, anigma_capsule_error_t* err) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;
    
    auto* plan = (anigma_plan_header_t*)malloc(sizeof(anigma_plan_header_t));
    if (!plan) return ANIGMA_ERR_INTERNAL;
    
    memset(plan, 0, sizeof(anigma_plan_header_t));
    plan->magic = ANIGMA_PLAN_MAGIC;
    plan->version = ANIGMA_PLAN_VERSION;
    
    *out_handle = reinterpret_cast<anigma_render_plan_t>(plan);
    return ANIGMA_OK;
}

anigma_status_t anigma_render_plan_destroy(anigma_render_plan_t handle, anigma_capsule_error_t* err) {
    if (handle) free(handle);
    return ANIGMA_OK;
}

} // extern "C"
