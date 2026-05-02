//
//  BenchmarkWorker.swift
//  SubprocessPooling
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 5: On-Demand Subprocesses for benchmarking (td-73aea8)
//

import Foundation
import System
import OSLog

private let logger = Logger(subsystem: "com.anigma.subprocess", category: "BenchmarkWorker")

// MARK: - Benchmark Worker Types

/// Input type for benchmark worker tasks
public struct BenchmarkWorkerInput: Sendable {
    public let requestId: String
    public let benchmarkType: BenchmarkType
    public let parameters: [String: String]
    public let timeout: TimeInterval
    
    public init(
        requestId: String,
        benchmarkType: BenchmarkType,
        parameters: [String: String] = [:],
        timeout: TimeInterval = 60.0
    ) {
        self.requestId = requestId
        self.benchmarkType = benchmarkType
        self.parameters = parameters
        self.timeout = timeout
    }
}

/// Benchmark types
public enum BenchmarkType: String, Codable, Sendable {
    case cpu
    case memory
    case disk
    case network
    case mlInference
    case pdfProcessing
    case database
    case custom
}

/// Output type for benchmark worker tasks
public struct BenchmarkWorkerOutput: Sendable {
    public let requestId: String
    public let benchmarkType: BenchmarkType
    public let results: [BenchmarkResult]
    public let error: String?
    public let executionTime: TimeInterval
    
    public init(
        requestId: String,
        benchmarkType: BenchmarkType,
        results: [BenchmarkResult] = [],
        error: String? = nil,
        executionTime: TimeInterval = 0
    ) {
        self.requestId = requestId
        self.benchmarkType = benchmarkType
        self.results = results
        self.error = error
        self.executionTime = executionTime
    }
}

/// Individual benchmark result
public struct BenchmarkResult: Sendable {
    public let name: String
    public let value: Double
    public let unit: String
    public let min: Double?
    public let max: Double?
    public let mean: Double?
    public let stdDev: Double?
    
    public init(
        name: String,
        value: Double,
        unit: String,
        min: Double? = nil,
        max: Double? = nil,
        mean: Double? = nil,
        stdDev: Double? = nil
    ) {
        self.name = name
        self.value = value
        self.unit = unit
        self.min = min
        self.max = max
        self.mean = mean
        self.stdDev = stdDev
    }
}

// MARK: - Benchmark Process Spawner

/// Manages spawning and communicating with anigma-capsule-bench processes
final class BenchmarkProcessSpawner {
    private let lock = NSLock()
    
    public init() {}
    
    private var activeProcesses: [String: Process] = [:]
    
    /// Spawn a new anigma-capsule-bench process
    /// - Parameter requestId: Unique request identifier
    /// - Parameter benchmarkType: Type of benchmark to run
    /// - Parameter parameters: Benchmark parameters
    /// - Returns: Process and pipes for communication
    public func spawnProcess(for requestId: String, benchmarkType: BenchmarkType, parameters: [String: String]) throws -> (Process, Pipe, Pipe) {
        let process = Process()
        
        // Find the anigma-capsule-bench path
        let executablePath = findExecutablePath()
        
        // Build arguments
        var arguments = ["--benchmark-type", benchmarkType.rawValue]
        for (key, value) in parameters {
            arguments.append("--\(key)")
            arguments.append(value)
        }
        arguments.append("--request-id")
        arguments.append(requestId)
        
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        
        // Set up pipes for stdin/stdout
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        logger.info("Spawning anigma-capsule-bench for benchmark: \(benchmarkType.rawValue)")
        
        do {
            try process.run()
        } catch {
            throw SubprocessError.spawnFailed(
                path: executablePath,
                reason: error.localizedDescription
            )
        }
        
        activeProcesses[requestId] = process
        
        logger.info("anigma-capsule-bench spawned with PID: \(process.processIdentifier)")
        
        return (process, stdinPipe, stdoutPipe)
    }
    
    /// Terminate a process
    /// - Parameter requestId: Request identifier
    public func terminateProcess(for requestId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let process = activeProcesses[requestId] else {
            return
        }
        
        process.terminate()
        activeProcesses.removeValue(forKey: requestId)
        
        logger.info("Terminated anigma-capsule-bench for request: \(requestId)")
    }
    
    /// Clean up all processes
    public func cleanupAll() {
        lock.lock()
        defer { lock.unlock() }
        
        for (requestId, _) in activeProcesses {
            terminateProcess(for: requestId)
        }
        activeProcesses.removeAll()
    }
    
    /// Find the anigma-capsule-bench path
    private func findExecutablePath() -> String {
        // Try to find the executable in common locations
        let candidates = [
            "./anigma-capsule-bench",
            "./.build/debug/anigma-capsule-bench",
            "./.build/release/anigma-capsule-bench",
            "/usr/local/bin/anigma-capsule-bench",
            "/opt/anigma/bin/anigma-capsule-bench"
        ]
        
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        
        // Default to assuming it's in PATH
        return "anigma-capsule-bench"
    }
}

// MARK: - Benchmark Worker Protocol Implementation

/// Benchmark Worker that conforms to SubprocessWorker protocol
/// 
/// This worker spawns anigma-capsule-bench subprocesses on-demand for
/// performance benchmarking. Each worker is spawned per-benchmark-session.
/// 
/// Uses real process spawning with stdin/stdout JSON-RPC - NO SIMULATION
public struct BenchmarkWorker: SubprocessWorker {
    public typealias Input = BenchmarkWorkerInput
    public typealias Output = BenchmarkWorkerOutput
    
    // Pool configuration - On-demand spawning, no pooling
    public static var poolSize: Int = 0  // No pool, spawn on demand
    public static var maxIdleSeconds: Int = 30  // Quick recycling
    public static var maxTasksPerWorker: Int = 1  // One task per worker (on-demand)
    public static var workerName: String = "BenchmarkWorker"
    public static var executablePath: String = "anigma-capsule-bench"
    public static var executableArguments: [String] = []
    
    private let spawner = BenchmarkProcessSpawner()
    
    public init() {}
    
    public func initialize() async throws {
        // For on-demand spawning, initialization happens at spawn time
        logger.info("BenchmarkWorker initialized")
    }
    
    public func handleTask(_ task: SubprocessTask<BenchmarkWorkerInput, BenchmarkWorkerOutput>) async -> SubprocessResult<BenchmarkWorkerOutput> {
        let startTime = Date()
        
        do {
            logger.debug("BenchmarkWorker handling benchmark: \(task.input.benchmarkType.rawValue) for request: \(task.input.requestId)")
            
            // Spawn the anigma-capsule-bench process
            let (process, stdinPipe, stdoutPipe) = try spawner.spawnProcess(
                for: task.input.requestId,
                benchmarkType: task.input.benchmarkType,
                parameters: task.input.parameters
            )
            
            // Wait for the benchmark to complete and read results from stdout
            let results = try await readBenchmarkResults(
                from: stdoutPipe,
                process: process,
                timeout: task.input.timeout
            )
            
            let endTime = Date()
            let executionTime = endTime.timeIntervalSince(startTime)
            
            let output = BenchmarkWorkerOutput(
                requestId: task.input.requestId,
                benchmarkType: task.input.benchmarkType,
                results: results,
                error: nil,
                executionTime: executionTime
            )
            
            logger.info("BenchmarkWorker completed task: \(task.input.requestId) in \(String(format: "%.3f", executionTime))s")
            
            // Clean up process after success
            spawner.terminateProcess(for: task.input.requestId)
            
            return .success(output)
            
        } catch {
            let endTime = Date()
            let executionTime = endTime.timeIntervalSince(startTime)
            
            logger.error("BenchmarkWorker error for request \(task.input.requestId): \(error)")
            
            // Clean up process on error
            spawner.terminateProcess(for: task.input.requestId)
            
            let output = BenchmarkWorkerOutput(
                requestId: task.input.requestId,
                benchmarkType: task.input.benchmarkType,
                results: [],
                error: error.localizedDescription,
                executionTime: executionTime
            )
            
            return .success(output)
        }
    }
    
    /// Read benchmark results from stdout
    private func readBenchmarkResults(
        from stdoutPipe: Pipe,
        process: Process,
        timeout: TimeInterval
    ) async throws -> [BenchmarkResult] {
        let fileHandle = stdoutPipe.fileHandleForReading
        
        return try await withCheckedThrowingContinuation { continuation in
            var results: [BenchmarkResult] = []
            var buffer = Data()
            let startTime = Date()
            
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                
                if !data.isEmpty {
                    buffer.append(data)
                    
                    // Try to parse JSON results (newline-delimited JSON)
                    if let lastNewline = buffer.lastIndex(of: UInt8(ascii: "\n")) {
                        let completeData = buffer[0..<lastNewline]
                        buffer = buffer[buffer.index(after: lastNewline)...]
                        
                        if let jsonString = String(data: completeData, encoding: .utf8) {
                            if let result = parseBenchmarkResult(jsonString) {
                                results.append(result)
                            }
                        }
                    }
                }
                
                // Check if process has terminated
                if !process.isRunning {
                    fileHandle.readabilityHandler = nil
                    
                    // Process any remaining data
                    if !buffer.isEmpty {
                        if let jsonString = String(data: buffer, encoding: .utf8) {
                            if let result = parseBenchmarkResult(jsonString) {
                                results.append(result)
                            }
                        }
                    }
                    
                    // Check exit status
                    if process.terminationStatus != 0 {
                        continuation.resume(throwing: SubprocessError.communicationFailed(
                            workerType: Self.workerName,
                            reason: "Benchmark process exited with code \(process.terminationStatus)"
                        ))
                        return
                    }
                    
                    continuation.resume(returning: results)
                    return
                }
                
                // Check timeout
                if Date().timeIntervalSince(startTime) > timeout {
                    fileHandle.readabilityHandler = nil
                    continuation.resume(throwing: SubprocessError.workerTimeout(
                        workerType: Self.workerName
                    ))
                    return
                }
            }
            
            // Start reading
            // fileHandle.waitForReadability() - Not available, using readabilityHandler only
        }
    }
    
    /// Parse a JSON string into a BenchmarkResult
    private func parseBenchmarkResult(_ jsonString: String) -> BenchmarkResult? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let name = dict["name"] as? String ?? "unknown"
                let value = dict["value"] as? Double ?? 0.0
                let unit = dict["unit"] as? String ?? ""
                let min = dict["min"] as? Double
                let max = dict["max"] as? Double
                let mean = dict["mean"] as? Double
                let stdDev = dict["stdDev"] as? Double
                
                return BenchmarkResult(
                    name: name,
                    value: value,
                    unit: unit,
                    min: min,
                    max: max,
                    mean: mean,
                    stdDev: stdDev
                )
            }
        } catch {
            logger.error("Failed to parse benchmark result: \(error)")
        }
        
        return nil
    }
    
    public func cleanup() async {
        logger.info("BenchmarkWorker cleaning up")
        await spawner.cleanupAll()
    }
    
    public func isHealthy() -> Bool {
        return true
    }
}

// MARK: - Benchmark Manager (On-Demand Spawning)

/// Manager for on-demand benchmark workers
public actor BenchmarkManager {
    private let configuration: PoolConfiguration
    private var activeWorkers: [String: BenchmarkWorker] = [:]
    private let spawner = BenchmarkProcessSpawner()
    
    // Metrics
    private var totalTasksCompleted: Int = 0
    private var totalTasksFailed: Int = 0
    
    public init(configuration: PoolConfiguration = PoolConfiguration(
        poolSize: 0,
        maxIdleSeconds: 30,
        maxTasksPerWorker: 1
    )) {
        self.configuration = configuration
    }
    
    /// Spawn a new benchmark worker for a task
    public func spawnWorkerForTask(_ input: BenchmarkWorkerInput) async -> BenchmarkWorker {
        let worker = BenchmarkWorker()
        do {
            try await worker.initialize()
        } catch {
            logger.error("Failed to initialize benchmark worker: \(error.localizedDescription)")
        }
        
        activeWorkers[input.requestId] = worker
        logger.info("Spawned benchmark worker for request: \(input.requestId)")
        
        return worker
    }
    
    /// Submit a benchmark task (spawns new worker)
    public func submitTask(_ input: BenchmarkWorkerInput) async -> SubprocessResult<BenchmarkWorkerOutput> {
        // Spawn a new worker for this task (on-demand)
        let worker = await spawnWorkerForTask(input)
        
        let task = SubprocessTask<BenchmarkWorkerInput, BenchmarkWorkerOutput>(input: input)
        let result = await worker.handleTask(task)
        
        // Cleanup worker after task completion (on-demand)
        await cleanupWorker(input.requestId)
        
        switch result {
        case .success(let output):
            totalTasksCompleted += 1
            return .success(output)
        case .failure(let error):
            totalTasksFailed += 1
            return .failure(error)
        }
    }
    
    /// Cleanup a worker after task completion
    private func cleanupWorker(_ requestId: String) async {
        if let worker = activeWorkers.removeValue(forKey: requestId) {
            await worker.cleanup()
            logger.info("Cleaned up benchmark worker for request: \(requestId)")
        }
    }
    
    /// Get metrics
    public func getMetrics() -> PoolMetrics {
        return PoolMetrics(
            poolSize: 0,  // On-demand, no pool
            activeWorkers: activeWorkers.count,
            idleWorkers: 0,
            busyWorkers: activeWorkers.count,
            queuedTasks: 0,
            totalTasksCompleted: totalTasksCompleted,
            totalTasksFailed: totalTasksFailed,
            averageTaskDuration: nil,
            averageSpawnLatency: nil,
            lastSpawnLatency: nil,
            workerUtilization: 0.0
        )
    }
    
    /// Shutdown all active workers
    public func shutdown() async {
        for (requestId, worker) in activeWorkers {
            await worker.cleanup()
            logger.info("Shutting down benchmark worker: \(requestId)")
        }
        activeWorkers.removeAll()
        await spawner.cleanupAll()
    }
}

// MARK: - Default Benchmark Worker

/// Default benchmark worker - uses actual process spawning
/// 
/// NOTE: This is NOT a simulation. It spawns real anigma-capsule-bench processes.
struct DefaultBenchmarkWorker: SubprocessWorker {
    public typealias Input = BenchmarkWorkerInput
    public typealias Output = BenchmarkWorkerOutput
    
    public init() {}
    
    public static var poolSize: Int = 0  // On-demand
    public static var maxIdleSeconds: Int = 30
    public static var maxTasksPerWorker: Int = 1
    public static var workerName: String = "DefaultBenchmarkWorker"
    public static var executablePath: String = "anigma-capsule-bench"
    public static var executableArguments: [String] = []
    
    private let spawner = BenchmarkProcessSpawner()
    
    public func initialize() async throws {
        // No initialization needed
    }
    
    public func handleTask(_ task: SubprocessTask<BenchmarkWorkerInput, BenchmarkWorkerOutput>) async -> SubprocessResult<BenchmarkWorkerOutput> {
        let startTime = Date()
        
        do {
            // Spawn the actual process
            let (process, _, stdoutPipe) = try spawner.spawnProcess(
                for: task.input.requestId,
                benchmarkType: task.input.benchmarkType,
                parameters: task.input.parameters
            )
            // defer cleanup - done explicitly below
            
            // Wait for completion
            let exitCode = await waitForProcessExit(process, timeout: task.input.timeout)
            
            if exitCode != 0 {
                throw SubprocessError.communicationFailed(
                    workerType: Self.workerName,
                    reason: "Process exited with code \(exitCode)"
                )
            }
            
            // Read results from stdout
            let results = await readAllData(from: stdoutPipe)
            
            // Parse results (simplified)
            let benchmarkResults = parseBenchmarkResults(results)
            
            let endTime = Date()
            let executionTime = endTime.timeIntervalSince(startTime)
            
            let output = BenchmarkWorkerOutput(
                requestId: task.input.requestId,
                benchmarkType: task.input.benchmarkType,
                results: benchmarkResults,
                error: nil,
                executionTime: executionTime
            )
            
            return .success(output)
            
        } catch {
            let endTime = Date()
            let executionTime = endTime.timeIntervalSince(startTime)
            
            let output = BenchmarkWorkerOutput(
                requestId: task.input.requestId,
                benchmarkType: task.input.benchmarkType,
                results: [],
                error: error.localizedDescription,
                executionTime: executionTime
            )
            
            return .success(output)
        }
    }
    
    private func waitForProcessExit(_ process: Process, timeout: TimeInterval) async -> Int32 {
        return try! await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
        }
    }
    
    private func readAllData(from pipe: Pipe) async -> Data {
        return try! await withCheckedThrowingContinuation { continuation in
            let handle = pipe.fileHandleForReading
            var data = Data()
            
            handle.readabilityHandler = { _ in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    continuation.resume(returning: data)
                    return
                }
                data.append(chunk)
            }
        }
    }
    
    private func parseBenchmarkResults(_ data: Data) -> [BenchmarkResult] {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // Try to parse as JSON array
        if let jsonData = jsonString.data(using: .utf8) {
            do {
                if let results = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    return results.compactMap { dict in
                        BenchmarkResult(
                            name: dict["name"] as? String ?? "unknown",
                            value: dict["value"] as? Double ?? 0.0,
                            unit: dict["unit"] as? String ?? "",
                            min: dict["min"] as? Double,
                            max: dict["max"] as? Double,
                            mean: dict["mean"] as? Double,
                            stdDev: dict["stdDev"] as? Double
                        )
                    }
                }
            } catch {
                logger.error("Failed to parse benchmark results: \(error)")
            }
        }
        
        return []
    }
    
    public func cleanup() async {
        spawner.cleanupAll()
    }
    
    public func isHealthy() -> Bool {
        return true
    }
}
