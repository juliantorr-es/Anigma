//
//  RendererManager.swift
//  PlatformCore
//
//  Renderer integration manager for Phase 8.2
//

import Foundation

/// Integration manager for all platform-specific renderers
public actor RendererManager {
    private let registry = RendererRegistry()

    public init() {
        // Task-based initialization doesn't work well with actor init
        // We'll handle default renderer registration in a separate method
    }

    /// Initialize default renderers - call this method after creating a RendererManager instance
    public func setupDefaultRenderers() async {
        do {
            try await registry.register(HTMLRenderer(), for: .html)
            try await registry.register(PDFRenderer(), for: .pdf)
            try await registry.register(CLIRenderer(), for: .cli)
            try await registry.register(PlainTextRenderer(), for: .plainText)
            try await registry.register(MarkdownRenderer(), for: .markdown)
        } catch {
            print("Failed to register default renderers: \(error)")
        }
    }

    /// Convenience method that creates a manager and sets up defaults
    public static func createWithDefaults() async -> RendererManager {
        let manager = RendererManager()
        await manager.setupDefaultRenderers()
        return manager
    }

    /// Get all supported output formats
    public func supportedFormats() async -> [OutputFormat] {
        await registry.supportedFormats
    }

    /// Render a document to a specific format
    public func render(document: ContentDocument, to format: OutputFormat) async throws -> RenderResult {
        return try await registry.render(document: document, to: format)
    }

    /// Render a document to multiple formats
    public func renderToMultipleFormats(document: ContentDocument, formats: [OutputFormat]) async throws -> [RenderResult] {
        var results: [RenderResult] = []

        for format in formats {
            do {
                let result = try await render(document: document, to: format)
                results.append(result)
            } catch {
                // If rendering fails for a format, we could choose to either:
                // 1. Skip that format and continue
                // 2. Throw an error and stop the entire process
                // For now, we'll throw the error to maintain consistency
                throw error
            }
        }

        return results
    }

    /// Register a custom renderer for a format
    public func registerRenderer(_ renderer: any Renderer, for format: OutputFormat) async throws {
        try await registry.register(renderer, for: format)
    }
}
