import Foundation
import ImageIO
import CoreGraphics
import FoundationContracts
import MediaPipelineContracts
import ContractsCore

/// A Tier 3 Backend Executor that uses ImageIO for hardware-accelerated image decoding.
/// Produces managed ImageSurfaceReferences in the SurfaceAuthority substrate.
/// Phase 4: Conforms to Saturable for lane-based routing.
public struct ImageIODecodeExecutor: MediaExecutor, Saturable {
    public let lane: MediaLane = .decode
    
    private let surfaceAuthority: SurfaceAuthority
    private let artifactStore: any MediaArtifactStore
    
    public enum ImageError: Error {
        case sourceCreationFailed
        case decodeFailed
        case invalidArtifact
    }
    
    public init(surfaceAuthority: SurfaceAuthority, artifactStore: any MediaArtifactStore) {
        self.surfaceAuthority = surfaceAuthority
        self.artifactStore = artifactStore
    }
    
    public func execute(contract: any MediaContract) async throws -> MediaReference {
        guard let imageContract = contract as? ImageDecodeContract else {
            throw ValidationError.invalidRequest("ImageIODecodeExecutor: Unsupported contract \(type(of: contract))")
        }
        
        // Resolve the artifact data from the governed artifact store
        let (data, _) = try await artifactStore.loadRaw(imageContract.artifactId.uuidString)
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageError.sourceCreationFailed
        }
        
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageError.decodeFailed
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Register image with SurfaceAuthority
        let reference = await surfaceAuthority.registerImageInternal(
            nativeSurface: cgImage,
            width: width,
            height: height,
            format: imageContract.format
        )
        
        return .imageSurface(reference)
    }
    
    // MARK: - Saturable Conformance (Phase 4)
    
    /// Saturable process method for lane-based routing.
    /// Note: This is a Phase 4 placeholder - full image MediaSurface integration requires Phase 5 work.
    public func process(surface: MediaSurface, contract: any MediaContract) async throws -> MediaSurface {
        // ImageIODecodeExecutor works with CGImage, not MediaSurface
        // Full integration requires MediaSurface support for CGImage
        // For Phase 4, return the input surface unchanged as a placeholder
        return surface
    }
}
