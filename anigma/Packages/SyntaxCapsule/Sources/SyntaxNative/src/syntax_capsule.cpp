#include "anigma_syntax_capsule.h"
#include "tree_sitter/api.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// Forward declarations for language parsers
// These must be linked in or included in the source build
extern "C" const TSLanguage *tree_sitter_json(void);
// extern "C" const TSLanguage *tree_sitter_swift(void);
// extern "C" const TSLanguage *tree_sitter_python(void);
// extern "C" const TSLanguage *tree_sitter_markdown(void);

extern "C" {

struct SyntaxParser {
    TSParser* parser;
};

struct SyntaxTree {
    TSTree* tree;
};

struct SyntaxNode {
    TSNode node;
};

static void fill_node_info(TSNode node, anigma_syntax_node_info_t* out_info) {
    if (!out_info) return;
    out_info->start_byte = ts_node_start_byte(node);
    out_info->end_byte = ts_node_end_byte(node);
    TSPoint start = ts_node_start_point(node);
    TSPoint end = ts_node_end_point(node);
    out_info->start_row = start.row;
    out_info->start_column = start.column;
    out_info->end_row = end.row;
    out_info->end_column = end.column;
    out_info->type = ts_node_type(node);
    out_info->is_named = ts_node_is_named(node);
}

anigma_status_t anigma_syntax_parser_create(
    anigma_syntax_language_t language,
    anigma_syntax_parser_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!out_handle) return ANIGMA_ERR_INVALID_ARG;
    
    const TSLanguage* lang = nullptr;
    switch (language) {
        case ANIGMA_SYNTAX_LANG_JSON:
            lang = tree_sitter_json();
            break;
        case ANIGMA_SYNTAX_LANG_SWIFT:
            // lang = tree_sitter_swift();
            return ANIGMA_ERR_NOT_IMPLEMENTED;
        case ANIGMA_SYNTAX_LANG_PYTHON:
            // lang = tree_sitter_python();
            return ANIGMA_ERR_NOT_IMPLEMENTED;
        case ANIGMA_SYNTAX_LANG_MARKDOWN:
            // lang = tree_sitter_markdown();
            return ANIGMA_ERR_NOT_IMPLEMENTED;
        default:
            return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!lang) return ANIGMA_ERR_INTERNAL;
    
    TSParser* parser = ts_parser_new();
    if (!parser) return ANIGMA_ERR_OUT_OF_MEMORY;
    
    if (!ts_parser_set_language(parser, lang)) {
        ts_parser_delete(parser);
        return ANIGMA_ERR_INTERNAL; // Language version mismatch?
    }
    
    SyntaxParser* wrapper = (SyntaxParser*)malloc(sizeof(SyntaxParser));
    if (!wrapper) {
        ts_parser_delete(parser);
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    wrapper->parser = parser;
    // wrapper->language = lang; // Const mismatch if not careful, but we don't own language
    
    *out_handle = (anigma_syntax_parser_t)wrapper;
    return ANIGMA_OK;
}

anigma_status_t anigma_syntax_parser_destroy(
    anigma_syntax_parser_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_OK;
    SyntaxParser* wrapper = (SyntaxParser*)handle;
    if (wrapper->parser) ts_parser_delete(wrapper->parser);
    free(wrapper);
    return ANIGMA_OK;
}

anigma_status_t anigma_syntax_parser_parse_string(
    anigma_syntax_parser_t parser,
    const char* source_code,
    uint32_t length,
    anigma_syntax_tree_t* out_tree,
    anigma_capsule_error_t* err
) {
    if (!parser || !source_code || !out_tree) return ANIGMA_ERR_INVALID_ARG;
    SyntaxParser* wrapper = (SyntaxParser*)parser;
    
    // Parse
    TSTree* tree = ts_parser_parse_string(
        wrapper->parser,
        NULL, // old_tree (for incremental parsing, not supported yet in capsule)
        source_code,
        length
    );
    
    if (!tree) return ANIGMA_ERR_INTERNAL;
    
    SyntaxTree* treeWrapper = (SyntaxTree*)malloc(sizeof(SyntaxTree));
    if (!treeWrapper) {
        ts_tree_delete(tree);
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }
    
    treeWrapper->tree = tree;
    *out_tree = (anigma_syntax_tree_t)treeWrapper;
    
    return ANIGMA_OK;
}

anigma_status_t anigma_syntax_tree_destroy(
    anigma_syntax_tree_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_OK;
    SyntaxTree* wrapper = (SyntaxTree*)handle;
    if (wrapper->tree) ts_tree_delete(wrapper->tree);
    free(wrapper);
    return ANIGMA_OK;
}

anigma_status_t anigma_syntax_tree_root_node_string(
    anigma_syntax_tree_t tree,
    char** out_string,
    anigma_capsule_error_t* err
) {
    if (!tree || !out_string) return ANIGMA_ERR_INVALID_ARG;
    SyntaxTree* wrapper = (SyntaxTree*)tree;
    
    TSNode root = ts_tree_root_node(wrapper->tree);
    char* s = ts_node_string(root);
    
    if (!s) return ANIGMA_ERR_INTERNAL;
    
    *out_string = s; // ts_node_string returns malloc'd string that caller must free
    
    return ANIGMA_OK;
}

anigma_status_t anigma_syntax_tree_get_root_node(
    anigma_syntax_tree_t tree,
    anigma_syntax_node_info_t* out_info,
    anigma_capsule_handle_t* out_node_handle,
    anigma_capsule_error_t* err
) {
    if (!tree || !out_node_handle) return ANIGMA_ERR_INVALID_ARG;
    SyntaxTree* wrapper = (SyntaxTree*)tree;
    
    TSNode root = ts_tree_root_node(wrapper->tree);
    if (ts_node_is_null(root)) return ANIGMA_STATUS_NOT_FOUND;
    
    fill_node_info(root, out_info);
    
    SyntaxNode* nodeWrapper = (SyntaxNode*)malloc(sizeof(SyntaxNode));
    if (!nodeWrapper) return ANIGMA_ERR_OUT_OF_MEMORY;
    nodeWrapper->node = root;
    
    *out_node_handle = (anigma_capsule_handle_t)nodeWrapper;
    return ANIGMA_OK;
}

anigma_status_t anigma_syntax_node_get_child_count(
    anigma_capsule_handle_t node_handle,
    uint32_t* out_count,
    anigma_capsule_error_t* err
) {
    if (!node_handle || !out_count) return ANIGMA_ERR_INVALID_ARG;
    SyntaxNode* wrapper = (SyntaxNode*)node_handle;
    *out_count = ts_node_child_count(wrapper->node);
    return ANIGMA_OK;
}

anigma_status_t anigma_syntax_node_get_child(
    anigma_capsule_handle_t node_handle,
    uint32_t index,
    anigma_syntax_node_info_t* out_info,
    anigma_capsule_handle_t* out_child_handle,
    anigma_capsule_error_t* err
) {
    if (!node_handle || !out_child_handle) return ANIGMA_ERR_INVALID_ARG;
    SyntaxNode* wrapper = (SyntaxNode*)node_handle;
    
    TSNode child = ts_node_child(wrapper->node, index);
    if (ts_node_is_null(child)) return ANIGMA_STATUS_NOT_FOUND;
    
    fill_node_info(child, out_info);
    
    SyntaxNode* childWrapper = (SyntaxNode*)malloc(sizeof(SyntaxNode));
    if (!childWrapper) return ANIGMA_ERR_OUT_OF_MEMORY;
    childWrapper->node = child;
    
    *out_child_handle = (anigma_capsule_handle_t)childWrapper;
    return ANIGMA_OK;
}

anigma_status_t anigma_syntax_node_destroy(
    anigma_capsule_handle_t handle,
    anigma_capsule_error_t* err
) {
    if (!handle) return ANIGMA_OK;
    free((void*)handle);
    return ANIGMA_OK;
}

}
