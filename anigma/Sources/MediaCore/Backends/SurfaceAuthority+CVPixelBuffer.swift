import Foundation
import CoreVideo
import FoundationContracts

#if canImport(CoreVideo)
extension SurfaceAuthority {
    
    /// Registers a macOS native CVPixelBuffer and returns a portable FrameReference.
    /// This allows Apple frameworks to introduce surfaces into the Anigma governance substrate.
    public func register(pixelBuffer: CVPixelBuffer) -> FrameReference {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let formatCode = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        // Map common pixel formats to portable strings
        let format: String
        switch formatCode {
        case kCVPixelFormatType_32BGRA: format = "bgra"
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: format = "420v"
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: format = "420f"
        default: format = "0x\(String(formatCode, radix: 16))"
        }
        
        return registerInternal(
            nativeSurface: pixelBuffer,
            width: width,
            height: height,
            format: format
        )
    }
    
    /// Resolves a FrameLease back to its native CVPixelBuffer for use in a macOS backend executor.
    public func resolvePixelBuffer(for lease: FrameLease) throws -> CVPixelBuffer {
        let surface = try resolveNativeSurface(for: lease)
        
        // Use CFGetTypeID for robust type checking of CoreFoundation objects bridged to 'Any'
        guard CFGetTypeID(surface as CFTypeRef) == CVPixelBufferGetTypeID() else {
            throw SurfaceError.registrationFailed("Surface is not a CVPixelBuffer")
        }
        
        return surface as! CVPixelBuffer
    }
}
#endif
