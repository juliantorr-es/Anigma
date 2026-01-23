import Foundation
import AnigmaPrimitives

/// High-level interface for vector indexing and search.
/// Uses HNSW algorithm for approximate nearest neighbor search.
public actor VectorIndexCapsule {
    private let wrapper: VectorIndexCapsuleWrapper
    
    public init(config: VectorIndexConfig) throws {
        self.wrapper = try VectorIndexCapsuleWrapper(config: config)
    }
    
    /// Add a vector to the index.
    public func add(id: UInt64, vector: [Float]) throws {
        try await wrapper.addVector(id: id, vector: vector)
    }
    
    /// Search for nearest neighbors.
    public func search(query: [Float], k: Int) throws -> [(id: UInt64, distance: Float)] {
        try await wrapper.search(query: query, k: k)
    }
    
    /// Search within a specific subset of IDs (two-stage retrieval).
    public func search(query: [Float], candidates: [UInt64], k: Int) throws -> [(id: UInt64, distance: Float)] {
        try await wrapper.searchPool(query: query, candidateIds: candidates, k: k)
    }
    
    /// Get total number of vectors in the index.
    public func count() async throws -> Int {
        Int(try await wrapper.getCount())
    }
    
    /// Clear the index.
    public func clear() async throws {
        try await wrapper.clear()
    }
}
