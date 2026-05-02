#ifndef ANIGMA_GEOMETRY_CAPSULE_H
#define ANIGMA_GEOMETRY_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"

#if defined(__cplusplus)
extern "C" {
#endif

// Opaque handles
typedef anigma_capsule_handle_t anigma_geometry_paths64_t;
typedef anigma_capsule_handle_t anigma_geometry_paths_d_t;

// Enums matching Clipper2
typedef enum {
    ANIGMA_GEOMETRY_FILL_EVEN_ODD = 0,
    ANIGMA_GEOMETRY_FILL_NON_ZERO = 1,
    ANIGMA_GEOMETRY_FILL_POSITIVE = 2,
    ANIGMA_GEOMETRY_FILL_NEGATIVE = 3
} anigma_geometry_fillrule_t;

typedef enum {
    ANIGMA_GEOMETRY_JOIN_SQUARE = 0,
    ANIGMA_GEOMETRY_JOIN_ROUND = 1,
    ANIGMA_GEOMETRY_JOIN_MITER = 2
} anigma_geometry_jointype_t;

typedef enum {
    ANIGMA_GEOMETRY_END_SQUARE = 0,
    ANIGMA_GEOMETRY_END_ROUND = 1,
    ANIGMA_GEOMETRY_END_BUTT = 2,
    ANIGMA_GEOMETRY_END_POLYGON = 3
} anigma_geometry_endtype_t;

// Lifecycle - Paths64
anigma_status_t anigma_geometry_paths64_create(
    anigma_geometry_paths64_t* out_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_paths64_destroy(
    anigma_geometry_paths64_t handle,
    anigma_capsule_error_t* err
);

// Lifecycle - PathsD
anigma_status_t anigma_geometry_paths_d_create(
    anigma_geometry_paths_d_t* out_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_paths_d_destroy(
    anigma_geometry_paths_d_t handle,
    anigma_capsule_error_t* err
);

// Operations - Paths64
anigma_status_t anigma_geometry_paths64_add_path_coords(
    anigma_geometry_paths64_t handle,
    const int64_t* coords,
    size_t count,
    bool closed, // Clipper2 usually assumes paths, but we might want to specify logic
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_paths64_clear(
    anigma_geometry_paths64_t handle,
    anigma_capsule_error_t* err
);

// Boolean Ops - Paths64
anigma_status_t anigma_geometry_intersect_64(
    anigma_geometry_paths64_t subject,
    anigma_geometry_paths64_t clip,
    anigma_geometry_fillrule_t fillrule,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_union_64(
    anigma_geometry_paths64_t subject,
    anigma_geometry_paths64_t clip,
    anigma_geometry_fillrule_t fillrule,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_difference_64(
    anigma_geometry_paths64_t subject,
    anigma_geometry_paths64_t clip,
    anigma_geometry_fillrule_t fillrule,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_xor_64(
    anigma_geometry_paths64_t subject,
    anigma_geometry_paths64_t clip,
    anigma_geometry_fillrule_t fillrule,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
);

// Offsetting - Paths64
anigma_status_t anigma_geometry_inflate_paths_64(
    anigma_geometry_paths64_t paths,
    double delta,
    anigma_geometry_jointype_t jointype,
    anigma_geometry_endtype_t endtype,
    double miter_limit,
    double arc_tolerance,
    anigma_geometry_paths64_t* out_result,
    anigma_capsule_error_t* err
);

// Operations - PathsD
anigma_status_t anigma_geometry_paths_d_add_path_coords(
    anigma_geometry_paths_d_t handle,
    const double* coords,
    size_t count,
    anigma_capsule_error_t* err
);

// Boolean Ops - PathsD
anigma_status_t anigma_geometry_intersect_d(
    anigma_geometry_paths_d_t subject,
    anigma_geometry_paths_d_t clip,
    anigma_geometry_fillrule_t fillrule,
    int precision,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_union_d(
    anigma_geometry_paths_d_t subject,
    anigma_geometry_paths_d_t clip,
    anigma_geometry_fillrule_t fillrule,
    int precision,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_difference_d(
    anigma_geometry_paths_d_t subject,
    anigma_geometry_paths_d_t clip,
    anigma_geometry_fillrule_t fillrule,
    int precision,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_xor_d(
    anigma_geometry_paths_d_t subject,
    anigma_geometry_paths_d_t clip,
    anigma_geometry_fillrule_t fillrule,
    int precision,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
);

// Offsetting - PathsD
anigma_status_t anigma_geometry_inflate_paths_d(
    anigma_geometry_paths_d_t paths,
    double delta,
    anigma_geometry_jointype_t jointype,
    anigma_geometry_endtype_t endtype,
    double miter_limit,
    int precision,
    double arc_tolerance,
    anigma_geometry_paths_d_t* out_result,
    anigma_capsule_error_t* err
);

// Data Access
// Get the number of paths
anigma_status_t anigma_geometry_paths64_count(
    anigma_geometry_paths64_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
);

// Get the number of points in a specific path
anigma_status_t anigma_geometry_paths64_path_count(
    anigma_geometry_paths64_t handle,
    size_t path_index,
    size_t* out_count,
    anigma_capsule_error_t* err
);

// Get points from a path (copies into buffer)
anigma_status_t anigma_geometry_paths64_get_path(
    anigma_geometry_paths64_t handle,
    size_t path_index,
    int64_t* out_coords, // Buffer of size 2 * count
    size_t buffer_size, // In number of int64_t elements
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_paths_d_count(
    anigma_geometry_paths_d_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_paths_d_path_count(
    anigma_geometry_paths_d_t handle,
    size_t path_index,
    size_t* out_count,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_geometry_paths_d_get_path(
    anigma_geometry_paths_d_t handle,
    size_t path_index,
    double* out_coords,
    size_t buffer_size,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif
