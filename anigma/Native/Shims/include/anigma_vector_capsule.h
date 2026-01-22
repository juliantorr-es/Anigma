#ifndef ANIGMA_VECTOR_CAPSULE_H
#define ANIGMA_VECTOR_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Vector Capsule Types
// ============================================================================

// Opaque handle for vector paths
typedef anigma_capsule_handle_t anigma_vector_capsule_t;

// Boolean operation types
typedef enum {
    ANIGMA_VECTOR_OP_UNION = 0,
    ANIGMA_VECTOR_OP_DIFFERENCE = 1,
    ANIGMA_VECTOR_OP_INTERSECTION = 2,
    ANIGMA_VECTOR_OP_XOR = 3
} anigma_vector_op_t;

// Fill rule types
typedef enum {
    ANIGMA_VECTOR_FILL_EVEN_ODD = 0,
    ANIGMA_VECTOR_FILL_NON_ZERO = 1,
    ANIGMA_VECTOR_FILL_POSITIVE = 2,
    ANIGMA_VECTOR_FILL_NEGATIVE = 3
} anigma_vector_fillrule_t;

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get vector capsule identity.
 * Overrides the weak default implementation.
 */
anigma_capsule_identity_t anigma_vector_capsule_get_identity(void);

/**
 * Create a vector capsule handle from SVG path string.
 * This is an import operation (text → canonical internal representation).
 */
anigma_status_t anigma_vector_capsule_create_from_svg(
    const char* svg_path,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a vector capsule handle.
 */
anigma_status_t anigma_vector_capsule_destroy(
    anigma_vector_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Boolean Operations
// ============================================================================

/**
 * Perform boolean operation between two vector capsules.
 * Returns a new handle with the result.
 */
anigma_status_t anigma_vector_capsule_boolean_op(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

/**
 * Perform boolean operation in-place (modifies subject).
 */
anigma_status_t anigma_vector_capsule_boolean_op_in_place(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_capsule_error_t* err
);

// ============================================================================
// Export Functions
// ============================================================================

/**
 * Export vector capsule to SVG path string (presentation format).
 * Output string is capsule-allocated and must be freed with anigma_capsule_free_buffer.
 */
anigma_status_t anigma_vector_capsule_export_to_svg(
    anigma_vector_capsule_t handle,
    char** out_svg_string,
    anigma_capsule_error_t* err
);

/**
 * Export vector capsule to canonical binary format (receipt format).
 * Uses caller-allocated buffer with two-phase filling pattern.
 * 
 * Canonical Binary Format:
 *   [num_paths: uint32_t]
 *   for each path:
 *     [point_count: uint32_t]
 *     [points: double[2 * point_count]]  // x1, y1, x2, y2, ...
 * 
 * All integers are little-endian. Doubles are IEEE 754 binary64 little-endian.
 * Paths are stored in the order they appear in the internal representation.
 * Each path represents a closed polygon (implicitly closed by Z).
 */
anigma_status_t anigma_vector_capsule_export_canonical(
    anigma_vector_capsule_t handle,
    anigma_capsule_buffer_t* out_buffer,
    anigma_capsule_error_t* err
);

/**
 * Create vector capsule from canonical binary format.
 */
anigma_status_t anigma_vector_capsule_create_from_canonical(
    const anigma_capsule_buffer_t* buffer,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Check if a vector capsule is empty.
 */
anigma_status_t anigma_vector_capsule_is_empty(
    anigma_vector_capsule_t handle,
    bool* out_empty,
    anigma_capsule_error_t* err
);

/**
 * Get bounding box of vector capsule.
 */
anigma_status_t anigma_vector_capsule_get_bounds(
    anigma_vector_capsule_t handle,
    double* out_min_x,
    double* out_min_y,
    double* out_max_x,
    double* out_max_y,
    anigma_capsule_error_t* err
);

// ============================================================================
// Path Simplification Functions
// ============================================================================

/**
 * Simplify path using Douglas-Peucker algorithm.
 */
anigma_status_t anigma_vector_capsule_simplify_douglas_peucker(
    anigma_vector_capsule_t handle,
    double tolerance,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

/**
 * Simplify path using Visvalingam algorithm.
 */
anigma_status_t anigma_vector_capsule_simplify_visvalingam(
    anigma_vector_capsule_t handle,
    double tolerance,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

// ============================================================================
// Transformation Functions
// ============================================================================

/**
 * Apply affine transformation matrix to path.
 * Matrix format: [a c e; b d f; 0 0 1]
 */
anigma_status_t anigma_vector_capsule_transform(
    anigma_vector_capsule_t handle,
    double a, double b, double c, double d, double e, double f,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

// ============================================================================
// Geometric Primitive Creation Functions
// ============================================================================

/**
 * Create cubic Bezier curve.
 */
anigma_status_t anigma_vector_capsule_create_bezier(
    double start_x, double start_y,
    double control1_x, double control1_y,
    double control2_x, double control2_y,
    double end_x, double end_y,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

/**
 * Create circular arc.
 */
anigma_status_t anigma_vector_capsule_create_arc(
    double center_x, double center_y,
    double radius,
    double start_angle,
    double end_angle,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

// ============================================================================
// Geometric Predicate Functions
// ============================================================================

/**
 * Test if point is inside polygon.
 */
anigma_status_t anigma_vector_capsule_point_in_polygon(
    anigma_vector_capsule_t handle,
    double x, double y,
    bool* out_result,
    anigma_capsule_error_t* err
);

/**
 * Calculate intersection of two line segments.
 */
anigma_status_t anigma_vector_capsule_line_intersection(
    double line1_start_x, double line1_start_y,
    double line1_end_x, double line1_end_y,
    double line2_start_x, double line2_start_y,
    double line2_end_x, double line2_end_y,
    bool* out_has_intersection,
    double* out_x, double* out_y,
    anigma_capsule_error_t* err
);

/**
 * Calculate distance from point to line segment.
 */
anigma_status_t anigma_vector_capsule_point_to_line_distance(
    double point_x, double point_y,
    double line_start_x, double line_start_y,
    double line_end_x, double line_end_y,
    double* out_distance,
    anigma_capsule_error_t* err
);

// ============================================================================
// Additional Utility Functions
// ============================================================================

/**
 * Get total length of path(s).
 */
anigma_status_t anigma_vector_capsule_get_length(
    anigma_vector_capsule_t handle,
    double* out_length,
    anigma_capsule_error_t* err
);

/**
 * Smooth path using curve fitting.
 */
anigma_status_t anigma_vector_capsule_smooth_path(
    anigma_vector_capsule_t handle,
    double factor,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

// ============================================================================
// Swift Usage Example
// ============================================================================
/*
import AnigmaNativeShims

// Create a vector capsule from an SVG path string
func createSquare() throws -> CapsuleHandle<AnyObject> {
    var handle: anigma_vector_capsule_t?
    var error = anigma_capsule_error_t()
    let status = anigma_vector_capsule_create_from_svg(
        "M0,0 L100,0 L100,100 L0,100 Z",
        &handle,
        &error
    )
    guard status == ANIGMA_OK, let handle = handle else {
        throw CapsuleError(status: status, error: error)
    }
    return CapsuleHandle<AnyObject>(
        rawHandle: handle,
        destroyFunction: anigma_vector_capsule_destroy
    )
}

// Perform boolean union of two shapes
func unionShapes(_ shape1: CapsuleHandle<AnyObject>, _ shape2: CapsuleHandle<AnyObject>) throws -> CapsuleHandle<AnyObject> {
    var resultHandle: anigma_vector_capsule_t?
    var error = anigma_capsule_error_t()
    try shape1.withHandle { handle1 in
        try shape2.withHandle { handle2 in
            let status = anigma_vector_capsule_boolean_op(
                handle1,
                handle2,
                ANIGMA_VECTOR_OP_UNION,
                ANIGMA_VECTOR_FILL_EVEN_ODD,
                &resultHandle,
                &error
            )
            guard status == ANIGMA_OK, let result = resultHandle else {
                throw CapsuleError(status: status, error: error)
            }
            return CapsuleHandle<AnyObject>(
                rawHandle: result,
                destroyFunction: anigma_vector_capsule_destroy
            )
        }
    }
}

// Export to SVG path string
func exportToSVG(_ capsule: CapsuleHandle<AnyObject>) throws -> String {
    var svgString: UnsafeMutablePointer<CChar>?
    var error = anigma_capsule_error_t()
    try capsule.withHandle { handle in
        let status = anigma_vector_capsule_export_to_svg(handle, &svgString, &error)
        guard status == ANIGMA_OK, let svg = svgString else {
            throw CapsuleError(status: status, error: error)
        }
        defer { anigma_capsule_free_buffer(svg, &error) }
        return String(cString: svg)
    }
}
*/

#endif // ANIGMA_VECTOR_CAPSULE_H