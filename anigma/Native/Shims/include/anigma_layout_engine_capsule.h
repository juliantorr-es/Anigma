#ifndef ANIGMA_LAYOUT_ENGINE_CAPSULE_H
#define ANIGMA_LAYOUT_ENGINE_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Layout Engine Capsule Types
// ============================================================================

// Opaque handle for layout engine context
typedef anigma_capsule_handle_t anigma_layout_engine_capsule_t;

// Configuration structure for layout analysis
struct anigma_layout_engine_config_t {
    uint32_t determinism_tier;  // ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    uint32_t flags;             // Analysis flags (e.g., extract_font_metrics, detect_tables)
    size_t max_elements_per_page; // Limit for memory safety
    double merge_text_threshold;   // Distance threshold for merging text segments (in points)
    double table_detection_confidence; // Confidence threshold for table detection (0.0-1.0)
};
typedef struct anigma_layout_engine_config_t anigma_layout_engine_config_t;

// Layout engine flag definitions
#define ANIGMA_LAYOUT_ENGINE_FLAG_EXTRACT_FONT_METRICS   (1u << 0)
#define ANIGMA_LAYOUT_ENGINE_FLAG_DETECT_TABLES          (1u << 1)
#define ANIGMA_LAYOUT_ENGINE_FLAG_DETECT_FIGURES         (1u << 2)
#define ANIGMA_LAYOUT_ENGINE_FLAG_EXTRACT_IMAGES         (1u << 3)
#define ANIGMA_LAYOUT_ENGINE_FLAG_ENABLE_PROFILING       (1u << 4)
#define ANIGMA_LAYOUT_ENGINE_FLAG_PRESERVE_CACHES        (1u << 5)
#define ANIGMA_LAYOUT_ENGINE_FLAG_ENABLE_OCR             (1u << 6)
#define ANIGMA_LAYOUT_ENGINE_FLAG_ADVANCED_FONT_ANALYSIS (1u << 7)
#define ANIGMA_LAYOUT_ENGINE_FLAG_LAYOUT_CLASSIFICATION  (1u << 8)
#define ANIGMA_LAYOUT_ENGINE_FLAG_READING_ORDER_DETECTION (1u << 9)
#define ANIGMA_LAYOUT_ENGINE_FLAG_MULTI_PAGE_ANALYSIS    (1u << 10)

// Profiling statistics structure
struct anigma_layout_engine_profiling_stats_t {
    size_t total_chars_processed;
    size_t total_segments_created;
    size_t total_pages_processed;
    double pdf_load_time_ms;
    double text_extraction_time_ms;
    double spatial_index_build_time_ms;
    double total_analysis_time_ms; // sum of above times
};
typedef struct anigma_layout_engine_profiling_stats_t anigma_layout_engine_profiling_stats_t;

// Bounding box in PDF coordinates (points)
struct anigma_bounding_box_t {
    double left;
    double top;
    double right;
    double bottom;
};
typedef struct anigma_bounding_box_t anigma_bounding_box_t;

// Text segment with styling information
struct anigma_text_segment_t {
    struct anigma_bounding_box_t bbox;
    const char* text;           // UTF-8 null-terminated string (capsule-owned)
    const char* font_name;      // Font name (optional)
    double font_size;           // Font size in points
    uint32_t font_flags;        // Bold, italic, etc.
    uint32_t color_rgb;         // RGB color (0xRRGGBB)
};
typedef struct anigma_text_segment_t anigma_text_segment_t;

// Image data with metadata and raw bytes
struct anigma_image_data_t {
    struct anigma_bounding_box_t bbox;
    uint8_t* raw_data;           // Raw image bytes (capsule-owned)
    size_t raw_data_len;
    unsigned int width;          // Pixels
    unsigned int height;         // Pixels
    float horizontal_dpi;
    float vertical_dpi;
    unsigned int bits_per_pixel;
    int colorspace;              // PDFium colorspace constant
    const char* filter;          // First image filter (e.g., "DCTDecode", "FlateDecode")
};
typedef struct anigma_image_data_t anigma_image_data_t;

// OCR result structure
struct anigma_ocr_result_t {
    struct anigma_bounding_box_t bbox;
    const char* text;           // OCR-extracted text (UTF-8, capsule-owned)
    double confidence;          // Confidence score (0.0-1.0)
    const char* language;       // Detected language (e.g., "eng", "fra")
    uint32_t word_count;        // Number of words in this region
};
typedef struct anigma_ocr_result_t anigma_ocr_result_t;

// Advanced font analysis
struct anigma_font_analysis_t {
    const char* family;         // Font family name with fallback detection
    const char* subfamily;      // Font subfamily (e.g., "Bold", "Italic")
    double size;               // Font size in points
    uint32_t weight;           // Font weight (100-900)
    uint8_t italic;            // 1 if italic detected
    uint8_t bold;              // 1 if bold detected
    uint8_t monospace;         // 1 if monospace detected
    uint8_t serif;             // 1 if serif detected
    uint32_t style_flags;      // Additional style flags
    double x_height;           // X-height ratio (for advanced analysis)
    double cap_height;         // Capital height ratio
    uint32_t color_rgb;        // RGB color
    double contrast_ratio;      // Contrast with background
};
typedef struct anigma_font_analysis_t anigma_font_analysis_t;

// Layout element classification
enum anigma_layout_element_type_t {
    ANIGMA_LAYOUT_ELEMENT_UNKNOWN = 0,
    ANIGMA_LAYOUT_ELEMENT_HEADER = 1,
    ANIGMA_LAYOUT_ELEMENT_PARAGRAPH = 2,
    ANIGMA_LAYOUT_ELEMENT_LIST_ITEM = 3,
    ANIGMA_LAYOUT_ELEMENT_TABLE_CELL = 4,
    ANIGMA_LAYOUT_ELEMENT_CAPTION = 5,
    ANIGMA_LAYOUT_ELEMENT_FOOTER = 6,
    ANIGMA_LAYOUT_ELEMENT_SIDEBAR = 7,
    ANIGMA_LAYOUT_ELEMENT_QUOTE = 8,
    ANIGMA_LAYOUT_ELEMENT_CODE_BLOCK = 9
};
typedef enum anigma_layout_element_type_t anigma_layout_element_type_t;

// Layout element with classification
struct anigma_layout_element_t {
    struct anigma_bounding_box_t bbox;
    anigma_layout_element_type_t type;
    const char* text;           // Element text (capsule-owned)
    double confidence;          // Classification confidence (0.0-1.0)
    uint32_t reading_order;     // Reading order index
    struct anigma_font_analysis_t font; // Font analysis
    uint32_t element_id;        // Unique element ID within page
    uint32_t parent_id;         // Parent element ID (0 if none)
    uint32_t level;             // Hierarchy level (0=root)
};
typedef struct anigma_layout_element_t anigma_layout_element_t;

// Multi-page document structure
struct anigma_document_structure_t {
    uint32_t total_pages;
    uint32_t section_count;
    const char** section_titles;  // Array of section titles (capsule-owned)
    uint32_t* section_start_pages; // Starting page for each section
    uint32_t* element_counts;     // Number of elements per section
    uint8_t has_toc;             // 1 if table of contents detected
    uint8_t has_index;            // 1 if index detected
    uint8_t has_bibliography;     // 1 if bibliography detected
};
typedef struct anigma_document_structure_t anigma_document_structure_t;

// Reading order chain
struct anigma_reading_order_t {
    uint32_t element_count;
    uint32_t* element_ids;        // Elements in reading order (capsule-owned)
    double* confidence_scores;    // Confidence for each ordering (capsule-owned)
    uint32_t* column_breaks;      // Column break indices (capsule-owned)
};
typedef struct anigma_reading_order_t anigma_reading_order_t;

// Page layout analysis result
struct anigma_page_layout_t {
    uint32_t page_index;
    size_t segment_count;
    struct anigma_text_segment_t* segments; // Array of segments (capsule-owned)
    size_t table_count;
    struct anigma_bounding_box_t* table_bboxes; // Array of table bounding boxes
    size_t figure_count;
    struct anigma_bounding_box_t* figure_bboxes; // Array of figure bounding boxes
    size_t image_count;
    struct anigma_image_data_t* images; // Array of image data (capsule-owned)
    
    // Advanced features
    size_t ocr_result_count;
    struct anigma_ocr_result_t* ocr_results; // OCR results (capsule-owned)
    size_t element_count;
    struct anigma_layout_element_t* elements; // Classified layout elements (capsule-owned)
    struct anigma_reading_order_t reading_order; // Reading order information
};
typedef struct anigma_page_layout_t anigma_page_layout_t;

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get layout engine capsule identity.
 */
anigma_capsule_identity_t anigma_layout_engine_capsule_get_identity(void);

/**
 * Create a layout engine capsule context with given configuration.
 */
anigma_status_t anigma_layout_engine_capsule_create(
    const struct anigma_layout_engine_config_t* config,
    anigma_layout_engine_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a layout engine capsule context.
 */
anigma_status_t anigma_layout_engine_capsule_destroy(
    anigma_layout_engine_capsule_t handle,
    anigma_capsule_error_t* err
);

/**
 * Reset layout engine capsule context, clearing document-specific state
 * but preserving configuration and optionally caches.
 *
 * @param handle Capsule handle
 * @param preserve_caches If non-zero, preserve font name cache across resets
 * @param err Error output
 *
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_layout_engine_capsule_reset(
    anigma_layout_engine_capsule_t handle,
    int preserve_caches,
    anigma_capsule_error_t* err
);

// ============================================================================
// Layout Analysis Functions
// ============================================================================

/**
 * Analyze PDF data and extract layout information.
 * Uses two-phase buffer fill pattern for variable-sized output.
 * 
 * Phase 1: Call with out_layout = NULL to get required size (in err->aux)
 * Phase 2: Allocate buffer and call again
 * 
 * @param handle Capsule handle
 * @param pdf_data Input PDF data
 * @param pdf_data_len Length of PDF data
 * @param out_layout Output layout structure (caller-allocated)
 * @param max_pages Maximum number of pages that can be stored
 * @param out_actual Actual number of pages analyzed
 * @param err Error output
 * 
 * @return ANIGMA_OK on success, ANIGMA_ERR_BUFFER_TOO_SMALL if buffer too small
 */
anigma_status_t anigma_layout_engine_capsule_analyze_pdf(
    anigma_layout_engine_capsule_t handle,
    const uint8_t* pdf_data,
    size_t pdf_data_len,
    struct anigma_page_layout_t* out_layout,
    size_t max_pages,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Free layout analysis results allocated by the capsule.
 * Must be called after processing the layout data to release memory.
 */
anigma_status_t anigma_layout_engine_capsule_free_layout(
    anigma_layout_engine_capsule_t handle,
    struct anigma_page_layout_t* layout,
    anigma_capsule_error_t* err
);

/**
 * Get spatial index for a page (R-tree for efficient spatial queries).
 * Returns a handle to an internal spatial index that can be used for queries.
 * The index is owned by the capsule and valid until the capsule is destroyed
 * or the page layout is freed.
 */
anigma_status_t anigma_layout_engine_capsule_get_spatial_index(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    void** out_index_handle,
    anigma_capsule_error_t* err
);

/**
 * Query elements within a bounding box using spatial index.
 */
anigma_status_t anigma_layout_engine_capsule_query_bbox(
    anigma_layout_engine_capsule_t handle,
    void* index_handle,
    const struct anigma_bounding_box_t* bbox,
    uint32_t* out_element_indices,
    size_t max_elements,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Get profiling statistics for the layout engine capsule.
 * Statistics are cumulative across all PDF analyses performed with this handle.
 * If profiling flag is not enabled, values may be zero.
 */
anigma_status_t anigma_layout_engine_capsule_get_profiling_stats(
    anigma_layout_engine_capsule_t handle,
    struct anigma_layout_engine_profiling_stats_t* out_stats,
    anigma_capsule_error_t* err
);

// ============================================================================
// Advanced Features API
// ============================================================================

/**
 * Perform OCR analysis on a page.
 * Requires ANIGMA_LAYOUT_ENGINE_FLAG_ENABLE_OCR flag.
 * Processes images and non-text regions to extract text using Tesseract.
 */
anigma_status_t anigma_layout_engine_capsule_perform_ocr(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    const char* language,  // ISO 639-3 language code (e.g., "eng", "fra")
    anigma_capsule_error_t* err
);

/**
 * Get OCR results for a page.
 * Returns OCR text regions with confidence scores and language detection.
 */
anigma_status_t anigma_layout_engine_capsule_get_ocr_results(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    struct anigma_ocr_result_t* out_results,
    size_t max_results,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Perform advanced font analysis on text segments.
 * Requires ANIGMA_LAYOUT_ENGINE_FLAG_ADVANCED_FONT_ANALYSIS flag.
 * Enhances font detection with family recognition, style analysis, and metrics.
 */
anigma_status_t anigma_layout_engine_capsule_analyze_fonts(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    anigma_capsule_error_t* err
);

/**
 * Classify layout elements into semantic types.
 * Requires ANIGMA_LAYOUT_ENGINE_FLAG_LAYOUT_CLASSIFICATION flag.
 * Identifies headers, paragraphs, lists, captions, etc.
 */
anigma_status_t anigma_layout_engine_capsule_classify_layout(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    anigma_capsule_error_t* err
);

/**
 * Detect reading order for layout elements.
 * Requires ANIGMA_LAYOUT_ENGINE_FLAG_READING_ORDER_DETECTION flag.
 * Determines natural reading flow for complex multi-column layouts.
 */
anigma_status_t anigma_layout_engine_capsule_detect_reading_order(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    anigma_capsule_error_t* err
);

/**
 * Analyze multi-page document structure.
 * Requires ANIGMA_LAYOUT_ENGINE_FLAG_MULTI_PAGE_ANALYSIS flag.
 * Detects sections, table of contents, and document hierarchy.
 */
anigma_status_t anigma_layout_engine_capsule_analyze_document_structure(
    anigma_layout_engine_capsule_t handle,
    struct anigma_document_structure_t* out_structure,
    anigma_capsule_error_t* err
);

/**
 * Get classified layout elements for a page.
 * Returns semantic layout elements with font analysis and reading order.
 */
anigma_status_t anigma_layout_engine_capsule_get_layout_elements(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    struct anigma_layout_element_t* out_elements,
    size_t max_elements,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Get reading order information for a page.
 * Returns the reading sequence of elements with confidence scores.
 */
anigma_status_t anigma_layout_engine_capsule_get_reading_order(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    struct anigma_reading_order_t* out_order,
    anigma_capsule_error_t* err
);

/**
 * Validate OCR accuracy against ground truth.
 * Used for testing and quality assurance.
 */
anigma_status_t anigma_layout_engine_capsule_validate_ocr_accuracy(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    const char* ground_truth_text,
    double* out_character_accuracy,
    double* out_word_accuracy,
    anigma_capsule_error_t* err
);

// ============================================================================
// Configuration and Utility Functions
// ============================================================================

/**
 * Get default configuration.
 */
struct anigma_layout_engine_config_t anigma_layout_engine_capsule_get_default_config(void);

/**
 * Validate configuration parameters.
 */
anigma_status_t anigma_layout_engine_capsule_validate_config(
    const struct anigma_layout_engine_config_t* config,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_LAYOUT_ENGINE_CAPSULE_H