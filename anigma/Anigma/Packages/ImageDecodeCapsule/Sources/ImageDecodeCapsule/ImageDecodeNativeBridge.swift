// ImageDecodeNativeBridge.swift
// Swift interface to the native C++ image decoding library

import Foundation

@_implementationOnly import ImageDecodeNative

// MARK: - C Bridge Functions

enum ImageDecodeNativeBridge {
    // Error codes
    static let success: Int32 = 0
    static let errorNullPointer: Int32 = 1
    static let errorInvalidData: Int32 = 2
    static let errorUnsupportedFormat: Int32 = 3
    static let errorDecodeFailed: Int32 = 4
    static let errorMemoryAllocation: Int32 = 5
    static let errorInvalidDimensions: Int32 = 6
    
    // Pixel formats
    static let formatGray: UInt32 = 0
    static let formatRGB: UInt32 = 1
    static let formatRGBA: UInt32 = 2
    static let formatBGRA: UInt32 = 3
    
    // C bridge types
    typealias ErrorCode = Int32
    
    /// Image metadata structure
    public struct image_metadata_t {
        public var width: UInt32
        public var height: UInt32
        public var format: UInt32
        public var bytes_per_pixel: UInt32
        public var data_size: UInt64
    }
    
    // Version
    static func version() -> String {
        let versionPtr = image_decode_version()
        return String(cString: versionPtr!)
    }
    
    // Image decoding
    static func decode(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        metadata: inout image_metadata_t
    ) -> UnsafeMutablePointer<UInt8>? {
        var outputData: UnsafeMutablePointer<UInt8>?
        let result = image_decode(data, size, &outputData, &metadata)
        guard result == success else { return nil }
        return outputData
    }
    
    static func decodeJPEG(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        metadata: inout image_metadata_t
    ) -> UnsafeMutablePointer<UInt8>? {
        var outputData: UnsafeMutablePointer<UInt8>?
        let result = image_decode_jpeg(data, size, &outputData, &metadata)
        guard result == success else { return nil }
        return outputData
    }
    
    static func decodePNG(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        metadata: inout image_metadata_t
    ) -> UnsafeMutablePointer<UInt8>? {
        var outputData: UnsafeMutablePointer<UInt8>?
        let result = image_decode_png(data, size, &outputData, &metadata)
        guard result == success else { return nil }
        return outputData
    }
    
    static func decodeWebP(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        metadata: inout image_metadata_t
    ) -> UnsafeMutablePointer<UInt8>? {
        var outputData: UnsafeMutablePointer<UInt8>?
        let result = image_decode_webp(data, size, &outputData, &metadata)
        guard result == success else { return nil }
        return outputData
    }
    
    static func free(_ data: UnsafeMutablePointer<UInt8>) {
        image_decode_free(data)
    }
}
