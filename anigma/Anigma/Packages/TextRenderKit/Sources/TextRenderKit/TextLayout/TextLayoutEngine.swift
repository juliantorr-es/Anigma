import Foundation

// MARK: - Text Layout Engine

/// Handles text shaping and layout using HarfBuzz
public final class TextLayoutEngine {
    
    private let harfBuzzWrapper: HarfBuzzWrapper
    private let fontManager: FontManager
    
    // Layout cache
    private var layoutCache: [LayoutCacheKey: ShapedTextResult] = [:]
    private let maxLayoutCacheSize = 128
    
    // MARK: - Initialization
    
    public init(harfBuzzWrapper: HarfBuzzWrapper = .shared, fontManager: FontManager) {
        self.harfBuzzWrapper = harfBuzzWrapper
        self.fontManager = fontManager
        
        ConsoleLogger.log(".layoutEngine.init", "TextLayoutEngine initialized")
    }
    
    // MARK: - Text Layout
    
    /// Shape and layout text
    public func layoutText(
        _ text: String,
        font: FontFace,
        direction: TextDirection = .leftToRight,
        script: TextScript = .latin,
        language: TextLanguage = .english,
        features: [TextFeature] = []
    ) async throws -> ShapedTextResult {
        let cacheKey = LayoutCacheKey(
            text: text,
            font: font,
            direction: direction,
            script: script,
            language: language
        )
        
        // Check cache first
        if let cachedResult = layoutCache[cacheKey] {
            return cachedResult
        }
        
        // Clean cache if full
        if layoutCache.count >= maxLayoutCacheSize {
            cleanLayoutCache()
        }
        
        // Convert direction to HarfBuzz-specific type
        let harfBuzzDirection = harfBuzzWrapper.convertToHarfBuzzDirection(direction)
        
        // Convert features to HarfBuzz-specific type
        let harfBuzzFeatures = features.map { feature in
            HarfBuzzTextFeature(
                tag: feature.tag,
                value: feature.value,
                startIndex: feature.startIndex,
                endIndex: feature.endIndex
            )
        }

        // Perform text shaping using HarfBuzz
        let shapedResult = try harfBuzzWrapper.shapeText(
            text,
            fontPath: font.url.path,
            fontSize: font.size,
            direction: harfBuzzDirection,
            script: script,  // Keep original TextScript
            language: language,  // Keep original TextLanguage
            features: harfBuzzFeatures
        )
        
        // Cache and return
        layoutCache[cacheKey] = shapedResult
        return shapedResult
    }
    
    /// Calculate text bounds
    public func calculateTextBounds(_ shapedText: ShapedTextResult) -> TextBounds {
        var width: Float = 0
        let height: Float = shapedText.lineHeight
        var minX: Float = 0
        var minY: Float = 0
        var maxX: Float = 0
        var maxY: Float = shapedText.lineHeight
        
        for glyph in shapedText.glyphs {
            // Update width based on advance
            width += glyph.xAdvance
            
            // Update bounds based on glyph position and metrics
            let glyphX = glyph.xOffset
            let glyphY = glyph.yOffset
            let glyphRight = glyphX + glyph.xAdvance
            let glyphBottom = glyphY + shapedText.lineHeight
            
            minX = min(minX, glyphX)
            minY = min(minY, glyphY)
            maxX = max(maxX, glyphRight)
            maxY = max(maxY, glyphBottom)
        }
        
        return TextBounds(
            width: width,
            height: height,
            bounds: SIMD4<Float>(minX, minY, maxX - minX, maxY - minY)
        )
    }
    
    // MARK: - Cache Management
    
    private func cleanLayoutCache() {
        let itemsToRemove = max(1, layoutCache.count / 4)
        let keysToRemove = Array(layoutCache.keys.prefix(itemsToRemove))
        
        for key in keysToRemove {
            layoutCache.removeValue(forKey: key)
        }
        
        ConsoleLogger.log(".layoutEngine.cache", "Cleaned layout cache, removed \(keysToRemove.count) entries")
    }
    
    // MARK: - Layout Utilities
    
    /// Calculate line breaks for multi-line text
    public func calculateLineBreaks(
        for text: String,
        font: FontFace,
        maxWidth: Float,
        direction: TextDirection = .leftToRight
    ) async throws -> [ShapedTextResult] {
        // In a real implementation, this would use proper line breaking algorithms
        // For now, we'll do a simple word-based approach
        
        let words = text.components(separatedBy: .whitespaces)
        var lines: [String] = []
        var currentLine = ""
        var currentWidth: Float = 0
        
        for word in words {
            let wordWidth = try await estimateTextWidth(word, font: font)
            
            if currentWidth + wordWidth <= maxWidth {
                if !currentLine.isEmpty {
                    currentLine += " "
                    currentWidth += try await estimateTextWidth(" ", font: font)
                }
                currentLine += word
                currentWidth += wordWidth
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = word
                currentWidth = wordWidth
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        // Shape each line
        var shapedLines: [ShapedTextResult] = []
        for line in lines {
            let shaped = try await layoutText(line, font: font, direction: direction)
            shapedLines.append(shaped)
        }
        
        return shapedLines
    }
    
    /// Estimate text width (simplified)
    private func estimateTextWidth(_ text: String, font: FontFace) async throws -> Float {
        // In a real implementation, this would use proper text measurement
        // For now, we'll use a simple approximation
        return Float(text.count) * font.size * 0.6
    }
}

// MARK: - Supporting Types

/// Layout cache key
private struct LayoutCacheKey: Hashable, Equatable, Sendable {
    let text: String
    let font: FontFace
    let direction: TextDirection
    let script: TextScript
    let language: TextLanguage
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(font)
        hasher.combine(direction)
        hasher.combine(script)
        hasher.combine(language)
    }
}

/// Text bounds
public struct TextBounds: Sendable {
    public let width: Float
    public let height: Float
    public let bounds: SIMD4<Float> // x, y, width, height
    
    public init(width: Float, height: Float, bounds: SIMD4<Float>) {
        self.width = width
        self.height = height
        self.bounds = bounds
    }
}

/// Text direction
public enum TextDirection: String, Sendable, CaseIterable {
    case leftToRight = "LTR"
    case rightToLeft = "RTL"
    case topToBottom = "TTB"
    case bottomToTop = "BTT"
}

/// Text script
public enum TextScript: String, Sendable, CaseIterable {
    case latin = "latn"
    case cyrillic = "cyrl"
    case arabic = "arab"
    case hebrew = "hebr"
    case common = "Zyyy"
}

/// Text language
public enum TextLanguage: String, Sendable, CaseIterable {
    case english = "en"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case chinese = "zh"
}

/// Text feature
public struct TextFeature: Sendable {
    public let tag: String // 4-character feature tag
    public let value: UInt32
    public let startIndex: UInt32
    public let endIndex: UInt32
    
    public init(tag: String, value: UInt32, startIndex: UInt32 = 0, endIndex: UInt32 = UInt32.max) {
        self.tag = tag
        self.value = value
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
    
    // Common features
    public static let ligatures = TextFeature(tag: "liga", value: 1)
    public static let kerning = TextFeature(tag: "kern", value: 1)
    public static let smallCaps = TextFeature(tag: "smcp", value: 1)
}
