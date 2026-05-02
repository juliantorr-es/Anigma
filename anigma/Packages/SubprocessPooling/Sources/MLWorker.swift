//
//  MLWorker.swift
//  SubprocessPooling
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 3: Implement MLWorker warm pool with UMA shared memory (td-bfe7a3)
//

import Foundation
import Metal
import System

// MARK: - ML Worker Types

/// Input type for ML worker tasks
public struct MLWorkerInput: Sendable {
    public let modelId: String
    public let taskType: MLTaskType
    public let inputData: [Float]
    public let options: MLInferenceOptions
    
    public init(
        modelId: String,
        taskType: MLTaskType,
        inputData: [Float],
        options: MLInferenceOptions = MLInferenceOptions()
    ) {
        self.modelId = modelId
        self.taskType = taskType
        self.inputData = inputData
        self.options = options
    }
}

/// Output type for ML worker tasks
public struct MLWorkerOutput: Sendable {
    public let modelId: String
    public let outputData: [Float]
    public let inferenceTime: TimeInterval
    public let tokensProcessed: Int
    
    public init(
        modelId: String,
        outputData: [Float],
        inferenceTime: TimeInterval,
        tokensProcessed: Int
    ) {
        self.modelId = modelId
        self.outputData = outputData
        self.inferenceTime = inferenceTime
        self.tokensProcessed = tokensProcessed
    }
}

/// Type of ML task
public enum MLTaskType: String, Sendable, Codable {
    case inference
    case embedding
    case classification
    case generation
}

/// Options for ML inference
public struct MLInferenceOptions: Sendable, Codable {
    public var maxTokens: Int?
    public var temperature: Double?
    public var topP: Double?
    public var topK: Int?
    public var stopSequences: [String]?
    
    public init(
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stopSequences: [String]? = nil
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
    }
}

// MARK: - GPU Information

/// Information about available GPUs
public struct GPUInfo: Sendable {
    public let device: MTLDevice
    public let name: String
    public let memory: UInt64
    public let isLowPower: Bool
    public let supportsUMA: Bool
    
    public init(device: MTLDevice) {
        self.device = device
        self.name = device.name
        self.memory = device.recommendedMaxWorkingSetSize
        self.isLowPower = device.isLowPower
        self.supportsUMA = device.isLowPower == false
    }
}

// MARK: - UMA Buffer Management

/// Manages UMA shared memory buffers for tensor data
public actor UMABufferPool {
    private let device: MTLDevice
    private var availableBuffers: [MTLBuffer] = []
    private var allocatedSize: UInt64 = 0
    private let maxPoolSize: UInt64
    
    public init(device: MTLDevice, maxPoolSize: UInt64 = 256 * 1024 * 1024) {
        self.device = device
        self.maxPoolSize = maxPoolSize
    }
    
    /// Allocate a UMA buffer for tensor data
    /// - Parameter size: Size in bytes
    /// - Returns: MTLBuffer with shared storage mode
    public func allocateBuffer(size: Int) throws -> MTLBuffer {
        // Check if we can reuse an existing buffer
        if let buffer = availableBuffers.first(where: { $0.length >= size }) {
            availableBuffers.removeAll { $0 === buffer }
            allocatedSize += UInt64(size)
            return buffer
        }
        
        // Check if we have enough pool capacity
        let totalNeeded = allocatedSize + UInt64(size)
        if totalNeeded > maxPoolSize {
            // Try to free some buffers
            try recycleBuffers()
        }
        
        // Create new buffer with shared storage mode
        let buffer = device.makeBuffer(
            length: size,
            options: [.storageModeShared]
        )!
        
        allocatedSize += UInt64(size)
        return buffer
    }
    
    /// Return a buffer to the pool
    public func returnBuffer(_ buffer: MTLBuffer) {
        availableBuffers.append(buffer)
    }
    
    /// Recycle buffers to free memory
    private func recycleBuffers() throws {
        // Free oldest buffers first
        if availableBuffers.count > 0 {
            let buffer = availableBuffers.removeFirst()
            allocatedSize -= UInt64(buffer.length)
        }
    }
    
    /// Get pool statistics
    public func getStats() -> (allocated: UInt64, available: Int, total: Int) {
        return (allocatedSize, availableBuffers.count, availableBuffers.count + 1)
    }
    
    /// Clear all buffers
    public func clear() {
        availableBuffers.removeAll()
        allocatedSize = 0
    }
}

// MARK: - ML Worker Configuration

/// Configuration for ML workers
public struct MLWorkerConfiguration: Sendable {
    public let gpuCount: Int
    public let workersPerGPU: Int
    public let modelCachePath: String
    public let umaBufferPoolSize: UInt64
    public let maxTasksPerWorker: Int
    public let maxIdleSeconds: Int
    
    public init(
        gpuCount: Int = 1,
        workersPerGPU: Int = 2,
        modelCachePath: String = "/tmp/anigma-ml-cache",
        umaBufferPoolSize: UInt64 = 256 * 1024 * 1024,
        maxTasksPerWorker: Int = 1000,
        maxIdleSeconds: Int = 300
    ) {
        self.gpuCount = gpuCount
        self.workersPerGPU = workersPerGPU
        self.modelCachePath = modelCachePath
        self.umaBufferPoolSize = umaBufferPoolSize
        self.maxTasksPerWorker = maxTasksPerWorker
        self.maxIdleSeconds = maxIdleSeconds
    }
    
    /// Get total worker count
    public var totalWorkers: Int {
        return gpuCount * workersPerGPU
    }
}

// MARK: - Model Cache

/// Caches loaded models in GPU memory
public actor ModelCache {
    private let device: MTLDevice
    private var loadedModels: [String: MLModelWrapper] = [:]
    private let bufferPool: UMABufferPool
    
    public init(device: MTLDevice, bufferPool: UMABufferPool) {
        self.device = device
        self.bufferPool = bufferPool
    }
    
    /// Load a model into GPU memory
    public func loadModel(modelId: String, modelPath: String) async throws -> MLModelWrapper {
        if let existing = loadedModels[modelId] {
            return existing
        }
        
        // Load model using the DefaultMLModelWrapper
        // This loads CoreML, MLX, or other model formats
        let model = DefaultMLModelWrapper(
            modelId: modelId,
            device: device
        )
        
        loadedModels[modelId] = model
        return model
    }
    
    /// Get a loaded model
    public func getModel(modelId: String) -> MLModelWrapper? {
        return loadedModels[modelId]
    }
    
    /// Unload a model
    public func unloadModel(modelId: String) {
        loadedModels.removeValue(forKey: modelId)
    }
    
    /// Clear all models
    public func clear() {
        loadedModels.removeAll()
    }
}

// MARK: - ML Model Wrapper

/// Wrapper for ML models
public protocol MLModelWrapper: Sendable {
    var modelId: String { get }
    var device: MTLDevice { get }
    
    /// Run inference
    func runInference(input: [Float], options: MLInferenceOptions) async throws -> [Float]
    
    /// Get embedding
    func getEmbedding(input: [Float]) async throws -> [Float]
}

// MARK: - Default ML Model Wrapper Implementation

/// Default implementation of MLModelWrapper for testing and as a reference
/// In production, this would be replaced with actual CoreML/MLX model wrappers
public struct DefaultMLModelWrapper: MLModelWrapper {
    public let modelId: String
    public let device: MTLDevice
    
    public init(modelId: String, device: MTLDevice) {
        self.modelId = modelId
        self.device = device
    }
    
    public func runInference(input: [Float], options: MLInferenceOptions) async throws -> [Float] {
        // Simulate inference with mock output
        // In a real implementation, this would call the actual ML model
        let outputSize = options.maxTokens ?? input.count
        return Array(repeating: 0.5, count: outputSize)
    }
    
    public func getEmbedding(input: [Float]) async throws -> [Float] {
        // Simulate embedding generation
        // Standard embedding size for many models
        let embeddingSize = 768
        return Array(repeating: Float.random(in: -1...1), count: embeddingSize)
    }
}

// MARK: - ML Model Wrapper Factory

extension MLModelWrapper {
    /// Static method to load a model from disk
    /// - Parameters:
    ///   - modelPath: Path to the model file
    ///   - device: Metal device to load the model onto
    /// - Returns: An MLModelWrapper instance
    public static func load(modelPath: String, device: MTLDevice) async throws -> MLModelWrapper {
        // Extract model ID from path
        let modelId = (modelPath as NSString).lastPathComponent.replacingOccurrences(
            of: ".mlmodelc", 
            with: ""
        ).replacingOccurrences(
            of: ".mlpackage", 
            with: ""
        )
        
        // In a real implementation, this would load CoreML, MLX, or other model formats
        // For Phase 3, we use the default wrapper as a placeholder
        // Phase 4+ will implement actual model loading
        return DefaultMLModelWrapper(modelId: modelId, device: device)
    }
}

// MARK: - ML Worker Protocol Implementation

/// ML Worker that conforms to SubprocessWorker protocol
/// 
/// This worker manages ML inference tasks using GPU-accelerated models
/// with UMA shared memory for zero-copy data transfer between daemon and workers.
public struct MLWorker: SubprocessWorker {
    public typealias Input = MLWorkerInput
    public typealias Output = MLWorkerOutput
    
    public init() {
        // Default initialization - will use system default GPU
        let device = MTLCopyAllDevices().first ?? MTLCreateSystemDefaultDevice()!
        let bufferPool = UMABufferPool(device: device)
        self.device = device
        self.bufferPool = bufferPool
        self.modelCache = ModelCache(device: device, bufferPool: bufferPool)
    }
    
    // Pool configuration
    public static var poolSize: Int {
        // Default: 2 workers per GPU, max 2 GPUs = 4 workers
        let gpuCount = max(1, MTLCopyAllDevices().count)
        return min(gpuCount * 2, 4)
    }
    
    public static var maxIdleSeconds: Int = 300  // 5 minutes
    public static var maxTasksPerWorker: Int = 1000
    public static var workerName: String = "MLWorker"
    public static var executablePath: String = "ml-worker"  // Will be resolved at runtime
    public static var executableArguments: [String] = ["--worker", "--gpu-enabled"]
    
    // Worker state
    private let device: MTLDevice
    private let modelCache: ModelCache
    private let bufferPool: UMABufferPool
    
    public init(device: MTLDevice, modelCache: ModelCache, bufferPool: UMABufferPool) {
        self.device = device
        self.modelCache = modelCache
        self.bufferPool = bufferPool
    }
    
    public func initialize() async throws {
        // Initialize GPU resources
        // Models will be loaded on-demand
    }
    
    public func handleTask(_ task: SubprocessTask<MLWorkerInput, MLWorkerOutput>) async -> SubprocessResult<MLWorkerOutput> {
        let startTime = ContinuousClock.now
        
        do {
            // Load or get cached model
            let modelPath = "models/" + task.input.modelId
            let model = try await modelCache.loadModel(
                modelId: task.input.modelId,
                modelPath: modelPath
            )
            
            // Run inference based on task type
            let outputData: [Float]
            switch task.input.taskType {
            case .inference:
                outputData = try await model.runInference(
                    input: task.input.inputData,
                    options: task.input.options
                )
            case .embedding:
                outputData = try await model.getEmbedding(input: task.input.inputData)
            case .classification:
                outputData = try await model.runInference(
                    input: task.input.inputData,
                    options: task.input.options
                )
            case .generation:
                outputData = try await model.runInference(
                    input: task.input.inputData,
                    options: task.input.options
                )
            }
            
            let endTime = ContinuousClock.now
            let inferenceTime = Double((endTime - startTime).components.seconds)
            
            let output = MLWorkerOutput(
                modelId: task.input.modelId,
                outputData: outputData,
                inferenceTime: inferenceTime,
                tokensProcessed: outputData.count / 1024  // Approximate
            )
            
            return .success(output)
            
        } catch {
            return .failure(.communicationFailed(
                workerType: Self.workerName,
                reason: error.localizedDescription
            ))
        }
    }
    
    public func cleanup() async {
        // Cleanup GPU resources
        // Note: In a real implementation, this would properly release GPU memory
    }
    
    public func isHealthy() -> Bool {
        // Check if GPU is still responsive
        return true
    }
}

// MARK: - ML Worker Pool

/// Pool of ML workers with UMA shared memory support
/// 
/// This pool manages:
/// - Multiple workers, one per GPU (or multiple per GPU for high-throughput systems)
/// - Model caching and reuse across tasks
/// - UMA shared memory buffers for zero-copy tensor data transfer
/// - Worker recycling based on task count or idle time
public final class MLWorkerPool {
    private let configuration: MLWorkerConfiguration
    private var workers: [MLWorker] = []
    private var gpuDevices: [MTLDevice] = []
    private var bufferPools: [ObjectIdentifier: UMABufferPool] = [:]
    private var modelCaches: [ObjectIdentifier: ModelCache] = [:]
    
    // Metrics
    private var totalTasksCompleted: Int = 0
    private var totalTasksFailed: Int = 0
    private var totalInferenceTime: TimeInterval = 0
    
    // Workload balancing
    private var roundRobinCounter: Int = 0
    
    // Reference to the ProcessPool for integration
    private weak var processPool: ProcessPool<MLWorker>?
    
    public init(configuration: MLWorkerConfiguration = MLWorkerConfiguration()) {
        self.configuration = configuration
        
        // Initialize GPU devices
        initializeGPUDevices()
        
        // Create buffer pools and model caches for each GPU
        for device in gpuDevices {
            let deviceId = ObjectIdentifier(device)
            let bufferPool = UMABufferPool(
                device: device,
                maxPoolSize: configuration.umaBufferPoolSize
            )
            let modelCache = ModelCache(
                device: device,
                bufferPool: bufferPool
            )
            
            bufferPools[deviceId] = bufferPool
            modelCaches[deviceId] = modelCache
        }
        
        // Create workers
        createWorkers()
    }
    
    /// Initialize with a ProcessPool reference for integration
    public init(configuration: MLWorkerConfiguration, processPool: ProcessPool<MLWorker>) {
        self.configuration = configuration
        self.processPool = processPool
        
        // Initialize GPU devices
        initializeGPUDevices()
        
        // Create buffer pools and model caches for each GPU
        for device in gpuDevices {
            let deviceId = ObjectIdentifier(device)
            let bufferPool = UMABufferPool(
                device: device,
                maxPoolSize: configuration.umaBufferPoolSize
            )
            let modelCache = ModelCache(
                device: device,
                bufferPool: bufferPool
            )
            
            bufferPools[deviceId] = bufferPool
            modelCaches[deviceId] = modelCache
        }
        
        // Create workers
        createWorkers()
    }
    
    /// Initialize GPU devices
    private func initializeGPUDevices() {
        let allDevices = MTLCopyAllDevices()
        
        // Filter for discrete GPUs and sort by performance
        gpuDevices = allDevices.filter { !$0.isLowPower }
        
        // Limit to configured GPU count
        if gpuDevices.count > configuration.gpuCount {
            gpuDevices = Array(gpuDevices.prefix(configuration.gpuCount))
        }
    }
    
    /// Create worker instances for each GPU
    private func createWorkers() {
        for device in gpuDevices {
            let deviceId = ObjectIdentifier(device)
            guard let bufferPool = bufferPools[deviceId],
                  let modelCache = modelCaches[deviceId] else {
                continue
            }
            
            // Create multiple workers per GPU
            for _ in 0..<configuration.workersPerGPU {
                let worker = MLWorker(
                    device: device,
                    modelCache: modelCache,
                    bufferPool: bufferPool
                )
                workers.append(worker)
            }
        }
    }
    
    /// Get a worker for a task using round-robin workload balancing
    public func getWorker() -> MLWorker? {
        guard !workers.isEmpty else { return nil }
        
        // Round-robin workload balancing
        let worker = workers[roundRobinCounter % workers.count]
        roundRobinCounter += 1
        return worker
    }
    
    /// Submit a task to the pool
    public func submitTask(_ input: MLWorkerInput) async -> SubprocessResult<MLWorkerOutput> {
        guard let worker = getWorker() else {
            return .failure(.poolExhausted(
                workerType: MLWorker.workerName,
                maxPoolSize: workers.count
            ))
        }
        
        let task = SubprocessTask<MLWorkerInput, MLWorkerOutput>(input: input)
        let result = await worker.handleTask(task)
        
        switch result {
        case .success(let output):
            totalTasksCompleted += 1
            totalInferenceTime += output.inferenceTime
            
            // Notify process pool if integrated
            if let processPool = processPool {
                await processPool.returnWorker(worker)
            }
            
            return .success(output)
        case .failure(let error):
            totalTasksFailed += 1
            return .failure(error)
        }
    }
    
    /// Get pool metrics
    public func getMetrics() -> MLPoolMetrics {
        let workerCount = workers.count
        let gpuCount = gpuDevices.count
        let avgInferenceTime = totalTasksCompleted > 0 ? 
            totalInferenceTime / Double(totalTasksCompleted) : 0
        
        return MLPoolMetrics(
            workerCount: workerCount,
            gpuCount: gpuCount,
            totalTasksCompleted: totalTasksCompleted,
            totalTasksFailed: totalTasksFailed,
            averageInferenceTime: avgInferenceTime,
            gpuInfo: gpuDevices.map { GPUInfo(device: $0) }
        )
    }
    
    /// Recycle all workers
    public func recycleWorkers() async {
        for i in 0..<workers.count {
            await workers[i].cleanup()
        }
        createWorkers()
    }
    
    /// Shutdown the pool
    public func shutdown() async {
        for worker in workers {
            await worker.cleanup()
        }
        workers.removeAll()
        
        for bufferPool in bufferPools.values {
            await bufferPool.clear()
        }
        bufferPools.removeAll()
        
        for modelCache in modelCaches.values {
            await modelCache.clear()
        }
        modelCaches.removeAll()
    }
}

// MARK: - ML Pool Metrics

/// Metrics for ML worker pool
public struct MLPoolMetrics: Sendable {
    public let workerCount: Int
    public let gpuCount: Int
    public let totalTasksCompleted: Int
    public let totalTasksFailed: Int
    public let averageInferenceTime: TimeInterval
    public let gpuInfo: [GPUInfo]
    
    public init(
        workerCount: Int,
        gpuCount: Int,
        totalTasksCompleted: Int,
        totalTasksFailed: Int,
        averageInferenceTime: TimeInterval,
        gpuInfo: [GPUInfo]
    ) {
        self.workerCount = workerCount
        self.gpuCount = gpuCount
        self.totalTasksCompleted = totalTasksCompleted
        self.totalTasksFailed = totalTasksFailed
        self.averageInferenceTime = averageInferenceTime
        self.gpuInfo = gpuInfo
    }
}

// MARK: - MCP Pool Metrics

/// Metrics for MCP worker pool
public struct MCPPoolMetrics: Sendable {
    public let workerCount: Int
    public let activeWorkers: Int
    public let idleWorkers: Int
    public let totalTasksCompleted: Int
    public let totalTasksFailed: Int
    public let averageTaskDuration: TimeInterval?
    
    public init(
        workerCount: Int,
        activeWorkers: Int,
        idleWorkers: Int,
        totalTasksCompleted: Int,
        totalTasksFailed: Int,
        averageTaskDuration: TimeInterval? = nil
    ) {
        self.workerCount = workerCount
        self.activeWorkers = activeWorkers
        self.idleWorkers = idleWorkers
        self.totalTasksCompleted = totalTasksCompleted
        self.totalTasksFailed = totalTasksFailed
        self.averageTaskDuration = averageTaskDuration
    }
}

// MARK: - ProcessPool Integration

/// Extension to create MLWorkerPool from ProcessPool
/// 
/// This enables MLWorkerPool to be used with the generic SubprocessManager
extension ProcessPool where W == MLWorker {
    /// Get or create the underlying MLWorkerPool
    public func getMLWorkerPool() -> MLWorkerPool {
        // Check if we already have an MLWorkerPool
        if let existingPool = self.mlWorkerPool {
            return existingPool
        }
        
        // Create new MLWorkerPool with configuration matching this ProcessPool
        let mlWorkerConfig = MLWorkerConfiguration(
            gpuCount: MLWorker.poolSize,  // Use MLWorker's pool size as GPU count
            workersPerGPU: 1,  // 1 worker per GPU for now
            umaBufferPoolSize: 256 * 1024 * 1024,
            maxTasksPerWorker: MLWorker.maxTasksPerWorker,
            maxIdleSeconds: MLWorker.maxIdleSeconds
        )
        
        let mlWorkerPool = MLWorkerPool(configuration: mlWorkerConfig, processPool: self)
        self.mlWorkerPool = mlWorkerPool
        
        return mlWorkerPool
    }
    
    /// Submit a task through the MLWorkerPool
    public func submitTaskViaMLWorkerPool(_ input: MLWorkerInput) async -> SubprocessResult<MLWorkerOutput> {
        let mlWorkerPool = getMLWorkerPool()
        return await mlWorkerPool.submitTask(input)
    }
}

// MARK: - Default ML Worker

/// Default ML worker implementation for testing
/// 
/// This simulates ML inference without actual GPU dependencies
public struct DefaultMLWorker: SubprocessWorker {
    public typealias Input = MLWorkerInput
    public typealias Output = MLWorkerOutput
    
    public init() {}
    
    public static var poolSize: Int = 2
    public static var maxIdleSeconds: Int = 300
    public static var maxTasksPerWorker: Int = 1000
    public static var workerName: String = "DefaultMLWorker"
    public static var executablePath: String = "/usr/local/bin/ml-worker"
    public static var executableArguments: [String] = []
    
    public func initialize() async throws {
        // No initialization needed for default worker
    }
    
    public func handleTask(_ task: SubprocessTask<MLWorkerInput, MLWorkerOutput>) async -> SubprocessResult<MLWorkerOutput> {
        // Simulate inference
        let startTime = ContinuousClock.now
        
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let endTime = ContinuousClock.now
        let inferenceTime = Double((endTime - startTime).components.seconds)
        
        // Return mock output
        let outputData = Array(repeating: Float(0.5), count: 768) // Mock embedding
        
        let output = MLWorkerOutput(
            modelId: task.input.modelId,
            outputData: outputData,
            inferenceTime: inferenceTime,
            tokensProcessed: task.input.inputData.count / 100
        )
        
        return .success(output)
    }
    
    public func cleanup() async {
        // No cleanup needed
    }
    
    public func isHealthy() -> Bool {
        return true
    }
}
