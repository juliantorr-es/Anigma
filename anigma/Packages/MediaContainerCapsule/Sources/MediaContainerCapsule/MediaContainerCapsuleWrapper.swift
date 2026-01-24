import Foundation
import AnigmaNativeShims
import CapsuleCore

internal final class MediaContainerCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>
    
    init(config: MediaContainerConfig) throws {
        var rawHandle: anigma_media_container_capsule_t?
        var error = anigma_capsule_error_t()
        var cConfig = anigma_media_container_config_t()
        
        let status = anigma_media_container_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: { ptr, err in
                var mutablePtr: anigma_media_container_capsule_t? = ptr
                return anigma_media_container_capsule_destroy(&mutablePtr, err)
            }
        )
    }
}

public struct MediaContainerConfig: Sendable, Codable {
    public init() {}
}
