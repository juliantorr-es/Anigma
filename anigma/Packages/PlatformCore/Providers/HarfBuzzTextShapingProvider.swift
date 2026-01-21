//
//  HarfBuzzTextShapingProvider.swift
//  PlatformCore
//
//  Text shaping provider for Linux using HarfBuzz and FreeType.
//

import CapabilityCore
import Foundation

#if os(Linux)
    import CHarfBuzz
    import CFreeType

    /// Text shaping provider using HarfBuzz and FreeType (Linux).
    /// Note: This requires HarfBuzz and FreeType to be installed on the system.
    public final class HarfBuzzTextShapingProvider: CapabilityProvider, TextShapingCapability {
        public let providerId: String = "anigma.provider.text.shaping.harfbuzz"

        public var supportedCapabilities: [String] {
            [CapabilityIds.textShaping]
        }

        public init() {}

        public func shapeText(_ text: String, fontPath: URL, fontSize: Double) async throws
            -> [GlyphInfo] {
            if text.isEmpty { return [] }

            guard FileManager.default.fileExists(atPath: fontPath.path) else {
                throw CapabilityError.invalidInput("Font not found at: \(fontPath.path)")
            }

            var library: FT_Library?
            if FT_Init_FreeType(&library) != 0 {
                throw CapabilityError.providerFailed(
                    providerId,
                    NSError(
                        domain: "HarfBuzzTextShapingProvider",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to initialize FreeType"]
                    )
                )
            }
            guard let ftLibrary = library else {
                throw CapabilityError.providerFailed(
                    providerId,
                    NSError(
                        domain: "HarfBuzzTextShapingProvider",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "FreeType library unavailable"]
                    )
                )
            }
            defer { FT_Done_FreeType(ftLibrary) }

            var face: FT_Face?
            let faceResult = fontPath.path.withCString { pathPtr in
                FT_New_Face(ftLibrary, pathPtr, 0, &face)
            }
            if faceResult != 0 {
                throw CapabilityError.providerFailed(
                    providerId,
                    NSError(
                        domain: "HarfBuzzTextShapingProvider",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to load font face"]
                    )
                )
            }
            guard let ftFace = face else {
                throw CapabilityError.providerFailed(
                    providerId,
                    NSError(
                        domain: "HarfBuzzTextShapingProvider",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "Font face unavailable"]
                    )
                )
            }
            defer { FT_Done_Face(ftFace) }

            let sizeResult = FT_Set_Char_Size(
                ftFace,
                0,
                Int32(fontSize * 64.0),
                0,
                0
            )
            if sizeResult != 0 {
                throw CapabilityError.providerFailed(
                    providerId,
                    NSError(
                        domain: "HarfBuzzTextShapingProvider",
                        code: 6,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to set font size"]
                    )
                )
            }

            guard let hbFont = hb_ft_font_create_referenced(ftFace) else {
                throw CapabilityError.providerFailed(
                    providerId,
                    NSError(
                        domain: "HarfBuzzTextShapingProvider",
                        code: 7,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create HarfBuzz font"]
                    )
                )
            }
            defer { hb_font_destroy(hbFont) }

            let buffer = hb_buffer_create()
            defer { hb_buffer_destroy(buffer) }

            let utf8 = Array(text.utf8)
            utf8.withUnsafeBytes { rawBuffer in
                let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: Int8.self)
                hb_buffer_add_utf8(
                    buffer,
                    ptr,
                    Int32(rawBuffer.count),
                    0,
                    Int32(rawBuffer.count)
                )
            }

            hb_buffer_guess_segment_properties(buffer)
            hb_shape(hbFont, buffer, nil, 0)

            let length = Int(hb_buffer_get_length(buffer))
            guard length > 0 else { return [] }

            guard
                let infos = hb_buffer_get_glyph_infos(buffer, nil),
                let positions = hb_buffer_get_glyph_positions(buffer, nil)
            else {
                return []
            }

            var glyphs: [GlyphInfo] = []
            glyphs.reserveCapacity(length)
            let scale = 64.0
            for index in 0..<length {
                let info = infos[index]
                let position = positions[index]
                glyphs.append(
                    GlyphInfo(
                        glyphId: info.codepoint,
                        xOffset: Double(position.x_offset) / scale,
                        yOffset: Double(position.y_offset) / scale,
                        xAdvance: Double(position.x_advance) / scale,
                        yAdvance: Double(position.y_advance) / scale
                    )
                )
            }

            return glyphs
        }
    }
#endif
