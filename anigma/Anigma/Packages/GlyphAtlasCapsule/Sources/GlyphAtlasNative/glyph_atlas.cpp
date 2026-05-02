// glyph_atlas.cpp
// Native glyph atlas generation implementation
// This is a stub implementation for Phase 1

#include "glyph_atlas.h"
#include <stdlib.h>
#include <math.h>

// Stub implementation for Phase 1
const char* glyph_atlas_version(void) {
    return "1.0.0-stub";
}

// Stub glyph atlas handle
struct glyph_atlas_handle {
    uint32_t font_size;
    bool initialized;
};

// Create a new glyph atlas
glyph_atlas_error_t glyph_atlas_create(
    const char* font_name,
    uint32_t font_size,
    glyph_atlas_t* atlas
) {
    if (!font_name || !atlas) {
        return GLYPH_ATLAS_ERROR_NULL_POINTER;
    }
    
    // Stub: allocate handle
    glyph_atlas_handle* handle = new glyph_atlas_handle{font_size, true};
    *atlas = handle;
    return GLYPH_ATLAS_SUCCESS;
}

// Load a glyph atlas from a font file path
glyph_atlas_error_t glyph_atlas_create_from_file(
    const uint8_t* font_data,
    uint64_t font_data_size,
    uint32_t font_size,
    glyph_atlas_t* atlas
) {
    if (!font_data || !atlas || font_data_size == 0) {
        return GLYPH_ATLAS_ERROR_NULL_POINTER;
    }
    
    // Stub: allocate handle
    glyph_atlas_handle* handle = new glyph_atlas_handle{font_size, true};
    *atlas = handle;
    return GLYPH_ATLAS_SUCCESS;
}

// Add codepoints to the atlas
glyph_atlas_error_t glyph_atlas_add_codepoints(
    glyph_atlas_t atlas,
    const uint32_t* codepoints,
    uint32_t count
) {
    if (!atlas || !codepoints) {
        return GLYPH_ATLAS_ERROR_NULL_POINTER;
    }
    
    // Stub: pretend to add codepoints
    return GLYPH_ATLAS_SUCCESS;
}

// Generate the atlas (pack glyphs into texture)
glyph_atlas_error_t glyph_atlas_generate(
    glyph_atlas_t atlas,
    uint32_t atlas_width,
    uint32_t atlas_height
) {
    if (!atlas || atlas_width == 0 || atlas_height == 0) {
        return GLYPH_ATLAS_ERROR_INVALID_SIZE;
    }
    
    // Stub: pretend to generate atlas
    return GLYPH_ATLAS_SUCCESS;
}

// Get glyph metrics for a codepoint
glyph_atlas_error_t glyph_atlas_get_glyph(
    glyph_atlas_t atlas,
    uint32_t codepoint,
    glyph_metrics_t* metrics
) {
    if (!atlas || !metrics) {
        return GLYPH_ATLAS_ERROR_NULL_POINTER;
    }
    
    // Stub: return dummy metrics
    metrics->codepoint = codepoint;
    metrics->x = 0;
    metrics->y = 0;
    metrics->width = 16;
    metrics->height = 16;
    metrics->advance_x = 8.0f;
    metrics->offset_x = 0;
    metrics->offset_y = 12;
    
    return GLYPH_ATLAS_SUCCESS;
}

// Get all glyph metrics
glyph_atlas_error_t glyph_atlas_get_all_glyphs(
    glyph_atlas_t atlas,
    glyph_metrics_t** metrics,
    uint32_t* count
) {
    if (!atlas || !metrics || !count) {
        return GLYPH_ATLAS_ERROR_NULL_POINTER;
    }
    
    // Stub: return one dummy glyph
    *count = 1;
    *metrics = (glyph_metrics_t*)malloc(sizeof(glyph_metrics_t));
    
    if (*metrics) {
        (*metrics)->codepoint = 65;  // 'A'
        (*metrics)->x = 0;
        (*metrics)->y = 0;
        (*metrics)->width = 16;
        (*metrics)->height = 16;
        (*metrics)->advance_x = 8.0f;
        (*metrics)->offset_x = 0;
        (*metrics)->offset_y = 12;
    }
    
    return GLYPH_ATLAS_SUCCESS;
}

// Get atlas bitmap data
glyph_atlas_error_t glyph_atlas_get_bitmap(
    glyph_atlas_t atlas,
    uint8_t** bitmap_data,
    uint32_t* width,
    uint32_t* height
) {
    if (!atlas || !bitmap_data || !width || !height) {
        return GLYPH_ATLAS_ERROR_NULL_POINTER;
    }
    
    // Stub: return dummy 64x64 grayscale bitmap
    const uint32_t size = 64 * 64;
    *width = 64;
    *height = 64;
    *bitmap_data = (uint8_t*)malloc(size);
    
    if (*bitmap_data) {
        // Create a simple checkerboard pattern
        for (uint32_t y = 0; y < 64; y++) {
            for (uint32_t x = 0; x < 64; x++) {
                (*bitmap_data)[y * 64 + x] = ((x / 8) + (y / 8)) % 2 ? 255 : 0;
            }
        }
    }
    
    return GLYPH_ATLAS_SUCCESS;
}

// Destroy the atlas
void glyph_atlas_destroy(glyph_atlas_t atlas) {
    if (atlas) {
        delete static_cast<glyph_atlas_handle*>(atlas);
    }
}

// Free allocated memory
void glyph_atlas_free(void* data) {
    if (data) {
        free(data);
    }
}