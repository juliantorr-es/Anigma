import Foundation
import os

/// Snapshot of cross-language call counters at Swift/native boundaries.
public struct CrossLanguageCallMetricsSnapshot: Sendable {
    public let totalCalls: UInt64
    public let perBoundary: [String: UInt64]

    public init(totalCalls: UInt64, perBoundary: [String: UInt64]) {
        self.totalCalls = totalCalls
        self.perBoundary = perBoundary
    }

    /// Convert counts into flat metadata for existing diagnostics pipelines.
    public func diagnosticsMetadata(prefix: String = "cross_language_calls", topK: Int = 8) -> [String: String] {
        let normalizedTopK = max(topK, 0)
        var metadata: [String: String] = [
            "\(prefix).total": String(totalCalls),
            "\(prefix).unique_boundaries": String(perBoundary.count)
        ]

        guard normalizedTopK > 0 else { return metadata }

        for (index, entry) in perBoundary
            .sorted(by: { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            })
            .prefix(normalizedTopK)
            .enumerated() {
            let key = "\(prefix).top\(index + 1)"
            metadata[key] = "\(entry.key)=\(entry.value)"
        }

        return metadata
    }
}

/// Low-overhead process-local counters for Swift/native boundary calls.
public enum CrossLanguageCallMetrics {
    private struct State {
        var totalCalls: UInt64 = 0
        var perBoundary: [String: UInt64] = [:]
    }

    private static let stateLock = OSAllocatedUnfairLock<State>(initialState: State())

    /// Record one or more boundary calls for a stable key.
    @inline(__always)
    public static func record(boundary: String, calls: UInt64 = 1) {
        guard calls > 0 else { return }
        stateLock.withLock { state in
            state.totalCalls &+= calls
            state.perBoundary[boundary, default: 0] &+= calls
        }
    }

    /// Record one or more boundary calls for a static key.
    @inline(__always)
    public static func record(boundary: StaticString, calls: UInt64 = 1) {
        record(boundary: String(describing: boundary), calls: calls)
    }

    /// Read all call counters.
    public static func snapshot() -> CrossLanguageCallMetricsSnapshot {
        stateLock.withLock { state in
            CrossLanguageCallMetricsSnapshot(
                totalCalls: state.totalCalls,
                perBoundary: state.perBoundary
            )
        }
    }

    /// Read calls for one boundary key.
    public static func count(for boundary: String) -> UInt64 {
        stateLock.withLock { state in
            state.perBoundary[boundary, default: 0]
        }
    }

    /// Reset all counters.
    public static func reset() {
        stateLock.withLock { state in
            state = State()
        }
    }
}
