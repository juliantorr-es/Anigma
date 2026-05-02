//
//  CoreMLConversionPipeline.swift
//  ModelRegistry
//
//  CoreML conversion pipeline with deterministic execution and receipts.
//  Wraps coremltools Python package with pinned environment for reproducibility.
//

import Foundation
import CommonCrypto
import IntelligenceContracts
import FoundationContracts

// MARK: - CoreML Conversion Types

public enum CoreMLFormat: String, Codable, Sendable {
    case mlprogram = "mlprogram"
    case neuralnetwork = "neuralnetwork"
}

public enum CoreMLComputeUnits: String, Codable, Sendable {
    case all = "all"
    case cpuOnly = "cpuOnly"
    case cpuAndGPU = "cpuAndGPU"
    case cpuAndNeuralEngine = "cpuAndNeuralEngine"
}

public enum CoreMLQuantization: String, Codable, Sendable {
    case int8 = "int8"
    case fp16 = "fp16"
    case fp32 = "fp32"
}

public enum CoreMLOSVersion: String, Codable, Sendable, CaseIterable {
    case macos13 = "macos13"
    case macos14 = "macos14"
    case macos15 = "macos15"
    case macos16 = "macos16"
    case ios17 = "ios17"
    case ios18 = "ios18"
    
    public var deploymentTarget: String {
        switch self {
        case .macos13: return "13.0"
        case .macos14: return "14.0"
        case .macos15: return "15.0"
        case .macos16: return "16.0"
        case .ios17: return "17.0"
        case .ios18: return "18.0"
        }
    }
}

public struct CoreMLPlacementAnalysis: Codable, Sendable {
    public let supportedOps: [String]
    public let unsupportedOps: [String]
    public let likelyPlacement: String
    public let aneCompatible: Bool
    public let dynamicShapes: Bool
    public let statefulSupported: Bool
    
    public init(
        supportedOps: [String] = [],
        unsupportedOps: [String] = [],
        likelyPlacement: String = "unknown",
        aneCompatible: Bool = false,
        dynamicShapes: Bool = false,
        statefulSupported: Bool = false
    ) {
        self.supportedOps = supportedOps
        self.unsupportedOps = unsupportedOps
        self.likelyPlacement = likelyPlacement
        self.aneCompatible = aneCompatible
        self.dynamicShapes = dynamicShapes
        self.statefulSupported = statefulSupported
    }
}

public struct CoreMLConversionReceipt: Codable, Sendable {
    public let inputHashes: [String: String]
    public let toolId: String
    public let toolVersion: String
    public let outputHashes: [String: String]
    public let targetFormat: CoreMLFormat
    public let computeUnits: CoreMLComputeUnits
    public let quantization: CoreMLQuantization?
    public let minOSVersion: String
    public let placementAnalysis: CoreMLPlacementAnalysis
    public let timestamp: Date
    public let metadata: [String: String]
    public let cacheKey: String?
    public let calibrationDataHash: String?
    
    public init(
        inputHashes: [String: String],
        toolId: String,
        toolVersion: String,
        outputHashes: [String: String],
        targetFormat: CoreMLFormat,
        computeUnits: CoreMLComputeUnits,
        quantization: CoreMLQuantization? = nil,
        minOSVersion: String = "macos15",
        placementAnalysis: CoreMLPlacementAnalysis,
        timestamp: Date = Date(),
        metadata: [String: String] = [:],
        cacheKey: String? = nil,
        calibrationDataHash: String? = nil
    ) {
        self.inputHashes = inputHashes
        self.toolId = toolId
        self.toolVersion = toolVersion
        self.outputHashes = outputHashes
        self.targetFormat = targetFormat
        self.computeUnits = computeUnits
        self.quantization = quantization
        self.minOSVersion = minOSVersion
        self.placementAnalysis = placementAnalysis
        self.timestamp = timestamp
        self.metadata = metadata
        self.cacheKey = cacheKey
        self.calibrationDataHash = calibrationDataHash
    }
}

public struct CoreMLCalibrationData: Codable, Sendable {
    public let samples: [Data]
    public let sampleShape: [Int]
    public let dataType: String
    public let source: String
    
    public init(
        samples: [Data],
        sampleShape: [Int],
        dataType: String = "float32",
        source: String = "generated"
    ) {
        self.samples = samples
        self.sampleShape = sampleShape
        self.dataType = dataType
        self.source = source
    }
    
    public func hash() -> String {
        var hasher = Hasher()
        hasher.combine(samples.count)
        for sample in samples.prefix(10) {
            hasher.combine(sample.count)
            if sample.count > 0 {
                hasher.combine(sample[0])
            }
        }
        hasher.combine(sampleShape)
        hasher.combine(dataType)
        hasher.combine(source)
        return String(hasher.finalize())
    }
}

// MARK: - Logging Protocol

public protocol CoreMLConversionLogger: Sendable {
    func logConversionStart(modelId: String, targetFormat: CoreMLFormat, quantization: CoreMLQuantization?)
    func logConversionProgress(modelId: String, progress: Double, message: String)
    func logConversionSuccess(modelId: String, receipt: CoreMLConversionReceipt)
    func logConversionError(modelId: String, error: Error)
    func logCacheHit(modelId: String, cacheKey: String)
    func logCacheMiss(modelId: String, cacheKey: String)
    func logRetryAttempt(modelId: String, attempt: Int, maxAttempts: Int, error: Error?)
}

public struct DefaultCoreMLConversionLogger: CoreMLConversionLogger {
    public init() {}
    
    public func logConversionStart(modelId: String, targetFormat: CoreMLFormat, quantization: CoreMLQuantization?) {
        print("[CoreML] Starting conversion: \(modelId) -> \(targetFormat) (\(quantization?.rawValue ?? "none"))")
    }
    
    public func logConversionProgress(modelId: String, progress: Double, message: String) {
        let percent = Int(progress * 100)
        print("[CoreML] \(modelId): \(percent)% - \(message)")
    }
    
    public func logConversionSuccess(modelId: String, receipt: CoreMLConversionReceipt) {
        let duration = receipt.metadata["duration_sec"] ?? "unknown"
        print("[CoreML] Conversion successful: \(modelId) (\(duration)s)")
    }
    
    public func logConversionError(modelId: String, error: Error) {
        print("[CoreML] Conversion failed: \(modelId) - \(error.localizedDescription)")
    }
    
    public func logCacheHit(modelId: String, cacheKey: String) {
        print("[CoreML] Cache hit: \(modelId) (\(cacheKey.prefix(8)))")
    }
    
    public func logCacheMiss(modelId: String, cacheKey: String) {
        print("[CoreML] Cache miss: \(modelId) (\(cacheKey.prefix(8)))")
    }
    
    public func logRetryAttempt(modelId: String, attempt: Int, maxAttempts: Int, error: Error?) {
        let errorMsg = error.map { " - \($0.localizedDescription)" } ?? ""
        print("[CoreML] Retry \(attempt)/\(maxAttempts) for \(modelId)\(errorMsg)")
    }
}

public enum CoreMLConversionError: Error {
    case modelNotFound(String)
    case conversionFailed(String)
    case analysisFailed(String)
    case toolNotFound(String)
    case cacheError(String)
    case calibrationError(String)
    case retryExhausted(String)
    case invalidOSVersion(String)
}

// MARK: - Model Registry Protocol (Simplified for CoreML Conversion)

public protocol ModelRegistryProtocol: Sendable {
    func find(id: String) async throws -> ModelRegistryEntry?
}

// MARK: - Batch Conversion Types

public struct BatchConversionJob: Codable, Sendable, Identifiable {
    public let id: String
    public let modelIds: [String]
    public let targetFormat: CoreMLFormat
    public let computeUnits: CoreMLComputeUnits
    public let quantization: CoreMLQuantization?
    public let minOSVersion: String
    public let workloadCategory: WorkloadCategory?
    public let priority: Int
    public let createdAt: Date
    public var status: BatchConversionStatus
    public var progress: Double
    public var completedModels: [String]
    public var failedModels: [String: String]
    public var results: [String: CoreMLConversionReceipt]?
    public var metadata: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        modelIds: [String],
        targetFormat: CoreMLFormat = .mlprogram,
        computeUnits: CoreMLComputeUnits = .all,
        quantization: CoreMLQuantization? = nil,
        minOSVersion: String = "macos15",
        workloadCategory: WorkloadCategory? = nil,
        priority: Int = 0,
        status: BatchConversionStatus = .pending,
        progress: Double = 0.0,
        completedModels: [String] = [],
        failedModels: [String: String] = [:],
        results: [String: CoreMLConversionReceipt]? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.modelIds = modelIds
        self.targetFormat = targetFormat
        self.computeUnits = computeUnits
        self.quantization = quantization
        self.minOSVersion = minOSVersion
        self.workloadCategory = workloadCategory
        self.priority = priority
        self.createdAt = Date()
        self.status = status
        self.progress = progress
        self.completedModels = completedModels
        self.failedModels = failedModels
        self.results = results
        self.metadata = metadata
    }
    
    public mutating func updateProgress(completed: Int, total: Int) {
        self.progress = total > 0 ? Double(completed) / Double(total) : 0.0
    }
}

public enum BatchConversionStatus: String, Codable, Sendable {
    case pending = "pending"
    case running = "running"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

public struct BatchConversionProgress: Codable, Sendable {
    public let jobId: String
    public let totalModels: Int
    public let completedModels: Int
    public let failedModels: Int
    public let progress: Double
    public let estimatedTimeRemaining: TimeInterval?
    public let currentModel: String?
    public let status: BatchConversionStatus
    public let startedAt: Date
    public let updatedAt: Date
    
    public init(
        jobId: String,
        totalModels: Int,
        completedModels: Int,
        failedModels: Int,
        progress: Double,
        estimatedTimeRemaining: TimeInterval? = nil,
        currentModel: String? = nil,
        status: BatchConversionStatus,
        startedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.jobId = jobId
        self.totalModels = totalModels
        self.completedModels = completedModels
        self.failedModels = failedModels
        self.progress = progress
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.currentModel = currentModel
        self.status = status
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}

public protocol BatchConversionProgressReporter: Sendable {
    func reportBatchProgress(_ progress: BatchConversionProgress)
    func reportModelProgress(jobId: String, modelId: String, progress: Double, message: String)
    func reportBatchCompletion(jobId: String, results: [String: CoreMLConversionReceipt], failedModels: [String: String])
    func reportBatchError(jobId: String, error: Error)
}

public struct DefaultBatchConversionProgressReporter: BatchConversionProgressReporter {
    private let logger: CoreMLConversionLogger
    
    public init(logger: CoreMLConversionLogger = DefaultCoreMLConversionLogger()) {
        self.logger = logger
    }
    
    public func reportBatchProgress(_ progress: BatchConversionProgress) {
        let percent = Int(progress.progress * 100)
        let eta = progress.estimatedTimeRemaining.map { String(format: " (ETA: %.0fs)", $0) } ?? ""
        print("[Batch \(progress.jobId.prefix(8))] \(percent)% complete - \(progress.completedModels)/\(progress.totalModels) models\(eta)")
    }
    
    public func reportModelProgress(jobId: String, modelId: String, progress: Double, message: String) {
        let percent = Int(progress * 100)
        print("[Batch \(jobId.prefix(8))] \(modelId): \(percent)% - \(message)")
    }
    
    public func reportBatchCompletion(jobId: String, results: [String: CoreMLConversionReceipt], failedModels: [String: String]) {
        let successCount = results.count
        let failCount = failedModels.count
        print("[Batch \(jobId.prefix(8))] Completed: \(successCount) successful, \(failCount) failed")
    }
    
    public func reportBatchError(jobId: String, error: Error) {
        print("[Batch \(jobId.prefix(8))] Error: \(error.localizedDescription)")
    }
}

// MARK: - Job Queue Types

public actor BatchConversionJobQueue {
    private var pendingJobs: [BatchConversionJob] = []
    private var runningJobs: [String: BatchConversionJob] = [:]
    private var completedJobs: [String: BatchConversionJob] = [:]
    private var maxConcurrentJobs: Int
    private var isProcessing = false
    
    public init(maxConcurrentJobs: Int = 2) {
        self.maxConcurrentJobs = maxConcurrentJobs
    }
    
    public func enqueue(_ job: BatchConversionJob) -> String {
        var job = job
        job.status = .pending
        pendingJobs.append(job)
        pendingJobs.sort { $0.priority > $1.priority } // Higher priority first
        return job.id
    }
    
    public func dequeue() -> BatchConversionJob? {
        guard !pendingJobs.isEmpty else { return nil }
        return pendingJobs.removeFirst()
    }
    
    public func startJob(_ job: BatchConversionJob) {
        var job = job
        job.status = .running
        runningJobs[job.id] = job
    }
    
    public func updateJob(_ job: BatchConversionJob) {
        if job.status == .completed || job.status == .failed || job.status == .cancelled {
            runningJobs.removeValue(forKey: job.id)
            completedJobs[job.id] = job
        } else {
            runningJobs[job.id] = job
        }
    }
    
    public func cancelJob(_ jobId: String) -> Bool {
        if let index = pendingJobs.firstIndex(where: { $0.id == jobId }) {
            pendingJobs.remove(at: index)
            return true
        }
        
        if var job = runningJobs[jobId] {
            job.status = .cancelled
            runningJobs.removeValue(forKey: jobId)
            completedJobs[jobId] = job
            return true
        }
        
        return false
    }
    
    public func getJob(_ jobId: String) -> BatchConversionJob? {
        return pendingJobs.first { $0.id == jobId } 
            ?? runningJobs[jobId] 
            ?? completedJobs[jobId]
    }
    
    public func listJobs(status: BatchConversionStatus? = nil) -> [BatchConversionJob] {
        let allJobs = pendingJobs + Array(runningJobs.values) + Array(completedJobs.values)
        if let status = status {
            return allJobs.filter { $0.status == status }
        }
        return allJobs
    }
    
    public func getQueueStats() -> (pending: Int, running: Int, completed: Int) {
        return (pendingJobs.count, runningJobs.count, completedJobs.count)
    }
    
    public func canStartNewJob() -> Bool {
        return runningJobs.count < maxConcurrentJobs && !pendingJobs.isEmpty
    }
}

// MARK: - CoreML Conversion Pipeline

public actor CoreMLConversionPipeline {
    private let workDir: URL
    private let registry: any ModelRegistryProtocol
    private let conversionRegistry: (any CoreMLConversionRegistry)?
    private let pythonEnvPath: String
    private let cacheDir: URL
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    private let logger: CoreMLConversionLogger
    
    public init(
        workDir: URL,
        registry: any ModelRegistryProtocol,
        pythonEnvPath: String = "/opt/anigma/coreml-env",
        cacheDir: URL? = nil,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 2.0,
        logger: CoreMLConversionLogger = DefaultCoreMLConversionLogger()
    ) {
        self.workDir = workDir
        self.registry = registry
        self.conversionRegistry = registry as? any CoreMLConversionRegistry
        self.pythonEnvPath = pythonEnvPath
        self.cacheDir = cacheDir ?? workDir.appendingPathComponent("coreml_cache")
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.logger = logger
        
        // Ensure cache directory exists
        try? FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true)
    }
    
    // MARK: - CoreML Conversion with Enhanced Features
    
    /// Convert PyTorch model to CoreML mlprogram format with enhanced features
    public func convertToCoreML(
        modelId: String,
        targetFormat: CoreMLFormat = .mlprogram,
        computeUnits: CoreMLComputeUnits = .all,
        quantization: CoreMLQuantization? = nil,
        minOSVersion: String = "macos15",
        calibrationData: CoreMLCalibrationData? = nil,
        skipCache: Bool = false,
        storeInRegistry: Bool = true
    ) async throws -> CoreMLConversionReceipt {
        logger.logConversionStart(modelId: modelId, targetFormat: targetFormat, quantization: quantization)
        
        guard let entry = try await registry.find(id: modelId) else {
            let error = CoreMLConversionError.modelNotFound(modelId)
            logger.logConversionError(modelId: modelId, error: error)
            throw error
        }
        
        // Validate OS version
        guard CoreMLOSVersion(rawValue: minOSVersion) != nil else {
            let error = CoreMLConversionError.invalidOSVersion("Unsupported OS version: \(minOSVersion)")
            logger.logConversionError(modelId: modelId, error: error)
            throw error
        }
        
        let startTime = Date()
        
        // Generate cache key
        let cacheKey = generateCacheKey(
            modelId: modelId,
            targetFormat: targetFormat,
            computeUnits: computeUnits,
            quantization: quantization,
            minOSVersion: minOSVersion,
            calibrationData: calibrationData
        )
        
        // Check cache if not skipped
        if !skipCache, let cachedReceipt = try await loadFromCache(cacheKey: cacheKey) {
            logger.logCacheHit(modelId: modelId, cacheKey: cacheKey)
            // Also check registry if storeInRegistry is true
            if storeInRegistry, let conversionRegistry = conversionRegistry {
                try? await conversionRegistry.storeCoreMLConversionReceipt(cachedReceipt, modelId: modelId)
            }
            logger.logConversionSuccess(modelId: modelId, receipt: cachedReceipt)
            return cachedReceipt
        } else if !skipCache {
            logger.logCacheMiss(modelId: modelId, cacheKey: cacheKey)
        }
        
        // Check registry for existing conversion
        if storeInRegistry, let conversionRegistry = conversionRegistry {
            if let existingReceipt = try? await conversionRegistry.findCoreMLConversion(
                modelId: modelId,
                targetFormat: targetFormat,
                computeUnits: computeUnits,
                quantization: quantization,
                minOSVersion: minOSVersion
            ) {
                logger.logCacheHit(modelId: modelId, cacheKey: "registry")
                // Found in registry, also cache it
                try await saveToCache(receipt: existingReceipt, cacheKey: cacheKey)
                logger.logConversionSuccess(modelId: modelId, receipt: existingReceipt)
                return existingReceipt
            }
        }
        
        logger.logConversionProgress(modelId: modelId, progress: 0.1, message: "Preparing conversion")
        
        let outputDir = workDir.appendingPathComponent("\(modelId)_coreml_\(cacheKey.prefix(8))")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // Build input hashes manifest
        var inputHashes: [String: String] = [:]
        for (file, hash) in entry.spec.artifactHashes {
            inputHashes[file] = hash
        }
        
        logger.logConversionProgress(modelId: modelId, progress: 0.3, message: "Starting conversion")
        
        // Execute conversion with retry logic
        let result = try await executeConversionWithRetry(
            modelPath: entry.installPath,
            outputPath: outputDir.path,
            targetFormat: targetFormat,
            computeUnits: computeUnits,
            quantization: quantization,
            minOSVersion: minOSVersion,
            calibrationData: calibrationData
        )
        
        guard result.exitCode == 0 else {
            let error = CoreMLConversionError.conversionFailed(result.stderr)
            logger.logConversionError(modelId: modelId, error: error)
            throw error
        }
        
        logger.logConversionProgress(modelId: modelId, progress: 0.7, message: "Conversion complete, hashing outputs")
        
        // Hash output artifacts
        var outputHashes: [String: String] = [:]
        let outputFiles = try FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)
        for file in outputFiles {
            let hash = try await computeFileSHA256(url: file)
            outputHashes[file.lastPathComponent] = hash
        }
        
        logger.logConversionProgress(modelId: modelId, progress: 0.8, message: "Analyzing placement")
        
        // Generate placement analysis
        let placementAnalysis = try await analyzeCoreMLPlacement(modelPath: outputDir.path)
        
        let toolVersion = try await getCoreMLToolsVersion()
        let receipt = CoreMLConversionReceipt(
            inputHashes: inputHashes,
            toolId: "coremltools",
            toolVersion: toolVersion,
            outputHashes: outputHashes,
            targetFormat: targetFormat,
            computeUnits: computeUnits,
            quantization: quantization,
            minOSVersion: minOSVersion,
            placementAnalysis: placementAnalysis,
            timestamp: startTime,
            metadata: [
                "duration_sec": String(Int(Date().timeIntervalSince(startTime))),
                "output_dir": outputDir.path,
                "model_id": modelId,
                "retry_count": "0"
            ],
            cacheKey: cacheKey,
            calibrationDataHash: calibrationData?.hash()
        )
        
        logger.logConversionProgress(modelId: modelId, progress: 0.9, message: "Saving to cache")
        
        // Save to cache
        try await saveToCache(receipt: receipt, cacheKey: cacheKey)
        
        // Store in registry if requested
        if storeInRegistry, let conversionRegistry = conversionRegistry {
            try await conversionRegistry.storeCoreMLConversionReceipt(receipt, modelId: modelId)
        }
        
        logger.logConversionProgress(modelId: modelId, progress: 1.0, message: "Conversion complete")
        logger.logConversionSuccess(modelId: modelId, receipt: receipt)
        
        return receipt
    }
    
    // MARK: - Batch Conversion
    
    /// Convert multiple models in parallel with progress reporting
    public func convertBatch(
        modelIds: [String],
        targetFormat: CoreMLFormat = .mlprogram,
        computeUnits: CoreMLComputeUnits = .all,
        quantization: CoreMLQuantization? = nil,
        minOSVersion: String = "macos15",
        workloadCategory: WorkloadCategory? = nil,
        maxConcurrentConversions: Int = 2,
        skipCache: Bool = false,
        storeInRegistry: Bool = true,
        progressReporter: BatchConversionProgressReporter? = nil
    ) async throws -> BatchConversionJob {
        let job = BatchConversionJob(
            modelIds: modelIds,
            targetFormat: targetFormat,
            computeUnits: computeUnits,
            quantization: quantization,
            minOSVersion: minOSVersion,
            workloadCategory: workloadCategory,
            priority: 0
        )
        
        return try await executeBatchConversion(
            job: job,
            maxConcurrentConversions: maxConcurrentConversions,
            skipCache: skipCache,
            storeInRegistry: storeInRegistry,
            progressReporter: progressReporter
        )
    }
    
    /// Execute batch conversion with progress tracking
    private func executeBatchConversion(
        job: BatchConversionJob,
        maxConcurrentConversions: Int,
        skipCache: Bool,
        storeInRegistry: Bool,
        progressReporter: BatchConversionProgressReporter?
    ) async throws -> BatchConversionJob {
        var job = job
        job.status = .running
        let startTime = Date()
        
        let reporter = progressReporter ?? DefaultBatchConversionProgressReporter(logger: logger)
        
        // Report start
        let initialProgress = BatchConversionProgress(
            jobId: job.id,
            totalModels: job.modelIds.count,
            completedModels: 0,
            failedModels: 0,
            progress: 0.0,
            status: .running,
            startedAt: startTime
        )
        reporter.reportBatchProgress(initialProgress)
        
        var results: [String: CoreMLConversionReceipt] = [:]
        var failedModels: [String: String] = [:]
        var completedCount = 0
        
        // Process models in batches for concurrency control
        let modelBatches = job.modelIds.chunked(into: maxConcurrentConversions)
        
        for (batchIndex, batch) in modelBatches.enumerated() {
            // Process batch concurrently
            await withTaskGroup(of: (String, Result<CoreMLConversionReceipt, Error>).self) { group in
                for modelId in batch {
                    group.addTask {
                        do {
                            let receipt: CoreMLConversionReceipt
                            
                            if let workloadCategory = job.workloadCategory {
                                receipt = try await self.convertForWorkload(
                                    modelId: modelId,
                                    workloadCategory: workloadCategory,
                                    calibrationData: nil
                                )
                            } else {
                                receipt = try await self.convertToCoreML(
                                    modelId: modelId,
                                    targetFormat: job.targetFormat,
                                    computeUnits: job.computeUnits,
                                    quantization: job.quantization,
                                    minOSVersion: job.minOSVersion,
                                    calibrationData: nil,
                                    skipCache: skipCache,
                                    storeInRegistry: storeInRegistry
                                )
                            }
                            
                            return (modelId, .success(receipt))
                        } catch {
                            return (modelId, .failure(error))
                        }
                    }
                }
                
                // Collect results as they complete
                for await (modelId, result) in group {
                    switch result {
                    case .success(let receipt):
                        results[modelId] = receipt
                        completedCount += 1
                        job.completedModels.append(modelId)
                        
                    case .failure(let error):
                        failedModels[modelId] = error.localizedDescription
                        job.failedModels[modelId] = error.localizedDescription
                    }
                    
                    // Update progress
                    job.updateProgress(completed: completedCount, total: job.modelIds.count)
                    
                    // Calculate ETA
                    let elapsedTime = Date().timeIntervalSince(startTime)
                    let estimatedTimeRemaining: TimeInterval?
                    if completedCount > 0 {
                        let timePerModel = elapsedTime / Double(completedCount)
                        let remainingModels = job.modelIds.count - completedCount
                        estimatedTimeRemaining = timePerModel * Double(remainingModels)
                    } else {
                        estimatedTimeRemaining = nil
                    }
                    
                    // Report progress
                    let progress = BatchConversionProgress(
                        jobId: job.id,
                        totalModels: job.modelIds.count,
                        completedModels: completedCount,
                        failedModels: failedModels.count,
                        progress: job.progress,
                        estimatedTimeRemaining: estimatedTimeRemaining,
                        currentModel: nil,
                        status: .running,
                        startedAt: startTime
                    )
                    reporter.reportBatchProgress(progress)
                }
            }
            
            // Small delay between batches to prevent resource exhaustion
            if batchIndex < modelBatches.count - 1 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        // Update job with results
        job.results = results
        job.status = failedModels.isEmpty ? .completed : .failed
        job.metadata["duration_sec"] = String(Int(Date().timeIntervalSince(startTime)))
        job.metadata["success_count"] = String(results.count)
        job.metadata["failure_count"] = String(failedModels.count)
        
        // Report completion
        if job.status == .completed {
            reporter.reportBatchCompletion(jobId: job.id, results: results, failedModels: failedModels)
        } else {
            let error = CoreMLConversionError.conversionFailed("Batch conversion failed for \(failedModels.count) models")
            reporter.reportBatchError(jobId: job.id, error: error)
        }
        
        return job
    }
    
    /// Convert with workload-specific settings
    public func convertForWorkload(
        modelId: String,
        workloadCategory: WorkloadCategory,
        calibrationData: CoreMLCalibrationData? = nil
    ) async throws -> CoreMLConversionReceipt {
        let format: CoreMLFormat
        let computeUnits: CoreMLComputeUnits
        let quantization: CoreMLQuantization?
        let minOSVersion: String
        
        switch workloadCategory {
        case .embeddings:
            format = .mlprogram
            computeUnits = .cpuAndNeuralEngine
            quantization = .int8
            minOSVersion = "macos15"
        case .reranker:
            format = .mlprogram
            computeUnits = .cpuAndNeuralEngine
            quantization = .fp16
            minOSVersion = "macos15"
        case .classifier:
            format = .mlprogram
            computeUnits = .all
            quantization = .int8
            minOSVersion = "macos14"
        case .perception:
            format = .mlprogram
            computeUnits = .cpuAndNeuralEngine
            quantization = .fp16
            minOSVersion = "macos15"
        case .prefill:
            format = .mlprogram
            computeUnits = .all
            quantization = .fp16
            minOSVersion = "macos15"
        case .decode, .multimodal, .specialized:
            format = .mlprogram
            computeUnits = .all
            quantization = .fp16
            minOSVersion = "macos15"
        }
        
        return try await convertToCoreML(
            modelId: modelId,
            targetFormat: format,
            computeUnits: computeUnits,
            quantization: quantization,
            minOSVersion: minOSVersion,
            calibrationData: calibrationData
        )
    }
    
    // MARK: - Cache Management
    
    private func generateCacheKey(
        modelId: String,
        targetFormat: CoreMLFormat,
        computeUnits: CoreMLComputeUnits,
        quantization: CoreMLQuantization?,
        minOSVersion: String,
        calibrationData: CoreMLCalibrationData?
    ) -> String {
        var hasher = Hasher()
        hasher.combine(modelId)
        hasher.combine(targetFormat.rawValue)
        hasher.combine(computeUnits.rawValue)
        hasher.combine(quantization?.rawValue ?? "none")
        hasher.combine(minOSVersion)
        hasher.combine(calibrationData?.hash() ?? "none")
        return String(hasher.finalize())
    }
    
    private func loadFromCache(cacheKey: String) async throws -> CoreMLConversionReceipt? {
        let cacheFile = cacheDir.appendingPathComponent("\(cacheKey).json")
        
        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: cacheFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let receipt = try decoder.decode(CoreMLConversionReceipt.self, from: data)
            
            // Verify output files still exist
            if let outputDir = receipt.metadata["output_dir"] {
                let outputURL = URL(fileURLWithPath: outputDir)
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    return receipt
                }
            }
            
            // Cache miss - output files don't exist
            try FileManager.default.removeItem(at: cacheFile)
            return nil
        } catch {
            // Corrupted cache file
            try? FileManager.default.removeItem(at: cacheFile)
            return nil
        }
    }
    
    private func saveToCache(receipt: CoreMLConversionReceipt, cacheKey: String) async throws {
        let cacheFile = cacheDir.appendingPathComponent("\(cacheKey).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(receipt)
        try data.write(to: cacheFile)
    }
    
    public func clearCache() async throws {
        let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
    }
    
    public func getCacheStats() async throws -> (total: Int, size: Int64) {
        let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey])
        
        var totalSize: Int64 = 0
        for file in files {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            totalSize += (attributes[.size] as? Int64) ?? 0
        }
        
        return (files.count, totalSize)
    }
    
    // MARK: - Calibration Data Generation
    
    /// Generate calibration data for common model types
    public func generateCalibrationData(
        for workloadCategory: WorkloadCategory,
        sampleCount: Int = 100,
        sequenceLength: Int = 512
    ) -> CoreMLCalibrationData {
        var samples: [Data] = []
        var sampleShape: [Int]
        var dataType: String
        
        switch workloadCategory {
        case .embeddings, .reranker, .classifier:
            // Text models: [batch, sequence, hidden]
            sampleShape = [1, sequenceLength, 768]  // Typical hidden size
            dataType = "float32"
            for _ in 0..<sampleCount {
                // Generate random float data
                var randomFloats = [Float](repeating: 0, count: sampleShape.reduce(1, *))
                for i in 0..<randomFloats.count {
                    randomFloats[i] = Float.random(in: -1.0...1.0)
                }
                let data = randomFloats.withUnsafeBufferPointer { buffer in
                    Data(buffer: buffer)
                }
                samples.append(data)
            }
            
        case .perception:
            // Vision models: [batch, channels, height, width]
            sampleShape = [1, 3, 224, 224]  // Standard ImageNet size
            dataType = "float32"
            for _ in 0..<sampleCount {
                var randomFloats = [Float](repeating: 0, count: sampleShape.reduce(1, *))
                for i in 0..<randomFloats.count {
                    randomFloats[i] = Float.random(in: 0.0...1.0)  // Pixel values
                }
                let data = randomFloats.withUnsafeBufferPointer { buffer in
                    Data(buffer: buffer)
                }
                samples.append(data)
            }
            
        case .prefill, .decode, .multimodal:
            // Language models: [batch, sequence, hidden]
            sampleShape = [1, sequenceLength, 4096]  // Larger hidden size for LLMs
            dataType = "float32"
            for _ in 0..<sampleCount {
                var randomFloats = [Float](repeating: 0, count: sampleShape.reduce(1, *))
                for i in 0..<randomFloats.count {
                    randomFloats[i] = Float.random(in: -1.0...1.0)
                }
                let data = randomFloats.withUnsafeBufferPointer { buffer in
                    Data(buffer: buffer)
                }
                samples.append(data)
            }
            
        case .specialized:
            // Generic 1D signal
            sampleShape = [1, 1024]
            dataType = "float32"
            for _ in 0..<sampleCount {
                var randomFloats = [Float](repeating: 0, count: sampleShape.reduce(1, *))
                for i in 0..<randomFloats.count {
                    randomFloats[i] = Float.random(in: -1.0...1.0)
                }
                let data = randomFloats.withUnsafeBufferPointer { buffer in
                    Data(buffer: buffer)
                }
                samples.append(data)
            }
        }
        
        return CoreMLCalibrationData(
            samples: samples,
            sampleShape: sampleShape,
            dataType: dataType,
            source: "generated_\(workloadCategory.rawValue)"
        )
    }
    
    /// Generate calibration data from existing model outputs
    public func generateCalibrationDataFromModel(
        modelId: String,
        sampleCount: Int = 100
    ) async throws -> CoreMLCalibrationData? {
        // This would require running the model to collect actual outputs
        // For now, return nil to indicate this feature isn't implemented
        return nil
    }
    
    // MARK: - Retry Logic
    
    private func executeConversionWithRetry(
        modelPath: String,
        outputPath: String,
        targetFormat: CoreMLFormat,
        computeUnits: CoreMLComputeUnits,
        quantization: CoreMLQuantization?,
        minOSVersion: String,
        calibrationData: CoreMLCalibrationData?
    ) async throws -> ProcessResult {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let result = try await executePythonConversion(
                    modelPath: modelPath,
                    outputPath: outputPath,
                    targetFormat: targetFormat,
                    computeUnits: computeUnits,
                    quantization: quantization,
                    minOSVersion: minOSVersion,
                    calibrationData: calibrationData
                )
                
                if result.exitCode == 0 {
                    return result
                }
                
                lastError = CoreMLConversionError.conversionFailed("Attempt \(attempt): \(result.stderr)")
                logger.logRetryAttempt(modelId: URL(fileURLWithPath: modelPath).lastPathComponent, attempt: attempt, maxAttempts: maxRetries, error: lastError)
                
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            } catch {
                lastError = error
                logger.logRetryAttempt(modelId: URL(fileURLWithPath: modelPath).lastPathComponent, attempt: attempt, maxAttempts: maxRetries, error: error)
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
        
        throw CoreMLConversionError.retryExhausted("Failed after \(maxRetries) attempts: \(lastError?.localizedDescription ?? "Unknown error")")
    }
    
    // MARK: - Tool Version Detection
    
    private func getCoreMLToolsVersion() async throws -> String {
        let result = try await executeCommand(args: [
            "\(pythonEnvPath)/bin/python",
            "-c",
            "import coremltools; print(coremltools.__version__)"
        ])
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Placement Analysis
    
    private func analyzeCoreMLPlacement(modelPath: String) async throws -> CoreMLPlacementAnalysis {
        let scriptPath = "/Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/ModelRegistry/Scripts/coreml_conversion_simple.py"
        
        let result = try await executeCommand(args: [
            "\(pythonEnvPath)/bin/python",
            scriptPath,
            "--model-path", modelPath,
            "--analyze-only"
        ])
        
        guard let data = result.stdout.data(using: .utf8) else {
            throw CoreMLConversionError.analysisFailed("Failed to parse placement analysis")
        }
        
        // Parse the JSON response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let success = json?["success"] as? Bool, success == true else {
            let error = json?["error"] as? String ?? "Unknown error"
            throw CoreMLConversionError.analysisFailed(error)
        }
        
        // Convert to CoreMLPlacementAnalysis
        return CoreMLPlacementAnalysis(
            supportedOps: json?["supported_ops"] as? [String] ?? [],
            unsupportedOps: json?["unsupported_ops"] as? [String] ?? [],
            likelyPlacement: json?["likely_placement"] as? String ?? "unknown",
            aneCompatible: json?["ane_compatible"] as? Bool ?? false,
            dynamicShapes: json?["dynamic_shapes"] as? Bool ?? false,
            statefulSupported: json?["stateful_supported"] as? Bool ?? false
        )
    }
    
    // MARK: - Execution Helpers
    
    private func executePythonConversion(
        modelPath: String,
        outputPath: String,
        targetFormat: CoreMLFormat,
        computeUnits: CoreMLComputeUnits,
        quantization: CoreMLQuantization?,
        minOSVersion: String,
        calibrationData: CoreMLCalibrationData?
    ) async throws -> ProcessResult {
        let scriptPath = "/Users/user/Developer/GitHub/Anigma_clean/anigma/Packages/ModelRegistry/Scripts/coreml_conversion_simple.py"
        
        var args = [
            "\(pythonEnvPath)/bin/python",
            scriptPath,
            "--model-path", modelPath,
            "--output-path", outputPath,
            "--target-format", targetFormat.rawValue,
            "--compute-units", computeUnits.rawValue,
            "--min-os-version", minOSVersion
        ]
        
        if let quantization = quantization {
            args.append(contentsOf: ["--quantization", quantization.rawValue])
        }
        
        // Add calibration data if provided
        if let calibrationData = calibrationData {
            // In a real implementation, we would write calibration data to a temporary file
            // and pass it to the Python script
            let calibrationFile = workDir.appendingPathComponent("calibration_\(UUID().uuidString).json")
            let encoder = JSONEncoder()
            let calibrationJSON = try encoder.encode(calibrationData)
            try calibrationJSON.write(to: calibrationFile)
            
            args.append(contentsOf: ["--calibration-data", calibrationFile.path])
        }
        
        return try await executeCommand(args: args)
    }
    
    private func executeCommand(args: [String]) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        try process.run()
        process.waitUntilExit()
        
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        return ProcessResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
    
    private func computeFileSHA256(url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Model Registry Integration Protocol

public protocol CoreMLConversionRegistry: ModelRegistryProtocol {
    func storeCoreMLConversionReceipt(_ receipt: CoreMLConversionReceipt, modelId: String) async throws
    func getCoreMLConversionReceipts(for modelId: String) async throws -> [CoreMLConversionReceipt]
    func findCoreMLConversion(
        modelId: String,
        targetFormat: CoreMLFormat,
        computeUnits: CoreMLComputeUnits,
        quantization: CoreMLQuantization?,
        minOSVersion: String
    ) async throws -> CoreMLConversionReceipt?
}

// MARK: - In-Memory Registry Implementation (for testing/demo)

public actor InMemoryCoreMLRegistry: CoreMLConversionRegistry {
    private var models: [String: ModelRegistryEntry] = [:]
    private var conversionReceipts: [String: [CoreMLConversionReceipt]] = [:]
    
    public init() {}
    
    public func find(id: String) async throws -> ModelRegistryEntry? {
        return models[id]
    }
    
    public func storeCoreMLConversionReceipt(_ receipt: CoreMLConversionReceipt, modelId: String) async throws {
        var receipts = conversionReceipts[modelId] ?? []
        receipts.append(receipt)
        conversionReceipts[modelId] = receipts
    }
    
    public func getCoreMLConversionReceipts(for modelId: String) async throws -> [CoreMLConversionReceipt] {
        return conversionReceipts[modelId] ?? []
    }
    
    public func findCoreMLConversion(
        modelId: String,
        targetFormat: CoreMLFormat,
        computeUnits: CoreMLComputeUnits,
        quantization: CoreMLQuantization?,
        minOSVersion: String
    ) async throws -> CoreMLConversionReceipt? {
        let receipts = conversionReceipts[modelId] ?? []
        return receipts.first { receipt in
            receipt.targetFormat == targetFormat &&
            receipt.computeUnits == computeUnits &&
            receipt.quantization == quantization &&
            receipt.minOSVersion == minOSVersion
        }
    }
    
    // Helper method for testing
    public func registerModel(_ entry: ModelRegistryEntry) {
        models[entry.id] = entry
    }
}

// MARK: - Supporting Types

private struct ProcessResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

// MARK: - Example Usage

/*
 Example of using the enhanced CoreMLConversionPipeline:
 
 let workDir = URL(fileURLWithPath: "/tmp/coreml_conversions")
 let registry = ModelRegistryStore(storagePath: "/tmp/model_registry.db")
 let pipeline = CoreMLConversionPipeline(
     workDir: workDir,
     registry: registry,
     maxRetries: 3,
     retryDelay: 2.0
 )
 
 // Convert with quantization and calibration
 let calibrationData = pipeline.generateCalibrationData(
     for: .embeddings,
     sampleCount: 50
 )
 
 let receipt = try await pipeline.convertToCoreML(
     modelId: "bert-base-uncased",
     targetFormat: .mlprogram,
     computeUnits: .cpuAndNeuralEngine,
     quantization: .int8,
     minOSVersion: "macos15",
     calibrationData: calibrationData
 )
 
 // Convert for specific workload
 let workloadReceipt = try await pipeline.convertForWorkload(
     modelId: "clip-vit-base-patch32",
     workloadCategory: .perception
 )
 
 // Get cache statistics
 let cacheStats = try await pipeline.getCacheStats()
 print("Cache: \(cacheStats.total) entries, \(cacheStats.size) bytes")
 
  // Clear cache if needed
  try await pipeline.clearCache()
  */

// MARK: - Array Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}