#ifndef ANIGMA_MARKDOWN_CAPSULE_H
#define ANIGMA_MARKDOWN_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"

#if defined(__cplusplus)
extern "C" {
#endif

// Opaque handles
typedef anigma_capsule_handle_t anigma_markdown_node_t;

// Parsing
anigma_status_t anigma_markdown_parse_string(
    const char* markdown,
    size_t length,
    int options,
    anigma_markdown_node_t* out_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_markdown_node_destroy(
    anigma_markdown_node_t handle,
    anigma_capsule_error_t* err
);

// Rendering
anigma_status_t anigma_markdown_render_html(
    anigma_markdown_node_t handle,
    int options,
    char** out_html, // Caller must free
    anigma_capsule_error_t* err
);

anigma_status_t anigma_markdown_render_plaintext(
    anigma_markdown_node_t handle,
    int options,
    int width,
    char** out_text, // Caller must free
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif
