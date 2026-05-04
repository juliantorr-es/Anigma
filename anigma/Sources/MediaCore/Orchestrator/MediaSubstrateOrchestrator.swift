import Foundation
import AVFoundation
import FoundationContracts
import MediaPipelineContracts
import EvidenceContracts
import SaturationKit
import AnigmaPrimitives
import CoreVideo

/// Phase 4: GovernanceLogger implementation that adapts to SaturatedLoggingRing
/// For now, uses a no-op implementation since full governance integration
/// requires dedicated AuditPacket infrastructure
private struct NoOpGovernanceLogger: GovernanceLogger {
    func log(event: MaterializationEvent) async throws {
        // Phase 4: Placeholder implementation
        // Full governance logging with MaterializationEvent → SaturatedLoggingRing
        // adaptation will be implemented in a future iteration
        // For now, the SaturationSubstrate is wired but uses a no-op logger
    }
}

/// The primary Tier 1 entry point for the Unified Media Substrate.
/// Orchestrates capture executors, governance authorities, validation lanes, and evidence adapters.
/// 
/// **Phase 0**: Uses MediaMemoryAuthority as the keystone for all live media memory.
/// **Phase 1+**: Adds contract execution, backend registry, and execution pipelines.
public actor MediaSubstrateOrchestrator {
    private let mediaMemoryAuthority: MediaMemoryAuthority
    private let captureAuthority: CaptureAuthority
    private let loggingRing: SaturatedLoggingRing
    private let artifactStore: any MediaArtifactStore
    
    private let validationLane = AccelerateValidationLane()
    private let evidenceAdapter = CryptoKitEvidenceAdapter()
    private let backendRegistry = MediaBackendRegistry()
    
    // Phase 4: SaturationSubstrate for lane-based transform pipelines
    private let saturationSubstrate: SaturationSubstrate
    
    /// Creates a new MediaSubstrateOrchestrator with the keystone MediaMemoryAuthority.
    ///
    /// - Parameters:
    ///   - mediaMemoryAuthority: The keystone authority owning all live media memory (Phase 0)
    ///   - captureAuthority: Authority managing capture sources
    ///   - loggingRing: Ring for saturated telemetry logging
    ///   - artifactStore: Store for durable media artifacts
    public init(
        mediaMemoryAuthority: MediaMemoryAuthority,
        captureAuthority: CaptureAuthority,
        loggingRing: SaturatedLoggingRing,
        artifactStore: any MediaArtifactStore
    ) {
        self.mediaMemoryAuthority = mediaMemoryAuthority
        self.captureAuthority = captureAuthority
        self.loggingRing = loggingRing
        self.artifactStore = artifactStore
        // Phase 4: Initialize SaturationSubstrate with governance logger
        // Phase 5: Add backpressure and queuing configuration
        let logger = NoOpGovernanceLogger()
        self.saturationSubstrate = SaturationSubstrate(
            logger: logger,
            maxConcurrentRequests: 10,
            backpressureThreshold: 0.8
        )
    }
    
    /// Convenience initializer that creates a MediaMemoryAuthority from individual authorities.
    /// This is useful for migration from pre-Phase 0 code.
    public init(
        captureAuthority: CaptureAuthority,
        surfaceAuthority: SurfaceAuthority,
        audioAuthority: AudioBufferAuthority,
        packetAuthority: PacketStreamAuthority,
        loggingRing: SaturatedLoggingRing,
        artifactStore: any MediaArtifactStore,
        materializationGate: MaterializationGate
    ) {
        let mediaMemoryAuthority = MediaMemoryAuthority(
            surfaceAuthority: surfaceAuthority,
            audioBufferAuthority: audioAuthority,
            packetStreamAuthority: packetAuthority,
            materializationGate: materializationGate,
            loggingRing: loggingRing
        )
        self.mediaMemoryAuthority = mediaMemoryAuthority
        self.captureAuthority = captureAuthority
        self.loggingRing = loggingRing
        self.artifactStore = artifactStore
        // Phase 4: Initialize SaturationSubstrate with governance logger
        // Phase 5: Add backpressure and queuing configuration
        let logger = NoOpGovernanceLogger()
        self.saturationSubstrate = SaturationSubstrate(
            logger: logger,
            maxConcurrentRequests: 10,
            backpressureThreshold: 0.8
        )
    }
    
    // MARK: - Authority Access
    
    /// Returns the keystone MediaMemoryAuthority.
    public func getMediaMemoryAuthority() -> MediaMemoryAuthority {
        return mediaMemoryAuthority
    }
    
    /// Returns the SurfaceAuthority for video/image surface management.
    public func getSurfaceAuthority() async -> SurfaceAuthority {
        return await mediaMemoryAuthority.getSurfaceAuthority()
    }
    
    /// Returns the AudioBufferAuthority for audio buffer management.
    public func getAudioBufferAuthority() async -> AudioBufferAuthority {
        return await mediaMemoryAuthority.getAudioBufferAuthority()
    }
    
    /// Returns the PacketStreamAuthority for packet stream management.
    public func getPacketStreamAuthority() async -> PacketStreamAuthority {
        return await mediaMemoryAuthority.getPacketStreamAuthority()
    }
    
    /// Returns the MaterializationGate for copy governance.
    public func getMaterializationGate() async -> MaterializationGate {
        return await mediaMemoryAuthority.getMaterializationGate()
    }
    
    // MARK: - Saturation Pipeline (Phase 4)
    
    /// Returns the SaturationSubstrate for lane-based transform pipelines.
    public func getSaturationSubstrate() -> SaturationSubstrate {
        return saturationSubstrate
    }
    
    /// Registers a Saturable node with the SaturationSubstrate.
    /// Phase 4: Allows dynamic registration of executors for lane-based routing.
    public func registerSaturableNode(_ node: any Saturable) async {
        await saturationSubstrate.register(node: node)
    }
    
    // MARK: - Phase 5: Backpressure & Monitoring
    
    /// Returns current hardware saturation metrics.
    public func getSaturationMetrics() async -> HardwareSaturationMetrics {
        await saturationSubstrate.getSaturationMetrics()
    }
    
    /// Checks if the system is currently under backpressure.
    public func isUnderBackpressure() async -> Bool {
        await saturationSubstrate.isUnderBackpressure()
    }
    
    /// Enqueues a saturation request for later processing.
    /// Phase 5: Unified request queuing
    public func enqueueSaturationRequest(
        surface: MediaSurface,
        lane: MediaLane,
        contract: any MediaContract,
        priority: Int = 0
    ) async throws {
        let request = SaturationRequest(
            surface: surface,
            lane: lane,
            contract: contract,
            priority: priority
        )
        try await saturationSubstrate.enqueue(request: request)
    }
    
    /// Processes the next request from the saturation queue.
    public func processNextSaturationRequest() async throws -> MediaSurface? {
        try await saturationSubstrate.processNextRequest()
    }
    
    /// Processes all pending requests in the saturation queue.
    public func processAllSaturationRequests() async throws -> [MediaSurface] {
        try await saturationSubstrate.processAllRequests()
    }
    
    // MARK: - Contract Execution (Phase 1)
    
    /// Executes a governed media contract by selecting the optimal backend executor.
    public func execute(contract: any MediaContract) async throws -> MediaReference {
        let kind = try await backendRegistry.selectExecutor(for: contract)
        
        // Audit the dispatch event
        try await logDispatchEvent(contract: contract, executor: kind)
        
        switch kind {
        case .videoToolbox:
            if let decodeContract = contract as? VideoDecodeContract {
                let executor = VideoToolboxDecodeExecutor(
                    surfaceAuthority: await getSurfaceAuthority(),
                    packetAuthority: await getPacketStreamAuthority(),
                    loggingRing: loggingRing
                )
                return try await executor.execute(contract: decodeContract)
            }
            if let encodeContract = contract as? VideoEncodeContract {
                let executor = VideoToolboxEncodeExecutor(
                    surfaceAuthority: await getSurfaceAuthority(),
                    packetAuthority: await getPacketStreamAuthority()
                )
                return try await executor.execute(contract: encodeContract)
            }
            return try await unsupportedContractFallback(contract: contract)
            
        case .imageIO:
            let executor = ImageIODecodeExecutor(
                surfaceAuthority: await getSurfaceAuthority(),
                artifactStore: artifactStore
            )
            return try await executor.execute(contract: contract)
            
        case .audioToolbox:
            if let audioContract = contract as? AudioDecodeContract {
                let executor = AudioToolboxDecodeExecutor(
                    audioAuthority: await getAudioBufferAuthority(),
                    artifactStore: artifactStore
                )
                return try await executor.execute(contract: audioContract)
            }
            return try await unsupportedContractFallback(contract: contract)
            
        case .metal:
            // Phase 4: Route through SaturationSubstrate
            guard let videoContract = contract as? VideoScaleContract else { 
                throw MediaError.laneUnavailable(.transform) 
            }
            let surfaceAuth = await getSurfaceAuthority()
            let lease = try await surfaceAuth.acquireLease(for: videoContract.sourceFrame)
            let native = try await surfaceAuth.resolveNativeSurface(for: lease) as! CVPixelBuffer
            
            // Create and register MetalTransformExecutor as a Saturable node
            let executor = MetalTransformExecutor(surfaceAuthority: surfaceAuth, surfaceRegistry: .shared)
            await saturationSubstrate.register(node: executor)
            
            // Wrap native CVPixelBuffer in portable MediaSurface
            let surfaceToken = SurfaceRegistry.shared.register(pixelBuffer: native)
            let inputSurface = MediaSurface(
                token: surfaceToken,
                kind: .pixelBuffer,
                width: CVPixelBufferGetWidth(native),
                height: CVPixelBufferGetHeight(native),
                byteCount: CVPixelBufferGetByteCount(native)
            )
            
            let result = try await saturationSubstrate.process(
                surface: inputSurface,
                lane: .transform,
                contract: contract
            )
            
            // Map surface back to MediaReference
            if let buffer = result.resolveToPixelBuffer() {
                let frame = await surfaceAuth.registerInternal(
                    nativeSurface: buffer,
                    width: videoContract.targetWidth,
                    height: videoContract.targetHeight,
                    format: videoContract.sourceFrame.format,
                    metadata: ["transformed": "metal", "engine": "mps", "substrate": "saturated"]
                )
                return .videoFrame(frame)
            }
            throw MediaError.laneUnavailable(.transform)
            
        case .accelerate:
            let executor = AccelerateDSPExecutor(audioAuthority: await getAudioBufferAuthority())
            return try await executor.execute(contract: contract)
            
        default:
            throw MediaError.laneUnavailable(.transform) // General fallback for unsupported kinds
        }
    }
    
    // MARK: - Ingestion (Phase 0)
    
    /// A single governed frame package containing the frame reference and its security/health proofs.
    public struct GovernedMediaFrame: Sendable {
        public let reference: FrameReference
        public let validation: SIMDValidationResult
        public let fingerprint: MediaFingerprint
        public let proof: ZeroCopyProof
    }
    
    /// A governed audio package.
    public struct GovernedAudioFrame: Sendable {
        public let reference: AudioBufferReference
        public let validation: SIMDValidationResult
    }
    
    /// Starts a governed video ingestion stream.
    public func ingestVideo(configuration: CaptureConfiguration = .standard) async throws -> (
        AsyncThrowingStream<GovernedMediaFrame, Error>,
        AsyncStream<GovernanceStripState>
    ) {
        let receipt = try await captureAuthority.requestCapture(type: .video)
        
        let gate = CaptureAcceptanceGate(
            captureAuthority: captureAuthority,
            receipt: receipt,
            loggingRing: loggingRing
        )
        
        let executor = try CameraCaptureExecutor(
            surfaceAuthority: await getSurfaceAuthority(),
            receipt: receipt
        )
        let rawStream = await executor.start(configuration: configuration)
        
        let monitoredStream = await gate.monitor(stream: rawStream)
        
        let governedStream = AsyncThrowingStream<GovernedMediaFrame, Error> { continuation in
            let task = Task {
                do {
                    for try await frame in monitoredStream {
                        let surfaceAuth = await getSurfaceAuthority()
                        let lease = try await surfaceAuth.acquireLease(for: frame)
                        let native = try await surfaceAuth.resolveNativeSurface(for: lease)
                        
                        let pixelBuffer = native as! CVPixelBuffer
                        
                        let validationResult = try validationLane.validate(pixelBuffer: pixelBuffer)
                        let fingerprint = try await evidenceAdapter.generateFingerprint(for: pixelBuffer)
                        let proof = await surfaceAuth.generateZeroCopyProof(for: frame)
                        
                        await surfaceAuth.releaseLease(lease)
                        
                        continuation.yield(GovernedMediaFrame(
                            reference: frame,
                            validation: validationResult,
                            fingerprint: fingerprint,
                            proof: proof
                        ))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
        
        let stripStream = await gate.stripStateStream
        return (governedStream, stripStream)
    }
    
    /// Starts a governed audio ingestion stream.
    public func ingestAudio() async throws -> AsyncThrowingStream<GovernedAudioFrame, Error> {
        let receipt = try await captureAuthority.requestCapture(type: .audio)
        
        let executor = try MicrophoneCaptureExecutor(
            audioAuthority: await getAudioBufferAuthority(),
            receipt: receipt
        )
        let rawStream = await executor.start()
        
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await reference in rawStream {
                        let audioAuth = await getAudioBufferAuthority()
                        guard let buffer = await audioAuth.resolve(token: reference.token) as? AVAudioPCMBuffer else {
                            continue
                        }
                        
                        let validationResult = validationLane.validate(audioBuffer: buffer)
                        
                        continuation.yield(GovernedAudioFrame(
                            reference: reference,
                            validation: validationResult
                        ))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func logDispatchEvent(contract: any MediaContract, executor: MediaBackendRegistry.ExecutorKind) async throws {
        let sequence: UInt32 = 0 // Sequence management would be here
        let hashSource = "Dispatch:\(contract.mediaKind):\(executor.rawValue)"
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

    private func unsupportedContractFallback(contract: any MediaContract) async throws -> MediaReference {
        throw ValidationError.invalidRequest(
            "No concrete media executor for \(type(of: contract)); selected backend requires a supported contract shape"
        )
    }
}
