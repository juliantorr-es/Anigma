#include "anigma_render.h"

#include <stdlib.h>

struct anigma_renderer_s {
    int dummy_state;
};

extern "C" {

anigma_result_t anigma_renderer_create(
    anigma_ctx_t* ctx,
    anigma_renderer_t* out_handle
) {
    (void)ctx;
    if (!out_handle) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Null handle ptr"};
    }

    struct anigma_renderer_s* renderer =
        static_cast<struct anigma_renderer_s*>(malloc(sizeof(struct anigma_renderer_s)));
    if (!renderer) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    }

    renderer->dummy_state = 1;
    *out_handle = renderer;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_renderer_destroy(anigma_renderer_t handle) {
    if (handle) {
        free(handle);
    }
    return (anigma_result_t){ANIGMA_OK, NULL};
}

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
) {
    (void)ctx;
    (void)ir_len;
    if (!handle || !ir_data || !out_width || !out_height || !out_bitmap || !out_bitmap_len) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    }

    uint32_t width = static_cast<uint32_t>(595.0 * scale);
    uint32_t height = static_cast<uint32_t>(842.0 * scale);
    size_t bitmap_size = static_cast<size_t>(width) * static_cast<size_t>(height) * 4;

    uint8_t* bitmap = static_cast<uint8_t*>(malloc(bitmap_size));
    if (!bitmap) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    }

    for (size_t i = 0; i < bitmap_size; i += 4) {
        bitmap[i + 0] = 0x00;
        bitmap[i + 1] = 0x00;
        bitmap[i + 2] = 0xFF;
        bitmap[i + 3] = 0x80;
    }

    *out_width = width;
    *out_height = height;
    *out_bitmap = bitmap;
    *out_bitmap_len = bitmap_size;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

} // extern "C"
