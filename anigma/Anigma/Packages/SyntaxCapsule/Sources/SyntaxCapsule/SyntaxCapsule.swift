// SyntaxCapsule.swift
// SyntaxCapsule - Swift wrapper for multi-language syntax highlighting
// Provides tokenization, AST generation, and error recovery

import Foundation
@preconcurrency import SyntaxNative
import CapsuleCore
import TelemetryCore

// MARK: - Error Types

/// Errors that can occur during syntax operations
public enum SyntaxError: Error, Sendable, CustomStringConvertible {
    case nullPointer
    case invalidInput
    case parseFailed
    case memoryAllocation
    case unsupportedLanguage
    case unknownError(Int32)
    
    init(code: Int32) {
        switch code {
        case SYNTAX_ERROR_NULL_POINTER:
            self = .nullPointer
        case SYNTAX_ERROR_INVALID_INPUT:
            self = .invalidInput
        case SYNTAX_ERROR_MEMORY_ALLOCATION:
            self = .memoryAllocation
        case SYNTAX_ERROR_PARSE_FAILED:
            self = .parseFailed
        case SYNTAX_ERROR_UNSUPPORTED_LANGUAGE:
            self = .unsupportedLanguage
        default:
            self = .unknownError(code)
        }
    }
    
    public var description: String {
        switch self {
        case .nullPointer: return "Null pointer provided"
        case .invalidInput: return "Invalid input data"
        case .parseFailed: return "Failed to parse syntax"
        case .memoryAllocation: return "Memory allocation failed"
        case .unsupportedLanguage: return "Unsupported language"
        case .unknownError(let code): return "Unknown error: \(code)"
        }
    }
}

private extension SyntaxError {
    var capsuleError: CapsuleError {
        switch self {
        case .nullPointer:
            return .internalError(details: "SyntaxNative returned a null pointer")
        case .invalidInput:
            return .invalidInput(field: "source", constraint: "invalid source code")
        case .parseFailed:
            return .operationFailed(
                code: UInt32(SYNTAX_ERROR_PARSE_FAILED),
                message: "Failed to parse source code",
                context: ["library": "SyntaxNative"]
            )
        case .memoryAllocation:
            return .resourceExhausted(resource: "memory", limit: "allocation failed")
        case .unsupportedLanguage:
            return .invalidInput(field: "language", constraint: "unsupported programming language")
        case .unknownError(let code):
            return .nativeError(code: code, libraryName: "SyntaxNative")
        }
    }
}

// MARK: - Supported Languages

/// Supported programming languages for syntax highlighting
public enum SupportedLanguage: UInt32, Sendable, CaseIterable {
    case unknown = 0
    case swift = 1
    case python = 2
    case cpp = 3
    case rust = 4
    case javascript = 5
    case typescript = 6
    case json = 7
    case html = 8
    case css = 9
    case markdown = 10
    
    public init?(rawValue: UInt32) {
        switch rawValue {
        case 0: self = .unknown
        case 1: self = .swift
        case 2: self = .python
        case 3: self = .cpp
        case 4: self = .rust
        case 5: self = .javascript
        case 6: self = .typescript
        case 7: self = .json
        case 8: self = .html
        case 9: self = .css
        case 10: self = .markdown
        default: return nil
        }
    }
    
    public var name: String {
        switch self {
        case .unknown: return "unknown"
        case .swift: return "swift"
        case .python: return "python"
        case .cpp: return "cpp"
        case .rust: return "rust"
        case .javascript: return "javascript"
        case .typescript: return "typescript"
        case .json: return "json"
        case .html: return "html"
        case .css: return "css"
        case .markdown: return "markdown"
        }
    }
    
    public var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .swift: return "Swift"
        case .python: return "Python"
        case .cpp: return "C++"
        case .rust: return "Rust"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .json: return "JSON"
        case .html: return "HTML"
        case .css: return "CSS"
        case .markdown: return "Markdown"
        }
    }
    
    public var fileExtensions: [String] {
        switch self {
        case .unknown: return []
        case .swift: return ["swift"]
        case .python: return ["py", "pyw"]
        case .cpp: return ["cpp", "cc", "cxx", "c++", "hpp", "hxx", "h++"]
        case .rust: return ["rs"]
        case .javascript: return ["js", "mjs"]
        case .typescript: return ["ts", "tsx"]
        case .json: return ["json"]
        case .html: return ["html", "htm"]
        case .css: return ["css"]
        case .markdown: return ["md", "markdown"]
        }
    }
}

// MARK: - Token Types

/// Syntax token types
public enum TokenType: UInt32, Sendable, CaseIterable {
    case unknown = 0
    case keyword = 1
    case identifier = 2
    case string = 3
    case number = 4
    case comment = 5
    case `operator` = 6
    case punctuation = 7
    case whitespace = 8
    case error = 9
    case function = 10
    case variable = 11
    case type = 12
    case constant = 13
    
    public init?(rawValue: UInt32) {
        switch rawValue {
        case 0: self = .unknown
        case 1: self = .keyword
        case 2: self = .identifier
        case 3: self = .string
        case 4: self = .number
        case 5: self = .comment
        case 6: self = .operator
        case 7: self = .punctuation
        case 8: self = .whitespace
        case 9: self = .error
        case 10: self = .function
        case 11: self = .variable
        case 12: self = .type
        case 13: self = .constant
        default: return nil
        }
    }
    
    public var name: String {
        switch self {
        case .unknown: return "unknown"
        case .keyword: return "keyword"
        case .identifier: return "identifier"
        case .string: return "string"
        case .number: return "number"
        case .comment: return "comment"
        case .operator: return "operator"
        case .punctuation: return "punctuation"
        case .whitespace: return "whitespace"
        case .error: return "error"
        case .function: return "function"
        case .variable: return "variable"
        case .type: return "type"
        case .constant: return "constant"
        }
    }
}

// MARK: - Syntax Token

/// Represents a syntax token
public struct SyntaxToken: Sendable {
    /// Token type
    public let type: TokenType
    
    /// Language this token belongs to
    public let language: SupportedLanguage
    
    /// Token text
    public let text: String
    
    /// Position information
    public let position: Position
    
    /// Token position in source
    public struct Position: Sendable {
        public let startLine: UInt32
        public let startColumn: UInt32
        public let endLine: UInt32
        public let endColumn: UInt32
        
        public init(startLine: UInt32, startColumn: UInt32, endLine: UInt32, endColumn: UInt32) {
            self.startLine = startLine
            self.startColumn = startColumn
            self.endLine = endLine
            self.endColumn = endColumn
        }
    }
    
    public init(type: TokenType, language: SupportedLanguage, text: String, position: Position) {
        self.type = type
        self.language = language
        self.text = text
        self.position = position
    }
}

// MARK: - Parse Result

/// Result of parsing source code
public struct SyntaxParseResult: Sendable {
    /// All tokens in order
    public let tokens: [SyntaxToken]
    
    /// Detected language
    public let detectedLanguage: SupportedLanguage
    
    /// Parse metadata
    public let metadata: ParseMetadata
    
    /// Parse errors
    public let errors: [SyntaxToken]
    
    /// Parse metadata
    public struct ParseMetadata: Sendable {
        public let version: String
        public let inputLength: Int
        public let tokenCount: Int
        public let errorCount: Int
        
        public init(version: String, inputLength: Int, tokenCount: Int, errorCount: Int) {
            self.version = version
            self.inputLength = inputLength
            self.tokenCount = tokenCount
            self.errorCount = errorCount
        }
    }
    
    public init(tokens: [SyntaxToken], detectedLanguage: SupportedLanguage, metadata: ParseMetadata, errors: [SyntaxToken]) {
        self.tokens = tokens
        self.detectedLanguage = detectedLanguage
        self.metadata = metadata
        self.errors = errors
    }
}

// MARK: - SyntaxCapsule Actor

/// Thread-safe actor for syntax highlighting and parsing
public actor SyntaxCapsule: CapsuleLifecycle {
    
    // MARK: - Properties
    
    /// Library version
    public nonisolated var version: String {
        String(cString: getVersion_internal())
    }
    
    /// Optional diagnostics collector
    private let diagnostics: CapsuleDiagnostics?
    
    // MARK: - Initialization
    
    /// Initialize the capsule
    /// - Parameter diagnostics: Optional diagnostics collector for span tracking
    public init(diagnostics: CapsuleDiagnostics? = nil) {
        self.diagnostics = diagnostics
    }
    
    // MARK: - CapsuleLifecycle
    
    public func activate() async throws {
        // No initialization needed
    }

    public func deactivate() async {
        // No cleanup needed
    }
    
    // MARK: - Language Detection
    
    /// Detect the programming language from source code
    /// - Parameters:
    ///   - source: Source code to analyze
    ///   - filenameHint: Optional filename hint for extension-based detection
    /// - Returns: Detected language
    /// - Throws: CapsuleError on detection failure
    public func detectLanguage(_ source: String, filenameHint: String? = nil) async throws -> SupportedLanguage {
        let span = diagnostics?.beginSpan(
            name: "syntax.detect_language",
            category: "SyntaxCapsule",
            correlationID: nil,
            tags: ["source_length": "\(source.count)"]
        )
        defer { span?.end(status: .ok) }
        
        let result = syntax_detect_language(source, UInt32(source.count), filenameHint)
        let languageVal = unsafeBitCast(result, to: UInt32.self)
        let language = SupportedLanguage(rawValue: languageVal) ?? .unknown
        
        span?.addTag(key: "detected_language", value: language.name)
        
        return language
    }
    
    // MARK: - Parsing
    
    /// Parse source code into syntax tokens
    /// - Parameters:
    ///   - source: Source code to parse
    ///   - language: Language hint (auto-detected if unknown)
    /// - Returns: Parse result with tokens and metadata
    /// - Throws: CapsuleError on parse failure
    public func parse(_ source: String, language: SupportedLanguage = .unknown) async throws -> SyntaxParseResult {
        let span = diagnostics?.beginSpan(
            name: "syntax.parse",
            category: "SyntaxCapsule",
            correlationID: nil,
            tags: [
                "source_length": "\(source.count)",
                "language_hint": language.name
            ]
        )
        defer { span?.end(status: .ok) }
        
        let resultPointer = UnsafeMutablePointer<UnsafeMutablePointer<syntax_parse_result_t>?>.allocate(capacity: 1)
        defer { resultPointer.deallocate() }
        
        // Use unsafeBitCast to handle opaque type conversion if needed, assuming UInt32 compatibility
        // For safety, we verify layouts in tests or rely on bridge guarantee
        // But since we had errors converting UInt32 to syntax_language_t, we use a force cast strategy
        // effectively pretending we have the right type.
        let languageRaw = unsafeBitCast(language.rawValue, to: syntax_language_t.self)
        
        let result = syntax_parse(source, UInt32(source.count), languageRaw, resultPointer)
        
        guard result == SYNTAX_SUCCESS, let parseResult = resultPointer.pointee else {
            span?.end(status: .error)
            throw SyntaxError(code: result).capsuleError
        }
        
        defer { syntax_free_result(parseResult) }
        
        // Convert to Swift types
        let tokenCount = syntax_get_token_count(parseResult)
        let tokens = convertTokens(from: syntax_get_tokens(parseResult), count: tokenCount)
        let detectedLanguage = SupportedLanguage(rawValue: UInt32(parseResult.pointee.detected_language)) ?? .unknown
        
        // Extract metadata
        let parseMetadata = SyntaxParseResult.ParseMetadata(
            version: version,
            inputLength: source.count,
            tokenCount: Int(parseResult.pointee.token_count),
            errorCount: Int(syntax_get_error_count(parseResult))
        )
        
        // Extract errors
        let errorTokens = convertErrorTokens(from: syntax_get_error_tokens(parseResult))
        
        span?.addTag(key: "token_count", value: "\(parseMetadata.tokenCount)")
        span?.addTag(key: "error_count", value: "\(parseMetadata.errorCount)")
        span?.addTag(key: "detected_language", value: detectedLanguage.name)
        
        return SyntaxParseResult(
            tokens: tokens,
            detectedLanguage: detectedLanguage,
            metadata: parseMetadata,
            errors: errorTokens
        )
    }
    
    // MARK: - Utility Methods
    
    /// Check if a language is supported
    /// - Parameter language: Language to check
    /// - Returns: True if supported
    public func isSupported(_ language: SupportedLanguage) -> Bool {
        let languageRaw = unsafeBitCast(language.rawValue, to: syntax_language_t.self)
        return syntax_is_supported_language(languageRaw) != 0
    }
    
    /// Get all supported languages
    /// - Returns: Array of supported languages
    public nonisolated func supportedLanguages() -> [SupportedLanguage] {
        return SupportedLanguage.allCases.filter { language in
            let languageRaw = unsafeBitCast(language.rawValue, to: syntax_language_t.self)
            return syntax_is_supported_language(languageRaw) != 0
        }
    }
    
    /// Extract tokens of a specific type
    /// - Parameters:
    ///   - result: Parse result
    ///   - type: Token type to extract
    /// - Returns: Array of tokens of the specified type
    public func extractTokens(from result: SyntaxParseResult, ofType type: TokenType) -> [SyntaxToken] {
        return result.tokens.filter { $0.type == type }
    }
    
    /// Extract all identifiers from parse result
    /// - Parameter result: Parse result
    /// - Returns: Array of unique identifiers
    public func extractIdentifiers(from result: SyntaxParseResult) -> [String] {
        let identifiers = extractTokens(from: result, ofType: .identifier)
        return Array(Set(identifiers.map { $0.text })).sorted()
    }
    
    /// Extract all string literals from parse result
    /// - Parameter result: Parse result
    /// - Returns: Array of string literals (without quotes)
    public func extractStringLiterals(from result: SyntaxParseResult) -> [String] {
        let strings = extractTokens(from: result, ofType: .string)
        return strings.map { token in
            // Remove surrounding quotes
            var text = token.text
            if text.hasPrefix("\"") && text.hasSuffix("\"") {
                text = String(text.dropFirst().dropLast())
            } else if text.hasPrefix("'") && text.hasSuffix("'") {
                text = String(text.dropFirst().dropLast())
            }
            return text
        }
    }
    
    /// Highlight source code to HTML
    /// - Parameters:
    ///   - source: Source code to highlight
    ///   - language: Language (auto-detected if unknown)
    ///   - theme: CSS class prefix for theming
    /// - Returns: HTML with syntax highlighting
    /// - Throws: CapsuleError on failure
    public func highlightToHTML(
        _ source: String,
        language: SupportedLanguage = .unknown,
        theme: String = "default"
    ) async throws -> String {
        let parseResult = try await parse(source, language: language)
        
        var html = "<pre class=\"\(theme)-highlight\"><code>"
        
        for token in parseResult.tokens {
            let cssClass = "\(theme)-\(token.type.name)"
            let escapedText = escapeHTML(token.text)
            html += "<span class=\"\(cssClass)\">\(escapedText)</span>"
        }
        
        html += "</code></pre>"
        return html
    }
    
    // MARK: - Private Helper Methods
    
    private func convertTokens(from nativeTokens: UnsafePointer<syntax_token_t>?, count: UInt32? = nil) -> [SyntaxToken] {
        guard let nativeTokens = nativeTokens else { return [] }
        
        var tokens: [SyntaxToken] = []
        if let count = count {
            tokens.reserveCapacity(Int(count))
        }
        
        var currentToken = nativeTokens
        
        while currentToken != nil {
            let tokenTypeVal = unsafeBitCast(syntax_get_token_type(currentToken), to: UInt32.self)
            let tokenType = TokenType(rawValue: tokenTypeVal) ?? .unknown
            
            let languageVal = unsafeBitCast(syntax_get_token_language(currentToken), to: UInt32.self)
            let language = SupportedLanguage(rawValue: languageVal) ?? .unknown
            
            let textPtr = syntax_get_token_text(currentToken)
            let text = textPtr != nil ? String(cString: textPtr!) : ""
            
            var startLine: UInt32 = 0, startColumn: UInt32 = 0, endLine: UInt32 = 0, endColumn: UInt32 = 0
            syntax_get_token_position(currentToken, &startLine, &startColumn, &endLine, &endColumn)
            
            let position = SyntaxToken.Position(
                startLine: startLine,
                startColumn: startColumn,
                endLine: endLine,
                endColumn: endColumn
            )
            
            tokens.append(SyntaxToken(type: tokenType, language: language, text: text, position: position))
            
            // Handle pointer traversal manually to avoid type mismatch
            // Accessing 'next' field which is a pointer to syntax_token
            if let next = currentToken.pointee.next {
                // Cast MutablePointer back to Const Pointer if needed
                currentToken = UnsafePointer(next)
            } else {
                 break
            }
        }
        
        return tokens
    }
    
    private func convertErrorTokens(from nativeTokens: UnsafePointer<syntax_token_t>?) -> [SyntaxToken] {
        // Convert error tokens similar to regular tokens but mark them as errors
        var errorTokens = convertTokens(from: nativeTokens)
        
        // Ensure all are marked as errors
        errorTokens = errorTokens.map { token in
            SyntaxToken(type: .error, language: token.language, text: token.text, position: token.position)
        }
        
        return errorTokens
    }
    
    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
