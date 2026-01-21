//
//  ImageComponent.swift
//  OutlineumModule
//
//  Ported from: Outlineum/backend/outlineum/ecs/components/image_components.py
//
//  Tracks source image and normalized variant for outline generation.
//

import AnigmaCore
import Foundation

/// Tracks an image through the ingest and normalization pipeline.
///
/// ## Pipeline Flow
/// 1. `originalPath` set on entity creation
/// 2. IngestSystem normalizes → sets `normalizedPath`, `width`, `height`
/// 3. OutlineSystem reads `normalizedPath` for edge detection
public struct ImageComponent: Component, Codable {
    /// Path to the original uploaded image.
    public let originalPath: String

    /// Path to normalized PNG (auto-oriented, stripped metadata).
    public var normalizedPath: String?

    /// Image width in pixels (set after normalization).
    public var width: Int = 0

    /// Image height in pixels (set after normalization).
    public var height: Int = 0

    /// DPI (dots per inch) for print workflows.
    public var dpi: Int = 72

    /// MIME type of original file.
    public var mimeType: String?

    /// Additional metadata extracted from image.
    public var metadata: [String: String] = [:]

    public init(
        originalPath: String,
        normalizedPath: String? = nil,
        width: Int = 0,
        height: Int = 0,
        dpi: Int = 72,
        mimeType: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.originalPath = originalPath
        self.normalizedPath = normalizedPath
        self.width = width
        self.height = height
        self.dpi = dpi
        self.mimeType = mimeType
        self.metadata = metadata
    }
}
