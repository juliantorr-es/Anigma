// swiftlint:disable explicit_type_interface
import XCTest
import CompressionKit

internal final class CompressionKitTests: XCTestCase {
    internal func testNativeCompressorInitialization() {
        let compressor = NativeCompressor()
        XCTAssertNotNil(compressor)
    }

    internal func testCompressEmptyData() {
        let compressor = NativeCompressor()
        XCTAssertNoThrow(try compressor.compress(Data(), algorithm: .zstd))
    }

    internal func testDecompressEmptyDataThrows() {
        let compressor = NativeCompressor()
        // Decompressing empty data likely fails
        XCTAssertThrowsError(try compressor.decompress(Data(), algorithm: .zstd)) { error in
            XCTAssertTrue(error is NativeError)
        }
    }

    internal func testCompressInvalidDataSmall() {
        let compressor = NativeCompressor()
        let smallData = Data([0x01, 0x02, 0x03])
        XCTAssertNoThrow(try compressor.compress(smallData, algorithm: .zstd))
    }

    internal func testAllAlgorithms() {
        let compressor = NativeCompressor()
        let data = Data("Hello, World!".utf8)
        for algorithm in [CompressionAlgorithm.zstd, .brotli, .lz4] {
            XCTAssertNoThrow(try compressor.compress(data, algorithm: algorithm))
        }
    }
}