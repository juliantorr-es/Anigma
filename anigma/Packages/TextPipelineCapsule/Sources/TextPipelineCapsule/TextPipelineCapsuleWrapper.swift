import Foundation
import AnigmaNativeShims
import CapsuleCore

internal final class TextPipelineCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>
    
    init(config: TextPipelineConfig) throws {
        var rawHandle: anigma_text_pipeline_capsule_t? = nil
        var error = anigma_capsule_error_t()
        var cConfig = anigma_text_pipeline_config_t()
        
        let status = anigma_text_pipeline_capsule_create(&cConfig, &rawHandle, &error)
        
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: { ptr, err in
                return anigma_text_pipeline_capsule_destroy(ptr, err)
            }
        )
    }
}
