#include "anigma_render_plan.h"
#include <string.h>

extern "C" {

anigma_status_t anigma_render_plan_create(anigma_render_plan_t* out_handle, anigma_capsule_error_t* err) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;
    *out_handle = (anigma_render_plan_t)1;
    return ANIGMA_OK;
}

anigma_status_t anigma_render_plan_destroy(anigma_render_plan_t handle, anigma_capsule_error_t* err) {
    return ANIGMA_OK;
}

} // extern "C"
