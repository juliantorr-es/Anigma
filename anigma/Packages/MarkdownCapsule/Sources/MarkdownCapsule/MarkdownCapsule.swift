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
            throw CapsuleError(status: status, error: err)
        }
        
        self.handle = CapsuleHandle(rawHandle: h, destroyFunction: { ptr, e in
            anigma_markdown_node_destroy(ptr, e)
        })
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
        throw CapsuleError(status: status, error: err)
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
        throw CapsuleError(status: status, error: err)
    }
}
