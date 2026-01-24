import Foundation
import CapsuleCore

/// A high-performance vector index for similarity search.
public final class VectorIndexCapsule: IdentifiableCapsule {
    private let wrapper: VectorIndexCapsuleWrapper
    
    public init(config: VectorIndexConfig) throws {
        self.wrapper = try VectorIndexCapsuleWrapper(config: config)
    }
    
    /// Add a vector to the index.
    public func add(id: UInt64, vector: [Float]) async throws {
        try await wrapper.addVector(id: id, vector: vector)
    }
    
    /// Search for nearest neighbors.
    public func search(query: [Float], k: Int) async throws -> [(id: UInt64, distance: Float)] {
        try await wrapper.search(query: query, k: k)
    }
    
    /// Search within a specific subset of IDs (two-stage retrieval).
    public func search(query: [Float], candidates: [UInt64], k: Int) async throws -> [(id: UInt64, distance: Float)] {
        try await wrapper.searchPool(query: query, candidateIds: candidates, k: k)
    }
    
    /// Current number of elements in the index.
    public var count: UInt32 {
        get async throws {
            try await wrapper.getCount()
        }
    }
    
    /// Clear all elements from the index.
    public func clear() async throws {
        try await wrapper.clear()
    }
}
