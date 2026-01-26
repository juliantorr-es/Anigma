import Foundation
import SyntaxNative
import CapsuleCore
import AnigmaNativeShims

public enum SyntaxLanguage: Int {
    case json = 0
    case swift = 1
    case python = 2
    case markdown = 3
    
    var native: anigma_syntax_language_t {
        return anigma_syntax_language_t(rawValue: UInt32(self.rawValue))
    }
}

public final class SyntaxParser {
    internal let handle: CapsuleHandle<AnyObject>
    
    public init(language: SyntaxLanguage) throws {
        var raw: anigma_syntax_parser_t?
        var err = anigma_capsule_error_t()
        
        let status = anigma_syntax_parser_create(language.native, &raw, &err)
        
        guard status == ANIGMA_OK, let h = raw else {
            throw capsuleError(status: status, error: err)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: h,
            destroyFunction: capsuleDestroyer(anigma_syntax_parser_destroy)
        )
    }
    
    public func parse(source: String) throws -> SyntaxTree {
        var rawTree: anigma_syntax_tree_t?
        var err = anigma_capsule_error_t()
        
        let status = try handle.withHandle { parserHandle in
            source.withCString { sourcePtr in
                anigma_syntax_parser_parse_string(
                    parserHandle,
                    sourcePtr,
                    UInt32(source.utf8.count),
                    &rawTree,
                    &err
                )
            }
        }
        
        guard status == ANIGMA_OK, let h = rawTree else {
            throw capsuleError(status: status, error: err)
        }
        
        let treeHandle = CapsuleHandle<AnyObject>(
            rawHandle: h,
            destroyFunction: capsuleDestroyer(anigma_syntax_tree_destroy)
        )
        
        return SyntaxTree(handle: treeHandle)
    }
}

public final class SyntaxTree {
    internal let handle: CapsuleHandle<AnyObject>
    
    internal init(handle: CapsuleHandle<AnyObject>) {
        self.handle = handle
    }
    
    public var rootNode: SyntaxNode? {
        var info = anigma_syntax_node_info_t()
        var nodeHandleRaw: anigma_capsule_handle_t?
        var err = anigma_capsule_error_t()
        
        let status = try? handle.withHandle { treeHandle in
            anigma_syntax_tree_get_root_node(treeHandle, &info, &nodeHandleRaw, &err)
        }
        
        if status == ANIGMA_OK, let h = nodeHandleRaw {
            let capHandle = CapsuleHandle<AnyObject>(
                rawHandle: h,
                destroyFunction: capsuleDestroyer(anigma_syntax_node_destroy)
            )
            return SyntaxNode(handle: capHandle, info: info)
        }
        return nil
    }

    public var rootNodeString: String {
        var strPtr: UnsafeMutablePointer<CChar>?
        var err = anigma_capsule_error_t()
        
        let status = try? handle.withHandle { ptr in
            anigma_syntax_tree_root_node_string(ptr, &strPtr, &err)
        }
        
        if status == ANIGMA_OK, let s = strPtr {
            let str = String(cString: s)
            free(s)
            return str
        }
        return ""
    }
}

public struct SyntaxNodeInfo {
    public let startByte: Int
    public let endByte: Int
    public let startRow: Int
    public let startColumn: Int
    public let endRow: Int
    public let endColumn: Int
    public let type: String
    public let isNamed: Bool

    init(native: anigma_syntax_node_info_t) {
        self.startByte = Int(native.start_byte)
        self.endByte = Int(native.end_byte)
        self.startRow = Int(native.start_row)
        self.startColumn = Int(native.start_column)
        self.endRow = Int(native.end_row)
        self.endColumn = Int(native.end_column)
        self.type = String(cString: native.type)
        self.isNamed = native.is_named
    }
}

public final class SyntaxNode {
    internal let handle: CapsuleHandle<AnyObject>
    public let info: SyntaxNodeInfo
    
    internal init(handle: CapsuleHandle<AnyObject>, info: anigma_syntax_node_info_t) {
        self.handle = handle
        self.info = SyntaxNodeInfo(native: info)
    }

    public var children: [SyntaxNode] {
        var count: UInt32 = 0
        var err = anigma_capsule_error_t()
        
        let status = try? handle.withHandle { h in
            anigma_syntax_node_get_child_count(h, &count, &err)
        }
        
        guard status == ANIGMA_OK else { return [] }
        
        var result: [SyntaxNode] = []
        for i in 0..<count {
            var childInfo = anigma_syntax_node_info_t()
            var childHandleRaw: anigma_capsule_handle_t?
            
            let childStatus = try? handle.withHandle { h in
                anigma_syntax_node_get_child(h, i, &childInfo, &childHandleRaw, &err)
            }
            
            if childStatus == ANIGMA_OK, let ch = childHandleRaw {
                let capHandle = CapsuleHandle<AnyObject>(
                    rawHandle: ch,
                    destroyFunction: capsuleDestroyer(anigma_syntax_node_destroy)
                )
                result.append(SyntaxNode(handle: capHandle, info: childInfo))
            }
        }
        return result
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
