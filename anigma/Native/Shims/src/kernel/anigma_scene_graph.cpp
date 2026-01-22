#include "../../include/anigma_scene_graph.h"
#include <cstring>
#include <algorithm>
#include <new>

namespace {

constexpr size_t DEFAULT_NODE_CAPACITY = 256;
constexpr size_t DEFAULT_DIRTY_CAPACITY = 64;

int compare_entities_by_id(const void* a, const void* b) {
    const anigma_entity_id_t* ea = static_cast<const anigma_entity_id_t*>(a);
    const anigma_entity_id_t* eb = static_cast<const anigma_entity_id_t*>(b);
    
    if (ea->high != eb->high) {
        return (ea->high < eb->high) ? -1 : 1;
    }
    if (ea->low != eb->low) {
        return (ea->low < eb->low) ? -1 : 1;
    }
    return 0;
}

void multiply_transform(
    const anigma_transform_t* a,
    const anigma_transform_t* b,
    anigma_transform_t* result
) {
    for (int row = 0; row < 3; row++) {
        for (int col = 0; col < 3; col++) {
            int64_t sum = 0;
            for (int k = 0; k < 3; k++) {
                sum += static_cast<int64_t>(a->m[row][k]) * b->m[k][col];
            }
            result->m[row][col] = static_cast<anigma_coordinate_t>(
                (sum + ANIGMA_COORDINATE_SCALE / 2) / ANIGMA_COORDINATE_SCALE
            );
        }
    }
}

}  // namespace

anigma_status_t anigma_scene_create(
    anigma_scene_graph_t* graph,
    uint32_t initial_capacity,
    anigma_arena_t* arena
) {
    if (graph == nullptr || arena == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    size_t node_size = sizeof(anigma_scene_node_t) * initial_capacity;
    graph->nodes = static_cast<anigma_scene_node_t*>(
        anigma_arena_alloc(arena, node_size, alignof(anigma_scene_node_t))
    );
    
    if (graph->nodes == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    graph->node_capacity = initial_capacity;
    graph->node_count = 0;
    graph->version = 1;
    graph->dirty_count = 0;
    graph->dirty_capacity = DEFAULT_DIRTY_CAPACITY;
    graph->dirty_list = static_cast<anigma_entity_id_t*>(
        anigma_arena_alloc(
            arena,
            sizeof(anigma_entity_id_t) * DEFAULT_DIRTY_CAPACITY,
            alignof(anigma_entity_id_t)
        )
    );
    
    if (graph->dirty_list == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_scene_destroy(anigma_scene_graph_t* graph) {
    if (graph == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    graph->nodes = nullptr;
    graph->node_capacity = 0;
    graph->node_count = 0;
    graph->version = 0;
    graph->dirty_list = nullptr;
    graph->dirty_count = 0;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_scene_attach(
    anigma_scene_graph_t* graph,
    const anigma_scene_node_t* node
) {
    if (graph == nullptr || node == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    if (graph->node_count >= graph->node_capacity) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    anigma_scene_node_t* new_node = &graph->nodes[graph->node_count];
    *new_node = *node;
    new_node->world_transform_valid = false;
    
    if (!anigma_entity_id_equal(node->parent_id, (anigma_entity_id_t){0, 0})) {
        anigma_scene_node_t* parent = anigma_scene_find_node(graph, node->parent_id);
        if (parent != nullptr) {
            if (parent->child_count >= parent->child_capacity) {
                return ANIGMA_STATUS_BUFFER_TOO_SMALL;
            }
            parent->children[parent->child_count++] = node->id;
        }
    }
    
    graph->node_count++;
    graph->version++;
    
    if (graph->dirty_count < graph->dirty_capacity) {
        graph->dirty_list[graph->dirty_count++] = node->id;
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_scene_detach(
    anigma_scene_graph_t* graph,
    anigma_entity_id_t node_id
) {
    if (graph == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    for (size_t i = 0; i < graph->node_count; i++) {
        if (anigma_entity_id_equal(graph->nodes[i].id, node_id)) {
            graph->nodes[i] = graph->nodes[graph->node_count - 1];
            graph->node_count--;
            graph->version++;
            return ANIGMA_STATUS_SUCCESS;
        }
    }
    
    return ANIGMA_STATUS_NOT_FOUND;
}

anigma_status_t anigma_scene_update_transform(
    anigma_scene_graph_t* graph,
    anigma_entity_id_t node_id,
    const anigma_transform_t* transform
) {
    if (graph == nullptr || transform == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    anigma_scene_node_t* node = anigma_scene_find_node(graph, node_id);
    if (node == nullptr) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    node->local_transform = *transform;
    node->world_transform_valid = false;
    
    if (graph->dirty_count < graph->dirty_capacity) {
        graph->dirty_list[graph->dirty_count++] = node_id;
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

static void mark_dirty(anigma_scene_graph_t* graph, anigma_entity_id_t node_id) {
    for (size_t i = 0; i < graph->dirty_count; i++) {
        if (anigma_entity_id_equal(graph->dirty_list[i], node_id)) {
            return;
        }
    }
    
    if (graph->dirty_count < graph->dirty_capacity) {
        graph->dirty_list[graph->dirty_count++] = node_id;
    }
}

anigma_status_t anigma_scene_evaluate_transforms(
    anigma_scene_graph_t* graph
) {
    if (graph == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    for (size_t di = 0; di < graph->dirty_count; di++) {
        anigma_entity_id_t dirty_id = graph->dirty_list[di];
        
        for (size_t ni = 0; ni < graph->node_count; ni++) {
            if (anigma_entity_id_equal(graph->nodes[ni].id, dirty_id)) {
                anigma_scene_node_t* node = &graph->nodes[ni];
                
                if (!anigma_entity_id_equal(node->parent_id, (anigma_entity_id_t){0, 0})) {
                    anigma_scene_node_t* parent = anigma_scene_find_node(graph, node->parent_id);
                    if (parent != nullptr) {
                        if (parent->world_transform_valid) {
                            multiply_transform(&parent->world_transform, &node->local_transform, &node->world_transform);
                            node->world_transform_valid = true;
                        } else {
                            node->world_transform_valid = false;
                        }
                    } else {
                        node->world_transform = node->local_transform;
                        node->world_transform_valid = true;
                    }
                } else {
                    node->world_transform = node->local_transform;
                    node->world_transform_valid = true;
                }
                
                for (uint32_t ci = 0; ci < node->child_count; ci++) {
                    mark_dirty(graph, node->children[ci]);
                }
                
                break;
            }
        }
    }
    
    graph->dirty_count = 0;
    return ANIGMA_STATUS_SUCCESS;
}

anigma_scene_node_t* anigma_scene_find_node(
    anigma_scene_graph_t* graph,
    anigma_entity_id_t node_id
) {
    if (graph == nullptr) {
        return nullptr;
    }
    
    for (size_t i = 0; i < graph->node_count; i++) {
        if (anigma_entity_id_equal(graph->nodes[i].id, node_id)) {
            return &graph->nodes[i];
        }
    }
    
    return nullptr;
}

static void traverse_pre_order(
    anigma_scene_node_t* node,
    void (*callback)(anigma_scene_node_t*, void*),
    void* context,
    anigma_entity_id_t* visited,
    size_t* visited_count,
    size_t visited_capacity
) {
    for (size_t i = 0; i < *visited_count; i++) {
        if (anigma_entity_id_equal(visited[i], node->id)) {
            return;
        }
    }
    
    if (*visited_count < visited_capacity) {
        visited[(*visited_count)++] = node->id;
    }
    
    callback(node, context);
    
    for (uint32_t i = 0; i < node->child_count; i++) {
        anigma_scene_node_t* child = anigma_scene_find_node(
            reinterpret_cast<anigma_scene_graph_t*>(0xDEADBEEF),
            node->children[i]
        );
    }
}

void anigma_scene_traverse(
    anigma_scene_graph_t* graph,
    anigma_traversal_order_t order,
    void (*callback)(anigma_scene_node_t*, void*),
    void* context
) {
    if (graph == nullptr || callback == nullptr) {
        return;
    }
    
    switch (order) {
        case ANIGMA_TRAVERSAL_PRE_ORDER:
            for (size_t i = 0; i < graph->node_count; i++) {
                anigma_scene_node_t* node = &graph->nodes[i];
                callback(node, context);
            }
            break;
            
        case ANIGMA_TRAVERSAL_LAYER_ORDER: {
            anigma_scene_node_t* sorted = static_cast<anigma_scene_node_t*>(
                alloca(sizeof(anigma_scene_node_t) * graph->node_count)
            );
            std::memcpy(sorted, graph->nodes, sizeof(anigma_scene_node_t) * graph->node_count);
            
            std::sort(sorted, sorted + graph->node_count, [](const anigma_scene_node_t& a, const anigma_scene_node_t& b) {
                if (a.layer_index != b.layer_index) {
                    return a.layer_index < b.layer_index;
                }
                if (a.render_order != b.render_order) {
                    return a.render_order < b.render_order;
                }
                return anigma_entity_id_less(a.id, b.id);
            });
            
            for (size_t i = 0; i < graph->node_count; i++) {
                callback(&sorted[i], context);
            }
            break;
        }
            
        default:
            for (size_t i = 0; i < graph->node_count; i++) {
                callback(&graph->nodes[i], context);
            }
            break;
    }
}

uint32_t anigma_scene_get_version(anigma_scene_graph_t* graph) {
    return (graph != nullptr) ? graph->version : 0;
}
