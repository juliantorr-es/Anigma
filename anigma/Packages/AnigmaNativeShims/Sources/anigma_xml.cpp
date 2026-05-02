#include "anigma_xml.h"

#include <stdlib.h>
#include <string.h>

struct anigma_xml_doc_s {
    char* content;
    size_t len;
};

extern "C" {

anigma_result_t anigma_xml_parse(
    anigma_ctx_t* ctx,
    const uint8_t* data,
    size_t len,
    anigma_xml_doc_t* out_doc
) {
    (void)ctx;
    if (!data || !out_doc) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    }

    struct anigma_xml_doc_s* doc =
        static_cast<struct anigma_xml_doc_s*>(malloc(sizeof(struct anigma_xml_doc_s)));
    if (!doc) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    }

    doc->content = static_cast<char*>(malloc(len + 1));
    if (!doc->content) {
        free(doc);
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    }

    memcpy(doc->content, data, len);
    doc->content[len] = '\0';
    doc->len = len;
    *out_doc = doc;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_xml_destroy(anigma_xml_doc_t doc) {
    if (doc) {
        free(doc->content);
        free(doc);
    }
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_xml_apply_patch(
    anigma_xml_doc_t doc,
    anigma_ctx_t* ctx,
    const uint8_t* patch_spec,
    size_t patch_len
) {
    (void)ctx;
    (void)patch_spec;
    (void)patch_len;
    if (!doc) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    }

    size_t new_len = doc->len + 8;
    char* new_content = static_cast<char*>(realloc(doc->content, new_len + 1));
    if (!new_content) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    }

    strcat(new_content, "_PATCHED");
    doc->content = new_content;
    doc->len = new_len;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

anigma_result_t anigma_xml_serialize(
    anigma_xml_doc_t doc,
    anigma_ctx_t* ctx,
    uint8_t** out_data,
    size_t* out_len
) {
    (void)ctx;
    if (!doc || !out_data || !out_len) {
        return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    }

    uint8_t* buffer = static_cast<uint8_t*>(malloc(doc->len));
    if (!buffer) {
        return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    }

    memcpy(buffer, doc->content, doc->len);
    *out_data = buffer;
    *out_len = doc->len;
    return (anigma_result_t){ANIGMA_OK, NULL};
}

} // extern "C"
