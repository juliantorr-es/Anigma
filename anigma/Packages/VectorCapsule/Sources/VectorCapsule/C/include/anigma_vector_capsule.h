#ifndef ANIGMA_VECTOR_CAPSULE_H
#define ANIGMA_VECTOR_CAPSULE_H

#include "../../../Native/Shims/include/anigma_capsule_core.h"
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Vector capsule types
typedef struct anigma_vector_capsule_t anigma_vector_capsule_t;

// Fixed-point coordinate (1/1000th of a point)
typedef int32_t anigma_fixed_point_t;

// Vector operation types
typedef enum {
    ANIGMA_VECTOR_OP_UNION = 0,
    ANIGMA_VECTOR_OP_INTERSECTION = 1,
    ANIGMA_VECTOR_OP_DIFFERENCE = 2,
    ANIGMA_VECTOR_OP_XOR = 3
} anigma_vector_op_t;

// Fill rules
typedef enum {
    ANIGMA_VECTOR_FILL_EVEN_ODD = 0,
    ANIGMA_VECTOR_FILL_NON_ZERO = 1
} anigma_vector_fill_rule_t;

// Join styles for offset operations
typedef enum {
    ANIGMA_VECTOR_JOIN_SQUARE = 0,
    ANIGMA_VECTOR_JOIN_ROUND = 1,
    ANIGMA_VECTOR_JOIN_MITER = 2
} anigma_vector_join_style_t;

// End cap styles for offset operations
typedef enum {
    ANIGMA_VECTOR_CAP_BUTT = 0,
    ANIGMA_VECTOR_CAP_ROUND = 1,
    ANIGMA_VECTOR_CAP_SQUARE = 2
} anigma_vector_cap_style_t;

// Point structure (fixed-point)
typedef struct {
    anigma_fixed_point_t x;
    anigma_fixed_point_t y;
} anigma_point_t;

// Bounding box (fixed-point)
typedef struct {
    anigma_fixed_point_t min_x;
    anigma_fixed_point_t min_y;
    anigma_fixed_point_t max_x;
    anigma_fixed_point_t max_y;
} anigma_bounds_t;

// Path contour
typedef struct {
    anigma_point_t* points;
    size_t point_count;
    uint8_t closed;  // 0 = open, 1 = closed
    anigma_vector_fill_rule_t fill_rule;
} anigma_contour_t;

// Path (collection of contours)
typedef struct {
    anigma_contour_t* contours;
    size_t contour_count;
} anigma_path_t;

// Vector capsule configuration
typedef struct {
    anigma_fixed_point_t scale_factor;  // Coordinate scale (default: 1000 = 1/1000th point)
    uint32_t determinism_tier;         // 1 = bitwise, 2 = epsilon-stable
    double simplification_tolerance;     // Default tolerance for simplification
    uint32_t miter_limit;             // Default miter limit for offsets
} anigma_vector_config_t;

// Offset operation parameters
typedef struct {
    anigma_fixed_point_t delta;         // Offset distance (fixed-point)
    anigma_vector_join_style_t join_style;
    anigma_vector_cap_style_t cap_style;
    uint32_t miter_limit;
} anigma_offset_params_t;

// Operation result with metadata
typedef struct {
    anigma_path_t output_path;
    uint64_t operation_hash;           // BLAKE3 hash of operation inputs
    uint32_t output_contour_count;
    uint64_t processing_time_us;       // Microseconds
} anigma_operation_result_t;

// Get capsule identity
anigma_capsule_identity_t anigma_vector_capsule_get_identity(void);

// Get default configuration
anigma_vector_config_t anigma_vector_capsule_get_default_config(void);

// Validate configuration
anigma_status_t anigma_vector_capsule_validate_config(
    const anigma_vector_config_t* config,
    anigma_capsule_error_t* error
);

// Create capsule instance
anigma_status_t anigma_vector_capsule_create(
    const anigma_vector_config_t* config,
    anigma_vector_capsule_t** capsule,
    anigma_capsule_error_t* error
);

// Destroy capsule instance
anigma_status_t anigma_vector_capsule_destroy(
    anigma_vector_capsule_t* capsule,
    anigma_capsule_error_t* error
);

// Load path from binary data (canonical internal format)
anigma_status_t anigma_vector_capsule_load_path_binary(
    anigma_vector_capsule_t* capsule,
    const uint8_t* data,
    size_t data_size,
    uint64_t* path_id,
    anigma_capsule_error_t* error
);

// Load path from SVG string (debug/convenience only)
anigma_status_t anigma_vector_capsule_load_path_svg(
    anigma_vector_capsule_t* capsule,
    const char* svg_string,
    uint64_t* path_id,
    anigma_capsule_error_t* error
);

// Boolean operations
anigma_status_t anigma_vector_capsule_boolean_op(
    anigma_vector_capsule_t* capsule,
    uint64_t path_a_id,
    uint64_t path_b_id,
    anigma_vector_op_t operation,
    anigma_vector_fill_rule_t fill_rule,
    anigma_operation_result_t* result,
    anigma_capsule_error_t* error
);

// Offset operation (inflate/deflate)
anigma_status_t anigma_vector_capsule_offset_path(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    const anigma_offset_params_t* params,
    anigma_operation_result_t* result,
    anigma_capsule_error_t* error
);

// Simplification operations
anigma_status_t anigma_vector_capsule_simplify_douglas_peucker(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    anigma_fixed_point_t tolerance,
    anigma_operation_result_t* result,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_capsule_simplify_visvalingam(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    anigma_fixed_point_t tolerance,
    anigma_operation_result_t* result,
    anigma_capsule_error_t* error
);

// Transform operations
anigma_status_t anigma_vector_capsule_transform(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    // 2D transformation matrix [a b c d e f]
    anigma_fixed_point_t a, anigma_fixed_point_t b, anigma_fixed_point_t c,
    anigma_fixed_point_t d, anigma_fixed_point_t e, anigma_fixed_point_t f,
    anigma_operation_result_t* result,
    anigma_capsule_error_t* error
);

// Geometric predicates
anigma_status_t anigma_vector_capsule_point_in_polygon(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    anigma_point_t point,
    uint8_t* result,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_capsule_get_bounds(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    anigma_bounds_t* bounds,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_capsule_is_empty(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    uint8_t* result,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_capsule_get_length(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    anigma_fixed_point_t* length,
    anigma_capsule_error_t* error
);

// Export operations
anigma_status_t anigma_vector_capsule_export_binary(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_capsule_export_svg(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    char** svg_string,
    anigma_capsule_error_t* error
);

// Path management
anigma_status_t anigma_vector_capsule_release_path(
    anigma_vector_capsule_t* capsule,
    uint64_t path_id,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_vector_capsule_clear_cache(
    anigma_vector_capsule_t* capsule,
    anigma_capsule_error_t* error
);

// Diagnostic information
anigma_status_t anigma_vector_capsule_get_stats(
    anigma_vector_capsule_t* capsule,
    anigma_capsule_buffer_t* buffer,  // JSON formatted stats
    anigma_capsule_error_t* error
);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_VECTOR_CAPSULE_H