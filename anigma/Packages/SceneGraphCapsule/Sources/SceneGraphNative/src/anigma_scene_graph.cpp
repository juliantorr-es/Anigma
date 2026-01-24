#include "anigma_scene_graph.h"
#include <string.h>

extern "C" {

anigma_status_t anigma_scene_graph_create(anigma_scene_graph_t* out_handle, anigma_capsule_error_t* err) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;
    *out_handle = (anigma_scene_graph_t)1;
    return ANIGMA_OK;
}

anigma_status_t anigma_scene_graph_destroy(anigma_scene_graph_t handle, anigma_capsule_error_t* err) {
    return ANIGMA_OK;
}

} // extern "C"
