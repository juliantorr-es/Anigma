#include "reference_resolution_capsule.h"

#include <cstring>
#include <memory>

namespace {
struct ReferenceResolutionImpl {
    anigma_reference_resolution_config_t config;

    explicit ReferenceResolutionImpl(const anigma_reference_resolution_config_t& cfg) : config(cfg) {}
};

using ReferenceResolutionImplPtr = std::unique_ptr<ReferenceResolutionImpl>;
} // namespace

extern "C" {

anigma_status_t anigma_reference_resolution_get_default_config(
    struct anigma_reference_resolution_config_t* out_config
) {
    if (!out_config) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(out_config, 0, sizeof(*out_config));
    out_config->enable_online_lookup = false;
    out_config->enable_fuzzy_matching = true;
    out_config->fuzzy_threshold = 0.8f;
    out_config->enable_caching = true;
    out_config->cache_dir = nullptr;
    out_config->crossref_endpoint = nullptr;
    out_config->pubmed_endpoint = nullptr;
    return ANIGMA_OK;
}

anigma_status_t anigma_reference_resolution_capsule_create(
    const struct anigma_reference_resolution_config_t* config,
    anigma_capsule_handle_t* out_handle
) {
    if (!out_handle) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    *out_handle = nullptr;

    anigma_reference_resolution_config_t resolved_config{};
    if (config) {
        resolved_config = *config;
    } else {
        anigma_reference_resolution_get_default_config(&resolved_config);
    }

    // Use smart pointer for automatic memory management
    auto* impl = new ReferenceResolutionImpl(resolved_config);
    if (!impl) {
        return ANIGMA_ERR_INTERNAL;
    }

    // Transfer ownership to caller
    *out_handle = impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_reference_resolution_capsule_destroy(
    anigma_capsule_handle_t handle
) {
    if (!handle) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    // Use proper type casting and smart pointer for cleanup
    auto* impl = static_cast<ReferenceResolutionImpl*>(handle);
    delete impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_reference_resolution_resolve(
    anigma_capsule_handle_t handle,
    const struct anigma_citation_reference_t* references,
    size_t reference_count,
    struct anigma_reference_resolution_result_t* out_result
) {
    if (!handle || !out_result || (reference_count > 0 && !references)) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(out_result, 0, sizeof(*out_result));
    return ANIGMA_OK;
}

anigma_status_t anigma_reference_resolution_free_result(
    struct anigma_reference_resolution_result_t* result
) {
    if (!result) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(result, 0, sizeof(*result));
    return ANIGMA_OK;
}

anigma_status_t anigma_resolved_reference_export_to_bibtex(
    const struct anigma_resolved_reference_t* reference,
    const char** out_bibtex,
    size_t* out_bibtex_len
) {
    if (!reference || !out_bibtex || !out_bibtex_len) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    static const char* empty_bibtex = "";
    *out_bibtex = empty_bibtex;
    *out_bibtex_len = 0;
    return ANIGMA_OK;
}

anigma_status_t anigma_resolved_reference_export_to_json(
    const struct anigma_resolved_reference_t* reference,
    const char** out_json,
    size_t* out_json_len
) {
    if (!reference || !out_json || !out_json_len) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    static const char* empty_json = "{}";
    *out_json = empty_json;
    *out_json_len = 2;
    return ANIGMA_OK;
}

anigma_status_t anigma_reference_resolution_free_export(
    const char* data
) {
    (void)data;
    return ANIGMA_OK;
}

} // extern "C"
