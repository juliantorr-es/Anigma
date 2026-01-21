//
//  NativeCompressionProvider.swift
//  PlatformCore
//
//  [Brief description of file purpose]
//

import Foundation
import CapabilityCore

#if canImport(Compression)
import Compression

public final class NativeCompressionProvider: CapabilityProvider, CompressionCapability {
    public let providerId: String = "anigma.provider.compression.native.apple"

    public var supportedCapabilities: [String] {
        [CapabilityIds.compression]
    }

    public init() {}

    public func compress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data {
        let compressionAlgorithm: compression_algorithm
        switch algorithm {
        case .gzip:
            compressionAlgorithm = COMPRESSION_ZLIB // zlib is used for gzip
        case .lz4:
            compressionAlgorithm = COMPRESSION_LZ4
        case .zstd:
            throw CapabilityError.unsupportedOperation("zstd not supported by NativeCompressionProvider")
        }

        return try performCompression(data: data, algorithm: compressionAlgorithm, operation: COMPRESSION_STREAM_ENCODE)
    }

    public func decompress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data {
        let compressionAlgorithm: compression_algorithm
        switch algorithm {
        case .gzip:
            compressionAlgorithm = COMPRESSION_ZLIB
        case .lz4:
            compressionAlgorithm = COMPRESSION_LZ4
        case .zstd:
            throw CapabilityError.unsupportedOperation("zstd not supported by NativeCompressionProvider")
        }

        return try performCompression(data: data, algorithm: compressionAlgorithm, operation: COMPRESSION_STREAM_DECODE)
    }

    private func performCompression(data: Data, algorithm: compression_algorithm, operation: compression_stream_operation) throws -> Data {
        let pageSize = 128 * 1024

        let dummy = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer { dummy.deallocate() }

        // Manual initialization of compression_stream to avoid missing argument error
        var stream = compression_stream(dst_ptr: dummy,
                                        dst_size: 0,
                                        src_ptr: dummy,
                                        src_size: 0,
                                        state: nil)

        var status = compression_stream_init(&stream, operation, algorithm)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw CapabilityError.providerFailed(providerId, NSError(domain: "NativeCompressionProvider", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize compression stream"]))
        }
        defer { compression_stream_destroy(&stream) }

        var resultData = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: pageSize)
        defer { buffer.deallocate() }

        data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) in
            stream.src_ptr = srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            stream.src_size = data.count
            stream.dst_ptr = buffer
            stream.dst_size = pageSize

            while true {
                let flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
                status = compression_stream_process(&stream, flags)

                switch status {
                case COMPRESSION_STATUS_OK:
                    if stream.dst_size == 0 {
                        resultData.append(buffer, count: pageSize)
                        stream.dst_ptr = buffer
                        stream.dst_size = pageSize
                    }
                case COMPRESSION_STATUS_END:
                    resultData.append(buffer, count: pageSize - stream.dst_size)
                    return
                default:
                    return
                }
            }
        }

        if status != COMPRESSION_STATUS_END {
             throw CapabilityError.providerFailed(providerId, NSError(domain: "NativeCompressionProvider", code: 3, userInfo: [NSLocalizedDescriptionKey: "Compression failed with status \(status)"]))
        }

        return resultData
    }
}
#endif
