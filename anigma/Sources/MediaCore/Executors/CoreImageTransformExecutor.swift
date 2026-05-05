//
//  CoreImageTransformExecutor.swift
//  MediaCore
//
//  Phase 3: CoreImage Transform Executor
//  GPU-accelerated image processing using CoreImage framework.
//
//  See POLYTROPOS_SATURATED_MEDIA_BACKEND_COMPREHENSIVE_SPEC.md Part 5
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import FoundationContracts
import MediaPipelineContracts

/// A media executor that performs image transformations using CoreImage.
/// Supports hardware-accelerated filtering, color correction, and geometry transforms.
///
/// **Tier 2b**: Swappable implementation for image processing.
/// **Hardware**: Uses GPU acceleration when available, falls back to CPU.
/// **Zero-copy**: Maintains GPU-resident surfaces when possible.
public actor CoreImageTransformExecutor: MediaExecutor {
    
    private let surfaceAuthority: SurfaceAuthority
    private let context: CIContext
    
    public enum TransformError: Error {
        case ciContextCreationFailed
        case filterCreationFailed(String)
        case surfaceConversionFailed
        case unsupportedOperation(String)
        case outputImageCreationFailed
    }
    
    /// Creates a new CoreImageTransformExecutor.
    /// 
    /// - Parameter surfaceAuthority: The authority for registering output surfaces
    public init(surfaceAuthority: SurfaceAuthority) {
        self.surfaceAuthority = surfaceAuthority
        
        // Create CIContext with Metal backend for GPU acceleration
        // Falls back to CPU if Metal is not available
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.context = CIContext(mtlDevice: metalDevice)
        } else {
            self.context = CIContext()
        }
    }
    
    /// Executes a media contract using CoreImage processing.
    /// 
    /// - Parameter contract: The media contract to execute
    /// - Returns: A MediaReference containing the transformed result
    public func execute(contract: any MediaContract) async throws -> MediaReference {
        // Currently handles image transform contracts
        // Will be extended as new CoreImage contract types are added
        
        if let filterContract = contract as? ImageFilterContract {
            return try await applyFilter(contract: filterContract)
        }
        
        if let resizeContract = contract as? ImageResizeContract {
            return try await applyResize(contract: resizeContract)
        }
        
        if let colorContract = contract as? ImageColorAdjustmentContract {
            return try await applyColorAdjustment(contract: colorContract)
        }
        
        throw TransformError.unsupportedOperation("CoreImage: Unsupported contract type: \(type(of: contract))")
    }
    
    // MARK: - Filter Application
    
    private func applyFilter(contract: ImageFilterContract) async throws -> MediaReference {
        // Resolve the source image surface to a CIImage
        let imageLease = try await surfaceAuthority.acquireImageLease(for: contract.sourceImage)
        let native = try await surfaceAuthority.resolveNativeSurface(for: imageLease)
       
        
        let ciImage: CIImage
        
        // Convert various surface types to CIImage
        if native is CGImage {
            let cgImage = native as! CGImage
            ciImage = CIImage(cgImage: cgImage)
        } else if native is CVPixelBuffer {
            let pixelBuffer = native as! CVPixelBuffer
            ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        } else {
            throw TransformError.surfaceConversionFailed
        }
        
        // Apply the specified filter
        let filteredImage = try applyCIFilter(name: contract.filterName, to: ciImage)
        
        // Create output CVPixelBuffer
        let outputPixelBuffer = try createOutputPixelBuffer(from: filteredImage, width: contract.targetWidth, height: contract.targetHeight)
        
        // Register and release
        let frame = await surfaceAuthority.registerInternal(
            nativeSurface: outputPixelBuffer,
            width: contract.targetWidth,
            height: contract.targetHeight,
            format: "bgra",
            metadata: ["executor": "CoreImageTransformExecutor", "filter": contract.filterName]
        )
        await surfaceAuthority.releaseImageLease(imageLease)
        
        return .videoFrame(frame)
    }
    
    private func applyCIFilter(name: String, to image: CIImage) throws -> CIImage {
        guard let filter = CIFilter(name: name) else {
            throw TransformError.filterCreationFailed("Unknown filter: \(name)")
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        
        guard let outputImage = filter.outputImage else {
            throw TransformError.filterCreationFailed("Filter \(name) produced no output")
        }
        
        return outputImage
    }
    
    // MARK: - Resize
    
    private func applyResize(contract: ImageResizeContract) async throws -> MediaReference {
        // Resolve the source image
        let imageLease = try await surfaceAuthority.acquireImageLease(for: contract.sourceImage)
        let native = try await surfaceAuthority.resolveNativeSurface(for: imageLease)
        
        let ciImage: CIImage
        
        if native is CGImage {
            let cgImage = native as! CGImage
            ciImage = CIImage(cgImage: cgImage)
        } else if native is CVPixelBuffer {
            let pixelBuffer = native as! CVPixelBuffer
            ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        } else {
            throw TransformError.surfaceConversionFailed
        }
        
        // Create resize filter
        let resizeFilter = CIFilter.lanczosScaleTransform()
        resizeFilter.inputImage = ciImage
        resizeFilter.scale = Float(contract.targetWidth) / Float(ciImage.extent.width)
        resizeFilter.aspectRatio = Float(contract.targetHeight) / Float(contract.targetWidth)
        
        guard let resizedImage = resizeFilter.outputImage else {
            throw TransformError.outputImageCreationFailed
        }
        
        // Create output buffer
        let outputPixelBuffer = try createOutputPixelBuffer(from: resizedImage, width: contract.targetWidth, height: contract.targetHeight)
        
        let frame = await surfaceAuthority.registerInternal(
            nativeSurface: outputPixelBuffer,
            width: contract.targetWidth,
            height: contract.targetHeight,
            format: "bgra",
            metadata: ["executor": "CoreImageTransformExecutor", "operation": "resize"]
        )
        await surfaceAuthority.releaseImageLease(imageLease)
        
        return .videoFrame(frame)
    }
    
    // MARK: - Color Adjustment
    
    private func applyColorAdjustment(contract: ImageColorAdjustmentContract) async throws -> MediaReference {
        let imageLease = try await surfaceAuthority.acquireImageLease(for: contract.sourceImage)
        let native = try await surfaceAuthority.resolveNativeSurface(for: imageLease)
        
        let ciImage: CIImage
        
        if native is CGImage {
            let cgImage = native as! CGImage
            ciImage = CIImage(cgImage: cgImage)
        } else if native is CVPixelBuffer {
            let pixelBuffer = native as! CVPixelBuffer
            ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        } else {
            throw TransformError.surfaceConversionFailed
        }
        
        // Build color adjustment filter chain
        var currentImage = ciImage
        
        if let brightness = contract.brightness {
            let filter = CIFilter.colorControls()
            filter.inputImage = currentImage
            filter.brightness = brightness
            currentImage = filter.outputImage ?? currentImage
        }
        
        if let contrast = contract.contrast {
            let filter = CIFilter.colorControls()
            filter.inputImage = currentImage
            filter.contrast = contrast
            currentImage = filter.outputImage ?? currentImage
        }
        
        if let saturation = contract.saturation {
            let filter = CIFilter.colorControls()
            filter.inputImage = currentImage
            filter.saturation = saturation
            currentImage = filter.outputImage ?? currentImage
        }
        
        if let exposure = contract.exposure {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = currentImage
            filter.ev = exposure
            currentImage = filter.outputImage ?? currentImage
        }
        
        // Create output buffer
        let outputPixelBuffer = try createOutputPixelBuffer(from: currentImage, width: contract.targetWidth, height: contract.targetHeight)
        
        let frame = await surfaceAuthority.registerInternal(
            nativeSurface: outputPixelBuffer,
            width: contract.targetWidth,
            height: contract.targetHeight,
            format: "bgra",
            metadata: ["executor": "CoreImageTransformExecutor", "operation": "color_adjust"]
        )
        await surfaceAuthority.releaseImageLease(imageLease)
        
        return .videoFrame(frame)
    }
    
    // MARK: - Helper Methods
    
    /// Creates a CVPixelBuffer from a CIImage suitable for output.
    private func createOutputPixelBuffer(from ciImage: CIImage, width: Int, height: Int) throws -> CVPixelBuffer {
        let extent = ciImage.extent
        let outputExtent = CGRect(x: 0, y: 0, width: width, height: height)
        
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let outputBuffer = pixelBuffer else {
            throw TransformError.outputImageCreationFailed
        }
        
        context.render(ciImage, to: outputBuffer)
        
        return outputBuffer
    }
}
