#pragma once
#include "../../Shims/include/anigma_render_plan.h"
#include "../../Shims/include/anigma_kernel_abi.h"
#include <vector>
#include <map>
#include <memory>

namespace anigma {

struct SceneNode {
    uint64_t id;
    uint64_t parent_id;
    anigma_affine_i32_t local_transform;
    anigma_affine_i32_t world_transform;
    anigma_draw_op_type_t type;
    uint32_t layer_id;
    uint32_t paint_index;
    uint32_t resource_index;
    bool transform_dirty = true;
};

class KernelContext {
public:
    KernelContext();
    ~KernelContext();

    anigma_status_t apply_diff_batch(anigma_blob_t batch);
    anigma_status_t step_fixed(uint32_t ticks);
    anigma_status_t generate_render_plan(anigma_blob_t viewport_request, anigma_mut_blob_t* out_plan);
    anigma_status_t hit_test(anigma_blob_t query, anigma_mut_blob_t* out_hits);

    uint32_t add_paint(const anigma_paint_t& paint);
    uint32_t add_resource(const anigma_resource_ref_t& res);

private:
    void update_transforms();
    
    std::map<uint64_t, std::unique_ptr<SceneNode>> nodes;
    std::vector<anigma_paint_t> paints;
    std::vector<anigma_resource_ref_t> resources;
    
    uint32_t coord_scale = 1024;
    uint32_t tick_hz = 120;
};

} // namespace anigma

struct anigma_kernel_t {
    anigma::KernelContext ctx;
};
