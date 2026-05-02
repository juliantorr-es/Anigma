//
//  SaturatedEmbeddingComponent.swift
//  ContextumModule
//
//  Data-Oriented Embedding Storage for Hardware Saturation.
//  Uses the "Saturated Spine" architecture to eliminate serialization overhead.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import SaturationKit
import Metal

/// Metadata-only component that links a Contextum entity to its high-dimensional
/// vector stored in a GPU-native Binary Atlas.
public struct SaturatedEmbeddingComponent: Component, Codable, Sendable {
    /// The unique identifier for the Binary Atlas file (.atlas).
    public let atlasId: UUID
    
    /// The offset in bytes within the atlas file where the vector data begins.
    /// Aligned to 128-byte boundaries for SIMD saturation.
    public let offset: UInt64
    
    /// The dimensionality of the vector (e.g., 384, 1024).
    public let dimension: Int
    
    /// The numeric format of the data (e.g., Float32, BFloat16).
    public let format: VectorFormat
    
    /// A small, CPU-resident summary for quick filtering without GPU/mmap.
    public let centroidHash: UInt32
    
    public init(
        atlasId: UUID,
        offset: UInt64,
        dimension: Int,
        format: VectorFormat = .float32,
        centroidHash: UInt32 = 0
    ) {
        self.atlasId = atlasId
        self.offset = offset
        self.dimension = dimension
        self.format = format
        self.centroidHash = centroidHash
    }
}

/// Tier 2 Authority for managing the memory-mapped Binary Atlases.
public actor AtlasAuthority {
    private var mappedAtlases: [UUID: DSLMappedAtlas] = [:]
    
    /// Maps a Binary Atlas into the GPU's address space via DSLMemoryBridge.
    public func mountAtlas(id: UUID, url: URL) async throws -> MTLBuffer {
        // Implementation uses mmap and makeBuffer(noCopy:...)
        // This ensures zero-copy data flow from Disk to GPU.
        let bridge = DSLMemoryBridge()
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw DSLMemoryBridgeError.deviceMissing
        }
        
        let atlas = try bridge.mapAtlas(url: url, device: device)
        mappedAtlases[id] = atlas
        return atlas.buffer
    }
    
    public func getBuffer(for atlasId: UUID) -> MTLBuffer? {
        return mappedAtlases[atlasId]?.buffer
    }
}
