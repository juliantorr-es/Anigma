//
//  CoreMLVerificationDemo.swift
//  ModelRegistry
//
//  Demonstration of the CoreML verification suite with example tests.
//

import Foundation

public struct CoreMLVerificationDemo {
    private let workDir: URL
    private let registry: any ModelRegistryProtocol
    
    public init(workDir: URL, registry: any ModelRegistryProtocol) {
        self.workDir = workDir
        self.registry = registry
    }
    
    /// Run a complete verification demo
    public func runDemo() async throws -> String {
        print("🚀 Starting CoreML Verification Demo")
        print("====================================\n")
        
        // Create pipeline
        let pipeline = CoreMLConversionPipeline(
            workDir: workDir,
            registry: registry
        )
        
        // Create verification suite
        let suite = CoreMLVerificationSuite(
            pipeline: pipeline,
            goldenTestsPath: workDir.appendingPathComponent("golden_tests"),
            baselinePath: workDir.appendingPathComponent("baselines"),
            resultsPath: workDir.appendingPathComponent("results")
        )
        
        // Example golden test specs (in real usage, these would be loaded from JSON)
        let goldenSpecs = [
            GoldenTestSpec(
                id: "test_bert_base_mlprogram",
                modelId: "bert-base-uncased",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndNeuralEngine,
                quantization: .int8,
                expectedOutputHash: "dummy_hash_for_demo",
                expectedPlacement: "ANE",
                description: "BERT base model with INT8 quantization"
            ),
            GoldenTestSpec(
                id: "test_clip_fp16",
                modelId: "clip-vit-base-patch32",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndGPU,
                quantization: .fp16,
                expectedOutputHash: "dummy_hash_for_demo",
                expectedPlacement: "GPU",
                description: "CLIP model with FP16 quantization"
            )
        ]
        
        print("1. Running Golden Tests...")
        let goldenResults = await suite.runGoldenTests(goldenSpecs)
        print("   ✅ Golden tests completed: \(goldenResults.filter { $0.isSuccess }.count)/\(goldenResults.count) passed\n")
        
        // Example performance benchmarks
        let benchmarks = [
            PerformanceBenchmark(
                id: "benchmark_bert_ane",
                modelId: "bert-base-uncased",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndNeuralEngine,
                quantization: .int8,
                iterations: 5,
                warmupIterations: 2,
                expectedThroughput: 0.5, // 0.5 conversions per second
                maxLatency: 30.0 // 30 seconds max
            ),
            PerformanceBenchmark(
                id: "benchmark_bert_cpu",
                modelId: "bert-base-uncased",
                targetFormat: .mlprogram,
                computeUnits: .cpuOnly,
                quantization: .int8,
                iterations: 3,
                warmupIterations: 1,
                expectedThroughput: 0.2, // 0.2 conversions per second
                maxLatency: 60.0 // 60 seconds max
            )
        ]
        
        print("2. Running Performance Benchmarks...")
        let performanceMetrics = await suite.runPerformanceBenchmarks(
            benchmarks,
            hardwareTargets: [.ane, .cpu]
        )
        print("   ✅ Performance benchmarks completed: \(performanceMetrics.count) benchmarks\n")
        
        // Save baseline for regression detection
        print("3. Saving Performance Baseline...")
        try await suite.savePerformanceBaseline(performanceMetrics, name: "demo_baseline")
        print("   ✅ Baseline saved\n")
        
        // Example determinism tests
        let determinismTests = [
            DeterminismTest(
                id: "determinism_bert",
                modelId: "bert-base-uncased",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndNeuralEngine,
                quantization: .int8,
                runs: 3,
                requireExactMatch: true
            )
        ]
        
        print("4. Running Determinism Tests...")
        let determinismResults = await suite.runDeterminismTests(determinismTests)
        print("   ✅ Determinism tests completed: \(determinismResults.filter { $0.isSuccess }.count)/\(determinismResults.count) passed\n")
        
        // Example regression detection (using current metrics as both baseline and current)
        print("5. Running Regression Detection...")
        let regressionReports = try await suite.detectRegressions(
            currentMetrics: performanceMetrics,
            baselineName: "demo_baseline",
            thresholds: RegressionThresholds(
                maxPerformanceRegression: 10.0,
                maxMemoryIncrease: 15.0,
                maxAccuracyRegression: 1.0,
                minThroughput: 0.1
            )
        )
        
        let regressionFailures = regressionReports.filter { $0.verdict == .fail }.count
        let regressionWarnings = regressionReports.filter { $0.verdict == .warning }.count
        print("   ✅ Regression detection completed: \(regressionFailures) failures, \(regressionWarnings) warnings\n")
        
        // Generate comprehensive report
        print("6. Generating Verification Report...")
        let report = suite.generateVerificationReport(
            goldenResults: goldenResults,
            performanceMetrics: performanceMetrics,
            determinismResults: determinismResults,
            regressionReports: regressionReports
        )
        
        // Save report
        let reportName = "verification_demo_\(Date().timeIntervalSince1970)"
        try await suite.saveVerificationReport(report, name: reportName)
        
        print("7. Demo Complete!")
        print("=================\n")
        print("📋 Summary:")
        print("   - Golden Tests: \(goldenResults.filter { $0.isSuccess }.count)/\(goldenResults.count) passed")
        print("   - Performance Benchmarks: \(performanceMetrics.count) executed")
        print("   - Determinism Tests: \(determinismResults.filter { $0.isSuccess }.count)/\(determinismResults.count) passed")
        print("   - Regression Detection: \(regressionFailures) failures, \(regressionWarnings) warnings")
        print("\n📄 Report saved to: \(workDir.appendingPathComponent("results/\(reportName)_report.md").path)")
        
        return report
    }
    
    /// Create example golden test configuration file
    public func createExampleGoldenTestConfig() throws -> URL {
        let config = [
            GoldenTestSpec(
                id: "example_bert_int8",
                modelId: "bert-base-uncased",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndNeuralEngine,
                quantization: .int8,
                minOSVersion: "macos15",
                expectedOutputHash: "REPLACE_WITH_ACTUAL_HASH",
                expectedPlacement: "ANE",
                tolerance: 0.0,
                description: "BERT base model with INT8 quantization for ANE"
            ),
            GoldenTestSpec(
                id: "example_clip_fp16",
                modelId: "clip-vit-base-patch32",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndGPU,
                quantization: .fp16,
                minOSVersion: "macos15",
                expectedOutputHash: "REPLACE_WITH_ACTUAL_HASH",
                expectedPlacement: "GPU",
                tolerance: 0.0,
                description: "CLIP vision model with FP16 quantization for GPU"
            ),
            GoldenTestSpec(
                id: "example_llama_fp16",
                modelId: "llama-2-7b",
                targetFormat: .mlprogram,
                computeUnits: .all,
                quantization: .fp16,
                minOSVersion: "macos15",
                expectedOutputHash: "REPLACE_WITH_ACTUAL_HASH",
                expectedPlacement: "CPU+GPU",
                tolerance: 0.0,
                description: "LLaMA 2 7B model with FP16 quantization"
            )
        ]
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        
        let file = workDir.appendingPathComponent("example_golden_tests.json")
        try data.write(to: file)
        
        return file
    }
    
    /// Create example performance benchmark configuration
    public func createExampleBenchmarkConfig() throws -> URL {
        let config = [
            PerformanceBenchmark(
                id: "benchmark_bert_int8_ane",
                modelId: "bert-base-uncased",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndNeuralEngine,
                quantization: .int8,
                iterations: 10,
                warmupIterations: 2,
                expectedThroughput: 0.5,
                maxLatency: 30.0,
                memoryBudget: 2 * 1024 * 1024 * 1024 // 2GB
            ),
            PerformanceBenchmark(
                id: "benchmark_clip_fp16_gpu",
                modelId: "clip-vit-base-patch32",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndGPU,
                quantization: .fp16,
                iterations: 8,
                warmupIterations: 2,
                expectedThroughput: 0.3,
                maxLatency: 45.0,
                memoryBudget: 4 * 1024 * 1024 * 1024 // 4GB
            ),
            PerformanceBenchmark(
                id: "benchmark_llama_fp16_all",
                modelId: "llama-2-7b",
                targetFormat: .mlprogram,
                computeUnits: .all,
                quantization: .fp16,
                iterations: 3,
                warmupIterations: 1,
                expectedThroughput: 0.05,
                maxLatency: 300.0,
                memoryBudget: 16 * 1024 * 1024 * 1024 // 16GB
            )
        ]
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        
        let file = workDir.appendingPathComponent("example_benchmarks.json")
        try data.write(to: file)
        
        return file
    }
    
    /// Create example determinism test configuration
    public func createExampleDeterminismConfig() throws -> URL {
        let config = [
            DeterminismTest(
                id: "determinism_bert_int8",
                modelId: "bert-base-uncased",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndNeuralEngine,
                quantization: .int8,
                runs: 5,
                requireExactMatch: true,
                tolerance: 0.0
            ),
            DeterminismTest(
                id: "determinism_clip_fp16",
                modelId: "clip-vit-base-patch32",
                targetFormat: .mlprogram,
                computeUnits: .cpuAndGPU,
                quantization: .fp16,
                runs: 5,
                requireExactMatch: true,
                tolerance: 0.0
            )
        ]
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        
        let file = workDir.appendingPathComponent("example_determinism_tests.json")
        try data.write(to: file)
        
        return file
    }
}

// MARK: - CLI Integration

public struct VerificationCLI {
    private let workDir: URL
    
    public init(workDir: URL = URL(fileURLWithPath: "/tmp/coreml_verification")) {
        self.workDir = workDir
    }
    
    /// Run verification from command line
    public func runVerification(
        goldenTestsFile: URL? = nil,
        benchmarksFile: URL? = nil,
        determinismFile: URL? = nil,
        baselineName: String? = nil
    ) async throws {
        print("🔍 CoreML Verification Suite")
        print("===========================\n")
        
        // Create registry (in-memory for demo)
        let registry = InMemoryCoreMLRegistry()
        
        // Create demo instance
        let demo = CoreMLVerificationDemo(workDir: workDir, registry: registry)
        
        // Check for configuration files
        if goldenTestsFile == nil && benchmarksFile == nil && determinismFile == nil {
            print("ℹ️  No configuration files provided. Running demo with example tests.\n")
            
            // Create example configs
            let goldenFile = try demo.createExampleGoldenTestConfig()
            let benchmarkFile = try demo.createExampleBenchmarkConfig()
            let determinismFile = try demo.createExampleDeterminismConfig()
            
            print("📁 Created example configuration files:")
            print("   - Golden tests: \(goldenFile.path)")
            print("   - Benchmarks: \(benchmarkFile.path)")
            print("   - Determinism tests: \(determinismFile.path)\n")
            
            print("⚠️  Note: These are example configurations.")
            print("   Update the expected hashes with actual values from successful conversions.\n")
        }
        
        // Run the demo
        let report = try await demo.runDemo()
        
        print("\n📊 Verification Complete!")
        print("========================")
        print(report)
    }
    
    /// Generate configuration templates
    public func generateTemplates() throws {
        let demo = CoreMLVerificationDemo(
            workDir: workDir,
            registry: InMemoryCoreMLRegistry()
        )
        
        let goldenFile = try demo.createExampleGoldenTestConfig()
        let benchmarkFile = try demo.createExampleBenchmarkConfig()
        let determinismFile = try demo.createExampleDeterminismConfig()
        
        print("✅ Configuration templates generated:")
        print("   - Golden tests: \(goldenFile.path)")
        print("   - Benchmarks: \(benchmarkFile.path)")
        print("   - Determinism tests: \(determinismFile.path)")
        print("\n📝 Edit these files with your actual model IDs and expected values.")
    }
}

// MARK: - Example Usage

/*
 Command-line usage example:

 // Create verification CLI
 let cli = VerificationCLI(workDir: URL(fileURLWithPath: "/tmp/my_verification"))
 
 // Run verification
 try await cli.runVerification()
 
 // Or generate templates
 try cli.generateTemplates()
 
 // Or run with specific configuration files
 try await cli.runVerification(
     goldenTestsFile: URL(fileURLWithPath: "/path/to/golden_tests.json"),
     benchmarksFile: URL(fileURLWithPath: "/path/to/benchmarks.json"),
     determinismFile: URL(fileURLWithPath: "/path/to/determinism_tests.json"),
     baselineName: "v1.0.0"
 )
 */