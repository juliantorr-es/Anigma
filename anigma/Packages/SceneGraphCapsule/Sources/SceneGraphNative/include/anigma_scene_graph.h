#ifndef ANIGMA_SCENE_GRAPH_H
#define ANIGMA_SCENE_GRAPH_H

#include "anigma_capsule_core.h"
#include "anigma_kernel_types.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef anigma_capsule_handle_t anigma_scene_graph_t;

typedef struct {
    uint64_t entity_id;
    uint64_t parent_id;
    anigma_transform_t local_transform;
    anigma_transform_t world_transform;
    uint32_t flags;
    uint32_t layer_mask;
} anigma_scene_node_t;

anigma_status_t anigma_scene_graph_create(anigma_scene_graph_t* out_handle, anigma_capsule_error_t* err);
anigma_status_t anigma_scene_graph_destroy(anigma_scene_graph_t handle, anigma_capsule_error_t* err);
anigma_status_t anigma_scene_graph_attach(anigma_scene_graph_t scene, const anigma_scene_node_t* node, anigma_capsule_error_t* err);
anigma_status_t anigma_scene_graph_detach(anigma_scene_graph_t scene, uint64_t entity_id, anigma_capsule_error_t* err);
anigma_status_t anigma_scene_graph_update_transform(anigma_scene_graph_t scene, uint64_t entity_id, const anigma_transform_t* transform, anigma_capsule_error_t* err);
anigma_status_t anigma_scene_graph_get_node(anigma_scene_graph_t scene, uint64_t entity_id, anigma_scene_node_t* out_node, anigma_capsule_error_t* err);
anigma_status_t anigma_scene_graph_get_node_count(anigma_scene_graph_t scene, size_t* out_count, anigma_capsule_error_t* err);
anigma_status_t anigma_scene_graph_get_nodes(anigma_scene_graph_t scene, anigma_scene_node_t* buffer, size_t capacity, size_t* out_count, anigma_capsule_error_t* err);
anigma_status_t anigma_scene_graph_evaluate_transforms(anigma_scene_graph_t scene, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
