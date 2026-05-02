#ifndef HARFBUZZ_WRAPPER_H
#define HARFBUZZ_WRAPPER_H

// Use minimal declarations instead of full system headers
#include "harfbuzz_minimal.h"

// Function declarations for HarfBuzz API
#ifdef __cplusplus
extern "C" {
#endif

// Basic HarfBuzz functions
hb_font_t* hb_bridge_font_create(hb_face_t* face);
void hb_bridge_font_destroy(hb_font_t* font);

hb_face_t* hb_bridge_face_create(const char* fontPath, unsigned int index);
void hb_bridge_face_destroy(hb_face_t* face);

hb_buffer_t* hb_bridge_buffer_create(void);
void hb_bridge_buffer_destroy(hb_buffer_t* buffer);

void hb_bridge_buffer_add_utf8(hb_buffer_t* buffer, const char* text, int text_length, unsigned int item_offset, int item_length);
void hb_bridge_buffer_guess_segment_properties(hb_buffer_t* buffer);
void hb_bridge_buffer_set_language(hb_buffer_t* buffer, hb_language_t language);
void hb_bridge_buffer_set_direction(hb_buffer_t* buffer, hb_direction_t direction);
void hb_bridge_buffer_set_script(hb_buffer_t* buffer, hb_script_t script);

hb_bool_t hb_bridge_shape(hb_font_t* font, hb_buffer_t* buffer, const hb_feature_t* features, unsigned int num_features);

unsigned int hb_bridge_buffer_get_length(hb_buffer_t* buffer);
// Get pointers to internal glyph data
const struct hb_glyph_info_t* hb_bridge_buffer_get_glyph_infos(hb_buffer_t* buffer, unsigned int* length);
const struct hb_glyph_position_t* hb_bridge_buffer_get_glyph_positions(hb_buffer_t* buffer, unsigned int* length);

// Initialization and cleanup
hb_bool_t hb_bridge_init(void);
void hb_bridge_cleanup(void);

// Error handling
const char* hb_bridge_get_error_message(void);

#ifdef __cplusplus
}
#endif

#endif /* HARFBUZZ_WRAPPER_H */
