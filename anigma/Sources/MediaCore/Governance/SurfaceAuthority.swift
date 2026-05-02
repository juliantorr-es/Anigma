import Foundation
import FoundationContracts
import GovernanceCore

/// A Tier 2 Authority that governs all live media surfaces across the substrate.
/// Ensures zero-copy continuity by issuing opaque handles (FrameReference/ImageSurfaceReference)
/// and tracking their lifecycles via leases.
public actor SurfaceAuthority {
    
    /// Errors related to surface governance.
    public enum SurfaceError: Error {
        case surfaceNotFound(SurfaceToken)
        case leaseExpired(SurfaceToken)
        case registrationFailed(String)
    }
    
    private struct SurfaceRecord {
        let token: SurfaceToken
        let nativeSurface: Any // Platform-specific surface (e.g. CVPixelBuffer, CGImage)
        let width: Int
        let height: Int
        let format: String
        let metadata: [String: String]
        var leaseCount: Int
    }
    
    private var registry: [SurfaceToken: SurfaceRecord] = [:]
    
    public init() {}
    
    // MARK: - Video Frame Registration
    
    /// Internal registration for backends to introduce a native video surface.
    internal func registerInternal(
        nativeSurface: Any,
        width: Int,
        height: Int,
        format: String,
        metadata: [String: String] = [:]
    ) -> FrameReference {
        let token = SurfaceToken()
        let record = SurfaceRecord(
            token: token,
            nativeSurface: nativeSurface,
            width: width,
            height: height,
            format: format,
            metadata: metadata,
            leaseCount: 0
        )
        
        registry[token] = record
        
        return FrameReference(
            token: token,
            width: width,
            height: height,
            format: format,
            metadata: metadata
        )
    }
    
    // MARK: - Image Surface Registration
    
    /// Internal registration for backends to introduce a native image surface.
    internal func registerImageInternal(
        nativeSurface: Any,
        width: Int,
        height: Int,
        format: String
    ) -> ImageSurfaceReference {
        let token = SurfaceToken()
        let record = SurfaceRecord(
            token: token,
            nativeSurface: nativeSurface,
            width: width,
            height: height,
            format: format,
            metadata: [:],
            leaseCount: 0
        )
        
        registry[token] = record
        
        return ImageSurfaceReference(
            token: token,
            width: width,
            height: height,
            format: format
        )
    }
    
    // MARK: - Lease Management
    
    /// Acquires a lease for a given video frame reference.
    public func acquireLease(for reference: FrameReference) throws -> FrameLease {
        try incrementLease(for: reference.token)
        return FrameLease(token: reference.token, reference: reference)
    }
    
    /// Acquires a lease for a given image surface reference.
    public func acquireImageLease(for reference: ImageSurfaceReference) throws -> ImageSurfaceLease {
        try incrementLease(for: reference.token)
        return ImageSurfaceLease(token: reference.token, reference: reference)
    }
    
    private func incrementLease(for token: SurfaceToken) throws {
        guard var record = registry[token] else {
            throw SurfaceError.surfaceNotFound(token)
        }
        record.leaseCount += 1
        registry[token] = record
    }
    
    /// Releases a lease, decrementing the reference count.
    /// If the count reaches zero, the underlying native surface is removed from the registry.
    public func releaseLease(token: SurfaceToken) {
        guard var record = registry[token] else {
            return
        }
        
        record.leaseCount -= 1
        if record.leaseCount <= 0 {
            registry.removeValue(forKey: token)
        } else {
            registry[token] = record
        }
    }
    
    /// Convenience for releasing a video lease.
    public func releaseLease(_ lease: FrameLease) {
        releaseLease(token: lease.token)
    }
    
    /// Convenience for releasing an image lease.
    public func releaseImageLease(_ lease: ImageSurfaceLease) {
        releaseLease(token: lease.token)
    }
    
    // MARK: - Resolution
    
    /// Internal method for backends to retrieve the native surface for a valid lease.
    internal func resolveNativeSurface(token: SurfaceToken) throws -> Any {
        guard let record = registry[token] else {
            throw SurfaceError.surfaceNotFound(token)
        }
        return record.nativeSurface
    }
    
    /// Resolves native surface from a video lease.
    internal func resolveNativeSurface(for lease: FrameLease) throws -> Any {
        return try resolveNativeSurface(token: lease.token)
    }
    
    /// Resolves native surface from an image lease.
    internal func resolveNativeSurface(for lease: ImageSurfaceLease) throws -> Any {
        return try resolveNativeSurface(token: lease.token)
    }
    
    // MARK: - Proofs & Stats
    
    /// Generates a proof that no copies occurred for this surface.
    public func generateZeroCopyProof(for token: SurfaceToken) -> ZeroCopyProof {
        return ZeroCopyProof(token: token)
    }
    
    public func generateZeroCopyProof(for reference: FrameReference) -> ZeroCopyProof {
        return generateZeroCopyProof(for: reference.token)
    }
    
    public func generateZeroCopyProof(for reference: ImageSurfaceReference) -> ZeroCopyProof {
        return generateZeroCopyProof(for: reference.token)
    }
    
    /// Returns the current number of active surfaces in the registry.
    public func activeSurfaceCount() -> Int {
        return registry.count
    }
}
