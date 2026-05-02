#ifndef ANIGMA_SYNTAX_CAPSULE_H
#define ANIGMA_SYNTAX_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"

#if defined(__cplusplus)
extern "C" {
#endif

// Opaque handles
typedef anigma_capsule_handle_t anigma_syntax_parser_t;
typedef anigma_capsule_handle_t anigma_syntax_tree_t;
typedef anigma_capsule_handle_t anigma_syntax_node_t; // Actually just a wrapped TSTreeCursor or similar? 
// TSNode is a struct, not a pointer. Passing it across ABI is tricky if we want to be opaque.
// We can use a "Cursor" approach.

typedef enum {
    ANIGMA_SYNTAX_LANG_JSON = 0,
    ANIGMA_SYNTAX_LANG_SWIFT = 1,
    ANIGMA_SYNTAX_LANG_PYTHON = 2,
    ANIGMA_SYNTAX_LANG_MARKDOWN = 3
} anigma_syntax_language_t;

// Lifecycle
anigma_status_t anigma_syntax_parser_create(
    anigma_syntax_language_t language,
    anigma_syntax_parser_t* out_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_syntax_parser_destroy(
    anigma_syntax_parser_t handle,
    anigma_capsule_error_t* err
);

// Parsing
anigma_status_t anigma_syntax_parser_parse_string(
    anigma_syntax_parser_t parser,
    const char* source_code,
    uint32_t length,
    anigma_syntax_tree_t* out_tree,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_syntax_tree_destroy(
    anigma_syntax_tree_t handle,
    anigma_capsule_error_t* err
);

// Inspection
anigma_status_t anigma_syntax_tree_root_node_string(
    anigma_syntax_tree_t tree,
    char** out_string, // S-expression, must free
    anigma_capsule_error_t* err
);

// Node Access
typedef struct {
    uint32_t start_byte;
    uint32_t end_byte;
    uint32_t start_row;
    uint32_t start_column;
    uint32_t end_row;
    uint32_t end_column;
    const char* type;
    bool is_named;
} anigma_syntax_node_info_t;

anigma_status_t anigma_syntax_tree_get_root_node(
    anigma_syntax_tree_t tree,
    anigma_syntax_node_info_t* out_info,
    anigma_capsule_handle_t* out_node_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_syntax_node_get_child_count(
    anigma_capsule_handle_t node_handle,
    uint32_t* out_count,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_syntax_node_get_child(
    anigma_capsule_handle_t node_handle,
    uint32_t index,
    anigma_syntax_node_info_t* out_info,
    anigma_capsule_handle_t* out_child_handle,
    anigma_capsule_error_t* err
);

anigma_status_t anigma_syntax_node_destroy(
    anigma_capsule_handle_t handle,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif
