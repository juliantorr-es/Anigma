#ifndef ANIGMA_TEXT_PIPELINE_CAPSULE_H
#define ANIGMA_TEXT_PIPELINE_CAPSULE_H

#include "anigma_capsule_core.h"
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Text pipeline capsule types
typedef anigma_capsule_handle_t anigma_text_pipeline_capsule_t;

// Unicode normalization forms
typedef enum {
    ANIGMA_UNICODE_NONE = 0,          // No normalization
    ANIGMA_UNICODE_NFC = 1,          // Canonical Decomposition + Composition
    ANIGMA_UNICODE_NFD = 2,          // Canonical Decomposition
    ANIGMA_UNICODE_NFKC = 3,         // Compatibility Decomposition + Composition
    ANIGMA_UNICODE_NFKD = 4,         // Compatibility Decomposition
    ANIGMA_UNICODE_UNC = 5          // Unnormalized (raw input)
} anigma_unicode_form_t;

// Case conversion modes
typedef enum {
    ANIGMA_CASE_NONE = 0,            // No case conversion
    ANIGMA_CASE_LOWER = 1,            // Convert to lowercase
    ANIGMA_CASE_UPPER = 2,            // Convert to uppercase
    ANIGMA_CASE_TITLE = 3,            // Convert to titlecase
    ANIGMA_CASE_FOLD = 4             // Case folding (for case-insensitive matching)
} anigma_case_mode_t;

// Diacritic handling modes
typedef enum {
    ANIGMA_DIACRITICS_KEEP = 0,      // Keep all diacritics
    ANIGMA_DIACRITICS_STRIP = 1,     // Remove all diacritics
    ANIGMA_DIACRITICS_NORMALIZE = 2  // Normalize diacritics but keep them
} anigma_diacritic_mode_t;

// Boundary types for segmentation
typedef enum {
    ANIGMA_BOUNDARY_NONE = 0,         // No boundary detection
    ANIGMA_BOUNDARY_GRAPHEME = 1,    // Grapheme cluster boundaries
    ANIGMA_BOUNDARY_WORD = 2,         // Word boundaries
    ANIGMA_BOUNDARY_SENTENCE = 3      // Sentence boundaries
    ANIGMA_BOUNDARY_LINE = 4          // Line break opportunities
} anigma_boundary_type_t;

// Text transformation configuration
typedef struct {
    anigma_unicode_form_t unicode_form;     // Unicode normalization form
    anigma_case_mode_t case_mode;         // Case conversion mode
    anigma_diacritic_mode_t diacritic_mode; // Diacritic handling
    uint8_t preserve_whitespace;          // Preserve original whitespace (0/1)
    uint8_t preserve_line_breaks;         // Preserve original line breaks (0/1)
    uint32_t determinism_tier;            // 1 = bitwise, 2 = epsilon-stable
} anigma_text_pipeline_config_t;

// Boundary information
typedef struct {
    uint64_t offset;                      // Byte offset in original text
    uint64_t length;                      // Length in bytes
    anigma_boundary_type_t type;           // Type of boundary
    uint8_t confidence;                   // Confidence score (0-255)
} anigma_text_boundary_t;

// Text transformation result
typedef struct {
    uint8_t* transformed_text;            // Transformed text bytes
    size_t transformed_length;              // Length of transformed text
    anigma_text_boundary_t* boundaries;     // Array of boundaries
    size_t boundary_count;                 // Number of boundaries
    uint64_t* offset_map;                // Original->transformed offset map
    size_t offset_map_length;              // Length of offset map
    uint64_t operation_hash;               // BLAKE3 hash of inputs for receipt
    uint64_t processing_time_us;           // Processing time in microseconds
} anigma_text_result_t;

// Get capsule identity
anigma_capsule_identity_t anigma_text_pipeline_capsule_get_identity(void);

// Get default configuration
anigma_text_pipeline_config_t anigma_text_pipeline_capsule_get_default_config(void);

// Validate configuration
anigma_status_t anigma_text_pipeline_capsule_validate_config(
    const anigma_text_pipeline_config_t* config,
    anigma_capsule_error_t* error
);

// Create capsule instance
anigma_status_t anigma_text_pipeline_capsule_create(
    const anigma_text_pipeline_config_t* config,
    anigma_text_pipeline_capsule_t** capsule,
    anigma_capsule_error_t* error
);

// Destroy capsule instance
anigma_status_t anigma_text_pipeline_capsule_destroy(
    anigma_text_pipeline_capsule_t* capsule,
    anigma_capsule_error_t* error
);

// Transform text with full pipeline
anigma_status_t anigma_text_pipeline_capsule_transform(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_text_result_t* result,
    anigma_capsule_error_t* error
);

// Unicode normalization only
anigma_status_t anigma_text_pipeline_capsule_normalize_unicode(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_unicode_form_t form,
    anigma_capsule_buffer_t* output_buffer,
    anigma_capsule_error_t* error
);

// Case conversion only
anigma_status_t anigma_text_pipeline_capsule_convert_case(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_case_mode_t mode,
    anigma_capsule_buffer_t* output_buffer,
    anigma_capsule_error_t* error
);

// Diacritic processing
anigma_status_t anigma_text_pipeline_capsule_process_diacritics(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_diacritic_mode_t mode,
    anigma_capsule_buffer_t* output_buffer,
    anigma_capsule_error_t* error
);

// Boundary detection
anigma_status_t anigma_text_pipeline_capsule_detect_boundaries(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_boundary_type_t boundary_type,
    anigma_capsule_buffer_t* output_buffer,  // anigma_text_boundary_t array
    anigma_capsule_error_t* error
);

// Grapheme cluster segmentation
anigma_status_t anigma_text_pipeline_capsule_segment_graphemes(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_capsule_buffer_t* output_buffer,  // anigma_text_boundary_t array
    anigma_capsule_error_t* error
);

// Word boundary detection
anigma_status_t anigma_text_pipeline_capsule_detect_word_boundaries(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_capsule_buffer_t* output_buffer,  // anigma_text_boundary_t array
    anigma_capsule_error_t* error
);

// Sentence boundary detection
anigma_status_t anigma_text_pipeline_capsule_detect_sentence_boundaries(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_capsule_buffer_t* output_buffer,  // anigma_text_boundary_t array
    anigma_capsule_error_t* error
);

// ASCII folding for indexing
anigma_status_t anigma_text_pipeline_capsule_fold_to_ascii(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_capsule_buffer_t* output_buffer,
    anigma_capsule_error_t* error
);

// Create offset map for transformed text
anigma_status_t anigma_text_pipeline_capsule_create_offset_map(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* original_text,
    size_t original_length,
    const uint8_t* transformed_text,
    size_t transformed_length,
    anigma_capsule_buffer_t* output_buffer,  // uint64_t array
    anigma_capsule_error_t* error
);

// Apply text transformation with custom settings
anigma_status_t anigma_text_pipeline_capsule_custom_transform(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    const anigma_text_pipeline_config_t* config,
    anigma_text_result_t* result,
    anigma_capsule_error_t* error
);

// Get transformation receipt (JSON format)
anigma_status_t anigma_text_pipeline_capsule_get_receipt(
    anigma_text_pipeline_capsule_t* capsule,
    anigma_capsule_buffer_t* output_buffer,
    anigma_capsule_error_t* error
);

// Validate UTF-8 encoding
anigma_status_t anigma_text_pipeline_capsule_validate_utf8(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    uint8_t* is_valid,
    anigma_capsule_error_t* error
);

// Estimate text complexity metrics
anigma_status_t anigma_text_pipeline_capsule_get_complexity_metrics(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_capsule_buffer_t* output_buffer,  // JSON formatted metrics
    anigma_capsule_error_t* error
);

// Free result structures
anigma_status_t anigma_text_pipeline_capsule_free_result(
    anigma_text_pipeline_capsule_t* capsule,
    anigma_text_result_t* result,
    anigma_capsule_error_t* error
);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_TEXT_PIPELINE_CAPSULE_H