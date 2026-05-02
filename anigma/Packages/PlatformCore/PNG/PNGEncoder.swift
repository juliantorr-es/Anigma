//
//  PNGEncoder.swift
//  PlatformCore
//
//  Minimal embedded PNG encoder for RGBA buffers.
//

import Foundation

enum PNGEncoderError: Error {
    case invalidDimensions
    case bufferTooSmall
}

enum PNGEncoder {
    static func encodeRGBA(
        width: Int,
        height: Int,
        rgba: [UInt8],
        bytesPerRow: Int
    ) throws -> Data {
        guard width > 0, height > 0 else {
            throw PNGEncoderError.invalidDimensions
        }
        guard rgba.count >= height * bytesPerRow else {
            throw PNGEncoderError.bufferTooSmall
        }

        var raw = Data()
        raw.reserveCapacity(height * (bytesPerRow + 1))
        for row in 0..<height {
            raw.append(0)  // filter type 0
            let start = row * bytesPerRow
            raw.append(contentsOf: rgba[start..<(start + bytesPerRow)])
        }

        var png = Data()
        png.append(contentsOf: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        var ihdr = Data()
        ihdr.append(contentsOf: withBigEndian(UInt32(width)))
        ihdr.append(contentsOf: withBigEndian(UInt32(height)))
        ihdr.append(8)  // bit depth
        ihdr.append(6)  // color type: RGBA
        ihdr.append(0)  // compression
        ihdr.append(0)  // filter
        ihdr.append(0)  // interlace
        png.append(makeChunk(type: "IHDR", data: ihdr))

        let compressed = makeZlibStream(from: raw)
        png.append(makeChunk(type: "IDAT", data: compressed))
        png.append(makeChunk(type: "IEND", data: Data()))

        return png
    }

    private static func makeChunk(type: String, data: Data) -> Data {
        var chunk = Data()
        chunk.append(contentsOf: withBigEndian(UInt32(data.count)))
        let typeData = type.data(using: .ascii) ?? Data()
        chunk.append(typeData)
        chunk.append(data)
        var crcData = Data()
        crcData.append(typeData)
        crcData.append(data)
        chunk.append(contentsOf: withBigEndian(crc32(crcData)))
        return chunk
    }

    private static func makeZlibStream(from data: Data) -> Data {
        var stream = Data()
        stream.append(0x78)
        stream.append(0x01)  // no compression, check bits set

        var offset = 0
        while offset < data.count {
            let remaining = data.count - offset
            let blockSize = min(remaining, 0xFFFF)
            let isFinal = (offset + blockSize) == data.count
            stream.append(isFinal ? 0x01 : 0x00)
            stream.append(contentsOf: withLittleEndian(UInt16(blockSize)))
            stream.append(contentsOf: withLittleEndian(UInt16(~blockSize)))
            stream.append(data[offset..<(offset + blockSize)])
            offset += blockSize
        }

        stream.append(contentsOf: withBigEndian(adler32(data)))
        return stream
    }

    private static func withBigEndian<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        let be = value.bigEndian
        return withUnsafeBytes(of: be) { Array($0) }
    }

    private static func withLittleEndian<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        let le = value.littleEndian
        return withUnsafeBytes(of: le) { Array($0) }
    }

    private static func adler32(_ data: Data) -> UInt32 {
        var a: UInt32 = 1
        var b: UInt32 = 0
        for byte in data {
            a = (a + UInt32(byte)) % 65521
            b = (b + a) % 65521
        }
        return (b << 16) | a
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if (crc & 1) != 0 {
                    crc = (crc >> 1) ^ 0xEDB8_8320
                } else {
                    crc = crc >> 1
                }
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}
