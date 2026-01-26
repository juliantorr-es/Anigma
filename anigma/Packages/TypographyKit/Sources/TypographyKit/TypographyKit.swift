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
    // In a real implementation, we'd cache font handles
    public init() {}

    public func shape(text: String, fontId: String) throws -> [Int] {
        // 1. Create dummy font handle
        var ctx = anigma_ctx_t()
        var fontPtr: anigma_font_t?
        let fontData = Data([0x00])
        _ = fontData.withUnsafeNativeBytes { ptr, len in
            anigma_font_create(&ctx, ptr, len, &fontPtr)
        }

        guard let fPtr = fontPtr else { throw NativeError(status: -1, context: "font_create") }

        // Use a local cleanup block instead of NativeHandle generic
        defer {
            anigma_font_destroy(fPtr)
        }

        // 2. Shape
        return try text.withCString { cStr in
            var count: UInt32 = 0
            var idsPtr: UnsafeMutablePointer<UInt32>?
            var posPtr: UnsafeMutablePointer<Float>?

            let res = anigma_text_shape(
                fPtr,
                &ctx,
                cStr,
                &count,
                &idsPtr,
                &posPtr
            )

            guard res.status == ANIGMA_OK else { throw NativeError(status: Int32(res.status.rawValue), context: "shape") }

            defer {
                if let p = idsPtr { anigma_free_buffer(UnsafeMutablePointer(OpaquePointer(p))) }
                if let p = posPtr { anigma_free_buffer(UnsafeMutablePointer(OpaquePointer(p))) }
            }

            var ids: [Int] = []
            if let ptr = idsPtr {
                for i in 0..<Int(count) {
                    ids.append(Int(ptr[i]))
                }
            }
            return ids
        }
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