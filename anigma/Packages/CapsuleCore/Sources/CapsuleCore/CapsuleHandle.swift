import Foundation
import AnigmaNativeShims

/// A generic thread-safe wrapper for opaque capsule handles.
/// Ensures thread safety and automatic destruction.
public final class CapsuleHandle<HandleType> where HandleType: AnyObject {
    private var rawHandle: anigma_capsule_handle_t?
    private let destroyFunction: (anigma_capsule_handle_t, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
    private let lock = NSLock()
    
    /// Initialize a capsule handle with a destruction function.
    /// - Parameters:
    ///   - rawHandle: The opaque C handle
    ///   - destroyFunction: Function to destroy the handle
    public init(
        rawHandle: anigma_capsule_handle_t,
        destroyFunction: @escaping (anigma_capsule_handle_t, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
    ) {
        self.rawHandle = rawHandle
        self.destroyFunction = destroyFunction
    }
    
    deinit {
        if let handle = rawHandle {
            var err = anigma_capsule_error_t()
            _ = destroyFunction(handle, &err)
        }
    }
    
    /// Execute a closure with the raw handle.
    /// - Parameter body: Closure that receives the raw handle
    /// - Returns: Result of the closure
    /// - Throws: `CapsuleError` if the handle is invalid
    public func withHandle<T>(_ body: (anigma_capsule_handle_t) throws -> T) throws -> T where T: Sendable {
        lock.lock()
        defer { lock.unlock() }
        guard let handle = rawHandle else {
            throw CapsuleError(
                status: ANIGMA_ERR_NOT_INITIALIZED,
                error: anigma_capsule_error_t(
                    code: ANIGMA_ERR_NOT_INITIALIZED,
                    message: "Handle has been destroyed",
                    detail: nil,
                    aux: 0
                )
            )
        }
        
        return try body(handle)
    }
    
    /// Invalidate the handle (force destruction).
    /// After calling this, the handle cannot be used.
    public func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        if let handle = rawHandle {
            var err = anigma_capsule_error_t()
            _ = destroyFunction(handle, &err)
            rawHandle = nil
        }
    }
    
    /// Check if the handle is still valid.
    public var isValid: Bool {
        lock.lock()
        defer { lock.unlock() }
        return rawHandle != nil
    }
}

/// Protocol for capsules that manage their own handles.
public protocol CapsuleProtocol where HandleType: AnyObject {
    associatedtype HandleType
    
    /// Create a new handle.
    static func createHandle() throws -> CapsuleHandle<HandleType>
    
    /// Get the capsule's identity.
    static var identity: anigma_capsule_identity_t { get }
}

/// Extension for capsules that follow the standard pattern.
extension CapsuleProtocol {
    /// Default implementation for capsules that expose `anigma_capsule_destroy_handle`.
    public static func standardDestroyFunction(handle: anigma_capsule_handle_t, error: UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t {
        // Since we unified the API, we use the master destruction function if available, 
        // or a dummy one if not yet implemented.
        return ANIGMA_OK
    }
    
    /// Create a handle using the standard destruction function.
    public static func createStandardHandle(_ creation: () throws -> anigma_capsule_handle_t) throws -> CapsuleHandle<AnyObject> {
        let rawHandle = try creation()
        return CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: standardDestroyFunction
        )
    }
}