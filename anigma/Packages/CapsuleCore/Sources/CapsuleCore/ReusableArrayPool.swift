import Foundation

/// Small reusable array pool for hot capsule paths.
///
/// Keeps a tiny number of scratch buffers alive so repeated batch work can
/// reuse capacity instead of repeatedly allocating new arrays.
public final class ReusableArrayPool<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var buffers: [[Element]] = []
    private let maxBuffers: Int

    public init(maxBuffers: Int = 2) {
        self.maxBuffers = max(1, maxBuffers)
    }

    /// Borrow a scratch array, use it in-place, then return it to the pool.
    ///
    /// The closure receives a uniquely-owned buffer, so it can be mutated freely.
    /// The returned value should be copied out if it needs to outlive the closure.
    public func withBuffer<R>(
        minimumCapacity: Int = 0,
        _ body: (inout [Element]) throws -> R
    ) rethrows -> R {
        var buffer = lock.withLock { buffers.popLast() ?? [] }
        if minimumCapacity > 0 {
            buffer.reserveCapacity(minimumCapacity)
        }
        buffer.removeAll(keepingCapacity: true)

        defer {
            lock.withLock {
                if buffers.count < maxBuffers {
                    buffers.append(buffer)
                }
            }
        }

        return try body(&buffer)
    }

    public func clear() {
        lock.withLock {
            buffers.removeAll(keepingCapacity: true)
        }
    }
}

private extension NSLock {
    func withLock<R>(_ body: () throws -> R) rethrows -> R {
        lock()
        defer { unlock() }
        return try body()
    }
}
