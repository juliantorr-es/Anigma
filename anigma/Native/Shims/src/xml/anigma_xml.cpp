#include "anigma_xml.h"
#include <stdlib.h>
#include <string.h>

struct anigma_xml_doc_s {
    char* content;
    size_t len;
};

anigma_result_t anigma_xml_parse(
    anigma_ctx_t* ctx,
    const uint8_t* data,
    size_t len,
    anigma_xml_doc_t* out_doc
) {
    if (!data || !out_doc) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    struct anigma_xml_doc_s* doc = (struct anigma_xml_doc_s*)malloc(sizeof(struct anigma_xml_doc_s));
    if (!doc) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    
    doc->content = (char*)malloc(len + 1);
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
        if (doc->content) free(doc->content);
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
    if (!doc) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    // Mock: just append "PATCHED" to content if there's room, or realloc
    // Simplified: realloc
    size_t new_len = doc->len + 8;
    char* new_content = (char*)realloc(doc->content, new_len + 1);
    if (!new_content) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    
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
    if (!doc || !out_data || !out_len) return (anigma_result_t){ANIGMA_ERR_INVALID_ARG, "Invalid args"};
    
    uint8_t* buf = (uint8_t*)malloc(doc->len);
    if (!buf) return (anigma_result_t){ANIGMA_ERR_INTERNAL, "OOM"};
    
    memcpy(buf, doc->content, doc->len);
    *out_data = buf;
    *out_len = doc->len;
    
    return (anigma_result_t){ANIGMA_OK, NULL};
}
