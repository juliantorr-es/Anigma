#include "anigma_scene_graph.h"
#include <string.h>
#include <stdlib.h>
#include <unordered_map>
#include <vector>

// Internal scene graph implementation
struct SceneGraphImpl {
    std::unordered_map<uint64_t, anigma_scene_node_t> nodes;
};

extern "C" {

anigma_status_t anigma_scene_graph_create(anigma_scene_graph_t* out_handle, anigma_capsule_error_t* err) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;
    
    SceneGraphImpl* impl = new (std::nothrow) SceneGraphImpl();
    if (!impl) {
        if (err) {
            err->code = ANIGMA_ERR_OUT_OF_MEMORY;
            err->message = "Failed to allocate scene graph";
        }
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    *out_handle = (anigma_scene_graph_t)impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_scene_graph_destroy(anigma_scene_graph_t handle, anigma_capsule_error_t* err) {
    if (!handle) return ANIGMA_OK;
    
    SceneGraphImpl* impl = (SceneGraphImpl*)handle;
    delete impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_scene_graph_attach(
    anigma_scene_graph_t scene,
    const anigma_scene_node_t* node,
    anigma_capsule_error_t* err
) {
    if (!scene || !node) return ANIGMA_ERR_INVALID_ARG;
    
    SceneGraphImpl* impl = (SceneGraphImpl*)scene;
    impl->nodes[node->entity_id] = *node;
    return ANIGMA_OK;
}

anigma_status_t anigma_scene_graph_detach(
    anigma_scene_graph_t scene,
    uint64_t entity_id,
    anigma_capsule_error_t* err
) {
    if (!scene) return ANIGMA_ERR_INVALID_ARG;
    
    SceneGraphImpl* impl = (SceneGraphImpl*)scene;
    impl->nodes.erase(entity_id);
    return ANIGMA_OK;
}

anigma_status_t anigma_scene_graph_update_transform(
    anigma_scene_graph_t scene,
    uint64_t entity_id,
    const anigma_transform_t* transform,
    anigma_capsule_error_t* err
) {
    if (!scene || !transform) return ANIGMA_ERR_INVALID_ARG;
    
    SceneGraphImpl* impl = (SceneGraphImpl*)scene;
    auto it = impl->nodes.find(entity_id);
    if (it == impl->nodes.end()) {
        if (err) {
            err->code = ANIGMA_STATUS_NOT_FOUND;
            err->message = "Node not found";
        }
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    it->second.local_transform = *transform;
    return ANIGMA_OK;
}

anigma_status_t anigma_scene_graph_get_node(
    anigma_scene_graph_t scene,
    uint64_t entity_id,
    anigma_scene_node_t* out_node,
    anigma_capsule_error_t* err
) {
    if (!scene || !out_node) return ANIGMA_ERR_INVALID_ARG;
    
    SceneGraphImpl* impl = (SceneGraphImpl*)scene;
    auto it = impl->nodes.find(entity_id);
    if (it == impl->nodes.end()) {
        if (err) {
            err->code = ANIGMA_STATUS_NOT_FOUND;
            err->message = "Node not found";
        }
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    *out_node = it->second;
    return ANIGMA_OK;
}

anigma_status_t anigma_scene_graph_get_node_count(
    anigma_scene_graph_t scene,
    size_t* out_count,
    anigma_capsule_error_t* err
) {
    if (!scene || !out_count) return ANIGMA_ERR_INVALID_ARG;
    
    SceneGraphImpl* impl = (SceneGraphImpl*)scene;
    *out_count = impl->nodes.size();
    return ANIGMA_OK;
}

anigma_status_t anigma_scene_graph_get_nodes(
    anigma_scene_graph_t scene,
    anigma_scene_node_t* buffer,
    size_t capacity,
    size_t* out_count,
    anigma_capsule_error_t* err
) {
    if (!scene || !out_count) return ANIGMA_ERR_INVALID_ARG;
    
    SceneGraphImpl* impl = (SceneGraphImpl*)scene;
    size_t count = impl->nodes.size();
    *out_count = count;
    
    if (buffer && capacity >= count) {
        size_t i = 0;
        for (const auto& pair : impl->nodes) {
            buffer[i++] = pair.second;
        }
    } else if (buffer && capacity < count) {
        return ANIGMA_ERR_BUFFER_TOO_SMALL;
    }
    
    return ANIGMA_OK;
}

// Helper to multiply 3x3 transforms
static void multiply_transforms(const anigma_transform_t* parent, const anigma_transform_t* local, anigma_transform_t* out) {
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            int64_t sum = 0;
            for (int k = 0; k < 3; k++) {
                sum += (int64_t)parent->m[i][k] * (int64_t)local->m[k][j];
            }
            // Scale back by ANIGMA_COORDINATE_SCALE (256)
            out->m[i][j] = (int32_t)(sum / 256);
        }
    }
}

anigma_status_t anigma_scene_graph_evaluate_transforms(
    anigma_scene_graph_t scene,
    anigma_capsule_error_t* err
) {
    if (!scene) return ANIGMA_ERR_INVALID_ARG;
    
    SceneGraphImpl* impl = (SceneGraphImpl*)scene;
    
    // Simple evaluation: for each node, compute world transform from parent chain
    for (auto& pair : impl->nodes) {
        anigma_scene_node_t& node = pair.second;
        
        if (node.parent_id == 0 || node.parent_id == node.entity_id) {
            // Root node: world = local
            node.world_transform = node.local_transform;
        } else {
            // Find parent and multiply transforms
            auto parent_it = impl->nodes.find(node.parent_id);
            if (parent_it != impl->nodes.end()) {
                multiply_transforms(&parent_it->second.world_transform, &node.local_transform, &node.world_transform);
            } else {
                // Parent not found, treat as root
                node.world_transform = node.local_transform;
            }
        }
    }
    
    return ANIGMA_OK;
}

} // extern "C"
