// ImageDecodeCapsule.swift
// ImageDecodeCapsule - Swift actor wrapper for image decoding
// Supports JPEG, PNG, WebP formats with diagnostics

import Foundation
import AnigmaNativeShims
import CapsuleCore
import TelemetryCore

// MARK: - Error Types

/// Errors that can occur during image decoding operations
public enum ImageDecodeError: Error, Sendable, CustomStringConvertible {
    case nullPointer
    case invalidData
    case unsupportedFormat
    case decodeFailed
    case memoryAllocation
    case invalidDimensions
    case unknownError(Int32)
    
    init(code: Int32) {
        switch code {
        case ImageDecodeNativeBridge.errorNullPointer:
            self = .nullPointer
        case ImageDecodeNativeBridge.errorInvalidData:
            self = .invalidData
        case ImageDecodeNativeBridge.errorUnsupportedFormat:
            self = .unsupportedFormat
        case ImageDecodeNativeBridge.errorDecodeFailed:
            self = .decodeFailed
        case ImageDecodeNativeBridge.errorMemoryAllocation:
            self = .memoryAllocation
        case ImageDecodeNativeBridge.errorInvalidDimensions:
            self = .invalidDimensions
        default:
            self = .unknownError(code)
        }
    }
    
    public var description: String {
        switch self {
        case .nullPointer: return "Null pointer provided"
        case .invalidData: return "Invalid or corrupted image data"
        case .unsupportedFormat: return "Unsupported image format"
        case .decodeFailed: return "Failed to decode image"
        case .memoryAllocation: return "Memory allocation failed"
        case .invalidDimensions: return "Invalid image dimensions"
        case .unknownError(let code): return "Unknown error: \(code)"
        }
    }
}

private extension ImageDecodeError {
    var capsuleError: CapsuleError {
        switch self {
        case .nullPointer:
            return .internalError(details: "ImageDecodeNative returned a null pointer")
        case .invalidData:
            return .invalidInput(field: "imageData", constraint: "invalid or corrupted data")
        case .unsupportedFormat:
            return .invalidInput(field: "format", constraint: "unsupported image format")
        case .decodeFailed:
            return .operationFailed(
                code: UInt32(ImageDecodeNativeBridge.errorDecodeFailed),
                message: "Failed to decode image",
                context: ["library": "ImageDecodeNative"]
            )
        case .memoryAllocation:
            return .resourceExhausted(resource: "memory", limit: "allocation failed")
        case .invalidDimensions:
            return .invalidInput(field: "dimensions", constraint: "invalid image dimensions")
        case .unknownError(let code):
            return .nativeError(code: code, libraryName: "ImageDecodeNative")
        }
    }
}

// MARK: - Image Format

/// Supported image formats
public enum ImageFormat: UInt32, Sendable, Codable {
    case jpeg = 0x01
    case png = 0x02
    case webp = 0x03
    
    public var mimeType: String {
        switch self {
        case .jpeg: return "image/jpeg"
        case .png: return "image/png"
        case .webp: return "image/webp"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .jpeg: return ".jpg"
        case .png: return ".png"
        case .webp: return ".webp"
        }
    }
}

// MARK: - Pixel Format

/// Pixel format of decoded image
public enum PixelFormat: Sendable, Codable {
    case gray8
    case rgb24
    case rgba32
    case bgra32
    
    var bytesPerPixel: Int {
        switch self {
        case .gray8: return 1
        case .rgb24: return 3
        case .rgba32, .bgra32: return 4
        }
    }
    
    public var description: String {
        switch self {
        case .gray8: return "Grayscale 8-bit"
        case .rgb24: return "RGB 24-bit"
        case .rgba32: return "RGBA 32-bit"
        case .bgra32: return "BGRA 32-bit"
        }
    }
}

// MARK: - Decoded Image Data

/// Decoded image with metadata
public struct DecodedImage: Sendable {
    /// Raw pixel data
    public let pixelData: Data
    
    /// Image width in pixels
    public let width: Int
    
    /// Image height in pixels
    public let height: Int
    
    /// Pixel format
    public let pixelFormat: PixelFormat
    
    /// Original image format
    public let imageFormat: ImageFormat?
    
    /// Bytes per row (stride)
    public var bytesPerRow: Int {
        width * pixelFormat.bytesPerPixel
    }
    
    /// Total pixel count
    public var pixelCount: Int {
        width * height
    }
    
    /// Image size in bytes
    public var dataSizeBytes: Int {
        pixelData.count
    }
    
    public init(
        pixelData: Data,
        width: Int,
        height: Int,
        pixelFormat: PixelFormat,
        imageFormat: ImageFormat? = nil
    ) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.imageFormat = imageFormat
    }
}

// MARK: - ImageDecodeCapsule Actor

/// Thread-safe actor for decoding images (JPEG, PNG, WebP)
public actor ImageDecodeCapsule {
    
    // MARK: - Properties
    
    /// Library version
    public nonisolated var version: String {
        ImageDecodeNativeBridge.version()
    }
    
    /// Optional diagnostics collector
    private let diagnostics: CapsuleDiagnostics?
    
    // MARK: - Initialization
    
    /// Initialize the capsule
    /// - Parameter diagnostics: Optional diagnostics collector for span tracking
    public init(diagnostics: CapsuleDiagnostics? = nil) {
        self.diagnostics = diagnostics
    }
    
    // MARK: - Decoding
    
    /// Decode an image from encoded data
    /// - Parameters:
    ///   - data: Encoded image data (JPEG, PNG, or WebP)
    ///   - format: Optional format hint (auto-detected if not provided)
    /// - Returns: Decoded image with metadata
    /// - Throws: CapsuleError on decode failure
    public func decode(data: Data, format: ImageFormat? = nil) async throws -> DecodedImage {
        let span = diagnostics?.beginSpan(
            name: "image.decode",
            category: "ImageDecodeCapsule",
            correlationID: nil,
            tags: ["format": format?.mimeType ?? "auto-detect"]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: ImageDecodeError.nullPointer.capsuleError)
                    return
                }
                
                var metadata = image_metadata_t()
                
                let outputPtr: UnsafeMutablePointer<UInt8>?
                do {
                    if let format = format {
                        // Use format-specific decoder
                        switch format {
                        case .jpeg:
                            outputPtr = ImageDecodeNativeBridge.decodeJPEG(
                                data: ptr,
                                size: UInt64(buffer.count),
                                metadata: &metadata
                            )
                        case .png:
                            outputPtr = ImageDecodeNativeBridge.decodePNG(
                                data: ptr,
                                size: UInt64(buffer.count),
                                metadata: &metadata
                            )
                        case .webp:
                            outputPtr = ImageDecodeNativeBridge.decodeWebP(
                                data: ptr,
                                size: UInt64(buffer.count),
                                metadata: &metadata
                            )
                        }
                    } else {
                        // Auto-detect
                        outputPtr = ImageDecodeNativeBridge.decode(
                            data: ptr,
                            size: UInt64(buffer.count),
                            metadata: &metadata
                        )
                    }
                } catch {
                    span?.end(status: .error)
                    continuation.resume(throwing: ImageDecodeError.decodeFailed.capsuleError)
                    return
                }
                
                guard let outputPtr = outputPtr else {
                    span?.end(status: .error)
                    continuation.resume(throwing: ImageDecodeError.decodeFailed.capsuleError)
                    return
                }
                
                // Create Data from output buffer
                let pixelData = Data(
                    bytesNoCopy: outputPtr,
                    count: Int(metadata.data_size),
                    deallocator: .custom { _, _ in
                        ImageDecodeNativeBridge.free(outputPtr)
                    }
                )
                
                let pixelFormat: PixelFormat = {
                    switch metadata.format {
                    case ImageDecodeNativeBridge.formatGray:
                        return .gray8
                    case ImageDecodeNativeBridge.formatRGB:
                        return .rgb24
                    case ImageDecodeNativeBridge.formatRGBA:
                        return .rgba32
                    case ImageDecodeNativeBridge.formatBGRA:
                        return .bgra32
                    default:
                        return .rgba32
                    }
                }()
                
                let decoded = DecodedImage(
                    pixelData: pixelData,
                    width: Int(metadata.width),
                    height: Int(metadata.height),
                    pixelFormat: pixelFormat,
                    imageFormat: format
                )
                
                span?.addTag(key: "width", value: String(metadata.width))
                span?.addTag(key: "height", value: String(metadata.height))
                span?.addTag(key: "format", value: pixelFormat.description)
                
                continuation.resume(returning: decoded)
            }
        }
    }
    
    /// Decode a JPEG image
    /// - Parameter data: JPEG encoded data
    /// - Returns: Decoded image
    /// - Throws: CapsuleError
    public func decodeJPEG(_ data: Data) async throws -> DecodedImage {
        try await decode(data: data, format: .jpeg)
    }
    
    /// Decode a PNG image
    /// - Parameter data: PNG encoded data
    /// - Returns: Decoded image
    /// - Throws: CapsuleError
    public func decodePNG(_ data: Data) async throws -> DecodedImage {
        try await decode(data: data, format: .png)
    }
    
    /// Decode a WebP image
    /// - Parameter data: WebP encoded data
    /// - Returns: Decoded image
    /// - Throws: CapsuleError
    public func decodeWebP(_ data: Data) async throws -> DecodedImage {
        try await decode(data: data, format: .webp)
    }
    
    /// Batch decode multiple images
    /// - Parameters:
    ///   - images: Array of encoded image data
    ///   - format: Optional format hint for all images
    /// - Returns: Array of decoded images (nil for failed images)
    public func decodeBatch(
        images: [Data],
        format: ImageFormat? = nil
    ) async -> [DecodedImage?] {
        await withTaskGroup(of: (Int, DecodedImage?).self) { group in
            for (index, imageData) in images.enumerated() {
                group.addTask {
                    do {
                        let decoded = try await self.decode(data: imageData, format: format)
                        return (index, decoded)
                    } catch {
                        return (index, nil)
                    }
                }
            }
            
            var results = [DecodedImage?](repeating: nil, count: images.count)
            for await (index, decoded) in group {
                results[index] = decoded
            }
            return results
        }
    }
}

// MARK: - CapsuleCore Integration

/// Protocol for capsule lifecycle management
public protocol CapsuleLifecycle: Actor {
    func activate() async throws
    func deactivate() async
}

extension ImageDecodeCapsule: CapsuleLifecycle {
    public func activate() async throws {
        // No initialization needed
    }
    
    public func deactivate() async {
        // No cleanup needed
    }
}
