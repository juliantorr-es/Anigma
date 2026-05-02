import Foundation
import CoreVideo
import Metal
// import ContractsCore // REMOVED to break dependency cycle

/// Defines the hardware affinity lane for a media operation.
public enum MediaLane: String, Sendable, Codable {
    case capture
    case decode
    case transform
    case inference
}

/// A zero-copy container for hardware-backed media surfaces.
public enum MediaSurface: Sendable {
    case pixelBuffer(CVPixelBuffer)
    case texture(MTLTexture)
    
    public var width: Int {
        switch self {
        case .pixelBuffer(let buffer): return CVPixelBufferGetWidth(buffer)
        case .texture(let texture): return texture.width
        }
    }
    
    public var height: Int {
        switch self {
        case .pixelBuffer(let buffer): return CVPixelBufferGetHeight(buffer)
        case .texture(let texture): return texture.height
        }
    }
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
