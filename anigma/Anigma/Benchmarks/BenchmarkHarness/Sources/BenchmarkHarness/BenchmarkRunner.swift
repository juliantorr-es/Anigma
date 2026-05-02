import Foundation
import Darwin
import CapsuleCore

public struct BenchmarkRunner {
    public init() {}

    public func run(benchmarks: [BenchmarkCase]) async throws -> BenchmarkReport {
        let clock = ContinuousClock()
        var results: [BenchmarkResult] = []

        for var benchmark in benchmarks {
            CrossLanguageCallMetrics.reset()
            try await benchmark.setUp()
            let startMemory = MemorySampler.currentMemoryBytes()
            let startAllocationCount = AllocationSampler.currentAllocationCount()
            let startCrossLanguageCalls = CrossLanguageCallMetrics.snapshot()
            let start = clock.now

            for _ in 0..<benchmark.iterations {
                try await benchmark.run()
            }

            let end = clock.now
            let endMemory = MemorySampler.currentMemoryBytes()
            let endAllocationCount = AllocationSampler.currentAllocationCount()
            let endCrossLanguageCalls = CrossLanguageCallMetrics.snapshot()
            try await benchmark.tearDown()

            let durationSeconds = Self.durationToSeconds(start.duration(to: end))
            let opsPerSecond = durationSeconds > 0
                ? Double(benchmark.iterations) / durationSeconds
                : 0
            let memoryBytes = MemorySampler.deltaBytes(start: startMemory, end: endMemory)
            let rssBytes = endMemory
            let allocationCount = AllocationSampler.deltaCount(start: startAllocationCount, end: endAllocationCount)
            let crossLanguageCallsByBoundary = CrossLanguageCallSampler.deltaByBoundary(
                start: startCrossLanguageCalls,
                end: endCrossLanguageCalls
            )
            let crossLanguageCallCount = CrossLanguageCallSampler.deltaTotal(
                start: startCrossLanguageCalls,
                end: endCrossLanguageCalls
            )
            let bytesCopied = benchmark.metricHints.bytesCopiedPerIteration.map {
                $0 * Int64(benchmark.iterations)
            }

            results.append(
                BenchmarkResult(
                    name: benchmark.name,
                    wallTimeSeconds: durationSeconds,
                    durationSeconds: durationSeconds,
                    operations: benchmark.iterations,
                    opsPerSecond: opsPerSecond,
                    memoryBytes: memoryBytes,
                    rssBytes: rssBytes,
                    allocationCount: allocationCount,
                    crossLanguageCallCount: crossLanguageCallCount,
                    crossLanguageCallsByBoundary: crossLanguageCallsByBoundary,
                    bytesCopied: bytesCopied
                )
            )
        }

        return BenchmarkReport(generatedAt: Date(), results: results)
    }

    private static func durationToSeconds(_ duration: Duration) -> Double {
        let components = duration.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds)
        return seconds + (attoseconds / 1_000_000_000_000_000_000)
    }
}

enum MemorySampler {
    static func currentMemoryBytes() -> Int64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) /
            mach_msg_type_number_t(MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        return Int64(info.resident_size)
    }

    static func deltaBytes(start: Int64?, end: Int64?) -> Int64? {
        guard let start, let end else {
            return nil
        }

        return end - start
    }
}

enum AllocationSampler {
    static func currentAllocationCount() -> Int64? {
        var stats = malloc_statistics_t()
        malloc_zone_statistics(malloc_default_zone(), &stats)
        return Int64(stats.blocks_in_use)
    }

    static func deltaCount(start: Int64?, end: Int64?) -> Int64? {
        guard let start, let end else {
            return nil
        }

        return end - start
    }
}

enum CrossLanguageCallSampler {
    static func deltaTotal(
        start: CrossLanguageCallMetricsSnapshot,
        end: CrossLanguageCallMetricsSnapshot
    ) -> Int64? {
        guard end.totalCalls >= start.totalCalls else { return nil }
        return Int64(end.totalCalls - start.totalCalls)
    }

    static func deltaByBoundary(
        start: CrossLanguageCallMetricsSnapshot,
        end: CrossLanguageCallMetricsSnapshot
    ) -> [String: Int64]? {
        var deltas: [String: Int64] = [:]
        for (boundary, endCount) in end.perBoundary {
            let startCount = start.perBoundary[boundary, default: 0]
            guard endCount >= startCount else { continue }
            let delta = endCount - startCount
            if delta > 0 {
                deltas[boundary] = Int64(delta)
            }
        }
        return deltas.isEmpty ? nil : deltas
    }
}

public enum BenchmarkBlackhole {
    @inline(never)
    public static func consume<T>(_ value: T) {
        withUnsafeBytes(of: value) { buffer in
            _ = buffer.count
        }
    }
}
