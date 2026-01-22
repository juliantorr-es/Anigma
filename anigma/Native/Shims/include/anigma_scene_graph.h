#ifndef ANIGMA_SCENE_GRAPH_H
#define ANIGMA_SCENE_GRAPH_H

#include "anigma_kernel_types.h"
#include <cstddef>

#if defined(__cplusplus)
extern "C" {
#endif

struct anigma_scene_node_t {
    anigma_entity_id_t id;
    anigma_entity_id_t parent_id;
    uint32_t child_count;
    uint32_t child_capacity;
    anigma_entity_id_t* children;
    anigma_transform_t local_transform;
    anigma_transform_t world_transform;
    uint32_t layer_index;
    uint32_t render_order;
    uint32_t hit_test_group;
    uint64_t flags;
    bool world_transform_valid;
};

struct anigma_scene_graph_t {
    anigma_scene_node_t* nodes;
    size_t node_capacity;
    size_t node_count;
    uint32_t version;
    uint32_t dirty_count;
    anigma_entity_id_t* dirty_list;
    size_t dirty_capacity;
};

anigma_status_t anigma_scene_create(
    anigma_scene_graph_t* graph,
    uint32_t initial_capacity,
    anigma_arena_t* arena
);

anigma_status_t anigma_scene_destroy(anigma_scene_graph_t* graph);

anigma_status_t anigma_scene_attach(
    anigma_scene_graph_t* graph,
    const anigma_scene_node_t* node
);

anigma_status_t anigma_scene_detach(
    anigma_scene_graph_t* graph,
    anigma_entity_id_t node_id
);

anigma_status_t anigma_scene_update_transform(
    anigma_scene_graph_t* graph,
    anigma_entity_id_t node_id,
    const anigma_transform_t* transform
);

anigma_status_t anigma_scene_evaluate_transforms(
    anigma_scene_graph_t* graph
);

anigma_scene_node_t* anigma_scene_find_node(
    anigma_scene_graph_t* graph,
    anigma_entity_id_t node_id
);

void anigma_scene_traverse(
    anigma_scene_graph_t* graph,
    anigma_traversal_order_t order,
    void (*callback)(anigma_scene_node_t*, void*),
    void* context
);

uint32_t anigma_scene_get_version(anigma_scene_graph_t* graph);

#if defined(__cplusplus)
}
#endif

#endif
