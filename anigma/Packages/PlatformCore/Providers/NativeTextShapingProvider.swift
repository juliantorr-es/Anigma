//
//  NativeTextShapingProvider.swift
//  PlatformCore
//
//  Native text shaping provider for macOS/iOS using CoreText.
//

import CapabilityCore
import Foundation

#if canImport(CoreText)
    import CoreText
    import CoreGraphics

    /// Text shaping provider using CoreText (macOS/iOS).
    public final class NativeTextShapingProvider: CapabilityProvider, TextShapingCapability {
        public let providerId: String = "anigma.provider.text.shaping.native"

        public var supportedCapabilities: [String] {
            [CapabilityIds.textShaping]
        }

        public init() {}

        public func shapeText(_ text: String, fontPath: URL, fontSize: Double) async throws
            -> [GlyphInfo] {
            // Load font from URL
            guard let fontDataProvider = CGDataProvider(url: fontPath as CFURL) else {
                throw CapabilityError.invalidInput(
                    "Failed to create data provider for font at: \(fontPath.path)")
            }

            guard let cgFont = CGFont(fontDataProvider) else {
                throw CapabilityError.invalidInput("Failed to load CGFont from: \(fontPath.path)")
            }

            // Create CTFont (returns non-optional)
            let ctFont = CTFontCreateWithGraphicsFont(cgFont, fontSize, nil, nil)

            // Create attributed string with the font
            let attributes: [NSAttributedString.Key: Any] = [.font: ctFont]
            let attributedString = NSAttributedString(string: text, attributes: attributes)

            // Create typographic line
            let line = CTLineCreateWithAttributedString(attributedString as CFAttributedString)

            // Get glyph runs from the line
            guard let runs = CTLineGetGlyphRuns(line) as? [CTRun], !runs.isEmpty else {
                // Empty text or no glyphs
                return []
            }

            var glyphs: [GlyphInfo] = []

            // Process each run
            for run in runs {
                let glyphCount = CTRunGetGlyphCount(run)
                guard glyphCount > 0 else { continue }

                // Allocate buffers for glyphs and positions
                var runGlyphs = [CGGlyph](repeating: 0, count: glyphCount)
                var positions = [CGPoint](repeating: .zero, count: glyphCount)
                var advances = [CGSize](repeating: .zero, count: glyphCount)

                // Get glyphs, positions, and advances
                CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &runGlyphs)
                CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
                CTRunGetAdvances(run, CFRangeMake(0, glyphCount), &advances)

                // Convert to GlyphInfo
                for i in 0..<glyphCount {
                    glyphs.append(
                        GlyphInfo(
                            glyphId: UInt32(runGlyphs[i]),
                            xOffset: positions[i].x,
                            yOffset: positions[i].y,
                            xAdvance: advances[i].width,
                            yAdvance: advances[i].height
                        ))
                }
            }

            return glyphs
        }
    }
#endif
