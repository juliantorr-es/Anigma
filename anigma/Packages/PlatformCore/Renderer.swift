//
//  Renderer.swift
//  PlatformCore
//
//  Platform-agnostic renderer abstraction for Phase 8.1
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import AnigmaPrimitives

// MARK: - Core Content Model

/// Represents a piece of content that can be rendered across different platforms
public struct ContentDocument: Component, Codable, Sendable {
    public let id: EntityId
    public let title: String
    public let sections: [ContentSection]
    public let metadata: DocumentMetadata

    public init(id: EntityId = EntityId(), title: String, sections: [ContentSection], metadata: DocumentMetadata) {
        self.id = id
        self.title = title
        self.sections = sections
        self.metadata = metadata
    }
}

/// A section of content with hierarchical structure
public struct ContentSection: Codable, Sendable {
    public let id: EntityId
    public let title: String?
    public let level: Int
    public let content: ContentNode
    public let subsections: [ContentSection]

    public init(id: EntityId = EntityId(), title: String? = nil, level: Int = 1, content: ContentNode, subsections: [ContentSection] = []) {
        self.id = id
        self.title = title
        self.level = level
        self.content = content
        self.subsections = subsections
    }
}

/// Represents different types of content nodes
public enum ContentNode: Codable, Sendable {
    case text(String)
    case paragraph([ContentNode])
    case heading(Int, String) // level + text
    case list([ContentNode], ListType)
    case table([[ContentNode]])
    case image(ImageResource)
    case link(String, String) // url + text
    case code(String, String?) // code + language
    case container([ContentNode]) // generic container
}

public enum ListType: String, Codable, Sendable {
    case unordered = "unordered"
    case ordered = "ordered"
}

/// Represents an image resource with metadata
public struct ImageResource: Codable, Sendable {
    public let id: EntityId
    public let title: String?
    public let source: ResourceSource
    public let alt: String?
    public let dimensions: ImageDimensions?
    public let metadata: [String: String]

    public init(id: EntityId = EntityId(), title: String? = nil, source: ResourceSource, alt: String? = nil, dimensions: ImageDimensions? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.source = source
        self.alt = alt
        self.dimensions = dimensions
        self.metadata = metadata
    }
}

/// Simple width/height container to keep Codable synthesis working.
public struct ImageDimensions: Codable, Sendable {
    public let width: Int?
    public let height: Int?

    public init(width: Int? = nil, height: Int? = nil) {
        self.width = width
        self.height = height
    }
}

/// Different sources for resources
public enum ResourceSource: Codable, Sendable {
    case url(String)
    case data(Data)
    case reference(String) // reference to another part of the document bundle
}

/// Metadata for documents
public struct DocumentMetadata: Codable, Sendable {
    public let author: String?
    public let createdAt: Date
    public let modifiedAt: Date
    public let tags: [String]
    public let custom: [String: String]

    public init(author: String? = nil, createdAt: Date = Date(), modifiedAt: Date = Date(), tags: [String] = [], custom: [String: String] = [:]) {
        self.author = author
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.custom = custom
    }
}

// MARK: - Renderer Protocol

/// Platform-agnostic renderer protocol
public protocol Renderer {
    var supportedFormats: [OutputFormat] { get }

    func render(document: ContentDocument, to format: OutputFormat) async throws -> RenderResult
}

/// Output format types
public enum OutputFormat: String, CaseIterable, Codable, Sendable {
    case html = "html"
    case pdf = "pdf"
    case cli = "cli"
    case plainText = "plainText"
    case markdown = "markdown"
}

/// Result of rendering a document
public struct RenderResult: Codable, Sendable {
    public let format: OutputFormat
    public let data: Data
    public let metadata: [String: String]
    public let resources: [ResourceSource]

    public init(format: OutputFormat, data: Data, metadata: [String: String] = [:], resources: [ResourceSource] = []) {
        self.format = format
        self.data = data
        self.metadata = metadata
        self.resources = resources
    }
}

// MARK: - PlatformRenderer Registry

/// Registry for managing platform-specific renderers
public actor RendererRegistry {
    private var renderers: [OutputFormat: Renderer] = [:]

    public init() {}

    /// Register a renderer for a specific format
    public func register(_ renderer: any Renderer, for format: OutputFormat) throws {
        guard renderer.supportedFormats.contains(format) else {
            throw RendererError.unsupportedFormat(format)
        }

        renderers[format] = renderer
    }

    /// Get a renderer for a specific format
    public func renderer(for format: OutputFormat) throws -> any Renderer {
        guard let renderer = renderers[format] else {
            throw RendererError.noRendererForFormat(format)
        }
        return renderer
    }

    /// Get all supported formats
    public var supportedFormats: [OutputFormat] {
        return Array(renderers.keys)
    }

    /// Render a document to a specific format
    public func render(document: ContentDocument, to format: OutputFormat) async throws -> RenderResult {
        let renderer = try self.renderer(for: format)
        return try await renderer.render(document: document, to: format)
    }
}

/// Errors that can occur during rendering
public enum RendererError: Error, LocalizedError, Equatable {
    case unsupportedFormat(OutputFormat)
    case noRendererForFormat(OutputFormat)
    case renderingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format.rawValue)"
        case .noRendererForFormat(let format):
            return "No renderer available for format: \(format.rawValue)"
        case .renderingFailed(let message):
            return "Rendering failed: \(message)"
        }
    }
}
