#include "table_extraction_capsule.h"

#include <cstring>
#include <memory>

namespace {
struct TableExtractionImpl {
    anigma_table_extraction_config_t config;

    explicit TableExtractionImpl(const anigma_table_extraction_config_t& cfg) : config(cfg) {}
};
} // namespace

extern "C" {

anigma_status_t anigma_table_extraction_get_default_config(
    struct anigma_table_extraction_config_t* out_config
) {
    if (!out_config) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(out_config, 0, sizeof(*out_config));
    out_config->enable_ml_detection = false;
    out_config->min_table_area = 1000.0;
    out_config->max_aspect_ratio = 5.0;
    out_config->enable_cell_merging = true;
    out_config->enable_header_detection = true;
    out_config->enable_footer_detection = true;
    out_config->onnx_model_path = nullptr;
    return ANIGMA_OK;
}

anigma_status_t anigma_table_extraction_capsule_create(
    const struct anigma_table_extraction_config_t* config,
    anigma_capsule_handle_t* out_handle
) {
    if (!out_handle) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    *out_handle = nullptr;

    anigma_table_extraction_config_t resolved_config{};
    if (config) {
        resolved_config = *config;
    } else {
        anigma_table_extraction_get_default_config(&resolved_config);
    }

    auto* impl = new TableExtractionImpl(resolved_config);
    if (!impl) {
        return ANIGMA_ERR_INTERNAL;
    }

    *out_handle = impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_table_extraction_capsule_destroy(
    anigma_capsule_handle_t handle
) {
    if (!handle) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    delete static_cast<TableExtractionImpl*>(handle);
    return ANIGMA_OK;
}

anigma_status_t anigma_table_extraction_extract_from_segments(
    anigma_capsule_handle_t handle,
    int32_t page_index,
    const struct anigma_layout_segment_t* segments,
    size_t segment_count,
    double page_width,
    double page_height,
    struct anigma_table_extraction_result_t* out_result
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

anigma_status_t anigma_table_extraction_extract_from_pdf(
    anigma_capsule_handle_t handle,
    const uint8_t* pdf_data,
    size_t pdf_size,
    struct anigma_table_extraction_result_t* out_result
) {
    if (!handle || !out_result || (pdf_size > 0 && !pdf_data)) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(out_result, 0, sizeof(*out_result));
    return ANIGMA_OK;
}

anigma_status_t anigma_table_extraction_free_result(
    struct anigma_table_extraction_result_t* result
) {
    if (!result) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(result, 0, sizeof(*result));
    return ANIGMA_OK;
}

anigma_status_t anigma_table_export_to_json(
    const struct anigma_table_t* table,
    const char** out_json,
    size_t* out_json_len
) {
    if (!table || !out_json || !out_json_len) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    static const char* empty_json = "{}";
    *out_json = empty_json;
    *out_json_len = 2;
    return ANIGMA_OK;
}

anigma_status_t anigma_table_export_to_csv(
    const struct anigma_table_t* table,
    const char** out_csv,
    size_t* out_csv_len
) {
    if (!table || !out_csv || !out_csv_len) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    static const char* empty_csv = "";
    *out_csv = empty_csv;
    *out_csv_len = 0;
    return ANIGMA_OK;
}

anigma_status_t anigma_table_free_export(
    const char* data
) {
    (void)data;
    return ANIGMA_OK;
}

} // extern "C"
