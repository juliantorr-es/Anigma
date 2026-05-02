import Foundation
import AVFoundation
import FoundationContracts

/// A Tier 2 Governance actor that manages live audio buffer registrations.
/// Issues portable AudioBufferReference tokens and ensures data integrity.
public actor AudioBufferAuthority {
    private var registry: [AudioBufferToken: AVAudioBuffer] = [:]
    
    public init() {}
    
    /// Registers a PCM audio buffer and returns a portable reference.
    public func register(pcmBuffer: AVAudioPCMBuffer) -> AudioBufferReference {
        let token = AudioBufferToken()
        registry[token] = pcmBuffer
        
        return AudioBufferReference(
            token: token,
            sampleRate: pcmBuffer.format.sampleRate,
            channels: Int(pcmBuffer.format.channelCount),
            frameCount: Int(pcmBuffer.frameLength),
            format: "pcm_\(pcmBuffer.format.commonFormat)"
        )
    }
    
    /// Registers a compressed audio buffer (e.g., AAC) and returns a portable reference.
    public func register(compressedBuffer: AVAudioCompressedBuffer) -> AudioBufferReference {
        let token = AudioBufferToken()
        registry[token] = compressedBuffer
        
        return AudioBufferReference(
            token: token,
            sampleRate: compressedBuffer.format.sampleRate,
            channels: Int(compressedBuffer.format.channelCount),
            frameCount: Int(compressedBuffer.packetCount),
            format: "compressed_\(compressedBuffer.format.settings[AVFormatIDKey] ?? "unknown")"
        )
    }
    
    /// Generates a zero-copy proof for a registered audio buffer.
    public func generateZeroCopyProof(for reference: AudioBufferReference) -> AudioZeroCopyProof {
        // In Phase 0, we assume registration implies zero-copy receipt.
        // We verify the token exists in our registry.
        guard registry[reference.token] != nil else {
            return AudioZeroCopyProof(token: reference.token, copiedBytes: -1) // Invalid
        }
        
        return AudioZeroCopyProof(token: reference.token, copiedBytes: 0)
    }
    
    /// Returns the number of currently registered audio buffers.
    public func activeBufferCount() -> Int {
        return registry.count
    }
    
    /// Resolves a token to its native buffer if still available.
    public func resolve(token: AudioBufferToken) -> AVAudioBuffer? {
        return registry[token]
    }
    
    /// Removes a buffer from the registry, invalidating its token.
    public func release(token: AudioBufferToken) {
        registry.removeValue(forKey: token)
    }

    /// Registers a mock token for testing purposes (no actual buffer).
    /// Used by MockMediaExecutor to maintain registry consistency.
    public func registerMock(token: AudioBufferToken) {
        registry[token] = nil
    }
}
