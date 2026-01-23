import Foundation
import AnigmaPrimitives

/// High-performance cosine similarity calculations.
/// Supports SIMD acceleration and batch operations.
public final class CosineSimilarityCapsule {
    private let wrapper: CosineSimilarityCapsuleWrapper
    
    public init() throws {
        self.wrapper = try CosineSimilarityCapsuleWrapper()
    }
    
    /// Compute similarity between two vectors.
    public func similarity(between query: [Float], and candidate: [Float]) throws -> Float {
        return try wrapper.computeSingle(query: query, candidate: candidate)
    }
    
    /// Compute similarities for a batch of candidates.
    public func similarity(between query: [Float], and candidates: [[Float]]) throws -> [Float] {
        return try wrapper.computeBatch(query: query, candidates: candidates)
    }
    
    /// Compute all-to-all similarity matrix.
    /// Result is a flattened array of size `queries.count * candidates.count`.
    public func similarityMatrix(queries: [[Float]], candidates: [[Float]]) throws -> [Float] {
        return try wrapper.computeMatrix(queries: queries, candidates: candidates)
    }
}
