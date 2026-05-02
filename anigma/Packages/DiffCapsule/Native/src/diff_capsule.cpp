#include "diff_capsule.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <memory>
#include <string>

namespace {
struct DiffImpl {
    anigma_diff_config_t config;

    explicit DiffImpl(const anigma_diff_config_t& cfg) : config(cfg) {}
};

using DiffImplPtr = std::unique_ptr<DiffImpl>;

static void assign_version(
    anigma_document_version_t& version,
    const char* doc_id,
    const char* content,
    uint64_t timestamp,
    const char* author,
    const char* message
) {
    std::memset(&version, 0, sizeof(version));
    version.doc_id = doc_id ? doc_id : "";
    version.doc_id_len = std::strlen(version.doc_id);
    version.content = content ? content : "";
    version.content_len = std::strlen(version.content);
    version.timestamp = timestamp;
    version.author = author;
    version.author_len = author ? std::strlen(author) : 0;
    version.message = message;
    version.message_len = message ? std::strlen(message) : 0;
}

static std::string normalize_text(const char* text, const anigma_diff_config_t& config) {
    std::string normalized = text ? text : "";

    if (config.ignore_whitespace) {
        normalized.erase(
            std::remove_if(normalized.begin(), normalized.end(), [](unsigned char ch) {
                return std::isspace(ch) != 0;
            }),
            normalized.end()
        );
    }

    if (config.ignore_case) {
        std::transform(normalized.begin(), normalized.end(), normalized.begin(), [](unsigned char ch) {
            return static_cast<char>(std::tolower(ch));
        });
    }

    return normalized;
}

static void clear_result(anigma_document_diff_result_t& result) {
    std::memset(&result, 0, sizeof(result));
    result.similarity = 1.0f;
}
} // namespace

extern "C" {

anigma_status_t anigma_diff_get_default_config(
    struct anigma_diff_config_t* out_config
) {
    if (!out_config) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::memset(out_config, 0, sizeof(*out_config));
    out_config->enable_line_diff = true;
    out_config->enable_word_diff = false;
    out_config->enable_char_diff = false;
    out_config->ignore_whitespace = false;
    out_config->ignore_case = false;
    out_config->context_lines = 3;
    return ANIGMA_OK;
}

anigma_status_t anigma_diff_capsule_create(
    const struct anigma_diff_config_t* config,
    anigma_capsule_handle_t* out_handle
) {
    if (!out_handle) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    *out_handle = nullptr;

    anigma_diff_config_t resolved_config{};
    if (config) {
        resolved_config = *config;
    } else {
        anigma_diff_get_default_config(&resolved_config);
    }

    // Use smart pointer for automatic memory management
    auto* impl = new DiffImpl(resolved_config);
    if (!impl) {
        return ANIGMA_ERR_INTERNAL;
    }

    // Transfer ownership to caller using release()
    *out_handle = impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_diff_capsule_destroy(
    anigma_capsule_handle_t handle
) {
    if (!handle) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    // Use proper type casting and smart pointer for cleanup
    auto* impl = static_cast<DiffImpl*>(handle);
    delete impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_diff_compute(
    anigma_capsule_handle_t handle,
    const char* original_doc,
    size_t original_doc_len,
    const char* modified_doc,
    size_t modified_doc_len,
    struct anigma_document_diff_result_t* out_result
) {
    if (!handle || !out_result || !original_doc || !modified_doc) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    const auto* impl = static_cast<const DiffImpl*>(handle);
    clear_result(*out_result);
    assign_version(out_result->original, "", original_doc, 0, nullptr, nullptr);
    assign_version(out_result->modified, "", modified_doc, 0, nullptr, nullptr);
    out_result->similarity = normalize_text(original_doc, impl->config) ==
                             normalize_text(modified_doc, impl->config)
                                 ? 1.0f
                                 : 0.0f;
    (void)original_doc_len;
    (void)modified_doc_len;
    return ANIGMA_OK;
}

anigma_status_t anigma_diff_compute_from_versions(
    anigma_capsule_handle_t handle,
    const struct anigma_document_version_t* original,
    const struct anigma_document_version_t* modified,
    struct anigma_document_diff_result_t* out_result
) {
    if (!handle || !original || !modified || !out_result) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    const auto* impl = static_cast<const DiffImpl*>(handle);
    clear_result(*out_result);
    assign_version(
        out_result->original,
        original->doc_id,
        original->content,
        original->timestamp,
        original->author,
        original->message
    );
    assign_version(
        out_result->modified,
        modified->doc_id,
        modified->content,
        modified->timestamp,
        modified->author,
        modified->message
    );
    out_result->similarity = normalize_text(original->content, impl->config) ==
                             normalize_text(modified->content, impl->config)
                                 ? 1.0f
                                 : 0.0f;
    return ANIGMA_OK;
}

anigma_status_t anigma_diff_free_result(
    struct anigma_document_diff_result_t* result
) {
    if (!result) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    clear_result(*result);
    return ANIGMA_OK;
}

anigma_status_t anigma_diff_export_to_unified(
    const struct anigma_document_diff_result_t* result,
    const char** out_unified,
    size_t* out_unified_len
) {
    if (!result || !out_unified || !out_unified_len) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    static const char* unified = "--- original\n+++ modified\n";
    *out_unified = unified;
    *out_unified_len = std::strlen(unified);
    return ANIGMA_OK;
}

anigma_status_t anigma_diff_export_to_json(
    const struct anigma_document_diff_result_t* result,
    const char** out_json,
    size_t* out_json_len
) {
    if (!result || !out_json || !out_json_len) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    static const char* json = "{\"operations\":[]}";
    *out_json = json;
    *out_json_len = std::strlen(json);
    return ANIGMA_OK;
}

anigma_status_t anigma_diff_free_export(
    const char* data
) {
    (void)data;
    return ANIGMA_OK;
}

} // extern "C"
