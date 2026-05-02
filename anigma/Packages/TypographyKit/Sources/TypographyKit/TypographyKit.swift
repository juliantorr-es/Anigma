//
//  TypographyKit.swift
//  TypographyKit
//
//  Text shaping and metrics.
//

import Foundation
import AnigmaNativeShims
import AnigmaPrimitives

public protocol TextShaper: Sendable {
    func shape(text: String, fontId: String) throws -> [Int]
}

public final class NativeShaper: TextShaper, @unchecked Sendable {
    public init() {}

    public func shape(text: String, fontId: String) throws -> [Int] {
        // Stub: Return dummy glyph IDs (1 per character)
        return text.enumerated().map { $0.offset + 1 }
    }
}

// MARK: - New Layout API

public struct FontMetrics: Sendable, Codable {
    public let ascent: Double
    public let descent: Double
    public let leading: Double
    public let xHeight: Double
    public let capHeight: Double
    
    public init(ascent: Double, descent: Double, leading: Double, xHeight: Double, capHeight: Double) {
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.xHeight = xHeight
        self.capHeight = capHeight
    }
}

public struct GlyphInfo: Sendable, Codable {
    public let glyphID: UInt32
    public let advance: Double
    public let offsetX: Double
    public let offsetY: Double
    
    public init(glyphID: UInt32, advance: Double, offsetX: Double = 0, offsetY: Double = 0) {
        self.glyphID = glyphID
        self.advance = advance
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

public func shape(text: String, fontName: String, fontSize: Double) -> [GlyphInfo] {
    // Stub implementation
    var glyphs: [GlyphInfo] = []
    
    // Simple dummy shaping: 1 char = 1 glyph, constant advance
    for (index, _) in text.enumerated() {
        let dummyID = UInt32(index + 1) // 1-based dummy ID
        let dummyAdvance = fontSize * 0.6
        glyphs.append(GlyphInfo(glyphID: dummyID, advance: dummyAdvance))
    }
    
    return glyphs
}