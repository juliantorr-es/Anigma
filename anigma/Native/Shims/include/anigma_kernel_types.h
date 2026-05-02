#ifndef ANIGMA_KERNEL_TYPES_H
#define ANIGMA_KERNEL_TYPES_H

#include "anigma_native_common.h"

#ifdef __cplusplus
#include <cmath>
#include <cstdint>
#include <cstddef>

extern "C" {
#endif

#define ANIGMA_KERNEL_VERSION_MAJOR 1
#define ANIGMA_KERNEL_VERSION_MINOR 0
#define ANIGMA_KERNEL_VERSION_PATCH 0
#define ANIGMA_KERNEL_ABI_VERSION 0x10000

#define ANIGMA_TICKS_PER_SECOND 1000000LL
#define ANIGMA_COORDINATE_SCALE 256
#define ANIGMA_HASH_SIZE 32

typedef int64_t anigma_time_tick_t;
typedef int32_t anigma_coordinate_t;
typedef anigma_status_t anigma_kernel_status_t;
typedef uint16_t anigma_operation_t;
typedef uint8_t anigma_kernel_diff_op_t;
typedef uint8_t anigma_draw_op_type_t;
typedef uint8_t anigma_traversal_order_t;

typedef enum {
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
} anigma_operation;

typedef enum {
    ANIGMA_DIFF_ATTACH = 0,
    ANIGMA_DIFF_DETACH = 1,
    ANIGMA_DIFF_UPDATE = 2,
    ANIGMA_DIFF_TRANSFORM = 3,
    ANIGMA_DIFF_PROPERTY = 4,
} anigma_diff_op;

typedef enum {
    ANIGMA_DRAW_CLEAR = 0,
    ANIGMA_DRAW_RECT = 1,
    ANIGMA_DRAW_PATH = 2,
    ANIGMA_DRAW_TEXT = 3,
    ANIGMA_DRAW_IMAGE = 4,
    ANIGMA_DRAW_CLIP = 5,
    ANIGMA_DRAW_LAYER = 6,
} anigma_draw_op_type;

typedef enum {
    ANIGMA_TRAVERSAL_PRE_ORDER = 0,
    ANIGMA_TRAVERSAL_POST_ORDER = 1,
    ANIGMA_TRAVERSAL_DEPTH_FIRST = 2,
    ANIGMA_TRAVERSAL_LAYER_ORDER = 3,
} anigma_traversal_order;

typedef struct {
    uint64_t high;
    uint64_t low;
} anigma_entity_id_t;

typedef struct {
    anigma_coordinate_t x;
    anigma_coordinate_t y;
} anigma_point_t;

typedef struct {
    anigma_coordinate_t x;
    anigma_coordinate_t y;
    anigma_coordinate_t width;
    anigma_coordinate_t height;
} anigma_rect_t;

typedef struct {
    anigma_coordinate_t m[3][3];
} anigma_transform_t;

typedef struct {
    uint64_t profile_id;
    uint64_t tick_resolution;
    int32_t coordinate_scale;
    uint32_t sort_tie_break_mode;
    uint64_t flags;
} anigma_determinism_profile_t;

typedef struct {
    uint32_t schema_version;
    uint32_t operation_code;
    uint64_t request_id;
    uint64_t profile_id;
    anigma_time_tick_t timestamp;
    uint32_t payload_size;
    const uint8_t* payload_ptr;
} anigma_request_header_t;

typedef struct {
    uint32_t schema_version;
    uint32_t status_code;
    uint64_t request_id;
    uint8_t input_hash[ANIGMA_HASH_SIZE];
    uint8_t output_hash[ANIGMA_HASH_SIZE];
    uint32_t payload_size;
    uint8_t* payload_ptr;
} anigma_response_header_t;

typedef struct {
    uint8_t* data;
    size_t size;
    size_t capacity;
} anigma_buffer_t;

typedef struct {
    anigma_determinism_profile_t profile;
    uint64_t config_hash;
    uint32_t initial_entity_capacity;
    uint32_t initial_component_capacity;
} anigma_initialize_request_t;

typedef struct {
    uint64_t instance_id;
    uint64_t kernel_build_id;
    anigma_determinism_profile_t active_profile;
} anigma_initialize_response_t;

typedef struct {
    anigma_kernel_diff_op_t op;
    uint32_t target_count;
    uint64_t flags;
    uint32_t payload_size;
} anigma_diff_header_t;

typedef struct {
    anigma_entity_id_t entity_id;
    uint32_t component_type;
    uint32_t component_size;
    uint8_t component_data[0];
} anigma_diff_attach_t;

typedef struct {
    anigma_entity_id_t entity_id;
    anigma_transform_t transform;
} anigma_diff_transform_t;

typedef struct {
    uint32_t diff_count;
    uint32_t schema_version;
    uint64_t sequence_id;
    anigma_diff_header_t diffs[0];
} anigma_diff_batch_t;

typedef struct {
    anigma_time_tick_t delta_ticks;
    uint32_t max_steps;
} anigma_simulation_step_request_t;

typedef struct {
    anigma_time_tick_t accumulated_time;
    uint32_t steps_taken;
    uint8_t state_hash[ANIGMA_HASH_SIZE];
} anigma_simulation_step_response_t;

typedef struct {
    anigma_point_t point;
    uint32_t flags;
    uint32_t max_results;
    const anigma_entity_id_t* exclude_ids;
    uint32_t exclude_count;
} anigma_hit_query_t;

typedef struct {
    anigma_entity_id_t entity_id;
    anigma_point_t local_point;
    uint32_t hit_reason;
    uint32_t layer_index;
    uint32_t render_order;
} anigma_hit_result_t;

typedef struct {
    uint32_t result_count;
    uint32_t total_considered;
    anigma_hit_result_t results[0];
} anigma_hit_response_t;

typedef struct {
    uint64_t resource_id;
    uint32_t resource_type;
} anigma_resource_ref_t;

typedef struct {
    uint32_t op_index;
    anigma_draw_op_type_t type;
    uint32_t layer_id;
    
    // Indices into plan data arrays
    uint32_t transform_index;
    uint32_t paint_index;
    uint32_t resource_index;
    
    // For depth sorting
    uint64_t sort_key;
    
    anigma_rect_t clip;
    
    union {
        struct { anigma_rect_t rect; } rect;
        struct { uint64_t path_id; } path;
        struct { uint64_t text_run_id; anigma_point_t origin; } text;
        struct { uint64_t image_id; anigma_rect_t source; } image;
    } data;
} anigma_draw_op_t;

typedef struct {
    uint32_t op_count;
    uint32_t resource_count;
    uint8_t plan_hash[ANIGMA_HASH_SIZE];
    anigma_draw_op_t ops[0];
} anigma_render_plan_data_t;

typedef struct {
    anigma_rect_t viewport;
    uint32_t render_flags;
} anigma_render_plan_request_t;

typedef struct {
    uint32_t schema_version;
    uint64_t kernel_build_id;
    uint64_t config_hash;
    uint64_t entity_count;
    uint64_t state_size;
    uint8_t header_hash[ANIGMA_HASH_SIZE];
} anigma_snapshot_header_t;

typedef struct {
    uint32_t hash_algorithm;
    uint64_t components_mask;
} anigma_state_hash_request_t;

typedef struct {
    uint8_t hash[ANIGMA_HASH_SIZE];
    uint64_t entity_count;
    uint64_t component_count;
} anigma_state_hash_response_t;

typedef struct {
    uint64_t build_id;
    uint32_t capabilities;
    uint32_t reserved;
} anigma_info_response_t;

typedef void* anigma_snapshot_t;

static inline int anigma_entity_id_equal(anigma_entity_id_t a, anigma_entity_id_t b) {
    return a.high == b.high && a.low == b.low;
}

static inline int anigma_entity_id_less(anigma_entity_id_t a, anigma_entity_id_t b) {
    return a.high < b.high || (a.high == b.high && a.low < b.low);
}

#ifdef __cplusplus
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
#endif

#ifdef __cplusplus
}
#endif

#endif
