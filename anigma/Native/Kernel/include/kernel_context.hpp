#pragma once
#include "anigma_render_plan.h"
#include "anigma_kernel_abi.h"
#include "anigma_evidence_ring.h"
#include "blake3.h"
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
    enum class InitError {
        noLoggingRing = 1,
        invalidMetadata = 2,
        invalidPackets = 3,
        mmapFailed = 4
    };
    
    static std::optional<InitError> validate_ring(anigma_evidence_ring_t* ring);
    
    KernelContext(anigma_evidence_ring_t* logging_ring);
    ~KernelContext();

    anigma_status_t apply_diff_batch(anigma_blob_t batch);
    anigma_status_t step_fixed(uint32_t ticks);
    anigma_status_t generate_render_plan(anigma_blob_t viewport_request, anigma_mut_blob_t* out_plan);
    anigma_status_t hit_test(anigma_blob_t query, anigma_mut_blob_t* out_hits);

    uint32_t add_paint(const anigma_paint_t& paint);
    uint32_t add_resource(const anigma_resource_ref_t& res);

    bool is_valid() const { return logging_ring.metadata != nullptr && logging_ring.packets != nullptr; }
    
    // Check if ring memory is still mapped (zero-copy residency)
    bool is_resident() const;
    
    // Get BLAKE3 hash of current ring state for ContractReceipt
    void ring_hash(uint8_t out_hash[32]) const;

private:
    void update_transforms();
    void update_node_recursive(SceneNode* node, const anigma_affine_i32_t& parent_world);
    void emit_heartbeat(uint32_t packet_type, const uint8_t* payload, size_t payload_size);
    
    anigma_evidence_ring_t logging_ring;
    uint8_t mission_id[16];
    uint32_t sequence_counter = 0;

    std::map<anigma_entity_id_t, std::unique_ptr<SceneNode>, EntityIdCompare> nodes;
    std::vector<anigma_paint_t> paints;
    std::vector<anigma_resource_ref_t> resources;
    
    uint32_t coord_scale = 256;
    uint32_t tick_hz = 120;
};

} // namespace anigma

struct anigma_kernel_t {
    anigma::KernelContext ctx;

    anigma_kernel_t(anigma_evidence_ring_t* ring) : ctx(ring) {}
};
