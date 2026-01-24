#include "anigma_layout_engine_capsule.h"
#include <string.h>

extern "C" {

anigma_capsule_identity_t anigma_layout_engine_capsule_get_identity(void) {
    static const anigma_capsule_identity_t identity = { "layout_engine_capsule", "v1.0.0-stub", "1.0", 1 };
    return identity;
}

anigma_status_t anigma_layout_engine_capsule_create(anigma_layout_engine_capsule_t* out_handle, anigma_capsule_error_t* err) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;
    *out_handle = (anigma_layout_engine_capsule_t)1;
    return ANIGMA_OK;
}

anigma_status_t anigma_layout_engine_capsule_destroy(anigma_layout_engine_capsule_t handle, anigma_capsule_error_t* err) {
    return ANIGMA_OK;
}

} // extern "C"
