#ifndef ANIGMA_TEXT_PIPELINE_CAPSULE_H
#define ANIGMA_TEXT_PIPELINE_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Text Pipeline Capsule Types
// ============================================================================

// Opaque handle for text pipeline capsule context
typedef anigma_capsule_handle_t anigma_text_pipeline_capsule_t;

// Language codes (ISO 639-1)
enum anigma_language_t {
    ANIGMA_LANG_UNKNOWN = 0,
    ANIGMA_LANG_EN = 1,
    ANIGMA_LANG_ES = 2,
    ANIGMA_LANG_FR = 3,
    ANIGMA_LANG_DE = 4,
    ANIGMA_LANG_IT = 5,
    ANIGMA_LANG_PT = 6,
    ANIGMA_LANG_RU = 7,
    ANIGMA_LANG_JA = 8,
    ANIGMA_LANG_ZH = 9,
    ANIGMA_LANG_KO = 10,
    ANIGMA_LANG_AR = 11,
    ANIGMA_LANG_HI = 12,
    ANIGMA_LANG_TH = 13,
    ANIGMA_LANG_VI = 14,
    ANIGMA_LANG_TR = 15,
    ANIGMA_LANG_PL = 16,
    ANIGMA_LANG_NL = 17,
    ANIGMA_LANG_SV = 18,
    ANIGMA_LANG_DA = 19,
    ANIGMA_LANG_NO = 20,
    ANIGMA_LANG_FI = 21,
    ANIGMA_LANG_EL = 22,
    ANIGMA_LANG_HE = 23,
    ANIGMA_LANG_CS = 24,
    ANIGMA_LANG_HU = 25,
    ANIGMA_LANG_RO = 26,
    ANIGMA_LANG_BG = 27,
    ANIGMA_LANG_HR = 28,
    ANIGMA_LANG_SK = 29,
    ANIGMA_LANG_SL = 30,
    ANIGMA_LANG_ET = 31,
    ANIGMA_LANG_LT = 32,
    ANIGMA_LANG_LV = 33,
    ANIGMA_LANG_UK = 34,
    ANIGMA_LANG_BE = 35,
    ANIGMA_LANG_SR = 36,
    ANIGMA_LANG_MK = 37,
    ANIGMA_LANG_SQ = 38,
    ANIGMA_LANG_MT = 39,
    ANIGMA_LANG_IS = 40,
    ANIGMA_LANG_GA = 41,
    ANIGMA_LANG_CY = 42,
    ANIGMA_LANG_EU = 43,
    ANIGMA_LANG_CA = 44,
    ANIGMA_LANG_GL = 45,
    ANIGMA_LANG_AST = 46,
    ANIGMA_LANG_LAD = 47,
    ANIGMA_LANG_EXT = 48
};

// Text preprocessing operations
enum anigma_preprocessing_op_t {
    ANIGMA_PREOP_TOKENIZE = 0,
    ANIGMA_PREOP_NORMALIZE = 1,
    ANIGMA_PREOP_LOWERCASE = 2,
    ANIGMA_PREOP_REMOVE_STOPWORDS = 3,
    ANIGMA_PREOP_STEM = 4,
    ANIGMA_PREOP_LEMMATIZE = 5,
    ANIGMA_PREOP_REMOVE_PUNCTUATION = 6,
    ANIGMA_PREOP_REMOVE_NUMBERS = 7,
    ANIGMA_PREOP_REMOVE_WHITESPACE = 8
};

// Sentiment analysis results
struct anigma_sentiment_result_t {
    float positive_score;      // 0.0 to 1.0
    float negative_score;      // 0.0 to 1.0
    float neutral_score;       // 0.0 to 1.0
    float confidence;          // 0.0 to 1.0
};

// Named entity types
enum anigma_entity_type_t {
    ANIGMA_ENTITY_PERSON = 0,
    ANIGMA_ENTITY_ORGANIZATION = 1,
    ANIGMA_ENTITY_LOCATION = 2,
    ANIGMA_ENTITY_DATE = 3,
    ANIGMA_ENTITY_TIME = 4,
    ANIGMA_ENTITY_MONEY = 5,
    ANIGMA_ENTITY_PERCENTAGE = 6,
    ANIGMA_ENTITY_PHONE = 7,
    ANIGMA_ENTITY_EMAIL = 8,
    ANIGMA_ENTITY_URL = 9,
    ANIGMA_ENTITY_MISC = 10
};

// Named entity result
struct anigma_entity_t {
    enum anigma_entity_type_t type;
    const char* text;          // entity text (capsule-allocated)
    size_t start_offset;       // start position in original text
    size_t end_offset;         // end position in original text
    float confidence;          // 0.0 to 1.0
};

// Named entity result array
struct anigma_entities_t {
    struct anigma_entity_t* entities;  // capsule-allocated array
    size_t count;                       // number of entities
};

// Text classification categories
enum anigma_classification_category_t {
    ANIGMA_CATEGORY_NEWS = 0,
    ANIGMA_CATEGORY_BLOG = 1,
    ANIGMA_CATEGORY_SOCIAL_MEDIA = 2,
    ANIGMA_CATEGORY_EMAIL = 3,
    ANIGMA_CATEGORY_REVIEW = 4,
    ANIGMA_CATEGORY_ACADEMIC = 5,
    ANIGMA_CATEGORY_LEGAL = 6,
    ANIGMA_CATEGORY_MEDICAL = 7,
    ANIGMA_CATEGORY_TECHNICAL = 8,
    ANIGMA_CATEGORY_FINANCIAL = 9,
    ANIGMA_CATEGORY_MARKETING = 10,
    ANIGMA_CATEGORY_EDUCATIONAL = 11,
    ANIGMA_CATEGORY_CREATIVE = 12,
    ANIGMA_CATEGORY_PERSONAL = 13,
    ANIGMA_CATEGORY_OTHER = 14
};

// Text classification result
struct anigma_classification_result_t {
    enum anigma_classification_category_t category;
    float confidence;          // 0.0 to 1.0
    float* category_scores;    // capsule-allocated array of scores per category
    size_t category_count;     // number of categories (should be 15)
};

// Token information
struct anigma_token_t {
    const char* text;          // token text (capsule-allocated)
    size_t start_offset;       // start position in original text
    size_t end_offset;         // end position in original text
    const char* pos_tag;       // part-of-speech tag (capsule-allocated)
    const char* lemma;         // lemma form (capsule-allocated)
    float confidence;          // 0.0 to 1.0
};

// Token result array
struct anigma_tokens_t {
    struct anigma_token_t* tokens;     // capsule-allocated array
    size_t count;                      // number of tokens
};

// Pipeline configuration
struct anigma_text_pipeline_config_t {
    bool enable_language_detection;
    bool enable_tokenization;
    bool enable_sentiment_analysis;
    bool enable_ner;
    bool enable_classification;
    bool enable_stemming;
    bool enable_lemmatization;
    bool remove_stopwords;
    bool remove_punctuation;
    enum anigma_language_t default_language;
    uint32_t determinism_tier;         // ANIGMA_DETERMINISM_TIER_* value
};

// Stream handle for processing large texts
typedef anigma_capsule_handle_t anigma_text_stream_t;

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get text pipeline capsule identity.
 * Overrides the weak default implementation.
 */
anigma_capsule_identity_t anigma_text_pipeline_capsule_get_identity(void);

/**
 * Create a text pipeline capsule context with given configuration.
 */
anigma_status_t anigma_text_pipeline_capsule_create(
    const struct anigma_text_pipeline_config_t* config,
    anigma_text_pipeline_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a text pipeline capsule context.
 */
anigma_status_t anigma_text_pipeline_capsule_destroy(
    anigma_text_pipeline_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Text Processing Operations
// ============================================================================

/**
 * Process text with the full pipeline.
 * Uses two-phase buffer fill pattern for outputs.
 */
anigma_status_t anigma_text_pipeline_capsule_process(
    anigma_text_pipeline_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);

/**
 * Detect language of input text.
 */
anigma_status_t anigma_text_pipeline_capsule_detect_language(
    anigma_text_pipeline_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    enum anigma_language_t* out_language,
    float* out_confidence,
    anigma_capsule_error_t* err
);

/**
 * Tokenize input text.
 * Output structure is capsule-allocated.
 */
anigma_status_t anigma_text_pipeline_capsule_tokenize(
    anigma_text_pipeline_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    struct anigma_tokens_t* out_tokens,
    anigma_capsule_error_t* err
);

/**
 * Perform sentiment analysis.
 */
anigma_status_t anigma_text_pipeline_capsule_analyze_sentiment(
    anigma_text_pipeline_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    struct anigma_sentiment_result_t* out_result,
    anigma_capsule_error_t* err
);

/**
 * Extract named entities.
 * Output structure is capsule-allocated.
 */
anigma_status_t anigma_text_pipeline_capsule_extract_entities(
    anigma_text_pipeline_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    struct anigma_entities_t* out_entities,
    anigma_capsule_error_t* err
);

/**
 * Classify text content.
 * Output structure is capsule-allocated.
 */
anigma_status_t anigma_text_pipeline_capsule_classify(
    anigma_text_pipeline_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    struct anigma_classification_result_t* out_result,
    anigma_capsule_error_t* err
);

// ============================================================================
// Streaming API (for Large Texts)
// ============================================================================

/**
 * Begin streaming text processing.
 * Returns a stream handle for subsequent operations.
 */
anigma_status_t anigma_text_pipeline_capsule_begin_stream(
    anigma_text_pipeline_capsule_t handle,
    anigma_text_stream_t* out_stream_handle,
    anigma_capsule_error_t* err
);

/**
 * Process a chunk of text in streaming mode.
 */
anigma_status_t anigma_text_pipeline_capsule_process_stream_chunk(
    anigma_text_stream_t stream_handle,
    const anigma_capsule_buffer_t* chunk,
    anigma_capsule_error_t* err
);

/**
 * End streaming processing and get accumulated results.
 * Uses two-phase buffer fill pattern.
 */
anigma_status_t anigma_text_pipeline_capsule_end_stream(
    anigma_text_stream_t stream_handle,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);

// ============================================================================
// Individual Operations (for fine-grained control)
// ============================================================================

/**
 * Apply preprocessing operations to text.
 */
anigma_status_t anigma_text_pipeline_capsule_preprocess(
    anigma_text_pipeline_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    const enum anigma_preprocessing_op_t* operations,
    size_t operation_count,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);

/**
 * Stem text (reduce words to their root form).
 */
anigma_status_t anigma_text_pipeline_capsule_stem(
    anigma_text_pipeline_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    enum anigma_language_t language,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);

/**
 * Lemmatize text (reduce words to dictionary form).
 */
anigma_status_t anigma_text_pipeline_capsule_lemmatize(
    anigma_text_pipeline_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    enum anigma_language_t language,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Get default pipeline configuration.
 */
struct anigma_text_pipeline_config_t anigma_text_pipeline_capsule_get_default_config(void);

/**
 * Get supported languages.
 * Output array is capsule-allocated.
 */
anigma_status_t anigma_text_pipeline_capsule_get_supported_languages(
    enum anigma_language_t* out_languages,
    size_t* out_count,
    anigma_capsule_error_t* err
);

/**
 * Validate configuration parameters.
 */
anigma_status_t anigma_text_pipeline_capsule_validate_config(
    const struct anigma_text_pipeline_config_t* config,
    anigma_capsule_error_t* err
);

/**
 * Convert language enum to ISO 639-1 code string.
 * Output string is capsule-allocated.
 */
anigma_status_t anigma_text_pipeline_capsule_language_to_code(
    enum anigma_language_t language,
    char** out_iso_code,
    anigma_capsule_error_t* err
);

/**
 * Convert ISO 639-1 code string to language enum.
 */
anigma_status_t anigma_text_pipeline_capsule_code_to_language(
    const char* iso_code,
    enum anigma_language_t* out_language,
    anigma_capsule_error_t* err
);

/**
 * Free capsule-allocated memory for complex structures.
 */
anigma_status_t anigma_text_pipeline_capsule_free_tokens(
    struct anigma_tokens_t* tokens,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_text_pipeline_capsule_free_entities(
    struct anigma_entities_t* entities,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_text_pipeline_capsule_free_classification_result(
    struct anigma_classification_result_t* result,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_TEXT_PIPELINE_CAPSULE_H