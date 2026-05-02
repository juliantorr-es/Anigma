import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore
import Metal

// MARK: - Error Types

/// Errors that can occur during glyph atlas operations
public enum GlyphAtlasError: Error, Sendable {
    case nullPointer
    case invalidFont
    case fontNotFound
    case memoryAllocation
    case invalidSize
    case packingFailed
    case notInitialized
    case unknownError(Int32)
    
    init(code: Int32) {
        switch code {
        case GlyphAtlasNativeBridge.errorNullPointer:
            self = .nullPointer
        case GlyphAtlasNativeBridge.errorInvalidFont:
            self = .invalidFont
        case GlyphAtlasNativeBridge.errorFontNotFound:
            self = .fontNotFound
        case GlyphAtlasNativeBridge.errorMemoryAllocation:
            self = .memoryAllocation
        case GlyphAtlasNativeBridge.errorInvalidSize:
            self = .invalidSize
        case GlyphAtlasNativeBridge.errorPackingFailed:
            self = .packingFailed
        case GlyphAtlasNativeBridge.errorNotInitialized:
            self = .notInitialized
        default:
            self = .unknownError(code)
        }
    }
}

/// High-level interface for glyph atlas management.
/// Integrates with DSLMemoryBridge for zero-copy GPU access and HarfBuzz for text shaping.
public final class GlyphAtlasCapsule {
    private var atlasTexture: Texture?
    private var atlasMTLBuffer: MTLBuffer?
    private var fontMetrics: [String: FontMetrics] = [:]
    
    public init() {}
    
    /// Loads a pre-computed glyph atlas from disk via DSLMemoryBridge (zero-copy).
    /// Maps the atlas file directly to GPU memory, eliminating serialization overhead.
    public func loadAtlas(from url: URL, device: MTLDevice) throws {
        let dslBridge = DSLMemoryBridge()
        let mappedAtlas = try dslBridge.mapAtlas(url: url, device: device)
        
        self.atlasMTLBuffer = mappedAtlas.buffer
        
        // Create texture metadata (to be integrated with actual atlas format)
        self.atlasTexture = Texture(
            id: UInt64(bitPattern: Int64(mappedAtlas.buffer.gpuAddress)),
            width: 2048,  // TODO: Read from atlas metadata
            height: 2048
        )
    }
    
    /// Shapes text using HarfBuzz (via AnigmaNativeShims).
    /// Returns glyph shapes with cluster information and positioning.
    public func shapeText(_ text: String, font: String) throws -> [ShapedGlyph] {
        var count: UInt32 = 0
        var shapedGlyphsPtr: UnsafeMutablePointer<glyph_atlas_shaped_glyph_t>?
        
        let result = text.withCString { textPtr in
            font.withCString { fontPtr in
                GlyphAtlasNativeBridge.shapeText(
                    text: textPtr,
                    fontPath: fontPtr,
                    fontSize: 12, // TODO: Make font size configurable
                    shapedGlyphs: &shapedGlyphsPtr,
                    count: &count
                )
            }
        }
        
        if result != GlyphAtlasNativeBridge.success {
            throw GlyphAtlasError(code: result)
        }
        
        defer {
            if let ptr = shapedGlyphsPtr {
                GlyphAtlasNativeBridge.free(ptr)
            }
        }
        
        var shaped: [ShapedGlyph] = []
        if let ptr = shapedGlyphsPtr {
            for i in 0..<Int(count) {
                let g = ptr[i]
                shaped.append(ShapedGlyph(
                    index: g.index,
                    codepoint: g.codepoint,
                    glyphId: g.glyph_id,
                    cluster: g.cluster,
                    xAdvance: g.x_advance,
                    yAdvance: g.y_advance,
                    xOffset: g.x_offset,
                    yOffset: g.y_offset
                ))
            }
        }
        
        return shaped
    }
    
    /// Retrieves glyph metrics (advance width, height, offsets) for a codepoint.
    public func getGlyphMetrics(_ codepoint: UInt32, font: String) throws -> GlyphMetrics? {
        // TODO: Look up in font metrics cache or load from font
        let key = "\(font):\(codepoint)"
        return fontMetrics[key]
    }
    
    /// Returns the zero-copy mapped MTLBuffer for direct GPU access.
    public func getMappedBuffer() -> MTLBuffer? {
        return atlasMTLBuffer
    }
    
    /// Returns the atlas texture handle.
    public func getAtlasTexture() -> Texture? {
        return atlasTexture
    }
    
    /// Caches font metrics for fast lookup.
    public func setGlyphMetrics(_ metrics: GlyphMetrics, for codepoint: UInt32, font: String) {
        let key = "\(font):\(codepoint)"
        fontMetrics[key] = metrics
    }
    
    /// Clears all cached data.
    public func clearCache() {
        fontMetrics.removeAll()
        atlasMTLBuffer = nil
        atlasTexture = nil
    }
}

// MARK: - Data Structures

/// Represents a shaped glyph with positioning information.
public struct ShapedGlyph: Sendable {
    public let index: UInt32          // Position in input string
    public let codepoint: UInt32      // Unicode codepoint
    public let glyphId: UInt32        // Font-specific glyph ID
    public let cluster: UInt32        // Cluster ID for complex scripts
    public let xAdvance: Int32        // Horizontal advance in design units
    public let yAdvance: Int32        // Vertical advance in design units
    public let xOffset: Int32         // Horizontal offset in design units
    public let yOffset: Int32         // Vertical offset in design units
    
    public init(
        index: UInt32,
        codepoint: UInt32,
        glyphId: UInt32,
        cluster: UInt32,
        xAdvance: Int32,
        yAdvance: Int32,
        xOffset: Int32,
        yOffset: Int32
    ) {
        self.index = index
        self.codepoint = codepoint
        self.glyphId = glyphId
        self.cluster = cluster
        self.xAdvance = xAdvance
        self.yAdvance = yAdvance
        self.xOffset = xOffset
        self.yOffset = yOffset
    }
}

/// Glyph metrics for layout and rendering.
public struct GlyphMetrics: Sendable {
    public let width: UInt32           // Glyph bitmap width
    public let height: UInt32          // Glyph bitmap height
    public let advanceWidth: Int32     // Horizontal advance
    public let advanceHeight: Int32    // Vertical advance
    public let bearingX: Int32         // Left bearing
    public let bearingY: Int32         // Top bearing
    public let atlasX: UInt32          // X position in atlas
    public let atlasY: UInt32          // Y position in atlas
    
    public init(
        width: UInt32,
        height: UInt32,
        advanceWidth: Int32,
        advanceHeight: Int32,
        bearingX: Int32,
        bearingY: Int32,
        atlasX: UInt32,
        atlasY: UInt32
    ) {
        self.width = width
        self.height = height
        self.advanceWidth = advanceWidth
        self.advanceHeight = advanceHeight
        self.bearingX = bearingX
        self.bearingY = bearingY
        self.atlasX = atlasX
        self.atlasY = atlasY
    }
}

public struct Texture {
    public var id: UInt64
    public var width: UInt32
    public var height: UInt32
    
    public init(id: UInt64, width: UInt32, height: UInt32) {
        self.id = id
        self.width = width
        self.height = height
    }
}
