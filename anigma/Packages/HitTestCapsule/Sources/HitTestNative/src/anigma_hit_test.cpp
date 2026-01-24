#include "anigma_hit_test.h"
#include <string.h>

extern "C" {

anigma_status_t anigma_hit_test_perform(anigma_scene_graph_t scene, float x, float y, anigma_entity_id_t* out_entity, anigma_capsule_error_t* err) {
    if (!out_entity) return ANIGMA_ERR_INVALID_ARG;
    out_entity->high = 0;
    out_entity->low = 0;
    return ANIGMA_OK;
}

} // extern "C"
