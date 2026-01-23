#include "../../include/anigma_render_plan.h"
#include "../../include/anigma_scene_graph.h"
#include "../../include/anigma_hash.h"
#include <cstring>
#include <algorithm>
#include <new>

namespace {

constexpr uint32_t DEFAULT_OP_CAPACITY = 256;
constexpr uint32_t DEFAULT_RESOURCE_CAPACITY = 64;

int compare_entities_by_layer(const void* a, const void* b) {
    const anigma_entity_id_t* ea = static_cast<const anigma_entity_id_t*>(a);
    const anigma_entity_id_t* eb = static_cast<const anigma_entity_id_t*>(b);
    return anigma_entity_id_less(*ea, *eb) ? -1 : 1;
}

}  // namespace

anigma_status_t anigma_render_plan_builder_create(
    anigma_render_plan_builder_t* builder,
    uint32_t initial_op_capacity,
    uint32_t initial_resource_capacity,
    anigma_arena_t* arena
) {
    if (builder == nullptr || arena == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    uint32_t op_cap = (initial_op_capacity > 0) ? initial_op_capacity : DEFAULT_OP_CAPACITY;
    uint32_t res_cap = (initial_resource_capacity > 0) ? initial_resource_capacity : DEFAULT_RESOURCE_CAPACITY;
    
    size_t op_size = sizeof(anigma_draw_op_t) * op_cap;
    builder->ops = static_cast<anigma_draw_op_t*>(
        anigma_arena_alloc(arena, op_size, alignof(anigma_draw_op_t))
    );
    
    if (builder->ops == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    size_t res_size = sizeof(anigma_resource_ref_t) * res_cap;
    builder->resources = static_cast<anigma_resource_ref_t*>(
        anigma_arena_alloc(arena, res_size, alignof(anigma_resource_ref_t))
    );
    
    if (builder->resources == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    builder->op_count = 0;
    builder->op_capacity = op_cap;
    builder->resource_count = 0;
    builder->resource_capacity = res_cap;
    builder->arena = arena;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_render_plan_builder_destroy(anigma_render_plan_builder_t* builder) {
    if (builder == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    builder->ops = nullptr;
    builder->op_count = 0;
    builder->op_capacity = 0;
    builder->resources = nullptr;
    builder->resource_count = 0;
    builder->resource_capacity = 0;
    builder->arena = nullptr;
    
    return ANIGMA_STATUS_SUCCESS;
}

static anigma_status_t ensure_op_capacity(anigma_render_plan_builder_t* builder, uint32_t additional) {
    if (builder->op_count + additional <= builder->op_capacity) {
        return ANIGMA_STATUS_SUCCESS;
    }
    
    uint32_t new_capacity = builder->op_capacity * 2;
    while (new_capacity < builder->op_count + additional) {
        new_capacity *= 2;
    }
    
    size_t new_size = sizeof(anigma_draw_op_t) * new_capacity;
    anigma_draw_op_t* new_ops = static_cast<anigma_draw_op_t*>(
        anigma_arena_alloc(builder->arena, new_size, alignof(anigma_draw_op_t))
    );
    
    if (new_ops == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    std::memcpy(new_ops, builder->ops, sizeof(anigma_draw_op_t) * builder->op_count);
    builder->ops = new_ops;
    builder->op_capacity = new_capacity;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_render_plan_builder_add_clear(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    anigma_resource_ref_t background_color
) {
    if (builder == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    anigma_status_t status = ensure_op_capacity(builder, 1);
    if (status != ANIGMA_STATUS_SUCCESS) {
        return status;
    }
    
    anigma_draw_op_t* op = &builder->ops[builder->op_count++];
    op->op_index = builder->op_count - 1;
    op->type = ANIGMA_DRAW_CLEAR;
    op->layer_id = layer_id;
    op->transform = ANIGMA_TRANSFORM_IDENTITY;
    op->clip = anigma_rect_t{0, 0, 0, 0};
    op->material = background_color;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_render_plan_builder_add_rect(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    const anigma_rect_t* rect,
    const anigma_transform_t* transform,
    const anigma_resource_ref_t* material
) {
    if (builder == nullptr || rect == nullptr || transform == nullptr || material == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    anigma_status_t status = ensure_op_capacity(builder, 1);
    if (status != ANIGMA_STATUS_SUCCESS) {
        return status;
    }
    
    anigma_draw_op_t* op = &builder->ops[builder->op_count++];
    op->op_index = builder->op_count - 1;
    op->type = ANIGMA_DRAW_RECT;
    op->layer_id = layer_id;
    op->transform = *transform;
    op->clip = *rect;
    op->material = *material;
    op->rect.rect = *rect;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_render_plan_builder_add_path(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    uint64_t path_id,
    const anigma_transform_t* transform,
    const anigma_resource_ref_t* fill_material,
    const anigma_resource_ref_t* stroke_material,
    anigma_coordinate_t stroke_width
) {
    if (builder == nullptr || transform == nullptr || fill_material == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    anigma_status_t status = ensure_op_capacity(builder, 1);
    if (status != ANIGMA_STATUS_SUCCESS) {
        return status;
    }
    
    anigma_draw_op_t* op = &builder->ops[builder->op_count++];
    op->op_index = builder->op_count - 1;
    op->type = ANIGMA_DRAW_PATH;
    op->layer_id = layer_id;
    op->transform = *transform;
    op->clip = anigma_rect_t{0, 0, 0, 0};
    op->material = *fill_material;
    op->path.path_id = path_id;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_render_plan_builder_add_text(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    uint64_t text_run_id,
    anigma_point_t position,
    const anigma_resource_ref_t* text_material
) {
    if (builder == nullptr || text_material == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    anigma_status_t status = ensure_op_capacity(builder, 1);
    if (status != ANIGMA_STATUS_SUCCESS) {
        return status;
    }
    
    anigma_draw_op_t* op = &builder->ops[builder->op_count++];
    op->op_index = builder->op_count - 1;
    op->type = ANIGMA_DRAW_TEXT;
    op->layer_id = layer_id;
    op->transform = ANIGMA_TRANSFORM_IDENTITY;
    op->clip = anigma_rect_t{0, 0, 0, 0};
    op->material = *text_material;
    op->text.text_run_id = text_run_id;
    op->text.origin = position;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_render_plan_builder_add_image(
    anigma_render_plan_builder_t* builder,
    uint32_t layer_id,
    uint64_t image_id,
    anigma_rect_t destination,
    const anigma_transform_t* transform
) {
    if (builder == nullptr || transform == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    anigma_status_t status = ensure_op_capacity(builder, 1);
    if (status != ANIGMA_STATUS_SUCCESS) {
        return status;
    }
    
    anigma_draw_op_t* op = &builder->ops[builder->op_count++];
    op->op_index = builder->op_count - 1;
    op->type = ANIGMA_DRAW_IMAGE;
    op->layer_id = layer_id;
    op->transform = *transform;
    op->clip = destination;
    op->material = anigma_resource_ref_t{0, ANIGMA_RESOURCE_IMAGE};
    op->image.image_id = image_id;
    op->image.source = destination;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_render_plan_build(
    const anigma_render_plan_builder_t* builder,
    anigma_render_plan_t** plan
) {
    if (builder == nullptr || plan == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    size_t plan_size = sizeof(anigma_render_plan_t) + sizeof(anigma_draw_op_t) * builder->op_count;
    anigma_render_plan_t* p = static_cast<anigma_render_plan_t*>(
        anigma_arena_alloc(builder->arena, plan_size, alignof(anigma_render_plan_t))
    );
    
    if (p == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    p->op_count = builder->op_count;
    p->resource_count = builder->resource_count;
    std::memcpy(p->ops, builder->ops, sizeof(anigma_draw_op_t) * builder->op_count);
    std::memset(p->plan_hash, 0, ANIGMA_HASH_SIZE);
    
    anigma_render_plan_compute_hash(p);
    
    *plan = p;
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_render_plan_compute_hash(anigma_render_plan_t* plan) {
    if (plan == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    uint8_t hash_input[sizeof(anigma_render_plan_t) - ANIGMA_HASH_SIZE + sizeof(anigma_draw_op_t) * 100];
    size_t offset = 0;
    
    std::memcpy(hash_input + offset, &plan->op_count, sizeof(uint32_t));
    offset += sizeof(uint32_t);
    
    std::memcpy(hash_input + offset, &plan->resource_count, sizeof(uint32_t));
    offset += sizeof(uint32_t);
    
    for (uint32_t i = 0; i < plan->op_count && offset + sizeof(anigma_draw_op_t) < sizeof(hash_input); i++) {
        std::memcpy(hash_input + offset, &plan->ops[i], sizeof(anigma_draw_op_t));
        offset += sizeof(anigma_draw_op_t);
    }
    
    anigma_hash(hash_input, offset, plan->plan_hash);
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_generate_render_plan(
    const anigma_scene_graph_t* graph,
    const anigma_render_plan_request_t* request,
    anigma_render_plan_t** plan,
    anigma_arena_t* arena
) {
    if (graph == nullptr || request == nullptr || plan == nullptr || arena == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    anigma_render_plan_builder_t builder;
    anigma_status_t status = anigma_render_plan_builder_create(
        &builder, graph->node_count * 2, 32, arena
    );
    
    if (status != ANIGMA_STATUS_SUCCESS) {
        return status;
    }
    
    anigma_resource_ref_t background = {0, ANIGMA_RESOURCE_COLOR};
    status = anigma_render_plan_builder_add_clear(&builder, 0, background);
    if (status != ANIGMA_STATUS_SUCCESS) {
        return status;
    }
    
    anigma_entity_id_t* sorted = static_cast<anigma_entity_id_t*>(
        anigma_arena_alloc(arena, sizeof(anigma_entity_id_t) * graph->node_count, alignof(anigma_entity_id_t))
    );
    
    uint32_t sorted_count = 0;
    for (size_t i = 0; i < graph->node_count; i++) {
        if (!(request->flags & ANIGMA_RENDER_FLAG_VISIBLE_ONLY) || (graph->nodes[i].flags & 0x01)) {
            sorted[sorted_count++] = graph->nodes[i].id;
        }
    }
    
    std::sort(sorted, sorted + sorted_count, compare_entities_by_layer);
    
    for (uint32_t i = 0; i < sorted_count; i++) {
        anigma_scene_node_t* node = anigma_scene_find_node(
            const_cast<anigma_scene_graph_t*>(graph), sorted[i]
        );
        
        if (node == nullptr) {
            continue;
        }
        
        anigma_rect_t bounds = {
            node->world_transform.m[0][2],
            node->world_transform.m[1][2],
            node->world_transform.m[0][0],
            node->world_transform.m[1][1]
        };
        
        anigma_resource_ref_t material = {0, ANIGMA_RESOURCE_COLOR};
        status = anigma_render_plan_builder_add_rect(
            &builder, node->layer_id, &bounds, &node->world_transform, &material
        );
        
        if (status != ANIGMA_STATUS_SUCCESS) {
            return status;
        }
    }
    
    status = anigma_render_plan_build(&builder, plan);
    anigma_render_plan_builder_destroy(&builder);
    
    return status;
}

anigma_status_t anigma_cull_invisible(
    const anigma_scene_graph_t* graph,
    const anigma_rect_t* viewport,
    anigma_entity_id_t* visible_entities,
    uint32_t* visible_count,
    uint32_t max_visible,
    anigma_arena_t* arena
) {
    if (graph == nullptr || viewport == nullptr || visible_entities == nullptr || visible_count == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    *visible_count = 0;
    
    for (size_t i = 0; i < graph->node_count && *visible_count < max_visible; i++) {
        const anigma_scene_node_t* node = &graph->nodes[i];
        
        anigma_coordinate_t wx = node->world_transform.m[0][2];
        anigma_coordinate_t wy = node->world_transform.m[1][2];
        anigma_coordinate_t ww = node->world_transform.m[0][0];
        anigma_coordinate_t wh = node->world_transform.m[1][1];
        
        int overlaps = !(wx + ww < viewport->x || wx > viewport->x + viewport->width ||
                        wy + wh < viewport->y || wy > viewport->y + viewport->height);
        
        if (overlaps && (node->flags & 0x01)) {
            visible_entities[(*visible_count)++] = node->id;
        }
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_sort_by_layer(
    const anigma_scene_graph_t* graph,
    anigma_entity_id_t* sorted_entities,
    uint32_t* sorted_count,
    uint32_t max_count,
    anigma_arena_t* arena
) {
    if (graph == nullptr || sorted_entities == nullptr || sorted_count == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    *sorted_count = 0;
    
    for (size_t i = 0; i < graph->node_count && *sorted_count < max_count; i++) {
        sorted_entities[(*sorted_count)++] = graph->nodes[i].id;
    }
    
    std::sort(sorted_entities, sorted_entities + *sorted_count, compare_entities_by_layer);
    
    return ANIGMA_STATUS_SUCCESS;
}
