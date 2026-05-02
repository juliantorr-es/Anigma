#ifndef SYNTAX_NATIVE_H
#define SYNTAX_NATIVE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Error codes
#define SYNTAX_SUCCESS 0
#define SYNTAX_ERROR_NULL_POINTER -1
#define SYNTAX_ERROR_INVALID_INPUT -2
#define SYNTAX_ERROR_MEMORY_ALLOCATION -3
#define SYNTAX_ERROR_PARSE_FAILED -4
#define SYNTAX_ERROR_UNSUPPORTED_LANGUAGE -5

// Supported languages
typedef enum {
    SYNTAX_LANGUAGE_UNKNOWN = 0,
    SYNTAX_LANGUAGE_SWIFT = 1,
    SYNTAX_LANGUAGE_PYTHON = 2,
    SYNTAX_LANGUAGE_CPP = 3,
    SYNTAX_LANGUAGE_RUST = 4,
    SYNTAX_LANGUAGE_JAVASCRIPT = 5,
    SYNTAX_LANGUAGE_TYPESCRIPT = 6,
    SYNTAX_LANGUAGE_JSON = 7,
    SYNTAX_LANGUAGE_HTML = 8,
    SYNTAX_LANGUAGE_CSS = 9,
    SYNTAX_LANGUAGE_MARKDOWN = 10
} syntax_language_t;

// Token types
typedef enum {
    SYNTAX_TOKEN_UNKNOWN = 0,
    SYNTAX_TOKEN_KEYWORD = 1,
    SYNTAX_TOKEN_IDENTIFIER = 2,
    SYNTAX_TOKEN_STRING = 3,
    SYNTAX_TOKEN_NUMBER = 4,
    SYNTAX_TOKEN_COMMENT = 5,
    SYNTAX_TOKEN_OPERATOR = 6,
    SYNTAX_TOKEN_PUNCTUATION = 7,
    SYNTAX_TOKEN_WHITESPACE = 8,
    SYNTAX_TOKEN_ERROR = 9,
    SYNTAX_TOKEN_FUNCTION = 10,
    SYNTAX_TOKEN_VARIABLE = 11,
    SYNTAX_TOKEN_TYPE = 12,
    SYNTAX_TOKEN_CONSTANT = 13
} syntax_token_type_t;

// Token structure
typedef struct syntax_token {
    syntax_token_type_t type;
    syntax_language_t language;
    char* text;
    uint32_t length;
    uint32_t start_line;
    uint32_t start_column;
    uint32_t end_line;
    uint32_t end_column;
    struct syntax_token* next;
} syntax_token_t;

// Parse result structure
typedef struct {
    syntax_token_t* tokens;
    uint32_t token_count;
    syntax_language_t detected_language;
    char* metadata;
} syntax_parse_result_t;

// Language detection
syntax_language_t syntax_detect_language(const char* input, uint32_t length, const char* filename_hint);

// Parsing functions
int32_t syntax_parse(const char* input, uint32_t length, syntax_language_t language, syntax_parse_result_t** result);

// Token access
syntax_token_t* syntax_get_tokens(const syntax_parse_result_t* result);
uint32_t syntax_get_token_count(const syntax_parse_result_t* result);
syntax_token_type_t syntax_get_token_type(const syntax_token_t* token);
const char* syntax_get_token_text(const syntax_token_t* token);
uint32_t syntax_get_token_length(const syntax_token_t* token);
syntax_language_t syntax_get_token_language(const syntax_token_t* token);
void syntax_get_token_position(const syntax_token_t* token, uint32_t* start_line, uint32_t* start_column, uint32_t* end_line, uint32_t* end_column);

// Error recovery
int32_t syntax_has_errors(const syntax_parse_result_t* result);
uint32_t syntax_get_error_count(const syntax_parse_result_t* result);
syntax_token_t* syntax_get_error_tokens(const syntax_parse_result_t* result);

// Memory management
void syntax_free_result(syntax_parse_result_t* result);
void syntax_free_tokens(syntax_token_t* tokens);

// Utility functions
const char* syntax_get_version(void);
const char* syntax_get_language_name(syntax_language_t language);
const char* syntax_get_token_type_name(syntax_token_type_t token_type);
int32_t syntax_is_supported_language(syntax_language_t language);

#ifdef __cplusplus
}
#endif

#endif // SYNTAX_NATIVE_H