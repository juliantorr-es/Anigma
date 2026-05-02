#ifndef CLIPPER2_WRAPPER_H
#define CLIPPER2_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/*
 * Clipper2 C ABI Wrapper
 * ======================
 *
 * This header provides a C interface to the Clipper2 library for use in Swift capsules.
 * All functions are thread-safe as long as different threads operate on different opaque
 * handles. Concurrent reads on the same handle are allowed, but concurrent modifications
 * are not.
 *
 * Determinism:
 * - All operations are deterministic; identical inputs produce identical outputs.
 * - The library uses integer arithmetic for 64-bit paths and double precision arithmetic
 *   for floating-point paths with specified precision.
 *
 * Memory Ownership:
 * - Opaque handles (clipper2_paths64_t, clipper2_path64_t, etc.) are allocated by the
 *   library and must be destroyed using the corresponding `_destroy` function.
 * - Handles returned by boolean operations, inflate, and SVG load are newly allocated
 *   and must be destroyed by the caller.
 * - The `clipper2_paths64_get_path` and `clipper2_paths_d_get_path` functions return
 *   a pointer to internal storage of the parent paths object. The returned pointer is
 *   valid only as long as the parent paths object is not modified or destroyed.
 *   The caller must NOT destroy the returned path pointer.
 *
 * Error Handling:
 * - Functions that return a handle indicate failure by returning NULL.
 * - Functions that return a boolean indicate failure by returning false.
 * - The library does not provide detailed error messages; for production use, wrap
 *   with a higher-level error reporting layer.
 *
 * Example usage:
 *   clipper2_paths64_t* subj = clipper2_paths64_create();
 *   clipper2_path64_t* path = clipper2_path64_create();
 *   clipper2_path64_add_point(path, 0, 0);
 *   clipper2_path64_add_point(path, 100, 0);
 *   clipper2_path64_add_point(path, 100, 100);
 *   clipper2_paths64_add_path(subj, path);
 *   clipper2_path64_destroy(path); // path no longer needed
 *
 *   clipper2_paths64_t* clip = clipper2_paths64_create();
 *   ... add clip paths ...
 *
 *   clipper2_paths64_t* result = clipper2_intersect_64(subj, clip, CLIPPER2_FILLRULE_EVEN_ODD);
 *   if (result) {
 *       // process result
 *       clipper2_paths64_destroy(result);
 *   }
 *   clipper2_paths64_destroy(subj);
 *   clipper2_paths64_destroy(clip);
 */

// Forward declarations for opaque pointers
typedef struct clipper2_paths64 clipper2_paths64_t;
typedef struct clipper2_path64 clipper2_path64_t;
typedef struct clipper2_paths_d clipper2_paths_d_t;
typedef struct clipper2_path_d clipper2_path_d_t;
typedef struct clipper2_rect64 clipper2_rect64_t;
typedef struct clipper2_rect_d clipper2_rect_d_t;

// Point structures
typedef struct {
    int64_t x;
    int64_t y;
} clipper2_point64_t;

typedef struct {
    double x;
    double y;
} clipper2_point_d_t;

// Enums
typedef enum {
    CLIPPER2_FILLRULE_EVEN_ODD = 0,
    CLIPPER2_FILLRULE_NON_ZERO = 1,
    CLIPPER2_FILLRULE_POSITIVE = 2,
    CLIPPER2_FILLRULE_NEGATIVE = 3
} clipper2_fillrule_t;

typedef enum {
    CLIPPER2_CLIPTYPE_INTERSECTION = 0,
    CLIPPER2_CLIPTYPE_UNION = 1,
    CLIPPER2_CLIPTYPE_DIFFERENCE = 2,
    CLIPPER2_CLIPTYPE_XOR = 3
} clipper2_cliptype_t;

typedef enum {
    CLIPPER2_JOINTYPE_SQUARE = 0,
    CLIPPER2_JOINTYPE_ROUND = 1,
    CLIPPER2_JOINTYPE_MITER = 2
} clipper2_jointype_t;

typedef enum {
    CLIPPER2_ENDTYPE_SQUARE = 0,
    CLIPPER2_ENDTYPE_ROUND = 1,
    CLIPPER2_ENDTYPE_BUTT = 2,
    CLIPPER2_ENDTYPE_POLYGON = 3
} clipper2_endtype_t;

// Memory management functions
void clipper2_paths64_destroy(clipper2_paths64_t* paths);
void clipper2_path64_destroy(clipper2_path64_t* path);
void clipper2_paths_d_destroy(clipper2_paths_d_t* paths);
void clipper2_path_d_destroy(clipper2_path_d_t* path);

// Creation functions
clipper2_paths64_t* clipper2_paths64_create(void);
clipper2_path64_t* clipper2_path64_create(void);
clipper2_paths_d_t* clipper2_paths_d_create(void);
clipper2_path_d_t* clipper2_path_d_create(void);

// Path operations
void clipper2_path64_add_point(clipper2_path64_t* path, int64_t x, int64_t y);
void clipper2_path_d_add_point(clipper2_path_d_t* path, double x, double y);
void clipper2_paths64_add_path(clipper2_paths64_t* paths, const clipper2_path64_t* path);
void clipper2_paths_d_add_path(clipper2_paths_d_t* paths, const clipper2_path_d_t* path);

// Access functions for paths
size_t clipper2_paths64_size(const clipper2_paths64_t* paths);
size_t clipper2_path64_size(const clipper2_path64_t* path);
clipper2_point64_t clipper2_path64_get_point(const clipper2_path64_t* path, size_t index);
const clipper2_path64_t* clipper2_paths64_get_path(const clipper2_paths64_t* paths, size_t index);

size_t clipper2_paths_d_size(const clipper2_paths_d_t* paths);
size_t clipper2_path_d_size(const clipper2_path_d_t* path);
clipper2_point_d_t clipper2_path_d_get_point(const clipper2_path_d_t* path, size_t index);
const clipper2_path_d_t* clipper2_paths_d_get_path(const clipper2_paths_d_t* paths, size_t index);

// Boolean operations
clipper2_paths64_t* clipper2_intersect_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule
);

clipper2_paths64_t* clipper2_union_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule
);

clipper2_paths64_t* clipper2_difference_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule
);

clipper2_paths64_t* clipper2_xor_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule
);

clipper2_paths_d_t* clipper2_intersect_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision
);

clipper2_paths_d_t* clipper2_union_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision
);

clipper2_paths_d_t* clipper2_difference_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision
);

clipper2_paths_d_t* clipper2_xor_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision
);

// Inflate (offset) operations
clipper2_paths64_t* clipper2_inflate_paths_64(
    const clipper2_paths64_t* paths,
    double delta,
    clipper2_jointype_t jointype,
    clipper2_endtype_t endtype,
    double miter_limit,
    double arc_tolerance
);

clipper2_paths_d_t* clipper2_inflate_paths_d(
    const clipper2_paths_d_t* paths,
    double delta,
    clipper2_jointype_t jointype,
    clipper2_endtype_t endtype,
    double miter_limit,
    int precision,
    double arc_tolerance
);

// SVG import/export
clipper2_paths64_t* clipper2_svg_load_paths64(const char* filename);
clipper2_paths_d_t* clipper2_svg_load_paths_d(const char* filename);
bool clipper2_svg_save_paths64(const char* filename, const clipper2_paths64_t* paths,
    int max_width, int max_height, int margin);
bool clipper2_svg_save_paths_d(const char* filename, const clipper2_paths_d_t* paths,
    int max_width, int max_height, int margin);

#ifdef __cplusplus
}
#endif

#endif /* CLIPPER2_WRAPPER_H */