#include "math_ocr_capsule.h"

#include <cstring>
#include <memory>

namespace {
struct EquationRecognitionImpl {
    anigma_equation_recognition_config_t config;

    explicit EquationRecognitionImpl(const anigma_equation_recognition_config_t& cfg) : config(cfg) {}
};
} // namespace

extern "C" {

anigma_status_t anigma_equation_recognition_get_default_config(
    struct anigma_equation_recognition_config_t* out_config
) {
    if (!out_config) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(out_config, 0, sizeof(*out_config));
    out_config->enable_ml_recognition = false;
    out_config->min_equation_area = 100.0;
    out_config->enable_symbol_recognition = true;
    out_config->enable_latex_generation = true;
    out_config->enable_unicode_generation = true;
    out_config->onnx_model_path = nullptr;
    out_config->symbol_dict_path = nullptr;
    return ANIGMA_OK;
}

anigma_status_t anigma_equation_recognition_capsule_create(
    const struct anigma_equation_recognition_config_t* config,
    anigma_capsule_handle_t* out_handle
) {
    if (!out_handle) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    *out_handle = nullptr;

    anigma_equation_recognition_config_t resolved_config{};
    if (config) {
        resolved_config = *config;
    } else {
        anigma_equation_recognition_get_default_config(&resolved_config);
    }

    auto* impl = new EquationRecognitionImpl(resolved_config);
    if (!impl) {
        return ANIGMA_ERR_INTERNAL;
    }

    *out_handle = impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_equation_recognition_capsule_destroy(
    anigma_capsule_handle_t handle
) {
    if (!handle) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    delete static_cast<EquationRecognitionImpl*>(handle);
    return ANIGMA_OK;
}

anigma_status_t anigma_equation_recognition_extract_from_segments(
    anigma_capsule_handle_t handle,
    int32_t page_index,
    const struct anigma_layout_segment_t* segments,
    size_t segment_count,
    double page_width,
    double page_height,
    struct anigma_equation_recognition_result_t* out_result
) {
    if (!handle || !out_result || (segment_count > 0 && !segments)) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    (void)page_index;
    (void)page_width;
    (void)page_height;

    std::memset(out_result, 0, sizeof(*out_result));
    return ANIGMA_OK;
}

anigma_status_t anigma_equation_recognition_extract_from_pdf(
    anigma_capsule_handle_t handle,
    const uint8_t* pdf_data,
    size_t pdf_size,
    struct anigma_equation_recognition_result_t* out_result
) {
    if (!handle || !out_result || (pdf_size > 0 && !pdf_data)) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(out_result, 0, sizeof(*out_result));
    return ANIGMA_OK;
}

anigma_status_t anigma_equation_recognition_free_result(
    struct anigma_equation_recognition_result_t* result
) {
    if (!result) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(result, 0, sizeof(*result));
    return ANIGMA_OK;
}

anigma_status_t anigma_equation_export_to_latex(
    const struct anigma_equation_t* equation,
    const char** out_latex,
    size_t* out_latex_len
) {
    if (!equation || !out_latex || !out_latex_len) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    static const char* empty_latex = "";
    *out_latex = empty_latex;
    *out_latex_len = 0;
    return ANIGMA_OK;
}

anigma_status_t anigma_equation_export_to_unicode(
    const struct anigma_equation_t* equation,
    const char** out_unicode,
    size_t* out_unicode_len
) {
    if (!equation || !out_unicode || !out_unicode_len) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    static const char* empty_unicode = "";
    *out_unicode = empty_unicode;
    *out_unicode_len = 0;
    return ANIGMA_OK;
}

anigma_status_t anigma_equation_export_to_mathml(
    const struct anigma_equation_t* equation,
    const char** out_mathml,
    size_t* out_mathml_len
) {
    if (!equation || !out_mathml || !out_mathml_len) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    static const char* empty_mathml = "";
    *out_mathml = empty_mathml;
    *out_mathml_len = 0;
    return ANIGMA_OK;
}

anigma_status_t anigma_equation_free_export(
    const char* data
) {
    (void)data;
    return ANIGMA_OK;
}

} // extern "C"
