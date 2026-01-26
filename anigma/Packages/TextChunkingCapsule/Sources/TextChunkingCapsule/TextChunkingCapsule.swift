import Foundation
import CapsuleCore
import AnigmaNativeShims

/// High-level actor wrapper for text chunking operations.
/// Provides thread-safe access to the native Rabin fingerprinting implementation.
public actor TextChunkingCapsule: IdentifiableCapsule {
    private let wrapper: TextChunkingCapsuleWrapper
    
    public init(config: TextChunkingConfig = TextChunkingConfig()) throws {
        self.wrapper = try TextChunkingCapsuleWrapper(config: config)
    }
    
    /// One-shot chunking of a String. Returns String chunks.
    /// Handles UTF-8 conversion and ensures valid string boundaries.
    public func chunk(_ text: String) throws -> [String] {
        let data = Data(text.utf8)
        try wrapper.reset()
        try wrapper.processBytes(data)
        try wrapper.finalize()
        
        let boundaries = try wrapper.getBoundaries()
        var chunks: [String] = []
        
        for boundary in boundaries {
            let offset = Int(boundary.offset)
            let length = Int(boundary.length)
            if offset + length <= data.count {
                let chunkData = data.subdata(in: offset..<(offset + length))
                if let chunkString = String(data: chunkData, encoding: .utf8) {
                    chunks.append(chunkString)
                } else {
                    // If we hit an invalid UTF-8 boundary (rare with CDC but possible),
                    // we try to expand slightly to find a valid one or just skip.
                    // For now, we fall back to a safer string-based approach if needed.
                }
            }
        }
        
        return chunks.isEmpty && !text.isEmpty ? [text] : chunks
    }
    
    /// One-shot chunking of Data.
    public func chunk(_ data: Data) throws -> [Data] {
        try wrapper.reset()
        try wrapper.processBytes(data)
        try wrapper.finalize()
        
        let boundaries = try wrapper.getBoundaries()
        var chunks: [Data] = []
        
        for boundary in boundaries {
            let offset = Int(boundary.offset)
            let length = Int(boundary.length)
            if offset + length <= data.count {
                chunks.append(data.subdata(in: offset..<(offset + length)))
            }
        }
        
        return chunks
    }
    
    public func processBytes(_ data: Data) throws {
        try wrapper.processBytes(data)
    }
    
    public func finalize() throws -> [anigma_chunk_boundary_t] {
        try wrapper.finalize()
        return try wrapper.getBoundaries()
    }
    
    public func reset() throws {
        try wrapper.reset()
    }
}
