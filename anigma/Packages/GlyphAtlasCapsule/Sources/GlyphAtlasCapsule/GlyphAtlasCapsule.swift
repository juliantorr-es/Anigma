import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// High-level interface for glyph atlas management.
public final class GlyphAtlasCapsule {
    // Atlas management logic.
    // Likely uses FreeType or HarfBuzz underneath via native shim.
    // anigma_render.h includes resources for text/images.
    
    public init() {}
    
    public func getAtlasTexture() -> Texture? {
        // Return texture handle
        return nil
    }
}

public struct Texture {
    public var id: UInt64
    public var width: UInt32
    public var height: UInt32
}
