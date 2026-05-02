import Testing
import Foundation
import CoreVideo
import ContractsCore
@testable import MediaCore

@Suite("SurfaceAuthority Tests")
struct SurfaceAuthorityTests {
    let authority: SurfaceAuthority
    
    init() {
        self.authority = SurfaceAuthority()
    }
    
    @Test("Registering and resolving CVPixelBuffer")
    func registerAndResolve() async throws {
        // Create a dummy pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            1920,
            1080,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )
        
        #expect(status == kCVReturnSuccess)
        let pb = try #require(pixelBuffer)
        
        // Register
        let reference = await authority.register(pixelBuffer: pb)
        #expect(reference.width == 1920)
        #expect(reference.height == 1080)
        #expect(reference.format == "bgra")
        
        // Registry should have 1 item
        let count = await authority.activeSurfaceCount()
        #expect(count == 1)
        
        // Acquire Lease
        let lease = try await authority.acquireLease(for: reference)
        #expect(lease.token == reference.token)
        
        // Resolve
        let resolvedPB = try await authority.resolvePixelBuffer(for: lease)
        #expect(resolvedPB === pb)
        
        // Release Lease
        await authority.releaseLease(lease)
        
        // Count should be 0 because leaseCount hit 0
        let finalCount = await authority.activeSurfaceCount()
        #expect(finalCount == 0)
    }
    
    @Test("Multiple leases maintain surface persistence")
    func multipleLeases() async throws {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 640, 480, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        let pb = try #require(pixelBuffer)
        
        let reference = await authority.register(pixelBuffer: pb)
        
        let lease1 = try await authority.acquireLease(for: reference)
        let lease2 = try await authority.acquireLease(for: reference)
        
        #expect(await authority.activeSurfaceCount() == 1)
        
        await authority.releaseLease(lease1)
        #expect(await authority.activeSurfaceCount() == 1) // Still held by lease2
        
        await authority.releaseLease(lease2)
        #expect(await authority.activeSurfaceCount() == 0) // Finally released
    }
    
    @Test("ZeroCopyProof generation")
    func zeroCopyProof() async throws {
        let reference = FrameReference(token: SurfaceToken(), width: 100, height: 100, format: "test")
        let proof = await authority.generateZeroCopyProof(for: reference)
        
        #expect(proof.token == reference.token)
        #expect(proof.copiedBytes == 0)
        #expect(proof.isPerfect == true)
    }
}
