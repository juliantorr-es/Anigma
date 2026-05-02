/**
 * TableExtractionCapsule - C++ compute capsule for table extraction
 *
 * This capsule provides high-performance table extraction from PDF documents
 * using advanced algorithms and optional ML models via ONNX Runtime.
 *
 * Architecture: "Swift governs, C++ computes"
 * Determinism Tier: Tier 2 (epsilon-stable)
 */

#ifndef ANIGMA_TABLE_EXTRACTION_CAPSULE_H
#define ANIGMA_TABLE_EXTRACTION_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Table cell representation
 */
struct anigma_table_cell_t {
    /** Cell text content */
    const char* text;
    /** Text length */
    size_t text_len;
    /** Bounding box (left, top, right, bottom) */
    struct {
        double left;
        double top;
        double right;
        double bottom;
    } bbox;
    /** Column index */
    int32_t col_index;
    /** Row index */
    int32_t row_index;
    /** Column span */
    int32_t col_span;
    /** Row span */
    int32_t row_span;
    /** Cell type (header, data, footer) */
    int32_t cell_type;
};

/**
 * Table representation
 */
struct anigma_table_t {
    /** Table cells */
    struct anigma_table_cell_t* cells;
    /** Number of cells */
    size_t cell_count;
    /** Number of columns */
    int32_t col_count;
    /** Number of rows */
    int32_t row_count;
    /** Table bounding box */
    struct {
        double left;
        double top;
        double right;
        double bottom;
    } bbox;
    /** Page index */
    int32_t page_index;
    /** Table confidence score (0-1) */
    float confidence;
};

/**
 * Table extraction result
 */
struct anigma_table_extraction_result_t {
    /** Extracted tables */
    struct anigma_table_t* tables;
    /** Number of tables */
    size_t table_count;
    /** Total processing time in microseconds */
    uint64_t processing_time_us;
};

/**
 * Table extraction configuration
 */
struct anigma_table_extraction_config_t {
    /** Enable ML-based table detection (requires ONNX Runtime) */
    bool enable_ml_detection;
    /** Minimum table area (in points²) */
    double min_table_area;
    /** Maximum table aspect ratio */
    double max_aspect_ratio;
    /** Enable cell merging */
    bool enable_cell_merging;
    /** Enable header detection */
    bool enable_header_detection;
    /** Enable footer detection */
    bool enable_footer_detection;
    /** ONNX model path (optional) */
    const char* onnx_model_path;
};

/**
 * Default table extraction configuration
 */
anigma_status_t anigma_table_extraction_get_default_config(
    struct anigma_table_extraction_config_t* out_config
);

/**
 * Create table extraction capsule context
 *
 * @param config Table extraction configuration
 * @param out_handle Output capsule handle
 * @return Status code
 */
anigma_status_t anigma_table_extraction_capsule_create(
    const struct anigma_table_extraction_config_t* config,
    anigma_capsule_handle_t* out_handle
);

/**
 * Destroy table extraction capsule context
 *
 * @param handle Capsule handle
 * @return Status code
 */
anigma_status_t anigma_table_extraction_capsule_destroy(
    anigma_capsule_handle_t handle
);

/**
 * Extract tables from PDF page layout
 *
 * @param handle Capsule handle
 * @param page_index Page index
 * @param segments Text segments from layout engine
 * @param segment_count Number of segments
 * @param page_width Page width in points
 * @param page_height Page height in points
 * @param out_result Output table extraction result
 * @return Status code
 */
anigma_status_t anigma_table_extraction_extract_from_segments(
    anigma_capsule_handle_t handle,
    int32_t page_index,
    const struct anigma_layout_segment_t* segments,
    size_t segment_count,
    double page_width,
    double page_height,
    struct anigma_table_extraction_result_t* out_result
);

/**
 * Extract tables from PDF document
 *
 * @param handle Capsule handle
 * @param pdf_data PDF document data
 * @param pdf_size PDF document size
 * @param out_result Output table extraction result
 * @return Status code
 */
anigma_status_t anigma_table_extraction_extract_from_pdf(
    anigma_capsule_handle_t handle,
    const uint8_t* pdf_data,
    size_t pdf_size,
    struct anigma_table_extraction_result_t* out_result
);

/**
 * Free table extraction result
 *
 * @param result Table extraction result to free
 * @return Status code
 */
anigma_status_t anigma_table_extraction_free_result(
    struct anigma_table_extraction_result_t* result
);

/**
 * Export table to JSON
 *
 * @param table Table to export
 * @param out_json Output JSON string
 * @param out_json_len Output JSON length
 * @return Status code
 */
anigma_status_t anigma_table_export_to_json(
    const struct anigma_table_t* table,
    const char** out_json,
    size_t* out_json_len
);

/**
 * Export table to CSV
 *
 * @param table Table to export
 * @param out_csv Output CSV string
 * @param out_csv_len Output CSV length
 * @return Status code
 */
anigma_status_t anigma_table_export_to_csv(
    const struct anigma_table_t* table,
    const char** out_csv,
    size_t* out_csv_len
);

/**
 * Free JSON/CSV export
 *
 * @param data Data to free
 * @return Status code
 */
anigma_status_t anigma_table_free_export(
    const char* data
);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_TABLE_EXTRACTION_CAPSULE_H
