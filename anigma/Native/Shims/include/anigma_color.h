#ifndef ANIGMA_COLOR_SHIM_H
#define ANIGMA_COLOR_SHIM_H

#include "anigma_native_common.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct anigma_transform_s* anigma_color_transform_t;

/**
 * Create a color transform from source profile to dest profile.
 */
anigma_result_t anigma_transform_create(
    anigma_ctx_t* ctx,
    const uint8_t* src_profile,
    size_t src_len,
    const uint8_t* dst_profile,
    size_t dst_len,
    anigma_color_transform_t* out_handle
);

anigma_result_t anigma_transform_destroy(anigma_color_transform_t handle);

/**
 * Apply transform to pixel buffer in-place.
 */
anigma_result_t anigma_transform_apply(
    anigma_color_transform_t handle,
    anigma_ctx_t* ctx,
    uint8_t* pixels,
    size_t pixel_count,
    uint32_t bytes_per_pixel
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_COLOR_SHIM_H
