import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// High-level interface for text shaping and font management.
public final class TypographyCapsule {
    private var fontHandle: anigma_font_t?
    // We need a context?
    
    public init(fontData: Data) throws {
        // Create context and font
        // anigma_font_create(ctx, data, len, &handle)
    }
    
    public func shape(text: String) throws -> [GlyphRun] {
        // anigma_text_shape
        return []
    }
}

public struct GlyphRun {
    public var glyphIDs: [UInt32]
    public var positions: [Point]
}
