import Foundation
import Darwin

public struct BenchmarkRunner {
    public init() {}

    public func run(benchmarks: [BenchmarkCase]) throws -> BenchmarkReport {
        let clock = ContinuousClock()
        var results: [BenchmarkResult] = []

        for benchmark in benchmarks {
            try benchmark.setUp()
            let startMemory = MemorySampler.currentMemoryBytes()
            let start = clock.now

            for _ in 0..<benchmark.iterations {
                try benchmark.run()
            }

            let end = clock.now
            let endMemory = MemorySampler.currentMemoryBytes()
            try benchmark.tearDown()

            let durationSeconds = Self.durationToSeconds(start.duration(to: end))
            let opsPerSecond = durationSeconds > 0
                ? Double(benchmark.iterations) / durationSeconds
                : 0
            let memoryBytes = MemorySampler.deltaBytes(start: startMemory, end: endMemory)

            results.append(
                BenchmarkResult(
                    name: benchmark.name,
                    durationSeconds: durationSeconds,
                    operations: benchmark.iterations,
                    opsPerSecond: opsPerSecond,
                    memoryBytes: memoryBytes
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

public enum BenchmarkBlackhole {
    @inline(never)
    public static func consume<T>(_ value: T) {
        withUnsafeBytes(of: value) { buffer in
            _ = buffer.count
        }
    }
}
