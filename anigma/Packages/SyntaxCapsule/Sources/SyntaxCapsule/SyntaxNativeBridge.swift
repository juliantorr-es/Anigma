// SyntaxNativeBridge.swift
// Swift bridge for the C++ syntax highlighting library

import Foundation
import AnigmaNativeShims

typealias syntax_language_t = UInt32
typealias syntax_token_type_t = UInt32

struct syntax_token_t {
    var type: syntax_token_type_t
    var language: syntax_language_t
    var text: UnsafeMutablePointer<Int8>?
    var length: UInt32
    var start_line: UInt32
    var start_column: UInt32
    var end_line: UInt32
    var end_column: UInt32
    var next: UnsafeMutablePointer<syntax_token_t>?
}

struct syntax_parse_result_t {
    var tokens: UnsafeMutablePointer<syntax_token_t>?
    var token_count: UInt32
    var detected_language: syntax_language_t
    var metadata: UnsafeMutablePointer<Int8>?
}

@_silgen_name("syntax_detect_language")
internal func syntax_detect_language(_ input: String, _ length: UInt32, _ filenameHint: UnsafePointer<Int8>?) -> UInt32

@_silgen_name("syntax_parse")
internal func syntax_parse(_ input: String, _ length: UInt32, _ language: UInt32, _ result: UnsafeMutablePointer<UnsafeMutablePointer<syntax_parse_result_t>?>) -> Int32

@_silgen_name("syntax_get_tokens")
internal func syntax_get_tokens(_ result: UnsafePointer<syntax_parse_result_t>) -> UnsafePointer<syntax_token_t>?

@_silgen_name("syntax_get_token_count")
internal func syntax_get_token_count(_ result: UnsafePointer<syntax_parse_result_t>) -> UInt32

@_silgen_name("syntax_get_token_type")
internal func syntax_get_token_type(_ token: UnsafePointer<syntax_token_t>) -> UInt32

@_silgen_name("syntax_get_token_text")
internal func syntax_get_token_text(_ token: UnsafePointer<syntax_token_t>) -> UnsafePointer<Int8>?

@_silgen_name("syntax_get_token_length")
internal func syntax_get_token_length(_ token: UnsafePointer<syntax_token_t>) -> UInt32

@_silgen_name("syntax_get_token_language")
internal func syntax_get_token_language(_ token: UnsafePointer<syntax_token_t>) -> UInt32

@_silgen_name("syntax_get_token_position")
internal func syntax_get_token_position(_ token: UnsafePointer<syntax_token_t>, _ startLine: UnsafeMutablePointer<UInt32>, _ startColumn: UnsafeMutablePointer<UInt32>, _ endLine: UnsafeMutablePointer<UInt32>, _ endColumn: UnsafeMutablePointer<UInt32>)

@_silgen_name("syntax_has_errors")
internal func syntax_has_errors(_ result: UnsafePointer<syntax_parse_result_t>) -> Int32

@_silgen_name("syntax_get_error_count")
internal func syntax_get_error_count(_ result: UnsafePointer<syntax_parse_result_t>) -> UInt32

@_silgen_name("syntax_get_error_tokens")
internal func syntax_get_error_tokens(_ result: UnsafePointer<syntax_parse_result_t>) -> UnsafePointer<syntax_token_t>?

@_silgen_name("syntax_free_result")
internal func syntax_free_result(_ result: UnsafeMutablePointer<syntax_parse_result_t>)

@_silgen_name("syntax_free_tokens")
internal func syntax_free_tokens(_ tokens: UnsafeMutablePointer<syntax_token_t>)

@_silgen_name("syntax_get_version")
internal func getVersion_internal() -> UnsafePointer<Int8>

@_silgen_name("syntax_get_language_name")
internal func syntax_get_language_name(_ language: UInt32) -> UnsafePointer<Int8>

@_silgen_name("syntax_get_token_type_name")
internal func syntax_get_token_type_name(_ tokenType: UInt32) -> UnsafePointer<Int8>

@_silgen_name("syntax_is_supported_language")
internal func syntax_is_supported_language(_ language: UInt32) -> Int32

// Error codes
let SYNTAX_SUCCESS: Int32 = 0
let SYNTAX_ERROR_NULL_POINTER: Int32 = -1
let SYNTAX_ERROR_INVALID_INPUT: Int32 = -2
let SYNTAX_ERROR_MEMORY_ALLOCATION: Int32 = -3
let SYNTAX_ERROR_PARSE_FAILED: Int32 = -4
let SYNTAX_ERROR_UNSUPPORTED_LANGUAGE: Int32 = -5
