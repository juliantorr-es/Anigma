import Foundation

/// Results from a capsule benchmark run.
public struct BenchmarkResults {
    /// Duration in nanoseconds.
    public let durationNanoseconds: UInt64
    /// Marshalling telemetry captured during the benchmark.
    public let telemetry: MarshallingTelemetry
    /// Whether the benchmark passed all budget checks.
    public let passedBudgets: Bool
    /// Violations found, if any.
    public let violations: [String]
    
    public init(
        durationNanoseconds: UInt64,
        telemetry: MarshallingTelemetry,
        passedBudgets: Bool,
        violations: [String]
    ) {
        self.durationNanoseconds = durationNanoseconds
        self.telemetry = telemetry
        self.passedBudgets = passedBudgets
        self.violations = violations
    }
}

/// Protocol for capsules that can be benchmarked.
public protocol CapsuleBenchmark {
    /// Name of the benchmark for reporting.
    static var benchmarkName: String { get }
    
    /// Optional setup before each iteration.
    func setUp() throws
    
    /// Run a single iteration of the benchmark.
    /// - Parameter telemetry: Telemetry object to record marshalling operations.
    /// - Returns: Result of the operation (can be discarded).
    func runIteration(telemetry: MarshallingTelemetry) throws -> Any
    
    /// Optional tear down after each iteration.
    func tearDown() throws
    
    /// Budgets to enforce for this benchmark.
    /// Defaults to `.strict` for performance-critical capsules.
    static var budgets: MarshallingBudgets { get }
}

extension CapsuleBenchmark {
    public func setUp() throws {}
    public func tearDown() throws {}
    
    public static var budgets: MarshallingBudgets {
        .strict
    }
    
    /// Run the benchmark for a given number of iterations.
    /// - Parameter iterations: Number of times to run the iteration (default 100).
    /// - Returns: Aggregated benchmark results.
    public func run(iterations: Int = 100) throws -> BenchmarkResults {
        let telemetry = MarshallingTelemetry()
        var totalDuration: UInt64 = 0
        var violations: [String] = []
        
        for _ in 0..<iterations {
            try setUp()
            telemetry.reset()
            
            let start = DispatchTime.now()
            _ = try runIteration(telemetry: telemetry)
            let end = DispatchTime.now()
            
            totalDuration += end.uptimeNanoseconds - start.uptimeNanoseconds
            try tearDown()
            
            let iterationViolations = telemetry.checkBudgets(Self.budgets)
            violations.append(contentsOf: iterationViolations)
        }
        
        let avgDuration = totalDuration / UInt64(iterations)
        let passed = violations.isEmpty
        
        return BenchmarkResults(
            durationNanoseconds: avgDuration,
            telemetry: telemetry,
            passedBudgets: passed,
            violations: violations
        )
    }
}

/// A benchmark that wraps a closure for ad‑hoc testing.
public struct ClosureBenchmark: CapsuleBenchmark {
    public static let benchmarkName = "ClosureBenchmark"
    private let iteration: (MarshallingTelemetry) throws -> Any
    
    public init(_ iteration: @escaping (MarshallingTelemetry) throws -> Any) {
        self.iteration = iteration
    }
    
    public func runIteration(telemetry: MarshallingTelemetry) throws -> Any {
        try iteration(telemetry)
    }
}

/// Runs a suite of capsule benchmarks and reports results.
public final class BenchmarkRunner {
    private let benchmarks: [any CapsuleBenchmark.Type]
    
    public init(benchmarks: [any CapsuleBenchmark.Type]) {
        self.benchmarks = benchmarks
    }
    
    /// Run all benchmarks and return a dictionary of results keyed by benchmark name.
    public func runAll(iterations: Int = 100) throws -> [String: BenchmarkResults] {
        var results: [String: BenchmarkResults] = [:]
        
        for benchmarkType in benchmarks {
            let instance = try createInstance(of: benchmarkType)
            let result = try instance.run(iterations: iterations)
            results[benchmarkType.benchmarkName] = result
        }
        
        return results
    }
    
    private func createInstance(of benchmarkType: any CapsuleBenchmark.Type) throws -> any CapsuleBenchmark {
        // Assume the benchmark type has a zero‑argument initializer.
        // This is a limitation; in practice each capsule should provide its own factory.
        if let type = benchmarkType as? any InstantiableCapsuleBenchmark.Type {
            return type.init()
        }
        fatalError("Benchmark type \(benchmarkType) must conform to InstantiableCapsuleBenchmark")
    }
}

/// Protocol for benchmarks that can be instantiated with a parameterless initializer.
public protocol InstantiableCapsuleBenchmark: CapsuleBenchmark {
    init()
}

/// Default budget definitions for common capsule categories.
extension MarshallingBudgets {
    /// Budget for vector/math capsules (high performance, zero string conversions).
    public static let vectorCapsule = MarshallingBudgets(
        maxABICalls: 5,
        maxStringConversions: 0,
        maxBytesCopied: 1024 * 1024,
        maxBufferAllocations: 2
    )
    
    /// Budget for search/ranking capsules (moderate ABI calls).
    public static let searchCapsule = MarshallingBudgets(
        maxABICalls: 20,
        maxStringConversions: 0,
        maxBytesCopied: 10 * 1024 * 1024,
        maxBufferAllocations: 5
    )
    
    /// Budget for compression capsules (many buffer allocations allowed).
    public static let compressionCapsule = MarshallingBudgets(
        maxABICalls: 10,
        maxStringConversions: 0,
        maxBytesCopied: 100 * 1024 * 1024,
        maxBufferAllocations: 20
    )
}