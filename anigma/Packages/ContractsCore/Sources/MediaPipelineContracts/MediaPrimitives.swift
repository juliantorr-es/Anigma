import Foundation
import AnigmaPrimitives
import FoundationContracts

/// Kind of media surface (portable, no native types exposed).
public enum MediaSurfaceKind: String, Sendable, Codable {
    case pixelBuffer
    case texture
    case audioBuffer
    case unknown
}

/// Portable media surface contract - NO CVPixelBuffer/MTLTexture in public interface.
/// The underlying surface (CVPixelBuffer, MTLTexture, etc.) is registered in MediaCore's SurfaceRegistry.
/// Dimensions are stored in the token for access without resolving to native types.
public struct MediaSurface: Sendable, Hashable, Codable {
    public let token: SurfaceToken
    public let kind: MediaSurfaceKind
    public let width: Int
    public let height: Int
    public let byteCount: Int?
    
    public init(
        token: SurfaceToken,
        kind: MediaSurfaceKind,
        width: Int,
        height: Int,
        byteCount: Int? = nil
    ) {
        self.token = token
        self.kind = kind
        self.width = width
        self.height = height
        self.byteCount = byteCount
    }
}

/// Defines the hardware affinity lane for a media operation.
public enum MediaLane: String, Sendable, Codable {
    case capture
    case decode
    case transform
    case inference
}

/// The interface for saturable media processing nodes.
public protocol Saturable: Sendable {
    var lane: MediaLane { get }
    func process(surface: MediaSurface, contract: any MediaContract) async throws -> MediaSurface
}

/// Protocol for the substrate orchestration layer.
public protocol SaturationSubstrateProtocol: Sendable {
    func process(surface: MediaSurface, lane: MediaLane, contract: any MediaContract) async throws -> MediaSurface
}
