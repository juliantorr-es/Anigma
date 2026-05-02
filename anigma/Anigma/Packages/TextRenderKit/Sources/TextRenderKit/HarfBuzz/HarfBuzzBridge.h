#ifndef HarfBuzzBridge_h
#define HarfBuzzBridge_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle types
typedef void* hb_face_t;
typedef void* hb_font_t;
typedef void* hb_buffer_t;
typedef void* hb_shape_plan_t;

// Unicode functions
typedef uint32_t hb_codepoint_t;
typedef uint32_t hb_mask_t;

// Direction enum
typedef enum {
    HB_DIRECTION_INVALID = 0,
    HB_DIRECTION_LTR = 4,    /* Left-To-Right */
    HB_DIRECTION_RTL = 5,    /* Right-To-Left */
    HB_DIRECTION_TTB = 6,    /* Top-To-Bottom */
    HB_DIRECTION_BTT = 7     /* Bottom-To-Top */
} hb_direction_t;

// Script enum
typedef enum {
    HB_SCRIPT_INVALID = 0,
    HB_SCRIPT_COMMON = 0x100,
    HB_SCRIPT_LATIN = 0x101,
    HB_SCRIPT_CYRILLIC = 0x102,
    // ... other scripts would be defined here
} hb_script_t;

// Language enum
typedef enum {
    HB_LANGUAGE_INVALID = 0
} hb_language_t;

// Feature enum
typedef enum {
    HB_FEATURE_GLOBAL_START = 0x00010000,
    HB_FEATURE_GLOBAL_END = 0x00020000,
} hb_feature_t;

// Glyph information
typedef struct {
    hb_codepoint_t codepoint;
    hb_mask_t mask;
    uint32_t cluster;
    int32_t var1;
    int32_t var2;
} hb_glyph_info_t;

// Glyph position
typedef struct {
    int32_t x_advance;
    int32_t y_advance;
    int32_t x_offset;
    int32_t y_offset;
    uint32_t var;
} hb_glyph_position_t;

// Initialize HarfBuzz library
bool hb_bridge_init(void);

// Cleanup HarfBuzz library
void hb_bridge_cleanup(void);

// Create a new face from file
hb_face_t hb_bridge_face_create(const char* path, uint32_t index);

// Create a new font from face
hb_font_t hb_bridge_font_create(hb_face_t face);

// Create a new buffer
hb_buffer_t hb_bridge_buffer_create(void);

// Add text to buffer
void hb_bridge_buffer_add_utf8(hb_buffer_t buffer, const char* text, int text_length, uint32_t item_offset, int item_length);

// Set buffer direction
void hb_bridge_buffer_set_direction(hb_buffer_t buffer, hb_direction_t direction);

// Set buffer script
void hb_bridge_buffer_set_script(hb_buffer_t buffer, hb_script_t script);

// Set buffer language
void hb_bridge_buffer_set_language(hb_buffer_t buffer, hb_language_t language);

// Shape text
hb_bool_t hb_bridge_shape(hb_font_t font, hb_buffer_t buffer, const hb_feature_t* features, uint32_t num_features);

// Get glyph count
uint32_t hb_bridge_buffer_get_length(hb_buffer_t buffer);

// Get glyph info
void hb_bridge_buffer_get_glyph_infos(hb_buffer_t buffer, hb_glyph_info_t* infos, uint32_t length);

// Get glyph positions
void hb_bridge_buffer_get_glyph_positions(hb_buffer_t buffer, hb_glyph_position_t* positions, uint32_t length);

// Destroy face
void hb_bridge_face_destroy(hb_face_t face);

// Destroy font
void hb_bridge_font_destroy(hb_font_t font);

// Destroy buffer
void hb_bridge_buffer_destroy(hb_buffer_t buffer);

// Get error message
const char* hb_bridge_get_error_message(void);

#ifdef __cplusplus
}
#endif

#endif /* HarfBuzzBridge_h */
