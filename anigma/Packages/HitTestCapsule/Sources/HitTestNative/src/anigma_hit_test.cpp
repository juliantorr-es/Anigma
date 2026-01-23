#include "../../include/anigma_hit_test.h"
#include "../../include/anigma_scene_graph.h"
#include <cstring>
#include <algorithm>
#include <new>

namespace {

int compare_hit_results(const void* a, const void* b) {
    const anigma_hit_result_t* ha = static_cast<const anigma_hit_result_t*>(a);
    const anigma_hit_result_t* hb = static_cast<const anigma_hit_result_t*>(b);
    
    if (ha->layer_index != hb->layer_index) {
        return (ha->layer_index < hb->layer_index) ? 1 : -1;
    }
    if (ha->render_order != hb->render_order) {
        return (ha->render_order < hb->render_order) ? 1 : -1;
    }
    return anigma_entity_id_less(ha->entity_id, hb->entity_id) ? 1 : -1;
}

int is_excluded(
    anigma_entity_id_t id,
    const anigma_entity_id_t* exclude_ids,
    uint32_t exclude_count
) {
    for (uint32_t i = 0; i < exclude_count; i++) {
        if (anigma_entity_id_equal(id, exclude_ids[i])) {
            return 1;
        }
    }
    return 0;
}

int point_in_rectangle(
    anigma_coordinate_t px,
    anigma_coordinate_t py,
    const anigma_rect_t* rect
) {
    return (px >= rect->x && px <= rect->x + rect->width &&
            py >= rect->y && py <= rect->y + rect->height);
}

int winding_number(
    anigma_coordinate_t px,
    anigma_coordinate_t py,
    const anigma_point_t* polygon,
    uint32_t count
) {
    int winding = 0;
    
    for (uint32_t i = 0; i < count; i++) {
        const anigma_point_t& p1 = polygon[i];
        const anigma_point_t& p2 = polygon[(i + 1) % count];
        
        if (p1.y <= py) {
            if (p2.y > py) {
                int64_t cross = static_cast<int64_t>(p2.x - p1.x) * (py - p1.y) -
                               static_cast<int64_t>(px - p1.x) * (p2.y - p1.y);
                if (cross > 0) {
                    winding++;
                } else if (cross < 0) {
                    winding--;
                }
            }
        } else {
            if (p2.y <= py) {
                int64_t cross = static_cast<int64_t>(p2.x - p1.x) * (py - p1.y) -
                               static_cast<int64_t>(px - p1.x) * (p2.y - p1.y);
                if (cross > 0) {
                    winding++;
                } else if (cross < 0) {
                    winding--;
                }
            }
        }
    }
    
    return winding;
}

}  // namespace

anigma_status_t anigma_hit_test_create_buffer(
    anigma_hit_result_buffer_t* buffer,
    uint32_t max_results,
    anigma_arena_t* arena
) {
    if (buffer == nullptr || max_results == 0 || arena == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    size_t result_size = sizeof(anigma_hit_result_t) * max_results;
    buffer->results = static_cast<anigma_hit_result_t*>(
        anigma_arena_alloc(arena, result_size, alignof(anigma_hit_result_t))
    );
    
    if (buffer->results == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    buffer->capacity = max_results;
    buffer->count = 0;
    buffer->total_considered = 0;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_hit_test_destroy_buffer(anigma_hit_result_buffer_t* buffer) {
    if (buffer == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    buffer->results = nullptr;
    buffer->capacity = 0;
    buffer->count = 0;
    buffer->total_considered = 0;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_hit_test_point(
    const anigma_scene_graph_t* graph,
    anigma_point_t world_point,
    uint32_t flags,
    uint32_t max_results,
    const anigma_entity_id_t* exclude_ids,
    uint32_t exclude_count,
    anigma_hit_result_buffer_t* results,
    anigma_arena_t* arena
) {
    if (graph == nullptr || results == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    results->count = 0;
    results->total_considered = 0;
    
    for (size_t i = 0; i < graph->node_count; i++) {
        const anigma_scene_node_t* node = &graph->nodes[i];
        
        if ((flags & ANIGMA_HIT_FLAG_VISIBLE_ONLY) && !(node->flags & 0x01)) {
            continue;
        }
        
        if (!(flags & ANIGMA_HIT_FLAG_INCLUDE_LOCKED) && (node->flags & 0x02)) {
            continue;
        }
        
        if (is_excluded(node->id, exclude_ids, exclude_count)) {
            continue;
        }
        
        results->total_considered++;
        
        anigma_geometry_bounds_t bounds;
        anigma_status_t status = anigma_get_node_bounds(graph, node->id, &bounds);
        if (status != ANIGMA_STATUS_SUCCESS) {
            continue;
        }
        
        if (world_point.x >= bounds.min_x && world_point.x <= bounds.max_x &&
            world_point.y >= bounds.min_y && world_point.y <= bounds.max_y) {
            
            if (results->count < results->capacity) {
                anigma_hit_result_t* result = &results->results[results->count];
                result->entity_id = node->id;
                result->world_point = world_point;
                result->layer_index = node->layer_index;
                result->render_order = node->render_order;
                result->hit_reason = ANIGMA_HIT_BOUNDS;
                result->distance = 0;
                
                anigma_world_to_local(
                    &node->world_transform,
                    world_point,
                    &result->local_point
                );
                
                results->count++;
            }
        }
    }
    
    if (results->count > 1) {
        anigma_hit_result_sort(results->results, results->count, compare_hit_results);
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_hit_test_rect(
    const anigma_scene_graph_t* graph,
    anigma_rect_t rect,
    uint32_t flags,
    anigma_hit_result_buffer_t* results,
    anigma_arena_t* arena
) {
    if (graph == nullptr || results == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    results->count = 0;
    results->total_considered = 0;
    
    for (size_t i = 0; i < graph->node_count; i++) {
        const anigma_scene_node_t* node = &graph->nodes[i];
        
        results->total_considered++;
        
        anigma_geometry_bounds_t bounds;
        anigma_status_t status = anigma_get_node_bounds(graph, node->id, &bounds);
        if (status != ANIGMA_STATUS_SUCCESS) {
            continue;
        }
        
        int overlaps = !(bounds.max_x < rect.x || bounds.min_x > rect.x + rect.width ||
                        bounds.max_y < rect.y || bounds.min_y > rect.y + rect.height);
        
        if (overlaps && results->count < results->capacity) {
            anigma_hit_result_t* result = &results->results[results->count];
            result->entity_id = node->id;
            result->world_point.x = (rect.x + rect.width / 2);
            result->world_point.y = (rect.y + rect.height / 2);
            result->layer_index = node->layer_index;
            result->render_order = node->render_order;
            result->hit_reason = ANIGMA_HIT_BOUNDS;
            result->distance = 0;
            result->local_point = result->world_point;
            
            results->count++;
        }
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_hit_test_path(
    const anigma_point_t* path_points,
    uint32_t point_count,
    anigma_point_t test_point,
    anigma_hit_reason_t* hit_reasons,
    uint32_t* hit_count,
    anigma_arena_t* arena
) {
    if (path_points == nullptr || point_count < 3 || hit_reasons == nullptr || hit_count == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    int wn = winding_number(test_point.x, test_point.y, path_points, point_count);
    
    if (wn != 0) {
        hit_reasons[0] = ANIGMA_HIT_FILL;
        *hit_count = 1;
    } else {
        *hit_count = 0;
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_get_node_bounds(
    const anigma_scene_graph_t* graph,
    anigma_entity_id_t node_id,
    anigma_geometry_bounds_t* bounds
) {
    if (graph == nullptr || bounds == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    anigma_scene_node_t* node = anigma_scene_find_node(const_cast<anigma_scene_graph_t*>(graph), node_id);
    if (node == nullptr) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    anigma_coordinate_t cx = node->world_transform.m[0][2];
    anigma_coordinate_t cy = node->world_transform.m[1][2];
    
    bounds->min_x = cx;
    bounds->min_y = cy;
    bounds->max_x = cx;
    bounds->max_y = cy;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_world_to_local(
    const anigma_transform_t* world_transform,
    anigma_point_t world_point,
    anigma_point_t* local_point
) {
    if (world_transform == nullptr || local_point == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    int64_t wx = world_point.x;
    int64_t wy = world_point.y;
    
    int64_t dx = wx - world_transform->m[0][2];
    int64_t dy = wy - world_transform->m[1][2];
    
    if (world_transform->m[0][0] != 0) {
        local_point->x = static_cast<anigma_coordinate_t>(
            (dx * ANIGMA_COORDINATE_SCALE + world_transform->m[0][0] / 2) / world_transform->m[0][0]
        );
    } else {
        local_point->x = 0;
    }
    
    if (world_transform->m[1][1] != 0) {
        local_point->y = static_cast<anigma_coordinate_t>(
            (dy * ANIGMA_COORDINATE_SCALE + world_transform->m[1][1] / 2) / world_transform->m[1][1]
        );
    } else {
        local_point->y = 0;
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

int anigma_point_in_rect(anigma_point_t point, anigma_rect_t rect) {
    return (point.x >= rect.x && point.x <= rect.x + rect.width &&
            point.y >= rect.y && point.y <= rect.y + rect.height);
}

int anigma_point_in_polygon(
    anigma_point_t point,
    const anigma_point_t* polygon,
    uint32_t point_count,
    int fill_rule_even_odd
) {
    int wn = winding_number(point.x, point.y, polygon, point_count);
    
    if (fill_rule_even_odd) {
        return (wn % 2) != 0;
    }
    return wn != 0;
}

void anigma_hit_result_sort(
    anigma_hit_result_t* results,
    uint32_t count,
    int (*compare)(const void*, const void*)
) {
    std::qsort(results, count, sizeof(anigma_hit_result_t), compare);
}
