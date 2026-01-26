import Foundation
import AnigmaNativeShims
import CapsuleCore
import TelemetryCore

/// Internal wrapper for the native vector index capsule.
internal actor VectorIndexCapsuleWrapper {
    private let config: VectorIndexConfig
    private var handle: CapsuleHandle<AnyObject>?
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "hnsw-v1"
    
    init(
        config: VectorIndexConfig,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        self.config = config
        self.diagnostics = resolvedDiagnostics
        
        var rawHandle: anigma_vector_index_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = anigma_vector_index_config_t()
        cConfig.dimension = UInt32(config.dimension)
        cConfig.max_elements = UInt32(config.maxElements)
        cConfig.M = UInt32(config.M)
        cConfig.ef_construction = UInt32(config.efConstruction)
        cConfig.ef_search = UInt32(config.efSearch)
        cConfig.allow_replace_deleted = config.allowReplaceDeleted ? 1 : 0
        
        var status: anigma_status_t = ANIGMA_OK
        if let path = config.mmapPath {
            try path.withCString { pathPtr in
                cConfig.mmap_path = pathPtr
                status = anigma_vector_index_capsule_create(&cConfig, &rawHandle, &error)
            }
        } else {
            cConfig.mmap_path = nil
            status = anigma_vector_index_capsule_create(&cConfig, &rawHandle, &error)
        }
        
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            resolvedDiagnostics.event(
                level: .error,
                category: "vectorindex.init",
                message: "Failed to create native handle (status: \(status))",
                correlationID: nil,
                tags: ["algorithm_version": Self.algorithmVersion]
            )
            throw capsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: { ptr in
                var mutablePtr: anigma_vector_index_capsule_t? = ptr
                anigma_vector_index_capsule_destroy(&mutablePtr)
            }
        )
    }
    
    func addVector(id: UInt64, vector: [Float]) throws {
        let span = diagnostics.beginSpan(
            name: "VectorIndexCapsuleWrapper.addVector",
            category: "vectorindex.native.add",
            correlationID: nil,
            tags: [
                "vector_dim": "\(vector.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        guard vector.count == Int(config.dimension) else {
            diagnostics.event(
                level: .error,
                category: "vectorindex.native.add",
                message: "Invalid vector dimension",
                correlationID: nil,
                tags: [
                    "expected": "\(config.dimension)",
                    "actual": "\(vector.count)"
                ]
            )
            span.end(status: .error)
            throw capsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
        }
        
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = vector.withUnsafeBufferPointer { buf in
                anigma_vector_index_capsule_add_vector(rawHandle, id, buf.baseAddress, &error)
            }
            guard status == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "vectorindex.native.add",
                    message: "Native add failed (status: \(status))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: status, error: error)
            }
        }
        span.end(status: .ok)
    }
    
    func search(query: [Float], k: Int) throws -> [(id: UInt64, distance: Float)] {
        let span = diagnostics.beginSpan(
            name: "VectorIndexCapsuleWrapper.search",
            category: "vectorindex.native.search",
            correlationID: nil,
            tags: [
                "query_dim": "\(query.count)",
                "k": "\(k)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        guard query.count == Int(config.dimension) else {
            diagnostics.event(
                level: .error,
                category: "vectorindex.native.search",
                message: "Invalid query dimension",
                correlationID: nil,
                tags: [
                    "expected": "\(config.dimension)",
                    "actual": "\(query.count)"
                ]
            )
            span.end(status: .error)
            throw capsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
        }
        
        var ids = [UInt64](repeating: 0, count: k)
        var distances = [Float](repeating: 0, count: k)
        var count: UInt32 = 0
        var error = anigma_capsule_error_t()
        
        try handle?.withHandle { rawHandle in
            let status = query.withUnsafeBufferPointer { qBuf in
                anigma_vector_index_capsule_search(
                    rawHandle,
                    qBuf.baseAddress,
                    UInt32(k),
                    &ids,
                    &distances,
                    &count,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "vectorindex.native.search",
                    message: "Native search failed (status: \(status))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: status, error: error)
            }
        }

        span.end(status: .ok)
        return (0..<Int(count)).map { (ids[$0], distances[$0]) }
    }
    
    func searchPool(query: [Float], candidateIds: [UInt64], k: Int) throws -> [(id: UInt64, distance: Float)] {
        let span = diagnostics.beginSpan(
            name: "VectorIndexCapsuleWrapper.searchPool",
            category: "vectorindex.native.search",
            correlationID: nil,
            tags: [
                "query_dim": "\(query.count)",
                "candidate_count": "\(candidateIds.count)",
                "k": "\(k)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        var ids = [UInt64](repeating: 0, count: k)
        var distances = [Float](repeating: 0, count: k)
        var count: UInt32 = 0
        var error = anigma_capsule_error_t()
        
        try handle?.withHandle { rawHandle in
            let status = query.withUnsafeBufferPointer { qBuf in
                candidateIds.withUnsafeBufferPointer { cBuf in
                    anigma_vector_index_capsule_search_pool(
                        rawHandle,
                        qBuf.baseAddress,
                        cBuf.baseAddress,
                        candidateIds.count,
                        UInt32(k),
                        &ids,
                        &distances,
                        &count,
                        &error
                    )
                }
            }
            guard status == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "vectorindex.native.search",
                    message: "Native search pool failed (status: \(status))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: status, error: error)
            }
        }

        span.end(status: .ok)
        return (0..<Int(count)).map { (ids[$0], distances[$0]) }
    }
    
    func getCount() throws -> UInt32 {
        let span = diagnostics.beginSpan(
            name: "VectorIndexCapsuleWrapper.getCount",
            category: "vectorindex.native.count",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        var count: UInt32 = 0
        do {
            try handle?.withHandle { rawHandle in
                count = anigma_vector_index_capsule_get_count(rawHandle)
            }
            span.end(status: .ok)
            return count
        } catch {
            diagnostics.event(
                level: .error,
                category: "vectorindex.native.count",
                message: "Native count failed: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    func clear() throws {
        let span = diagnostics.beginSpan(
            name: "VectorIndexCapsuleWrapper.clear",
            category: "vectorindex.native.clear",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_vector_index_capsule_clear(rawHandle, &error)
            guard status == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "vectorindex.native.clear",
                    message: "Native clear failed (status: \(status))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: status, error: error)
            }
        }
        span.end(status: .ok)
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleNativeError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleNativeError(status: status, code: error.code, message: message)
}
