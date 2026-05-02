# Anigma Runtime Kernel ABI Contract

## Overview

This document defines the stable C ABI surface between the Swift Runtime Orchestrator (Tier 1) and the C++ Runtime Kernel (Tier 2). The ABI is designed for stability, determinism, and type safety.

## Design Principles

1. **C ABI only** - No C++ name mangling, no exceptions, no RTTI
2. **Explicit versioning** - All payloads include schema versions
3. **Deterministic by default** - No OS calls, no wall-clock, no random
4. **Owned payloads** - Clear ownership semantics for all buffers
5. **Hash-verified** - Every boundary produces cryptographic hashes

## Versioning

```c
#define ANIGMA_KERNEL_VERSION_MAJOR 1
#define ANIGMA_KERNEL_VERSION_MINOR 0
#define ANIGMA_KERNEL_VERSION_PATCH 0

#define ANIGMA_KERNEL_VERSION_STRING "1.0.0"
#define ANIGMA_KERNEL_ABI_VERSION 0x10000
```

## Core Types

### Status Codes

```c
typedef enum anigma_status {
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
} anigma_status_t;
```

### Entity Identity

```c
typedef struct anigma_entity_id_t {
    uint64_t high;
    uint64_t low;
} anigma_entity_id_t;

static inline int anigma_entity_id_equal(
    anigma_entity_id_t a,
    anigma_entity_id_t b
) {
    return a.high == b.high && a.low == b.low;
}

static inline int anigma_entity_id_less(
    anigma_entity_id_t a,
    anigma_entity_id_t b
) {
    return a.high < b.high || (a.high == b.high && a.low < b.low);
}
```

### Time Representation

```c
typedef int64_t anigma_time_tick_t;

static const anigma_time_tick_t ANIGMA_TICKS_PER_SECOND = 1000000LL;

static inline anigma_time_tick_t anigma_time_from_seconds(double s) {
    return (anigma_time_tick_t)llround(s * (double)ANIGMA_TICKS_PER_SECOND);
}

static inline double anigma_time_to_seconds(anigma_time_tick_t t) {
    return (double)t / (double)ANIGMA_TICKS_PER_SECOND;
}
```

### Coordinate Representation

```c
typedef int32_t anigma_coordinate_t;
static const int32_t ANIGMA_COORDINATE_SCALE = 256;

static inline anigma_coordinate_t anigma_coord_from_float(float f) {
    return (anigma_coordinate_t)llround(f * (float)ANIGMA_COORDINATE_SCALE);
}

static inline float anigma_coord_to_float(anigma_coordinate_t c) {
    return (float)c / (float)ANIGMA_COORDINATE_SCALE;
}

typedef struct anigma_point_t {
    anigma_coordinate_t x;
    anigma_coordinate_t y;
} anigma_point_t;

typedef struct anigma_rect_t {
    anigma_coordinate_t x;
    anigma_coordinate_t y;
    anigma_coordinate_t width;
    anigma_coordinate_t height;
} anigma_rect_t;
```

### Transform (3x3 Matrix, Fixed-Point)

```c
typedef struct anigma_transform_t {
    anigma_coordinate_t m[3][3];
} anigma_transform_t;

static const anigma_transform_t ANIGMA_TRANSFORM_IDENTITY = {
    .m = {
        {ANIGMA_COORDINATE_SCALE, 0, 0},
        {0, ANIGMA_COORDINATE_SCALE, 0},
        {0, 0, ANIGMA_COORDINATE_SCALE}
    }
};
```

### Determinism Profile

```c
typedef struct anigma_determinism_profile_t {
    uint64_t profile_id;
    uint64_t tick_resolution;
    int32_t coordinate_scale;
    uint32_t sort_tie_break_mode;
    uint64_t flags;
} anigma_determinism_profile_t;

static const anigma_determinism_profile_t ANIGMA_PROFILE_DEFAULT = {
    .profile_id = 0x414E49474D410001ULL,
    .tick_resolution = ANIGMA_TICKS_PER_SECOND,
    .coordinate_scale = ANIGMA_COORDINATE_SCALE,
    .sort_tie_break_mode = 0,
    .flags = 0,
};
```

## Request/Response Pattern

### Request Header

```c
typedef struct anigma_request_header_t {
    uint32_t schema_version;
    uint32_t operation_code;
    uint64_t request_id;
    uint64_t profile_id;
    anigma_time_tick_t timestamp;
    uint32_t payload_size;
    const uint8_t* payload_ptr;
} anigma_request_header_t;
```

### Response Header

```c
typedef struct anigma_response_header_t {
    uint32_t schema_version;
    uint32_t status_code;
    uint64_t request_id;
    uint8_t input_hash[32];
    uint8_t output_hash[32];
    uint32_t payload_size;
    uint8_t* payload_ptr;
} anigma_response_header_t;
```

### Operation Codes

```c
typedef enum anigma_operation {
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
} anigma_operation_t;
```

## Memory and Buffer Management

### Buffer Descriptor

```c
typedef struct anigma_buffer_t {
    uint8_t* data;
    size_t size;
    size_t capacity;
} anigma_buffer_t;
```

### Memory Arena (for snapshot-able allocations)

```c
typedef struct anigma_arena_t {
    uint8_t* base;
    size_t size;
    size_t offset;
} anigma_arena_t;

void* anigma_arena_alloc(anigma_arena_t* arena, size_t size, size_t alignment);
void anigma_arena_reset(anigma_arena_t* arena);
void anigma_arena_free(anigma_arena_t* arena);
```

## Core Operations

### Initialize

```c
typedef struct anigma_initialize_request_t {
    anigma_determinism_profile_t profile;
    uint64_t config_hash;
    uint32_t initial_entity_capacity;
    uint32_t initial_component_capacity;
} anigma_initialize_request_t;

typedef struct anigma_initialize_response_t {
    uint64_t instance_id;
    uint64_t kernel_build_id;
    anigma_determinism_profile_t active_profile;
} anigma_initialize_response_t;

anigma_status_t anigma_initialize(
    const anigma_initialize_request_t* request,
    anigma_initialize_response_t* response,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
);
```

### Get Info

```c
typedef struct anigma_info_response_t {
    uint32_t major_version;
    uint32_t minor_version;
    uint32_t patch_version;
    uint64_t build_id;
    uint64_t abi_version;
    const char* build_date;
    const char* build_commit;
} anigma_info_response_t;

anigma_status_t anigma_get_info(anigma_info_response_t* response);
```

### Apply Diff Batch

```c
typedef enum anigma_diff_op {
    ANIGMA_DIFF_ATTACH = 0,
    ANIGMA_DIFF_DETACH = 1,
    ANIGMA_DIFF_UPDATE = 2,
    ANIGMA_DIFF_TRANSFORM = 3,
    ANIGMA_DIFF_PROPERTY = 4,
} anigma_diff_op_t;

typedef struct anigma_diff_header_t {
    anigma_diff_op_t op;
    uint32_t target_count;
    uint64_t flags;
} anigma_diff_header_t;

typedef struct anigma_diff_attach_t {
    anigma_entity_id_t entity_id;
    uint32_t component_type;
    uint32_t component_size;
    uint8_t component_data[];
} anigma_diff_attach_t;

typedef struct anigma_diff_transform_t {
    anigma_entity_id_t entity_id;
    anigma_transform_t transform;
} anigma_diff_transform_t;

typedef struct anigma_diff_batch_t {
    uint32_t diff_count;
    uint32_t schema_version;
    uint64_t sequence_id;
    anigma_diff_header_t diffs[];
} anigma_diff_batch_t;

anigma_status_t anigma_diff_apply(
    anigma_diff_batch_t* batch,
    anigma_buffer_t* output_state,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
);
```

### Simulation Step

```c
typedef struct anigma_simulation_step_request_t {
    anigma_time_tick_t delta_ticks;
    uint32_t max_steps;
} anigma_simulation_step_request_t;

typedef struct anigma_simulation_step_response_t {
    anigma_time_tick_t accumulated_time;
    uint32_t steps_taken;
    uint8_t state_hash[32];
} anigma_simulation_step_response_t;

anigma_status_t anigma_simulation_step(
    const anigma_simulation_step_request_t* request,
    anigma_simulation_step_response_t* response,
    anigma_buffer_t* error_info
);
```

### Hit Test

```c
typedef struct anigma_hit_query_t {
    anigma_point_t point;
    uint32_t flags;
    uint32_t max_results;
    const anigma_entity_id_t* exclude_ids;
    uint32_t exclude_count;
} anigma_hit_query_t;

typedef struct anigma_hit_result_t {
    anigma_entity_id_t entity_id;
    anigma_point_t local_point;
    uint32_t hit_reason;
    uint32_t layer_index;
    uint32_t render_order;
} anigma_hit_result_t;

typedef struct anigma_hit_response_t {
    uint32_t result_count;
    uint32_t total_considered;
    anigma_hit_result_t results[];
} anigma_hit_response_t;

anigma_status_t anigma_hit_test(
    const anigma_hit_query_t* query,
    anigma_hit_response_t* response,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
);
```

### Render Plan

```c
typedef enum anigma_draw_op_type {
    ANIGMA_DRAW_CLEAR = 0,
    ANIGMA_DRAW_RECT = 1,
    ANIGMA_DRAW_PATH = 2,
    ANIGMA_DRAW_TEXT = 3,
    ANIGMA_DRAW_IMAGE = 4,
    ANIGMA_DRAW_CLIP = 5,
    ANIGMA_DRAW_LAYER = 6,
} anigma_draw_op_type_t;

typedef struct anigma_resource_ref_t {
    uint64_t resource_id;
    uint32_t resource_type;
} anigma_resource_ref_t;

typedef struct anigma_draw_op_t {
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
} anigma_draw_op_t;

typedef struct anigma_render_plan_t {
    uint32_t op_count;
    uint32_t resource_count;
    uint8_t plan_hash[32];
    anigma_draw_op_t ops[];
} anigma_render_plan_t;

typedef struct anigma_render_plan_request_t {
    anigma_rect_t viewport;
    uint32_t render_flags;
} anigma_render_plan_request_t;

anigma_status_t anigma_render_plan_generate(
    const anigma_render_plan_request_t* request,
    anigma_render_plan_t** plan,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
);
```

### Snapshot Export

```c
typedef struct anigma_snapshot_header_t {
    uint32_t schema_version;
    uint64_t kernel_build_id;
    uint64_t config_hash;
    uint64_t entity_count;
    uint64_t state_size;
    uint8_t header_hash[32];
} anigma_snapshot_header_t;

typedef struct anigma_snapshot_t {
    anigma_snapshot_header_t header;
    uint8_t data[];
} anigma_snapshot_t;

anigma_status_t anigma_snapshot_export(
    anigma_snapshot_t** snapshot,
    size_t* snapshot_size,
    anigma_arena_t* arena,
    anigma_buffer_t* error_info
);

anigma_status_t anigma_snapshot_import(
    const anigma_snapshot_t* snapshot,
    size_t snapshot_size,
    anigma_buffer_t* error_info
);
```

### State Hash

```c
typedef struct anigma_state_hash_request_t {
    uint32_t hash_algorithm;
    uint64_t components_mask;
} anigma_state_hash_request_t;

typedef struct anigma_state_hash_response_t {
    uint8_t hash[32];
    uint64_t entity_count;
    uint64_t component_count;
} anigma_state_hash_response_t;

anigma_status_t anigma_state_hash(
    const anigma_state_hash_request_t* request,
    anigma_state_hash_response_t* response,
    anigma_buffer_t* error_info
);
```

## Error Handling

```c
typedef struct anigma_error_info_t {
    uint32_t error_code;
    uint32_t error_domain;
    const char* message;
    const char* detail;
    uint64_t aux;
} anigma_error_info_t;

const char* anigma_status_to_string(anigma_status_t status);
void anigma_error_free(anigma_error_info_t* error);
```

## Hashing

```c
#define ANIGMA_HASH_SIZE 32

void anigma_hash_init(uint8_t state[64]);
void anigma_hash_update(uint8_t state[64], const void* data, size_t size);
void anigma_hash_final(uint8_t state[64], uint8_t output[32]);
void anigma_hash(const void* data, size_t size, uint8_t output[32]);
```

## Usage Example

```c
// Swift calls into C++ kernel
anigma_status_t status;
anigma_initialize_response_t init_response;
anigma_buffer_t error_info = {0};

status = anigma_initialize(&init_request, &init_response, &arena, &error_info);
if (status != ANIGMA_STATUS_SUCCESS) {
    // Handle error
}

// Later, apply diffs
anigma_diff_batch_t* batch = create_diff_batch();
status = anigma_diff_apply(batch, &output, &arena, &error_info);

// Generate render plan
anigma_render_plan_t* plan;
status = anigma_render_plan_generate(&render_request, &plan, &arena, &error_info);

// Verify determinism
uint8_t expected_hash[32] = {...};
if (memcmp(plan->plan_hash, expected_hash, 32) != 0) {
    // Determinism violation!
}
```
