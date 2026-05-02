import Testing
import Foundation
import CoreVideo
import ContractsCore
@testable import MediaCore

@Suite("CryptoKitEvidenceAdapter Tests")
struct CryptoKitEvidenceAdapterTests {
    let adapter: CryptoKitEvidenceAdapter
    
    init() {
        self.adapter = CryptoKitEvidenceAdapter()
    }
    
    @Test("Identical buffers produce identical fingerprints")
    func testConsistency() async throws {
        let width = 16
        let height = 16
        
        // 1. Create two identical buffers
        let pb1 = try createPixelBuffer(width: width, height: height, color: 0xFF)
        let pb2 = try createPixelBuffer(width: width, height: height, color: 0xFF)
        
        // 2. Generate fingerprints
        let f1 = try await adapter.generateFingerprint(for: pb1)
        let f2 = try await adapter.generateFingerprint(for: pb2)
        
        // 3. Verify
        #expect(f1.hash == f2.hash)
        #expect(f1.algorithm == "sha256")
    }
    
    @Test("Different buffers produce different fingerprints")
    func testDifference() async throws {
        let width = 16
        let height = 16
        
        // 1. Create two different buffers
        let pb1 = try createPixelBuffer(width: width, height: height, color: 0xAA)
        let pb2 = try createPixelBuffer(width: width, height: height, color: 0xBB)
        
        // 2. Generate fingerprints
        let f1 = try await adapter.generateFingerprint(for: pb1)
        let f2 = try await adapter.generateFingerprint(for: pb2)
        
        // 3. Verify
        #expect(f1.hash != f2.hash)
    }
    
    @Test("Planar buffers (NV12) are correctly hashed")
    func testPlanarHashing() async throws {
        let width = 16
        let height = 16
        
        // Create an NV12 buffer
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, nil, &pixelBuffer)
        let pb = try #require(pixelBuffer)
        
        // Generate fingerprint
        let f = try await adapter.generateFingerprint(for: pb)
        #expect(!f.hash.isEmpty)
    }
    
    // MARK: - Helpers
    
    private func createPixelBuffer(width: Int, height: Int, color: UInt8) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        let pb = try #require(pixelBuffer)
        
        CVPixelBufferLockBaseAddress(pb, [])
        let baseAddress = CVPixelBufferGetBaseAddress(pb)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        
        for y in 0..<height {
            let row = baseAddress.advanced(by: y * bytesPerRow)
            memset(row, Int32(color), bytesPerRow)
        }
        
        CVPixelBufferUnlockBaseAddress(pb, [])
        return pb
    }
}
