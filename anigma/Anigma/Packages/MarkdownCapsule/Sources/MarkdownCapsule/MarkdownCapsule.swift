// MarkdownCapsule.swift
// MarkdownCapsule - Swift wrapper for CommonMark parsing
// Provides full AST generation, visitor pattern, and multi-format rendering

import Foundation
@preconcurrency import MarkdownNative
import CapsuleCore
import TelemetryCore

// MARK: - Error Types

/// Errors that can occur during markdown operations
public enum MarkdownError: Error, Sendable, CustomStringConvertible {
    case nullPointer
    case invalidInput
    case parseFailed
    case memoryAllocation
    case renderFailed
    case validationFailed(String)
    case unknownError(Int32)
    
    init(code: Int32) {
        switch code {
        case MARKDOWN_ERROR_NULL_POINTER:
            self = .nullPointer
        case MARKDOWN_ERROR_INVALID_INPUT:
            self = .invalidInput
        case MARKDOWN_ERROR_MEMORY_ALLOCATION:
            self = .memoryAllocation
        case MARKDOWN_ERROR_PARSE_FAILED:
            self = .parseFailed
        default:
            self = .unknownError(code)
        }
    }
    
    public var description: String {
        switch self {
        case .nullPointer: return "Null pointer provided"
        case .invalidInput: return "Invalid input data"
        case .parseFailed: return "Failed to parse markdown"
        case .memoryAllocation: return "Memory allocation failed"
        case .renderFailed: return "Failed to render output"
        case .validationFailed(let message): return "Validation failed: \(message)"
        case .unknownError(let code): return "Unknown error: \(code)"
        }
    }
}

private extension MarkdownError {
    var capsuleError: CapsuleError {
        switch self {
        case .nullPointer:
            return .internalError(details: "MarkdownNative returned a null pointer")
        case .invalidInput:
            return .invalidInput(field: "markdown", constraint: "invalid markdown input")
        case .parseFailed:
            return .operationFailed(
                code: UInt32(MARKDOWN_ERROR_PARSE_FAILED),
                message: "Failed to parse markdown",
                context: ["library": "MarkdownNative"]
            )
        case .memoryAllocation:
            return .resourceExhausted(resource: "memory", limit: "allocation failed")
        case .renderFailed:
            return .operationFailed(
                code: UInt32(MARKDOWN_ERROR_PARSE_FAILED),
                message: "Failed to render markdown",
                context: ["library": "MarkdownNative"]
            )
        case .validationFailed(let message):
            return .invalidInput(field: "markdown", constraint: message)
        case .unknownError(let code):
            return .nativeError(code: code, libraryName: "MarkdownNative")
        }
    }
}

// MARK: - Node Types

/// Markdown AST node types
public enum MarkdownNodeType: UInt32, Sendable, CaseIterable {
    case document = 0
    case blockQuote
    case list
    case item
    case codeBlock
    case htmlBlock
    case paragraph
    case header
    case hrule
    case text
    case softbreak
    case linebreak
    case code
    case htmlInline
    case emphasis
    case strong
    case link
    case image
    case textual
    
    public init?(rawValue: UInt32) {
        switch rawValue {
        case 0: self = .document
        case 1: self = .blockQuote
        case 2: self = .list
        case 3: self = .item
        case 4: self = .codeBlock
        case 5: self = .htmlBlock
        case 6: self = .paragraph
        case 7: self = .header
        case 8: self = .hrule
        case 9: self = .text
        case 10: self = .softbreak
        case 11: self = .linebreak
        case 12: self = .code
        case 13: self = .htmlInline
        case 14: self = .emphasis
        case 15: self = .strong
        case 16: self = .link
        case 17: self = .image
        case 18: self = .textual
        default: return nil
        }
    }
    
    public var name: String {
        switch self {
        case .document: return "document"
        case .blockQuote: return "blockquote"
        case .list: return "list"
        case .item: return "item"
        case .codeBlock: return "code_block"
        case .htmlBlock: return "html_block"
        case .paragraph: return "paragraph"
        case .header: return "header"
        case .hrule: return "hrule"
        case .text: return "text"
        case .softbreak: return "softbreak"
        case .linebreak: return "linebreak"
        case .code: return "code"
        case .htmlInline: return "html_inline"
        case .emphasis: return "emphasis"
        case .strong: return "strong"
        case .link: return "link"
        case .image: return "image"
        case .textual: return "textual"
        }
    }
}

// MARK: - Render Formats

/// Output formats for markdown rendering
public enum MarkdownRenderFormat: UInt32, Sendable, CaseIterable {
    case html = 0
    case xml
    case man
    case commonmark
    case plainText
    
    public var name: String {
        switch self {
        case .html: return "html"
        case .xml: return "xml"
        case .man: return "man"
        case .commonmark: return "commonmark"
        case .plainText: return "plain_text"
        }
    }
    
    public var mimeType: String {
        switch self {
        case .html: return "text/html"
        case .xml: return "application/xml"
        case .man: return "text/troff"
        case .commonmark: return "text/markdown"
        case .plainText: return "text/plain"
        }
    }
}

// MARK: - AST Node

/// Represents a node in the markdown AST
public struct MarkdownNode: Sendable {
    /// Node type
    public let type: MarkdownNodeType
    
    /// Text content (if any)
    public let content: String?
    
    /// Position information
    public let position: Position?
    
    /// Children nodes
    public let children: [MarkdownNode]
    
    /// Node position in source
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
    
    public init(type: MarkdownNodeType, content: String? = nil, position: Position? = nil, children: [MarkdownNode] = []) {
        self.type = type
        self.content = content
        self.position = position
        self.children = children
    }
}

// MARK: - Markdown Document

/// Represents a parsed markdown document
public struct MarkdownDocument: Sendable {
    /// Root node of the AST
    public let root: MarkdownNode
    
    /// Document metadata
    public let metadata: DocumentMetadata
    
    /// Document statistics
    public let statistics: DocumentStatistics
    
    /// Document metadata
    public struct DocumentMetadata: Sendable {
        public let version: String
        public let inputLength: Int
        public let nodeCount: Int
        
        public init(version: String, inputLength: Int, nodeCount: Int) {
            self.version = version
            self.inputLength = inputLength
            self.nodeCount = nodeCount
        }
    }
    
    /// Document statistics
    public struct DocumentStatistics: Sendable {
        public let paragraphCount: Int
        public let linkCount: Int
        public let imageCount: Int
        public let headerCount: Int
        public let codeBlockCount: Int
        
        public init(paragraphCount: Int, linkCount: Int, imageCount: Int, headerCount: Int, codeBlockCount: Int) {
            self.paragraphCount = paragraphCount
            self.linkCount = linkCount
            self.imageCount = imageCount
            self.headerCount = headerCount
            self.codeBlockCount = codeBlockCount
        }
    }
    
    public init(root: MarkdownNode, metadata: DocumentMetadata, statistics: DocumentStatistics) {
        self.root = root
        self.metadata = metadata
        self.statistics = statistics
    }
}

// MARK: - Visitor Pattern

/// Protocol for visiting markdown AST nodes
public protocol MarkdownVisitor: Sendable {
    /// Visit a node
    func visit(node: MarkdownNode) -> MarkdownVisitResult
    
    /// Enter a node (before visiting children)
    func enter(node: MarkdownNode) -> MarkdownVisitResult
    
    /// Leave a node (after visiting children)
    func leave(node: MarkdownNode) -> MarkdownVisitResult
}

/// Result of visiting a node
public enum MarkdownVisitResult: Sendable {
    case continueVisit
    case skipChildren
    case stopVisit
}

// MARK: - Syntax Highlighting

/// Syntax highlighting configuration
public struct SyntaxHighlighting: Sendable {
    public let enabled: Bool
    public let languages: Set<String>
    public let theme: String
    
    public init(enabled: Bool = true, languages: Set<String> = [], theme: String = "default") {
        self.enabled = enabled
        self.languages = languages
        self.theme = theme
    }
}

// MARK: - MarkdownCapsule Actor

/// Thread-safe actor for parsing and rendering markdown
public actor MarkdownCapsule {
    
    // MARK: - Properties
    
    /// Library version
    public nonisolated var version: String {
        String(cString: getVersion())
    }
    
    /// Optional diagnostics collector
    private let diagnostics: CapsuleDiagnostics?
    
    /// Syntax highlighting configuration
    private let syntaxHighlighting: SyntaxHighlighting
    
    // MARK: - Initialization
    
    /// Initialize the capsule
    /// - Parameters:
    ///   - syntaxHighlighting: Configuration for syntax highlighting
    ///   - diagnostics: Optional diagnostics collector for span tracking
    public init(
        syntaxHighlighting: SyntaxHighlighting = SyntaxHighlighting(),
        diagnostics: CapsuleDiagnostics? = nil
    ) {
        self.syntaxHighlighting = syntaxHighlighting
        self.diagnostics = diagnostics
    }
    
    // MARK: - Parsing
    
    /// Parse markdown text into an AST
    /// - Parameter markdown: Markdown text to parse
    /// - Returns: Parsed document with AST and metadata
    /// - Throws: CapsuleError on parse failure
    public func parse(_ markdown: String) async throws -> MarkdownDocument {
        let span = diagnostics?.beginSpan(
            name: "markdown.parse",
            category: "MarkdownCapsule",
            tags: ["input_length": "\(markdown.count)"]
        )
        defer { span?.end(status: .ok) }
        
        let documentPointer = UnsafeMutablePointer<UnsafeMutablePointer<markdown_document_t>?>.allocate(capacity: 1)
        defer { documentPointer.deallocate() }
        
        let result = markdown_parse(markdown, UInt32(markdown.count), documentPointer)
        
        guard result == MARKDOWN_SUCCESS, let document = documentPointer.pointee else {
            span?.end(status: .error)
            throw MarkdownError(code: result).capsuleError
        }
        
        defer { markdown_free_document(document) }
        
        // Convert to Swift types
        let rootNode = convertNode(from: markdown_get_root(document))
        
        // Extract metadata
        let metadataJSON = String(cString: document.pointee.metadata)
        let docMetadata = DocumentMetadata(
            version: version,
            inputLength: markdown.count,
            nodeCount: Int(document.pointee.node_count)
        )
        
        // Calculate statistics
        let statistics = calculateStatistics(root: rootNode)
        
        span?.addTag(key: "node_count", value: "\(docMetadata.nodeCount)")
        
        return MarkdownDocument(root: rootNode, metadata: docMetadata, statistics: statistics)
    }
    
    /// Validate markdown syntax
    /// - Parameter markdown: Markdown text to validate
    /// - Throws: CapsuleError if validation fails
    public func validate(_ markdown: String) async throws {
        let span = diagnostics?.beginSpan(
            name: "markdown.validate",
            category: "MarkdownCapsule",
            tags: ["input_length": "\(markdown.count)"]
        )
        defer { span?.end(status: .ok) }
        
        let errorPointer = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: 1)
        defer { errorPointer.deallocate() }
        
        let result = markdown_validate_syntax(markdown, UInt32(markdown.count), errorPointer)
        
        if result != MARKDOWN_SUCCESS, let errorString = errorPointer.pointee {
            defer { free(errorString) }
            span?.end(status: .error)
            throw MarkdownError.validationFailed(String(cString: errorString)).capsuleError
        }
    }
    
    // MARK: - Rendering
    
    /// Render a markdown document to the specified format
    /// - Parameters:
    ///   - document: Parsed markdown document
    ///   - format: Output format
    /// - Returns: Rendered output
    /// - Throws: CapsuleError on render failure
    public func render(
        document: MarkdownDocument,
        to format: MarkdownRenderFormat
    ) async throws -> String {
        let span = diagnostics?.beginSpan(
            name: "markdown.render",
            category: "MarkdownCapsule",
            tags: ["format": format.name]
        )
        defer { span?.end(status: .ok) }
        
        // For now, we'll use a simple rendering approach
        // In a full implementation, we'd convert back to native format
        switch format {
        case .html:
            return renderToHTML(document: document)
        case .plainText:
            return renderToPlainText(document: document)
        default:
            span?.end(status: .error)
            throw CapsuleError.operationFailed(
                code: UInt32(MARKDOWN_ERROR_PARSE_FAILED),
                message: "Format \(format.name) not yet implemented",
                context: ["format": format.name]
            )
        }
    }
    
    /// Parse and render in one operation
    /// - Parameters:
    ///   - markdown: Markdown text to parse
    ///   - format: Output format
    /// - Returns: Rendered output
    /// - Throws: CapsuleError on failure
    public func parseAndRender(
        _ markdown: String,
        to format: MarkdownRenderFormat
    ) async throws -> String {
        let document = try await parse(markdown)
        return try await render(document: document, to: format)
    }
    
    // MARK: - AST Operations
    
    /// Visit nodes in the AST using the visitor pattern
    /// - Parameters:
    ///   - document: Parsed document
    ///   - visitor: Visitor implementation
    /// - Returns: Whether the visit completed successfully
    public func visit(document: MarkdownDocument, using visitor: MarkdownVisitor) async -> Bool {
        return await visitNode(document.root, using: visitor)
    }
    
    /// Extract all links from a document
    /// - Parameter document: Parsed document
    /// - Returns: Array of link URLs
    public func extractLinks(from document: MarkdownDocument) async -> [String] {
        var links: [String] = []
        
        class LinkExtractor: MarkdownVisitor {
            var links: [String] = []
            
            func visit(node: MarkdownNode) -> MarkdownVisitResult {
                if node.type == .link, let content = node.content {
                    links.append(content)
                }
                return .continueVisit
            }
            
            func enter(node: MarkdownNode) -> MarkdownVisitResult { .continueVisit }
            func leave(node: MarkdownNode) -> MarkdownVisitResult { .continueVisit }
        }
        
        let extractor = LinkExtractor()
        _ = await visit(document: document, using: extractor)
        return extractor.links
    }
    
    // MARK: - Private Helper Methods
    
    private func convertNode(from nativeNode: UnsafePointer<markdown_node_t>?) -> MarkdownNode {
        guard let nativeNode = nativeNode else {
            return MarkdownNode(type: .document)
        }
        
        let type = MarkdownNodeType(rawValue: markdown_get_node_type(nativeNode)) ?? .document
        
        var content: String?
        let contentPtr = markdown_get_node_content(nativeNode)
        if let contentPtr = contentPtr {
            content = String(cString: contentPtr)
        }
        
        var position: MarkdownNode.Position?
        var startLine: UInt32 = 0, startColumn: UInt32 = 0, endLine: UInt32 = 0, endColumn: UInt32 = 0
        markdown_get_position(nativeNode, &startLine, &startColumn, &endLine, &endColumn)
        
        if startLine > 0 || startColumn > 0 || endLine > 0 || endColumn > 0 {
            position = MarkdownNode.Position(
                startLine: startLine,
                startColumn: startColumn,
                endLine: endLine,
                endColumn: endColumn
            )
        }
        
        var children: [MarkdownNode] = []
        var child = markdown_get_first_child(nativeNode)
        while let childPtr = child {
            children.append(convertNode(from: childPtr))
            child = markdown_get_next_sibling(childPtr)
        }
        
        return MarkdownNode(type: type, content: content, position: position, children: children)
    }
    
    private func calculateStatistics(root: MarkdownNode) -> MarkdownDocument.DocumentStatistics {
        var paragraphCount = 0
        var linkCount = 0
        var imageCount = 0
        var headerCount = 0
        var codeBlockCount = 0
        
        func countNodes(_ node: MarkdownNode) {
            switch node.type {
            case .paragraph: paragraphCount += 1
            case .link: linkCount += 1
            case .image: imageCount += 1
            case .header: headerCount += 1
            case .codeBlock: codeBlockCount += 1
            default: break
            }
            
            node.children.forEach(countNodes)
        }
        
        countNodes(root)
        
        return MarkdownDocument.DocumentStatistics(
            paragraphCount: paragraphCount,
            linkCount: linkCount,
            imageCount: imageCount,
            headerCount: headerCount,
            codeBlockCount: codeBlockCount
        )
    }
    
    private func visitNode(_ node: MarkdownNode, using visitor: MarkdownVisitor) async -> Bool {
        let enterResult = visitor.enter(node: node)
        
        guard enterResult != .stopVisit else { return false }
        
        if enterResult != .skipChildren {
            let visitResult = visitor.visit(node: node)
            guard visitResult != .stopVisit else { return false }
            
            if visitResult != .skipChildren {
                for child in node.children {
                    let shouldContinue = await visitNode(child, using: visitor)
                    guard shouldContinue else { return false }
                }
            }
        }
        
        let leaveResult = visitor.leave(node: node)
        return leaveResult != .stopVisit
    }
    
    private func renderToHTML(document: MarkdownDocument) -> String {
        // Simple HTML rendering
        func renderNode(_ node: MarkdownNode) -> String {
            switch node.type {
            case .document:
                return node.children.map(renderNode).joined()
            case .paragraph:
                return "<p>\(node.children.map(renderNode).joined())</p>"
            case .text:
                return node.content ?? ""
            case .emphasis:
                return "<em>\(node.children.map(renderNode).joined())</em>"
            case .strong:
                return "<strong>\(node.children.map(renderNode).joined())</strong>"
            case .code:
                return "<code>\(node.content ?? "")</code>"
            case .link:
                let href = node.content ?? "#"
                let text = node.children.map(renderNode).joined()
                return "<a href=\"\(href)\">\(text)</a>"
            case .image:
                let src = node.content ?? ""
                let alt = node.children.map(renderNode).joined()
                return "<img src=\"\(src)\" alt=\"\(alt)\">"
            case .header:
                let level = node.children.first?.type == .text ? 1 : 2
                let text = node.children.map(renderNode).joined()
                return "<h\(level)>\(text)</h\(level)>"
            case .codeBlock:
                return "<pre><code>\(node.content ?? "")</code></pre>"
            default:
                return node.children.map(renderNode).joined()
            }
        }
        
        return renderNode(document.root)
    }
    
    private func renderToPlainText(document: MarkdownDocument) -> String {
        // Simple plain text rendering
        func renderNode(_ node: MarkdownNode) -> String {
            switch node.type {
            case .document:
                return node.children.map(renderNode).joined()
            case .paragraph:
                return node.children.map(renderNode).joined() + "\n\n"
            case .text:
                return node.content ?? ""
            case .emphasis, .strong, .code, .link, .image:
                return node.children.map(renderNode).joined()
            case .header:
                return node.children.map(renderNode).joined() + "\n\n"
            case .codeBlock:
                return (node.content ?? "") + "\n\n"
            case .linebreak:
                return "\n"
            case .softbreak:
                return " "
            default:
                return node.children.map(renderNode).joined()
            }
        }
        
        return renderNode(document.root).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - CapsuleCore Integration

extension MarkdownCapsule: CapsuleLifecycle {
    public func activate() async throws {
        // No initialization needed
    }

    public func deactivate() async {
        // No cleanup needed
    }
}