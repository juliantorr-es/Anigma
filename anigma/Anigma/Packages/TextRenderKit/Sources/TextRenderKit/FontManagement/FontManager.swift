import Foundation
import Metal

// MARK: - Font Manager

/// Manages font loading, parsing, and caching
public final class FontManager {
    
    // Font cache
    private var fontCache: [FontKey: FontFace] = [:]
    private let maxFontCacheSize = 64
    
    // Glyph atlas cache
    private var atlasCache: [FontKey: GlyphAtlas] = [:]
    private let maxAtlasCacheSize = 32
    
    // MARK: - Initialization
    
    public init() {
        ConsoleLogger.log(".fontManager.init", "FontManager initialized")
    }
    
    // MARK: - Font Loading
    
    /// Load a font from file
    public func loadFont(from url: URL, size: Float) throws -> FontFace {
        let fontKey = FontKey(url: url, size: size)
        
        // Check cache first
        if let cachedFont = fontCache[fontKey] {
            return cachedFont
        }
        
        // Clean cache if full
        if fontCache.count >= maxFontCacheSize {
            cleanFontCache()
        }
        
        // Create new font face (in real implementation, this would parse the font file)
        let fontFace = FontFace(
            url: url,
            size: size,
            family: url.lastPathComponent.replacingOccurrences(of: ".ttf", with: ""),
            weight: .regular,
            glyphCount: 0 // Would be determined by parsing
        )
        
        // Cache and return
        fontCache[fontKey] = fontFace
        return fontFace
    }
    
    /// Get or create glyph atlas for a font
    public func getGlyphAtlas(for font: FontFace, device: MTLDevice) throws -> GlyphAtlas {
        let fontKey = FontKey(url: font.url, size: font.size)
        
        // Check cache first
        if let cachedAtlas = atlasCache[fontKey] {
            return cachedAtlas
        }
        
        // Clean cache if full
        if atlasCache.count >= maxAtlasCacheSize {
            cleanAtlasCache()
        }
        
        // Create new glyph atlas (in real implementation, this would generate the atlas)
        let atlas = try GlyphAtlas(
            font: font,
            device: device,
            resolution: 2048 // Default atlas resolution
        )
        
        // Cache and return
        atlasCache[fontKey] = atlas
        return atlas
    }
    
    // MARK: - Cache Management
    
    private func cleanFontCache() {
        let itemsToRemove = max(1, fontCache.count / 4)
        let keysToRemove = Array(fontCache.keys.prefix(itemsToRemove))
        
        for key in keysToRemove {
            fontCache.removeValue(forKey: key)
        }
        
        ConsoleLogger.log(".fontManager.cache", "Cleaned font cache, removed \(keysToRemove.count) entries")
    }
    
    private func cleanAtlasCache() {
        let itemsToRemove = max(1, atlasCache.count / 2)
        let keysToRemove = Array(atlasCache.keys.prefix(itemsToRemove))
        
        for key in keysToRemove {
            atlasCache.removeValue(forKey: key)
        }
        
        ConsoleLogger.log(".fontManager.atlas", "Cleaned atlas cache, removed \(keysToRemove.count) entries")
    }
    
    // MARK: - Font Information
    
    public func getFontInfo(for font: FontFace) -> FontInfo {
        return FontInfo(
            family: font.family,
            weight: font.weight,
            size: font.size,
            glyphCount: font.glyphCount,
            supportsLigatures: true, // Would be determined by font features
            supportsKerning: true
        )
    }
}

// MARK: - Supporting Types

/// Font key for caching
private struct FontKey: Hashable, Sendable {
    let url: URL
    let size: Float
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(size)
    }
}

/// Font face representation
public struct FontFace: Sendable, Hashable {
    public let url: URL
    public let size: Float
    public let family: String
    public let weight: FontWeight
    public let glyphCount: Int
    
    public init(url: URL, size: Float, family: String, weight: FontWeight, glyphCount: Int) {
        self.url = url
        self.size = size
        self.family = family
        self.weight = weight
        self.glyphCount = glyphCount
    }
}

extension FontFace {
    public var familyName: String { family }
    public var style: String { weight.rawValue }
    public var key: String { "\(family)-\(style)-\(weight)" }
}

/// Font weight
public enum FontWeight: String, Sendable, Codable, CaseIterable {
    case thin = "Thin"
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    case heavy = "Heavy"
    case black = "Black"
}

/// Font information
public struct FontInfo: Sendable {
    public let family: String
    public let weight: FontWeight
    public let size: Float
    public let glyphCount: Int
    public let supportsLigatures: Bool
    public let supportsKerning: Bool
    
    public init(family: String, weight: FontWeight, size: Float, glyphCount: Int, supportsLigatures: Bool, supportsKerning: Bool) {
        self.family = family
        self.weight = weight
        self.size = size
        self.glyphCount = glyphCount
        self.supportsLigatures = supportsLigatures
        self.supportsKerning = supportsKerning
    }
}

/// Glyph atlas
public struct GlyphAtlas {
    public let font: FontFace
    public let texture: MTLTexture
    public let resolution: UInt32
    public let glyphMetrics: [UInt32: GlyphMetrics]
    
    public init(font: FontFace, device: MTLDevice, resolution: UInt32) throws {
        self.font = font
        self.resolution = resolution
        
        // Create texture (in real implementation, this would be populated with glyph data)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(resolution),
            height: Int(resolution),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw FontManagerError.textureCreationFailed
        }
        
        self.texture = texture
        self.glyphMetrics = [:] // Would be populated with actual glyph metrics
    }
}

/// Glyph metrics
public struct GlyphMetrics: Sendable {
    public let advanceWidth: Float
    public let advanceHeight: Float
    public let bearingX: Float
    public let bearingY: Float
    public let uvRect: SIMD4<Float> // x, y, width, height in texture coordinates
    
    public init(advanceWidth: Float, advanceHeight: Float, bearingX: Float, bearingY: Float, uvRect: SIMD4<Float>) {
        self.advanceWidth = advanceWidth
        self.advanceHeight = advanceHeight
        self.bearingX = bearingX
        self.bearingY = bearingY
        self.uvRect = uvRect
    }
    
    public static let `default` = GlyphMetrics(
        advanceWidth: 1.0,
        advanceHeight: 1.0,
        bearingX: 0.0,
        bearingY: 0.0,
        uvRect: SIMD4<Float>(0, 0, 1, 1)
    )
}

// MARK: - Errors

public enum FontManagerError: Error, Equatable, Sendable {
    case fontNotFound(URL)
    case invalidFontFile(URL)
    case textureCreationFailed
    case atlasGenerationFailed
    case cacheFull
}
