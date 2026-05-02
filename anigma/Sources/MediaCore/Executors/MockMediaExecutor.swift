//
//  MockMediaExecutor.swift
//  MediaCore
//
//  Mock executor for testing media contract execution without hardware dependencies.
//  Part of Phase 1: Unified Contracts & Backend Registry deliverables.
//
//  See POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md Part 4
//

import Foundation
import FoundationContracts
import AnigmaPrimitives

/// A mock executor that simulates media operations without actual hardware processing.
/// Used for unit testing and development when hardware backends are not available.
///
/// **Note**: This executor does NOT produce real media data. It returns mock references
/// that can be used to test contract flow and governance without actual media processing.
///
/// For integration tests requiring real MediaMemoryAuthority interaction, use
/// the in-memory test authorities instead.
public struct MockMediaExecutor: MediaExecutor, Sendable {
    
    /// Shared surface authority for generating mock frame references.
    private let surfaceAuthority: SurfaceAuthority
    
    /// Shared audio buffer authority for generating mock audio references.
    private let audioBufferAuthority: AudioBufferAuthority
    
    /// Shared packet stream authority for generating mock packet references.
    private let packetStreamAuthority: PacketStreamAuthority
    
    /// Creates a new MockMediaExecutor with the provided authorities.
    /// 
    /// - Parameters:
    ///   - surfaceAuthority: Authority for generating mock frame references
    ///   - audioBufferAuthority: Authority for generating mock audio buffer references
    ///   - packetStreamAuthority: Authority for generating mock packet stream references
    public init(
        surfaceAuthority: SurfaceAuthority = SurfaceAuthority(),
        audioBufferAuthority: AudioBufferAuthority = AudioBufferAuthority(),
        packetStreamAuthority: PacketStreamAuthority = PacketStreamAuthority()
    ) {
        self.surfaceAuthority = surfaceAuthority
        self.audioBufferAuthority = audioBufferAuthority
        self.packetStreamAuthority = packetStreamAuthority
    }
    
    /// Executes a media contract and returns a mock MediaReference.
    /// 
    /// This mock implementation returns synthetic references that can be used for testing
    /// contract dispatch and governance flow. The returned references point to mock
    /// surfaces registered with the provided authorities.
    /// 
    /// - Parameter contract: The media contract to execute
    /// - Returns: A MediaReference containing mock data for testing
    public func execute(contract: any MediaContract) async throws -> MediaReference {
        switch contract.mediaKind {
        case "video":
            return try await executeVideoContract(contract)
        case "audio":
            return try await executeAudioContract(contract)
        case "image":
            return try await executeImageContract(contract)
        default:
            throw MockExecutorError.unsupportedMediaKind(contract.mediaKind)
        }
    }
    
    // MARK: - Video Contract Execution
    
    private func executeVideoContract(_ contract: any MediaContract) async throws -> MediaReference {
        if contract is VideoDecodeContract {
            // Return a mock decoded frame
            let mockPixelBuffer = MockCVPixelBuffer(width: 1920, height: 1080)
            let frame = await surfaceAuthority.registerInternal(
                nativeSurface: mockPixelBuffer,
                width: 1920,
                height: 1080,
                format: "bgra",
                metadata: ["mock": "true", "executor": "MockMediaExecutor"]
            )
            return .videoFrame(frame)
        } else if contract is VideoScaleContract {
            // Return a mock scaled frame
            let mockPixelBuffer = MockCVPixelBuffer(width: 960, height: 540)
            let frame = await surfaceAuthority.registerInternal(
                nativeSurface: mockPixelBuffer,
                width: 960,
                height: 540,
                format: "bgra",
                metadata: ["mock": "true", "executor": "MockMediaExecutor", "scaled": "true"]
            )
            return .videoFrame(frame)
        } else if contract is VideoEncodeContract {
            // Return a mock encoded packet stream
            let packet = await packetStreamAuthority.register(
                packet: MockCMSampleBuffer(),
                codec: "h264",
                mediaType: "video",
                bitRate: 5000000
            )
            return .packetStream(packet)
        } else {
            throw MockExecutorError.unsupportedVideoContract(String(describing: type(of: contract)))
        }
    }
    
    // MARK: - Audio Contract Execution
    
    private func executeAudioContract(_ contract: any MediaContract) async throws -> MediaReference {
        if contract is AudioDecodeContract {
            // Return a mock decoded audio buffer
            // Use registerMock + direct AudioBufferReference creation to avoid
            // MockAVAudioPCMBuffer type mismatch with AVAudioPCMBuffer expectation
            let token = AudioBufferToken()
            await audioBufferAuthority.registerMock(token: token)
            let audioRef = AudioBufferReference(
                token: token,
                sampleRate: 44100.0,
                channels: 2,
                frameCount: 1024,
                format: "pcm_f32"
            )
            return .audioBuffer(audioRef)
        } else if contract is AudioMixContract {
            // Return a mock mixed audio buffer
            let token = AudioBufferToken()
            await audioBufferAuthority.registerMock(token: token)
            let audioRef = AudioBufferReference(
                token: token,
                sampleRate: 44100.0,
                channels: 2,
                frameCount: 1024,
                format: "pcm_f32"
            )
            return .audioBuffer(audioRef)
        } else {
            throw MockExecutorError.unsupportedAudioContract(String(describing: type(of: contract)))
        }
    }
    
    // MARK: - Image Contract Execution
    
    private func executeImageContract(_ contract: any MediaContract) async throws -> MediaReference {
        if contract is ImageDecodeContract {
            // Return a mock decoded image surface
            let mockImage = MockCGImage()
            let imageRef = await surfaceAuthority.registerImageInternal(
                nativeSurface: mockImage,
                width: 800,
                height: 600,
                format: "rgba"
            )
            return .imageSurface(imageRef)
        } else {
            throw MockExecutorError.unsupportedImageContract(String(describing: type(of: contract)))
        }
    }
}

// MARK: - Mock Errors

public enum MockExecutorError: Error {
    case unsupportedMediaKind(String)
    case unsupportedVideoContract(String)
    case unsupportedAudioContract(String)
    case unsupportedImageContract(String)
}

// MARK: - Mock Platform Types

/// Mock CVPixelBuffer for testing. Does not contain actual pixel data.
/// Used to generate FrameReference tokens for testing.
public struct MockCVPixelBuffer: Sendable {
    public let width: Int
    public let height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Mock CMSampleBuffer for testing. Does not contain actual sample data.
/// Used to generate PacketStreamReference tokens for testing.
public struct MockCMSampleBuffer: Sendable {}

/// Mock AVAudioPCMBuffer for testing. Does not contain actual audio samples.
/// Used to generate AudioBufferReference tokens for testing.
public struct MockAVAudioPCMBuffer: Sendable {}

/// Mock CGImage for testing. Does not contain actual image data.
/// Used to generate ImageSurfaceReference tokens for testing.
public struct MockCGImage: Sendable {}
