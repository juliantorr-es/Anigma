import Foundation
@preconcurrency import VideoToolbox
@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import FoundationContracts
import SaturationKit
import AnigmaPrimitives
import ContractsCore
import MediaPipelineContracts

/// A Tier 3 Backend Executor that uses VideoToolbox for H.264 zero-copy decoding.
/// Produces IOSurface-backed FrameReferences and emits governance telemetry.
/// Phase 4: Conforms to Saturable for lane-based routing via extension.
public actor VideoToolboxDecodeExecutor: MediaExecutor {
    private let surfaceAuthority: SurfaceAuthority
    private let packetAuthority: PacketStreamAuthority
    private let loggingRing: SaturatedLoggingRing
    private var decompressionSession: VTDecompressionSession?
    private var eventSequence: UInt32 = 0
    
    /// Errors related to VideoToolbox decoding.
    public enum DecodeError: Error {
        case invalidContract
        case missingSampleBuffer
        case sessionCreationFailed(OSStatus)
        case decodeFailed(OSStatus)
        case invalidFormatDescription
        case noOutput
    }
    
    public init(
        surfaceAuthority: SurfaceAuthority,
        packetAuthority: PacketStreamAuthority,
        loggingRing: SaturatedLoggingRing
    ) {
        self.surfaceAuthority = surfaceAuthority
        self.packetAuthority = packetAuthority
        self.loggingRing = loggingRing
    }
    
    deinit {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
        }
    }
    
    /// Conformance to MediaExecutor. Dispatches the contract to the decoder.
    public func execute(contract: any MediaContract) async throws -> MediaReference {
        guard let decodeContract = contract as? VideoDecodeContract else {
            throw DecodeError.invalidContract
        }
        
        let token = decodeContract.packetToken
        guard let anyPacket = await packetAuthority.resolve(token: token) else {
            throw DecodeError.missingSampleBuffer
        }
        
        // CFType downcast workaround
        guard CFGetTypeID(anyPacket as CFTypeRef) == CMSampleBufferGetTypeID() else {
            throw DecodeError.missingSampleBuffer
        }
        let sampleBuffer = anyPacket as! CMSampleBuffer
        
        let output = try await decode(sampleBuffer: sampleBuffer)
        return .videoFrame(output.frame)
    }
    
    /// Decodes an H.264 sample buffer into a portable FrameReference.
    public func decode(sampleBuffer: CMSampleBuffer) async throws -> DecodeOutput {
        // 1. Ensure session is initialized for the current format
        try await ensureSession(for: sampleBuffer)
        
        guard let session = decompressionSession else {
            throw DecodeError.sessionCreationFailed(-1)
        }
        
        // 2. Wrap the callback in a continuation
        let output: DecodeOutput = try await withCheckedThrowingContinuation { continuation in
            var flagsOut: UInt32 = 0
            
            // Pass the continuation as the source frame refcon
            let refcon = UnsafeMutableRawPointer(Unmanaged.passRetained(ContinuationWrapper(continuation: continuation)).toOpaque())
            
            let status = VTDecompressionSessionDecodeFrame(
                session,
                sampleBuffer: sampleBuffer,
                flags: [._EnableAsynchronousDecompression],
                frameRefcon: refcon,
                infoFlagsOut: &flagsOut
            )
            
            if status != noErr {
                // If immediate failure, we need to release the refcon here as the callback won't run
                let wrapper = Unmanaged<ContinuationWrapper>.fromOpaque(refcon).takeRetainedValue()
                wrapper.continuation.resume(throwing: DecodeError.decodeFailed(status))
            }
        }
        
        // 3. Log execution via SaturatedLoggingRing
        try await logExecutionAudit(for: output.frame.token)
        
        return output
    }
    
    private func ensureSession(for sampleBuffer: CMSampleBuffer) async throws {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            throw DecodeError.invalidFormatDescription
        }
        
        // In Phase 0, we recreate the session if the format changes (simplified)
        if decompressionSession != nil {
            // Check if format matches existing session? For now, we just proceed.
            return
        }
        
        // Requirement: Output must be IOSurface-backed for zero-copy continuity.
        let destinationImageBufferAttributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        
        var session: VTDecompressionSession?
        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: decompressionCallback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: nil,
            imageBufferAttributes: destinationImageBufferAttributes as CFDictionary,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &session
        )
        
        guard status == noErr, let createdSession = session else {
            throw DecodeError.sessionCreationFailed(status)
        }
        
        self.decompressionSession = createdSession
    }
    
    private func logExecutionAudit(for token: SurfaceToken) async throws {
        let sequence = eventSequence
        eventSequence = eventSequence &+ 1
        
        let hashSource = "VTDecode:\(token.rawValue)"
        let hash = BLAKE3Digest.digest(Data(hashSource.utf8))
        
        let packet = SaturatedHeartbeatPacket(
            missionID: UUID(),
            packetType: .heartbeat,
            sequence: sequence,
            payloadHash: hash,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
        
        try await loggingRing.appendFromCPU(packet)
    }
}

// MARK: - Callback Bridging

private class ContinuationWrapper {
    let continuation: CheckedContinuation<DecodeOutput, Error>
    init(continuation: CheckedContinuation<DecodeOutput, Error>) {
        self.continuation = continuation
    }
}

private func decompressionCallback(
    decompressionOutputRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: UInt32,
    imageBuffer: CVImageBuffer?,
    presentationTimeStamp: CMTime,
    presentationDuration: CMTime
) {
    guard let sourceFrameRefCon = sourceFrameRefCon else { return }
    let wrapper = Unmanaged<ContinuationWrapper>.fromOpaque(sourceFrameRefCon).takeRetainedValue()
    
    if status != noErr {
        wrapper.continuation.resume(throwing: VideoToolboxDecodeExecutor.DecodeError.decodeFailed(status))
        return
    }
    
    guard let imageBuffer = imageBuffer else {
        wrapper.continuation.resume(throwing: VideoToolboxDecodeExecutor.DecodeError.noOutput)
        return
    }
    
    // We are in a C-callback. We need to call the actor's registration method.
    // Since this is Tier 3, we can assume the refcon is the actor itself.
    let executor = Unmanaged<VideoToolboxDecodeExecutor>.fromOpaque(decompressionOutputRefCon!).takeUnretainedValue()
    
    Task {
        let reference = await executor.registerAndProof(imageBuffer: imageBuffer)
        wrapper.continuation.resume(returning: reference)
    }
    
}

// MARK: - Saturable Conformance (Phase 4)

extension VideoToolboxDecodeExecutor: Saturable {
    public nonisolated var lane: MediaLane { .decode }
    
    /// Saturable process method for lane-based routing.
    /// Decodes the input using the contract's packet token and returns the decoded surface.
    /// Note: This is a Phase 4 adaptation - full encoded data as MediaSurface requires infrastructure work.
    public nonisolated func process(surface: MediaSurface, contract: any MediaContract) async throws -> MediaSurface {
        guard let decodeContract = contract as? VideoDecodeContract else {
            throw DecodeError.invalidContract
        }
        
        // Decode using the contract's packet token
        let token = decodeContract.packetToken
        guard let anyPacket = await packetAuthority.resolve(token: token) else {
            throw DecodeError.missingSampleBuffer
        }
        
        guard CFGetTypeID(anyPacket as CFTypeRef) == CMSampleBufferGetTypeID() else {
            throw DecodeError.missingSampleBuffer
        }
        let sampleBuffer = anyPacket as! CMSampleBuffer
        
        let output = try await decode(sampleBuffer: sampleBuffer)
        
        // Return the decoded frame as portable MediaSurface
        let lease = try await surfaceAuthority.acquireLease(for: output.frame)
        defer { Task { await surfaceAuthority.releaseLease(lease) } }
        let pixelBuffer = try await surfaceAuthority.resolvePixelBuffer(for: lease)
        
        // Create portable MediaSurface from native CVPixelBuffer via registry
        return SurfaceRegistry.shared.createMediaSurface(from: pixelBuffer)
    }
}

extension VideoToolboxDecodeExecutor {
    /// Internal bridge to allow the C-callback to call back into the actor.
    fileprivate func registerAndProof(imageBuffer: CVImageBuffer) async -> DecodeOutput {
        let reference = await surfaceAuthority.register(pixelBuffer: imageBuffer)
        let proof = await surfaceAuthority.generateZeroCopyProof(for: reference)
        return DecodeOutput(frame: reference, proof: proof)
    }
}
