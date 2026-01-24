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