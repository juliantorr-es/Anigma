#include "anigma_typography.h"
#include <stdlib.h>
#include <string.h>

struct anigma_font_s {
    int id;
};

anigma_result_t anigma_font_create(
    anigma_ctx_t* ctx,
    const uint8_t* font_data,
    size_t data_len,
    anigma_font_t* out_handle
) {
    if (!out_handle) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Null handle"};
    struct anigma_font_s* f = (struct anigma_font_s*)malloc(sizeof(struct anigma_font_s));
    if (!f) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    f->id = 123;
    *out_handle = f;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_font_destroy(anigma_font_t handle) {
    if (handle) free(handle);
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_text_shape(
    anigma_font_t font,
    anigma_ctx_t* ctx,
    const char* text,
    uint32_t* out_glyph_count,
    uint32_t** out_glyph_ids,
    float** out_positions
) {
    if (!font || !text || !out_glyph_count) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    size_t len = strlen(text);
    uint32_t count = (uint32_t)len;
    
    uint32_t* g_ids = (uint32_t*)malloc(count * sizeof(uint32_t));
    float* g_pos = (float*)malloc(count * 2 * sizeof(float));
    
    if (!g_ids || !g_pos) {
        if (g_ids) free(g_ids);
        if (g_pos) free(g_pos);
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    }
    
    for (uint32_t i = 0; i < count; i++) {
        g_ids[i] = (uint32_t)text[i];
        g_pos[i*2] = i * 10.0f;
        g_pos[i*2+1] = 0.0f;
    }
    
    *out_glyph_count = count;
    *out_glyph_ids = g_ids;
    *out_positions = g_pos;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}
