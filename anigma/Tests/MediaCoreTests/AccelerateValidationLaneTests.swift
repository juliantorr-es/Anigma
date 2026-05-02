import Testing
import Foundation
import AVFoundation
import CoreVideo
import ContractsCore
@testable import MediaCore

@Suite("AccelerateValidationLane Tests")
struct AccelerateValidationLaneTests {
    let lane: AccelerateValidationLane
    
    init() {
        self.lane = AccelerateValidationLane()
    }
    
    @Test("Audio: Silent buffer is invalid")
    func testAudioSilence() async throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // Ensure all zeros (silence)
        memset(buffer.floatChannelData![0], 0, 1024 * MemoryLayout<Float>.size)
        
        let result = lane.validate(audioBuffer: buffer)
        #expect(result.isValid == false)
        #expect(result.reason?.contains("silence") == true)
        #expect(result.statistics?.min == 0)
        #expect(result.statistics?.max == 0)
    }
    
    @Test("Audio: Sine wave buffer is valid")
    func testAudioSignal() async throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // Generate a simple sine wave
        for i in 0..<1024 {
            buffer.floatChannelData![0][i] = sin(Float(i) * 0.1)
        }
        
        let result = lane.validate(audioBuffer: buffer)
        #expect(result.isValid == true)
        #expect(result.statistics?.min ?? 0 < -0.9)
        #expect(result.statistics?.max ?? 0 > 0.9)
    }
    
    @Test("Video: Pitch black frame is invalid")
    func testVideoBlack() async throws {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        let pb = try #require(pixelBuffer)
        
        // Ensure all zeros (black)
        CVPixelBufferLockBaseAddress(pb, [])
        memset(CVPixelBufferGetBaseAddress(pb)!, 0, CVPixelBufferGetBytesPerRow(pb) * 16)
        CVPixelBufferUnlockBaseAddress(pb, [])
        
        let result = try lane.validate(pixelBuffer: pb)
        #expect(result.isValid == false)
        #expect(result.reason?.contains("black") == true)
    }
    
    @Test("Video: Non-black frame is valid")
    func testVideoContent() async throws {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        let pb = try #require(pixelBuffer)
        
        // Fill with some data
        CVPixelBufferLockBaseAddress(pb, [])
        memset(CVPixelBufferGetBaseAddress(pb)!, 0xFF, CVPixelBufferGetBytesPerRow(pb) * 16)
        CVPixelBufferUnlockBaseAddress(pb, [])
        
        let result = try lane.validate(pixelBuffer: pb)
        #expect(result.isValid == true)
        #expect(result.statistics?.max == 255)
    }
}
