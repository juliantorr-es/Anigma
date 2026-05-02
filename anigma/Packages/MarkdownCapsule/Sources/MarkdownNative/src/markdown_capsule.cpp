#include "anigma_markdown_capsule.h"
#include "cmark-gfm.h"
#include <string.h>
#include <stdlib.h>

extern "C" {

anigma_status_t anigma_markdown_parse_string(
    const char* markdown,
    size_t length,
    int options,
    anigma_markdown_node_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!markdown || !out_handle) return ANIGMA_ERR_INVALID_ARG;
    
    cmark_node* root = cmark_parse_document(markdown, length, options);
    if (!root) return ANIGMA_ERR_INTERNAL;
    
    *out_handle = (anigma_markdown_node_t)root;
    return ANIGMA_OK;
}

anigma_status_t anigma_markdown_node_destroy(
    anigma_markdown_node_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_OK;
    cmark_node_free((cmark_node*)handle);
    return ANIGMA_OK;
}

anigma_status_t anigma_markdown_render_html(
    anigma_markdown_node_t handle,
    int options,
    char** out_html,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_html) return ANIGMA_ERR_INVALID_ARG;
    
    char* html = cmark_render_html((cmark_node*)handle, options, NULL);
    if (!html) return ANIGMA_ERR_INTERNAL;
    
    *out_html = html;
    return ANIGMA_OK;
}

anigma_status_t anigma_markdown_render_plaintext(
    anigma_markdown_node_t handle,
    int options,
    int width,
    char** out_text,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_text) return ANIGMA_ERR_INVALID_ARG;
    
    char* text = cmark_render_plaintext((cmark_node*)handle, options, width);
    if (!text) return ANIGMA_ERR_INTERNAL;
    
    *out_text = text;
    return ANIGMA_OK;
}

}
