#include "anigma_animation.h"
#include <stdlib.h>
#include <string.h>

struct anigma_animation_s {
    double time;
};

anigma_result_t anigma_animation_load(
    anigma_ctx_t* ctx,
    const uint8_t* data,
    size_t len,
    anigma_animation_t* out_handle
) {
    if (!data || !out_handle) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    struct anigma_animation_s* a = (struct anigma_animation_s*)malloc(sizeof(struct anigma_animation_s));
    if (!a) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    
    a->time = 0.0;
    *out_handle = a;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_animation_destroy(anigma_animation_t handle) {
    if (handle) free(handle);
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_animation_advance(
    anigma_animation_t handle,
    anigma_ctx_t* ctx,
    double delta_seconds
) {
    if (!handle) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid handle"};
    handle->time += delta_seconds;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_animation_render(
    anigma_animation_t handle,
    anigma_ctx_t* ctx,
    uint32_t width,
    uint32_t height,
    uint8_t** out_bitmap,
    size_t* out_len
) {
    if (!handle || !out_bitmap) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    size_t size = width * height * 4;
    uint8_t* buf = (uint8_t*)malloc(size);
    if (!buf) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    
    // Mock: fill with shifting color based on time
    uint8_t c = (uint8_t)((int)(handle->time * 100) % 255);
    memset(buf, c, size);
    
    *out_bitmap = buf;
    *out_len = size;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}
