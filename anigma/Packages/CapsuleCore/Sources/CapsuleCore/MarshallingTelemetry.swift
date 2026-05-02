import Foundation
import AnigmaNativeShims
import os

/// Tracks marshalling metrics for performance analysis and enforcement.
public final class MarshallingTelemetry: @unchecked Sendable {
    private var metrics = anigma_capsule_telemetry_t()
    private let lock = OSAllocatedUnfairLock()
    
    public init() {}
    
    /// Record bytes transferred into the capsule.
    public func recordBytesIn(_ count: Int) {
        lock.withLock {
            metrics.bytes_in += UInt64(count)
        }
    }
    
    /// Record bytes transferred out of the capsule.
    public func recordBytesOut(_ count: Int) {
        lock.withLock {
            metrics.bytes_out += UInt64(count)
        }
    }
    
    /// Record an ABI call.
    public func recordABICall() {
        lock.withLock {
            metrics.abi_calls += 1
        }
    }
    
    /// Record a buffer allocation.
    public func recordBufferAllocation() {
        lock.withLock {
            metrics.buffer_allocations += 1
        }
    }
    
    /// Record a string conversion (should be zero in hot paths).
    public func recordStringConversion() {
        lock.withLock {
            metrics.string_conversions += 1
        }
    }
    
    /// Record a copy operation.
    public func recordCopyOperation() {
        lock.withLock {
            metrics.copy_operations += 1
        }
    }
    
    /// Record operation duration.
    public func recordDuration(_ nanoseconds: UInt64) {
        lock.withLock {
            metrics.total_duration_ns += nanoseconds
        }
    }
    
    /// Get current metrics snapshot.
    public var snapshot: anigma_capsule_telemetry_t {
        lock.withLock {
            metrics
        }
    }
    
    /// Reset all metrics to zero.
    public func reset() {
        lock.withLock {
            metrics = anigma_capsule_telemetry_t()
        }
    }
    
    /// Check if metrics violate any budgets.
    /// - Parameter budgets: The budget limits to check against
    /// - Returns: Array of violated budget descriptions, empty if all within limits
    public func checkBudgets(_ budgets: MarshallingBudgets) -> [String] {
        let snap = snapshot
        var violations: [String] = []
        
        if budgets.maxABICalls > 0 && snap.abi_calls > budgets.maxABICalls {
            violations.append("ABI calls exceeded: \(snap.abi_calls) > \(budgets.maxABICalls)")
        }
        
        if budgets.maxStringConversions > 0 && snap.string_conversions > budgets.maxStringConversions {
            violations.append("String conversions exceeded: \(snap.string_conversions) > \(budgets.maxStringConversions)")
        }
        
        if budgets.maxBytesCopied > 0 && snap.copy_operations > budgets.maxBytesCopied {
            violations.append("Bytes copied exceeded: \(snap.copy_operations) > \(budgets.maxBytesCopied)")
        }
        
        if budgets.maxBufferAllocations > 0 && snap.buffer_allocations > budgets.maxBufferAllocations {
            violations.append("Buffer allocations exceeded: \(snap.buffer_allocations) > \(budgets.maxBufferAllocations)")
        }
        
        return violations
    }
}

/// Budget limits for marshalling operations.
public struct MarshallingBudgets: Sendable {
    public let maxABICalls: UInt64
    public let maxStringConversions: UInt64
    public let maxBytesCopied: UInt64
    public let maxBufferAllocations: UInt64
    
    public init(
        maxABICalls: UInt64 = 0,  // 0 means no limit
        maxStringConversions: UInt64 = 0,
        maxBytesCopied: UInt64 = 0,
        maxBufferAllocations: UInt64 = 0
    ) {
        self.maxABICalls = maxABICalls
        self.maxStringConversions = maxStringConversions
        self.maxBytesCopied = maxBytesCopied
        self.maxBufferAllocations = maxBufferAllocations
    }
    
    /// Strict budget for performance-critical paths (no string conversions, minimal ABI calls).
    public static let strict = MarshallingBudgets(
        maxABICalls: 2,  // Size query + fill only
        maxStringConversions: 0,
        maxBytesCopied: 1024 * 1024,  // 1MB
        maxBufferAllocations: 1
    )
    
    /// Lenient budget for import/export boundaries.
    public static let lenient = MarshallingBudgets(
        maxABICalls: 10,
        maxStringConversions: 2,
        maxBytesCopied: 10 * 1024 * 1024,  // 10MB
        maxBufferAllocations: 5
    )
}

/// A wrapper that instruments capsule operations with telemetry.
@propertyWrapper
public struct Instrumented<Value> {
    private var value: Value
    private let telemetry: MarshallingTelemetry
    
    public init(wrappedValue: Value, telemetry: MarshallingTelemetry) {
        self.value = wrappedValue
        self.telemetry = telemetry
    }
    
    public var wrappedValue: Value {
        get { value }
        set { value = newValue }
    }
    
    public var projectedValue: MarshallingTelemetry {
        telemetry
    }
}

/// Helper to measure operation duration.
public func measureDuration<T>(_ operation: () throws -> T, recordTo telemetry: MarshallingTelemetry? = nil) rethrows -> T where T: Sendable {
    let start = DispatchTime.now()
    defer {
        let end = DispatchTime.now()
        let nanoseconds = end.uptimeNanoseconds - start.uptimeNanoseconds
        telemetry?.recordDuration(nanoseconds)
    }
    return try operation()
}
