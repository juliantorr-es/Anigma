//
//  CoreMLVerificationSuite.swift
//  ModelRegistry
//
//  Comprehensive verification suite for CoreML conversion pipeline.
//  Includes golden tests, performance benchmarking, determinism testing,
//  and regression detection.
//

import Foundation

// MARK: - Verification Types

public enum VerificationResult: Sendable {
    case success(VerificationDetails)
    case failure(VerificationError)
    
    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}

public struct VerificationDetails: Sendable {
    public let testName: String
    public let duration: TimeInterval
    public let metrics: [String: Double]
    public let metadata: [String: String]
    
    public init(
        testName: String,
        duration: TimeInterval,
        metrics: [String: Double] = [:],
        metadata: [String: String] = [:]
    ) {
        self.testName = testName
        self.duration = duration
        self.metrics = metrics
        self.metadata = metadata
    }
}

public struct VerificationError: Error, Sendable {
    public let testName: String
    public let error: String
    public let details: [String: String]
    
    public init(
        testName: String,
        error: String,
        details: [String: String] = [:]
    ) {
        self.testName = testName
        self.error = error
        self.details = details
    }
}

public struct GoldenTestSpec: Codable, Sendable {
    public let id: String
    public let modelId: String
    public let targetFormat: CoreMLFormat
    public let computeUnits: CoreMLComputeUnits
    public let quantization: CoreMLQuantization?
    public let minOSVersion: String
    public let expectedOutputHash: String
    public let expectedPlacement: String?
    public let tolerance: Double
    public let description: String
    
    public init(
        id: String,
        modelId: String,
        targetFormat: CoreMLFormat = .mlprogram,
        computeUnits: CoreMLComputeUnits = .all,
        quantization: CoreMLQuantization? = nil,
        minOSVersion: String = "macos15",
        expectedOutputHash: String,
        expectedPlacement: String? = nil,
        tolerance: Double = 0.0,
        description: String = ""
    ) {
        self.id = id
        self.modelId = modelId
        self.targetFormat = targetFormat
        self.computeUnits = computeUnits
        self.quantization = quantization
        self.minOSVersion = minOSVersion
        self.expectedOutputHash = expectedOutputHash
        self.expectedPlacement = expectedPlacement
        self.tolerance = tolerance
        self.description = description
    }
}

public struct PerformanceBenchmark: Codable, Sendable {
    public let id: String
    public let modelId: String
    public let targetFormat: CoreMLFormat
    public let computeUnits: CoreMLComputeUnits
    public let quantization: CoreMLQuantization?
    public let iterations: Int
    public let warmupIterations: Int
    public let expectedThroughput: Double? // conversions per second
    public let maxLatency: TimeInterval? // seconds
    public let memoryBudget: Int64? // bytes
    
    public init(
        id: String,
        modelId: String,
        targetFormat: CoreMLFormat = .mlprogram,
        computeUnits: CoreMLComputeUnits = .all,
        quantization: CoreMLQuantization? = nil,
        iterations: Int = 10,
        warmupIterations: Int = 2,
        expectedThroughput: Double? = nil,
        maxLatency: TimeInterval? = nil,
        memoryBudget: Int64? = nil
    ) {
        self.id = id
        self.modelId = modelId
        self.targetFormat = targetFormat
        self.computeUnits = computeUnits
        self.quantization = quantization
        self.iterations = iterations
        self.warmupIterations = warmupIterations
        self.expectedThroughput = expectedThroughput
        self.maxLatency = maxLatency
        self.memoryBudget = memoryBudget
    }
}

public struct DeterminismTest: Codable, Sendable {
    public let id: String
    public let modelId: String
    public let targetFormat: CoreMLFormat
    public let computeUnits: CoreMLComputeUnits
    public let quantization: CoreMLQuantization?
    public let runs: Int
    public let requireExactMatch: Bool
    public let tolerance: Double
    
    public init(
        id: String,
        modelId: String,
        targetFormat: CoreMLFormat = .mlprogram,
        computeUnits: CoreMLComputeUnits = .all,
        quantization: CoreMLQuantization? = nil,
        runs: Int = 5,
        requireExactMatch: Bool = true,
        tolerance: Double = 0.0
    ) {
        self.id = id
        self.modelId = modelId
        self.targetFormat = targetFormat
        self.computeUnits = computeUnits
        self.quantization = quantization
        self.runs = runs
        self.requireExactMatch = requireExactMatch
        self.tolerance = tolerance
    }
}

// MARK: - CoreML Performance Metrics

public struct CoreMLPerformanceMetrics: Sendable {
    public let minLatency: TimeInterval
    public let maxLatency: TimeInterval
    public let meanLatency: TimeInterval
    public let p50Latency: TimeInterval
    public let p95Latency: TimeInterval
    public let p99Latency: TimeInterval
    public let throughput: Double // conversions per second
    public let memoryUsage: Int64 // peak memory in bytes
    public let cpuUsage: Double // percentage
    
    public init(
        minLatency: TimeInterval,
        maxLatency: TimeInterval,
        meanLatency: TimeInterval,
        p50Latency: TimeInterval,
        p95Latency: TimeInterval,
        p99Latency: TimeInterval,
        throughput: Double,
        memoryUsage: Int64,
        cpuUsage: Double
    ) {
        self.minLatency = minLatency
        self.maxLatency = maxLatency
        self.meanLatency = meanLatency
        self.p50Latency = p50Latency
        self.p95Latency = p95Latency
        self.p99Latency = p99Latency
        self.throughput = throughput
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
    }
}

// MARK: - Hardware Target

public enum HardwareTarget: String, Codable, Sendable, CaseIterable {
    case cpu = "cpu"
    case gpu = "gpu"
    case ane = "ane"
    case all = "all"
    
    public var computeUnits: CoreMLComputeUnits {
        switch self {
        case .cpu: return .cpuOnly
        case .gpu: return .cpuAndGPU
        case .ane: return .cpuAndNeuralEngine
        case .all: return .all
        }
    }
}

// MARK: - Regression Detection

public struct RegressionThresholds: Sendable {
    public let maxPerformanceRegression: Double // percentage
    public let maxMemoryIncrease: Double // percentage
    public let maxAccuracyRegression: Double // percentage
    public let minThroughput: Double // conversions per second
    
    public init(
        maxPerformanceRegression: Double = 10.0,
        maxMemoryIncrease: Double = 15.0,
        maxAccuracyRegression: Double = 1.0,
        minThroughput: Double = 0.5
    ) {
        self.maxPerformanceRegression = maxPerformanceRegression
        self.maxMemoryIncrease = maxMemoryIncrease
        self.maxAccuracyRegression = maxAccuracyRegression
        self.minThroughput = minThroughput
    }
}

public struct RegressionReport: Sendable {
    public let testId: String
    public let modelId: String
    public let baselineMetrics: CoreMLPerformanceMetrics?
    public let currentMetrics: CoreMLPerformanceMetrics
    public let regressionPercentage: Double
    public let thresholds: RegressionThresholds
    public let verdict: RegressionVerdict
    public let details: [String: String]
    
    public enum RegressionVerdict: Sendable {
        case pass
        case warning
        case fail
    }
}

// MARK: - Baseline Entry

private struct BaselineEntry: Codable {
    let key: String
    let metrics: CoreMLPerformanceMetrics
    let timestamp: Date
}

// MARK: - CoreML Verification Suite

public actor CoreMLVerificationSuite {
    private let pipeline: CoreMLConversionPipeline
    private let goldenTestsPath: URL
    private let baselinePath: URL
    private let resultsPath: URL
    private let logger: CoreMLConversionLogger
    
    public init(
        pipeline: CoreMLConversionPipeline,
        goldenTestsPath: URL,
        baselinePath: URL,
        resultsPath: URL,
        logger: CoreMLConversionLogger = DefaultCoreMLConversionLogger()
    ) {
        self.pipeline = pipeline
        self.goldenTestsPath = goldenTestsPath
        self.baselinePath = baselinePath
        self.resultsPath = resultsPath
        self.logger = logger
        
        // Ensure directories exist
        try? FileManager.default.createDirectory(at: goldenTestsPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: baselinePath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: resultsPath, withIntermediateDirectories: true)
    }
    
    // MARK: - Golden Tests
    
    /// Run golden tests to verify conversion correctness
    public func runGoldenTests(_ specs: [GoldenTestSpec]) async -> [VerificationResult] {
        var results: [VerificationResult] = []
        
        for spec in specs {
            let startTime = Date()
            
            do {
                logger.logConversionStart(modelId: spec.modelId, targetFormat: spec.targetFormat, quantization: spec.quantization)
                
                let receipt = try await pipeline.convertToCoreML(
                    modelId: spec.modelId,
                    targetFormat: spec.targetFormat,
                    computeUnits: spec.computeUnits,
                    quantization: spec.quantization,
                    minOSVersion: spec.minOSVersion,
                    calibrationData: nil,
                    skipCache: true, // Force fresh conversion for golden tests
                    storeInRegistry: false
                )
                
                // Verify output hash
                let outputHash = receipt.outputHashes.values.first ?? ""
                if outputHash != spec.expectedOutputHash {
                    let error = VerificationError(
                        testName: spec.id,
                        error: "Output hash mismatch",
                        details: [
                            "expected": spec.expectedOutputHash,
                            "actual": outputHash,
                            "tolerance": String(spec.tolerance)
                        ]
                    )
                    results.append(.failure(error))
                    continue
                }
                
                // Verify placement if specified
                if let expectedPlacement = spec.expectedPlacement {
                    let actualPlacement = receipt.placementAnalysis.likelyPlacement
                    if actualPlacement != expectedPlacement {
                        let error = VerificationError(
                            testName: spec.id,
                            error: "Placement analysis mismatch",
                            details: [
                                "expected": expectedPlacement,
                                "actual": actualPlacement
                            ]
                        )
                        results.append(.failure(error))
                        continue
                    }
                }
                
                let duration = Date().timeIntervalSince(startTime)
                let details = VerificationDetails(
                    testName: spec.id,
                    duration: duration,
                    metrics: ["hash_match": 1.0],
                    metadata: [
                        "model_id": spec.modelId,
                        "output_hash": outputHash,
                        "placement": receipt.placementAnalysis.likelyPlacement
                    ]
                )
                
                results.append(.success(details))
                
            } catch {
                let verificationError = VerificationError(
                    testName: spec.id,
                    error: "Conversion failed: \(error.localizedDescription)",
                    details: ["model_id": spec.modelId]
                )
                results.append(.failure(verificationError))
            }
        }
        
        return results
    }
    
    /// Load golden test specs from JSON file
    public func loadGoldenTests(from file: URL) async throws -> [GoldenTestSpec] {
        let data = try Data(contentsOf: file)
        let decoder = JSONDecoder()
        return try decoder.decode([GoldenTestSpec].self, from: data)
    }
    
    /// Save golden test results
    public func saveGoldenTestResults(_ results: [VerificationResult], to file: URL) async throws {
        struct ResultSummary: Codable {
            let testName: String
            let success: Bool
            let duration: TimeInterval?
            let error: String?
            let metrics: [String: Double]?
        }
        
        let summaries = results.map { result -> ResultSummary in
            switch result {
            case .success(let details):
                return ResultSummary(
                    testName: details.testName,
                    success: true,
                    duration: details.duration,
                    error: nil,
                    metrics: details.metrics
                )
            case .failure(let error):
                return ResultSummary(
                    testName: error.testName,
                    success: false,
                    duration: nil,
                    error: error.error,
                    metrics: nil
                )
            }
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(summaries)
        try data.write(to: file)
    }
    
    // MARK: - Performance Benchmarking
    
    /// Run performance benchmarks across different hardware targets
    public func runPerformanceBenchmarks(
        _ benchmarks: [PerformanceBenchmark],
        hardwareTargets: [HardwareTarget] = HardwareTarget.allCases
    ) async -> [String: CoreMLPerformanceMetrics] {
        var results: [String: CoreMLPerformanceMetrics] = [:]
        
        for benchmark in benchmarks {
            for target in hardwareTargets {
                let key = "\(benchmark.id)_\(target.rawValue)"
                
                do {
                    let metrics = try await runSingleBenchmark(
                        benchmark: benchmark,
                        hardwareTarget: target
                    )
                    
                    results[key] = metrics
                    
                    // Check against thresholds
                    if let expectedThroughput = benchmark.expectedThroughput {
                        if metrics.throughput < expectedThroughput {
                            logger.logConversionError(
                                modelId: benchmark.modelId,
                                error: CoreMLConversionError.conversionFailed(
                                    "Throughput below expected: \(metrics.throughput) < \(expectedThroughput)"
                                )
                            )
                        }
                    }
                    
                    if let maxLatency = benchmark.maxLatency {
                        if metrics.p95Latency > maxLatency {
                            logger.logConversionError(
                                modelId: benchmark.modelId,
                                error: CoreMLConversionError.conversionFailed(
                                    "Latency above threshold: \(metrics.p95Latency) > \(maxLatency)"
                                )
                            )
                        }
                    }
                    
                } catch {
                    logger.logConversionError(
                        modelId: benchmark.modelId,
                        error: error
                    )
                }
            }
        }
        
        return results
    }
    
    private func runSingleBenchmark(
        benchmark: PerformanceBenchmark,
        hardwareTarget: HardwareTarget
    ) async throws -> CoreMLPerformanceMetrics {
        var latencies: [TimeInterval] = []
        var memoryReadings: [Int64] = []
        
        // Warmup iterations
        for _ in 0..<benchmark.warmupIterations {
            _ = try await pipeline.convertToCoreML(
                modelId: benchmark.modelId,
                targetFormat: benchmark.targetFormat,
                computeUnits: hardwareTarget.computeUnits,
                quantization: benchmark.quantization,
                minOSVersion: "macos15",
                calibrationData: nil,
                skipCache: true,
                storeInRegistry: false
            )
        }
        
        // Actual benchmark iterations
        for _ in 0..<benchmark.iterations {
            let startTime = Date()
            
            _ = try await pipeline.convertToCoreML(
                modelId: benchmark.modelId,
                targetFormat: benchmark.targetFormat,
                computeUnits: hardwareTarget.computeUnits,
                quantization: benchmark.quantization,
                minOSVersion: "macos15",
                calibrationData: nil,
                skipCache: true,
                storeInRegistry: false
            )
            
            let latency = Date().timeIntervalSince(startTime)
            latencies.append(latency)
            
            // Simulate memory reading (in real implementation, use ProcessInfo or mach APIs)
            let memoryUsage = getCurrentMemoryUsage()
            memoryReadings.append(memoryUsage)
        }
        
        // Calculate statistics
        let sortedLatencies = latencies.sorted()
        let minLatency = sortedLatencies.first ?? 0
        let maxLatency = sortedLatencies.last ?? 0
        let meanLatency = sortedLatencies.reduce(0, +) / Double(sortedLatencies.count)
        let p50Index = Int(Double(sortedLatencies.count) * 0.5)
        let p95Index = Int(Double(sortedLatencies.count) * 0.95)
        let p99Index = Int(Double(sortedLatencies.count) * 0.99)
        
        let p50Latency = sortedLatencies[p50Index]
        let p95Latency = sortedLatencies[p95Index]
        let p99Latency = sortedLatencies[min(p99Index, sortedLatencies.count - 1)]
        
        let throughput = 1.0 / meanLatency
        let peakMemory = memoryReadings.max() ?? 0
        
        // Simulate CPU usage (in real implementation, use host_statistics64)
        let cpuUsage = 0.0
        
        return CoreMLPerformanceMetrics(
            minLatency: minLatency,
            maxLatency: maxLatency,
            meanLatency: meanLatency,
            p50Latency: p50Latency,
            p95Latency: p95Latency,
            p99Latency: p99Latency,
            throughput: throughput,
            memoryUsage: peakMemory,
            cpuUsage: cpuUsage
        )
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        // In a real implementation, this would use mach APIs or ProcessInfo
        // For now, return a simulated value
        return 100 * 1024 * 1024 // 100 MB
    }
    
    /// Save performance baseline for regression detection
    public func savePerformanceBaseline(
        _ metrics: [String: CoreMLPerformanceMetrics],
        name: String
    ) async throws {
        let entries = metrics.map { key, metrics in
            BaselineEntry(key: key, metrics: metrics, timestamp: Date())
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(entries)
        
        let file = baselinePath.appendingPathComponent("\(name)_baseline.json")
        try data.write(to: file)
    }
    
    /// Load performance baseline
    public func loadPerformanceBaseline(name: String) async throws -> [String: CoreMLPerformanceMetrics] {
        let file = baselinePath.appendingPathComponent("\(name)_baseline.json")
        
        guard FileManager.default.fileExists(atPath: file.path) else {
            return [:]
        }
        
        let data = try Data(contentsOf: file)
        let decoder = JSONDecoder()
        let entries = try decoder.decode([BaselineEntry].self, from: data)
        
        var metrics: [String: CoreMLPerformanceMetrics] = [:]
        for entry in entries {
            metrics[entry.key] = entry.metrics
        }
        
        return metrics
    }
    
    // MARK: - Determinism Testing
    
    /// Run determinism tests to ensure reproducible conversions
    public func runDeterminismTests(_ tests: [DeterminismTest]) async -> [VerificationResult] {
        var results: [VerificationResult] = []
        
        for test in tests {
            do {
                let hashes = try await runDeterminismTest(test)
                
                // Check if all hashes are identical
                let firstHash = hashes.first ?? ""
                let allMatch = hashes.allSatisfy { $0 == firstHash }
                
                if test.requireExactMatch && !allMatch {
                    let error = VerificationError(
                        testName: test.id,
                        error: "Non-deterministic conversion detected",
                        details: [
                            "runs": String(test.runs),
                            "unique_hashes": String(Set(hashes).count),
                            "tolerance": String(test.tolerance)
                        ]
                    )
                    results.append(.failure(error))
                } else {
                    let matchPercentage = Double(hashes.filter { $0 == firstHash }.count) / Double(hashes.count)
                    let details = VerificationDetails(
                        testName: test.id,
                        duration: 0.0, // Would calculate actual duration
                        metrics: ["determinism_score": matchPercentage],
                        metadata: [
                            "model_id": test.modelId,
                            "runs": String(test.runs),
                            "unique_hashes": String(Set(hashes).count)
                        ]
                    )
                    results.append(.success(details))
                }
                
            } catch {
                let verificationError = VerificationError(
                    testName: test.id,
                    error: "Determinism test failed: \(error.localizedDescription)",
                    details: ["model_id": test.modelId]
                )
                results.append(.failure(verificationError))
            }
        }
        
        return results
    }
    
    private func runDeterminismTest(_ test: DeterminismTest) async throws -> [String] {
        var hashes: [String] = []
        
        for _ in 0..<test.runs {
            let receipt = try await pipeline.convertToCoreML(
                modelId: test.modelId,
                targetFormat: test.targetFormat,
                computeUnits: test.computeUnits,
                quantization: test.quantization,
                minOSVersion: "macos15",
                calibrationData: nil,
                skipCache: true, // Important: don't use cache for determinism tests
                storeInRegistry: false
            )
            
            let outputHash = receipt.outputHashes.values.first ?? ""
            hashes.append(outputHash)
        }
        
        return hashes
    }
    
    // MARK: - Regression Detection
    
    /// Detect performance regressions against baseline
    public func detectRegressions(
        currentMetrics: [String: CoreMLPerformanceMetrics],
        baselineName: String,
        thresholds: RegressionThresholds = RegressionThresholds()
    ) async throws -> [RegressionReport] {
        let baseline = try await loadPerformanceBaseline(name: baselineName)
        var reports: [RegressionReport] = []
        
        for (key, current) in currentMetrics {
            guard let baseline = baseline[key] else {
                // No baseline for this key
                continue
            }
            
            // Calculate regression percentages
            let latencyRegression = ((current.meanLatency - baseline.meanLatency) / baseline.meanLatency) * 100
            let memoryIncrease = ((Double(current.memoryUsage) - Double(baseline.memoryUsage)) / Double(baseline.memoryUsage)) * 100
            let throughputRegression = ((baseline.throughput - current.throughput) / baseline.throughput) * 100
            
            // Determine verdict
            let verdict: RegressionReport.RegressionVerdict
            if latencyRegression > thresholds.maxPerformanceRegression ||
               memoryIncrease > thresholds.maxMemoryIncrease ||
               current.throughput < thresholds.minThroughput {
                verdict = .fail
            } else if latencyRegression > thresholds.maxPerformanceRegression * 0.5 ||
                      memoryIncrease > thresholds.maxMemoryIncrease * 0.5 {
                verdict = .warning
            } else {
                verdict = .pass
            }
            
            let report = RegressionReport(
                testId: key,
                modelId: extractModelId(from: key),
                baselineMetrics: baseline,
                currentMetrics: current,
                regressionPercentage: max(latencyRegression, throughputRegression),
                thresholds: thresholds,
                verdict: verdict,
                details: [
                    "latency_regression": String(format: "%.2f%%", latencyRegression),
                    "memory_increase": String(format: "%.2f%%", memoryIncrease),
                    "throughput_regression": String(format: "%.2f%%", throughputRegression)
                ]
            )
            
            reports.append(report)
        }
        
        return reports
    }
    
    private func extractModelId(from key: String) -> String {
        // Extract model ID from key (format: "benchmark_id_hardware")
        let components = key.split(separator: "_")
        return String(components.first ?? "unknown")
    }
    
    // MARK: - Report Generation
    
    /// Generate comprehensive verification report
    public func generateVerificationReport(
        goldenResults: [VerificationResult],
        performanceMetrics: [String: CoreMLPerformanceMetrics],
        determinismResults: [VerificationResult],
        regressionReports: [RegressionReport]
    ) -> String {
        var report = "# CoreML Verification Report\n\n"
        report += "Generated: \(Date())\n\n"
        
        // Golden Tests Summary
        report += "## Golden Tests\n\n"
        let goldenSuccess = goldenResults.filter { $0.isSuccess }.count
        let goldenTotal = goldenResults.count
        report += "**\(goldenSuccess)/\(goldenTotal)** tests passed\n\n"
        
        for result in goldenResults {
            switch result {
            case .success(let details):
                report += "✅ **\(details.testName)**: \(String(format: "%.2f", details.duration))s\n"
            case .failure(let error):
                report += "❌ **\(error.testName)**: \(error.error)\n"
            }
        }
        
        // Performance Summary
        report += "\n## Performance Benchmarks\n\n"
        report += "**\(performanceMetrics.count)** benchmarks executed\n\n"
        
        for (key, metrics) in performanceMetrics {
            report += "### \(key)\n"
            report += "- Mean Latency: \(String(format: "%.3f", metrics.meanLatency))s\n"
            report += "- Throughput: \(String(format: "%.2f", metrics.throughput)) conversions/s\n"
            report += "- Peak Memory: \(formatBytes(metrics.memoryUsage))\n"
            report += "- p95 Latency: \(String(format: "%.3f", metrics.p95Latency))s\n\n"
        }
        
        // Determinism Summary
        report += "## Determinism Tests\n\n"
        let determinismSuccess = determinismResults.filter { $0.isSuccess }.count
        let determinismTotal = determinismResults.count
        report += "**\(determinismSuccess)/\(determinismTotal)** tests passed\n\n"
        
        // Regression Summary
        report += "## Regression Detection\n\n"
        let regressionFailures = regressionReports.filter { $0.verdict == .fail }.count
        let regressionWarnings = regressionReports.filter { $0.verdict == .warning }.count
        report += "**\(regressionFailures)** failures, **\(regressionWarnings)** warnings\n\n"
        
        for regression in regressionReports {
            let emoji = regression.verdict == .fail ? "❌" : (regression.verdict == .warning ? "⚠️" : "✅")
            report += "\(emoji) **\(regression.testId)**: \(String(format: "%.1f", regression.regressionPercentage))% regression\n"
        }
        
        return report
    }
    
    /// Save verification report to file
    public func saveVerificationReport(_ report: String, name: String) async throws {
        let file = resultsPath.appendingPathComponent("\(name)_report.md")
        try report.write(to: file, atomically: true, encoding: .utf8)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.2f %@", size, units[unitIndex])
    }
}

// MARK: - Codable Conformance for CoreMLPerformanceMetrics

extension CoreMLPerformanceMetrics: Codable {
    private enum CodingKeys: String, CodingKey {
        case minLatency
        case maxLatency
        case meanLatency
        case p50Latency
        case p95Latency
        case p99Latency
        case throughput
        case memoryUsage
        case cpuUsage
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minLatency = try container.decode(TimeInterval.self, forKey: .minLatency)
        maxLatency = try container.decode(TimeInterval.self, forKey: .maxLatency)
        meanLatency = try container.decode(TimeInterval.self, forKey: .meanLatency)
        p50Latency = try container.decode(TimeInterval.self, forKey: .p50Latency)
        p95Latency = try container.decode(TimeInterval.self, forKey: .p95Latency)
        p99Latency = try container.decode(TimeInterval.self, forKey: .p99Latency)
        throughput = try container.decode(Double.self, forKey: .throughput)
        memoryUsage = try container.decode(Int64.self, forKey: .memoryUsage)
        cpuUsage = try container.decode(Double.self, forKey: .cpuUsage)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minLatency, forKey: .minLatency)
        try container.encode(maxLatency, forKey: .maxLatency)
        try container.encode(meanLatency, forKey: .meanLatency)
        try container.encode(p50Latency, forKey: .p50Latency)
        try container.encode(p95Latency, forKey: .p95Latency)
        try container.encode(p99Latency, forKey: .p99Latency)
        try container.encode(throughput, forKey: .throughput)
        try container.encode(memoryUsage, forKey: .memoryUsage)
        try container.encode(cpuUsage, forKey: .cpuUsage)
    }
}

// MARK: - Example Usage

/*
 Example of using the CoreMLVerificationSuite:

 let workDir = URL(fileURLWithPath: "/tmp/coreml_verification")
 let registry = InMemoryCoreMLRegistry()
 let pipeline = CoreMLConversionPipeline(
     workDir: workDir,
     registry: registry
 )

 let suite = CoreMLVerificationSuite(
     pipeline: pipeline,
     goldenTestsPath: workDir.appendingPathComponent("golden_tests"),
     baselinePath: workDir.appendingPathComponent("baselines"),
     resultsPath: workDir.appendingPathComponent("results")
 )

 // Run golden tests
 let goldenSpecs = [
     GoldenTestSpec(
         id: "test_bert_base",
         modelId: "bert-base-uncased",
         expectedOutputHash: "abc123...",
         expectedPlacement: "ANE"
     )
 ]

 let goldenResults = await suite.runGoldenTests(goldenSpecs)

 // Run performance benchmarks
 let benchmarks = [
     PerformanceBenchmark(
         id: "benchmark_bert",
         modelId: "bert-base-uncased",
         iterations: 10
     )
 ]

 let performanceMetrics = await suite.runPerformanceBenchmarks(benchmarks)

 // Run determinism tests
 let determinismTests = [
     DeterminismTest(
         id: "determinism_bert",
         modelId: "bert-base-uncased",
         runs: 5
     )
 ]

 let determinismResults = await suite.runDeterminismTests(determinismTests)

 // Detect regressions
 let regressionReports = try await suite.detectRegressions(
     currentMetrics: performanceMetrics,
     baselineName: "v1.0.0"
 )

 // Generate report
 let report = suite.generateVerificationReport(
     goldenResults: goldenResults,
     performanceMetrics: performanceMetrics,
     determinismResults: determinismResults,
     regressionReports: regressionReports
 )

 try await suite.saveVerificationReport(report, name: "verification_run_1")
 */