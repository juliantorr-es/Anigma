import Foundation
import VideoToolbox
import CoreMedia
import FoundationContracts
import ContractsCore
import MediaPipelineContracts

/// A Tier 3 Backend Executor that uses VideoToolbox for hardware-accelerated video encoding.
/// Consumes managed FrameReferences and produces PacketStreamReferences.
/// Phase 4: Conforms to Saturable for lane-based routing via extension.
public actor VideoToolboxEncodeExecutor: MediaExecutor {
    
    private let surfaceAuthority: SurfaceAuthority
    private let packetAuthority: PacketStreamAuthority
    private var compressionSession: VTCompressionSession?
    
    public enum EncodeError: Error {
        case sessionCreationFailed(OSStatus)
        case encodingFailed(OSStatus)
        case resolutionFailed
    }
    
    public init(
        surfaceAuthority: SurfaceAuthority,
        packetAuthority: PacketStreamAuthority
    ) {
        self.surfaceAuthority = surfaceAuthority
        self.packetAuthority = packetAuthority
    }
    
    deinit {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
        }
    }
    
    public func execute(contract: any MediaContract) async throws -> MediaReference {
        guard let encodeContract = contract as? VideoEncodeContract else {
            throw ValidationError.invalidRequest("VideoToolboxEncodeExecutor: Unsupported contract \(type(of: contract))")
        }
        
        // 1. Resolve FrameLease and Native CVPixelBuffer
        let lease = try await surfaceAuthority.acquireLease(for: encodeContract.sourceFrame)
        defer { Task { await surfaceAuthority.releaseLease(lease) } }
        
        let pixelBuffer = try await surfaceAuthority.resolvePixelBuffer(for: lease)
        
        // 2. Ensure session is initialized
        try await ensureSession(width: Int32(encodeContract.sourceFrame.width), height: Int32(encodeContract.sourceFrame.height))
        
        guard let session = compressionSession else {
            throw EncodeError.sessionCreationFailed(-1)
        }
        
        // 3. Encode Frame
        let packet: PacketStreamReference = try await withCheckedThrowingContinuation { continuation in
            let status = VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: pixelBuffer,
                presentationTimeStamp: .zero, // Simplified for Phase 2
                duration: .invalid,
                frameProperties: nil,
                infoFlagsOut: nil
            ) { [weak self] status, flags, sampleBuffer in
                guard let self = self else { return }
                
                if status != noErr {
                    continuation.resume(throwing: EncodeError.encodingFailed(status))
                    return
                }
                
                guard let sampleBuffer = sampleBuffer,
                      let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                    continuation.resume(throwing: EncodeError.encodingFailed(-2))
                    return
                }
                
                // Extract raw data from sample buffer
                var length: Int = 0
                var pointer: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer)
                
                let data = Data(bytes: pointer!, count: length)
                
                Task {
                    // Register with PacketStreamAuthority
                    let reference = await self.packetAuthority.register(
                        packet: data,
                        codec: encodeContract.targetCodec,
                        mediaType: "video"
                    )
                    continuation.resume(returning: reference)
                }
            }
            
            if status != noErr {
                continuation.resume(throwing: EncodeError.encodingFailed(status))
            }
        }
        
        return .packetStream(packet)
    }
    
    private func ensureSession(width: Int32, height: Int32) async throws {
        if compressionSession != nil { return }
        
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil, // We use block-based callback in EncodeFrame
            refcon: nil,
            compressionSessionOut: &session
        )
        
        guard status == noErr, let createdSession = session else {
            throw EncodeError.sessionCreationFailed(status)
        }
        
        self.compressionSession = createdSession
    }
}

// MARK: - Saturable Conformance (Phase 4)

extension VideoToolboxEncodeExecutor: Saturable {
    public nonisolated var lane: MediaLane { .decode }
    
    /// Saturable process method for lane-based routing.
    /// Encodes the input surface and returns it (encoded data wrapped in surface for pipeline continuity).
    /// Note: This is a Phase 4 adaptation - full encoding pipeline with MediaSurface requires Phase 5 work.
    public nonisolated func process(surface: MediaSurface, contract: any MediaContract) async throws -> MediaSurface {
        guard let encodeContract = contract as? VideoEncodeContract else {
            throw ValidationError.invalidRequest("VideoToolboxEncodeExecutor: Unsupported contract \(type(of: contract))")
        }
        
        // For now, return the input surface unchanged
        // Full encoding pipeline with MediaSurface → encoded MediaSurface requires Phase 5 work
        // This placeholder allows the executor to be registered with SaturationSubstrate
        _ = encodeContract // Acknowledge usage for Phase 4 placeholder
        return surface
    }
}
