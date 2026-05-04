import Foundation
import AnigmaNativeShims
import CapsuleCore
import TelemetryCore

public enum VectorIndexError: Error, Sendable {
    case notInitialized
    case emptyIndex
}

public actor VectorIndexCapsuleWrapper {
    private let config: VectorIndexConfig
    private var handle: CapsuleHandle<AnyObject>?
    
    public init(config: VectorIndexConfig, diagnostics: CapsuleDiagnostics? = nil) throws {
        self.config = config
        var rawHandle: anigma_vector_index_capsule_t?
        var cConfig = anigma_vector_index_config_t()
        cConfig.dimension = UInt32(config.dimension)
        cConfig.max_elements = UInt32(config.maxElements)
        cConfig.M = UInt32(config.M)
        cConfig.ef_construction = UInt32(config.efConstruction)
        cConfig.ef_search = UInt32(config.efSearch)
        cConfig.allow_replace_deleted = config.allowReplaceDeleted ? 1 : 0
        cConfig.mmap_path = nil
        
        let status = anigma_vector_index_capsule_create(&cConfig, &rawHandle, nil)
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw VectorIndexError.notInitialized
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: { ptr in
                var mutablePtr: anigma_vector_index_capsule_t? = ptr
                anigma_vector_index_capsule_destroy(&mutablePtr)
            }
        )
    }
    
    public func addVector(id: UInt64, vector: [Float]) async throws {
        guard let handle = handle else { throw VectorIndexError.notInitialized }
        
        try handle.withHandle { rawHandle in
            try vector.withUnsafeBufferPointer { vecPtr in
                var error = anigma_capsule_error_t()
                let status = anigma_vector_index_capsule_add_vector(rawHandle, id, vecPtr.baseAddress, &error)
                if status != ANIGMA_OK { throw VectorIndexError.notInitialized }
            }
        }
    }
    
    public func search(query: [Float], k: Int) async throws -> [(id: UInt64, distance: Float)] {
        guard let handle = handle else { throw VectorIndexError.notInitialized }
        
        return try handle.withHandle { rawHandle in
            var ids = [UInt64](repeating: 0, count: k)
            var distances = [Float](repeating: 0, count: k)
            var count: UInt32 = 0
            
            try query.withUnsafeBufferPointer { queryPtr in
                try distances.withUnsafeMutableBufferPointer { distPtr in
                    try ids.withUnsafeMutableBufferPointer { idPtr in
                        var error = anigma_capsule_error_t()
                        let status = anigma_vector_index_capsule_search(
                            rawHandle, queryPtr.baseAddress, UInt32(k),
                            idPtr.baseAddress, distPtr.baseAddress, &count, &error
                        )
                        if status != ANIGMA_OK { throw VectorIndexError.notInitialized }
                    }
                }
            }
            
            guard count > 0 else { return [] }
            return (0..<Int(count)).map { (index) in (id: ids[index], distance: distances[index]) }
        }
    }
    
    public func searchPool(query: [Float], candidateIds: [UInt64], k: Int) async throws -> [(id: UInt64, distance: Float)] {
        guard let handle = handle else { throw VectorIndexError.notInitialized }
        
        let candidateCount = candidateIds.count  // Int matches C size_t
        
        return try handle.withHandle { rawHandle in
            var ids = [UInt64](repeating: 0, count: k)
            var distances = [Float](repeating: 0, count: k)
            var count: UInt32 = 0
            
            try candidateIds.withUnsafeBufferPointer { candPtr in
                try distances.withUnsafeMutableBufferPointer { distPtr in
                    try ids.withUnsafeMutableBufferPointer { idPtr in
                        try query.withUnsafeBufferPointer { queryPtr in
                            var error = anigma_capsule_error_t()
                            let status = anigma_vector_index_capsule_search_pool(
                                rawHandle, queryPtr.baseAddress, candPtr.baseAddress,
                                candidateCount, UInt32(k),
                                idPtr.baseAddress, distPtr.baseAddress, &count, &error
                            )
                            if status != ANIGMA_OK { throw VectorIndexError.notInitialized }
                        }
                    }
                }
            }
            
            guard count > 0 else { return [] }
            return (0..<Int(count)).map { (index) in (id: ids[index], distance: distances[index]) }
        }
    }
    
    public func getCount() throws -> UInt32 {
        guard let handle = handle else { throw VectorIndexError.notInitialized }
        var count: UInt32 = 0
        try handle.withHandle { rawHandle in
            count = anigma_vector_index_capsule_get_count(rawHandle)
        }
        return count
    }
    
    /// Bulk vector retrieval for GPU processing
    /// Returns all vectors flattened for Metal GPU processing
    public func getBulkVectors(count vectorCount: Int) async throws -> [Float] {
        guard let handle = handle else { throw VectorIndexError.emptyIndex }
        
        return try handle.withHandle { rawHandle in
            // Get actual count first
            let actualCount = anigma_vector_index_capsule_get_count(rawHandle)
            guard actualCount > 0 else { return [] }
            
            let dim = config.dimension
            let totalFloats = Int(actualCount) * dim
            
            // Allocate buffer - GPU-accessible via storageModeShared
            var vectors = [Float](repeating: 0, count: totalFloats)
            
            let returnedCount = vectors.withUnsafeMutableBufferPointer { ptr in
                anigma_vector_index_capsule_get_all_vectors(rawHandle, ptr.baseAddress, actualCount)
            }
            
            if returnedCount == 0 {
                return []
            }
            
            return vectors
        }
    }
    
    public func clear() throws {
        guard let handle = handle else { throw VectorIndexError.notInitialized }
        try handle.withHandle { rawHandle in
            var error = anigma_capsule_error_t()
            let status = anigma_vector_index_capsule_clear(rawHandle, &error)
            if status != ANIGMA_OK { throw VectorIndexError.notInitialized }
        }
    }
}