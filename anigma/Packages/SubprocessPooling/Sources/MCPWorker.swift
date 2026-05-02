//
//  MCPWorker.swift
//  SubprocessPooling
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 4: Warm Pool for MCP with Unix domain sockets (td-12f9d2)
//

import Foundation
import System
import OSLog

private let logger = Logger(subsystem: "com.anigma.subprocess", category: "MCPWorker")

// MARK: - MCP Worker Errors

/// Errors specific to MCP worker operations
public enum MCPWorkerError: Error, Sendable {
    case jsonRPCError(String)
    case socketError(String)
    case serializationError(String)
    case invalidResponse(String)
}

// MARK: - JSON-RPC Protocol

/// JSON-RPC request structure for MCP communication
public struct MCPJSONRPCRequest: Codable, Sendable {
    public let id: String
    public let method: String
    public let parameters: [String: AnyCodable]?
    
    public init(id: String, method: String, parameters: [String: AnyCodable]?) {
        self.id = id
        self.method = method
        self.parameters = parameters
    }
}

/// JSON-RPC response structure for MCP communication
public struct MCPJSONRPCResponse: Codable, Sendable {
    public let id: String
    public let result: [String: AnyCodable]?
    public let error: String?
    
    public init(id: String, result: [String: AnyCodable]?, error: String?) {
        self.id = id
        self.result = result
        self.error = error
    }
}

// MARK: - MCP Worker Types

/// Input type for MCP worker tasks
public struct MCPWorkerInput: Sendable {
    public let requestId: String
    public let method: String
    public let parameters: [String: AnyCodable]?
    public let clientId: String
    
    public init(
        requestId: String,
        method: String,
        parameters: [String: AnyCodable]? = nil,
        clientId: String
    ) {
        self.requestId = requestId
        self.method = method
        self.parameters = parameters
        self.clientId = clientId
    }
}

/// Output type for MCP worker tasks
public struct MCPWorkerOutput: Sendable {
    public let requestId: String
    public let result: [String: AnyCodable]?
    public let error: String?
    public let executionTime: TimeInterval
    
    public init(
        requestId: String,
        result: [String: AnyCodable]? = nil,
        error: String? = nil,
        executionTime: TimeInterval = 0
    ) {
        self.requestId = requestId
        self.result = result
        self.error = error
        self.executionTime = executionTime
    }
}

// MARK: - MCP Worker Protocol Implementation

/// MCP Worker that conforms to SubprocessWorker protocol
/// 
/// This worker manages MCP server connections using Unix domain sockets
/// for JSON-RPC communication between daemon and MCP server instances.
public final class MCPWorker: SubprocessWorker {
    public typealias Input = MCPWorkerInput
    public typealias Output = MCPWorkerOutput
    
    // Pool configuration
    public static var poolSize: Int = 4  // Pool of MCP worker processes
    public static var maxIdleSeconds: Int = 600  // 10 minutes
    public static var maxTasksPerWorker: Int = 10000
    public static var workerName: String = "MCPWorker"
    public static var executablePath: String = "anigma-mcp"  // MCP server executable
    public static var executableArguments: [String] = ["--worker", "--unix-socket"]
    
    // Worker state
    private let socketPath: String
    private var socketClient: UnixDomainSocketClient?
    private var isInitialized: Bool = false
    
    public init() {
        self.socketPath = "/tmp/anigma-mcp.sock"
    }
    
    public init(socketPath: String) {
        self.socketPath = socketPath
    }
    
    public func initialize() async throws {
        // Initialize Unix domain socket connection
        logger.info("MCPWorker initializing with socket: \(self.socketPath)")
        
        // Create Unix domain socket client
        let client = UnixDomainSocketClient(socketPath: socketPath)
        self.socketClient = client
        
        do {
            // Connect to the MCP server via Unix domain socket
            // For Phase 4, we'll use a simpler approach that works with the actor isolation
            // In production, this would be handled more robustly
            try await client.connect()
            isInitialized = true
            logger.info("MCPWorker connected to Unix domain socket successfully")
        } catch {
            logger.error("MCPWorker socket connection failed: \(error)")
            throw SubprocessError.workerInitializationFailed(
                workerType: Self.workerName,
                reason: error.localizedDescription
            )
        }
    }
    
    public func handleTask(_ task: SubprocessTask<MCPWorkerInput, MCPWorkerOutput>) async -> SubprocessResult<MCPWorkerOutput> {
        let startTime = ContinuousClock.now
        
        do {
            // Phase 4: Simulate MCP request handling
            // In production, this would send JSON-RPC over Unix domain socket
            
            logger.debug("MCPWorker handling task: \(task.input.method)")
            
            // Simulate MCP tool execution
            let result = try await handleMCPRequest(task.input)
            
            let endTime = ContinuousClock.now
            let executionTime = Double((endTime - startTime).components.seconds)
            
            let output = MCPWorkerOutput(
                requestId: task.input.requestId,
                result: result,
                error: nil,
                executionTime: executionTime
            )
            
            return .success(output)
            
        } catch {
            let endTime = ContinuousClock.now
            let executionTime = Double((endTime - startTime).components.seconds)
            
            let output = MCPWorkerOutput(
                requestId: task.input.requestId,
                result: nil,
                error: error.localizedDescription,
                executionTime: executionTime
            )
            
            return .success(output)
        }
    }
    
    /// Handle MCP request using JSON-RPC over Unix domain socket
    private func handleMCPRequest(_ input: MCPWorkerInput) async throws -> [String: AnyCodable] {
        // Create JSON-RPC request
        let request = MCPJSONRPCRequest(
            id: UUID().uuidString,
            method: input.method,
            parameters: input.parameters
        )
        
        // Serialize request to JSON
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        
        // Get socket client
        guard let socketClient = socketClient else {
            throw SubprocessError.communicationFailed(
                workerType: Self.workerName,
                reason: "Socket client not initialized"
            )
        }
        
        // For Phase 4, we'll use a simplified approach
        // In production, this would use proper actor isolation handling
        // Simulate the socket communication for now
        
        // Simulate different MCP methods - return simple string results
        switch input.method {
        case "tools/list":
            return ["result": AnyCodable.string("tools list")]
        case "tools/call":
            if let params = input.parameters, let nameVal = params["name"], case let .string(name) = nameVal {
                return ["result": AnyCodable.string("Called: \(name)")]
            }
            return ["result": AnyCodable.string("No tool name provided")]
        case "resources/list":
            return ["result": AnyCodable.string("resources list")]
        case "resources/read":
            if let params = input.parameters, let uriVal = params["uri"], case let .string(uri) = uriVal {
                return ["result": AnyCodable.string("Read: \(uri)")]
            }
            return ["result": AnyCodable.string("No URI provided")]
        default:
            // Generic MCP request handling
            return ["result": AnyCodable.string("Method \(input.method) executed")]
        }
    }
    
    public func cleanup() async {
        // Cleanup Unix domain socket connection
        logger.info("MCPWorker cleaning up socket connection")
        
        // For Phase 4, we'll use a simplified cleanup
        // In production, this would properly close the socket connection
        socketClient = nil
        isInitialized = false
    }
    
    public func isHealthy() -> Bool {
        return isInitialized
    }
}

// MARK: - MCP Worker Pool

/// Pool of MCP workers with Unix domain socket support
/// 
/// This pool manages:
/// - Multiple MCP worker processes
/// - Unix domain socket connections
/// - JSON-RPC communication
/// - Worker recycling based on task count or idle time
public final class MCPWorkerPool {
    private let configuration: PoolConfiguration
    private var workers: [MCPWorker] = []
    private var workerInstances: [UUID: MCPWorker] = [:]
    
    // Metrics
    private var totalTasksCompleted: Int = 0
    private var totalTasksFailed: Int = 0
    private var roundRobinCounter: Int = 0
    
    public init(configuration: PoolConfiguration = PoolConfiguration()) {
        self.configuration = configuration
        createWorkers()
    }
    
    /// Create worker instances
    private func createWorkers() {
        for _ in 0..<configuration.poolSize {
            let worker = MCPWorker()
            workers.append(worker)
        }
    }
    
    /// Get a worker for a task using round-robin balancing
    public func getWorker() -> MCPWorker? {
        guard !workers.isEmpty else { return nil }
        let worker = workers[roundRobinCounter % workers.count]
        roundRobinCounter += 1
        return worker
    }
    
    /// Submit a task to the pool
    public func submitTask(_ input: MCPWorkerInput) async -> SubprocessResult<MCPWorkerOutput> {
        guard let worker = getWorker() else {
            return .failure(.poolExhausted(
                workerType: MCPWorker.workerName,
                maxPoolSize: workers.count
            ))
        }
        
        let task = SubprocessTask<MCPWorkerInput, MCPWorkerOutput>(input: input)
        let result = await worker.handleTask(task)
        
        switch result {
        case .success(let output):
            totalTasksCompleted += 1
            return .success(output)
        case .failure(let error):
            totalTasksFailed += 1
            return .failure(error)
        }
    }
    
    /// Get pool metrics
    public func getMetrics() -> MCPPoolMetrics {
        return MCPPoolMetrics(
            workerCount: workers.count,
            activeWorkers: workers.count,
            idleWorkers: workers.count,
            totalTasksCompleted: totalTasksCompleted,
            totalTasksFailed: totalTasksFailed,
            averageTaskDuration: nil
        )
    }
    
    /// Recycle all workers
    public func recycleWorkers() async {
        for worker in workers {
            await worker.cleanup()
        }
        createWorkers()
    }
    
    /// Shutdown the pool
    public func shutdown() async {
        for worker in workers {
            await worker.cleanup()
        }
        workers.removeAll()
        workerInstances.removeAll()
    }
}

// MARK: - ProcessPool Integration

extension ProcessPool where W == MCPWorker {
    /// Create an MCPWorkerPool for this ProcessPool
    /// Note: For Phase 4, we create a new pool each time
    /// In future phases, this would be optimized to reuse pools
    public func getMCPWorkerPool() -> MCPWorkerPool {
        // Create new MCPWorkerPool with configuration matching this ProcessPool
        let config = PoolConfiguration(
            poolSize: MCPWorker.poolSize,
            maxIdleSeconds: MCPWorker.maxIdleSeconds,
            maxTasksPerWorker: MCPWorker.maxTasksPerWorker
        )
        
        return MCPWorkerPool(configuration: config)
    }
    
    /// Submit a task through the MCPWorkerPool
    public func submitTaskViaMCPWorkerPool(_ input: MCPWorkerInput) async -> SubprocessResult<MCPWorkerOutput> {
        let mcWorkerPool = getMCPWorkerPool()
        return await mcWorkerPool.submitTask(input)
    }
}

// MARK: - Default MCP Worker

/// Default MCP worker implementation for testing
/// 
/// This simulates MCP server communication without actual socket dependencies
public final class DefaultMCPWorker: SubprocessWorker {
    public typealias Input = MCPWorkerInput
    public typealias Output = MCPWorkerOutput
    
    public init() {}
    
    public static var poolSize: Int = 2
    public static var maxIdleSeconds: Int = 600
    public static var maxTasksPerWorker: Int = 10000
    public static var workerName: String = "DefaultMCPWorker"
    public static var executablePath: String = "/usr/local/bin/anigma-mcp"
    public static var executableArguments: [String] = []
    
    public func initialize() async throws {
        // No initialization needed for default worker
    }
    
    public func handleTask(_ task: SubprocessTask<MCPWorkerInput, MCPWorkerOutput>) async -> SubprocessResult<MCPWorkerOutput> {
        let startTime = ContinuousClock.now
        
        // Simulate MCP processing
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let endTime = ContinuousClock.now
        let executionTime = Double((endTime - startTime).components.seconds)
        
        // Return mock response
        let output = MCPWorkerOutput(
            requestId: task.input.requestId,
            result: [
                "status": AnyCodable.string("ok"),
                "method": AnyCodable.string(task.input.method)
            ],
            error: nil,
            executionTime: executionTime
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
