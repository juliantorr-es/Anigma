#ifndef ANIGMA_ANIMATION_SHIM_H
#define ANIGMA_ANIMATION_SHIM_H

#include "anigma_native_common.h"

#if defined(__cplusplus)
extern "C" {
#endif

typedef struct anigma_animation_s* anigma_animation_t;

/**
 * Load an animation from data (Rive/Lottie/Skottie).
 */
anigma_result_t anigma_animation_load(
    anigma_ctx_t* ctx,
    const uint8_t* data,
    size_t len,
    anigma_animation_t* out_handle
);

anigma_result_t anigma_animation_destroy(anigma_animation_t handle);

/**
 * Advance animation state.
 */
anigma_result_t anigma_animation_advance(
    anigma_animation_t handle,
    anigma_ctx_t* ctx,
    double delta_seconds
);

/**
 * Render current frame to buffer.
 */
anigma_result_t anigma_animation_render(
    anigma_animation_t handle,
    anigma_ctx_t* ctx,
    uint32_t width,
    uint32_t height,
    uint8_t** out_bitmap,
    size_t* out_len
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_ANIMATION_SHIM_H
