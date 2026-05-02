#include "harfbuzz_wrapper.h"

#include <stddef.h>
#include <stdio.h>
#include <string.h>

typedef struct FT_LibraryRec_* FT_Library;

// HarfBuzz API surface we need. Declared manually to avoid pulling in the full headers.
extern hb_font_t* hb_font_create(hb_face_t* face);
extern void hb_font_destroy(hb_font_t* font);
extern void hb_font_set_scale(hb_font_t* font, int x_scale, int y_scale);
extern void hb_ft_font_set_funcs(hb_font_t* font);

extern hb_face_t* hb_ft_face_create(FT_Face ft_face, void (*destroy)(FT_Face));
extern void hb_face_destroy(hb_face_t* face);
extern unsigned int hb_face_get_upem(hb_face_t* face);

extern hb_buffer_t* hb_buffer_create(void);
extern void hb_buffer_destroy(hb_buffer_t* buffer);
extern void hb_buffer_add_utf8(hb_buffer_t* buffer, const char* text, int text_length, unsigned int item_offset, int item_length);
extern void hb_buffer_set_direction(hb_buffer_t* buffer, hb_direction_t direction);
extern void hb_buffer_set_language(hb_buffer_t* buffer, hb_language_t language);
extern void hb_buffer_set_script(hb_buffer_t* buffer, hb_script_t script);
extern void hb_buffer_guess_segment_properties(hb_buffer_t* buffer);
extern unsigned int hb_buffer_get_length(hb_buffer_t* buffer);
extern const struct hb_glyph_info_t* hb_buffer_get_glyph_infos(hb_buffer_t* buffer, unsigned int* length);
extern const struct hb_glyph_position_t* hb_buffer_get_glyph_positions(hb_buffer_t* buffer, unsigned int* length);
extern void hb_shape(hb_font_t* font, hb_buffer_t* buffer, const hb_feature_t* features, unsigned int num_features);
extern const char* hb_language_to_string(hb_language_t language);

// FreeType API surface we need. Declared manually to keep the wrapper self-contained.
extern int FT_Init_FreeType(FT_Library* alibrary);
extern int FT_New_Face(FT_Library library, const char* filepathname, long face_index, FT_Face* aface);
extern int FT_Done_Face(FT_Face face);
extern int FT_Done_FreeType(FT_Library library);

static FT_Library g_library = NULL;
static char g_error_message[256] = {0};

static void set_error_message(const char* message) {
    if (message == NULL || message[0] == '\0') {
        g_error_message[0] = '\0';
        return;
    }

    strncpy(g_error_message, message, sizeof(g_error_message) - 1);
    g_error_message[sizeof(g_error_message) - 1] = '\0';
}

static void destroy_ft_face(FT_Face face) {
    if (face != NULL) {
        FT_Done_Face(face);
    }
}

hb_bool_t hb_bridge_init(void) {
    if (g_library != NULL) {
        set_error_message("");
        return 1;
    }

    if (FT_Init_FreeType(&g_library) != 0 || g_library == NULL) {
        g_library = NULL;
        set_error_message("Failed to initialize FreeType");
        return 0;
    }

    set_error_message("");
    return 1;
}

void hb_bridge_cleanup(void) {
    if (g_library != NULL) {
        FT_Done_FreeType(g_library);
        g_library = NULL;
    }
}

const char* hb_bridge_get_error_message(void) {
    return g_error_message[0] != '\0' ? g_error_message : NULL;
}

hb_face_t* hb_bridge_face_create(const char* fontPath, unsigned int index) {
    if (g_library == NULL && !hb_bridge_init()) {
        return NULL;
    }

    FT_Face ftFace = NULL;
    if (FT_New_Face(g_library, fontPath, (long)index, &ftFace) != 0 || ftFace == NULL) {
        set_error_message("Failed to load font face");
        return NULL;
    }

    hb_face_t* face = hb_ft_face_create(ftFace, destroy_ft_face);
    if (face == NULL) {
        FT_Done_Face(ftFace);
        set_error_message("Failed to create HarfBuzz face");
        return NULL;
    }

    return face;
}

void hb_bridge_face_destroy(hb_face_t* face) {
    if (face != NULL) {
        hb_face_destroy(face);
    }
}

hb_font_t* hb_bridge_font_create(hb_face_t* face) {
    if (face == NULL) {
        set_error_message("Missing HarfBuzz face");
        return NULL;
    }

    hb_font_t* font = hb_font_create(face);
    if (font == NULL) {
        set_error_message("Failed to create HarfBuzz font");
        return NULL;
    }

    hb_ft_font_set_funcs(font);
    unsigned int upem = hb_face_get_upem(face);
    if (upem > 0) {
        hb_font_set_scale(font, (int)upem, (int)upem);
    }
    return font;
}

void hb_bridge_font_destroy(hb_font_t* font) {
    if (font != NULL) {
        hb_font_destroy(font);
    }
}

hb_buffer_t* hb_bridge_buffer_create(void) {
    hb_buffer_t* buffer = hb_buffer_create();
    if (buffer == NULL) {
        set_error_message("Failed to create HarfBuzz buffer");
        return NULL;
    }
    return buffer;
}

void hb_bridge_buffer_destroy(hb_buffer_t* buffer) {
    if (buffer != NULL) {
        hb_buffer_destroy(buffer);
    }
}

void hb_bridge_buffer_add_utf8(hb_buffer_t* buffer, const char* text, int text_length, unsigned int item_offset, int item_length) {
    hb_buffer_add_utf8(buffer, text, text_length, item_offset, item_length);
}

void hb_bridge_buffer_guess_segment_properties(hb_buffer_t* buffer) {
    hb_buffer_guess_segment_properties(buffer);
}

void hb_bridge_buffer_set_language(hb_buffer_t* buffer, hb_language_t language) {
    // The Swift wrapper currently uses HB_LANGUAGE_INVALID placeholders.
    // Leave the buffer language untouched for that case.
    if (language != HB_LANGUAGE_INVALID) {
        hb_buffer_set_language(buffer, language);
    }
}

void hb_bridge_buffer_set_direction(hb_buffer_t* buffer, hb_direction_t direction) {
    hb_buffer_set_direction(buffer, direction);
}

void hb_bridge_buffer_set_script(hb_buffer_t* buffer, hb_script_t script) {
    hb_buffer_set_script(buffer, script);
}

hb_bool_t hb_bridge_shape(hb_font_t* font, hb_buffer_t* buffer, const hb_feature_t* features, unsigned int num_features) {
    if (font == NULL || buffer == NULL) {
        set_error_message("Missing HarfBuzz font or buffer");
        return 0;
    }

    hb_shape(font, buffer, features, num_features);
    set_error_message("");
    return 1;
}

unsigned int hb_bridge_buffer_get_length(hb_buffer_t* buffer) {
    return hb_buffer_get_length(buffer);
}

const struct hb_glyph_info_t* hb_bridge_buffer_get_glyph_infos(hb_buffer_t* buffer, unsigned int* length) {
    return hb_buffer_get_glyph_infos(buffer, length);
}

const struct hb_glyph_position_t* hb_bridge_buffer_get_glyph_positions(hb_buffer_t* buffer, unsigned int* length) {
    return hb_buffer_get_glyph_positions(buffer, length);
}
