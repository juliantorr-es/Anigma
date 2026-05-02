/**
 * CitationExtractionCapsule - C++ compute capsule for citation extraction
 *
 * This capsule provides high-performance citation extraction from PDF documents
 * using regex patterns and optional ML models.
 *
 * Architecture: "Swift governs, C++ computes"
 * Determinism Tier: Tier 1 (bitwise identical)
 */

#ifndef ANIGMA_CITATION_EXTRACTION_CAPSULE_H
#define ANIGMA_CITATION_EXTRACTION_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Citation bounding box representation
 */
struct anigma_citation_bbox_t {
    /** Left coordinate */
    double left;
    /** Top coordinate */
    double top;
    /** Right coordinate */
    double right;
    /** Bottom coordinate */
    double bottom;
};

/**
 * Citation reference representation
 */
struct anigma_citation_reference_t {
    /** Reference ID */
    const char* reference_id;
    /** Reference ID length */
    size_t reference_id_len;
    /** Author names */
    const char* authors;
    /** Authors length */
    size_t authors_len;
    /** Publication year */
    const char* year;
    /** Year length */
    size_t year_len;
    /** Title */
    const char* title;
    /** Title length */
    size_t title_len;
    /** Journal/conference name */
    const char* venue;
    /** Venue length */
    size_t venue_len;
    /** Pages */
    const char* pages;
    /** Pages length */
    size_t pages_len;
    /** DOI */
    const char* doi;
    /** DOI length */
    size_t doi_len;
    /** Bounding box */
    struct anigma_citation_bbox_t bbox;
    /** Confidence score (0-1) */
    float confidence;
};

/**
 * Inline citation representation
 */
struct anigma_inline_citation_t {
    /** Citation text */
    const char* text;
    /** Text length */
    size_t text_len;
    /** Reference ID */
    const char* reference_id;
    /** Reference ID length */
    size_t reference_id_len;
    /** Bounding box */
    struct anigma_citation_bbox_t bbox;
    /** Confidence score (0-1) */
    float confidence;
};

/**
 * Citation extraction result
 */
struct anigma_citation_extraction_result_t {
    /** Extracted references */
    struct anigma_citation_reference_t* references;
    /** Number of references */
    size_t reference_count;
    /** Inline citations */
    struct anigma_inline_citation_t* inline_citations;
    /** Number of inline citations */
    size_t inline_citation_count;
    /** Total processing time in microseconds */
    uint64_t processing_time_us;
};

/**
 * Citation extraction configuration
 */
struct anigma_citation_extraction_config_t {
    /** Enable ML-based extraction (requires ONNX Runtime) */
    bool enable_ml_extraction;
    /** Enable regex-based extraction */
    bool enable_regex_extraction;
    /** Enable reference section detection */
    bool enable_reference_section_detection;
    /** Enable inline citation detection */
    bool enable_inline_citation_detection;
    /** ONNX model path (optional) */
    const char* onnx_model_path;
    /** Custom regex patterns path (optional) */
    const char* regex_patterns_path;
};

/**
 * Default citation extraction configuration
 */
anigma_status_t anigma_citation_extraction_get_default_config(
    struct anigma_citation_extraction_config_t* out_config
);

/**
 * Create citation extraction capsule context
 *
 * @param config Citation extraction configuration
 * @param out_handle Output capsule handle
 * @return Status code
 */
anigma_status_t anigma_citation_extraction_capsule_create(
    const struct anigma_citation_extraction_config_t* config,
    anigma_capsule_handle_t* out_handle
);

/**
 * Destroy citation extraction capsule context
 *
 * @param handle Capsule handle
 * @return Status code
 */
anigma_status_t anigma_citation_extraction_capsule_destroy(
    anigma_capsule_handle_t handle
);

/**
 * Extract citations from PDF page layout
 *
 * @param handle Capsule handle
 * @param page_index Page index
 * @param segments Text segments from layout engine
 * @param segment_count Number of segments
 * @param page_width Page width in points
 * @param page_height Page height in points
 * @param out_result Output citation extraction result
 * @return Status code
 */
anigma_status_t anigma_citation_extraction_extract_from_segments(
    anigma_capsule_handle_t handle,
    int32_t page_index,
    const struct anigma_layout_segment_t* segments,
    size_t segment_count,
    double page_width,
    double page_height,
    struct anigma_citation_extraction_result_t* out_result
);

/**
 * Extract citations from PDF document
 *
 * @param handle Capsule handle
 * @param pdf_data PDF document data
 * @param pdf_size PDF document size
 * @param out_result Output citation extraction result
 * @return Status code
 */
anigma_status_t anigma_citation_extraction_extract_from_pdf(
    anigma_capsule_handle_t handle,
    const uint8_t* pdf_data,
    size_t pdf_size,
    struct anigma_citation_extraction_result_t* out_result
);

/**
 * Free citation extraction result
 *
 * @param result Citation extraction result to free
 * @return Status code
 */
anigma_status_t anigma_citation_extraction_free_result(
    struct anigma_citation_extraction_result_t* result
);

/**
 * Export reference to BibTeX
 *
 * @param reference Reference to export
 * @param out_bibtex Output BibTeX string
 * @param out_bibtex_len Output BibTeX length
 * @return Status code
 */
anigma_status_t anigma_reference_export_to_bibtex(
    const struct anigma_citation_reference_t* reference,
    const char** out_bibtex,
    size_t* out_bibtex_len
);

/**
 * Export reference to JSON
 *
 * @param reference Reference to export
 * @param out_json Output JSON string
 * @param out_json_len Output JSON length
 * @return Status code
 */
anigma_status_t anigma_reference_export_to_json(
    const struct anigma_citation_reference_t* reference,
    const char** out_json,
    size_t* out_json_len
);

/**
 * Export inline citation to JSON
 *
 * @param citation Inline citation to export
 * @param out_json Output JSON string
 * @param out_json_len Output JSON length
 * @return Status code
 */
anigma_status_t anigma_inline_citation_export_to_json(
    const struct anigma_inline_citation_t* citation,
    const char** out_json,
    size_t* out_json_len
);

/**
 * Free exported data
 *
 * @param data Data to free
 * @return Status code
 */
anigma_status_t anigma_citation_free_export(
    const char* data
);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_CITATION_EXTRACTION_CAPSULE_H
