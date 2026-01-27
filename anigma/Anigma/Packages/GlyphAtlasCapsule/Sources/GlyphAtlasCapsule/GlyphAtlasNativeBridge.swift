// GlyphAtlasNativeBridge.swift
// Swift bridge to native glyph atlas functionality
// Part of the Anigma project

import Foundation

/// Bridge to native glyph atlas library
public enum GlyphAtlasNativeBridge {
    
    // MARK: - Error Codes
    
    public static let success: Int32 = 0
    public static let errorNullPointer: Int32 = 1
    public static let errorInvalidFont: Int32 = 2
    public static let errorFontNotFound: Int32 = 3
    public static let errorMemoryAllocation: Int32 = 4
    public static let errorInvalidSize: Int32 = 5
    public static let errorPackingFailed: Int32 = 6
    public static let errorNotInitialized: Int32 = 7
    
    // MARK: - Native Functions
    
    /// Get library version
    public static func version() -> String {
        return String(cString: glyph_atlas_version())
    }
    
    /// Create glyph atlas from font name
    public static func create(
        fontName: UnsafePointer<CChar>?,
        fontSize: UInt32,
        atlas: UnsafeMutablePointer<OpaquePointer?>?
    ) -> Int32 {
        return glyph_atlas_create(fontName, fontSize, atlas)
    }
    
    /// Create glyph atlas from font data
    public static func createFromFile(
        fontData: UnsafePointer<UInt8>?,
        fontDataSize: UInt64,
        fontSize: UInt32,
        atlas: UnsafeMutablePointer<OpaquePointer?>?
    ) -> Int32 {
        return glyph_atlas_create_from_file(fontData, fontDataSize, fontSize, atlas)
    }
    
    /// Add codepoints to atlas
    public static func addCodepoints(
        atlas: OpaquePointer?,
        codepoints: UnsafePointer<UInt32>?,
        count: UInt32
    ) -> Int32 {
        return glyph_atlas_add_codepoints(atlas, codepoints, count)
    }
    
    /// Generate atlas
    public static func generate(
        atlas: OpaquePointer?,
        atlasWidth: UInt32,
        atlasHeight: UInt32
    ) -> Int32 {
        return glyph_atlas_generate(atlas, atlasWidth, atlasHeight)
    }
    
    /// Get glyph metrics
    public static func getGlyph(
        atlas: OpaquePointer?,
        codepoint: UInt32,
        metrics: UnsafeMutablePointer<glyph_metrics_t>?
    ) -> Int32 {
        return glyph_atlas_get_glyph(atlas, codepoint, metrics)
    }
    
    /// Get all glyph metrics
    public static func getAllGlyphs(
        atlas: OpaquePointer?,
        metrics: UnsafeMutablePointer<UnsafeMutablePointer<glyph_metrics_t>?>?,
        count: UnsafeMutablePointer<UInt32>?
    ) -> Int32 {
        return glyph_atlas_get_all_glyphs(atlas, metrics, count)
    }
    
    /// Get atlas bitmap
    public static func getBitmap(
        atlas: OpaquePointer?,
        bitmapData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
        width: UnsafeMutablePointer<UInt32>?,
        height: UnsafeMutablePointer<UInt32>?
    ) -> Int32 {
        return glyph_atlas_get_bitmap(atlas, bitmapData, width, height)
    }
    
    /// Destroy atlas
    public static func destroy(_ atlas: OpaquePointer?) {
        glyph_atlas_destroy(atlas)
    }
    
    /// Free memory
    public static func free(_ data: UnsafeMutableRawPointer?) {
        glyph_atlas_free(data)
    }
}

// MARK: - C Struct Definitions

/// Glyph metrics structure
public struct glyph_metrics_t {
    public var codepoint: UInt32
    public var x: Int32
    public var y: Int32
    public var width: UInt32
    public var height: UInt32
    public var advance_x: Float
    public var offset_x: Int32
    public var offset_y: Int32
}

// MARK: - C Function Declarations

@_silgen_name("glyph_atlas_version")
public func glyph_atlas_version() -> UnsafePointer<CChar>

@_silgen_name("glyph_atlas_create")
public func glyph_atlas_create(
    _ fontName: UnsafePointer<CChar>?,
    _ fontSize: UInt32,
    _ atlas: UnsafeMutablePointer<OpaquePointer?>?
) -> Int32

@_silgen_name("glyph_atlas_create_from_file")
public func glyph_atlas_create_from_file(
    _ fontData: UnsafePointer<UInt8>?,
    _ fontDataSize: UInt64,
    _ fontSize: UInt32,
    _ atlas: UnsafeMutablePointer<OpaquePointer?>?
) -> Int32

@_silgen_name("glyph_atlas_add_codepoints")
public func glyph_atlas_add_codepoints(
    _ atlas: OpaquePointer?,
    _ codepoints: UnsafePointer<UInt32>?,
    _ count: UInt32
) -> Int32

@_silgen_name("glyph_atlas_generate")
public func glyph_atlas_generate(
    _ atlas: OpaquePointer?,
    _ atlasWidth: UInt32,
    _ atlasHeight: UInt32
) -> Int32

@_silgen_name("glyph_atlas_get_glyph")
public func glyph_atlas_get_glyph(
    _ atlas: OpaquePointer?,
    _ codepoint: UInt32,
    _ metrics: UnsafeMutablePointer<glyph_metrics_t>?
) -> Int32

@_silgen_name("glyph_atlas_get_all_glyphs")
public func glyph_atlas_get_all_glyphs(
    _ atlas: OpaquePointer?,
    _ metrics: UnsafeMutablePointer<UnsafeMutablePointer<glyph_metrics_t>?>?,
    _ count: UnsafeMutablePointer<UInt32>?
) -> Int32

@_silgen_name("glyph_atlas_get_bitmap")
public func glyph_atlas_get_bitmap(
    _ atlas: OpaquePointer?,
    _ bitmapData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
    _ width: UnsafeMutablePointer<UInt32>?,
    _ height: UnsafeMutablePointer<UInt32>?
) -> Int32

@_silgen_name("glyph_atlas_destroy")
public func glyph_atlas_destroy(_ atlas: OpaquePointer?)

@_silgen_name("glyph_atlas_free")
public func glyph_atlas_free(_ data: UnsafeMutableRawPointer?)