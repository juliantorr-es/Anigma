// glyph_atlas.h
// Native glyph atlas generation interface
// Generates texture atlases from font files

#ifndef GLYPH_ATLAS_H
#define GLYPH_ATLAS_H

#include <stdint.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

// Version
const char* glyph_atlas_version(void);

// Error codes
typedef int32_t glyph_atlas_error_t;
#define GLYPH_ATLAS_SUCCESS 0
#define GLYPH_ATLAS_ERROR_NULL_POINTER 1
#define GLYPH_ATLAS_ERROR_INVALID_FONT 2
#define GLYPH_ATLAS_ERROR_FONT_NOT_FOUND 3
#define GLYPH_ATLAS_ERROR_MEMORY_ALLOCATION 4
#define GLYPH_ATLAS_ERROR_INVALID_SIZE 5
#define GLYPH_ATLAS_ERROR_PACKING_FAILED 6
#define GLYPH_ATLAS_ERROR_NOT_INITIALIZED 7

// Glyph metrics
typedef struct {
    uint32_t codepoint;
    int32_t x;          // Position in atlas
    int32_t y;
    uint32_t width;
    uint32_t height;
    float advance_x;    // Glyph advance
    int32_t offset_x;   // Bearing/offset
    int32_t offset_y;
} glyph_metrics_t;

// Shaped glyph (from HarfBuzz)
typedef struct {
    uint32_t index;
    uint32_t codepoint;
    uint32_t glyph_id;
    uint32_t cluster;
    int32_t x_advance;
    int32_t y_advance;
    int32_t x_offset;
    int32_t y_offset;
} glyph_atlas_shaped_glyph_t;

// Atlas metrics
typedef struct {
    uint32_t atlas_width;
    uint32_t atlas_height;
    uint32_t glyph_count;
    uint8_t* bitmap_data;  // Grayscale bitmap
    uint64_t bitmap_size;
} atlas_metrics_t;

// Atlas handle (opaque)
typedef struct glyph_atlas_handle* glyph_atlas_t;

// Create a new glyph atlas
glyph_atlas_error_t glyph_atlas_create(
    const char* font_name,
    uint32_t font_size,
    glyph_atlas_t* atlas
);

// Load a glyph atlas from a font file path
glyph_atlas_error_t glyph_atlas_create_from_file(
    const uint8_t* font_data,
    uint64_t font_data_size,
    uint32_t font_size,
    glyph_atlas_t* atlas
);

// Add codepoints to the atlas
glyph_atlas_error_t glyph_atlas_add_codepoints(
    glyph_atlas_t atlas,
    const uint32_t* codepoints,
    uint32_t count
);

// Generate the atlas (pack glyphs into texture)
glyph_atlas_error_t glyph_atlas_generate(
    glyph_atlas_t atlas,
    uint32_t atlas_width,
    uint32_t atlas_height
);

// Get glyph metrics for a codepoint
glyph_atlas_error_t glyph_atlas_get_glyph(
    glyph_atlas_t atlas,
    uint32_t codepoint,
    glyph_metrics_t* metrics
);

// Get all glyph metrics
glyph_atlas_error_t glyph_atlas_get_all_glyphs(
    glyph_atlas_t atlas,
    glyph_metrics_t** metrics,
    uint32_t* count
);

// Get atlas bitmap data
glyph_atlas_error_t glyph_atlas_get_bitmap(
    glyph_atlas_t atlas,
    uint8_t** bitmap_data,
    uint32_t* width,
    uint32_t* height
);

// Shape text using HarfBuzz
glyph_atlas_error_t glyph_atlas_shape_text(
    const char* text,
    const char* font_path,
    uint32_t font_size,
    glyph_atlas_shaped_glyph_t** shaped_glyphs,
    uint32_t* count
);

// Destroy the atlas
void glyph_atlas_destroy(glyph_atlas_t atlas);

// Free allocated memory
void glyph_atlas_free(void* data);

#ifdef __cplusplus
}
#endif

#endif // GLYPH_ATLAS_H
