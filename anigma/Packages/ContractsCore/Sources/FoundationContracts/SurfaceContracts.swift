import Foundation
import AnigmaPrimitives

/// Unique identifier for a live media surface registered in SurfaceAuthority.
public struct SurfaceToken: Hashable, Sendable, Codable {
    public let rawValue: UUID
    
    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// A portable, opaque handle to a live media surface.
/// Does not contain any platform-specific data buffers (e.g., CVPixelBuffer).
/// References must be resolved through SurfaceAuthority via a FrameLease.
public struct FrameReference: Sendable, Codable, Hashable {
    public let token: SurfaceToken
    public let width: Int
    public let height: Int
    public let format: String // e.g. "bgra", "420f"
    public let metadata: [String: String]
    
    public init(
        token: SurfaceToken,
        width: Int,
        height: Int,
        format: String,
        metadata: [String: String] = [:]
    ) {
        self.token = token
        self.width = width
        self.height = height
        self.format = format
        self.metadata = metadata
    }
}

/// A reference-counted handle to a live surface.
/// When the last lease is deinitialized, SurfaceAuthority may release the underlying native memory.
public struct FrameLease: Sendable {
    public let token: SurfaceToken
    public let reference: FrameReference
    
    public init(token: SurfaceToken, reference: FrameReference) {
        self.token = token
        self.reference = reference
    }
}

/// A reference-counted handle to a live image surface.
public struct ImageSurfaceLease: Sendable {
    public let token: SurfaceToken
    public let reference: ImageSurfaceReference
    
    public init(token: SurfaceToken, reference: ImageSurfaceReference) {
        self.token = token
        self.reference = reference
    }
}

/// An audit record proving that a media operation maintained zero-copy continuity.
public struct ZeroCopyProof: Sendable, Codable {
    public let token: SurfaceToken
    public let copiedBytes: Int64
    public let materializationReason: String?
    public let timestamp: Date
    
    public init(
        token: SurfaceToken,
        copiedBytes: Int64 = 0,
        materializationReason: String? = nil,
        timestamp: Date = Date()
    ) {
        self.token = token
        self.copiedBytes = copiedBytes
        self.materializationReason = materializationReason
        self.timestamp = timestamp
    }
    
    public var isPerfect: Bool {
        return copiedBytes == 0
    }
}
