#ifndef ANIGMA_KERNEL_TYPES_H
#define ANIGMA_KERNEL_TYPES_H

#include <cstdint>
#include <cstddef>
#include <cmath>

#if defined(__cplusplus)
extern "C" {
#endif

constexpr uint32_t ANIGMA_KERNEL_VERSION_MAJOR = 1;
constexpr uint32_t ANIGMA_KERNEL_VERSION_MINOR = 0;
constexpr uint32_t ANIGMA_KERNEL_VERSION_PATCH = 0;
constexpr uint32_t ANIGMA_KERNEL_ABI_VERSION = 0x10000;

constexpr int64_t ANIGMA_TICKS_PER_SECOND = 1000000LL;
constexpr int32_t ANIGMA_COORDINATE_SCALE = 256;
constexpr size_t ANIGMA_HASH_SIZE = 32;

using anigma_time_tick_t = int64_t;
using anigma_coordinate_t = int32_t;
using anigma_status_t = uint8_t;
using anigma_operation_t = uint16_t;
using anigma_diff_op_t = uint8_t;
using anigma_draw_op_type_t = uint8_t;
using anigma_traversal_order_t = uint8_t;

enum anigma_status : anigma_status_t {
    ANIGMA_STATUS_SUCCESS = 0,
    ANIGMA_STATUS_INVALID_INPUT = 1,
    ANIGMA_STATUS_INVALID_SCHEMA = 2,
    ANIGMA_STATUS_VERSION_MISMATCH = 3,
    ANIGMA_STATUS_OUT_OF_BOUNDS = 4,
    ANIGMA_STATUS_ALREADY_EXISTS = 5,
    ANIGMA_STATUS_NOT_FOUND = 6,
    ANIGMA_STATUS_DETERMINISM_VIOLATION = 7,
    ANIGMA_STATUS_INTERNAL_ERROR = 8,
    ANIGMA_STATUS_BUFFER_TOO_SMALL = 9,
    ANIGMA_STATUS_UNIMPLEMENTED = 10,
};

enum anigma_operation : anigma_operation_t {
    ANIGMA_OP_INITIALIZE = 0x1000,
    ANIGMA_OP_SHUTDOWN = 0x1001,
    ANIGMA_OP_GET_INFO = 0x1002,
    ANIGMA_OP_DIFF_APPLY = 0x2000,
    ANIGMA_OP_DIFF_BATCH = 0x2001,
    ANIGMA_OP_SIMULATION_STEP = 0x3000,
    ANIGMA_OP_TIMELINE_EVALUATE = 0x3001,
    ANIGMA_OP_ANIMATION_EVALUATE = 0x3002,
    ANIGMA_OP_HIT_TEST = 0x4000,
    ANIGMA_OP_SPATIAL_QUERY = 0x4001,
    ANIGMA_OP_RENDER_PLAN = 0x5000,
    ANIGMA_OP_SNAPSHOT_EXPORT = 0x6000,
    ANIGMA_OP_SNAPSHOT_IMPORT = 0x6001,
    ANIGMA_OP_STATE_HASH = 0x6002,
};

enum anigma_diff_op : anigma_diff_op_t {
    ANIGMA_DIFF_ATTACH = 0,
    ANIGMA_DIFF_DETACH = 1,
    ANIGMA_DIFF_UPDATE = 2,
    ANIGMA_DIFF_TRANSFORM = 3,
    ANIGMA_DIFF_PROPERTY = 4,
};

enum anigma_draw_op_type : anigma_draw_op_type_t {
    ANIGMA_DRAW_CLEAR = 0,
    ANIGMA_DRAW_RECT = 1,
    ANIGMA_DRAW_PATH = 2,
    ANIGMA_DRAW_TEXT = 3,
    ANIGMA_DRAW_IMAGE = 4,
    ANIGMA_DRAW_CLIP = 5,
    ANIGMA_DRAW_LAYER = 6,
};

enum anigma_traversal_order : anigma_traversal_order_t {
    ANIGMA_TRAVERSAL_PRE_ORDER = 0,
    ANIGMA_TRAVERSAL_POST_ORDER = 1,
    ANIGMA_TRAVERSAL_DEPTH_FIRST = 2,
    ANIGMA_TRAVERSAL_LAYER_ORDER = 3,
};

struct anigma_entity_id_t {
    uint64_t high;
    uint64_t low;
};

struct anigma_point_t {
    anigma_coordinate_t x;
    anigma_coordinate_t y;
};

struct anigma_rect_t {
    anigma_coordinate_t x;
    anigma_coordinate_t y;
    anigma_coordinate_t width;
    anigma_coordinate_t height;
};

struct anigma_transform_t {
    anigma_coordinate_t m[3][3];
};

struct anigma_determinism_profile_t {
    uint64_t profile_id;
    uint64_t tick_resolution;
    int32_t coordinate_scale;
    uint32_t sort_tie_break_mode;
    uint64_t flags;
};

struct anigma_request_header_t {
    uint32_t schema_version;
    uint32_t operation_code;
    uint64_t request_id;
    uint64_t profile_id;
    anigma_time_tick_t timestamp;
    uint32_t payload_size;
    const uint8_t* payload_ptr;
};

struct anigma_response_header_t {
    uint32_t schema_version;
    uint32_t status_code;
    uint64_t request_id;
    uint8_t input_hash[ANIGMA_HASH_SIZE];
    uint8_t output_hash[ANIGMA_HASH_SIZE];
    uint32_t payload_size;
    uint8_t* payload_ptr;
};

struct anigma_buffer_t {
    uint8_t* data;
    size_t size;
    size_t capacity;
};

struct anigma_arena_t {
    uint8_t* base;
    size_t size;
    size_t offset;
};

struct anigma_initialize_request_t {
    anigma_determinism_profile_t profile;
    uint64_t config_hash;
    uint32_t initial_entity_capacity;
    uint32_t initial_component_capacity;
};

struct anigma_initialize_response_t {
    uint64_t instance_id;
    uint64_t kernel_build_id;
    anigma_determinism_profile_t active_profile;
};

struct anigma_diff_header_t {
    anigma_diff_op_t op;
    uint32_t target_count;
    uint64_t flags;
};

struct anigma_diff_attach_t {
    anigma_entity_id_t entity_id;
    uint32_t component_type;
    uint32_t component_size;
    uint8_t component_data[];
};

struct anigma_diff_transform_t {
    anigma_entity_id_t entity_id;
    anigma_transform_t transform;
};

struct anigma_diff_batch_t {
    uint32_t diff_count;
    uint32_t schema_version;
    uint64_t sequence_id;
    anigma_diff_header_t diffs[];
};

struct anigma_simulation_step_request_t {
    anigma_time_tick_t delta_ticks;
    uint32_t max_steps;
};

struct anigma_simulation_step_response_t {
    anigma_time_tick_t accumulated_time;
    uint32_t steps_taken;
    uint8_t state_hash[ANIGMA_HASH_SIZE];
};

struct anigma_hit_query_t {
    anigma_point_t point;
    uint32_t flags;
    uint32_t max_results;
    const anigma_entity_id_t* exclude_ids;
    uint32_t exclude_count;
};

struct anigma_hit_result_t {
    anigma_entity_id_t entity_id;
    anigma_point_t local_point;
    uint32_t hit_reason;
    uint32_t layer_index;
    uint32_t render_order;
};

struct anigma_hit_response_t {
    uint32_t result_count;
    uint32_t total_considered;
    anigma_hit_result_t results[];
};

struct anigma_resource_ref_t {
    uint64_t resource_id;
    uint32_t resource_type;
};

struct anigma_draw_op_t {
    uint32_t op_index;
    anigma_draw_op_type_t type;
    uint32_t layer_id;
    anigma_transform_t transform;
    anigma_rect_t clip;
    anigma_resource_ref_t material;
    union {
        struct { anigma_rect_t rect; } rect;
        struct { uint64_t path_id; } path;
        struct { uint64_t text_run_id; anigma_point_t origin; } text;
        struct { uint64_t image_id; anigma_rect_t source; } image;
    };
};

struct anigma_render_plan_t {
    uint32_t op_count;
    uint32_t resource_count;
    uint8_t plan_hash[ANIGMA_HASH_SIZE];
    anigma_draw_op_t ops[];
};

struct anigma_render_plan_request_t {
    anigma_rect_t viewport;
    uint32_t render_flags;
};

struct anigma_snapshot_header_t {
    uint32_t schema_version;
    uint64_t kernel_build_id;
    uint64_t config_hash;
    uint64_t entity_count;
    uint64_t state_size;
    uint8_t header_hash[ANIGMA_HASH_SIZE];
};

struct anigma_state_hash_request_t {
    uint32_t hash_algorithm;
    uint64_t components_mask;
};

struct anigma_state_hash_response_t {
    uint8_t hash[ANIGMA_HASH_SIZE];
    uint64_t entity_count;
    uint64_t component_count;
};

static const anigma_determinism_profile_t ANIGMA_PROFILE_DEFAULT = {
    .profile_id = 0x414E49474D410001ULL,
    .tick_resolution = ANIGMA_TICKS_PER_SECOND,
    .coordinate_scale = ANIGMA_COORDINATE_SCALE,
    .sort_tie_break_mode = 0,
    .flags = 0,
};

static const anigma_transform_t ANIGMA_TRANSFORM_IDENTITY = {
    .m = {
        {ANIGMA_COORDINATE_SCALE, 0, 0},
        {0, ANIGMA_COORDINATE_SCALE, 0},
        {0, 0, ANIGMA_COORDINATE_SCALE}
    }
};

static inline int anigma_entity_id_equal(anigma_entity_id_t a, anigma_entity_id_t b) {
    return a.high == b.high && a.low == b.low;
}

static inline int anigma_entity_id_less(anigma_entity_id_t a, anigma_entity_id_t b) {
    return a.high < b.high || (a.high == b.high && a.low < b.low);
}

static inline anigma_time_tick_t anigma_time_from_seconds(double s) {
    return (anigma_time_tick_t)std::llround(s * (double)ANIGMA_TICKS_PER_SECOND);
}

static inline double anigma_time_to_seconds(anigma_time_tick_t t) {
    return (double)t / (double)ANIGMA_TICKS_PER_SECOND;
}

static inline anigma_coordinate_t anigma_coord_from_float(float f) {
    return (anigma_coordinate_t)std::llround(f * (float)ANIGMA_COORDINATE_SCALE);
}

static inline float anigma_coord_to_float(anigma_coordinate_t c) {
    return (float)c / (float)ANIGMA_COORDINATE_SCALE;
}

#if defined(__cplusplus)
}
#endif

#endif
