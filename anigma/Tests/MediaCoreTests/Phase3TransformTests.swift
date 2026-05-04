import Testing
import Foundation
import AVFoundation
import CoreVideo
import ContractsCore
import MediaPipelineContracts
@testable import MediaCore

@Suite("Phase 3: Transform Engine Tests")
struct Phase3TransformTests {
    let surfaceAuthority: SurfaceAuthority
    let audioAuthority: AudioBufferAuthority
    
    init() {
        self.surfaceAuthority = SurfaceAuthority()
        self.audioAuthority = AudioBufferAuthority()
    }
    
    @Test("MetalTransformExecutor: Zero-Copy Scaling lifecycle")
    func testMetalScale() async throws {
        let executor = MetalTransformExecutor(surfaceAuthority: surfaceAuthority)
        
        // 1. Create source buffer with IOSurface backing (required for Metal bridge)
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            100, 100,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard let pb = pixelBuffer else { return }
        
        // 2. Transform using new Saturable protocol
        let sourceRef = await surfaceAuthority.register(pixelBuffer: pb)
        let contract = VideoScaleContract(sourceFrame: sourceRef, targetWidth: 200, targetHeight: 200)
        
        let inputSurface = SurfaceRegistry.shared.createMediaSurface(from: pb)
        let result = try await executor.process(surface: inputSurface, contract: contract)
        
        if let output = result.resolveToPixelBuffer() {
            #expect(CVPixelBufferGetWidth(output) == 200)
            #expect(CVPixelBufferGetHeight(output) == 200)
        } else {
            Issue.record("Expected pixelBuffer result")
        }
    }
    
    @Test("AccelerateDSPExecutor: SIMD Audio Mix lifecycle")
    func testAccelerateMix() async throws {
        let executor = AccelerateDSPExecutor(audioAuthority: audioAuthority)
        
        // 1. Create source buffers
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let b1 = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        let b2 = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        b1.frameLength = 1024
        b2.frameLength = 1024
        
        let ref1 = await audioAuthority.register(pcmBuffer: b1)
        let ref2 = await audioAuthority.register(pcmBuffer: b2)
        
        // 2. Mix
        let contract = AudioMixContract(sourceBuffers: [ref1, ref2], outputFormat: "float32")
        let result = try await executor.execute(contract: contract)
        
        if case .audioBuffer(let buffer) = result {
            #expect(buffer.frameCount == 1024)
            #expect(buffer.sampleRate == 44100)
        } else {
            Issue.record("Expected audioBuffer result")
        }
    }
}
