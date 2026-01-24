import Foundation
import VectorStoreNative
import CapsuleCore
import AnigmaNativeShims

public final class VectorStore {
    // This is a utility class, mainly for registration.
    
    /// Register the sqlite-vec extension with a SQLite connection.
    /// - Parameter dbHandle: A raw pointer to the `sqlite3` connection handle.
    public static func registerExtension(with dbHandle: UnsafeMutableRawPointer) throws {
        var err = anigma_capsule_error_t()
        
        let status = anigma_vector_store_register(dbHandle, &err)
        
        if status != ANIGMA_OK {
            throw CapsuleError(status: status, error: err)
        }
    }
    
    /// Get the version of the underlying sqlite-vec extension.
    public static var version: String {
        var versionPtr: UnsafeMutablePointer<CChar>?
        var err = anigma_capsule_error_t()
        
        let status = anigma_vector_store_version(&versionPtr, &err)
        
        if status == ANIGMA_OK, let v = versionPtr {
            let str = String(cString: v)
            free(v) // Using standard free as we used malloc in C shim
            return str
        }
        
        return "unknown"
    }
}
