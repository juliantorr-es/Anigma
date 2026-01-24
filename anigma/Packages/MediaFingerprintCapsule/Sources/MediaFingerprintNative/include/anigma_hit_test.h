#ifndef ANIGMA_HIT_TEST_H
#define ANIGMA_HIT_TEST_H

#include "anigma_capsule_core.h"
#include "anigma_scene_graph.h"
#include "anigma_kernel_types.h"

#ifdef __cplusplus
extern "C" {
#endif

anigma_status_t anigma_hit_test_perform(anigma_scene_graph_t scene, float x, float y, anigma_entity_id_t* out_entity, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
