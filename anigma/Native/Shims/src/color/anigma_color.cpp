#include "anigma_color.h"
#include <stdlib.h>

struct anigma_transform_s {
    int mode;
};

anigma_result_t anigma_transform_create(
    anigma_ctx_t* ctx,
    const uint8_t* src_profile,
    size_t src_len,
    const uint8_t* dst_profile,
    size_t dst_len,
    anigma_transform_t* out_handle
) {
    if (!out_handle) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Null handle"};
    struct anigma_transform_s* t = (struct anigma_transform_s*)malloc(sizeof(struct anigma_transform_s));
    t->mode = 0;
    *out_handle = t;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_transform_destroy(anigma_transform_t handle) {
    if (handle) free(handle);
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_transform_apply(
    anigma_transform_t handle,
    anigma_ctx_t* ctx,
    uint8_t* pixels,
    size_t pixel_count,
    uint32_t bytes_per_pixel
) {
    if (!handle || !pixels) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    size_t len = pixel_count * bytes_per_pixel;
    for (size_t i = 0; i < len; i++) {
        pixels[i] = 255 - pixels[i];
    }
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}
