import Foundation
import AnigmaNativeShims

/// A generic thread-safe wrapper for opaque capsule handles.
/// Ensures thread safety and automatic destruction.
public final class CapsuleHandle<HandleType> where HandleType: AnyObject {
    public var rawHandle: UnsafeMutableRawPointer?
    public let destroyFunction: (UnsafeMutableRawPointer) -> Void
    private let lock = NSLock()
    
    /// Initialize a capsule handle with a destruction function.
    /// - Parameters:
    ///   - rawHandle: The opaque C handle
    ///   - destroyFunction: Function to destroy the handle
    public init(
        rawHandle: UnsafeMutableRawPointer,
        destroyFunction: @escaping (UnsafeMutableRawPointer) -> Void
    ) {
        self.rawHandle = rawHandle
        self.destroyFunction = destroyFunction
    }

    public convenience init(
        rawHandle: UnsafeMutableRawPointer,
        destroyFunction: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
    ) {
        self.init(
            rawHandle: rawHandle,
            destroyFunction: { ptr in
                var err = anigma_capsule_error_t()
                _ = destroyFunction(ptr, &err)
            }
        )
    }

    /// Factory for creating a capsule handle from another module.
    public static func make(
        rawHandle: UnsafeMutableRawPointer,
        destroyFunction: @escaping (UnsafeMutableRawPointer) -> Void
    ) -> CapsuleHandle<AnyObject> {
        CapsuleHandle<AnyObject>(rawHandle: rawHandle, destroyFunction: destroyFunction)
    }
    
    deinit {
        if let handle = rawHandle {
            destroyFunction(handle)
        }
    }
    
    /// Execute a closure with the raw handle.
    /// - Parameter body: Closure that receives the raw handle
    /// - Returns: Result of the closure
    /// - Throws: `CapsuleError` if the handle is invalid
    public func withHandle<T>(_ body: (UnsafeMutableRawPointer) throws -> T) throws -> T where T: Sendable {
        lock.lock()
        defer { lock.unlock() }
        guard let handle = rawHandle else {
            throw CapsuleError(
                status: ANIGMA_ERR_NOT_INITIALIZED,
                error: anigma_capsule_error_t(
                    code: ANIGMA_ERR_NOT_INITIALIZED,
                    message: nil, // String message issue handled in header/C
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
            destroyFunction(handle)
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

/// Top-level factory for creating capsule handles across modules.
public func makeCapsuleHandle(
    rawHandle: UnsafeMutableRawPointer,
    destroyFunction: @escaping (UnsafeMutableRawPointer) -> Void
) -> CapsuleHandle<AnyObject> {
    CapsuleHandle<AnyObject>(rawHandle: rawHandle, destroyFunction: destroyFunction)
}

public func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}

public func capsuleErrorFrom(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleError(status: status, code: error.code, message: message)
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
    public static func standardDestroyFunction(handle: UnsafeMutableRawPointer) {
    }
    
    /// Create a handle using the standard destruction function.
    public static func createStandardHandle(_ creation: () throws -> UnsafeMutableRawPointer) throws -> CapsuleHandle<AnyObject> {
        let rawHandle = try creation()
        return CapsuleHandle<AnyObject>(rawHandle: rawHandle, destroyFunction: standardDestroyFunction)
    }
}
