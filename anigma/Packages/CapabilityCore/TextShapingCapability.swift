//
//  TextShapingCapability.swift
//  CapabilityCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Information about a shaped glyph.
public struct GlyphInfo: Sendable, Codable {
    public let glyphId: UInt32
    public let xOffset: Double
    public let yOffset: Double
    public let xAdvance: Double
    public let yAdvance: Double

    public init(
        glyphId: UInt32, xOffset: Double, yOffset: Double, xAdvance: Double, yAdvance: Double
    ) {
        self.glyphId = glyphId
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.xAdvance = xAdvance
        self.yAdvance = yAdvance
    }
}

/// Capability for text shaping and font fallback.
public protocol TextShapingCapability: Capability {
    /// Shapes a string of text into glyphs using a specific font.
    /// - Parameters:
    ///   - text: The string to shape.
    ///   - fontPath: Path to the font file.
    ///   - fontSize: Size of the font in points.
    /// - Returns: An array of glyph information.
    func shapeText(_ text: String, fontPath: URL, fontSize: Double) async throws -> [GlyphInfo]
}

extension TextShapingCapability {
    public static var capabilityId: String { CapabilityIds.textShaping }
}
