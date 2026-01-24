import Foundation
import AnigmaNativeShims
import CapsuleCore

/// Low-level wrapper for the native text chunking capsule.
internal final class TextChunkingCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>
    
    init(config: TextChunkingConfig) throws {
        var rawHandle: anigma_text_chunking_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = anigma_text_chunking_config_t()
        cConfig.target_chunk_size = UInt32(config.targetChunkSize)
        cConfig.min_chunk_size = UInt32(config.minChunkSize)
        cConfig.max_chunk_size = UInt32(config.maxChunkSize)
        cConfig.window_size = UInt32(config.windowSize)
        cConfig.polynomial = config.polynomial
        cConfig.determinism_tier = config.determinismTier
        
        let status = anigma_text_chunking_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: { ptr, err in
                anigma_text_chunking_capsule_destroy(ptr, err)
            }
        )
    }
    
    func processBytes(_ data: Data) throws {
        var error = anigma_capsule_error_t()
        try handle.withHandle { rawHandle in
            let status = data.withUnsafeBytes { bytes in
                anigma_text_chunking_capsule_process_bytes(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
    
    func finalize() throws {
        var error = anigma_capsule_error_t()
        try handle.withHandle { rawHandle in
            let status = anigma_text_chunking_capsule_finalize(rawHandle, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
    
    func reset() throws {
        var error = anigma_capsule_error_t()
        try handle.withHandle { rawHandle in
            let status = anigma_text_chunking_capsule_reset(rawHandle, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
    
    func getBoundaries() throws -> [anigma_chunk_boundary_t] {
        var error = anigma_capsule_error_t()
        return try handle.withHandle { rawHandle in
            var count: Int = 0
            let countStatus = anigma_text_chunking_capsule_get_boundary_count(rawHandle, &count, &error)
            guard countStatus == ANIGMA_OK else {
                throw CapsuleError(status: countStatus, error: error)
            }
            
            var boundaries = [anigma_chunk_boundary_t](repeating: anigma_chunk_boundary_t(), count: count)
            var actual: Int = 0
            let getStatus = anigma_text_chunking_capsule_get_chunk_info(rawHandle, &boundaries, count, &actual, &error)
            guard getStatus == ANIGMA_OK else {
                throw CapsuleError(status: getStatus, error: error)
            }
            
            return Array(boundaries.prefix(actual))
        }
    }
}
