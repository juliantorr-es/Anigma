import Foundation
import AnigmaNativeShims
import CapsuleCore

public final class TextPipelineCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>
    
    public convenience init() throws {
        try self.init(config: TextPipelineConfig())
    }
    
    public init(config: TextPipelineConfig) throws {
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
    
    public func normalizeNFC(_ text: String) throws -> String {
        return text.precomposedStringWithCanonicalMapping
    }
    
    public func toLowercase(_ text: String) throws -> String {
        return text.lowercased()
    }
    
    public func stripDiacritics(_ text: String) throws -> String {
        return text.applyingTransform(.stripCombiningMarks, reverse: false) ?? text
    }
    
    public func validateUTF8(_ text: String) throws -> Bool {
        return text.data(using: .utf8) != nil
    }
    
    public func foldToASCII(_ text: String) throws -> String {
        return text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}
