#include "../../include/anigma_kernel_types.h"
#include "../../include/anigma_hash.h"
#include <cstring>
#include <algorithm>
#include <new>

namespace anigma {
namespace kernel {

struct KernelInstance {
    uint64_t instance_id;
    uint64_t build_id;
    anigma_determinism_profile_t profile;
    uint64_t config_hash;
    uint32_t state_version;
    bool initialized;
    
    KernelInstance() 
        : instance_id(0), build_id(0), config_hash(0), state_version(0), 
          initialized(false) {}
};

static KernelInstance* g_instance = nullptr;
static const uint64_t BUILD_ID = 0x414E49474D415245ULL;  // "ANIGMARE"

static anigma_status_t verify_profile(const anigma_determinism_profile_t* profile) {
    if (profile->profile_id != ANIGMA_PROFILE_DEFAULT.profile_id) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    if (profile->tick_resolution != ANIGMA_TICKS_PER_SECOND) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    if (profile->coordinate_scale != ANIGMA_COORDINATE_SCALE) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    return ANIGMA_STATUS_SUCCESS;
}

}  // namespace kernel
}  // namespace anigma

using namespace anigma::kernel;

anigma_status_t anigma_initialize(
    const anigma_initialize_request_t* request,
    anigma_initialize_response_t* response,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
) {
    if (g_instance != nullptr && g_instance->initialized) {
        return ANIGMA_STATUS_ALREADY_EXISTS;
    }
    
    anigma_status_t status = verify_profile(&request->profile);
    if (status != ANIGMA_STATUS_SUCCESS) {
        return status;
    }
    
    if (request->initial_entity_capacity == 0 || arena == nullptr || arena->base == nullptr) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    g_instance = new (std::nothrow) KernelInstance();
    if (g_instance == nullptr) {
        return ANIGMA_STATUS_INTERNAL_ERROR;
    }
    
    g_instance->instance_id = reinterpret_cast<uint64_t>(g_instance);
    g_instance->build_id = BUILD_ID;
    g_instance->profile = request->profile;
    g_instance->config_hash = request->config_hash;
    g_instance->state_version = 1;
    g_instance->initialized = true;
    
    response->instance_id = g_instance->instance_id;
    response->kernel_build_id = g_instance->build_id;
    response->active_profile = g_instance->profile;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_get_info(anigma_info_response_t* response) {
    response->major_version = ANIGMA_KERNEL_VERSION_MAJOR;
    response->minor_version = ANIGMA_KERNEL_VERSION_MINOR;
    response->patch_version = ANIGMA_KERNEL_VERSION_PATCH;
    response->build_id = BUILD_ID;
    response->abi_version = ANIGMA_KERNEL_ABI_VERSION;
    response->build_date = __DATE__;
    response->build_commit = "dev";
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_shutdown(void) {
    if (g_instance == nullptr || !g_instance->initialized) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    delete g_instance;
    g_instance = nullptr;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_diff_apply(
    anigma_diff_batch_t* batch,
    anigma_buffer_t* output_state,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
) {
    if (g_instance == nullptr || !g_instance->initialized) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    if (batch == nullptr || batch->diff_count == 0) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    g_instance->state_version++;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_simulation_step(
    const anigma_simulation_step_request_t* request,
    anigma_simulation_step_response_t* response,
    anigma_buffer_t* error_info
) {
    if (g_instance == nullptr || !g_instance->initialized) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    if (request->delta_ticks <= 0) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    response->accumulated_time += request->delta_ticks;
    response->steps_taken = 1;
    
    uint8_t hash_input[64];
    std::memcpy(hash_input, &g_instance->state_version, sizeof(uint32_t));
    std::memcpy(hash_input + 32, &response->accumulated_time, sizeof(anigma_time_tick_t));
    
    anigma_hash(hash_input, sizeof(hash_input), response->state_hash);
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_hit_test(
    const anigma_hit_query_t* query,
    anigma_hit_response_t* response,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
) {
    if (g_instance == nullptr || !g_instance->initialized) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    response->result_count = 0;
    response->total_considered = 0;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_render_plan_generate(
    const anigma_render_plan_request_t* request,
    anigma_render_plan_t** plan,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
) {
    if (g_instance == nullptr || !g_instance->initialized) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    size_t plan_size = sizeof(anigma_render_plan_t);
    anigma_render_plan_t* p = reinterpret_cast<anigma_render_plan_t*>(
        anigma_arena_alloc(arena, plan_size, alignof(anigma_render_plan_t))
    );
    
    if (p == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    p->op_count = 0;
    p->resource_count = 0;
    std::memset(p->plan_hash, 0, ANIGMA_HASH_SIZE);
    
    *plan = p;
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_snapshot_export(
    anigma_snapshot_t** snapshot,
    size_t* snapshot_size,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
) {
    if (g_instance == nullptr || !g_instance->initialized) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    size_t header_size = sizeof(anigma_snapshot_header_t);
    anigma_snapshot_header_t* header = reinterpret_cast<anigma_snapshot_header_t*>(
        anigma_arena_alloc(arena, header_size, alignof(anigma_snapshot_header_t))
    );
    
    if (header == nullptr) {
        return ANIGMA_STATUS_BUFFER_TOO_SMALL;
    }
    
    header->schema_version = ANIGMA_KERNEL_VERSION_MAJOR;
    header->kernel_build_id = g_instance->build_id;
    header->config_hash = g_instance->config_hash;
    header->entity_count = 0;
    header->state_size = 0;
    std::memset(header->header_hash, 0, ANIGMA_HASH_SIZE);
    
    *snapshot = reinterpret_cast<anigma_snapshot_t*>(header);
    *snapshot_size = header_size;
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_snapshot_import(
    const anigma_snapshot_t* snapshot,
    size_t snapshot_size,
    anigma_buffer_t* error_info
) {
    if (g_instance == nullptr || !g_instance->initialized) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    if (snapshot_size < sizeof(anigma_snapshot_header_t)) {
        return ANIGMA_STATUS_INVALID_INPUT;
    }
    
    const anigma_snapshot_header_t* header = &snapshot->header;
    if (header->schema_version != ANIGMA_KERNEL_VERSION_MAJOR) {
        return ANIGMA_STATUS_VERSION_MISMATCH;
    }
    if (header->kernel_build_id != g_instance->build_id) {
        return ANIGMA_STATUS_VERSION_MISMATCH;
    }
    
    return ANIGMA_STATUS_SUCCESS;
}

anigma_status_t anigma_state_hash(
    const anigma_state_hash_request_t* request,
    anigma_state_hash_response_t* response,
    anigma_buffer_t* error_info
) {
    if (g_instance == nullptr || !g_instance->initialized) {
        return ANIGMA_STATUS_NOT_FOUND;
    }
    
    uint8_t hash_input[32];
    std::memcpy(hash_input, &g_instance->state_version, sizeof(uint32_t));
    std::memcpy(hash_input + 16, &g_instance->config_hash, sizeof(uint64_t));
    
    anigma_hash(hash_input, sizeof(hash_input), response->hash);
    response->entity_count = 0;
    response->component_count = 0;
    
    return ANIGMA_STATUS_SUCCESS;
}

const char* anigma_status_to_string(anigma_status_t status) {
    switch (status) {
        case ANIGMA_STATUS_SUCCESS: return "SUCCESS";
        case ANIGMA_STATUS_INVALID_INPUT: return "INVALID_INPUT";
        case ANIGMA_STATUS_INVALID_SCHEMA: return "INVALID_SCHEMA";
        case ANIGMA_STATUS_VERSION_MISMATCH: return "VERSION_MISMATCH";
        case ANIGMA_STATUS_OUT_OF_BOUNDS: return "OUT_OF_BOUNDS";
        case ANIGMA_STATUS_ALREADY_EXISTS: return "ALREADY_EXISTS";
        case ANIGMA_STATUS_NOT_FOUND: return "NOT_FOUND";
        case ANIGMA_STATUS_DETERMINISM_VIOLATION: return "DETERMINISM_VIOLATION";
        case ANIGMA_STATUS_INTERNAL_ERROR: return "INTERNAL_ERROR";
        case ANIGMA_STATUS_BUFFER_TOO_SMALL: return "BUFFER_TOO_SMALL";
        case ANIGMA_STATUS_UNIMPLEMENTED: return "UNIMPLEMENTED";
        default: return "UNKNOWN";
    }
}

void* anigma_arena_alloc(anigma_arena_t* arena, size_t size, size_t alignment) {
    if (arena == nullptr || arena->base == nullptr) {
        return nullptr;
    }
    
    uintptr_t base = reinterpret_cast<uintptr_t>(arena->base) + arena->offset;
    uintptr_t aligned = (base + alignment - 1) & ~(alignment - 1);
    
    if (aligned + size > arena->base + arena->size) {
        return nullptr;
    }
    
    arena->offset = aligned + size - reinterpret_cast<uintptr_t>(arena->base);
    return reinterpret_cast<void*>(aligned);
}

void anigma_arena_reset(anigma_arena_t* arena) {
    if (arena != nullptr) {
        arena->offset = 0;
    }
}

void anigma_arena_free(anigma_arena_t* arena) {
    if (arena != nullptr) {
        arena->base = nullptr;
        arena->size = 0;
        arena->offset = 0;
    }
}
