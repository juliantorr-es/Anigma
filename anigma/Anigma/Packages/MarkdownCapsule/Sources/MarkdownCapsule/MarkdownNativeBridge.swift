// MarkdownNativeBridge.swift
// Swift bridge for the C markdown library

import Foundation

@_silgen_name("markdown_parse")
internal func markdown_parse(_ input: String, _ length: UInt32, _ document: UnsafeMutablePointer<UnsafeMutablePointer<markdown_document_t>?>) -> Int32

@_silgen_name("markdown_render")
internal func markdown_render(_ document: UnsafePointer<markdown_document_t>, _ format: UInt32, _ output: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>, _ outputLength: UnsafeMutablePointer<UInt32>) -> Int32

@_silgen_name("markdown_get_root")
internal func markdown_get_root(_ document: UnsafePointer<markdown_document_t>) -> UnsafePointer<markdown_node_t>?

@_silgen_name("markdown_get_node_type")
internal func markdown_get_node_type(_ node: UnsafePointer<markdown_node_t>) -> UInt32

@_silgen_name("markdown_get_node_content")
internal func markdown_get_node_content(_ node: UnsafePointer<markdown_node_t>) -> UnsafePointer<Int8>?

@_silgen_name("markdown_get_first_child")
internal func markdown_get_first_child(_ node: UnsafePointer<markdown_node_t>) -> UnsafePointer<markdown_node_t>?

@_silgen_name("markdown_get_next_sibling")
internal func markdown_get_next_sibling(_ node: UnsafePointer<markdown_node_t>) -> UnsafePointer<markdown_node_t>?

@_silgen_name("markdown_get_position")
internal func markdown_get_position(_ node: UnsafePointer<markdown_node_t>, _ startLine: UnsafeMutablePointer<UInt32>, _ startColumn: UnsafeMutablePointer<UInt32>, _ endLine: UnsafeMutablePointer<UInt32>, _ endColumn: UnsafeMutablePointer<UInt32>)

@_silgen_name("markdown_free_document")
internal func markdown_free_document(_ document: UnsafeMutablePointer<markdown_document_t>)

@_silgen_name("markdown_get_version")
internal func getVersion() -> UnsafePointer<Int8>

@_silgen_name("markdown_validate_syntax")
internal func markdown_validate_syntax(_ input: String, _ length: UInt32, _ errorMessage: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Int32

// Error codes
let MARKDOWN_SUCCESS: Int32 = 0
let MARKDOWN_ERROR_NULL_POINTER: Int32 = -1
let MARKDOWN_ERROR_INVALID_INPUT: Int32 = -2
let MARKDOWN_ERROR_MEMORY_ALLOCATION: Int32 = -3
let MARKDOWN_ERROR_PARSE_FAILED: Int32 = -4

// Render formats
let MARKDOWN_RENDER_HTML: UInt32 = 0
let MARKDOWN_RENDER_XML: UInt32 = 1
let MARKDOWN_RENDER_MAN: UInt32 = 2
let MARKDOWN_RENDER_COMMONMARK: UInt32 = 3
let MARKDOWN_RENDER_PLAIN_TEXT: UInt32 = 4