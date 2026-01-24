#ifndef ANIGMA_SCENE_GRAPH_H
#define ANIGMA_SCENE_GRAPH_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef anigma_capsule_handle_t anigma_scene_graph_t;

anigma_status_t anigma_scene_graph_create(anigma_scene_graph_t* out_handle, anigma_capsule_error_t* err);
anigma_status_t anigma_scene_graph_destroy(anigma_scene_graph_t handle, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
