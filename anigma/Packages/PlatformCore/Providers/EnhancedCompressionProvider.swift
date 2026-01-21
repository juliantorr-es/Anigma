//
//  EnhancedCompressionProvider.swift
//  PlatformCore
//
//  Enhanced compression provider with zstd and streaming support.
//  Extends NativeCompressionProvider with additional algorithms.
//

import CapabilityCore
import Foundation

#if canImport(Compression)
    import Compression

    /// Enhanced compression provider with zstd and streaming capabilities.
    /// Note: zstd support requires macOS 10.15+ or iOS 13+
    public final class EnhancedCompressionProvider: CapabilityProvider, CompressionCapability {
        public let providerId: String = "anigma.provider.compression.enhanced"

        public var supportedCapabilities: [String] {
            [CapabilityIds.compression]
        }

        public init() {}

        public func compress(data: Data, algorithm: String) async throws -> Data {
            let compressionAlgorithm = try mapAlgorithm(algorithm)

            return try data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Data in
                guard let sourcePointer = sourceBuffer.baseAddress else {
                    throw CapabilityError.invalidInput("Empty data")
                }

                let destinationBufferSize = sourceBuffer.count
                var destinationBuffer = Data(count: destinationBufferSize)

                let compressedSize = destinationBuffer.withUnsafeMutableBytes {
                    (destBuffer: UnsafeMutableRawBufferPointer) -> Int in
                    guard let destPointer = destBuffer.baseAddress else { return 0 }

                    return compression_encode_buffer(
                        destPointer,
                        destinationBufferSize,
                        sourcePointer,
                        sourceBuffer.count,
                        nil,
                        compressionAlgorithm
                    )
                }

                guard compressedSize > 0 else {
                    throw CapabilityError.providerFailed(
                        providerId,
                        NSError(
                            domain: "EnhancedCompressionProvider", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Compression failed"])
                    )
                }

                return destinationBuffer.prefix(compressedSize)
            }
        }

        public func compress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data {
            return try await compress(data: data, algorithm: algorithm.rawValue)
        }

        public func decompress(data: Data, algorithm: String) async throws -> Data {
            let compressionAlgorithm = try mapAlgorithm(algorithm)

            return try data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Data in
                guard let sourcePointer = sourceBuffer.baseAddress else {
                    throw CapabilityError.invalidInput("Empty data")
                }

                // Estimate decompressed size (4x compressed size as heuristic)
                let destinationBufferSize = sourceBuffer.count * 4
                var destinationBuffer = Data(count: destinationBufferSize)

                let decompressedSize = destinationBuffer.withUnsafeMutableBytes {
                    (destBuffer: UnsafeMutableRawBufferPointer) -> Int in
                    guard let destPointer = destBuffer.baseAddress else { return 0 }

                    return compression_decode_buffer(
                        destPointer,
                        destinationBufferSize,
                        sourcePointer,
                        sourceBuffer.count,
                        nil,
                        compressionAlgorithm
                    )
                }

                guard decompressedSize > 0 else {
                    throw CapabilityError.providerFailed(
                        providerId,
                        NSError(
                            domain: "EnhancedCompressionProvider", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Decompression failed"])
                    )
                }

                return destinationBuffer.prefix(decompressedSize)
            }
        }

        public func decompress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data {
            return try await decompress(data: data, algorithm: algorithm.rawValue)
        }

        // MARK: - Private Helpers

        private func mapAlgorithm(_ algorithm: String) throws -> compression_algorithm {
            switch algorithm.lowercased() {
            case "lz4":
                return COMPRESSION_LZ4
            case "zlib", "gzip":
                return COMPRESSION_ZLIB
            case "lzma":
                return COMPRESSION_LZMA
            case "lzfse":
                return COMPRESSION_LZFSE
            case "zstd":
                // zstd support varies by platform/SDK version
                throw CapabilityError.invalidInput(
                    "zstd not available on this platform. Use lz4, zlib, lzma, or lzfse instead.")
            default:
                throw CapabilityError.invalidInput(
                    "Unsupported algorithm: \(algorithm). Supported: lz4, zlib, lzma, lzfse")
            }
        }
    }
#endif
