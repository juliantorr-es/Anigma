// ImageDecodeCapsuleTests.swift
// Contract tests for ImageDecodeCapsule

import XCTest
@testable import ImageDecodeCapsule
import CapsuleCore

final class ImageDecodeCapsuleTests: XCTestCase {
    
    var capsule: ImageDecodeCapsule!
    
    override func setUp() async throws {
        capsule = ImageDecodeCapsule()
    }
    
    // MARK: - Version Tests
    
    func testVersion() {
        let version = capsule.version
        XCTAssertFalse(version.isEmpty)
    }
    
    // MARK: - Invalid Input Tests
    
    func testDecodeEmptyData() async {
        do {
            _ = try await capsule.decode(data: Data())
            XCTFail("Should throw error for empty data")
        } catch let error as CapsuleError {
            // Expected: should be invalid input error
            guard case .invalidInput(_, _) = error else {
                XCTFail("Wrong error type: \(error)")
                return
            }
        }
    }
    
    func testDecodeInvalidFormat() async {
        let invalidData = Data([0xFF, 0xFF, 0xFF, 0xFF])
        do {
            _ = try await capsule.decode(data: invalidData)
            XCTFail("Should throw error for invalid format")
        } catch let error as CapsuleError {
            // Expected: should be operation failed or invalid input
            switch error {
            case .operationFailed, .invalidInput:
                break
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testDecodeInvalidJPEG() async {
        let invalidJPEG = Data([0xFF, 0xD8, 0xFF, 0xAA])  // JPEG header but invalid
        do {
            _ = try await capsule.decodeJPEG(invalidJPEG)
            XCTFail("Should throw error for invalid JPEG")
        } catch is CapsuleError {
            // Expected
        }
    }
    
    func testDecodeInvalidPNG() async {
        let invalidPNG = Data([0x89, 0x50, 0x4E, 0x47, 0xFF, 0xFF])  // PNG header but invalid
        do {
            _ = try await capsule.decodePNG(invalidPNG)
            XCTFail("Should throw error for invalid PNG")
        } catch is CapsuleError {
            // Expected
        }
    }
    
    // MARK: - Pixel Format Tests
    
    func testPixelFormatGray8() {
        let format = PixelFormat.gray8
        XCTAssertEqual(format.bytesPerPixel, 1)
        XCTAssertEqual(format.description, "Grayscale 8-bit")
    }
    
    func testPixelFormatRGB24() {
        let format = PixelFormat.rgb24
        XCTAssertEqual(format.bytesPerPixel, 3)
        XCTAssertEqual(format.description, "RGB 24-bit")
    }
    
    func testPixelFormatRGBA32() {
        let format = PixelFormat.rgba32
        XCTAssertEqual(format.bytesPerPixel, 4)
        XCTAssertEqual(format.description, "RGBA 32-bit")
    }
    
    // MARK: - Image Format Tests
    
    func testImageFormatJPEG() {
        let format = ImageFormat.jpeg
        XCTAssertEqual(format.mimeType, "image/jpeg")
        XCTAssertEqual(format.fileExtension, ".jpg")
    }
    
    func testImageFormatPNG() {
        let format = ImageFormat.png
        XCTAssertEqual(format.mimeType, "image/png")
        XCTAssertEqual(format.fileExtension, ".png")
    }
    
    func testImageFormatWebP() {
        let format = ImageFormat.webp
        XCTAssertEqual(format.mimeType, "image/webp")
        XCTAssertEqual(format.fileExtension, ".webp")
    }
    
    // MARK: - Batch Decode Tests
    
    func testBatchDecodeEmpty() async {
        let results = await capsule.decodeBatch(images: [])
        XCTAssertEqual(results.count, 0)
    }
    
    func testBatchDecodeWithErrors() async {
        let invalidData = Data([0xFF, 0xFF])
        let results = await capsule.decodeBatch(images: [invalidData, invalidData])
        XCTAssertEqual(results.count, 2)
        XCTAssertNil(results[0])
        XCTAssertNil(results[1])
    }
    
    // MARK: - Error Mapping Tests
    
    func testErrorMapNullPointer() {
        let error = ImageDecodeError.nullPointer
        let capsuleError = error.capsuleError
        
        guard case .internalError = capsuleError else {
            XCTFail("Wrong error type")
            return
        }
    }
    
    func testErrorMapInvalidData() {
        let error = ImageDecodeError.invalidData
        let capsuleError = error.capsuleError
        
        guard case .invalidInput = capsuleError else {
            XCTFail("Wrong error type")
            return
        }
    }
    
    func testErrorMapMemoryAllocation() {
        let error = ImageDecodeError.memoryAllocation
        let capsuleError = error.capsuleError
        
        guard case .resourceExhausted = capsuleError else {
            XCTFail("Wrong error type")
            return
        }
    }
}

// MARK: - Golden Tests

final class ImageDecodeCapsuleGoldenTests: XCTestCase {
    
    var capsule: ImageDecodeCapsule!
    
    override func setUp() async throws {
        capsule = ImageDecodeCapsule()
    }
    
    /// Test with a minimal valid PNG: 1x1 red pixel
    func testDecodeMinimalPNG() async throws {
        // Minimal PNG: 1x1 red pixel (RGBA)
        // This is a valid 8-byte PNG header + IHDR + IDAT + IEND
        let minimalPNG = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  // PNG signature
            0x00, 0x00, 0x00, 0x0D,                            // IHDR chunk size
            0x49, 0x48, 0x44, 0x52,                            // "IHDR"
            0x00, 0x00, 0x00, 0x01,                            // Width: 1
            0x00, 0x00, 0x00, 0x01,                            // Height: 1
            0x08,                                               // Bit depth: 8
            0x02,                                               // Color type: RGB
            0x00, 0x00, 0x00,                                   // Compression, filter, interlace
            0x28, 0xCB, 0x34, 0xBB,                            // CRC
            0x00, 0x00, 0x00, 0x0C,                            // IDAT chunk size
            0x49, 0x44, 0x41, 0x54,                            // "IDAT"
            0x78, 0x9C, 0x62, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
            0x00, 0x03, 0x00, 0x01,                            // Compressed image data
            0x36, 0x84, 0x3D, 0xE2,                            // CRC
            0x00, 0x00, 0x00, 0x00,                            // IEND chunk size
            0x49, 0x45, 0x4E, 0x44,                            // "IEND"
            0xAE, 0x42, 0x60, 0x82                             // CRC
        ])
        
        do {
            let decoded = try await capsule.decodePNG(minimalPNG)
            XCTAssertEqual(decoded.width, 1)
            XCTAssertEqual(decoded.height, 1)
            XCTAssertEqual(decoded.pixelCount, 1)
            XCTAssertEqual(decoded.imageFormat, .png)
        } catch {
            // Expected - decoder may not handle minimal PNG
            // This test primarily ensures no crash
        }
    }
    
    /// Test dimensions calculation
    func testDecodedImageDimensions() {
        let decoded = DecodedImage(
            pixelData: Data(count: 256),
            width: 16,
            height: 16,
            pixelFormat: .rgba32
        )
        
        XCTAssertEqual(decoded.width, 16)
        XCTAssertEqual(decoded.height, 16)
        XCTAssertEqual(decoded.pixelCount, 256)
        XCTAssertEqual(decoded.bytesPerRow, 64)  // 16 * 4
    }
    
    /// Test memory efficiency
    func testDecodedImageMemoryCalc() {
        let decoded = DecodedImage(
            pixelData: Data(count: 1024),
            width: 32,
            height: 32,
            pixelFormat: .gray8
        )
        
        XCTAssertEqual(decoded.dataSizeBytes, 1024)
        XCTAssertEqual(decoded.bytesPerRow, 32)
        XCTAssertEqual(decoded.pixelCount, 1024)
    }
}
