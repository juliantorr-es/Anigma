#ifndef ANIGMA_VECTOR_CAPSULE_H
#define ANIGMA_VECTOR_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

typedef anigma_capsule_handle_t anigma_vector_capsule_t;

typedef enum {
    ANIGMA_VECTOR_OP_UNION = 0,
    ANIGMA_VECTOR_OP_DIFFERENCE = 1,
    ANIGMA_VECTOR_OP_INTERSECTION = 2,
    ANIGMA_VECTOR_OP_XOR = 3
} anigma_vector_op_t;

typedef enum {
    ANIGMA_VECTOR_FILL_EVEN_ODD = 0,
    ANIGMA_VECTOR_FILL_NON_ZERO = 1,
    ANIGMA_VECTOR_FILL_POSITIVE = 2,
    ANIGMA_VECTOR_FILL_NEGATIVE = 3
} anigma_vector_fillrule_t;

anigma_capsule_identity_t anigma_vector_capsule_get_identity(void);

anigma_status_t anigma_vector_capsule_create_from_svg(
    const char* svg_path,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_destroy(
    anigma_vector_capsule_t handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_boolean_op(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_boolean_op_in_place(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_export_to_svg(
    anigma_vector_capsule_t handle,
    char** out_svg_string,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_export_canonical(
    anigma_vector_capsule_t handle,
    anigma_capsule_buffer_t* out_buffer,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_create_from_canonical(
    const anigma_capsule_buffer_t* buffer,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_is_empty(
    anigma_vector_capsule_t handle,
    bool* out_empty,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_get_bounds(
    anigma_vector_capsule_t handle,
    double* out_min_x, double* out_min_y, double* out_max_x, double* out_max_y,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_simplify_douglas_peucker(
    anigma_vector_capsule_t handle,
    double tolerance,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_simplify_visvalingam(
    anigma_vector_capsule_t handle,
    double tolerance,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_transform(
    anigma_vector_capsule_t handle,
    double a, double b, double c, double d, double e, double f,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_create_bezier(
    double start_x, double start_y,
    double control1_x, double control1_y,
    double control2_x, double control2_y,
    double end_x, double end_y,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_create_arc(
    double center_x, double center_y,
    double radius,
    double start_angle,
    double end_angle,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_point_in_polygon(
    anigma_vector_capsule_t handle,
    double x, double y,
    bool* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_line_intersection(
    double line1_start_x, double line1_start_y,
    double line1_end_x, double line1_end_y,
    double line2_start_x, double line2_start_y,
    double line2_end_x, double line2_end_y,
    bool* out_has_intersection,
    double* out_x, double* out_y,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_point_to_line_distance(
    double point_x, double point_y,
    double line_start_x, double line_start_y,
    double line_end_x, double line_end_y,
    double* out_distance,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_get_length(
    anigma_vector_capsule_t handle,
    double* out_length,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_vector_capsule_smooth_path(
    anigma_vector_capsule_t handle,
    double factor,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif
