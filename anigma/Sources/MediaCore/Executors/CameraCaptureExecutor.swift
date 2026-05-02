import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import FoundationContracts
import AnigmaPrimitives

/// A Tier 3 Backend Executor that manages native camera capture via AVFoundation.
/// Requires a valid CaptureReceipt for initialization and bridges frames to SurfaceAuthority.
public actor CameraCaptureExecutor: NSObject {
    private let surfaceAuthority: SurfaceAuthority
    private let receipt: CaptureReceipt
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.anigma.media.camera-capture", qos: .userInteractive)
    
    private var streamContinuation: AsyncThrowingStream<FrameReference, Error>.Continuation?
    
    public enum CameraError: Error, Equatable {
        case invalidReceiptType
        case deviceNotFound
        case inputCreationFailed
        case setupFailed(String)
    }
    
    public init(surfaceAuthority: SurfaceAuthority, receipt: CaptureReceipt) throws {
        guard receipt.type == .video else {
            throw CameraError.invalidReceiptType
        }
        self.surfaceAuthority = surfaceAuthority
        self.receipt = receipt
        super.init()
    }
    
    /// Starts the camera capture stream.
    public func start(configuration: CaptureConfiguration = .standard) -> AsyncThrowingStream<FrameReference, Error> {
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
        
        // 1. Configure Preset
        let preset = AVCaptureSession.Preset(rawValue: config.preset)
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        }
        
        // 2. Add Input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.deviceNotFound
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                throw CameraError.setupFailed("Cannot add camera input")
            }
        } catch {
            throw CameraError.inputCreationFailed
        }
        
        // 3. Add Output
        if session.canAddOutput(output) {
            session.addOutput(output)
            
            // Critical for zero-copy: Require IOSurface-backed buffers
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
            ]
            
            output.setSampleBufferDelegate(self, queue: queue)
        } else {
            throw CameraError.setupFailed("Cannot add camera output")
        }
    }
}

extension CameraCaptureExecutor: AVCaptureVideoDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        Task {
            await handleFrame(imageBuffer)
        }
    }
    
    internal func handleFrame(_ imageBuffer: CVImageBuffer) async {
        // Register frame with SurfaceAuthority to get a portable FrameReference
        let frameRef = await surfaceAuthority.register(pixelBuffer: imageBuffer)
        streamContinuation?.yield(frameRef)
    }
}
