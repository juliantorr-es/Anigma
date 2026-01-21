#include "anigma_render.h"
#include <stdlib.h>
#include <string.h>

struct anigma_renderer_s {
    int dummy_state;
};

anigma_result_t anigma_renderer_create(
    anigma_ctx_t* ctx,
    anigma_renderer_t* out_handle
) {
    if (!out_handle) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Null handle ptr"};
    
    struct anigma_renderer_s* r = (struct anigma_renderer_s*)malloc(sizeof(struct anigma_renderer_s));
    if (!r) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    
    r->dummy_state = 1;
    *out_handle = r;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_renderer_destroy(anigma_renderer_t handle) {
    if (handle) free(handle);
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
    if (!handle || !ir_data || !out_bitmap) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    // Mock dimensions (e.g., A4 at 72dpi * scale)
    uint32_t w = (uint32_t)(595.0 * scale);
    uint32_t h = (uint32_t)(842.0 * scale);
    size_t size = w * h * 4; // RGBA
    
    uint8_t* buf = (uint8_t*)malloc(size);
    if (!buf) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    
    // Fill with a test color (e.g., semi-transparent blue)
    for (size_t i = 0; i < size; i += 4) {
        buf[i+0] = 0x00; // R
        buf[i+1] = 0x00; // G
        buf[i+2] = 0xFF; // B
        buf[i+3] = 0x80; // A
    }
    
    *out_width = w;
    *out_height = h;
    *out_bitmap = buf;
    *out_bitmap_len = size;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}
