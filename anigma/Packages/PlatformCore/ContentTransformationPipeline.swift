//
//  ContentTransformationPipeline.swift
//  PlatformCore
//
//  Content transformation pipeline for Phase 8.5
//

import Foundation

// MARK: - Content Format Types

/// Represents different content format types supported by the pipeline
public enum ContentFormatType: String, Codable, Sendable {
    case markdown = "markdown"
    case html = "html"
    case plainText = "plainText"
    case json = "json"
    case xml = "xml"
    case yaml = "yaml"
    case pdf = "pdf"
    case docx = "docx"
    case epub = "epub"
}

/// Configuration for content transformation
public struct TransformationConfig: Codable, Sendable {
    public let sourceFormat: ContentFormatType
    public let targetFormat: ContentFormatType
    public let preserveFormatting: Bool
    public let options: [String: String]

    public init(sourceFormat: ContentFormatType, targetFormat: ContentFormatType, preserveFormatting: Bool = true, options: [String: String] = [:]) {
        self.sourceFormat = sourceFormat
        self.targetFormat = targetFormat
        self.preserveFormatting = preserveFormatting
        self.options = options
    }
}

/// Result of a content transformation
public struct TransformationResult: Codable, Sendable {
    public let id: String
    public let sourceFormat: ContentFormatType
    public let targetFormat: ContentFormatType
    public let originalContent: String
    public let transformedContent: String
    public let metadata: [String: String]
    public let timestamp: Date

    public init(id: String = UUID().uuidString, sourceFormat: ContentFormatType, targetFormat: ContentFormatType, originalContent: String, transformedContent: String, metadata: [String: String] = [:], timestamp: Date = Date()) {
        self.id = id
        self.sourceFormat = sourceFormat
        self.targetFormat = targetFormat
        self.originalContent = originalContent
        self.transformedContent = transformedContent
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

// MARK: - Content Transformer Protocol

/// Protocol for implementing content transformers
public protocol ContentTransformer {
    /// Source format this transformer handles
    var sourceFormat: ContentFormatType { get }

    /// Target formats this transformer can produce
    var supportedTargets: [ContentFormatType] { get }

    /// Transform content from source to target format
    func transform(_ content: String, to targetFormat: ContentFormatType, options: [String: String]) throws -> String
}

// MARK: - Content Transformation Errors

public enum TransformationError: Error, LocalizedError {
    case unsupportedFormat(ContentFormatType)
    case transformationFailed(String)
    case invalidContent(String)
    case noTransformerAvailable(ContentFormatType, ContentFormatType)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format.rawValue)"
        case .transformationFailed(let message):
            return "Transformation failed: \(message)"
        case .invalidContent(let message):
            return "Invalid content: \(message)"
        case .noTransformerAvailable(let source, let target):
            return "No transformer available for \(source.rawValue) -> \(target.rawValue)"
        }
    }
}

// MARK: - Content Transformation Pipeline

/// Main pipeline for coordinating content transformations
public actor ContentTransformationPipeline {
    private var transformers: [ContentFormatType: any ContentTransformer] = [:]
    private var transformationCache: [String: TransformationResult] = [:]
    private var transformationHistory: [TransformationResult] = []

    public init() {}

    /// Register a content transformer
    public func register(_ transformer: any ContentTransformer) throws {
        transformers[transformer.sourceFormat] = transformer
    }

    /// Transform content using the pipeline
    public func transform(content: String, using config: TransformationConfig) async throws -> TransformationResult {
        // Check cache
        let cacheKey = "\(config.sourceFormat.rawValue)->\(config.targetFormat.rawValue)-\(content.hashValue)"
        if let cached = transformationCache[cacheKey] {
            return cached
        }

        // Find transformer
        guard let transformer = transformers[config.sourceFormat] else {
            throw TransformationError.noTransformerAvailable(config.sourceFormat, config.targetFormat)
        }

        // Validate transformer supports target format
        guard transformer.supportedTargets.contains(config.targetFormat) else {
            throw TransformationError.noTransformerAvailable(config.sourceFormat, config.targetFormat)
        }

        // Perform transformation
        let transformedContent = try transformer.transform(content, to: config.targetFormat, options: config.options)

        // Create result
        let result = TransformationResult(
            sourceFormat: config.sourceFormat,
            targetFormat: config.targetFormat,
            originalContent: content,
            transformedContent: transformedContent,
            metadata: ["cached": "false"]
        )

        // Cache result
        transformationCache[cacheKey] = result
        transformationHistory.append(result)

        return result
    }

    /// Get transformation history
    public var history: [TransformationResult] {
        transformationHistory
    }

    /// Clear transformation cache
    public func clearCache() {
        transformationCache.removeAll()
    }

    /// Get all supported format pairs
    public func supportedTransformations() -> [(source: ContentFormatType, targets: [ContentFormatType])] {
        transformers.map { key, transformer in
            (source: key, targets: transformer.supportedTargets)
        }
    }
}

// MARK: - Built-in Transformers

/// Transformer for Markdown to other formats
public struct MarkdownTransformer: ContentTransformer {
    public let sourceFormat: ContentFormatType = .markdown

    public var supportedTargets: [ContentFormatType] {
        [.html, .plainText, .json]
    }

    public func transform(_ content: String, to targetFormat: ContentFormatType, options: [String: String]) throws -> String {
        switch targetFormat {
        case .html:
            return transformMarkdownToHTML(content)
        case .plainText:
            return transformMarkdownToPlainText(content)
        case .json:
            return transformMarkdownToJSON(content)
        default:
            throw TransformationError.unsupportedFormat(targetFormat)
        }
    }

    private func transformMarkdownToHTML(_ markdown: String) -> String {
        var html = ""
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "# ") {
                let content = String(trimmed.dropFirst(2))
                html += "<h1>\(content)</h1>\n"
            } else if trimmed.starts(with: "## ") {
                let content = String(trimmed.dropFirst(3))
                html += "<h2>\(content)</h2>\n"
            } else if trimmed.starts(with: "- ") {
                let content = String(trimmed.dropFirst(2))
                html += "<li>\(content)</li>\n"
            } else if !trimmed.isEmpty {
                html += "<p>\(trimmed)</p>\n"
            }
        }

        return html
    }

    private func transformMarkdownToPlainText(_ markdown: String) -> String {
        let plainText = markdown
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "### ", with: "")
            .replacingOccurrences(of: "- ", with: "• ")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")

        return plainText
    }

    private func transformMarkdownToJSON(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n")

        var jsonDict: [String: Any] = [
            "type": "markdown_content",
            "sections": []
        ]

        var sections: [[String: String]] = []
        var currentSection: [String: String] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "# ") {
                if !currentSection.isEmpty {
                    sections.append(currentSection)
                }
                currentSection = ["type": "heading1", "content": String(trimmed.dropFirst(2))]
            } else if !trimmed.isEmpty {
                currentSection["content", default: ""] += trimmed + " "
            }
        }

        if !currentSection.isEmpty {
            sections.append(currentSection)
        }

        jsonDict["sections"] = sections

        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "{\"error\": \"Failed to serialize to JSON\"}"
    }
}

/// Transformer for HTML to other formats
public struct HTMLTransformer: ContentTransformer {
    public let sourceFormat: ContentFormatType = .html

    public var supportedTargets: [ContentFormatType] {
        [.plainText, .markdown]
    }

    public func transform(_ content: String, to targetFormat: ContentFormatType, options: [String: String]) throws -> String {
        switch targetFormat {
        case .plainText:
            return transformHTMLToPlainText(content)
        case .markdown:
            return transformHTMLToMarkdown(content)
        default:
            throw TransformationError.unsupportedFormat(targetFormat)
        }
    }

    private func transformHTMLToPlainText(_ html: String) -> String {
        // Remove HTML tags
        var plainText = html

        let patterns = [
            "<[^>]+>": "" // Remove all HTML tags
        ]

        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(plainText.startIndex..., in: plainText)
                plainText = regex.stringByReplacingMatches(in: plainText, range: range, withTemplate: replacement)
            }
        }

        // Decode HTML entities
        plainText = plainText
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        return plainText
    }

    private func transformHTMLToMarkdown(_ html: String) -> String {
        var markdown = ""
        let lines = html.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "<h1>"), trimmed.hasSuffix("</h1>") {
                let content = trimmed.replacingOccurrences(of: "<h1>", with: "").replacingOccurrences(of: "</h1>", with: "")
                markdown += "# \(content)\n"
            } else if trimmed.starts(with: "<p>"), trimmed.hasSuffix("</p>") {
                let content = trimmed.replacingOccurrences(of: "<p>", with: "").replacingOccurrences(of: "</p>", with: "")
                markdown += "\(content)\n\n"
            } else if trimmed.starts(with: "<li>"), trimmed.hasSuffix("</li>") {
                let content = trimmed.replacingOccurrences(of: "<li>", with: "").replacingOccurrences(of: "</li>", with: "")
                markdown += "- \(content)\n"
            }
        }

        return markdown
    }
}

// MARK: - Unified Content Bridge

/// Bridges internal content model with external formats
public actor UnifiedContentBridge {
    private let pipeline: ContentTransformationPipeline

    public init(pipeline: ContentTransformationPipeline) {
        self.pipeline = pipeline
    }

    /// Convert ContentDocument to external format
    public func exportDocument(_ document: ContentDocument, to format: ContentFormatType) async throws -> String {
        // Convert ContentDocument to markdown first (internal representation)
        let markdownContent = documentToMarkdown(document)

        // Transform to target format
        let config = TransformationConfig(
            sourceFormat: .markdown,
            targetFormat: format,
            preserveFormatting: true
        )

        let result = try await pipeline.transform(content: markdownContent, using: config)
        return result.transformedContent
    }

    /// Import content from external format to ContentDocument
    public func importContent(_ content: String, from format: ContentFormatType) async throws -> ContentDocument {
        // Transform to markdown (internal representation)
        let config = TransformationConfig(
            sourceFormat: format,
            targetFormat: .markdown,
            preserveFormatting: true
        )

        let result = try await pipeline.transform(content: content, using: config)

        // Parse markdown to ContentDocument
        return markdownToDocument(result.transformedContent)
    }

    // MARK: - Helper Methods

    private func documentToMarkdown(_ document: ContentDocument) -> String {
        var markdown = "# \(document.title)\n\n"

        for section in document.sections {
            markdown += sectionToMarkdown(section, level: 2)
        }

        return markdown
    }

    private func sectionToMarkdown(_ section: ContentSection, level: Int) -> String {
        var markdown = ""

        if let title = section.title {
            let prefix = String(repeating: "#", count: level)
            markdown += "\(prefix) \(title)\n\n"
        }

        markdown += nodeToMarkdown(section.content)
        markdown += "\n"

        for subsection in section.subsections {
            markdown += sectionToMarkdown(subsection, level: level + 1)
        }

        return markdown
    }

    private func nodeToMarkdown(_ node: ContentNode) -> String {
        switch node {
        case .text(let text):
            return text
        case .paragraph(let children):
            return children.map { nodeToMarkdown($0) }.joined(separator: " ") + "\n\n"
        case .heading(let level, let text):
            return String(repeating: "#", count: level) + " \(text)\n"
        case .list(let items, _):
            return items.map { "- \(nodeToMarkdown($0))" }.joined(separator: "\n") + "\n"
        case .code(let code, let lang):
            return "```\(lang ?? "")\n\(code)\n```\n"
        default:
            return ""
        }
    }

    private func markdownToDocument(_ markdown: String) -> ContentDocument {
        // Simple markdown parser
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        var title = "Untitled"
        let sections: [ContentSection] = []

        if let firstLine = lines.first, firstLine.starts(with: "#") {
            title = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }

        return ContentDocument(
            title: title,
            sections: sections,
            metadata: DocumentMetadata()
        )
    }
}
