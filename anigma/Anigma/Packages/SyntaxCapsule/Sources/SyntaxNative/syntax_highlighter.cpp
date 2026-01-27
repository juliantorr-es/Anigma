#include "syntax_native.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

// Simple syntax highlighting implementation
// This is a minimal implementation for demonstration

static const char* VERSION = "1.0.0";

// Language keywords for different languages
static const char* swift_keywords[] = {
    "class", "struct", "enum", "protocol", "func", "var", "let", "if", "else", "for", "in", "while", "return", "break", "continue", "import", "public", "private", "internal", "static", "final", "override", "init", "deinit", "self", "super", "extension", "switch", "case", "default", "try", "catch", "throw", "throws", "rethrows", "guard", "defer", "where", "as", "is", "nil", "true", "false"
};

static const char* python_keywords[] = {
    "class", "def", "if", "elif", "else", "for", "in", "while", "return", "break", "continue", "import", "from", "as", "try", "except", "finally", "raise", "with", "lambda", "yield", "pass", "del", "global", "nonlocal", "assert", "and", "or", "not", "is", "in", "True", "False", "None"
};

static const char* cpp_keywords[] = {
    "class", "struct", "enum", "union", "namespace", "using", "template", "typename", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return", "goto", "try", "catch", "throw", "public", "private", "protected", "virtual", "static", "extern", "inline", "const", "constexpr", "volatile", "mutable", "auto", "register", "signed", "unsigned", "short", "long", "int", "float", "double", "char", "bool", "void", "wchar_t", "size_t", "nullptr", "true", "false"
};

static const char* rust_keywords[] = {
    "fn", "let", "mut", "const", "static", "if", "else", "match", "for", "while", "loop", "break", "continue", "return", "struct", "enum", "impl", "trait", "mod", "use", "pub", "crate", "super", "self", "Self", "where", "type", "as", "unsafe", "async", "await", "move", "ref", "in", "dyn", "extern", "macro", "abstract", "become", "box", "do", "final", "override", "priv", "unsized", "virtual", "yield", "true", "false"
};

static const int swift_keyword_count = sizeof(swift_keywords) / sizeof(swift_keywords[0]);
static const int python_keyword_count = sizeof(python_keywords) / sizeof(python_keywords[0]);
static const int cpp_keyword_count = sizeof(cpp_keywords) / sizeof(cpp_keywords[0]);
static const int rust_keyword_count = sizeof(rust_keywords) / sizeof(rust_keywords[0]);

// Helper function to check if a string is a keyword
static bool is_keyword(const char* word, syntax_language_t language) {
    if (!word) return false;
    
    const char** keywords = NULL;
    int keyword_count = 0;
    
    switch (language) {
        case SYNTAX_LANGUAGE_SWIFT:
            keywords = swift_keywords;
            keyword_count = swift_keyword_count;
            break;
        case SYNTAX_LANGUAGE_PYTHON:
            keywords = python_keywords;
            keyword_count = python_keyword_count;
            break;
        case SYNTAX_LANGUAGE_CPP:
            keywords = cpp_keywords;
            keyword_count = cpp_keyword_count;
            break;
        case SYNTAX_LANGUAGE_RUST:
            keywords = rust_keywords;
            keyword_count = rust_keyword_count;
            break;
        default:
            return false;
    }
    
    for (int i = 0; i < keyword_count; i++) {
        if (strcmp(word, keywords[i]) == 0) {
            return true;
        }
    }
    return false;
}

// Helper function to create a new token
static syntax_token_t* create_token(syntax_token_type_t type, syntax_language_t language, const char* text, uint32_t length, uint32_t line, uint32_t column) {
    syntax_token_t* token = malloc(sizeof(syntax_token_t));
    if (!token) return NULL;
    
    memset(token, 0, sizeof(syntax_token_t));
    token->type = type;
    token->language = language;
    token->length = length;
    token->start_line = line;
    token->start_column = column;
    token->end_line = line;
    token->end_column = column + length;
    
    if (text && length > 0) {
        token->text = malloc(length + 1);
        if (!token->text) {
            free(token);
            return NULL;
        }
        memcpy(token->text, text, length);
        token->text[length] = '\0';
    }
    
    return token;
}

// Language detection based on file extension and content patterns
syntax_language_t syntax_detect_language(const char* input, uint32_t length, const char* filename_hint) {
    if (filename_hint) {
        const char* extension = strrchr(filename_hint, '.');
        if (extension) {
            extension++; // Skip the dot
            if (strcmp(extension, "swift") == 0) return SYNTAX_LANGUAGE_SWIFT;
            if (strcmp(extension, "py") == 0) return SYNTAX_LANGUAGE_PYTHON;
            if (strcmp(extension, "cpp") == 0 || strcmp(extension, "cc") == 0 || strcmp(extension, "cxx") == 0) return SYNTAX_LANGUAGE_CPP;
            if (strcmp(extension, "rs") == 0) return SYNTAX_LANGUAGE_RUST;
            if (strcmp(extension, "js") == 0) return SYNTAX_LANGUAGE_JAVASCRIPT;
            if (strcmp(extension, "ts") == 0) return SYNTAX_LANGUAGE_TYPESCRIPT;
            if (strcmp(extension, "json") == 0) return SYNTAX_LANGUAGE_JSON;
            if (strcmp(extension, "html") == 0 || strcmp(extension, "htm") == 0) return SYNTAX_LANGUAGE_HTML;
            if (strcmp(extension, "css") == 0) return SYNTAX_LANGUAGE_CSS;
            if (strcmp(extension, "md") == 0 || strcmp(extension, "markdown") == 0) return SYNTAX_LANGUAGE_MARKDOWN;
        }
    }
    
    // Simple content-based detection
    if (!input || length == 0) return SYNTAX_LANGUAGE_UNKNOWN;
    
    // Look for language-specific patterns
    if (strstr(input, "func ") || strstr(input, "let ") || strstr(input, "var ")) {
        return SYNTAX_LANGUAGE_SWIFT;
    }
    if (strstr(input, "def ") || strstr(input, "import ") || strstr(input, "from ")) {
        return SYNTAX_LANGUAGE_PYTHON;
    }
    if (strstr(input, "#include") || strstr(input, "std::") || strstr(input, "::")) {
        return SYNTAX_LANGUAGE_CPP;
    }
    if (strstr(input, "fn ") || strstr(input, "let mut") || strstr(input, "impl ")) {
        return SYNTAX_LANGUAGE_RUST;
    }
    
    return SYNTAX_LANGUAGE_UNKNOWN;
}

// Simple lexer implementation
int32_t syntax_parse(const char* input, uint32_t length, syntax_language_t language, syntax_parse_result_t** result) {
    if (!input || !result) {
        return SYNTAX_ERROR_NULL_POINTER;
    }
    
    if (length == 0) {
        return SYNTAX_ERROR_INVALID_INPUT;
    }
    
    // Auto-detect language if unknown
    if (language == SYNTAX_LANGUAGE_UNKNOWN) {
        language = syntax_detect_language(input, length, NULL);
    }
    
    // Create result
    syntax_parse_result_t* parse_result = malloc(sizeof(syntax_parse_result_t));
    if (!parse_result) {
        return SYNTAX_ERROR_MEMORY_ALLOCATION;
    }
    
    memset(parse_result, 0, sizeof(syntax_parse_result_t));
    parse_result->detected_language = language;
    
    // Simple tokenization
    uint32_t pos = 0;
    uint32_t line = 1;
    uint32_t column = 1;
    syntax_token_t* last_token = NULL;
    uint32_t token_count = 0;
    
    while (pos < length) {
        char c = input[pos];
        
        // Skip whitespace
        if (isspace(c)) {
            if (c == '\n') {
                line++;
                column = 1;
            } else {
                column++;
            }
            pos++;
            continue;
        }
        
        // Single-line comments
        if ((language == SYNTAX_LANGUAGE_SWIFT || language == SYNTAX_LANGUAGE_CPP || language == SYNTAX_LANGUAGE_RUST || language == SYNTAX_LANGUAGE_JAVASCRIPT) && 
            c == '/' && pos + 1 < length && input[pos + 1] == '/') {
            uint32_t start = pos;
            while (pos < length && input[pos] != '\n') pos++;
            
            syntax_token_t* token = create_token(SYNTAX_TOKEN_COMMENT, language, input + start, pos - start, line, column);
            if (token) {
                if (last_token) last_token->next = token;
                else parse_result->tokens = token;
                last_token = token;
                token_count++;
            }
            continue;
        }
        
        // Python comments
        if (language == SYNTAX_LANGUAGE_PYTHON && c == '#') {
            uint32_t start = pos;
            while (pos < length && input[pos] != '\n') pos++;
            
            syntax_token_t* token = create_token(SYNTAX_TOKEN_COMMENT, language, input + start, pos - start, line, column);
            if (token) {
                if (last_token) last_token->next = token;
                else parse_result->tokens = token;
                last_token = token;
                token_count++;
            }
            continue;
        }
        
        // String literals
        if (c == '"' || c == '\'') {
            char quote = c;
            uint32_t start = pos;
            pos++; // Skip opening quote
            column++;
            
            while (pos < length && input[pos] != quote) {
                if (input[pos] == '\\') pos++; // Skip escaped character
                if (input[pos] == '\n') {
                    line++;
                    column = 1;
                } else {
                    column++;
                }
                pos++;
            }
            
            if (pos < length) pos++; // Skip closing quote
            column++;
            
            syntax_token_t* token = create_token(SYNTAX_TOKEN_STRING, language, input + start, pos - start, line, column - (pos - start));
            if (token) {
                if (last_token) last_token->next = token;
                else parse_result->tokens = token;
                last_token = token;
                token_count++;
            }
            continue;
        }
        
        // Numbers
        if (isdigit(c)) {
            uint32_t start = pos;
            while (pos < length && (isdigit(input[pos]) || input[pos] == '.')) {
                pos++;
                column++;
            }
            
            syntax_token_t* token = create_token(SYNTAX_TOKEN_NUMBER, language, input + start, pos - start, line, column - (pos - start));
            if (token) {
                if (last_token) last_token->next = token;
                else parse_result->tokens = token;
                last_token = token;
                token_count++;
            }
            continue;
        }
        
        // Identifiers and keywords
        if (isalpha(c) || c == '_') {
            uint32_t start = pos;
            while (pos < length && (isalnum(input[pos]) || input[pos] == '_')) {
                pos++;
                column++;
            }
            
            // Check if it's a keyword
            char* word = malloc(pos - start + 1);
            if (word) {
                memcpy(word, input + start, pos - start);
                word[pos - start] = '\0';
                
                syntax_token_type_t token_type = is_keyword(word, language) ? SYNTAX_TOKEN_KEYWORD : SYNTAX_TOKEN_IDENTIFIER;
                
                syntax_token_t* token = create_token(token_type, language, input + start, pos - start, line, column - (pos - start));
                if (token) {
                    if (last_token) last_token->next = token;
                    else parse_result->tokens = token;
                    last_token = token;
                    token_count++;
                }
                
                free(word);
            }
            continue;
        }
        
        // Operators and punctuation
        if (ispunct(c)) {
            uint32_t start = pos;
            while (pos < length && ispunct(input[pos]) && input[pos] != '"' && input[pos] != '\'') {
                pos++;
                column++;
            }
            
            syntax_token_type_t token_type = (c == '{' || c == '}' || c == '(' || c == ')' || c == '[' || c == ']' || c == ';' || c == ',') ? SYNTAX_TOKEN_PUNCTUATION : SYNTAX_TOKEN_OPERATOR;
            
            syntax_token_t* token = create_token(token_type, language, input + start, pos - start, line, column - (pos - start));
            if (token) {
                if (last_token) last_token->next = token;
                else parse_result->tokens = token;
                last_token = token;
                token_count++;
            }
            continue;
        }
        
        // Default: treat as unknown
        pos++;
        column++;
    }
    
    parse_result->token_count = token_count;
    
    // Create metadata
    char metadata[512];
    snprintf(metadata, sizeof(metadata), 
             "{\"version\": \"%s\", \"language\": \"%s\", \"token_count\": %u, \"input_length\": %u}", 
             VERSION, syntax_get_language_name(language), token_count, length);
    parse_result->metadata = malloc(strlen(metadata) + 1);
    if (!parse_result->metadata) {
        syntax_free_result(parse_result);
        return SYNTAX_ERROR_MEMORY_ALLOCATION;
    }
    strcpy(parse_result->metadata, metadata);
    
    *result = parse_result;
    return SYNTAX_SUCCESS;
}

// Token access functions
syntax_token_t* syntax_get_tokens(const syntax_parse_result_t* result) {
    return result ? result->tokens : NULL;
}

uint32_t syntax_get_token_count(const syntax_parse_result_t* result) {
    return result ? result->token_count : 0;
}

syntax_token_type_t syntax_get_token_type(const syntax_token_t* token) {
    return token ? token->type : SYNTAX_TOKEN_UNKNOWN;
}

const char* syntax_get_token_text(const syntax_token_t* token) {
    return token ? token->text : NULL;
}

uint32_t syntax_get_token_length(const syntax_token_t* token) {
    return token ? token->length : 0;
}

syntax_language_t syntax_get_token_language(const syntax_token_t* token) {
    return token ? token->language : SYNTAX_LANGUAGE_UNKNOWN;
}

void syntax_get_token_position(const syntax_token_t* token, uint32_t* start_line, uint32_t* start_column, uint32_t* end_line, uint32_t* end_column) {
    if (!token) return;
    
    if (start_line) *start_line = token->start_line;
    if (start_column) *start_column = token->start_column;
    if (end_line) *end_line = token->end_line;
    if (end_column) *end_column = token->end_column;
}

// Error recovery functions
int32_t syntax_has_errors(const syntax_parse_result_t* result) {
    if (!result) return 0;
    
    syntax_token_t* token = result->tokens;
    while (token) {
        if (token->type == SYNTAX_TOKEN_ERROR) {
            return 1;
        }
        token = token->next;
    }
    return 0;
}

uint32_t syntax_get_error_count(const syntax_parse_result_t* result) {
    if (!result) return 0;
    
    uint32_t count = 0;
    syntax_token_t* token = result->tokens;
    while (token) {
        if (token->type == SYNTAX_TOKEN_ERROR) {
            count++;
        }
        token = token->next;
    }
    return count;
}

syntax_token_t* syntax_get_error_tokens(const syntax_parse_result_t* result) {
    if (!result) return NULL;
    
    syntax_token_t* error_tokens = NULL;
    syntax_token_t* last_error = NULL;
    
    syntax_token_t* token = result->tokens;
    while (token) {
        if (token->type == SYNTAX_TOKEN_ERROR) {
            syntax_token_t* error = malloc(sizeof(syntax_token_t));
            if (error) {
                memcpy(error, token, sizeof(syntax_token_t));
                error->next = NULL;
                
                if (last_error) last_error->next = error;
                else error_tokens = error;
                last_error = error;
            }
        }
        token = token->next;
    }
    
    return error_tokens;
}

// Memory management
void syntax_free_tokens(syntax_token_t* tokens) {
    while (tokens) {
        syntax_token_t* next = tokens->next;
        if (tokens->text) {
            free(tokens->text);
        }
        free(tokens);
        tokens = next;
    }
}

void syntax_free_result(syntax_parse_result_t* result) {
    if (!result) return;
    
    if (result->tokens) {
        syntax_free_tokens(result->tokens);
    }
    
    if (result->metadata) {
        free(result->metadata);
    }
    
    free(result);
}

// Utility functions
const char* syntax_get_version(void) {
    return VERSION;
}

const char* syntax_get_language_name(syntax_language_t language) {
    switch (language) {
        case SYNTAX_LANGUAGE_SWIFT: return "swift";
        case SYNTAX_LANGUAGE_PYTHON: return "python";
        case SYNTAX_LANGUAGE_CPP: return "cpp";
        case SYNTAX_LANGUAGE_RUST: return "rust";
        case SYNTAX_LANGUAGE_JAVASCRIPT: return "javascript";
        case SYNTAX_LANGUAGE_TYPESCRIPT: return "typescript";
        case SYNTAX_LANGUAGE_JSON: return "json";
        case SYNTAX_LANGUAGE_HTML: return "html";
        case SYNTAX_LANGUAGE_CSS: return "css";
        case SYNTAX_LANGUAGE_MARKDOWN: return "markdown";
        default: return "unknown";
    }
}

const char* syntax_get_token_type_name(syntax_token_type_t token_type) {
    switch (token_type) {
        case SYNTAX_TOKEN_KEYWORD: return "keyword";
        case SYNTAX_TOKEN_IDENTIFIER: return "identifier";
        case SYNTAX_TOKEN_STRING: return "string";
        case SYNTAX_TOKEN_NUMBER: return "number";
        case SYNTAX_TOKEN_COMMENT: return "comment";
        case SYNTAX_TOKEN_OPERATOR: return "operator";
        case SYNTAX_TOKEN_PUNCTUATION: return "punctuation";
        case SYNTAX_TOKEN_WHITESPACE: return "whitespace";
        case SYNTAX_TOKEN_ERROR: return "error";
        case SYNTAX_TOKEN_FUNCTION: return "function";
        case SYNTAX_TOKEN_VARIABLE: return "variable";
        case SYNTAX_TOKEN_TYPE: return "type";
        case SYNTAX_TOKEN_CONSTANT: return "constant";
        default: return "unknown";
    }
}

int32_t syntax_is_supported_language(syntax_language_t language) {
    return language >= SYNTAX_LANGUAGE_SWIFT && language <= SYNTAX_LANGUAGE_MARKDOWN;
}