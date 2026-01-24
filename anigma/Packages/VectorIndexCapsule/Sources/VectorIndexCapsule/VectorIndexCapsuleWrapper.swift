import Foundation
import AnigmaNativeShims
import CapsuleCore

/// Internal wrapper for the native vector index capsule.
internal actor VectorIndexCapsuleWrapper {
    private let config: VectorIndexConfig
    private var handle: CapsuleHandle<AnyObject>?
    
    init(config: VectorIndexConfig) throws {
        self.config = config
        
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
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: { ptr, err in
                var mutablePtr: anigma_vector_index_capsule_t? = ptr
                anigma_vector_index_capsule_destroy(&mutablePtr)
                return ANIGMA_OK
            }
        )
    }
    
    func addVector(id: UInt64, vector: [Float]) throws {
        guard vector.count == Int(config.dimension) else {
            throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
        }
        
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = vector.withUnsafeBufferPointer { buf in
                anigma_vector_index_capsule_add_vector(rawHandle, id, buf.baseAddress, &error)
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
    
    func search(query: [Float], k: Int) throws -> [(id: UInt64, distance: Float)] {
        guard query.count == Int(config.dimension) else {
            throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
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
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return (0..<Int(count)).map { (ids[$0], distances[$0]) }
    }
    
    func searchPool(query: [Float], candidateIds: [UInt64], k: Int) throws -> [(id: UInt64, distance: Float)] {
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
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return (0..<Int(count)).map { (ids[$0], distances[$0]) }
    }
    
    func getCount() throws -> UInt32 {
        var count: UInt32 = 0
        try handle?.withHandle { rawHandle in
            count = anigma_vector_index_capsule_get_count(rawHandle)
        }
        return count
    }
    
    func clear() throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_vector_index_capsule_clear(rawHandle, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
}
