import Foundation
import Metal
import MetalPerformanceShaders
import CoreVideo
import FoundationContracts
import MediaPipelineContracts
// Primitives are in same target

public actor MetalTransformExecutor: Saturable {

    public let lane: MediaLane = .transform
    private let surfaceAuthority: SurfaceAuthority
    private let surfaceRegistry: SurfaceRegistry
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?

    public enum TransformError: Error {
        case deviceInitializationFailed
        case transformFailed(String)
    }

    public init(surfaceAuthority: SurfaceAuthority, surfaceRegistry: SurfaceRegistry = .shared) {
        self.surfaceAuthority = surfaceAuthority
        self.surfaceRegistry = surfaceRegistry
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
    }

    public func process(surface: MediaSurface, contract: any MediaContract) async throws -> MediaSurface {
        guard let scaleContract = contract as? VideoScaleContract else {
            throw TransformError.transformFailed("Unsupported contract")
        }
        
        guard let device = device, let commandQueue = commandQueue else {
            throw TransformError.deviceInitializationFailed
        }
        
        guard let source = surface.resolveToPixelBuffer() else {
             throw TransformError.transformFailed("Unsupported surface type or unregistered surface")
        }
        
        let outputPixelBuffer = try await performMPSScaling(
            source: source,
            targetWidth: scaleContract.targetWidth,
            targetHeight: scaleContract.targetHeight,
            device: device,
            commandQueue: commandQueue
        )
        
        return surfaceRegistry.createMediaSurface(from: outputPixelBuffer)
    }
    
    private func performMPSScaling(
        source: CVPixelBuffer,
        targetWidth: Int,
        targetHeight: Int,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> CVPixelBuffer {
        
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            targetWidth,
            targetHeight,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let destination = pixelBuffer else {
            throw TransformError.transformFailed("Failed to create destination")
        }
        
        var textureCache: CVMetalTextureCache?
        let cacheStatus = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        
        guard cacheStatus == kCVReturnSuccess, let cache = textureCache else {
            throw TransformError.transformFailed("Failed to create texture cache")
        }
        
        var sourceTextureRef: CVMetalTexture?
        let _ = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, source, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(source), CVPixelBufferGetHeight(source), 0, &sourceTextureRef
        )
        
        var destinationTextureRef: CVMetalTexture?
        let _ = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, destination, nil, .bgra8Unorm,
            targetWidth, targetHeight, 0, &destinationTextureRef
        )
        
        guard let sRef = sourceTextureRef, let dRef = destinationTextureRef,
              let srcTex = CVMetalTextureGetTexture(sRef),
              let destTex = CVMetalTextureGetTexture(dRef) else {
            throw TransformError.transformFailed("Failed to create textures")
        }
        
        let scaler = MPSImageBilinearScale(device: device)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TransformError.transformFailed("Failed to create command buffer")
        }
        
        scaler.encode(commandBuffer: commandBuffer, sourceTexture: srcTex, destinationTexture: destTex)
        
        return try await withCheckedThrowingContinuation { continuation in
            commandBuffer.addCompletedHandler { cb in
                if let error = cb.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: destination)
                }
            }
            commandBuffer.commit()
        }
    }
}
