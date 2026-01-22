import Foundation
import CapsuleCore
import AnigmaPrimitives

/// Configuration for the Vector Index Capsule.
public struct VectorIndexConfig: Sendable {
    public var dimension: UInt32
    public var maxElements: UInt32
    public var M: UInt32
    public var efConstruction: UInt32
    public var efSearch: UInt32
    public var allowReplaceDeleted: Bool
    public var mmapPath: String?

    public init(
        dimension: UInt32,
        maxElements: UInt32 = 100_000,
        M: UInt32 = 16,
        efConstruction: UInt32 = 200,
        efSearch: UInt32 = 50,
        allowReplaceDeleted: Bool = true,
        mmapPath: String? = nil
    ) {
        self.dimension = dimension
        self.maxElements = maxElements
        self.M = M
        self.efConstruction = efConstruction
        self.efSearch = efSearch
        self.allowReplaceDeleted = allowReplaceDeleted
        self.mmapPath = mmapPath
    }
}

/// Swift wrapper for the HNSW-based Vector Index Capsule.
/// Provides high-performance ANN search and two-stage funnel retrieval.
public actor VectorIndexCapsuleWrapper {
    private var handle: CapsuleHandle<AnyObject>?
    private let config: VectorIndexConfig

    public init(config: VectorIndexConfig) throws {
        self.config = config
        
        var rawHandle: OpaquePointer?
        var error = anigma_capsule_error_t()
        
        var cConfig = anigma_vector_index_config_t(
            dimension: config.dimension,
            max_elements: config.maxElements,
            M: config.M,
            ef_construction: config.efConstruction,
            ef_search: config.efSearch,
            allow_replace_deleted: config.allowReplaceDeleted ? 1 : 0,
            mmap_path: config.mmapPath?.withCString { $0 } // This is dangerous if not handled properly
        )
        
        // Fix for mmap_path lifetime
        let status: anigma_status_t
        if let path = config.mmapPath {
            status = try path.withCString { pathPtr in
                cConfig.mmap_path = pathPtr
                return anigma_vector_index_capsule_create(&cConfig, &rawHandle, &error)
            }
        } else {
            cConfig.mmap_path = nil
            status = anigma_vector_index_capsule_create(&cConfig, &rawHandle, &error)
        }
        
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: UnsafeMutableRawPointer(rawHandle),
            destroyFunction: { ptr in
                anigma_vector_index_capsule_destroy(OpaquePointer(ptr))
            }
        )
    }

    /// Add a vector to the index.
    public func addVector(id: UInt64, vector: [Float]) throws {
        guard vector.count == Int(config.dimension) else {
            throw CapsuleError.invalidArgument("Vector dimension mismatch")
        }
        
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = vector.withUnsafeBufferPointer { buf in
                anigma_vector_index_capsule_add_vector(OpaquePointer(rawHandle), id, buf.baseAddress, &error)
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }

    /// Search for nearest neighbors.
    public func search(query: [Float], k: Int) throws -> [(id: UInt64, distance: Float)] {
        guard query.count == Int(config.dimension) else {
            throw CapsuleError.invalidArgument("Query dimension mismatch")
        }
        
        var ids = [UInt64](repeating: 0, count: k)
        var distances = [Float](repeating: 0, count: k)
        var count: UInt32 = 0
        var error = anigma_capsule_error_t()
        
        try handle?.withHandle { rawHandle in
            let status = query.withUnsafeBufferPointer { qBuf in
                anigma_vector_index_capsule_search(
                    OpaquePointer(rawHandle),
                    qBuf.baseAddress,
                    UInt32(k),
                    &ids,
                    &distances,
                    &count,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        var results: [(id: UInt64, distance: Float)] = []
        for i in 0..<Int(count) {
            results.append((id: ids[i], distance: distances[i]))
        }
        return results
    }

    /// Two-stage funnel search within a candidate pool.
    public func searchPool(query: [Float], candidateIds: [UInt64], k: Int) throws -> [(id: UInt64, distance: Float)] {
        guard query.count == Int(config.dimension) else {
            throw CapsuleError.invalidArgument("Query dimension mismatch")
        }
        
        var ids = [UInt64](repeating: 0, count: k)
        var distances = [Float](repeating: 0, count: k)
        var count: UInt32 = 0
        var error = anigma_capsule_error_t()
        
        try handle?.withHandle { rawHandle in
            let status = query.withUnsafeBufferPointer { qBuf in
                candidateIds.withUnsafeBufferPointer { cBuf in
                    anigma_vector_index_capsule_search_pool(
                        OpaquePointer(rawHandle),
                        qBuf.baseAddress,
                        cBuf.baseAddress,
                        cBuf.count,
                        UInt32(k),
                        &ids,
                        &distances,
                        &count,
                        &error
                    )
                }
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        var results: [(id: UInt64, distance: Float)] = []
        for i in 0..<Int(count) {
            results.append((id: ids[i], distance: distances[i]))
        }
        return results
    }

    /// Get current element count.
    public func getCount() throws -> UInt32 {
        var count: UInt32 = 0
        try handle?.withHandle { rawHandle in
            count = anigma_vector_index_capsule_get_count(OpaquePointer(rawHandle))
        }
        return count
    }

    /// Clear the index.
    public func clear() throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_vector_index_capsule_clear(OpaquePointer(rawHandle), &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
}
