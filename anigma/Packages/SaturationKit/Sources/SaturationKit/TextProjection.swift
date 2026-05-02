import Foundation
import Metal

// MARK: - Text Projection

/// Saturated projection for text rendering.
/// Manages CPU-side text layout ("CPU lane") and GPU-side Metal rendering ("GPU lane")
/// with zero-copy atlas access via DSLMemoryBridge.
///
/// Note: This provides the infrastructure; actual TextRenderer types are defined in RenderPlanCapsule
/// to avoid circular dependencies.
public actor TextProjection {
    
    private let dslBridge: DSLMemoryBridge
    private let device: MTLDevice?
    private var mappedAtlas: DSLMappedAtlas?
    
    public init(
        dslBridge: DSLMemoryBridge = DSLMemoryBridge(),
        device: MTLDevice? = MTLCreateSystemDefaultDevice()
    ) {
        self.dslBridge = dslBridge
        self.device = device
    }
    
    /// Maps a pre-computed glyph atlas file to GPU memory (zero-copy).
    /// This eliminates the "Serialization Wall" by using mmap + MTLBuffer(noCopy:).
    public func mapAtlas(from url: URL) throws {
        guard let device = device else {
            throw TextProjectionError.deviceNotAvailable
        }
        
        do {
            mappedAtlas = try dslBridge.mapAtlas(url: url, device: device)
        } catch let error as DSLMemoryBridgeError {
            throw TextProjectionError.atlasMapping(error.localizedDescription)
        } catch {
            throw TextProjectionError.atlasMapping(error.localizedDescription)
        }
    }
    
    // MARK: - Introspection
    
    /// Returns true if an atlas is currently mapped.
    public var isAtlasMapped: Bool {
        mappedAtlas != nil
    }
    
    /// Returns the mapped atlas buffer for direct GPU access.
    public var atlasBuffer: MTLBuffer? {
        mappedAtlas?.buffer
    }
}

// MARK: - Error Handling

public enum TextProjectionError: Error, Sendable {
    case deviceNotAvailable
    case atlasMapping(String)
    case renderingFailed(String)
    
    public var localizedDescription: String {
        switch self {
        case .deviceNotAvailable:
            return "Metal device not available for text rendering"
        case .atlasMapping(let msg):
            return "Failed to map glyph atlas: \(msg)"
        case .renderingFailed(let msg):
            return "Text rendering failed: \(msg)"
        }
    }
}
