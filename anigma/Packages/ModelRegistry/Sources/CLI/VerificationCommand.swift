//
//  VerificationCommand.swift
//  ModelRegistryCLI
//
//  CLI command for running CoreML verification suite.
//

import Foundation
import ArgumentParser
import ModelRegistry

struct VerificationCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Run CoreML verification suite",
        subcommands: [
            RunCommand.self,
            GenerateCommand.self,
            ReportCommand.self
        ],
        defaultSubcommand: RunCommand.self
    )
}

// MARK: - Run Command

struct RunCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run verification tests"
    )
    
    @Option(name: .shortAndLong, help: "Golden tests configuration file")
    var goldenTests: String?
    
    @Option(name: .shortAndLong, help: "Performance benchmarks configuration file")
    var benchmarks: String?
    
    @Option(name: .shortAndLong, help: "Determinism tests configuration file")
    var determinism: String?
    
    @Option(name: .shortAndLong, help: "Baseline name for regression detection")
    var baseline: String?
    
    @Option(name: .shortAndLong, help: "Working directory")
    var workDir: String = "/tmp/coreml_verification"
    
    @Flag(name: .shortAndLong, help: "Generate example configs if none provided")
    var generateExamples: Bool = false
    
    mutating func run() async throws {
        print("🔍 CoreML Verification Suite")
        print("===========================\n")
        
        let workDirURL = URL(fileURLWithPath: workDir)
        
        // Create CLI instance
        let cli = VerificationCLI(workDir: workDirURL)
        
        // Convert string paths to URLs if provided
        let goldenTestsURL = goldenTests.map { URL(fileURLWithPath: $0) }
        let benchmarksURL = benchmarks.map { URL(fileURLWithPath: $0) }
        let determinismURL = determinism.map { URL(fileURLWithPath: $0) }
        
        if generateExamples && goldenTestsURL == nil && benchmarksURL == nil && determinismURL == nil {
            print("📝 Generating example configuration files...\n")
            try cli.generateTemplates()
            print()
        }
        
        try await cli.runVerification(
            goldenTestsFile: goldenTestsURL,
            benchmarksFile: benchmarksURL,
            determinismFile: determinismURL,
            baselineName: baseline
        )
    }
}

// MARK: - Generate Command

struct GenerateCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate configuration templates"
    )
    
    @Option(name: .shortAndLong, help: "Working directory")
    var workDir: String = "/tmp/coreml_verification"
    
    @Option(name: .shortAndLong, help: "Output directory (defaults to working directory)")
    var outputDir: String?
    
    mutating func run() async throws {
        print("📝 Generating CoreML Verification Configuration Templates")
        print("========================================================\n")
        
        let workDirURL = URL(fileURLWithPath: workDir)
        let outputDirURL = outputDir.map { URL(fileURLWithPath: $0) } ?? workDirURL
        
        // Create demo instance
        let registry = InMemoryCoreMLRegistry()
        let demo = CoreMLVerificationDemo(workDir: outputDirURL, registry: registry)
        
        // Generate templates
        let goldenFile = try demo.createExampleGoldenTestConfig()
        let benchmarkFile = try demo.createExampleBenchmarkConfig()
        let determinismFile = try demo.createExampleDeterminismConfig()
        
        print("✅ Configuration templates generated:")
        print()
        print("1. Golden Tests Configuration:")
        print("   File: \(goldenFile.path)")
        print("   Purpose: Defines expected outputs for model conversions")
        print("   Usage: Update 'expectedOutputHash' with actual hash from successful conversion")
        print()
        
        print("2. Performance Benchmarks Configuration:")
        print("   File: \(benchmarkFile.path)")
        print("   Purpose: Defines performance thresholds and test parameters")
        print("   Usage: Set 'expectedThroughput' and 'maxLatency' based on your requirements")
        print()
        
        print("3. Determinism Tests Configuration:")
        print("   File: \(determinismFile.path)")
        print("   Purpose: Ensures conversions are reproducible")
        print("   Usage: Set 'runs' to number of repetitions (typically 3-5)")
        print()
        
        print("📋 Next Steps:")
        print("   1. Run conversions to get actual output hashes")
        print("   2. Update golden test configs with real hashes")
        print("   3. Run baseline performance tests")
        print("   4. Use verification in CI/CD pipeline")
        print()
        
        print("🚀 To run verification with these templates:")
        print("   model-registry verify run --generate-examples")
    }
}

// MARK: - Report Command

struct ReportCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "report",
        abstract: "Generate verification report from results"
    )
    
    @Option(name: .shortAndLong, help: "Results directory")
    var resultsDir: String = "/tmp/coreml_verification/results"
    
    @Option(name: .shortAndLong, help: "Report name (without extension)")
    var name: String?
    
    @Flag(name: .shortAndLong, help: "List available reports")
    var list: Bool = false
    
    mutating func run() async throws {
        let resultsDirURL = URL(fileURLWithPath: resultsDir)
        
        if list {
            try listReports(in: resultsDirURL)
            return
        }
        
        guard let name = name else {
            print("❌ Please specify a report name with --name")
            print("   Or use --list to see available reports")
            throw ValidationError("Report name required")
        }
        
        let reportFile = resultsDirURL.appendingPathComponent("\(name)_report.md")
        
        guard FileManager.default.fileExists(atPath: reportFile.path) else {
            print("❌ Report not found: \(reportFile.path)")
            print("   Use --list to see available reports")
            throw ValidationError("Report file not found")
        }
        
        let reportContent = try String(contentsOf: reportFile, encoding: .utf8)
        print(reportContent)
    }
    
    private func listReports(in directory: URL) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            print("❌ Results directory not found: \(directory.path)")
            return
        }
        
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let reportFiles = files.filter { $0.pathExtension == "md" && $0.lastPathComponent.contains("_report") }
        
        if reportFiles.isEmpty {
            print("📭 No reports found in \(directory.path)")
            print("   Run verification first with: model-registry verify run")
            return
        }
        
        print("📋 Available Reports:")
        print("=====================")
        
        for file in reportFiles.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            let date = attributes[.modificationDate] as? Date ?? Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            let name = file.lastPathComponent.replacingOccurrences(of: "_report.md", with: "")
            print("📄 \(name)")
            print("   Path: \(file.path)")
            print("   Modified: \(formatter.string(from: date))")
            print()
        }
        
        print("📖 To view a report:")
        print("   model-registry verify report --name <report_name>")
    }
}

// MARK: - Update Main CLI

// Note: To integrate with the existing CLI, we would update the main.swift
// to include VerificationCommand in the subcommands list.
// This would be done by modifying the existing main.swift file.

/*
 Example of updating the existing CLI:

 In main.swift, update the CommandConfiguration:

 static var configuration = CommandConfiguration(
     commandName: "model-registry",
     abstract: "CoreML conversion pipeline with batch support",
     version: "1.0.0",
     subcommands: [
         ConvertCommand.self,
         BatchConvertCommand.self,
         JobsCommand.self,
         CacheCommand.self,
         StatusCommand.self,
         VerificationCommand.self  // Add this line
     ],
     defaultSubcommand: ConvertCommand.self
 )
 */