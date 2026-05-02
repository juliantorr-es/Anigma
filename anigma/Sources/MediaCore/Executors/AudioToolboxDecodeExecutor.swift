import Foundation
import AVFoundation
import FoundationContracts
import MediaPipelineContracts
import ContractsCore

/// A Tier 3 Backend Executor that uses AudioToolbox/AVFoundation for high-performance audio decoding.
/// Produces managed AudioBufferReferences in the AudioBufferAuthority substrate.
/// Phase 4: Conforms to Saturable for lane-based routing.
public struct AudioToolboxDecodeExecutor: MediaExecutor, Saturable {
    public let lane: MediaLane = .decode
    
    private let audioAuthority: AudioBufferAuthority
    private let artifactStore: any MediaArtifactStore
    
    public enum AudioError: Error {
        case fileOpeningFailed(Error)
        case decodingFailed(Error)
        case invalidFormat
        case artifactNotFound
    }
    
    public init(audioAuthority: AudioBufferAuthority, artifactStore: any MediaArtifactStore) {
        self.audioAuthority = audioAuthority
        self.artifactStore = artifactStore
    }
    
    public func execute(contract: any MediaContract) async throws -> MediaReference {
        guard let audioContract = contract as? AudioDecodeContract else {
            throw ValidationError.invalidRequest("AudioToolboxDecodeExecutor: Unsupported contract \(type(of: contract))")
        }
        
        // 1. Resolve artifact data
        let (data, _) = try await artifactStore.loadRaw(audioContract.artifactId.uuidString)
        
        // 2. Write to temporary file for AVAudioFile (standard requirement for compressed intake)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        do {
            let audioFile = try AVAudioFile(forReading: tempURL)
            let format = audioFile.processingFormat
            let frameCount = UInt32(audioFile.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw AudioError.invalidFormat
            }
            
            try audioFile.read(into: buffer)
            
            // Register with AudioBufferAuthority
            let reference = await audioAuthority.register(pcmBuffer: buffer)
            return .audioBuffer(reference)
            
        } catch {
            throw AudioError.decodingFailed(error)
        }
    }
    
    // MARK: - Saturable Conformance (Phase 4)
    
    /// Saturable process method for lane-based routing.
    /// Note: This is a Phase 4 placeholder - full audio MediaSurface integration requires Phase 5 work.
    public func process(surface: MediaSurface, contract: any MediaContract) async throws -> MediaSurface {
        // AudioToolboxDecodeExecutor works with AVAudioPCMBuffer, not MediaSurface
        // Full integration requires MediaSurface support for audio buffers
        // For Phase 4, return the input surface unchanged as a placeholder
        return surface
    }
}
