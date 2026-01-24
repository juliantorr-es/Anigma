#ifndef ANIGMA_TEXT_PIPELINE_CAPSULE_H
#define ANIGMA_TEXT_PIPELINE_CAPSULE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef anigma_capsule_handle_t anigma_text_pipeline_capsule_t;

typedef enum {
    ANIGMA_UNICODE_NONE = 0,
    ANIGMA_UNICODE_NFC = 1,
    ANIGMA_UNICODE_NFD = 2,
    ANIGMA_UNICODE_NFKC = 3,
    ANIGMA_UNICODE_NFKD = 4,
    ANIGMA_UNICODE_UNC = 5
} anigma_unicode_form_t;

typedef enum {
    ANIGMA_CASE_NONE = 0,
    ANIGMA_CASE_LOWER = 1,
    ANIGMA_CASE_UPPER = 2,
    ANIGMA_CASE_TITLE = 3,
    ANIGMA_CASE_FOLD = 4
} anigma_case_mode_t;

typedef enum {
    ANIGMA_DIACRITICS_KEEP = 0,
    ANIGMA_DIACRITICS_STRIP = 1,
    ANIGMA_DIACRITICS_NORMALIZE = 2
} anigma_diacritic_mode_t;

typedef enum {
    ANIGMA_BOUNDARY_GRAPHEME = 0,
    ANIGMA_BOUNDARY_WORD = 1,
    ANIGMA_BOUNDARY_SENTENCE = 2,
    ANIGMA_BOUNDARY_LINE = 3
} anigma_text_boundary_type_t;

typedef struct {
    anigma_unicode_form_t unicode_form;
    anigma_case_mode_t case_mode;
    anigma_diacritic_mode_t diacritic_mode;
    uint8_t preserve_whitespace;
    uint8_t preserve_line_breaks;
    uint32_t determinism_tier;
} anigma_text_pipeline_config_t;

typedef struct {
    anigma_text_boundary_type_t type;
    uint64_t offset;
    uint64_t length;
    uint8_t confidence;
} anigma_text_boundary_t;

typedef struct {
    uint8_t* transformed_text;
    size_t transformed_length;
    uint64_t* offset_map;
    size_t offset_map_length;
    anigma_text_boundary_t* boundaries;
    size_t boundary_count;
    uint64_t operation_hash;
    uint64_t processing_time_us;
} anigma_text_result_t;

anigma_capsule_identity_t anigma_text_pipeline_capsule_get_identity(void);
anigma_text_pipeline_config_t anigma_text_pipeline_capsule_get_default_config(void);
anigma_status_t anigma_text_pipeline_capsule_validate_config(const anigma_text_pipeline_config_t* config, anigma_capsule_error_t* err);
anigma_status_t anigma_text_pipeline_capsule_create(const anigma_text_pipeline_config_t* config, anigma_text_pipeline_capsule_t* capsule, anigma_capsule_error_t* err);
anigma_status_t anigma_text_pipeline_capsule_destroy(anigma_text_pipeline_capsule_t capsule, anigma_capsule_error_t* err);
anigma_status_t anigma_text_pipeline_capsule_transform(anigma_text_pipeline_capsule_t capsule, const uint8_t* input_text, size_t input_length, anigma_text_result_t* result, anigma_capsule_error_t* err);
anigma_status_t anigma_text_pipeline_capsule_normalize_unicode(anigma_text_pipeline_capsule_t capsule, const uint8_t* input_text, size_t input_length, anigma_unicode_form_t form, anigma_capsule_buffer_t* output_buffer, anigma_capsule_error_t* err);
anigma_status_t anigma_text_pipeline_capsule_validate_utf8(anigma_text_pipeline_capsule_t capsule, const uint8_t* input_text, size_t input_length, uint8_t* is_valid, anigma_capsule_error_t* err);

#ifdef __cplusplus
}
#endif

#endif
