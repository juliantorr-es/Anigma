import Foundation
import MarkdownNative
import CapsuleCore
import AnigmaNativeShims

public final class MarkdownDocument {
    internal let handle: CapsuleHandle<AnyObject>
    
    public init(markdown: String, options: Int32 = 0) throws {
        var raw: anigma_markdown_node_t?
        var err = anigma_capsule_error_t()
        
        let status = markdown.withCString { mStr in
            anigma_markdown_parse_string(mStr, markdown.utf8.count, options, &raw, &err)
        }
        
        guard status == ANIGMA_OK, let h = raw else {
            throw capsuleError(status: status, error: err)
        }

        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: h,
            destroyFunction: capsuleDestroyer(anigma_markdown_node_destroy)
        )
    }
    
    public func renderHTML(options: Int32 = 0) throws -> String {
        var htmlPtr: UnsafeMutablePointer<CChar>?
        var err = anigma_capsule_error_t()
        
        let status = try handle.withHandle { ptr in
            anigma_markdown_render_html(ptr, options, &htmlPtr, &err)
        }
        
        if status == ANIGMA_OK, let s = htmlPtr {
            let str = String(cString: s)
            free(s)
            return str
        }
        throw capsuleError(status: status, error: err)
    }
    
    public func renderPlaintext(options: Int32 = 0, width: Int32 = 0) throws -> String {
        var textPtr: UnsafeMutablePointer<CChar>?
        var err = anigma_capsule_error_t()
        
        let status = try handle.withHandle { ptr in
            anigma_markdown_render_plaintext(ptr, options, width, &textPtr, &err)
        }
        
        if status == ANIGMA_OK, let s = textPtr {
            let str = String(cString: s)
            free(s)
            return str
        }
        throw capsuleError(status: status, error: err)
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}
