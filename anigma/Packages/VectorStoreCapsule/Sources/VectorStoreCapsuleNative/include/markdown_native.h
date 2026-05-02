#ifndef MARKDOWN_NATIVE_H
#define MARKDOWN_NATIVE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Error codes
#define MARKDOWN_SUCCESS 0
#define MARKDOWN_ERROR_NULL_POINTER -1
#define MARKDOWN_ERROR_INVALID_INPUT -2
#define MARKDOWN_ERROR_MEMORY_ALLOCATION -3
#define MARKDOWN_ERROR_PARSE_FAILED -4

// Node types
typedef enum {
    MARKDOWN_NODE_DOCUMENT = 0,
    MARKDOWN_NODE_BLOCK_QUOTE,
    MARKDOWN_NODE_LIST,
    MARKDOWN_NODE_ITEM,
    MARKDOWN_NODE_CODE_BLOCK,
    MARKDOWN_NODE_HTML_BLOCK,
    MARKDOWN_NODE_PARAGRAPH,
    MARKDOWN_NODE_HEADER,
    MARKDOWN_NODE_HRULE,
    MARKDOWN_NODE_TEXT,
    MARKDOWN_NODE_SOFTBREAK,
    MARKDOWN_NODE_LINEBREAK,
    MARKDOWN_NODE_CODE,
    MARKDOWN_NODE_HTML_INLINE,
    MARKDOWN_NODE_EMPH,
    MARKDOWN_NODE_STRONG,
    MARKDOWN_NODE_LINK,
    MARKDOWN_NODE_IMAGE,
    MARKDOWN_NODE_TEXTUAL
} markdown_node_type_t;

// Render formats
typedef enum {
    MARKDOWN_RENDER_HTML = 0,
    MARKDOWN_RENDER_XML,
    MARKDOWN_RENDER_MAN,
    MARKDOWN_RENDER_COMMONMARK,
    MARKDOWN_RENDER_PLAIN_TEXT
} markdown_render_format_t;

// Node structure
typedef struct markdown_node {
    markdown_node_type_t type;
    char* content;
    struct markdown_node* first_child;
    struct markdown_node* next;
    uint32_t start_line;
    uint32_t start_column;
    uint32_t end_line;
    uint32_t end_column;
} markdown_node_t;

// Document structure
typedef struct {
    markdown_node_t* root;
    uint32_t node_count;
    char* metadata;
} markdown_document_t;

// Parse functions
int32_t markdown_parse(const char* input, uint32_t length, markdown_document_t** document);

// Render functions
int32_t markdown_render(const markdown_document_t* document, markdown_render_format_t format, char** output, uint32_t* output_length);

// Node traversal
markdown_node_t* markdown_get_root(const markdown_document_t* document);
markdown_node_type_t markdown_get_node_type(const markdown_node_t* node);
const char* markdown_get_node_content(const markdown_node_t* node);
markdown_node_t* markdown_get_first_child(const markdown_node_t* node);
markdown_node_t* markdown_get_next_sibling(const markdown_node_t* node);
void markdown_get_position(const markdown_node_t* node, uint32_t* start_line, uint32_t* start_column, uint32_t* end_line, uint32_t* end_column);

// Memory management
void markdown_free_document(markdown_document_t* document);
void markdown_free_node(markdown_node_t* node);

// Utility functions
const char* markdown_get_version(void);
int32_t markdown_validate_syntax(const char* input, uint32_t length, char** error_message);

#ifdef __cplusplus
}
#endif

#endif // MARKDOWN_NATIVE_H