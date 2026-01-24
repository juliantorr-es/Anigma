#ifndef ANIGMA_RENDER_SHIM_H
#define ANIGMA_RENDER_SHIM_H

#include "anigma_native_common.h"

#if defined(__cplusplus)
extern "C" {
#endif

// Opaque handle for a renderer instance
typedef struct anigma_renderer_s* anigma_renderer_t;

/**
 * Create a renderer instance.
 */
anigma_result_t anigma_renderer_create(
    anigma_ctx_t* ctx,
    anigma_renderer_t* out_handle
);

/**
 * Destroy a renderer instance.
 */
anigma_result_t anigma_renderer_destroy(anigma_renderer_t handle);

/**
 * Render a page from Document IR to a bitmap buffer (RGBA).
 *
 * @param ir_data Pointer to the serialized IR data.
 * @param scale Scaling factor (e.g. 1.0 = 72 DPI, 2.0 = 144 DPI).
 * @param out_width Output width in pixels.
 * @param out_height Output height in pixels.
 * @param out_bitmap Output buffer (RGBA8888), allocated by shim.
 */
anigma_result_t anigma_renderer_render_bitmap(
    anigma_renderer_t handle,
    anigma_ctx_t* ctx,
    const uint8_t* ir_data,
    size_t ir_len,
    double scale,
    uint32_t* out_width,
    uint32_t* out_height,
    uint8_t** out_bitmap,
    size_t* out_bitmap_len
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_RENDER_SHIM_H
