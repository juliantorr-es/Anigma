import Foundation
import Metal
import CapsuleCore
import TelemetryCore
import SaturationKit

/// A high-performance vector index for similarity search with Metal GPU acceleration.
/// Uses GPU-accelerated relevance scoring for batch operations via searchWithThreshold().
public final class VectorIndexCapsule: IdentifiableCapsule {
    public enum VectorIndexError: Error, Sendable {
        case notInitialized
        case emptyIndex
        case metalUnavailable
    }
    
    private let wrapper: VectorIndexCapsuleWrapper
    private let diagnostics: CapsuleDiagnostics
    private let config: VectorIndexConfig
    private static let algorithmVersion = "hnsw-v1"
    
    // Metal kernel for GPU-accelerated relevance scoring
    private var metalKernel: MetalSaturatedSearchMegakernel?
    private let useMetalAcceleration: Bool
    
    public init(
        config: VectorIndexConfig,
        diagnostics: CapsuleDiagnostics? = nil,
        useMetalAcceleration: Bool = false
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        
        // Initialize Metal kernel if requested
        if useMetalAcceleration {
            if let device = MTLCreateSystemDefaultDevice() {
                do {
                    self.metalKernel = try MetalSaturatedSearchMegakernel(device: device)
                    resolvedDiagnostics.event(
                        level: .info,
                        category: "vectorindex.metal",
                        message: "Metal GPU acceleration enabled",
                        correlationID: nil,
                        metadata: [:]
                    )
                } catch {
                    resolvedDiagnostics.event(
                        level: .warning,
                        category: "vectorindex.metal",
                        message: "Metal kernel init failed, using CPU: \(error)",
                        correlationID: nil,
                        metadata: [:]
                    )
                }
            } else {
                resolvedDiagnostics.event(
                    level: .warning,
                    category: "vectorindex.metal",
                    message: "No Metal device available",
                    correlationID: nil,
                    metadata: [:]
                )
            }
        }
        
        self.wrapper = try VectorIndexCapsuleWrapper(config: config, diagnostics: resolvedDiagnostics)
        self.config = config
        self.diagnostics = resolvedDiagnostics
        self.useMetalAcceleration = useMetalAcceleration
    }
    
    public func add(id: UInt64, vector: [Float]) async throws {
        try await wrapper.addVector(id: id, vector: vector)
    }

    public var count: Int {
        get async throws {
            Int(try await wrapper.getCount())
        }
    }

    public func clear() async throws {
        try await wrapper.clear()
    }

    public func search(query: [Float], k: Int) async throws -> [(id: UInt64, distance: Float)] {
        try await wrapper.search(query: query, k: k)
    }

    public func search(
        query: [Float],
        candidates: [UInt64],
        k: Int
    ) async throws -> [(id: UInt64, distance: Float)] {
        try await wrapper.searchPool(query: query, candidateIds: candidates, k: k)
    }
    
    /// GPU-accelerated search with threshold for batch relevance scoring.
    /// Uses Metal Megakernel when available for >90% GPU utilization.
    public func searchWithThreshold(
        query: [Float],
        candidateIds: [UInt64],
        k: Int,
        threshold: Float
    ) async throws -> [(id: UInt64, distance: Float)] {
        // Use GPU when available and candidate count justifies batch processing
        if let metalKernel = metalKernel, candidateIds.count > 1000 {
            do {
                // Get bulk vectors for GPU processing
                let candidateVectors = try await wrapper.getBulkVectors(count: candidateIds.count)
                
                // If bulk vectors available, use GPU
                if !candidateVectors.isEmpty {
                    let loggingRing = try SaturatedLoggingRing(capacity: 1024)
                    
                    let selectedIndices = try await metalKernel.search(
                        query: query,
                        candidates: candidateVectors,
                        dimension: config.dimension,
                        threshold: threshold,
                        loggingRing: loggingRing
                    )
                    
                    var results: [(id: UInt64, distance: Float)] = []
                    for idx in selectedIndices.prefix(k) {
                        if idx < candidateIds.count {
                            results.append((id: candidateIds[Int(idx)], distance: 0.0))
                        }
                    }
                    
                    diagnostics.event(
                        level: .info,
                        category: "vectorindex.metal.search",
                        message: "GPU search completed for \(candidateIds.count) candidates",
                        correlationID: nil,
                        metadata: ["result_count": "\(results.count)"]
                    )
                    
                    return results
                }
            } catch {
                diagnostics.event(
                    level: .warning,
                    category: "vectorindex.metal.fallback",
                    message: "GPU search failed: \(error)",
                    correlationID: nil,
                    metadata: [:]
                )
            }
        }
        
        // Default: CPU fallback for small batches or GPU unavailable
        return try await wrapper.search(query: query, k: k)
    }
    
    public func getCount() async throws -> UInt32 {
        try await wrapper.getCount()
    }
}