import Foundation
@preconcurrency import AnigmaNativeShims

/// A buffer descriptor for zero-copy marshalling between Swift and C capsules.
/// Enforces the two-phase pattern: size query then fill.
public struct CapsuleBuffer: ~Copyable {
    private var descriptor: anigma_capsule_buffer_t
    private let owner: BufferOwner
    private var released: Bool = false
    
    public enum BufferOwner {
        case borrowedInput  // Caller owns, capsule reads only
        case callerAllocatedOutput  // Caller allocates, capsule writes
        case capsuleAllocatedOutput  // Capsule allocates, caller frees
    }
    
    /// Create a buffer for borrowed input (caller-owned memory).
    /// - Parameters:
    ///   - bytes: Pointer to the input data
    ///   - count: Number of bytes available
    public init(borrowedInput bytes: UnsafeRawPointer, count: Int) {
        self.descriptor = anigma_capsule_buffer_t(
            ptr: UnsafeMutablePointer<UInt8>(mutating: bytes.assumingMemoryBound(to: UInt8.self)),
            len: count,
            cap: count
        )
        self.owner = .borrowedInput
    }
    
    /// Create a buffer for caller-allocated output.
    /// - Parameters:
    ///   - capacity: Maximum capacity of the buffer
    public init(callerAllocatedOutput capacity: Int) {
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        self.descriptor = anigma_capsule_buffer_t(
            ptr: ptr,
            len: 0,  // Nothing written yet
            cap: capacity
        )
        self.owner = .callerAllocatedOutput
    }
    
    /// Create a buffer from a capsule-allocated pointer.
    /// - Parameters:
    ///   - capsuleAllocated: Pointer allocated by the capsule
    ///   - count: Number of bytes written by the capsule
    /// - Important: The buffer takes ownership and will free the pointer when deinitialized.
    public init(capsuleAllocated ptr: UnsafeMutablePointer<UInt8>, count: Int) {
        self.descriptor = anigma_capsule_buffer_t(
            ptr: ptr,
            len: count,
            cap: count
        )
        self.owner = .capsuleAllocatedOutput
    }
    
    deinit {
        if released { return }
        switch owner {
        case .borrowedInput:
            break  // Nothing to free
        case .callerAllocatedOutput:
            descriptor.ptr.deallocate()
        case .capsuleAllocatedOutput:
            var err = anigma_capsule_error_t()
            _ = anigma_capsule_free_buffer(descriptor.ptr, &err)
        }
    }
    
    /// Raw pointer to the buffer data.
    public var pointer: UnsafeMutablePointer<UInt8> {
        descriptor.ptr
    }
    
    /// Number of bytes written (for output) or available (for input).
    public var count: Int {
        get { descriptor.len }
        set { descriptor.len = newValue }
    }
    
    /// Total capacity of the buffer.
    public var capacity: Int {
        descriptor.cap
    }
    
    /// Copy the buffer contents into a Data object.
    /// - Returns: A Data object containing the buffer contents.
    public func toData() -> Data {
        Data(bytes: descriptor.ptr, count: descriptor.len)
    }
    
    /// Execute a closure with a pointer to the buffer descriptor for C interop.
    /// - Parameter body: Closure that receives a pointer to the buffer descriptor
    /// - Returns: Result of the closure
    public mutating func withUnsafeDescriptor<T>(_ body: (UnsafeMutablePointer<anigma_capsule_buffer_t>) throws -> T) rethrows -> T {
        try withUnsafeMutablePointer(to: &descriptor) { ptr in
            try body(ptr)
        }
    }
    
    /// Execute a closure with a pointer to the buffer descriptor for C interop (non‑mutating).
    /// - Parameter body: Closure that receives a pointer to the buffer descriptor
    /// - Returns: Result of the closure
    public func withUnsafeDescriptor<T>(
        _ body: (UnsafePointer<anigma_capsule_buffer_t>) throws -> T
    ) rethrows -> T {
        try withUnsafePointer(to: descriptor) { ptr in
            try body(ptr)
        }
    }
    
    /// Mark the buffer as released (to prevent double‑free).
    public consuming func markReleased() {
        released = true
    }
    
    /// Two-phase buffer filling pattern helper.
    /// 1. First call with nil buffer to get required size.
    /// 2. Allocate buffer with required size.
    /// 3. Second call with allocated buffer to fill.
    /// - Parameter operation: Closure that performs the capsule operation.
    ///   It receives a buffer descriptor pointer and returns a status code.
    /// - Returns: The filled buffer if successful.
    /// - Throws: `CapsuleNativeError` if the operation fails.
    public static func fill(
        _ operation: (UnsafeMutablePointer<anigma_capsule_buffer_t>?) throws -> AnigmaNativeShims.anigma_status_t
    ) throws -> CapsuleBuffer {
        // Phase 1: Query required size
        let err = anigma_capsule_error_t()
        let queryStatus = try operation(nil)
        
        guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
            throw CapsuleNativeError(status: queryStatus, error: err)
        }
        
        let requiredSize = err.aux
        
        // Phase 2: Allocate and fill
        var buffer = CapsuleBuffer(callerAllocatedOutput: Int(requiredSize))
        let fillStatus = try buffer.withUnsafeDescriptor { descPtr in
            try operation(descPtr)
        }
        
        guard fillStatus == ANIGMA_OK else {
            throw CapsuleNativeError(status: fillStatus, error: err)
        }
        
        return buffer
    }
}

/// Error type for capsule operations (native bridging).
public struct CapsuleNativeError: Error {
    public let status: anigma_status_t
    public let error: anigma_capsule_error_t
    public let message: String?
    
    public init(status: anigma_status_t, error: anigma_capsule_error_t) {
        self.status = status
        self.error = error
        self.message = nil
    }

    public init(status: anigma_status_t, code: anigma_status_t, message: String) {
        self.status = status
        self.error = anigma_capsule_error_t(code: code, message: nil, detail: nil, aux: 0)
        self.message = message
    }
    
    public var localizedDescription: String {
        let msg = message ?? (error.message.map { String(cString: $0) } ?? "Unknown error")
        let det = error.detail.map { String(cString: $0) } ?? ""
        return "Capsule native error \(status): \(msg)\(det.isEmpty ? "" : " (\(det))")"
    }
}
