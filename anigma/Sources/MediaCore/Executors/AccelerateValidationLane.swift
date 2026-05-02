import Foundation
import Accelerate
import AVFoundation
import CoreVideo
import FoundationContracts

/// A Tier 3 Execution component that uses Apple's Accelerate framework for SIMD-accelerated buffer validation.
/// Ensures media data is physically valid (non-degenerate) before routing to inference.
public struct AccelerateValidationLane: Sendable {
    
    public enum ValidationError: Error {
        case bufferLockFailed(OSStatus)
        case invalidFormat
    }
    
    public init() {}
    
    /// Validates an audio buffer using vDSP statistics.
    /// Flags as invalid if the buffer is completely silent (min == max).
    public func validate(audioBuffer: AVAudioPCMBuffer) -> SIMDValidationResult {
        guard let channelData = audioBuffer.floatChannelData else {
            return SIMDValidationResult(isValid: false, reason: "No float channel data")
        }
        
        let frameCount = vDSP_Length(audioBuffer.frameLength)
        let channelCount = Int(audioBuffer.format.channelCount)
        
        var globalMin: Float = .greatestFiniteMagnitude
        var globalMax: Float = -.greatestFiniteMagnitude
        var sumMean: Float = 0
        
        for i in 0..<channelCount {
            var min: Float = 0
            var max: Float = 0
            var mean: Float = 0
            
            vDSP_minv(channelData[i], 1, &min, frameCount)
            vDSP_maxv(channelData[i], 1, &max, frameCount)
            vDSP_meanv(channelData[i], 1, &mean, frameCount)
            
            globalMin = Swift.min(globalMin, min)
            globalMax = Swift.max(globalMax, max)
            sumMean += mean
        }
        
        let finalMean = Double(sumMean / Float(channelCount))
        let stats = BufferStatistics(min: Double(globalMin), max: Double(globalMax), mean: finalMean)
        
        // Sanity Check: All zeros or all same value indicates degenerate audio (silence/DC)
        if globalMin == globalMax {
            return SIMDValidationResult(isValid: false, reason: "Audio buffer is degenerate (silence or DC offset)", statistics: stats)
        }
        
        return SIMDValidationResult(isValid: true, statistics: stats)
    }
    
    /// Validates a video pixel buffer using vImage.
    /// Flags as invalid if the luma channel is pitch black (max luma == 0).
    public func validate(pixelBuffer: CVPixelBuffer) throws -> SIMDValidationResult {
        let status = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        guard status == kCVReturnSuccess else {
            throw ValidationError.bufferLockFailed(status)
        }
        
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        var minLuma: Int = 255
        var maxLuma: Int = 0
        
        // We use Histogram calculation as it's highly optimized and available in all SDKs.
        var histogram = [vImagePixelCount](repeating: 0, count: 256)
        
        try histogram.withUnsafeMutableBufferPointer { hPtr in
            let h = hPtr.baseAddress!
            
            if CVPixelBufferIsPlanar(pixelBuffer) && (format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
                // Luma is Plane 0
                guard let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
                    throw ValidationError.invalidFormat
                }
                let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
                let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
                let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
                
                var vBuffer = vImage_Buffer(
                    data: lumaBaseAddress,
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: bytesPerRow
                )
                
                vImageHistogramCalculation_Planar8(&vBuffer, h, vImage_Flags(kvImageNoFlags))
            } else {
                // Fallback for non-planar or other formats: treat as one big buffer
                guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                    throw ValidationError.invalidFormat
                }
                let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                
                var vBuffer = vImage_Buffer(
                    data: baseAddress,
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: bytesPerRow
                )
                
                vImageHistogramCalculation_Planar8(&vBuffer, h, vImage_Flags(kvImageNoFlags))
            }
        }
        
        // Find extrema from histogram
        minLuma = histogram.firstIndex(where: { $0 > 0 }) ?? 255
        maxLuma = histogram.lastIndex(where: { $0 > 0 }) ?? 0
        
        let stats = BufferStatistics(min: Double(minLuma), max: Double(maxLuma), mean: 0)
        
        if maxLuma == 0 {
            return SIMDValidationResult(isValid: false, reason: "Video buffer is pitch black", statistics: stats)
        }
        
        return SIMDValidationResult(isValid: true, statistics: stats)
    }
}
