#include "markdown_native.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Simple markdown parser implementation
// This is a minimal implementation for demonstration

static const char* VERSION = "1.0.0";

// Helper function to create a new node
static markdown_node_t* create_node(markdown_node_type_t type) {
    markdown_node_t* node = malloc(sizeof(markdown_node_t));
    if (!node) return NULL;
    
    memset(node, 0, sizeof(markdown_node_t));
    node->type = type;
    return node;
}

// Parse markdown input into document tree
int32_t markdown_parse(const char* input, uint32_t length, markdown_document_t** document) {
    if (!input || !document) {
        return MARKDOWN_ERROR_NULL_POINTER;
    }
    
    if (length == 0) {
        return MARKDOWN_ERROR_INVALID_INPUT;
    }
    
    // Create document
    markdown_document_t* doc = malloc(sizeof(markdown_document_t));
    if (!doc) {
        return MARKDOWN_ERROR_MEMORY_ALLOCATION;
    }
    
    memset(doc, 0, sizeof(markdown_document_t));
    
    // Create root document node
    doc->root = create_node(MARKDOWN_NODE_DOCUMENT);
    if (!doc->root) {
        free(doc);
        return MARKDOWN_ERROR_MEMORY_ALLOCATION;
    }
    
    // Simple parsing - create paragraph with text content
    markdown_node_t* paragraph = create_node(MARKDOWN_NODE_PARAGRAPH);
    if (!paragraph) {
        markdown_free_node(doc->root);
        free(doc);
        return MARKDOWN_ERROR_MEMORY_ALLOCATION;
    }
    
    markdown_node_t* text = create_node(MARKDOWN_NODE_TEXT);
    if (!text) {
        markdown_free_node(paragraph);
        markdown_free_node(doc->root);
        free(doc);
        return MARKDOWN_ERROR_MEMORY_ALLOCATION;
    }
    
    // Copy input content to text node
    text->content = malloc(length + 1);
    if (!text->content) {
        markdown_free_node(text);
        markdown_free_node(paragraph);
        markdown_free_node(doc->root);
        free(doc);
        return MARKDOWN_ERROR_MEMORY_ALLOCATION;
    }
    
    memcpy(text->content, input, length);
    text->content[length] = '\0';
    
    // Build tree structure
    paragraph->first_child = text;
    doc->root->first_child = paragraph;
    doc->node_count = 3; // document + paragraph + text
    
    // Create metadata
    char metadata[256];
    snprintf(metadata, sizeof(metadata), 
             "{\"version\": \"%s\", \"input_length\": %u, \"node_count\": %u}", 
             VERSION, length, doc->node_count);
    doc->metadata = malloc(strlen(metadata) + 1);
    if (!doc->metadata) {
        markdown_free_document(doc);
        return MARKDOWN_ERROR_MEMORY_ALLOCATION;
    }
    strcpy(doc->metadata, metadata);
    
    *document = doc;
    return MARKDOWN_SUCCESS;
}

// Render document to specified format
int32_t markdown_render(const markdown_document_t* document, markdown_render_format_t format, char** output, uint32_t* output_length) {
    if (!document || !output || !output_length) {
        return MARKDOWN_ERROR_NULL_POINTER;
    }
    
    // Simple rendering implementation
    const char* result = NULL;
    size_t result_length = 0;
    
    switch (format) {
        case MARKDOWN_RENDER_HTML:
            // Wrap text in <p> tags
            if (document->root && document->root->first_child && document->root->first_child->first_child) {
                const char* content = document->root->first_child->first_child->content;
                if (content) {
                    char* html = malloc(strlen(content) + 8); // <p></p>\0
                    if (html) {
                        sprintf(html, "<p>%s</p>", content);
                        result = html;
                        result_length = strlen(html);
                    }
                }
            }
            break;
            
        case MARKDOWN_RENDER_PLAIN_TEXT:
            // Just return the text content
            if (document->root && document->root->first_child && document->root->first_child->first_child) {
                result = document->root->first_child->first_child->content;
                result_length = strlen(result);
            }
            break;
            
        default:
            return MARKDOWN_ERROR_PARSE_FAILED;
    }
    
    if (!result) {
        // Return empty string
        *output = malloc(1);
        if (*output) {
            (*output)[0] = '\0';
            *output_length = 0;
            return MARKDOWN_SUCCESS;
        }
        return MARKDOWN_ERROR_MEMORY_ALLOCATION;
    }
    
    *output = malloc(result_length + 1);
    if (!*output) {
        if (format == MARKDOWN_RENDER_HTML) {
            free((void*)result);
        }
        return MARKDOWN_ERROR_MEMORY_ALLOCATION;
    }
    
    memcpy(*output, result, result_length + 1);
    *output_length = (uint32_t)result_length;
    
    if (format == MARKDOWN_RENDER_HTML) {
        free((void*)result);
    }
    
    return MARKDOWN_SUCCESS;
}

// Node traversal functions
markdown_node_t* markdown_get_root(const markdown_document_t* document) {
    return document ? document->root : NULL;
}

markdown_node_type_t markdown_get_node_type(const markdown_node_t* node) {
    return node ? node->type : MARKDOWN_NODE_DOCUMENT;
}

const char* markdown_get_node_content(const markdown_node_t* node) {
    return node ? node->content : NULL;
}

markdown_node_t* markdown_get_first_child(const markdown_node_t* node) {
    return node ? node->first_child : NULL;
}

markdown_node_t* markdown_get_next_sibling(const markdown_node_t* node) {
    return node ? node->next : NULL;
}

void markdown_get_position(const markdown_node_t* node, uint32_t* start_line, uint32_t* start_column, uint32_t* end_line, uint32_t* end_column) {
    if (!node) return;
    
    if (start_line) *start_line = node->start_line;
    if (start_column) *start_column = node->start_column;
    if (end_line) *end_line = node->end_line;
    if (end_column) *end_column = node->end_column;
}

// Memory management
void markdown_free_node(markdown_node_t* node) {
    if (!node) return;
    
    // Free children recursively
    markdown_node_t* child = node->first_child;
    while (child) {
        markdown_node_t* next = child->next;
        markdown_free_node(child);
        child = next;
    }
    
    // Free content
    if (node->content) {
        free(node->content);
    }
    
    // Free node itself
    free(node);
}

void markdown_free_document(markdown_document_t* document) {
    if (!document) return;
    
    // Free node tree
    if (document->root) {
        markdown_free_node(document->root);
    }
    
    // Free metadata
    if (document->metadata) {
        free(document->metadata);
    }
    
    // Free document
    free(document);
}

// Utility functions
const char* markdown_get_version(void) {
    return VERSION;
}

int32_t markdown_validate_syntax(const char* input, uint32_t length, char** error_message) {
    if (!input || !error_message) {
        return MARKDOWN_ERROR_NULL_POINTER;
    }
    
    if (length == 0) {
        *error_message = malloc(32);
        if (*error_message) {
            strcpy(*error_message, "Input cannot be empty");
        }
        return MARKDOWN_ERROR_INVALID_INPUT;
    }
    
    // Simple validation - check for basic markdown syntax issues
    // In a real implementation, this would be more sophisticated
    *error_message = NULL;
    return MARKDOWN_SUCCESS;
}