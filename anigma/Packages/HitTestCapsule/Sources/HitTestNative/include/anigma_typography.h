#ifndef ANIGMA_TYPOGRAPHY_SHIM_H
#define ANIGMA_TYPOGRAPHY_SHIM_H

#include "anigma_native_common.h"

#if defined(__cplusplus)
extern "C" {
#endif

typedef struct anigma_font_s* anigma_font_t;

/**
 * Create a font handle from font data.
 */
anigma_result_t anigma_font_create(
    anigma_ctx_t* ctx,
    const uint8_t* font_data,
    size_t data_len,
    anigma_font_t* out_handle
);

anigma_result_t anigma_font_destroy(anigma_font_t handle);

/**
 * Shape text into glyphs.
 * Returns arrays of glyph IDs and positions.
 */
anigma_result_t anigma_text_shape(
    anigma_font_t font,
    anigma_ctx_t* ctx,
    const char* text,
    uint32_t* out_glyph_count,
    uint32_t** out_glyph_ids,  // Allocated by shim
    float** out_positions      // Allocated by shim (x, y pairs)
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_TYPOGRAPHY_SHIM_H
