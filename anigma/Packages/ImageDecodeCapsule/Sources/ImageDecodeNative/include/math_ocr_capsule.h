/**
 * MathOCRCapsule - C++ compute capsule for mathematical equation recognition
 *
 * This capsule provides high-performance equation recognition from PDF documents
 * using advanced OCR algorithms and optional ML models.
 *
 * Architecture: "Swift governs, C++ computes"
 * Determinism Tier: Tier 2 (epsilon-stable)
 */

#ifndef ANIGMA_MATH_OCR_CAPSULE_H
#define ANIGMA_MATH_OCR_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Equation bounding box representation
 */
struct anigma_equation_bbox_t {
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
 * Mathematical symbol representation
 */
struct anigma_math_symbol_t {
    /** Symbol text (LaTeX or Unicode) */
    const char* text;
    /** Text length */
    size_t text_len;
    /** Bounding box */
    struct anigma_equation_bbox_t bbox;
    /** Symbol type (operator, variable, function, etc.) */
    int32_t symbol_type;
    /** Confidence score (0-1) */
    float confidence;
};

/**
 * Mathematical equation representation
 */
struct anigma_equation_t {
    /** Equation ID */
    const char* equation_id;
    /** Equation ID length */
    size_t equation_id_len;
    /** LaTeX representation */
    const char* latex;
    /** LaTeX length */
    size_t latex_len;
    /** Unicode representation */
    const char* unicode;
    /** Unicode length */
    size_t unicode_len;
    /** Symbols in the equation */
    struct anigma_math_symbol_t* symbols;
    /** Number of symbols */
    size_t symbol_count;
    /** Bounding box */
    struct anigma_equation_bbox_t bbox;
    /** Page index */
    int32_t page_index;
    /** Confidence score (0-1) */
    float confidence;
    /** Equation type (inline, display, etc.) */
    int32_t equation_type;
};

/**
 * Equation recognition result
 */
struct anigma_equation_recognition_result_t {
    /** Recognized equations */
    struct anigma_equation_t* equations;
    /** Number of equations */
    size_t equation_count;
    /** Total processing time in microseconds */
    uint64_t processing_time_us;
};

/**
 * Equation recognition configuration
 */
struct anigma_equation_recognition_config_t {
    /** Enable ML-based recognition (requires ONNX Runtime) */
    bool enable_ml_recognition;
    /** Minimum equation area (in points²) */
    double min_equation_area;
    /** Enable symbol-level recognition */
    bool enable_symbol_recognition;
    /** Enable LaTeX generation */
    bool enable_latex_generation;
    /** Enable Unicode generation */
    bool enable_unicode_generation;
    /** ONNX model path (optional) */
    const char* onnx_model_path;
    /** Custom symbol dictionary path (optional) */
    const char* symbol_dict_path;
};

/**
 * Default equation recognition configuration
 */
anigma_status_t anigma_equation_recognition_get_default_config(
    struct anigma_equation_recognition_config_t* out_config
);

/**
 * Create equation recognition capsule context
 *
 * @param config Equation recognition configuration
 * @param out_handle Output capsule handle
 * @return Status code
 */
anigma_status_t anigma_equation_recognition_capsule_create(
    const struct anigma_equation_recognition_config_t* config,
    anigma_capsule_handle_t* out_handle
);

/**
 * Destroy equation recognition capsule context
 *
 * @param handle Capsule handle
 * @return Status code
 */
anigma_status_t anigma_equation_recognition_capsule_destroy(
    anigma_capsule_handle_t handle
);

/**
 * Recognize equations from PDF page layout
 *
 * @param handle Capsule handle
 * @param page_index Page index
 * @param segments Text segments from layout engine
 * @param segment_count Number of segments
 * @param page_width Page width in points
 * @param page_height Page height in points
 * @param out_result Output equation recognition result
 * @return Status code
 */
anigma_status_t anigma_equation_recognition_extract_from_segments(
    anigma_capsule_handle_t handle,
    int32_t page_index,
    const struct anigma_layout_segment_t* segments,
    size_t segment_count,
    double page_width,
    double page_height,
    struct anigma_equation_recognition_result_t* out_result
);

/**
 * Recognize equations from PDF document
 *
 * @param handle Capsule handle
 * @param pdf_data PDF document data
 * @param pdf_size PDF document size
 * @param out_result Output equation recognition result
 * @return Status code
 */
anigma_status_t anigma_equation_recognition_extract_from_pdf(
    anigma_capsule_handle_t handle,
    const uint8_t* pdf_data,
    size_t pdf_size,
    struct anigma_equation_recognition_result_t* out_result
);

/**
 * Free equation recognition result
 *
 * @param result Equation recognition result to free
 * @return Status code
 */
anigma_status_t anigma_equation_recognition_free_result(
    struct anigma_equation_recognition_result_t* result
);

/**
 * Export equation to LaTeX
 *
 * @param equation Equation to export
 * @param out_latex Output LaTeX string
 * @param out_latex_len Output LaTeX length
 * @return Status code
 */
anigma_status_t anigma_equation_export_to_latex(
    const struct anigma_equation_t* equation,
    const char** out_latex,
    size_t* out_latex_len
);

/**
 * Export equation to Unicode
 *
 * @param equation Equation to export
 * @param out_unicode Output Unicode string
 * @param out_unicode_len Output Unicode length
 * @return Status code
 */
anigma_status_t anigma_equation_export_to_unicode(
    const struct anigma_equation_t* equation,
    const char** out_unicode,
    size_t* out_unicode_len
);

/**
 * Export equation to MathML
 *
 * @param equation Equation to export
 * @param out_mathml Output MathML string
 * @param out_mathml_len Output MathML length
 * @return Status code
 */
anigma_status_t anigma_equation_export_to_mathml(
    const struct anigma_equation_t* equation,
    const char** out_mathml,
    size_t* out_mathml_len
);

/**
 * Free exported data
 *
 * @param data Data to free
 * @return Status code
 */
anigma_status_t anigma_equation_free_export(
    const char* data
);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_MATH_OCR_CAPSULE_H
