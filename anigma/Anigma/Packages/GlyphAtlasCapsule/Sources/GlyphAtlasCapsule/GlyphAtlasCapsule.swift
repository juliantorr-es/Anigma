// GlyphAtlasCapsule.swift
// GlyphAtlasCapsule - Swift actor wrapper for glyph atlas generation
// Supports font loading and glyph metrics with diagnostics

import Foundation
import CoreGraphics
import CapsuleCore
import TelemetryCore

// MARK: - Error Types

/// Errors that can occur during glyph atlas operations
public enum GlyphAtlasError: Error, Sendable, CustomStringConvertible {
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
    
    public var description: String {
        switch self {
        case .nullPointer: return "Null pointer provided"
        case .invalidFont: return "Invalid font data"
        case .fontNotFound: return "Font not found"
        case .memoryAllocation: return "Memory allocation failed"
        case .invalidSize: return "Invalid size parameters"
        case .packingFailed: return "Failed to pack glyphs"
        case .notInitialized: return "Atlas not initialized"
        case .unknownError(let code): return "Unknown error: \(code)"
        }
    }
}

extension GlyphAtlasError {
    var capsuleError: CapsuleError {
        switch self {
        case .nullPointer:
            return .internalError(details: "GlyphAtlasNative returned a null pointer")
        case .invalidFont:
            return .invalidInput(field: "font", constraint: "invalid font data")
        case .fontNotFound:
            return .invalidInput(field: "font", constraint: "font not found")
        case .memoryAllocation:
            return .resourceExhausted(resource: "memory", limit: "allocation failed")
        case .invalidSize:
            return .invalidInput(field: "size", constraint: "invalid atlas size")
        case .packingFailed:
            return .operationFailed(
                code: UInt32(GlyphAtlasNativeBridge.errorPackingFailed),
                message: "Failed to pack glyphs into atlas",
                context: ["library": "GlyphAtlasNative"]
            )
        case .notInitialized:
            return .operationFailed(
                code: UInt32(GlyphAtlasNativeBridge.errorNotInitialized),
                message: "Atlas not initialized",
                context: ["library": "GlyphAtlasNative"]
            )
        case .unknownError(let code):
            return .nativeError(code: code, libraryName: "GlyphAtlasNative")
        }
    }
}

// MARK: - Glyph Metrics

/// Metrics for a single glyph in the atlas
public struct GlyphMetrics: Sendable, Codable {
    /// Unicode codepoint
    public let codepoint: UInt32
    
    /// Position in atlas texture
    public let x: Int32
    public let y: Int32
    
    /// Glyph dimensions
    public let width: UInt32
    public let height: UInt32
    
    /// Horizontal advance for layout
    public let advanceX: Float
    
    /// Offset from baseline
    public let offsetX: Int32
    public let offsetY: Int32
    
    public init(
        codepoint: UInt32,
        x: Int32,
        y: Int32,
        width: UInt32,
        height: UInt32,
        advanceX: Float,
        offsetX: Int32,
        offsetY: Int32
    ) {
        self.codepoint = codepoint
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.advanceX = advanceX
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
    
    /// Character represented by this glyph
    public var character: Character? {
        let scalar = UnicodeScalar(codepoint)
        return scalar.map { Character($0) }
    }
    
    /// Glyph rectangle in atlas coordinates
    public var rect: CGRect {
        CGRect(x: Double(x), y: Double(y), width: Double(width), height: Double(height))
    }
}

// MARK: - Atlas Metadata

/// Metadata for a generated glyph atlas
public struct AtlasMetadata: Sendable, Codable {
    /// Atlas texture dimensions
    public let width: UInt32
    public let height: UInt32
    
    /// Number of glyphs in atlas
    public let glyphCount: UInt32
    
    /// Font size used
    public let fontSize: UInt32
    
    /// Grayscale bitmap data
    public let bitmapData: Data
    
    public init(
        width: UInt32,
        height: UInt32,
        glyphCount: UInt32,
        fontSize: UInt32,
        bitmapData: Data
    ) {
        self.width = width
        self.height = height
        self.glyphCount = glyphCount
        self.fontSize = fontSize
        self.bitmapData = bitmapData
    }
    
    /// Atlas size in bytes
    public var dataSizeBytes: Int {
        bitmapData.count
    }
    
    /// Atlas area in pixels
    public var area: UInt32 {
        width * height
    }
}

// MARK: - GlyphAtlasCapsule Actor

/// Thread-safe actor for generating glyph atlases from fonts
public actor GlyphAtlasCapsule {
    
    // MARK: - Properties
    
    /// Library version
    public nonisolated var version: String {
        GlyphAtlasNativeBridge.version()
    }
    
    /// Optional diagnostics collector
    private let diagnostics: CapsuleDiagnostics?
    
    // MARK: - Initialization
    
    /// Initialize the capsule
    /// - Parameter diagnostics: Optional diagnostics collector for span tracking
    public init(diagnostics: CapsuleDiagnostics? = nil) {
        self.diagnostics = diagnostics
    }
    
    // MARK: - Atlas Creation
    
    /// Create a glyph atlas from a system font name
    /// - Parameters:
    ///   - fontName: System font name (e.g., "Helvetica", "Arial")
    ///   - fontSize: Font size in points
    /// - Returns: Atlas handle for further operations
    /// - Throws: CapsuleError on creation failure
    public func createAtlas(
        fontName: String,
        fontSize: UInt32
    ) async throws -> OpaquePointer {
        let span = diagnostics?.beginSpan(
            name: "atlas.create",
            category: "GlyphAtlasCapsule",
            correlationID: nil,
            tags: [
                "font_name": fontName,
                "font_size": String(fontSize)
            ]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            let result = fontName.withCString { fontNamePtr in
                var atlasPtr: OpaquePointer?
                let result = GlyphAtlasNativeBridge.create(
                    fontName: fontNamePtr,
                    fontSize: fontSize,
                    atlas: &atlasPtr
                )
                
                if result == GlyphAtlasNativeBridge.success {
                    span?.addTag(key: "success", value: "true")
                    continuation.resume(returning: atlasPtr!)
                } else {
                    span?.end(status: .error)
                    continuation.resume(throwing: GlyphAtlasError(code: result).capsuleError)
                }
            }
        }
    }
    
    /// Create a glyph atlas from font file data
    /// - Parameters:
    ///   - fontData: Raw font file data (TTF, OTF, etc.)
    ///   - fontSize: Font size in points
    /// - Returns: Atlas handle for further operations
    /// - Throws: CapsuleError on creation failure
    public func createAtlas(
        fontData: Data,
        fontSize: UInt32
    ) async throws -> OpaquePointer {
        let span = diagnostics?.beginSpan(
            name: "atlas.create_from_file",
            category: "GlyphAtlasCapsule",
            correlationID: nil,
            tags: [
                "font_data_size": String(fontData.count),
                "font_size": String(fontSize)
            ]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            fontData.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: GlyphAtlasError.nullPointer.capsuleError)
                    return
                }
                
                var atlasPtr: OpaquePointer?
                let result = GlyphAtlasNativeBridge.createFromFile(
                    fontData: ptr,
                    fontDataSize: UInt64(buffer.count),
                    fontSize: fontSize,
                    atlas: &atlasPtr
                )
                
                if result == GlyphAtlasNativeBridge.success {
                    span?.addTag(key: "success", value: "true")
                    continuation.resume(returning: atlasPtr!)
                } else {
                    span?.end(status: .error)
                    continuation.resume(throwing: GlyphAtlasError(code: result).capsuleError)
                }
            }
        }
    }
    
    // MARK: - Atlas Operations
    
    /// Add Unicode codepoints to the atlas
    /// - Parameters:
    ///   - atlas: Atlas handle
    ///   - codepoints: Array of Unicode codepoints
    /// - Throws: CapsuleError on failure
    public func addCodepoints(
        to atlas: OpaquePointer,
        codepoints: [UInt32]
    ) async throws {
        let span = diagnostics?.beginSpan(
            name: "atlas.add_codepoints",
            category: "GlyphAtlasCapsule",
            correlationID: nil,
            tags: ["codepoint_count": String(codepoints.count)]
        )
        defer { span?.end(status: .ok) }
        
        let result = codepoints.withUnsafeBufferPointer { buffer in
            GlyphAtlasNativeBridge.addCodepoints(
                atlas: atlas,
                codepoints: buffer.baseAddress,
                count: UInt32(buffer.count)
            )
        }
        
        if result != GlyphAtlasNativeBridge.success {
            span?.end(status: .error)
            throw GlyphAtlasError(code: result).capsuleError
        }
    }
    
    /// Generate the atlas with specified dimensions
    /// - Parameters:
    ///   - atlas: Atlas handle
    ///   - width: Atlas texture width
    ///   - height: Atlas texture height
    /// - Throws: CapsuleError on generation failure
    public func generateAtlas(
        _ atlas: OpaquePointer,
        width: UInt32,
        height: UInt32
    ) async throws {
        let span = diagnostics?.beginSpan(
            name: "atlas.generate",
            category: "GlyphAtlasCapsule",
            correlationID: nil,
            tags: [
                "width": String(width),
                "height": String(height)
            ]
        )
        defer { span?.end(status: .ok) }
        
        let result = GlyphAtlasNativeBridge.generate(
            atlas: atlas,
            atlasWidth: width,
            atlasHeight: height
        )
        
        if result != GlyphAtlasNativeBridge.success {
            span?.end(status: .error)
            throw GlyphAtlasError(code: result).capsuleError
        }
    }
    
    /// Get metrics for a specific glyph
    /// - Parameters:
    ///   - atlas: Atlas handle
    ///   - codepoint: Unicode codepoint
    /// - Returns: Glyph metrics
    /// - Throws: CapsuleError on failure
    public func getGlyphMetrics(
        from atlas: OpaquePointer,
        codepoint: UInt32
    ) async throws -> GlyphMetrics {
        let span = diagnostics?.beginSpan(
            name: "atlas.get_glyph",
            category: "GlyphAtlasCapsule",
            correlationID: nil,
            tags: ["codepoint": String(codepoint)]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            var metrics = glyph_metrics_t(
                codepoint: 0,
                x: 0,
                y: 0,
                width: 0,
                height: 0,
                advance_x: 0,
                offset_x: 0,
                offset_y: 0
            )
            let result = GlyphAtlasNativeBridge.getGlyph(
                atlas: atlas,
                codepoint: codepoint,
                metrics: &metrics
            )
            
            if result == GlyphAtlasNativeBridge.success {
                let glyphMetrics = GlyphMetrics(
                    codepoint: metrics.codepoint,
                    x: metrics.x,
                    y: metrics.y,
                    width: metrics.width,
                    height: metrics.height,
                    advanceX: metrics.advance_x,
                    offsetX: metrics.offset_x,
                    offsetY: metrics.offset_y
                )
                continuation.resume(returning: glyphMetrics)
            } else {
                span?.end(status: .error)
                continuation.resume(throwing: GlyphAtlasError(code: result).capsuleError)
            }
        }
    }
    
    /// Get all glyph metrics from the atlas
    /// - Parameter atlas: Atlas handle
    /// - Returns: Array of glyph metrics
    /// - Throws: CapsuleError on failure
    public func getAllGlyphMetrics(
        from atlas: OpaquePointer
    ) async throws -> [GlyphMetrics] {
        let span = diagnostics?.beginSpan(
            name: "atlas.get_all_glyphs",
            category: "GlyphAtlasCapsule",
            correlationID: nil,
            tags: [:]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            var metricsPtr: UnsafeMutablePointer<glyph_metrics_t>?
            var count: UInt32 = 0
            
            let result = GlyphAtlasNativeBridge.getAllGlyphs(
                atlas: atlas,
                metrics: &metricsPtr,
                count: &count
            )
            
            if result == GlyphAtlasNativeBridge.success,
               let metricsPtr = metricsPtr {
                
                var metrics: [GlyphMetrics] = []
                for i in 0..<count {
                    let metric = metricsPtr[Int(i)]
                    metrics.append(GlyphMetrics(
                        codepoint: metric.codepoint,
                        x: metric.x,
                        y: metric.y,
                        width: metric.width,
                        height: metric.height,
                        advanceX: metric.advance_x,
                        offsetX: metric.offset_x,
                        offsetY: metric.offset_y
                    ))
                }
                
                GlyphAtlasNativeBridge.free(metricsPtr)
                span?.addTag(key: "glyph_count", value: String(count))
                continuation.resume(returning: metrics)
            } else {
                span?.end(status: .error)
                continuation.resume(throwing: GlyphAtlasError(code: result).capsuleError)
            }
        }
    }
    
    /// Get atlas metadata and bitmap data
    /// - Parameter atlas: Atlas handle
    /// - Returns: Atlas metadata with bitmap
    /// - Throws: CapsuleError on failure
    public func getAtlasMetadata(
        from atlas: OpaquePointer
    ) async throws -> AtlasMetadata {
        let span = diagnostics?.beginSpan(
            name: "atlas.get_bitmap",
            category: "GlyphAtlasCapsule",
            correlationID: nil,
            tags: [:]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            var bitmapPtr: UnsafeMutablePointer<UInt8>?
            var width: UInt32 = 0
            var height: UInt32 = 0
            
            let result = GlyphAtlasNativeBridge.getBitmap(
                atlas: atlas,
                bitmapData: &bitmapPtr,
                width: &width,
                height: &height
            )
            
            if result == GlyphAtlasNativeBridge.success,
               let bitmapPtr = bitmapPtr {
                
                let dataSize = Int(width * height)
                let bitmapData = Data(
                    bytesNoCopy: bitmapPtr,
                    count: dataSize,
                    deallocator: .custom { _, _ in
                        GlyphAtlasNativeBridge.free(bitmapPtr)
                    }
                )
                
                let metadata = AtlasMetadata(
                    width: width,
                    height: height,
                    glyphCount: 0, // Would need to track this separately
                    fontSize: 0,   // Would need to track this separately
                    bitmapData: bitmapData
                )
                
                span?.addTag(key: "width", value: String(width))
                span?.addTag(key: "height", value: String(height))
                continuation.resume(returning: metadata)
            } else {
                span?.end(status: .error)
                continuation.resume(throwing: GlyphAtlasError(code: result).capsuleError)
            }
        }
    }
    
    /// Destroy an atlas and free resources
    /// - Parameter atlas: Atlas handle to destroy
    public func destroyAtlas(_ atlas: OpaquePointer) {
        let span = diagnostics?.beginSpan(
            name: "atlas.destroy",
            category: "GlyphAtlasCapsule",
            correlationID: nil,
            tags: [:]
        )
        defer { span?.end(status: .ok) }
        
        GlyphAtlasNativeBridge.destroy(atlas)
    }
}

// MARK: - CapsuleCore Integration

/// Protocol for capsule lifecycle management
public protocol CapsuleLifecycle: Actor {
    func activate() async throws
    func deactivate() async
}

extension GlyphAtlasCapsule: CapsuleLifecycle {
    public func activate() async throws {
        // No initialization needed
    }
    
    public func deactivate() async {
        // No cleanup needed
    }
}