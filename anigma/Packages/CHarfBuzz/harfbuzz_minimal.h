#ifndef HARFBUZZ_MINIMAL_H
#define HARFBUZZ_MINIMAL_H

// Minimal HarfBuzz declarations for Swift interop
// This avoids including complex system headers

typedef struct hb_font_t hb_font_t;
typedef struct hb_face_t hb_face_t;
typedef struct hb_buffer_t hb_buffer_t;

// Basic types
typedef unsigned int hb_codepoint_t;
typedef unsigned int hb_position_t;
typedef unsigned int hb_mask_t;
typedef int hb_bool_t;
typedef unsigned int hb_tag_t;
typedef unsigned int hb_script_t;
typedef unsigned int hb_language_t;

typedef enum {
    HB_DIRECTION_INVALID = 0,
    HB_DIRECTION_LTR = 4,
    HB_DIRECTION_RTL = 5,
    HB_DIRECTION_TTB = 6,
    HB_DIRECTION_BTT = 7
} hb_direction_t;

// HarfBuzz constants
#define HB_SCRIPT_INVALID ((hb_script_t) 0)
#define HB_SCRIPT_COMMON ((hb_script_t) 1)
#define HB_SCRIPT_LATIN ((hb_script_t) 2)
#define HB_SCRIPT_CYRILLIC ((hb_script_t) 3)

#define HB_LANGUAGE_INVALID ((hb_language_t) 0)

// FreeType types (forward declarations)
typedef struct FT_FaceRec_* FT_Face;

// Glyph info and position structures
struct hb_glyph_info_t {
    hb_codepoint_t codepoint;
    hb_mask_t mask;
    unsigned int cluster;
    unsigned int var1;
    unsigned int var2;
};

struct hb_glyph_position_t {
    hb_position_t x_advance;
    hb_position_t y_advance;
    hb_position_t x_offset;
    hb_position_t y_offset;
    unsigned int var;
};

// Feature structure
typedef struct {
    hb_tag_t tag;
    unsigned int value;
    unsigned int start;
    unsigned int end;
} hb_feature_t;

#endif /* HARFBUZZ_MINIMAL_H */
