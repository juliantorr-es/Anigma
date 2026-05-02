import Foundation
import CoreGraphics
import CapsuleCore

public struct TextShaper: Sendable {
    public init() {}

    /// Simulates shaping by calculating a stubbed width.
    /// For this stub, we assume each character has a fixed width (e.g. 0.6 * fontSize).
    public func shape(text: String, fontSize: CGFloat) -> [GlyphInfo] {
        var glyphs: [GlyphInfo] = []
        let charWidth: CGFloat = fontSize * 0.6
        let charHeight: CGFloat = fontSize

        for (index, _) in text.enumerated() {
            let bounds = CGRect(
                x: 0,
                y: 0,
                width: charWidth,
                height: charHeight
            )
            // Using index as ID
            let glyph = GlyphInfo(id: index, advance: charWidth, bounds: bounds)
            glyphs.append(glyph)
        }
        return glyphs
    }

    /// Measures text dimensions
    public func measure(text: String, fontSize: CGFloat) -> CGSize {
        let glyphs = shape(text: text, fontSize: fontSize)
        let width = glyphs.reduce(0) { $0 + $1.advance }
        // Height is roughly the font size
        return CGSize(width: width, height: fontSize)
    }
}
