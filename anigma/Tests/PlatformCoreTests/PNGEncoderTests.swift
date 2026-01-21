//
//  PNGEncoderTests.swift
//  PlatformCoreTests
//
//  Unit tests for the embedded PNG encoder.
//

import XCTest
@testable import PlatformCore

final class PNGEncoderTests: XCTestCase {
    func testEncodeRGBAProducesPngSignatureAndChunks() throws {
        let width = 2
        let height = 1
        let bytesPerRow = width * 4
        let rgba: [UInt8] = [
            0xFF, 0x00, 0x00, 0xFF,
            0x00, 0xFF, 0x00, 0xFF
        ]

        let data = try PNGEncoder.encodeRGBA(
            width: width,
            height: height,
            rgba: rgba,
            bytesPerRow: bytesPerRow
        )

        XCTAssertTrue(data.count > 24)
        XCTAssertEqual(Array(data.prefix(8)), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        let ihdrLength = readUInt32BE(data, offset: 8)
        XCTAssertEqual(ihdrLength, 13)
        let ihdrType = String(data: data.subdata(in: 12..<16), encoding: .ascii)
        XCTAssertEqual(ihdrType, "IHDR")
        XCTAssertEqual(readUInt32BE(data, offset: 16), UInt32(width))
        XCTAssertEqual(readUInt32BE(data, offset: 20), UInt32(height))

        let iendOffset = data.count - 12
        let iendType = String(data: data.subdata(in: (iendOffset + 4)..<(iendOffset + 8)), encoding: .ascii)
        XCTAssertEqual(iendType, "IEND")
    }

    func testEncodeRGBARejectsInvalidDimensions() {
        XCTAssertThrowsError(
            try PNGEncoder.encodeRGBA(
                width: 0,
                height: 1,
                rgba: [],
                bytesPerRow: 0
            )
        ) { error in
            XCTAssertEqual(error as? PNGEncoderError, .invalidDimensions)
        }
    }

    func testEncodeRGBARejectsSmallBuffer() {
        XCTAssertThrowsError(
            try PNGEncoder.encodeRGBA(
                width: 1,
                height: 1,
                rgba: [],
                bytesPerRow: 4
            )
        ) { error in
            XCTAssertEqual(error as? PNGEncoderError, .bufferTooSmall)
        }
    }

    private func readUInt32BE(_ data: Data, offset: Int) -> UInt32 {
        let bytes = data[offset..<(offset + 4)]
        return bytes.reduce(UInt32(0)) { value, byte in
            (value << 8) | UInt32(byte)
        }
    }
}
