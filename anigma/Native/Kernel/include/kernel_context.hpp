#pragma once
#include "../../Shims/include/anigma_render_plan.h"
#include "../../Shims/include/anigma_kernel_abi.h"
#include <vector>
#include <map>
#include <memory>

namespace anigma {

struct SceneNode {
    anigma_entity_id_t id;
    anigma_entity_id_t parent_id;
    anigma_affine_i32_t local_transform;
    anigma_affine_i32_t world_transform;
    anigma_draw_op_type_t type;
    uint32_t layer_id;
    uint32_t paint_index;
    uint32_t resource_index;
    bool transform_dirty = true;
};

struct EntityIdCompare {
    bool operator()(const anigma_entity_id_t& a, const anigma_entity_id_t& b) const {
        return a.high < b.high || (a.high == b.high && a.low < b.low);
    }
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
    void update_node_recursive(SceneNode* node, const anigma_affine_i32_t& parent_world);
    
    std::map<anigma_entity_id_t, std::unique_ptr<SceneNode>, EntityIdCompare> nodes;
    std::vector<anigma_paint_t> paints;
    std::vector<anigma_resource_ref_t> resources;
    
    uint32_t coord_scale = 256;
    uint32_t tick_hz = 120;
};

} // namespace anigma

struct anigma_kernel_t {
    anigma::KernelContext ctx;
};
