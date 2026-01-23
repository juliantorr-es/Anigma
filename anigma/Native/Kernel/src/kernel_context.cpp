#include "../include/kernel_context.hpp"
#include <cstdlib>
#include <cstring>
#include <algorithm>

namespace anigma {

KernelContext::KernelContext() = default;
KernelContext::~KernelContext() = default;

anigma_status_t KernelContext::apply_diff_batch(anigma_blob_t batch) {
    (void)batch;
    return ANIGMA_OK;
}

anigma_status_t KernelContext::step_fixed(uint32_t ticks) {
    (void)ticks;
    return ANIGMA_OK;
}

anigma_status_t KernelContext::generate_render_plan(anigma_blob_t viewport_request, anigma_mut_blob_t* out_plan) {
    if (out_plan == nullptr) return ANIGMA_ERR_INVALID;
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
        uint64_t id = pair.first;
        const auto& node = pair.second;
        
        anigma_draw_op_t op;
        memset(&op, 0, sizeof(op));
        op.type = node->type;
        op.layer_id = node->layer_id;
        op.paint_index = node->paint_index;
        op.resource_index = node->resource_index;
        
        op.transform_index = static_cast<uint32_t>(transforms.size());
        transforms.push_back(node->world_transform);
        
        op.sort_key = (static_cast<uint64_t>(node->layer_id) << 32) | static_cast<uint32_t>(id);
        
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
    out_plan->len = total_size;

    return ANIGMA_OK;
}

void KernelContext::update_transforms() {
    for (auto& pair : nodes) {
        auto& node = pair.second;
        if (node->transform_dirty) {
            node->world_transform = node->local_transform;
            node->transform_dirty = false;
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

anigma_status_t KernelContext::hit_test(anigma_blob_t query, anigma_mut_blob_t* out_hits) {
    (void)query;
    if (out_hits) {
        out_hits->ptr = nullptr;
        out_hits->len = 0;
    }
    return ANIGMA_OK;
}

} // namespace anigma

extern "C" {

anigma_status_t anigma_kernel_create(anigma_blob_t config, anigma_kernel_t** out_kernel) {
    (void)config;
    if (out_kernel == nullptr) return ANIGMA_ERR_INVALID;
    *out_kernel = new anigma_kernel_t();
    return ANIGMA_OK;
}

void anigma_kernel_destroy(anigma_kernel_t* kernel) {
    delete kernel;
}

void anigma_kernel_free_blob(anigma_mut_blob_t blob) {
    if (blob.ptr) free(blob.ptr);
}

anigma_status_t anigma_kernel_apply_diff_batch(anigma_kernel_t* kernel, anigma_blob_t diff_batch, anigma_mut_blob_t* out_receipt) {
    if (kernel == nullptr) return ANIGMA_ERR_INVALID;
    if (out_receipt) {
        out_receipt->ptr = nullptr;
        out_receipt->len = 0;
    }
    return kernel->ctx.apply_diff_batch(diff_batch);
}

anigma_status_t anigma_kernel_step_fixed(anigma_kernel_t* kernel, uint32_t ticks, anigma_mut_blob_t* out_receipt) {
    if (kernel == nullptr) return ANIGMA_ERR_INVALID;
    if (out_receipt) {
        out_receipt->ptr = nullptr;
        out_receipt->len = 0;
    }
    return kernel->ctx.step_fixed(ticks);
}

anigma_status_t anigma_kernel_render_plan(anigma_kernel_t* kernel, anigma_blob_t viewport_request, anigma_mut_blob_t* out_plan) {
    if (kernel == nullptr) return ANIGMA_ERR_INVALID;
    return kernel->ctx.generate_render_plan(viewport_request, out_plan);
}

anigma_status_t anigma_kernel_hit_test(anigma_kernel_t* kernel, anigma_blob_t hit_query, anigma_mut_blob_t* out_hits) {
    if (kernel == nullptr) return ANIGMA_ERR_INVALID;
    return kernel->ctx.hit_test(hit_query, out_hits);
}

anigma_status_t anigma_kernel_snapshot_export(anigma_kernel_t* kernel, anigma_mut_blob_t* out_snapshot) {
    (void)kernel;
    if (out_snapshot) {
        out_snapshot->ptr = nullptr;
        out_snapshot->len = 0;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_snapshot_import(anigma_kernel_t* kernel, anigma_blob_t snapshot) {
    (void)kernel; (void)snapshot;
    return ANIGMA_OK;
}

anigma_status_t anigma_kernel_state_hash(anigma_kernel_t* kernel, uint8_t out_hash32[32]) {
    (void)kernel;
    if (out_hash32 == nullptr) return ANIGMA_ERR_INVALID;
    memset(out_hash32, 0, 32);
    return ANIGMA_OK;
}

}
