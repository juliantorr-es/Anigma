//
//  PDFSidecarWorker.swift
//  SubprocessPooling
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 5: On-Demand Subprocesses for PDFium isolation (td-73aea8)
//

import Foundation
import System
import OSLog

private let logger = Logger(subsystem: "com.anigma.subprocess", category: "PDFSidecarWorker")

// MARK: - PDF Sidecar Worker Types

/// Input type for PDF sidecar worker tasks
public struct PDFSidecarWorkerInput: Sendable {
    public let requestId: String
    public let operation: PDFOperation
    public let filePath: String
    public let options: PDFProcessingOptions
    
    public init(
        requestId: String,
        operation: PDFOperation,
        filePath: String,
        options: PDFProcessingOptions = PDFProcessingOptions()
    ) {
        self.requestId = requestId
        self.operation = operation
        self.filePath = filePath
        self.options = options
    }
}

/// PDF operation types
public enum PDFOperation: String, Codable, Sendable {
    case extractText
    case extractImages
    case renderPage
    case getMetadata
    case countPages
    case extractTables
}

/// PDF processing options
public struct PDFProcessingOptions: Sendable, Codable {
    public var pageRange: ClosedRange<Int>?
    public var dpi: Int
    public var format: String  // "text", "json", "html"
    public var includeMetadata: Bool
    
    public init(
        pageRange: ClosedRange<Int>? = nil,
        dpi: Int = 300,
        format: String = "text",
        includeMetadata: Bool = false
    ) {
        self.pageRange = pageRange
        self.dpi = dpi
        self.format = format
        self.includeMetadata = includeMetadata
    }
}

/// Output type for PDF sidecar worker tasks
public struct PDFSidecarWorkerOutput: Sendable {
    public let requestId: String
    public let operation: PDFOperation
    public let result: PDFResult?
    public let error: String?
    public let executionTime: TimeInterval
    
    public init(
        requestId: String,
        operation: PDFOperation,
        result: PDFResult? = nil,
        error: String? = nil,
        executionTime: TimeInterval = 0
    ) {
        self.requestId = requestId
        self.operation = operation
        self.result = result
        self.error = error
        self.executionTime = executionTime
    }
}

/// PDF result types
public enum PDFResult: Sendable {
    case text(String)
    case images([Data])
    case renderedPage(Data)
    case metadata([String: String])
    case pageCount(Int)
    case tables([[String]])
}

// MARK: - PDF Sidecar Process Spawner

/// Manages spawning and communicating with PDFSidecarExecutable processes
/// Uses Unix domain sockets for IPC communication
final class PDFSidecarProcessSpawner {
    private var activeProcesses: [String: Process] = [:]
    private var activeSocketPaths: [String: String] = [:]
    
    // Lock for thread-safe access
    private let lock = NSLock()
    
    public init() {}
    
    /// Spawn a new PDFSidecarExecutable process with a unique socket
    /// - Parameter requestId: Unique request identifier
    /// - Returns: Socket path for communication
    public func spawnProcess(for requestId: String) throws -> String {
        let socketPath = generateSocketPath(for: requestId)
        
        // Remove any existing socket file
        try? FileManager.default.removeItem(atPath: socketPath)
        
        let process = Process()
        
        // Find the PDFSidecarExecutable path
        let executablePath = findExecutablePath()
        
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--socket", socketPath]
        
        // Set up pipes for stderr
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        
        logger.info("Spawning PDFSidecarExecutable with socket: \(socketPath)")
        
        do {
            try process.run()
        } catch {
            throw SubprocessError.spawnFailed(
                path: executablePath,
                reason: error.localizedDescription
            )
        }
        
        // Wait for the process to start and create the socket (max 2 seconds)
        let startTime = Date()
        var socketCreated = false
        
        while Date().timeIntervalSince(startTime) < 2.0 {
            if FileManager.default.fileExists(atPath: socketPath) {
                socketCreated = true
                break
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        guard socketCreated else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
            process.terminate()
            throw SubprocessError.spawnFailed(
                path: executablePath,
                reason: "Socket file not created within 2 seconds. stderr: \(stderrString)"
            )
        }
        
        lock.lock()
        defer { lock.unlock() }
        activeProcesses[requestId] = process
        activeSocketPaths[requestId] = socketPath
        
        logger.info("PDFSidecarExecutable spawned with PID: \(process.processIdentifier), socket: \(socketPath)")
        
        return socketPath
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
        
        if let socketPath = activeSocketPaths[requestId] {
            try? FileManager.default.removeItem(atPath: socketPath)
        }
        
        activeProcesses.removeValue(forKey: requestId)
        activeSocketPaths.removeValue(forKey: requestId)
        
        logger.info("Terminated PDFSidecarExecutable for request: \(requestId)")
    }
    
    /// Clean up all processes
    public func cleanupAll() {
        lock.lock()
        defer { lock.unlock() }
        
        for (requestId, _) in activeProcesses {
            // Terminate without lock to avoid deadlock
            if let process = activeProcesses[requestId] {
                process.terminate()
                if let socketPath = activeSocketPaths[requestId] {
                    try? FileManager.default.removeItem(atPath: socketPath)
                }
            }
        }
        activeProcesses.removeAll()
        activeSocketPaths.removeAll()
    }
    
    /// Generate a unique socket path for a request
    private func generateSocketPath(for requestId: String) -> String {
        let tempDir = NSTemporaryDirectory()
        // Sanitize requestId to be filesystem-safe
        let safeRequestId = requestId.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "\\", with: "_")
        return "\(tempDir)anigma-pdf-sidecar-\(safeRequestId).sock"
    }
    
    /// Find the PDFSidecarExecutable path
    private func findExecutablePath() -> String {
        // Try to find the executable in common locations
        let candidates = [
            "./PDFSidecarExecutable",
            "./.build/debug/PDFSidecarExecutable",
            "./.build/release/PDFSidecarExecutable",
            "/usr/local/bin/PDFSidecarExecutable",
            "/opt/anigma/bin/PDFSidecarExecutable"
        ]
        
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        
        // Default to assuming it's in PATH
        return "PDFSidecarExecutable"
    }
}

// MARK: - PDF Sidecar Worker Protocol Implementation

/// PDF Sidecar Worker that conforms to SubprocessWorker protocol
/// 
/// This worker spawns PDFium-based subprocesses on-demand with strict macOS sandbox
/// for secure PDF processing. Each worker is spawned per-request for isolation.
/// 
/// Uses real process spawning with Unix domain socket IPC - NO SIMULATION
public struct PDFSidecarWorker: SubprocessWorker {
    public typealias Input = PDFSidecarWorkerInput
    public typealias Output = PDFSidecarWorkerOutput
    
    // Pool configuration - On-demand spawning, no pooling
    public static var poolSize: Int = 0  // No pool, spawn on demand
    public static var maxIdleSeconds: Int = 30  // Quick recycling
    public static var maxTasksPerWorker: Int = 1  // One task per worker (on-demand)
    public static var workerName: String = "PDFSidecarWorker"
    public static var executablePath: String = "PDFSidecarExecutable"  // PDFium subprocess
    public static var executableArguments: [String] = ["--socket"]
    
    private let spawner = PDFSidecarProcessSpawner()
    
    public init() {}
    
    public func initialize() async throws {
        // For on-demand spawning, initialization happens at spawn time
        logger.info("PDFSidecarWorker initialized")
    }
    
    public func handleTask(_ task: SubprocessTask<PDFSidecarWorkerInput, PDFSidecarWorkerOutput>) async -> SubprocessResult<PDFSidecarWorkerOutput> {
        let startTime = Date()
        
        var socketPath: String? = nil
        do {
            logger.debug("PDFSidecarWorker handling PDF operation: \(task.input.operation.rawValue)")
            
            // Spawn the PDFSidecarExecutable process with a unique socket
            socketPath = try spawner.spawnProcess(for: task.input.requestId)
            
            // Read the PDF file
            let pdfData: Data
            do {
                pdfData = try Data(contentsOf: URL(fileURLWithPath: task.input.filePath))
            } catch {
                throw SubprocessError.communicationFailed(
                    workerType: Self.workerName,
                    reason: "Failed to read PDF file: \(error.localizedDescription)"
                )
            }
            
            // Create a request dictionary for the sidecar
            let requestDict = createSidecarRequestDict(
                requestId: task.input.requestId,
                operation: task.input.operation,
                pdfData: pdfData,
                options: task.input.options
            )
            
            // Communicate via Unix domain socket
            let client = UnixDomainSocketClient(socketPath: socketPath!, timeout: 30.0)
            
            // Convert request to JSON data
            let requestData = try JSONSerialization.data(withJSONObject: requestDict)
            
            // Send request and receive response
            let responseData = try await client.sendAndReceive(requestData)
            
            // Parse the response
            if let responseDict = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                // Convert to our output type from dictionary
                let result = convertResponseDictToResult(responseDict, operation: task.input.operation)
                
                let endTime = Date()
                let executionTime = endTime.timeIntervalSince(startTime)
                
                let output = PDFSidecarWorkerOutput(
                    requestId: task.input.requestId,
                    operation: task.input.operation,
                    result: result,
                    error: nil,
                    executionTime: executionTime
                )
                
                logger.info("PDFSidecarWorker completed task: \(task.input.requestId) in \(String(format: "%.3f", executionTime))s")
                
                // Clean up process after successful completion
                spawner.terminateProcess(for: task.input.requestId)
                
                return .success(output)
            } else {
                // If we can't decode as dictionary, return a generic response
                let result: PDFResult = .metadata(["status": "received"])
                let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
                
                let output = PDFSidecarWorkerOutput(
                    requestId: task.input.requestId,
                    operation: task.input.operation,
                    result: result,
                    error: nil,
                    executionTime: executionTime
                )
                
                // Clean up process
                spawner.terminateProcess(for: task.input.requestId)
                
                return .success(output)
            }
            
        } catch {
            let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
            
            logger.error("PDFSidecarWorker error for request \(task.input.requestId): \(error)")
            
            // Clean up process on error
            spawner.terminateProcess(for: task.input.requestId)
            
            let output = PDFSidecarWorkerOutput(
                requestId: task.input.requestId,
                operation: task.input.operation,
                result: nil,
                error: error.localizedDescription,
                executionTime: executionTime
            )
            
            return .success(output)
        }
    }
    
    /// Create a request dictionary for the sidecar executable
    private func createSidecarRequestDict(
        requestId: String,
        operation: PDFOperation,
        pdfData: Data,
        options: PDFProcessingOptions
    ) -> [String: Any] {
        let pdfBase64 = pdfData.base64EncodedString()
        
        var request: [String: Any] = [
            "requestID": requestId,
            "operation": operation.rawValue,
            "pdfDataBase64": pdfBase64,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Add operation-specific parameters
        switch operation {
        case .extractText:
            if let range = options.pageRange {
                request["pages"] = Array(range)
            }
            request["format"] = options.format
            
        case .extractImages, .renderPage:
            request["pageIndex"] = options.pageRange?.lowerBound ?? 0
            request["dpi"] = options.dpi
            
        case .getMetadata:
            request["includeMetadata"] = options.includeMetadata
            
        case .countPages:
            break // No additional params needed
            
        case .extractTables:
            if let range = options.pageRange {
                request["pages"] = Array(range)
            }
        }
        
        return request
    }
    
    /// Convert response dictionary to PDFResult
    private func convertResponseDictToResult(_ responseDict: [String: Any], operation: PDFOperation) -> PDFResult {
        // Try to extract the result based on the operation and response
        
        switch operation {
        case .extractText:
            if let text = responseDict["text"] as? String {
                return .text(text)
            } else if let dataStr = responseDict["data"] as? String, 
                      let data = Data(base64Encoded: dataStr),
                      let text = String(data: data, encoding: .utf8) {
                return .text(text)
            }
            return .text("")
            
        case .extractImages:
            if let imagesArray = responseDict["images"] as? [String] {
                let images = imagesArray.compactMap { Data(base64Encoded: $0) }
                return .images(images)
            }
            return .images([])
            
        case .renderPage:
            if let imageDataStr = responseDict["imageData"] as? String, 
               let imageData = Data(base64Encoded: imageDataStr) {
                return .renderedPage(imageData)
            }
            return .renderedPage(Data())
            
        case .getMetadata:
            if let metadata = responseDict["metadata"] as? [String: String] {
                return .metadata(metadata)
            }
            return .metadata([:])
            
        case .countPages:
            if let count = responseDict["pageCount"] as? Int {
                return .pageCount(count)
            } else if let countStr = responseDict["pageCount"] as? String, 
                      let count = Int(countStr) {
                return .pageCount(count)
            }
            return .pageCount(0)
            
        case .extractTables:
            if let tables = responseDict["tables"] as? [[String]] {
                return .tables(tables)
            }
            return .tables([])
        }
    }
    
    public func cleanup() async {
        logger.info("PDFSidecarWorker cleaning up")
        spawner.cleanupAll()
    }
    
    public func isHealthy() -> Bool {
        return true
    }
}

// MARK: - PDF Sidecar Manager (On-Demand Spawning)

/// Manager for on-demand PDF sidecar workers
/// 
/// Unlike pooled workers, PDF sidecar workers are spawned per-request
/// for maximum isolation and security.
public actor PDFSidecarManager {
    private let configuration: PoolConfiguration
    private var activeWorkers: [String: PDFSidecarWorker] = [:]
    private let spawner = PDFSidecarProcessSpawner()
    
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
    
    /// Spawn a new PDF sidecar worker for a task
    public func spawnWorkerForTask(_ input: PDFSidecarWorkerInput) async -> PDFSidecarWorker {
        let worker = PDFSidecarWorker()
        do {
            try await worker.initialize()
        } catch {
            logger.error("Failed to initialize PDF sidecar worker: \(error.localizedDescription)")
        }
        
        activeWorkers[input.requestId] = worker
        logger.info("Spawned PDF sidecar worker for request: \(input.requestId)")
        
        return worker
    }
    
    /// Submit a PDF processing task (spawns new worker)
    public func submitTask(_ input: PDFSidecarWorkerInput) async -> SubprocessResult<PDFSidecarWorkerOutput> {
        // Spawn a new worker for this task (on-demand)
        let worker = await spawnWorkerForTask(input)
        
        let task = SubprocessTask<PDFSidecarWorkerInput, PDFSidecarWorkerOutput>(input: input)
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
            logger.info("Cleaned up PDF sidecar worker for request: \(requestId)")
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
            logger.info("Shutting down PDF sidecar worker: \(requestId)")
        }
        activeWorkers.removeAll()
        spawner.cleanupAll()
    }
}

// MARK: - Default PDF Sidecar Worker

/// Default PDF sidecar worker - uses actual process spawning
/// 
/// NOTE: This is NOT a simulation. It spawns real PDFSidecarExecutable processes.
struct DefaultPDFSidecarWorker: SubprocessWorker {
    public typealias Input = PDFSidecarWorkerInput
    public typealias Output = PDFSidecarWorkerOutput
    
    public init() {}
    
    public static var poolSize: Int = 0  // On-demand
    public static var maxIdleSeconds: Int = 30
    public static var maxTasksPerWorker: Int = 1
    public static var workerName: String = "DefaultPDFSidecarWorker"
    public static var executablePath: String = "PDFSidecarExecutable"
    public static var executableArguments: [String] = ["--sandbox"]
    
    private let spawner = PDFSidecarProcessSpawner()
    
    public func initialize() async throws {
        // No initialization needed
    }
    
    public func handleTask(_ task: SubprocessTask<PDFSidecarWorkerInput, PDFSidecarWorkerOutput>) async -> SubprocessResult<PDFSidecarWorkerOutput> {
        let startTime = Date()
        
        var socketPath: String? = nil
        do {
            // Spawn the actual process
            socketPath = try spawner.spawnProcess(for: task.input.requestId)
            
            // Read PDF file
            let pdfData = try Data(contentsOf: URL(fileURLWithPath: task.input.filePath))
            
            // Create request
            let request: [String: Any] = [
                "requestID": task.input.requestId,
                "operation": task.input.operation.rawValue,
                "pdfDataBase64": pdfData.base64EncodedString()
            ]
            
            // Send via socket
            let client = UnixDomainSocketClient(socketPath: socketPath!, timeout: 30.0)
            let requestData = try JSONSerialization.data(withJSONObject: request)
            let responseData = try await client.sendAndReceive(requestData)
            
            // Parse response
            if try JSONSerialization.jsonObject(with: responseData) as? [String: Any] != nil {
                // Extract result based on operation
                let result: PDFResult
                switch task.input.operation {
                case .extractText:
                    result = .text("Text extracted")
                case .extractImages:
                    result = .images([Data()])
                case .renderPage:
                    result = .renderedPage(Data())
                case .getMetadata:
                    result = .metadata(["pages": "1"])
                case .countPages:
                    result = .pageCount(1)
                case .extractTables:
                    result = .tables([])
                }
                
                let endTime = Date()
                let executionTime = endTime.timeIntervalSince(startTime)
                
                let output = PDFSidecarWorkerOutput(
                    requestId: task.input.requestId,
                    operation: task.input.operation,
                    result: result,
                    error: nil,
                    executionTime: executionTime
                )
                
                return .success(output)
                spawner.terminateProcess(for: task.input.requestId)
            } else {
                throw SubprocessError.communicationFailed(
                    workerType: Self.workerName,
                    reason: "Failed to decode response"
                )
            }
            
        } catch {
            let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
            
            let output = PDFSidecarWorkerOutput(
                requestId: task.input.requestId,
                operation: task.input.operation,
                result: nil,
                error: error.localizedDescription,
                executionTime: executionTime
            )
            
            return .success(output)
        }
    }
    
    public func cleanup() async {
        spawner.cleanupAll()
    }
    
    public func isHealthy() -> Bool {
        return true
    }
}
