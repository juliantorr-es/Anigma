//
//  main.swift
//  ModelRegistryCLI
//
//  Command-line interface for CoreML conversion pipeline with batch support.
//

import Foundation
import ArgumentParser
import ModelRegistry

@main
struct ModelRegistryCLI: AsyncParsableCommand {
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
            VerificationCommand.self,
            CoreMLDemo.self
        ],
        defaultSubcommand: ConvertCommand.self
    )
}

// MARK: - Convert Command

struct ConvertCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "Convert a single model to CoreML format"
    )
    
    @Argument(help: "Model ID to convert")
    var modelId: String
    
    @Option(name: .shortAndLong, help: "Target format (mlprogram or neuralnetwork)")
    var format: CoreMLFormat = .mlprogram
    
    @Option(name: .shortAndLong, help: "Compute units (all, cpuOnly, cpuAndGPU, cpuAndNeuralEngine)")
    var computeUnits: CoreMLComputeUnits = .all
    
    @Option(name: .shortAndLong, help: "Quantization (int8, fp16, fp32)")
    var quantization: CoreMLQuantization?
    
    @Option(name: .shortAndLong, help: "Minimum OS version (macos13, macos14, macos15, macos16, ios17, ios18)")
    var minOSVersion: String = "macos15"
    
    @Option(name: .shortAndLong, help: "Workload category for automatic settings")
    var workload: WorkloadCategory?
    
    @Option(name: .shortAndLong, help: "Working directory for conversions")
    var workDir: String = "/tmp/coreml_conversions"
    
    @Flag(name: .shortAndLong, help: "Skip cache and force conversion")
    var skipCache: Bool = false
    
    @Flag(name: .shortAndLong, help: "Store conversion receipt in registry")
    var storeInRegistry: Bool = true
    
    mutating func run() async throws {
        print("🚀 Starting CoreML conversion for model: \(modelId)")
        
        // Create registry and pipeline
        let registry = InMemoryCoreMLRegistry()
        let workDirURL = URL(fileURLWithPath: workDir)
        let pipeline = CoreMLConversionPipeline(
            workDir: workDirURL,
            registry: registry
        )
        
        do {
            let receipt: CoreMLConversionReceipt
            
            if let workload = workload {
                print("📊 Using workload-specific settings for: \(workload.rawValue)")
                receipt = try await pipeline.convertForWorkload(
                    modelId: modelId,
                    workloadCategory: workload
                )
            } else {
                receipt = try await pipeline.convertToCoreML(
                    modelId: modelId,
                    targetFormat: format,
                    computeUnits: computeUnits,
                    quantization: quantization,
                    minOSVersion: minOSVersion,
                    calibrationData: nil,
                    skipCache: skipCache,
                    storeInRegistry: storeInRegistry
                )
            }
            
            print("✅ Conversion successful!")
            print("📋 CoreReceipt details:")
            print("   - Tool: \(receipt.toolId) v\(receipt.toolVersion)")
            print("   - Format: \(receipt.targetFormat.rawValue)")
            print("   - Compute units: \(receipt.computeUnits.rawValue)")
            print("   - Quantization: \(receipt.quantization?.rawValue ?? "none")")
            print("   - Min OS: \(receipt.minOSVersion)")
            print("   - Duration: \(receipt.metadata["duration_sec"] ?? "unknown") seconds")
            print("   - Output files: \(receipt.outputHashes.count)")
            
            if let placement = receipt.metadata["likely_placement"] {
                print("   - Placement: \(placement)")
            }
            
        } catch {
            print("❌ Conversion failed: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Batch Convert Command

struct BatchConvertCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "batch",
        abstract: "Convert multiple models in batch"
    )
    
    @Argument(help: "Model IDs to convert (comma-separated or file path)")
    var modelIds: String
    
    @Option(name: .shortAndLong, help: "Target format (mlprogram or neuralnetwork)")
    var format: CoreMLFormat = .mlprogram
    
    @Option(name: .shortAndLong, help: "Compute units (all, cpuOnly, cpuAndGPU, cpuAndNeuralEngine)")
    var computeUnits: CoreMLComputeUnits = .all
    
    @Option(name: .shortAndLong, help: "Quantization (int8, fp16, fp32)")
    var quantization: CoreMLQuantization?
    
    @Option(name: .shortAndLong, help: "Minimum OS version")
    var minOSVersion: String = "macos15"
    
    @Option(name: .shortAndLong, help: "Workload category for automatic settings")
    var workload: WorkloadCategory?
    
    @Option(name: .shortAndLong, help: "Maximum concurrent conversions")
    var maxConcurrent: Int = 2
    
    @Option(name: .shortAndLong, help: "Working directory")
    var workDir: String = "/tmp/coreml_conversions"
    
    @Flag(name: .shortAndLong, help: "Skip cache and force conversion")
    var skipCache: Bool = false
    
    @Flag(name: .shortAndLong, help: "Store conversion receipts in registry")
    var storeInRegistry: Bool = true
    
    mutating func run() async throws {
        // Parse model IDs
        let ids: [String]
        if FileManager.default.fileExists(atPath: modelIds) {
            // Read from file
            let content = try String(contentsOfFile: modelIds, encoding: .utf8)
            ids = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            // Parse comma-separated list
            ids = modelIds.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        
        guard !ids.isEmpty else {
            print("❌ No model IDs provided")
            throw ValidationError("Please provide model IDs")
        }
        
        print("🚀 Starting batch conversion for \(ids.count) models")
        print("📊 Settings:")
        print("   - Format: \(format.rawValue)")
        print("   - Compute units: \(computeUnits.rawValue)")
        print("   - Quantization: \(quantization?.rawValue ?? "none")")
        print("   - Min OS: \(minOSVersion)")
        print("   - Max concurrent: \(maxConcurrent)")
        print("   - Workload: \(workload?.rawValue ?? "custom")")
        
        // Create registry and pipeline
        let registry = InMemoryCoreMLRegistry()
        let workDirURL = URL(fileURLWithPath: workDir)
        let pipeline = CoreMLConversionPipeline(
            workDir: workDirURL,
            registry: registry
        )
        
        let progressReporter = DefaultBatchConversionProgressReporter()
        
        do {
            let job = try await pipeline.convertBatch(
                modelIds: ids,
                targetFormat: format,
                computeUnits: computeUnits,
                quantization: quantization,
                minOSVersion: minOSVersion,
                workloadCategory: workload,
                maxConcurrentConversions: maxConcurrent,
                skipCache: skipCache,
                storeInRegistry: storeInRegistry,
                progressReporter: progressReporter
            )
            
            print("\n📋 Batch conversion completed!")
            print("   - Job ID: \(job.id)")
            print("   - Status: \(job.status.rawValue)")
            print("   - Successful: \(job.completedModels.count)")
            print("   - Failed: \(job.failedModels.count)")
            print("   - Duration: \(job.metadata["duration_sec"] ?? "unknown") seconds")
            
            if !job.failedModels.isEmpty {
                print("\n❌ Failed models:")
                for (modelId, error) in job.failedModels {
                    print("   - \(modelId): \(error)")
                }
            }
            
        } catch {
            print("❌ Batch conversion failed: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Jobs Command

struct JobsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "jobs",
        abstract: "Manage batch conversion jobs"
    )
    
    @Option(name: .shortAndLong, help: "Working directory")
    var workDir: String = "/tmp/coreml_conversions"
    
    @Flag(name: .shortAndLong, help: "List all jobs")
    var list: Bool = false
    
    @Option(name: .shortAndLong, help: "Show details for specific job")
    var show: String?
    
    @Option(name: .shortAndLong, help: "Cancel specific job")
    var cancel: String?
    
    mutating func run() async throws {
        let workDirURL = URL(fileURLWithPath: workDir)
        
        // In a real implementation, we would load jobs from persistent storage
        // For now, we'll demonstrate the job queue API
        let jobQueue = BatchConversionJobQueue(maxConcurrentJobs: 2)
        
        if list {
            let stats = await jobQueue.getQueueStats()
            print("📊 Job Queue Status:")
            print("   - Pending: \(stats.pending)")
            print("   - Running: \(stats.running)")
            print("   - Completed: \(stats.completed)")
            
            let allJobs = await jobQueue.listJobs()
            if !allJobs.isEmpty {
                print("\n📋 All Jobs:")
                for job in allJobs {
                    let progress = Int(job.progress * 100)
                    print("   - \(job.id.prefix(8)): \(job.status.rawValue) (\(progress)%) - \(job.modelIds.count) models")
                }
            }
        }
        
        if let jobId = show {
            if let job = await jobQueue.getJob(jobId) {
                print("📋 Job Details: \(jobId)")
                print("   - Status: \(job.status.rawValue)")
                print("   - Progress: \(Int(job.progress * 100))%")
                print("   - Models: \(job.modelIds.count)")
                print("   - Completed: \(job.completedModels.count)")
                print("   - Failed: \(job.failedModels.count)")
                print("   - Created: \(job.createdAt)")
                
                if !job.completedModels.isEmpty {
                    print("\n✅ Completed models:")
                    for modelId in job.completedModels.prefix(5) {
                        print("   - \(modelId)")
                    }
                    if job.completedModels.count > 5 {
                        print("   - ... and \(job.completedModels.count - 5) more")
                    }
                }
                
                if !job.failedModels.isEmpty {
                    print("\n❌ Failed models:")
                    for (modelId, error) in job.failedModels.prefix(5) {
                        print("   - \(modelId): \(error)")
                    }
                    if job.failedModels.count > 5 {
                        print("   - ... and \(job.failedModels.count - 5) more")
                    }
                }
            } else {
                print("❌ Job not found: \(jobId)")
            }
        }
        
        if let jobId = cancel {
            let cancelled = await jobQueue.cancelJob(jobId)
            if cancelled {
                print("✅ Job cancelled: \(jobId)")
            } else {
                print("❌ Job not found or cannot be cancelled: \(jobId)")
            }
        }
        
        if !list && show == nil && cancel == nil {
            print("ℹ️  Use --list, --show <jobId>, or --cancel <jobId>")
        }
    }
}

// MARK: - Cache Command

struct CacheCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "cache",
        abstract: "Manage conversion cache"
    )
    
    @Option(name: .shortAndLong, help: "Working directory")
    var workDir: String = "/tmp/coreml_conversions"
    
    @Flag(name: .shortAndLong, help: "Show cache statistics")
    var stats: Bool = false
    
    @Flag(name: .shortAndLong, help: "Clear cache")
    var clear: Bool = false
    
    mutating func run() async throws {
        let workDirURL = URL(fileURLWithPath: workDir)
        let registry = InMemoryCoreMLRegistry()
        let pipeline = CoreMLConversionPipeline(
            workDir: workDirURL,
            registry: registry
        )
        
        if stats {
            let cacheStats = try await pipeline.getCacheStats()
            print("📊 Cache Statistics:")
            print("   - Entries: \(cacheStats.total)")
            print("   - Size: \(formatBytes(cacheStats.size))")
        }
        
        if clear {
            try await pipeline.clearCache()
            print("✅ Cache cleared")
        }
        
        if !stats && !clear {
            print("ℹ️  Use --stats or --clear")
        }
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

// MARK: - Status Command

struct StatusCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show conversion pipeline status"
    )
    
    @Option(name: .shortAndLong, help: "Working directory")
    var workDir: String = "/tmp/coreml_conversions"
    
    mutating func run() async throws {
        let workDirURL = URL(fileURLWithPath: workDir)
        
        print("🔍 CoreML Conversion Pipeline Status")
        print("=====================================")
        
        // Check working directory
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: workDir, isDirectory: &isDir)
        
        print("📁 Working Directory: \(workDir)")
        print("   - Exists: \(exists ? "✅" : "❌")")
        print("   - Is directory: \(exists && isDir.boolValue ? "✅" : "❌")")
        
        if exists && isDir.boolValue {
            // Check cache directory
            let cacheDir = workDirURL.appendingPathComponent("coreml_cache")
            let cacheExists = FileManager.default.fileExists(atPath: cacheDir.path)
            
            print("\n📦 Cache Directory: \(cacheDir.path)")
            print("   - Exists: \(cacheExists ? "✅" : "❌")")
            
            if cacheExists {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: cacheDir.path)
                    print("   - Entries: \(contents.count)")
                    
                    // Calculate total size
                    var totalSize: Int64 = 0
                    for item in contents {
                        let itemPath = cacheDir.appendingPathComponent(item).path
                        let attributes = try FileManager.default.attributesOfItem(atPath: itemPath)
                        totalSize += (attributes[.size] as? Int64) ?? 0
                    }
                    
                    print("   - Total size: \(formatBytes(totalSize))")
                } catch {
                    print("   - Error reading cache: \(error.localizedDescription)")
                }
            }
        }
        
        // Check Python environment (simplified)
        print("\n🐍 Python Environment:")
        print("   - CoreML tools: Not checked (requires actual Python environment)")
        print("   - Note: In production, this would verify coremltools installation")
        
        print("\n⚙️  System Information:")
        print("   - macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("   - Architecture: \(ProcessInfo.processInfo.machine)")
        
        print("\n✅ Status check complete")
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