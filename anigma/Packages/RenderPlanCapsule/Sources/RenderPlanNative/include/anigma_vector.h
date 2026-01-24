#ifndef ANIGMA_VECTOR_SHIM_H
#define ANIGMA_VECTOR_SHIM_H

#include "anigma_native_common.h"

#if defined(__cplusplus)
extern "C" {
#endif

typedef enum {
    ANIGMA_OP_UNION,
    ANIGMA_OP_DIFFERENCE,
    ANIGMA_OP_INTERSECTION,
    ANIGMA_OP_XOR
} anigma_path_op_t;

/**
 * Perform a boolean operation on two paths.
 * Paths are expected to be simplified SVG path strings or binary equivalent.
 * For this shim, we'll assume null-terminated strings.
 */
anigma_result_t anigma_path_boolean_op(
    anigma_ctx_t* ctx,
    anigma_path_op_t op,
    const char* path_a,
    const char* path_b,
    char** out_path
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_VECTOR_SHIM_H
