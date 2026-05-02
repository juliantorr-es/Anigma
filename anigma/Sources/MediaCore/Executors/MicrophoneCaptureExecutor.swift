import Foundation
import AVFoundation
import CoreMedia
import FoundationContracts

/// A Tier 3 Backend Executor that manages native microphone capture via AVFoundation.
/// Requires a valid CaptureReceipt for initialization and bridges buffers to AudioBufferAuthority.
public actor MicrophoneCaptureExecutor: NSObject {
    private let audioAuthority: AudioBufferAuthority
    private let receipt: CaptureReceipt
    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "com.anigma.media.microphone-capture", qos: .userInteractive)
    
    private var streamContinuation: AsyncThrowingStream<AudioBufferReference, Error>.Continuation?
    
    public enum MicrophoneError: Error, Equatable {
        case invalidReceiptType
        case deviceNotFound
        case inputCreationFailed
        case setupFailed(String)
    }
    
    public init(audioAuthority: AudioBufferAuthority, receipt: CaptureReceipt) throws {
        guard receipt.type == .audio else {
            throw MicrophoneError.invalidReceiptType
        }
        self.audioAuthority = audioAuthority
        self.receipt = receipt
        super.init()
    }
    
    /// Starts the microphone capture stream.
    public func start(configuration: CaptureConfiguration = .standard) -> AsyncThrowingStream<AudioBufferReference, Error> {
        return AsyncThrowingStream { continuation in
            self.streamContinuation = continuation
            
            Task {
                do {
                    try await setupSession(with: configuration)
                    session.startRunning()
                    
                    continuation.onTermination = { @Sendable _ in
                        Task { await self.stop() }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Stops the capture session.
    public func stop() {
        if session.isRunning {
            session.stopRunning()
        }
        streamContinuation?.finish()
        streamContinuation = nil
    }
    
    private func setupSession(with config: CaptureConfiguration) async throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // 1. Add Input
        guard let device = AVCaptureDevice.default(for: .audio) else {
            throw MicrophoneError.deviceNotFound
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                throw MicrophoneError.setupFailed("Cannot add microphone input")
            }
        } catch {
            throw MicrophoneError.inputCreationFailed
        }
        
        // 2. Add Output
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setSampleBufferDelegate(self, queue: queue)
        } else {
            throw MicrophoneError.setupFailed("Cannot add microphone output")
        }
    }
}

extension MicrophoneCaptureExecutor: AVCaptureAudioDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        Task {
            await handleAudioBuffer(sampleBuffer)
        }
    }
    
    internal func handleAudioBuffer(_ sampleBuffer: CMSampleBuffer) async {
        // In a real implementation, we'd convert CMSampleBuffer to AVAudioPCMBuffer.
        // For Phase 0 validation, we bridge a synthetic buffer if needed or skip if degenerate.
        // For the orchestrator to work, we need an AudioBufferReference.
        
        // Dummy conversion for Phase 0 Orchestration proof
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
        if let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) {
            pcmBuffer.frameLength = 1024
            let reference = await audioAuthority.register(pcmBuffer: pcmBuffer)
            streamContinuation?.yield(reference)
        }
    }
}
