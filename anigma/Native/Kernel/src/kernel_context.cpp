#include "../include/kernel_context.hpp"
#include <cstdlib>
#include <cstring>
#include <algorithm>
#include <vector>

namespace anigma {

static anigma_affine_i32_t multiply(const anigma_affine_i32_t& a, const anigma_affine_i32_t& b) {
    anigma_affine_i32_t c;
    auto mul = [](int32_t x, int32_t y) -> int32_t {
        return static_cast<int32_t>((static_cast<int64_t>(x) * y) / 256);
    };

    c.m[0] = mul(a.m[0], b.m[0]) + mul(a.m[2], b.m[1]);
    c.m[1] = mul(a.m[1], b.m[0]) + mul(a.m[3], b.m[1]);
    c.m[2] = mul(a.m[0], b.m[2]) + mul(a.m[2], b.m[3]);
    c.m[3] = mul(a.m[1], b.m[2]) + mul(a.m[3], b.m[3]);
    c.m[4] = mul(a.m[0], b.m[4]) + mul(a.m[2], b.m[5]) + a.m[4];
    c.m[5] = mul(a.m[1], b.m[4]) + mul(a.m[3], b.m[5]) + a.m[5];
    
    return c;
}

KernelContext::KernelContext() = default;
KernelContext::~KernelContext() = default;

anigma_status_t KernelContext::apply_diff_batch(anigma_blob_t batch) {
    if (!batch.ptr || batch.size < sizeof(anigma_diff_batch_t)) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    const auto* batch_header = reinterpret_cast<const anigma_diff_batch_t*>(batch.ptr);
    if (batch_header->schema_version != 1) {
        return ANIGMA_STATUS_VERSION_MISMATCH;
    }

    const uint8_t* cursor = reinterpret_cast<const uint8_t*>(batch_header->diffs);
    const uint8_t* end = batch.ptr + batch.size;

    for (uint32_t i = 0; i < batch_header->diff_count; ++i) {
        if (cursor + sizeof(anigma_diff_header_t) > end) {
            return ANIGMA_ERR_CORRUPT_DATA;
        }

        const auto* diff_header = reinterpret_cast<const anigma_diff_header_t*>(cursor);
        cursor += sizeof(anigma_diff_header_t);

        if (cursor + diff_header->payload_size > end) {
            return ANIGMA_ERR_CORRUPT_DATA;
        }

        switch (diff_header->op) {
            case ANIGMA_DIFF_ATTACH: {
                const auto* attach = reinterpret_cast<const anigma_diff_attach_t*>(cursor);
                auto node = std::make_unique<SceneNode>();
                node->id = attach->entity_id;
                node->parent_id.high = 0;
                node->parent_id.low = 0;
                node->local_transform.m[0] = 256;
                node->local_transform.m[1] = 0;
                node->local_transform.m[2] = 0;
                node->local_transform.m[3] = 256;
                node->local_transform.m[4] = 0;
                node->local_transform.m[5] = 0;
                node->world_transform = node->local_transform;
                node->type = ANIGMA_DRAW_RECT;
                node->layer_id = 0;
                node->paint_index = 0;
                node->resource_index = 0;
                node->transform_dirty = true;
                
                nodes[node->id] = std::move(node);
                break;
            }
            case ANIGMA_DIFF_TRANSFORM: {
                const auto* xform = reinterpret_cast<const anigma_diff_transform_t*>(cursor);
                auto it = nodes.find(xform->entity_id);
                if (it != nodes.end()) {
                    it->second->local_transform.m[0] = xform->transform.m[0][0];
                    it->second->local_transform.m[1] = xform->transform.m[1][0];
                    it->second->local_transform.m[2] = xform->transform.m[0][1];
                    it->second->local_transform.m[3] = xform->transform.m[1][1];
                    it->second->local_transform.m[4] = xform->transform.m[0][2];
                    it->second->local_transform.m[5] = xform->transform.m[1][2];
                    it->second->transform_dirty = true;
                }
                break;
            }
            case ANIGMA_DIFF_DETACH: {
                const auto* entity_id = reinterpret_cast<const anigma_entity_id_t*>(cursor);
                nodes.erase(*entity_id);
                break;
            }
            default:
                break;
        }

        cursor += diff_header->payload_size;
    }

    return ANIGMA_OK;
}

anigma_status_t KernelContext::hit_test(anigma_blob_t query, anigma_mut_blob_t* out_hits) {
    if (!query.ptr || query.size < sizeof(anigma_hit_query_t)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    const auto* q = reinterpret_cast<const anigma_hit_query_t*>(query.ptr);
    std::vector<anigma_hit_result_t> results;
    
    for (auto const& pair : nodes) {
        const auto& node = pair.second;
        int32_t x = node->world_transform.m[4];
        int32_t y = node->world_transform.m[5];
        int32_t w = 100 * 256;
        int32_t h = 100 * 256;
        
        if (q->point.x >= x && q->point.x <= x + w && q->point.y >= y && q->point.y <= y + h) {
            anigma_hit_result_t hit;
            hit.entity_id = node->id;
            hit.local_point.x = q->point.x - x;
            hit.local_point.y = q->point.y - y;
            hit.hit_reason = 1;
            hit.layer_index = node->layer_id;
            hit.render_order = 0;
            results.push_back(hit);
            if (results.size() >= q->max_results) break;
        }
    }
    
    if (out_hits) {
        if (results.empty()) {
            out_hits->ptr = nullptr;
            out_hits->size = 0;
        } else {
            size_t size = sizeof(anigma_hit_response_t) + results.size() * sizeof(anigma_hit_result_t);
            out_hits->ptr = (uint8_t*)malloc(size);
            if (!out_hits->ptr) return ANIGMA_ERR_INTERNAL;
            out_hits->size = size;
            
            auto* resp = reinterpret_cast<anigma_hit_response_t*>(out_hits->ptr);
            resp->result_count = static_cast<uint32_t>(results.size());
            resp->total_considered = static_cast<uint32_t>(nodes.size());
            memcpy(resp->results, results.data(), results.size() * sizeof(anigma_hit_result_t));
        }
    }
    
    return ANIGMA_OK;
}

anigma_status_t KernelContext::step_fixed(uint32_t ticks) {
    (void)ticks;
    return ANIGMA_OK;
}

anigma_status_t KernelContext::generate_render_plan(anigma_blob_t viewport_request, anigma_mut_blob_t* out_plan) {
    if (out_plan == nullptr) return ANIGMA_ERR_INVALID_ARG;
    (void)viewport_request;

    update_transforms();

    anigma_plan_header_t header;
    memset(&header, 0, sizeof(header));
    header.magic = ANIGMA_PLAN_MAGIC;
    header.version = ANIGMA_PLAN_VERSION;
    header.coord_scale = coord_scale;
    header.tick_hz = tick_hz;

    std::vector<anigma_draw_op_t> ops;
    std::vector<anigma_affine_i32_t> transforms;
    
    for (auto const& pair : nodes) {
        const auto& node = pair.second;
        anigma_draw_op_t op;
        memset(&op, 0, sizeof(op));
        op.type = node->type;
        op.layer_id = node->layer_id;
        op.paint_index = node->paint_index;
        op.resource_index = node->resource_index;
        
        op.transform_index = static_cast<uint32_t>(transforms.size());
        transforms.push_back(node->world_transform);
        
        op.sort_key = (static_cast<uint64_t>(node->layer_id) << 32) | static_cast<uint32_t>(node->id.low);
        
        ops.push_back(op);
    }

    std::sort(ops.begin(), ops.end(), [](const anigma_draw_op_t& a, const anigma_draw_op_t& b) {
        return a.sort_key < b.sort_key;
    });

    header.op_count = static_cast<uint32_t>(ops.size());
    header.transform_count = static_cast<uint32_t>(transforms.size());
    header.paint_count = static_cast<uint32_t>(paints.size());
    header.resource_count = static_cast<uint32_t>(resources.size());

    header.ops_offset = sizeof(anigma_plan_header_t);
    header.transforms_offset = header.ops_offset + static_cast<uint32_t>(ops.size() * sizeof(anigma_draw_op_t));
    header.paints_offset = header.transforms_offset + static_cast<uint32_t>(transforms.size() * sizeof(anigma_affine_i32_t));
    header.resources_offset = header.paints_offset + static_cast<uint32_t>(paints.size() * sizeof(anigma_paint_t));
    header.payload_offset = header.resources_offset + static_cast<uint32_t>(resources.size() * sizeof(anigma_resource_ref_t));
    header.payload_size = 0;

    size_t total_size = header.payload_offset + header.payload_size;
    auto* buffer = static_cast<uint8_t*>(malloc(total_size));
    if (buffer == nullptr) return ANIGMA_ERR_INTERNAL;

    memcpy(buffer, &header, sizeof(header));
    if (!ops.empty()) memcpy(buffer + header.ops_offset, ops.data(), ops.size() * sizeof(anigma_draw_op_t));
    if (!transforms.empty()) memcpy(buffer + header.transforms_offset, transforms.data(), transforms.size() * sizeof(anigma_affine_i32_t));
    if (!paints.empty()) memcpy(buffer + header.paints_offset, paints.data(), paints.size() * sizeof(anigma_paint_t));
    if (!resources.empty()) memcpy(buffer + header.resources_offset, resources.data(), resources.size() * sizeof(anigma_resource_ref_t));

    out_plan->ptr = buffer;
    out_plan->size = total_size;

    return ANIGMA_OK;
}

void KernelContext::update_transforms() {
    anigma_affine_i32_t identity = {{256, 0, 0, 256, 0, 0}};
    for (auto& pair : nodes) {
        auto& node = pair.second;
        if (node->parent_id.high == 0 && node->parent_id.low == 0) {
            update_node_recursive(node.get(), identity);
        }
    }
}

void KernelContext::update_node_recursive(SceneNode* node, const anigma_affine_i32_t& parent_world) {
    node->world_transform = multiply(parent_world, node->local_transform);
    node->transform_dirty = false;
    
    for (auto& pair : nodes) {
        auto& child = pair.second;
        if (child->parent_id.high == node->id.high && child->parent_id.low == node->id.low) {
            update_node_recursive(child.get(), node->world_transform);
        }
    }
}

uint32_t KernelContext::add_paint(const anigma_paint_t& paint) {
    uint32_t index = static_cast<uint32_t>(paints.size());
    paints.push_back(paint);
    return index;
}

uint32_t KernelContext::add_resource(const anigma_resource_ref_t& res) {
    uint32_t index = static_cast<uint32_t>(resources.size());
    resources.push_back(res);
    return index;
}

} // namespace anigma

extern "C" {

anigma_status_t anigma_kernel_initialize(anigma_ctx_t ctx, anigma_blob_t config, anigma_kernel_instance_t* out_instance) {
    (void)ctx; (void)config;
    if (out_instance == nullptr) return ANIGMA_ERR_INVALID_ARG;
    *out_instance = reinterpret_cast<anigma_kernel_instance_t>(new anigma_kernel_t());
    return ANIGMA_OK;
}

void anigma_kernel_shutdown(anigma_kernel_instance_t instance) {
    if (instance) delete reinterpret_cast<anigma_kernel_t*>(instance);
}

void anigma_kernel_free_blob(anigma_mut_blob_t blob) {
    if (blob.ptr) free(blob.ptr);
}

anigma_status_t anigma_kernel_apply_diff_batch(anigma_kernel_instance_t instance, anigma_ctx_t ctx, anigma_blob_t diff_batch, anigma_mut_blob_t* out_receipt) {
    (void)ctx;
    if (instance == nullptr) return ANIGMA_ERR_INVALID_ARG;
    if (out_receipt) {
        out_receipt->ptr = nullptr;
        out_receipt->size = 0;
    }
    return reinterpret_cast<anigma_kernel_t*>(instance)->ctx.apply_diff_batch(diff_batch);
}

anigma_status_t anigma_kernel_step_fixed(anigma_kernel_instance_t instance, anigma_ctx_t ctx, anigma_time_tick_t delta_ticks, anigma_mut_blob_t* out_receipt) {
    (void)ctx;
    if (instance == nullptr) return ANIGMA_ERR_INVALID_ARG;
    if (out_receipt) {
        out_receipt->ptr = nullptr;
        out_receipt->size = 0;
    }
    return reinterpret_cast<anigma_kernel_t*>(instance)->ctx.step_fixed(static_cast<uint32_t>(delta_ticks));
}

anigma_status_t anigma_kernel_render_plan(anigma_kernel_instance_t instance, anigma_ctx_t ctx, anigma_blob_t viewport_request, anigma_mut_blob_t* out_plan) {
    (void)ctx;
    if (instance == nullptr) return ANIGMA_ERR_INVALID_ARG;
    return reinterpret_cast<anigma_kernel_t*>(instance)->ctx.generate_render_plan(viewport_request, out_plan);
}

anigma_status_t anigma_kernel_hit_test(anigma_kernel_instance_t instance, anigma_ctx_t ctx, anigma_blob_t hit_query, anigma_mut_blob_t* out_hits) {
    (void)ctx;
    if (instance == nullptr) return ANIGMA_ERR_INVALID_ARG;
    return reinterpret_cast<anigma_kernel_t*>(instance)->ctx.hit_test(hit_query, out_hits);
}

anigma_status_t anigma_kernel_snapshot_export(anigma_kernel_instance_t instance, anigma_ctx_t ctx, anigma_mut_blob_t* out_snapshot) {
    (void)instance; (void)ctx;
    if (out_snapshot) {
        out_snapshot->ptr = nullptr;
        out_snapshot->size = 0;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_snapshot_import(anigma_kernel_instance_t instance, anigma_ctx_t ctx, anigma_blob_t snapshot) {
    (void)instance; (void)ctx; (void)snapshot;
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_state_hash(anigma_kernel_instance_t instance, uint8_t out_hash32[32]) {
    (void)instance;
    if (out_hash32 == nullptr) return ANIGMA_ERR_INVALID_ARG;
    memset(out_hash32, 0, 32);
    return ANIGMA_OK;
}

}
