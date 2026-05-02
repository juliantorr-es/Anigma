//
//  SubprocessManager.swift
//  SubprocessPooling
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 1: Implement SubprocessManager foundation with pool lifecycle (td-a84da2)
//

import Foundation
import System
import OSLog

// MARK: - Logger

private let logger = Logger(subsystem: "com.anigma.subprocess", category: "SubprocessManager")

// MARK: - Errors

/// Errors that can occur during subprocess management
public enum SubprocessError: Error, Sendable {
    case spawnFailed(path: String, reason: String)
    case workerInitializationFailed(workerType: String, reason: String)
    case workerTimeout(workerType: String)
    case poolExhausted(workerType: String, maxPoolSize: Int)
    case communicationFailed(workerType: String, reason: String)
    case recyclingFailed(workerType: String, reason: String)
}

// MARK: - Task Type

/// Represents a unit of work to be executed by a subprocess worker
public struct SubprocessTask<Input: Sendable, Output: Sendable>: Sendable {
    public let id: UUID
    public let input: Input
    public let deadline: ContinuousClock.Instant?
    
    public init(input: Input, deadline: ContinuousClock.Instant? = nil) {
        self.id = UUID()
        self.input = input
        self.deadline = deadline
    }
}

// MARK: - Result Type

/// Result of a subprocess task execution
public enum SubprocessResult<Output: Sendable>: Sendable {
    case success(Output)
    case failure(SubprocessError)
}

// MARK: - SubprocessWorker Protocol

/// Protocol that all subprocess workers must conform to
/// 
/// Workers are responsible for:
/// - Defining pool configuration (size, timeouts, task limits)
/// - Initializing themselves (loading models, establishing connections, etc.)
/// - Handling tasks
/// - Cleaning up resources
/// 
/// Note: Workers are managed by ProcessPool (an actor), so they don't need Sendable conformance.
/// They can contain non-Sendable state (like spawner references with mutable state).
public protocol SubprocessWorker {
    /// Type of input this worker accepts
    associatedtype Input: Sendable
    /// Type of output this worker produces
    associatedtype Output: Sendable
    
    /// Default pool size for this worker type
    static var poolSize: Int { get }
    
    /// Maximum idle time in seconds before a worker is recycled
    static var maxIdleSeconds: Int { get }
    
    /// Maximum number of tasks a worker can handle before recycling
    static var maxTasksPerWorker: Int { get }
    
    /// Human-readable name for this worker type (for logging/metrics)
    static var workerName: String { get }
    
    /// Path to the executable for this worker
    static var executablePath: String { get }
    
    /// Arguments to pass when spawning the worker process
    static var executableArguments: [String] { get }
    
    /// Initialize a new worker instance
    init()
    
    /// Initialize the worker (called after process spawn, before accepting tasks)
    /// This is where workers load models, establish connections, etc.
    func initialize() async throws
    
    /// Handle a single task
    /// - Parameter task: The task to execute
    /// - Returns: The result of the task
    func handleTask(_ task: SubprocessTask<Input, Output>) async -> SubprocessResult<Output>
    
    /// Clean up resources (called before process termination)
    func cleanup() async
    
    /// Check if the worker is still healthy
    /// - Returns: true if the worker can accept more tasks
    func isHealthy() -> Bool
}

// MARK: - Worker State

/// State of a single worker process
public enum WorkerState: Sendable {
    case notStarted
    case initializing
    case ready
    case busy
    case recycling
    case terminated
    case failed(Error)
}

// MARK: - Worker Process Info

/// Information about a worker process
public struct WorkerInfo: Sendable {
    public let id: UUID
    public let processId: pid_t?
    public let state: WorkerState
    public let tasksCompleted: Int
    public let createdAt: ContinuousClock.Instant
    public let lastUsedAt: ContinuousClock.Instant?
    
    public init(
        id: UUID = UUID(),
        processId: pid_t? = nil,
        state: WorkerState = .notStarted,
        tasksCompleted: Int = 0,
        createdAt: ContinuousClock.Instant = ContinuousClock.now,
        lastUsedAt: ContinuousClock.Instant? = nil
    ) {
        self.id = id
        self.processId = processId
        self.state = state
        self.tasksCompleted = tasksCompleted
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
    
    /// Create a new info with updated state
    public func withUpdatedState(_ newState: WorkerState) -> WorkerInfo {
        return WorkerInfo(
            id: id,
            processId: processId,
            state: newState,
            tasksCompleted: tasksCompleted,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt
        )
    }
    
    /// Create a new info with updated lastUsedAt
    public func withUpdatedLastUsed(_ newLastUsed: ContinuousClock.Instant?) -> WorkerInfo {
        return WorkerInfo(
            id: id,
            processId: processId,
            state: state,
            tasksCompleted: tasksCompleted,
            createdAt: createdAt,
            lastUsedAt: newLastUsed
        )
    }
    
    /// Create a new info with incremented task count
    public func withIncrementedTasks() -> WorkerInfo {
        return WorkerInfo(
            id: id,
            processId: processId,
            state: state,
            tasksCompleted: tasksCompleted + 1,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt
        )
    }
}

// MARK: - Pool Metrics

/// Metrics for monitoring pool performance
public struct PoolMetrics: Sendable {
    public let poolSize: Int
    public let activeWorkers: Int
    public let idleWorkers: Int
    public let busyWorkers: Int
    public let queuedTasks: Int
    public let totalTasksCompleted: Int
    public let totalTasksFailed: Int
    public let averageTaskDuration: TimeInterval?
    public let averageSpawnLatency: TimeInterval?
    public let lastSpawnLatency: TimeInterval?
    public let workerUtilization: Double // 0.0 to 1.0
    public let mlWorkerMetrics: MLPoolMetrics? // MLWorkerPool-specific metrics
    public let mcWorkerMetrics: MCPPoolMetrics? // MCPWorkerPool-specific metrics
    
    public init(
        poolSize: Int,
        activeWorkers: Int,
        idleWorkers: Int,
        busyWorkers: Int,
        queuedTasks: Int,
        totalTasksCompleted: Int,
        totalTasksFailed: Int,
        averageTaskDuration: TimeInterval? = nil,
        averageSpawnLatency: TimeInterval? = nil,
        lastSpawnLatency: TimeInterval? = nil,
        workerUtilization: Double = 0.0,
        mlWorkerMetrics: MLPoolMetrics? = nil,
        mcWorkerMetrics: MCPPoolMetrics? = nil
    ) {
        self.poolSize = poolSize
        self.activeWorkers = activeWorkers
        self.idleWorkers = idleWorkers
        self.busyWorkers = busyWorkers
        self.queuedTasks = queuedTasks
        self.totalTasksCompleted = totalTasksCompleted
        self.totalTasksFailed = totalTasksFailed
        self.averageTaskDuration = averageTaskDuration
        self.averageSpawnLatency = averageSpawnLatency
        self.lastSpawnLatency = lastSpawnLatency
        self.workerUtilization = workerUtilization
        self.mlWorkerMetrics = mlWorkerMetrics
        self.mcWorkerMetrics = mcWorkerMetrics
    }
}

// MARK: - Pool Configuration

/// Configuration for a worker pool
public struct PoolConfiguration: Sendable {
    public let poolSize: Int
    public let maxIdleSeconds: Int
    public let maxTasksPerWorker: Int
    public let spawnTimeout: TimeInterval
    public let recycleOnMaxTasks: Bool
    
    public init(
        poolSize: Int = 1,
        maxIdleSeconds: Int = 300, // 5 minutes default
        maxTasksPerWorker: Int = 1000,
        spawnTimeout: TimeInterval = 10.0,
        recycleOnMaxTasks: Bool = true
    ) {
        self.poolSize = poolSize
        self.maxIdleSeconds = maxIdleSeconds
        self.maxTasksPerWorker = maxTasksPerWorker
        self.spawnTimeout = spawnTimeout
        self.recycleOnMaxTasks = recycleOnMaxTasks
    }
    
    /// Create configuration from a worker type
    public init<W: SubprocessWorker>(for workerType: W.Type) {
        self.poolSize = workerType.poolSize
        self.maxIdleSeconds = workerType.maxIdleSeconds
        self.maxTasksPerWorker = workerType.maxTasksPerWorker
        self.spawnTimeout = 10.0
        self.recycleOnMaxTasks = true
    }
}

// MARK: - ProcessPool

/// A pool of subprocess workers of a specific type
/// 
/// The pool manages:
/// - Spawning worker processes on demand
/// - Maintaining a pool of ready workers
/// - Dispatching tasks to workers
/// - Recycling workers based on configuration
/// - Collecting metrics
public actor ProcessPool<W: SubprocessWorker> {
    private let configuration: PoolConfiguration
    private let workerName: String
    private let executablePath: String
    private let executableArguments: [String]
    
    // Worker process tracking
    private var workers: [WorkerInfo] = []
    
    // Worker instance storage (Phase 1: in-process workers)
    // Maps worker ID to the actual worker instance
    private var workerInstances: [UUID: W] = [:]
    
    // Process tracking for out-of-process workers (Phase 2+)
    private var workerProcesses: [UUID: Process] = [:]
    
    // Specialized pool storage for MLWorkerPool integration
    internal var mlWorkerPool: MLWorkerPool? = nil
    
    // Specialized pool storage for MCPWorkerPool integration
    internal var mcWorkerPool: MCPWorkerPool? = nil
    
    private var taskQueue: [any Sendable] = []
    private var totalTasksCompleted: Int = 0
    private var totalTasksFailed: Int = 0
    private var totalSpawnLatencies: [TimeInterval] = []
    private var totalTaskDurations: [TimeInterval] = []
    
    /// Create a new process pool
    /// - Parameter configuration: The pool configuration
    public init(configuration: PoolConfiguration = PoolConfiguration()) {
        self.configuration = configuration
        self.workerName = String(describing: W.self)
        self.executablePath = W.executablePath
        self.executableArguments = W.executableArguments
    }
    
    /// Create a pool with default configuration for the worker type
    public init() {
        let config = PoolConfiguration(for: W.self)
        self.init(configuration: config)
    }
    
    /// Get the current metrics for this pool
    public func getMetrics() -> PoolMetrics {
        let activeWorkers = workers.filter { worker in
            if case .ready = worker.state { return true }
            if case .busy = worker.state { return true }
            if case .initializing = worker.state { return true }
            return false
        }.count
        
        let idleWorkers = workers.filter { worker in
            if case .ready = worker.state { return true }
            return false
        }.count
        
        let busyWorkers = workers.filter { worker in
            if case .busy = worker.state { return true }
            return false
        }.count
        
        let averageSpawnLatency = totalSpawnLatencies.isEmpty ? nil : 
            totalSpawnLatencies.reduce(0, +) / Double(totalSpawnLatencies.count)
        
        let averageTaskDuration = totalTaskDurations.isEmpty ? nil :
            totalTaskDurations.reduce(0, +) / Double(totalTaskDurations.count)
        
        let utilization = activeWorkers > 0 ? 
            Double(busyWorkers) / Double(activeWorkers) : 0.0
        
        // Include MLWorkerPool metrics if available
        var mlWorkerMetrics: MLPoolMetrics? = nil
        if let mlWorkerPool = mlWorkerPool {
            mlWorkerMetrics = mlWorkerPool.getMetrics()
        }
        
        // Include MCPWorkerPool metrics if available
        var mcWorkerMetrics: MCPPoolMetrics? = nil
        if let mcWorkerPool = mcWorkerPool {
            mcWorkerMetrics = mcWorkerPool.getMetrics()
        }
        
        return PoolMetrics(
            poolSize: configuration.poolSize,
            activeWorkers: activeWorkers,
            idleWorkers: idleWorkers,
            busyWorkers: busyWorkers,
            queuedTasks: taskQueue.count,
            totalTasksCompleted: totalTasksCompleted,
            totalTasksFailed: totalTasksFailed,
            averageTaskDuration: averageTaskDuration,
            averageSpawnLatency: averageSpawnLatency,
            lastSpawnLatency: totalSpawnLatencies.last,
            workerUtilization: utilization,
            mlWorkerMetrics: mlWorkerMetrics,
            mcWorkerMetrics: mcWorkerMetrics
        )
    }
    
    /// Spawn a new worker process
    /// For Phase 1, this creates an in-process worker.
    /// For Phase 2+, this will spawn actual separate processes with IPC.
    private func spawnWorker() async throws -> W {
        let startTime = ContinuousClock.now
        
        logger.info("Spawning new worker for type: \(self.workerName)")
        
        let workerId = UUID()
        
        // Phase 1: In-process worker (no separate process)
        // Phase 2+: Spawn actual process with IPC communication
        let _: Process? = nil
        let processId: pid_t? = nil
        
        // For Phase 2+, uncomment the following to spawn actual processes:
        /*
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.executablePath)
        process.arguments = self.executableArguments
        process.standardInput = Pipe()
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
        } catch {
            throw SubprocessError.spawnFailed(
                path: self.executablePath,
                reason: error.localizedDescription
            )
        }
        
        workerProcesses[workerId] = process
        */
        
        let spawnLatency = ContinuousClock.now - startTime
        let latencySeconds = Double(spawnLatency.components.attoseconds) / 1_000_000_000_000_000_000.0
        totalSpawnLatencies.append(latencySeconds)
        
        logger.info("Worker spawned in \(String(format: "%.3f", latencySeconds * 1000))ms for type: \(self.workerName)")
        
        // Create worker info
        let workerInfo = WorkerInfo(
            id: workerId,
            processId: processId,
            state: .initializing,
            createdAt: ContinuousClock.now
        )
        
        // Add to workers list
        workers.append(workerInfo)
        
        // Initialize the worker (creates in-process instance)
        let worker = try await initializeWorker(workerId: workerId)
        
        return worker
    }
    
    /// Initialize a worker instance
    /// For Phase 1, this creates an in-process worker instance.
    /// Future phases will implement IPC communication with separate processes.
    private func initializeWorker(workerId: UUID) async throws -> W {
        // Create a new in-process worker instance
        // Phase 1: In-process workers for simplicity
        // Phase 2+: IPC communication with separate processes
        
        let worker = W()
        
        // Initialize the worker
        try await worker.initialize()
        
        // Store the worker instance
        workerInstances[workerId] = worker
        
        // Update worker info with initialized state
        if let index = workers.firstIndex(where: { $0.id == workerId }) {
            workers[index] = workers[index].withUpdatedState(.ready).withUpdatedLastUsed(ContinuousClock.now)
        }
        
        return worker
    }
    
    /// Get a worker from the pool or spawn a new one if needed
    public func getWorker() async throws -> W {
        // Try to get an available worker
        if let availableWorkerIndex = workers.firstIndex(where: { worker in
            if case .ready = worker.state { return true }
            return false
        }) {
            let workerInfo = workers[availableWorkerIndex]
            
            // Mark as busy
            workers[availableWorkerIndex] = workerInfo.withUpdatedState(.busy).withUpdatedLastUsed(ContinuousClock.now)
            
            // Return the actual worker instance
            if let worker = workerInstances[workerInfo.id] {
                return worker
            }
        }
        
        // Check if we can spawn a new worker
        let activeWorkers = workers.filter { worker in
            if case .terminated = worker.state { return false }
            if case .failed = worker.state { return false }
            return true
        }.count
        
        if activeWorkers >= configuration.poolSize {
            throw SubprocessError.poolExhausted(
                workerType: self.workerName,
                maxPoolSize: configuration.poolSize
            )
        }
        
        // Spawn a new worker
        return try await spawnWorker()
    }
    
    /// Return a worker to the pool
    public func returnWorker(_ worker: W) async {
        // Find the worker by reference (using ObjectIdentifier as a workaround)
        // In Phase 1 with in-process workers, we track by the worker's position in storage
        
        // For now, mark all busy workers as ready
        // A more robust implementation would track worker -> workerInfo mapping
        for i in 0..<workers.count {
            if case .busy = workers[i].state {
                workers[i] = workers[i].withUpdatedState(.ready).withUpdatedLastUsed(ContinuousClock.now)
                // Increment task count
                workers[i] = workers[i].withIncrementedTasks()
                totalTasksCompleted += 1
                break
            }
        }
        
        logger.info("Worker returned to pool for type: \(self.workerName)")
    }
    
    /// Submit a task to the pool
    public func submitTask(_ input: W.Input) async -> SubprocessResult<W.Output> {
        let task = SubprocessTask<W.Input, W.Output>(input: input)
        
        do {
            let worker = try await getWorker()
            let result = await worker.handleTask(task)
            await returnWorker(worker)
            return result
        } catch let error as SubprocessError {
            return .failure(error)
        } catch {
            return .failure(.communicationFailed(
                workerType: self.workerName,
                reason: error.localizedDescription
            ))
        }
    }
    
    /// Recycle a worker
    private func recycleWorker(_ workerId: UUID) async {
        guard let index = workers.firstIndex(where: { $0.id == workerId }) else {
            return
        }
        
        let workerInfo = workers[index]
        
        // Terminate the process if it exists (for out-of-process workers)
        if let processId = workerInfo.processId, let _ = workerProcesses[workerId] {
            // Graceful termination: send SIGTERM
            // For Phase 1 in-process workers, this is a no-op
            // For Phase 2+ out-of-process workers, this will terminate the process
            #if os(macOS) || os(Linux)
            kill(processId, SIGTERM)
            #endif
            workerProcesses.removeValue(forKey: workerId)
        }
        
        // For in-process workers, call cleanup
        if let worker = workerInstances[workerId] {
            await worker.cleanup()
            workerInstances.removeValue(forKey: workerId)
        }
        
        // Update state
        workers[index] = workerInfo.withUpdatedState(.recycling)
        
        // Clean up after a delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        if workers.indices.contains(index) {
            workers[index] = workers[index].withUpdatedState(.terminated)
        }
    }
    
    /// Check and recycle idle workers
    public func checkIdleWorkers() async {
        let now = ContinuousClock.now
        
        for workerInfo in workers {
            if case .ready = workerInfo.state {
                if let lastUsed = workerInfo.lastUsedAt {
                    let idleDuration = now - lastUsed
                    let idleSeconds = Int(idleDuration.components.attoseconds / 1_000_000_000_000_000_000)
                    
                    if idleSeconds >= configuration.maxIdleSeconds {
                        logger.info("Recycling idle worker: \(workerInfo.id) (idle for \(idleSeconds)s)")
                        await recycleWorker(workerInfo.id)
                    }
                }
            }
            
            // Check task limit
            if configuration.recycleOnMaxTasks && 
               workerInfo.tasksCompleted >= configuration.maxTasksPerWorker {
                logger.info("Recycling worker after max tasks: \(workerInfo.id) (\(workerInfo.tasksCompleted) tasks)")
                await recycleWorker(workerInfo.id)
            }
        }
    }
    
    /// Shutdown the pool
    public func shutdown() async {
        logger.info("Shutting down pool for type: \(self.workerName)")
        
        // Shutdown MLWorkerPool if it exists
        if let mlWorkerPool = mlWorkerPool {
            await mlWorkerPool.shutdown()
            self.mlWorkerPool = nil
        }
        
        // Shutdown MCPWorkerPool if it exists
        if let mcWorkerPool = mcWorkerPool {
            await mcWorkerPool.shutdown()
            self.mcWorkerPool = nil
        }
        
        // Gracefully terminate all worker processes
        for workerInfo in workers {
            if let processId = workerInfo.processId, let _ = workerProcesses[workerInfo.id] {
                // Send SIGTERM for graceful termination
                #if os(macOS) || os(Linux)
                kill(processId, SIGTERM)
                #endif
            }
        }
        
        // Clean up all worker instances
        for (_, worker) in workerInstances {
            await worker.cleanup()
        }
        
        // Clear all storage
        workerInstances.removeAll()
        workerProcesses.removeAll()
        workers.removeAll()
        taskQueue.removeAll()
    }
}

// MARK: - SubprocessManager

/// Singleton manager for all subprocess pools
/// 
/// The SubprocessManager:
/// - Maintains a registry of all process pools
/// - Provides centralized configuration
/// - Collects global metrics
/// - Manages lifecycle of all workers
public actor SubprocessManager {
    
    /// Shared singleton instance
    public static let shared = SubprocessManager()
    
    private var pools: [ObjectIdentifier: Any] = [:]
    private var mcWorkerPool: MCPWorkerPool? = nil
    
    /// Initialize SubprocessManager
    /// - Note: Use `shared` instance for singleton access, or create new instance for testing
    public init() {}
    
    /// Get or create a pool for a worker type
    public func getPool<W: SubprocessWorker>(for type: W.Type) -> ProcessPool<W> {
        let typeId = ObjectIdentifier(W.self)
        
        if let existing = pools[typeId] as? ProcessPool<W> {
            return existing
        }
        
        let pool = ProcessPool<W>()
        pools[typeId] = pool
        
        logger.info("Created new pool for worker type: \(String(describing: W.self))")
        
        return pool
    }
    
    /// Submit a task to the appropriate pool
    public func submitTask<W: SubprocessWorker>(_ input: W.Input, workerType: W.Type) async -> SubprocessResult<W.Output> {
        let pool: ProcessPool<W> = getPool(for: workerType)
        return await pool.submitTask(input)
    }
    
    /// Get metrics for a specific pool
    public func getMetrics<W: SubprocessWorker>(for workerType: W.Type) async -> PoolMetrics {
        let pool: ProcessPool<W> = getPool(for: workerType)
        return await pool.getMetrics()
    }
    
    /// Get all pool metrics
    public func getAllMetrics() -> [String: any Sendable] {
        var result: [String: any Sendable] = [:]
        
        for (typeId, _) in pools {
            let typeName = String(describing: typeId)
            result[typeName] = "Pool for type: \(typeName)"
        }
        
        return result
    }
    
    /// Shutdown all pools
    public func shutdownAll() async {
        logger.info("Shutting down all subprocess pools")
        
        for (_, pool) in pools {
            if let typedPool = pool as? any ProcessPoolType {
                await typedPool.shutdownPool()
            }
        }
        
        pools.removeAll()
    }

    // MARK: - MCP Stream Handling

    /// Handle streaming MCP requests via MCPWorkerPool
    /// 
    /// This method bridges HTTP streaming to MCPWorkerPool processing,
    /// converting JSON-RPC requests to MCPWorkerInput and back.
    public func handleMCPStream(_ inputStream: AsyncThrowingStream<String, Error>) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Ensure MCPWorkerPool is initialized
                    let mcWorkerPool = try await getOrCreateMCPWorkerPool()
                    
                    // Process each line from the input stream
                    for try await line in inputStream {
                        // Parse JSON-RPC request
                        guard let data = line.data(using: .utf8) else {
                            continuation.yield("{\"error\":\"Invalid JSON data\"}")
                            continue
                        }
                        
                        let request: MCPJSONRPCRequest
                        do {
                            request = try JSONDecoder().decode(MCPJSONRPCRequest.self, from: data)
                        } catch {
                            continuation.yield("{\"error\":\"Invalid JSON-RPC request: \(error.localizedDescription)\"}")
                            continue
                        }
                        
                        // Convert to MCPWorkerInput
                        let input = MCPWorkerInput(
                            requestId: request.id,
                            method: request.method,
                            parameters: request.parameters,
                            clientId: "daemon-mcp"
                        )
                        
                        // Submit to MCPWorkerPool
                        let result = await mcWorkerPool.submitTask(input)
                        
                        // Convert response back to JSON-RPC
                        let output: MCPWorkerOutput
                        let errorMessage: String?
                        
                        switch result {
                        case .success(let workerOutput):
                            output = workerOutput
                            errorMessage = nil
                        case .failure(let error):
                            output = MCPWorkerOutput(
                                requestId: request.id,
                                result: nil,
                                error: error.localizedDescription,
                                executionTime: 0
                            )
                            errorMessage = error.localizedDescription
                        }
                        
                        let response = MCPJSONRPCResponse(
                            id: request.id,
                            result: output.result,
                            error: errorMessage
                        )
                        
                        let responseData = try JSONEncoder().encode(response)
                        if let responseString = String(data: responseData, encoding: .utf8) {
                            continuation.yield(responseString)
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Get or create MCPWorkerPool (lazy initialization)
    private func getOrCreateMCPWorkerPool() async throws -> MCPWorkerPool {
        if let existingPool = mcWorkerPool {
            return existingPool
        }
        
        let config = PoolConfiguration(
            poolSize: MCPWorker.poolSize,
            maxIdleSeconds: MCPWorker.maxIdleSeconds,
            maxTasksPerWorker: MCPWorker.maxTasksPerWorker,
            spawnTimeout: 30.0,
            recycleOnMaxTasks: true
        )
        
        let newPool = MCPWorkerPool(configuration: config)
        self.mcWorkerPool = newPool
        return newPool
    }
}

// MARK: - Convenience Extensions for Specific Worker Types

extension SubprocessManager {
    
    /// Convenience method to submit PDF sidecar tasks
    public func submitPDFTask(_ input: PDFSidecarWorkerInput) async -> SubprocessResult<PDFSidecarWorkerOutput> {
        return await submitTask(input, workerType: PDFSidecarWorker.self)
    }
    
    /// Get metrics for PDF sidecar pool
    public func getPDFMetrics() async -> PoolMetrics {
        return await getMetrics(for: PDFSidecarWorker.self)
    }
    

    
    /// Convenience method to submit benchmark tasks
    public func submitBenchmarkTask(_ input: BenchmarkWorkerInput) async -> SubprocessResult<BenchmarkWorkerOutput> {
        return await submitTask(input, workerType: BenchmarkWorker.self)
    }
    
    /// Get metrics for benchmark pool
    public func getBenchmarkMetrics() async -> PoolMetrics {
        return await getMetrics(for: BenchmarkWorker.self)
    }
    
    /// Convenience method to submit MCP tasks
    public func submitMCPTask(_ input: MCPWorkerInput) async -> SubprocessResult<MCPWorkerOutput> {
        return await submitTask(input, workerType: MCPWorker.self)
    }
    
    /// Get metrics for MCP pool
    public func getMCPMetrics() async -> PoolMetrics {
        return await getMetrics(for: MCPWorker.self)
    }
}

// MARK: - Type Erasure

/// Protocol for type-erased process pools
public protocol ProcessPoolType {
    func shutdownPool() async
}

extension ProcessPool: ProcessPoolType {
    public func shutdownPool() async {
        await self.shutdown()
    }
}

// MARK: - Default Worker Implementations

/// A concrete implementation of SubprocessWorker for testing
public struct TestWorker: SubprocessWorker {
    public typealias Input = String
    public typealias Output = String
    
    public init() {}
    
    public static var poolSize: Int = 2
    public static var maxIdleSeconds: Int = 60
    public static var maxTasksPerWorker: Int = 100
    public static var workerName: String = "TestWorker"
    public static var executablePath: String = "/usr/bin/echo"
    public static var executableArguments: [String] = ["test"]
    
    public func initialize() async throws {
        // No initialization needed for test worker
    }
    
    public func handleTask(_ task: SubprocessTask<String, String>) async -> SubprocessResult<String> {
        return .success("Processed: \(task.input)")
    }
    
    public func cleanup() async {
        // No cleanup needed
    }
    
    public func isHealthy() -> Bool {
        return true
    }
}
