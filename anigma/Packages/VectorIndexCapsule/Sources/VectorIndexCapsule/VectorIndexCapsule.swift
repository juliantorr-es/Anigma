import Foundation
import CapsuleCore
import TelemetryCore

/// A high-performance vector index for similarity search.
public final class VectorIndexCapsule: IdentifiableCapsule {
    private let wrapper: VectorIndexCapsuleWrapper
    private let diagnostics: CapsuleDiagnostics
    private let config: VectorIndexConfig
    private static let algorithmVersion = "hnsw-v1"
    
    public init(
        config: VectorIndexConfig,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "VectorIndexCapsule.init",
            category: "vectorindex.init",
            correlationID: nil,
            tags: [
                "dimension": "\(config.dimension)",
                "max_elements": "\(config.maxElements)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            self.wrapper = try VectorIndexCapsuleWrapper(config: config, diagnostics: resolvedDiagnostics)
            self.config = config
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "vectorindex.init",
                message: "Failed to create index: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Add a vector to the index.
    public func add(id: UInt64, vector: [Float]) async throws {
        let span = diagnostics.beginSpan(
            name: "VectorIndexCapsule.add",
            category: "vectorindex.add",
            correlationID: nil,
            tags: [
                "vector_dim": "\(vector.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            try await wrapper.addVector(id: id, vector: vector)
            span.end(status: .ok)
        } catch {
            diagnostics.event(
                level: .error,
                category: "vectorindex.add",
                message: "Add failed: \(error)",
                correlationID: nil,
                tags: ["vector_dim": "\(vector.count)"]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Search for nearest neighbors.
    public func search(query: [Float], k: Int) async throws -> [(id: UInt64, distance: Float)] {
        let span = diagnostics.beginSpan(
            name: "VectorIndexCapsule.search",
            category: "vectorindex.search",
            correlationID: nil,
            tags: [
                "query_dim": "\(query.count)",
                "k": "\(k)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            let result = try await wrapper.search(query: query, k: k)
            span.end(status: .ok)
            return result
        } catch {
            diagnostics.event(
                level: .error,
                category: "vectorindex.search",
                message: "Search failed: \(error)",
                correlationID: nil,
                tags: ["query_dim": "\(query.count)"]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Search within a specific subset of IDs (two-stage retrieval).
    public func search(query: [Float], candidates: [UInt64], k: Int) async throws -> [(id: UInt64, distance: Float)] {
        let span = diagnostics.beginSpan(
            name: "VectorIndexCapsule.searchPool",
            category: "vectorindex.search",
            correlationID: nil,
            tags: [
                "query_dim": "\(query.count)",
                "candidate_count": "\(candidates.count)",
                "k": "\(k)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            let result = try await wrapper.searchPool(query: query, candidateIds: candidates, k: k)
            span.end(status: .ok)
            return result
        } catch {
            diagnostics.event(
                level: .error,
                category: "vectorindex.search",
                message: "Search pool failed: \(error)",
                correlationID: nil,
                tags: ["candidate_count": "\(candidates.count)"]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// Current number of elements in the index.
    public var count: UInt32 {
        get async throws {
            let span = diagnostics.beginSpan(
                name: "VectorIndexCapsule.count",
                category: "vectorindex.count",
                correlationID: nil,
                tags: ["algorithm_version": Self.algorithmVersion]
            )
            do {
                let value = try await wrapper.getCount()
                span.end(status: .ok)
                return value
            } catch {
                diagnostics.event(
                    level: .error,
                    category: "vectorindex.count",
                    message: "Count failed: \(error)",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw error
            }
        }
    }
    
    /// Clear all elements from the index.
    public func clear() async throws {
        let span = diagnostics.beginSpan(
            name: "VectorIndexCapsule.clear",
            category: "vectorindex.clear",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        do {
            try await wrapper.clear()
            span.end(status: .ok)
        } catch {
            diagnostics.event(
                level: .error,
                category: "vectorindex.clear",
                message: "Clear failed: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
}
