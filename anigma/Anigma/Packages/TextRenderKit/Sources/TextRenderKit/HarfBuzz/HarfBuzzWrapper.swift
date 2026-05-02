import Foundation
import CHarfBuzz

// MARK: - HarfBuzz Wrapper

/// Swift wrapper for HarfBuzz text shaping engine
public final class HarfBuzzWrapper: Sendable {
    
    // Singleton instance
    public static let shared = HarfBuzzWrapper()
    
    // Private initializer to enforce singleton
    private init() {
        // Initialize HarfBuzz library
        let initialized = hb_bridge_init()
        guard initialized != 0 else {
            fatalError("Failed to initialize HarfBuzz library")
        }
    }
    
    deinit {
        hb_bridge_cleanup()
    }

    // MARK: - Language Conversion

    internal func convertToHarfBuzzLanguage(_ language: TextLanguage) -> HarfBuzzTextLanguage {
        switch language {
        case .english: return .english
        case .french: return .french
        case .german: return .german
        case .spanish: return .spanish
        case .chinese: return .chinese
        }
    }

    internal func convertToHarfBuzzScript(_ script: TextScript) -> HarfBuzzTextScript {
        switch script {
        case .latin: return .latin
        case .cyrillic: return .cyrillic
        case .arabic: return .latin // Fallback
        case .hebrew: return .latin // Fallback
        case .common: return .common
        }
    }

    internal func convertToHarfBuzzDirection(_ direction: TextDirection) -> HarfBuzzTextDirection {
        switch direction {
        case .leftToRight: return .leftToRight
        case .rightToLeft: return .rightToLeft
        case .topToBottom: return .topToBottom
        case .bottomToTop: return .bottomToTop
        }
    }
    
    internal func convertFromHarfBuzzDirection(_ direction: HarfBuzzTextDirection) -> TextDirection {
        switch direction {
        case .invalid: return .leftToRight
        case .leftToRight: return .leftToRight
        case .rightToLeft: return .rightToLeft
        case .topToBottom: return .topToBottom
        case .bottomToTop: return .bottomToTop
        }
    }
    
    // MARK: - Text Shaping
    
    /// Shape text using HarfBuzz
    public func shapeText(
        _ text: String,
        fontPath: String,
        fontSize: Float,
        direction: HarfBuzzTextDirection = .leftToRight,
        script: TextScript = .latin,
        language: TextLanguage = .english,
        features: [HarfBuzzTextFeature] = []
    ) throws -> ShapedTextResult {
        // Create face from font file
        guard let face = hb_bridge_face_create(fontPath, 0) else {
            throw HarfBuzzError.fontCreationFailed(fontPath)
        }
        
        // Create font from face
        guard let font = hb_bridge_font_create(face) else {
            hb_bridge_face_destroy(face)
            throw HarfBuzzError.fontCreationFailed(fontPath)
        }
        
        // Create buffer
        guard let buffer = hb_bridge_buffer_create() else {
            hb_bridge_font_destroy(font)
            hb_bridge_face_destroy(face)
            throw HarfBuzzError.bufferCreationFailed
        }
        
        // Add text to buffer
        text.withCString { cString in
            hb_bridge_buffer_add_utf8(
                buffer,
                cString,
                Int32(text.utf8.count),
                0,
                Int32(text.utf8.count)
            )
        }
        
        // Set buffer properties
        // direction is already HarfBuzzTextDirection, use it directly
        let directionValue = direction.hbDirection
        hb_bridge_buffer_set_direction(buffer, directionValue)
        
        // Convert TextScript to HarfBuzzTextScript
        let harfBuzzScript = convertToHarfBuzzScript(script)
        let scriptValue = harfBuzzScript.hbScript
        hb_bridge_buffer_set_script(buffer, scriptValue)
        
        // Convert TextLanguage to HarfBuzzTextLanguage
        let harfBuzzLanguage = convertToHarfBuzzLanguage(language)
        let languageValue = harfBuzzLanguage.hbLanguage
        hb_bridge_buffer_set_language(buffer, languageValue)
        
        // Convert features to HarfBuzz format
        var hbFeatures = features.map { $0.hbFeature }
        
        // Shape the text
        let shaped = hb_bridge_shape(
            font,
            buffer,
            &hbFeatures,
            UInt32(hbFeatures.count)
        )
        
        guard shaped != 0 else {
            hb_bridge_buffer_destroy(buffer)
            hb_bridge_font_destroy(font)
            hb_bridge_face_destroy(face)
            throw HarfBuzzError.shapingFailed(getErrorMessage())
        }
        
        // Get glyph info and positions
        var glyphCount = hb_bridge_buffer_get_length(buffer)
        let glyphInfosPtr = hb_bridge_buffer_get_glyph_infos(buffer, &glyphCount)
        let glyphPositionsPtr = hb_bridge_buffer_get_glyph_positions(buffer, &glyphCount)
        
        // Copy data from pointers to Swift arrays
        var glyphInfos = [hb_glyph_info_t]()
        var glyphPositions = [hb_glyph_position_t]()
        
        if let glyphInfosPtr = glyphInfosPtr, let glyphPositionsPtr = glyphPositionsPtr {
            glyphInfos = Array(UnsafeBufferPointer<hb_glyph_info_t>(start: glyphInfosPtr, count: Int(glyphCount)))
            glyphPositions = Array(UnsafeBufferPointer<hb_glyph_position_t>(start: glyphPositionsPtr, count: Int(glyphCount)))
        }
        
        // Convert to Swift types
        var shapedGlyphs: [ShapedGlyph] = []
        var currentX: Float = 0
        var maxWidth: Float = 0
        var maxHeight: Float = 0
        
        for i in 0..<Int(glyphCount) {
            let info = glyphInfos[i]
            let position = glyphPositions[i]
            
            let glyph = ShapedGlyph(
                glyphId: UInt32(info.codepoint),
                cluster: info.cluster,
                xAdvance: Float(position.x_advance) / 64.0, // HarfBuzz uses 1/64th units
                yAdvance: Float(position.y_advance) / 64.0,
                xOffset: Float(position.x_offset) / 64.0,
                yOffset: Float(position.y_offset) / 64.0
            )
            
            shapedGlyphs.append(glyph)
            
            // Update dimensions
            currentX += glyph.xAdvance
            if glyph.xAdvance > maxWidth {
                maxWidth = glyph.xAdvance
            }
            if abs(glyph.yOffset) > maxHeight {
                maxHeight = abs(glyph.yOffset)
            }
        }
        
        // Calculate line height (approximate for now)
        let lineHeight = fontSize * 1.2
        
        // Cleanup
        hb_bridge_buffer_destroy(buffer)
        hb_bridge_font_destroy(font)
        hb_bridge_face_destroy(face)
        
        // Convert HarfBuzzTextDirection back to TextDirection for the result
        let textDirection = convertFromHarfBuzzDirection(direction)
        
        return ShapedTextResult(
            text: text,
            glyphs: shapedGlyphs,
            advanceWidth: currentX,
            lineHeight: lineHeight,
            direction: textDirection
        )
    }
    
    /// Get the last error message
    public func getErrorMessage() -> String {
        let cString = hb_bridge_get_error_message()
        if let cString = cString {
            return String(cString: cString)
        }
        return ""
    }
}

// MARK: - Supporting Types

/// Shaped text result
public struct ShapedTextResult: Sendable {
    public let text: String
    public let glyphs: [ShapedGlyph]
    public let advanceWidth: Float
    public let lineHeight: Float
    public let direction: TextDirection
    
    public var glyphCount: Int { glyphs.count }
    
    public init(
        text: String,
        glyphs: [ShapedGlyph],
        advanceWidth: Float,
        lineHeight: Float,
        direction: TextDirection
    ) {
        self.text = text
        self.glyphs = glyphs
        self.advanceWidth = advanceWidth
        self.lineHeight = lineHeight
        self.direction = direction
    }
}

/// Shaped glyph information
public struct ShapedGlyph: Sendable {
    public let glyphId: UInt32
    public let cluster: UInt32
    public let xAdvance: Float
    public let yAdvance: Float
    public let xOffset: Float
    public let yOffset: Float
    
    public init(
        glyphId: UInt32,
        cluster: UInt32,
        xAdvance: Float,
        yAdvance: Float,
        xOffset: Float,
        yOffset: Float
    ) {
        self.glyphId = glyphId
        self.cluster = cluster
        self.xAdvance = xAdvance
        self.yAdvance = yAdvance
        self.xOffset = xOffset
        self.yOffset = yOffset
    }
}

/// Text direction for HarfBuzz
public enum HarfBuzzTextDirection: Sendable, CaseIterable {
    case invalid
    case leftToRight
    case rightToLeft
    case topToBottom
    case bottomToTop
    
    var hbDirection: hb_direction_t {
        switch self {
        case .invalid: return HB_DIRECTION_INVALID
        case .leftToRight: return HB_DIRECTION_LTR
        case .rightToLeft: return HB_DIRECTION_RTL
        case .topToBottom: return HB_DIRECTION_TTB
        case .bottomToTop: return HB_DIRECTION_BTT
        }
    }
}

/// Text script for HarfBuzz
public enum HarfBuzzTextScript: Sendable, CaseIterable, Equatable {
    case invalid
    case common
    case latin
    case cyrillic
    
    var hbScript: hb_script_t {
        switch self {
        case .invalid: return HB_SCRIPT_INVALID
        case .common: return HB_SCRIPT_COMMON
        case .latin: return HB_SCRIPT_LATIN
        case .cyrillic: return HB_SCRIPT_CYRILLIC
        }
    }
}

/// Text language for HarfBuzz
public enum HarfBuzzTextLanguage: Sendable, CaseIterable, Equatable {
    case invalid
    case english
    case french
    case german
    case spanish
    case chinese
    
    var hbLanguage: hb_language_t {
        switch self {
        case .invalid: return HB_LANGUAGE_INVALID
        case .english: return HB_LANGUAGE_INVALID // Placeholder
        case .french: return HB_LANGUAGE_INVALID // Placeholder
        case .german: return HB_LANGUAGE_INVALID // Placeholder
        case .spanish: return HB_LANGUAGE_INVALID // Placeholder
        case .chinese: return HB_LANGUAGE_INVALID // Placeholder
        }
    }
}

/// Text feature for HarfBuzz
public struct HarfBuzzTextFeature: Sendable {
    public let tag: String
    public let value: UInt32
    public let startIndex: UInt32
    public let endIndex: UInt32
    
    public init(tag: String, value: UInt32, startIndex: UInt32, endIndex: UInt32) {
        self.tag = tag
        self.value = value
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
    
    var hbFeature: hb_feature_t {
        // Convert to HarfBuzz feature format
        // This is a simplified conversion
        let feature = hb_feature_t()
        // In a real implementation, we'd properly convert the tag and values
        return feature
    }
}

// MARK: - Errors

public enum HarfBuzzError: Error, Sendable {
    case libraryInitializationFailed
    case fontCreationFailed(String)
    case bufferCreationFailed
    case shapingFailed(String)
    case memoryAllocationFailed
    case invalidFontFile(String)
    case unsupportedScript(HarfBuzzTextScript)
    case unsupportedLanguage(HarfBuzzTextLanguage)
}

extension HarfBuzzError: Equatable {
    public static func == (lhs: HarfBuzzError, rhs: HarfBuzzError) -> Bool {
        switch (lhs, rhs) {
        case (.libraryInitializationFailed, .libraryInitializationFailed):
            return true
        case (.fontCreationFailed(let lhsStr), .fontCreationFailed(let rhsStr)):
            return lhsStr == rhsStr
        case (.bufferCreationFailed, .bufferCreationFailed):
            return true
        case (.shapingFailed(let lhsStr), .shapingFailed(let rhsStr)):
            return lhsStr == rhsStr
        case (.memoryAllocationFailed, .memoryAllocationFailed):
            return true
        case (.invalidFontFile(let lhsStr), .invalidFontFile(let rhsStr)):
            return lhsStr == rhsStr
        case (.unsupportedScript(let lhsScript), .unsupportedScript(let rhsScript)):
            return lhsScript == rhsScript
        case (.unsupportedLanguage(let lhsLang), .unsupportedLanguage(let rhsLang)):
            return lhsLang == rhsLang
        default:
            return false
        }
    }
}
