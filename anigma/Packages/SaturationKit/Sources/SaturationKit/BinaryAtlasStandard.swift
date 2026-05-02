//
//  BinaryAtlasStandard.swift
//  SaturationKit
//
//  Standard for "SoA at rest" Binary Atlases for hardware saturation.
//

import Foundation
import AnigmaPrimitives

/// Supported vector data formats for the Saturated Spine.
/// Optimized for zero-copy hardware saturation.
public enum VectorFormat: UInt32, Codable, Sendable {
    case float32 = 0
    case float16 = 1
    case bfloat16 = 2
}

/// The header for a Binary Atlas file (.atlas), optimized for zero-copy mmap.
/// Follows the "Structure-of-Arrays (SoA) at rest" principle to enable
/// 100% memory coalescing and hardware saturation.
public struct BinaryAtlasHeader: Sendable {
    /// 4 bytes: Magic number "ANIG" (0x47494E41 in little-endian)
    public let magic: UInt32
    /// 4 bytes: Format version
    public let version: UInt32
    /// 8 bytes: Total number of vector entries
    public let count: UInt64
    /// 4 bytes: Dimensionality of each vector
    public let dimension: UInt32
    /// 4 bytes: Data format (matching VectorFormat)
    public let format: UInt32
    /// 8 bytes: Offset to the contiguous SoA vector data (4096-aligned)
    public let dataOffset: UInt64
    /// 8 bytes: Offset to the metadata section
    public let metadataOffset: UInt64
    
    public static let magicValue: UInt32 = 0x47494E41 // "ANIG"
    public static let currentVersion: UInt32 = 1
    public static let alignment: Int = 4096
}

/// Utility for writing Binary Atlases in Structure-of-Arrays (SoA) format.
public struct BinaryAtlasWriter: Sendable {
    
    /// Writes a batch of vectors and optional metadata to a Binary Atlas file.
    ///
    /// - Parameters:
    ///   - url: Target file URL.
    ///   - vectors: Input vectors in Array-of-Structures (AoS) format.
    ///   - metadata: Optional associated metadata.
    ///   - format: The vector data format.
    ///   - version: The format version.
    public static func write(
        url: URL,
        vectors: [[Float]],
        metadata: Data? = nil,
        format: VectorFormat = .float32,
        version: UInt32 = BinaryAtlasHeader.currentVersion
    ) throws {
        guard !vectors.isEmpty else { return }
        let count = UInt64(vectors.count)
        let dimension = UInt32(vectors[0].count)
        
        // 1. Prepare Header
        // dataOffset must be aligned to system page size (4096)
        let dataOffset = UInt64(BinaryAtlasHeader.alignment)
        let elementSize = MemoryLayout<Float32>.size
        let dataSize = Int(count) * Int(dimension) * elementSize
        let metadataOffset = dataOffset + UInt64(dataSize)
        
        var header = BinaryAtlasHeader(
            magic: BinaryAtlasHeader.magicValue,
            version: version,
            count: count,
            dimension: dimension,
            format: format.rawValue,
            dataOffset: dataOffset,
            metadataOffset: metadataOffset
        )
        
        // 2. Build the File Content
        var data = Data()
        
        // Append header bytes
        withUnsafeBytes(of: &header) { ptr in
            data.append(ptr.bindMemory(to: UInt8.self))
        }
        
        // Pad to alignment
        let paddingSize = BinaryAtlasHeader.alignment - data.count
        if paddingSize > 0 {
            data.append(Data(count: paddingSize))
        }
        
        // 3. Pack vectors into SoA format
        // [v0_d0, v1_d0, v2_d0, ..., v0_d1, v1_d1, ...]
        for d in 0..<Int(dimension) {
            for v in 0..<Int(count) {
                var value = vectors[v][d]
                withUnsafeBytes(of: &value) { ptr in
                    data.append(ptr.bindMemory(to: UInt8.self))
                }
            }
        }
        
        // 4. Append Metadata
        if let metadata = metadata {
            data.append(metadata)
        }
        
        // 5. Final Write
        try data.write(to: url)
    }
}

extension DSLMappedAtlas {
    /// Reads the atlas header directly from the memory-mapped buffer.
    public var header: BinaryAtlasHeader {
        buffer.contents().assumingMemoryBound(to: BinaryAtlasHeader.self).pointee
    }
    
    /// Provides a zero-copy view of the entire vector data block as a contiguous buffer.
    /// Note: The data is in SoA format at rest.
    public func vectorBuffer() -> UnsafeBufferPointer<Float> {
        let h = header
        let ptr = buffer.contents().advanced(by: Int(h.dataOffset)).assumingMemoryBound(to: Float.self)
        let totalElements = Int(h.count) * Int(h.dimension)
        return UnsafeBufferPointer(start: ptr, count: totalElements)
    }
}
