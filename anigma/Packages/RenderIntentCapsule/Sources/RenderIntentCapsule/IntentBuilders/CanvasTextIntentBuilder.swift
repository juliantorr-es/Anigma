import Foundation

/// Builder for text rendering intents with canvas-specific optimizations.
/// Provides fluent API for constructing complex text rendering operations.
public struct CanvasTextIntentBuilder: Sendable {
    private var text: String
    private var position: SIMD2<Float>
    private var fontName: String
    private var fontSize: Float
    private var color: SIMD4<Float>
    private var maxWidth: Float?
    private var alignment: TextAlignment
    private var lineHeight: Float
    private var letterSpacing: Float
    private var paragraphSpacing: Float
    private var truncationMode: TruncationMode
    private var backgroundColor: SIMD4<Float>?
    private var borderColor: SIMD4<Float>?
    private var borderWidth: Float
    private var cornerRadius: Float
    private var padding: SIMD4<Float>
    private var shadow: Shadow?
    private var metadata: [String: String]
    
    /// Create a new builder with default values.
    public init(
        text: String,
        position: SIMD2<Float> = .zero,
        fontName: String = "system",
        fontSize: Float = 16,
        color: SIMD4<Float> = SIMD4(0, 0, 0, 1)
    ) {
        self.text = text
        self.position = position
        self.fontName = fontName
        self.fontSize = fontSize
        self.color = color
        self.alignment = .natural
        self.lineHeight = 1.2
        self.letterSpacing = 0
        self.paragraphSpacing = 0
        self.truncationMode = .none
        self.borderWidth = 0
        self.cornerRadius = 0
        self.padding = .zero
        self.metadata = [:]
    }
    
    // MARK: - Configuration Methods
    
    /// Set the text position.
    public func position(_ position: SIMD2<Float>) -> CanvasTextIntentBuilder {
        var builder = self
        builder.position = position
        return builder
    }
    
    /// Set the font name.
    public func font(_ fontName: String) -> CanvasTextIntentBuilder {
        var builder = self
        builder.fontName = fontName
        return builder
    }
    
    /// Set the font size.
    public func fontSize(_ size: Float) -> CanvasTextIntentBuilder {
        var builder = self
        builder.fontSize = size
        return builder
    }
    
    /// Set the text color.
    public func color(_ color: SIMD4<Float>) -> CanvasTextIntentBuilder {
        var builder = self
        builder.color = color
        return builder
    }
    
    /// Set the maximum width for text wrapping.
    public func maxWidth(_ width: Float?) -> CanvasTextIntentBuilder {
        var builder = self
        builder.maxWidth = width
        return builder
    }
    
    /// Set the text alignment.
    public func alignment(_ alignment: TextAlignment) -> CanvasTextIntentBuilder {
        var builder = self
        builder.alignment = alignment
        return builder
    }
    
    /// Set the line height multiplier.
    public func lineHeight(_ multiplier: Float) -> CanvasTextIntentBuilder {
        var builder = self
        builder.lineHeight = multiplier
        return builder
    }
    
    /// Set the letter spacing.
    public func letterSpacing(_ spacing: Float) -> CanvasTextIntentBuilder {
        var builder = self
        builder.letterSpacing = spacing
        return builder
    }
    
    /// Set the paragraph spacing.
    public func paragraphSpacing(_ spacing: Float) -> CanvasTextIntentBuilder {
        var builder = self
        builder.paragraphSpacing = spacing
        return builder
    }
    
    /// Set the truncation mode.
    public func truncationMode(_ mode: TruncationMode) -> CanvasTextIntentBuilder {
        var builder = self
        builder.truncationMode = mode
        return builder
    }
    
    /// Set a background color.
    public func backgroundColor(_ color: SIMD4<Float>?) -> CanvasTextIntentBuilder {
        var builder = self
        builder.backgroundColor = color
        return builder
    }
    
    /// Set a border color and width.
    public func border(color: SIMD4<Float>?, width: Float = 1) -> CanvasTextIntentBuilder {
        var builder = self
        builder.borderColor = color
        builder.borderWidth = width
        return builder
    }
    
    /// Set corner radius for background/border.
    public func cornerRadius(_ radius: Float) -> CanvasTextIntentBuilder {
        var builder = self
        builder.cornerRadius = radius
        return builder
    }
    
    /// Set padding around the text.
    public func padding(_ padding: SIMD4<Float>) -> CanvasTextIntentBuilder {
        var builder = self
        builder.padding = padding
        return builder
    }
    
    /// Set padding with equal values on all sides.
    public func padding(_ value: Float) -> CanvasTextIntentBuilder {
        padding(SIMD4(value, value, value, value))
    }
    
    /// Set a shadow effect.
    public func shadow(_ shadow: Shadow?) -> CanvasTextIntentBuilder {
        var builder = self
        builder.shadow = shadow
        return builder
    }
    
    /// Add metadata for debugging/telemetry.
    public func metadata(_ metadata: [String: String]) -> CanvasTextIntentBuilder {
        var builder = self
        for (key, value) in metadata {
            builder.metadata[key] = value
        }
        return builder
    }
    
    /// Add a single metadata entry.
    public func metadata(key: String, value: String) -> CanvasTextIntentBuilder {
        var builder = self
        builder.metadata[key] = value
        return builder
    }
    
    // MARK: - Build Method
    
    /// Build the render intent.
    public mutating func build() -> RenderIntent {
        var parameters: [String: ParameterValue] = [
            "text": .string(text),
            "x": .float(Double(position.x)),
            "y": .float(Double(position.y)),
            "font": .string(fontName),
            "size": .float(Double(fontSize)),
            "color_r": .float(Double(color.x)),
            "color_g": .float(Double(color.y)),
            "color_b": .float(Double(color.z)),
            "color_a": .float(Double(color.w)),
            "alignment": .string(alignment.rawValue),
            "line_height": .float(Double(lineHeight)),
            "letter_spacing": .float(Double(letterSpacing)),
            "paragraph_spacing": .float(Double(paragraphSpacing)),
            "truncation_mode": .string(truncationMode.rawValue),
            "border_width": .float(Double(borderWidth)),
            "corner_radius": .float(Double(cornerRadius)),
            "padding_top": .float(Double(padding.x)),
            "padding_right": .float(Double(padding.y)),
            "padding_bottom": .float(Double(padding.z)),
            "padding_left": .float(Double(padding.w))
        ]
        
        if let maxWidth = maxWidth {
            parameters["max_width"] = .float(Double(maxWidth))
        }
        
        if let backgroundColor = backgroundColor {
            parameters["background_color_r"] = .float(Double(backgroundColor.x))
            parameters["background_color_g"] = .float(Double(backgroundColor.y))
            parameters["background_color_b"] = .float(Double(backgroundColor.z))
            parameters["background_color_a"] = .float(Double(backgroundColor.w))
        }
        
        if let borderColor = borderColor {
            parameters["border_color_r"] = .float(Double(borderColor.x))
            parameters["border_color_g"] = .float(Double(borderColor.y))
            parameters["border_color_b"] = .float(Double(borderColor.z))
            parameters["border_color_a"] = .float(Double(borderColor.w))
        }
        
        if let shadow = shadow {
            parameters["shadow_offset_x"] = .float(Double(shadow.offset.x))
            parameters["shadow_offset_y"] = .float(Double(shadow.offset.y))
            parameters["shadow_blur"] = .float(Double(shadow.blur))
            parameters["shadow_color_r"] = .float(Double(shadow.color.x))
            parameters["shadow_color_g"] = .float(Double(shadow.color.y))
            parameters["shadow_color_b"] = .float(Double(shadow.color.z))
            parameters["shadow_color_a"] = .float(Double(shadow.color.w))
        }
        
        // Add source location metadata if available
        #if DEBUG
        if metadata["source_file"] == nil {
            let file = #file
            let line = #line
            metadata["source_file"] = file
            metadata["source_line"] = String(line)
        }
        #endif
        
        return RenderIntent(
            type: .drawText,
            parameters: parameters,
            metadata: metadata
        )
    }
}

// MARK: - Supporting Types

/// Text alignment options.
public enum TextAlignment: String, Sendable, Codable {
    case natural
    case left
    case center
    case right
    case justified
}

/// Text truncation modes.
public enum TruncationMode: String, Sendable, Codable {
    case none
    case head
    case middle
    case tail
    case clip
}

/// Shadow configuration.
public struct Shadow: Sendable, Codable {
    public let offset: SIMD2<Float>
    public let blur: Float
    public let color: SIMD4<Float>
    
    public init(offset: SIMD2<Float>, blur: Float, color: SIMD4<Float>) {
        self.offset = offset
        self.blur = blur
        self.color = color
    }
    
    /// Simple black shadow.
    public static let `default` = Shadow(
        offset: SIMD2(2, 2),
        blur: 4,
        color: SIMD4(0, 0, 0, 0.25)
    )
}

// MARK: - Convenience Methods

extension CanvasTextIntentBuilder {
    /// Create a builder for a heading.
    public static func heading(
        _ text: String,
        level: Int = 1,
        position: SIMD2<Float> = .zero
    ) -> CanvasTextIntentBuilder {
        let fontSize: Float
        switch level {
        case 1: fontSize = 32
        case 2: fontSize = 24
        case 3: fontSize = 20
        case 4: fontSize = 18
        case 5: fontSize = 16
        case 6: fontSize = 14
        default: fontSize = Float(32 - (level - 1) * 2)
        }
        
        return CanvasTextIntentBuilder(text: text, position: position, fontSize: fontSize)
            .font("system-bold")
            .lineHeight(1.1)
    }
    
    /// Create a builder for body text.
    public static func body(
        _ text: String,
        position: SIMD2<Float> = .zero
    ) -> CanvasTextIntentBuilder {
        CanvasTextIntentBuilder(text: text, position: position, fontSize: 16)
            .lineHeight(1.5)
            .paragraphSpacing(8)
    }
    
    /// Create a builder for caption text.
    public static func caption(
        _ text: String,
        position: SIMD2<Float> = .zero
    ) -> CanvasTextIntentBuilder {
        CanvasTextIntentBuilder(text: text, position: position, fontSize: 12)
            .color(SIMD4(0.5, 0.5, 0.5, 1))
            .lineHeight(1.2)
    }
    
    /// Create a builder for button text.
    public static func button(
        _ text: String,
        position: SIMD2<Float> = .zero
    ) -> CanvasTextIntentBuilder {
        CanvasTextIntentBuilder(text: text, position: position, fontSize: 14)
            .font("system-semibold")
            .color(SIMD4(1, 1, 1, 1))
            .backgroundColor(SIMD4(0, 0.5, 1, 1))
            .cornerRadius(6)
            .padding(12)
            .alignment(.center)
    }
}

// MARK: - SIMD2 Extensions

extension SIMD2 where Scalar == Float {
    public static var zero: SIMD2<Float> { SIMD2(0, 0) }
}

extension SIMD4 where Scalar == Float {
    public static var zero: SIMD4<Float> { SIMD4(0, 0, 0, 0) }
}