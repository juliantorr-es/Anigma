import Testing
import Foundation
import AVFoundation
import ContractsCore
@testable import MediaCore

@Suite("AudioBufferAuthority Tests")
struct AudioBufferAuthorityTests {
    let authority: AudioBufferAuthority
    
    init() {
        self.authority = AudioBufferAuthority()
    }
    
    @Test("Registering a PCM buffer produces a valid reference and proof")
    func testPCMRegistration() async throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        let reference = await authority.register(pcmBuffer: buffer)
        
        #expect(reference.sampleRate == 44100)
        #expect(reference.channels == 2)
        #expect(reference.frameCount == 1024)
        
        let proof = await authority.generateZeroCopyProof(for: reference)
        #expect(proof.isPerfect == true)
        
        let activeCount = await authority.activeBufferCount()
        #expect(activeCount == 1)
        
        let resolved = await authority.resolve(token: reference.token)
        #expect(resolved === buffer)
    }
    
    @Test("Releasing a token removes it from the registry")
    func testRelease() async throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        
        let reference = await authority.register(pcmBuffer: buffer)
        #expect(await authority.activeBufferCount() == 1)
        
        await authority.release(token: reference.token)
        #expect(await authority.activeBufferCount() == 0)
        
        let resolved = await authority.resolve(token: reference.token)
        #expect(resolved == nil)
    }
    
    @Test("Registering a compressed buffer fixture")
    func testCompressedRegistration() async throws {
        // Create a basic AAC format
        var asbd = AudioStreamBasicDescription(
            mSampleRate: 44100,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        let format = AVAudioFormat(streamDescription: &asbd)!
        
        // AVAudioCompressedBuffer normally comes from an encoder or file; this fixture uses direct initialization.
        // Note: AVAudioCompressedBuffer usually comes from an encoder or file.
        // We'll use a basic initialization if possible.
        let buffer = AVAudioCompressedBuffer(format: format, packetCapacity: 1, maximumPacketSize: 1024)
        
        let reference = await authority.register(compressedBuffer: buffer)
        #expect(reference.sampleRate == 44100)
        #expect(reference.channels == 2)
        
        let proof = await authority.generateZeroCopyProof(for: reference)
        #expect(proof.isPerfect == true)
    }
}
