//
//  DaemonInferenceAuthority.swift
//  AnigmaDaemonCore
//
//  Inference authority for daemon that executes ml-worker for actual inference.
//

import Foundation
import AnigmaCore
import InferenceCore
import ContractsCore

private struct DaemonInferenceError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
    
    init(_ message: String) {
        self.message = message
    }
}

actor DaemonInferenceAuthority: InferenceAuthority {
    private let mlWorkerPath: String
    private let timeoutSeconds: Int
    private let defaultEngine: MLWorkerEngine
    
    init(mlWorkerPath: String? = nil, timeoutSeconds: Int = 120, defaultEngine: MLWorkerEngine = .llama) {
        // Resolve ml-worker path
        if let path = mlWorkerPath {
            self.mlWorkerPath = path
        } else if let envPath = ProcessInfo.processInfo.environment["ML_WORKER_PATH"] {
            self.mlWorkerPath = envPath
        } else {
            // Default to build directory
            let currentDir = FileManager.default.currentDirectoryPath
            self.mlWorkerPath = "\(currentDir)/.build/debug/ml-worker"
        }
        self.timeoutSeconds = timeoutSeconds
        self.defaultEngine = defaultEngine
    }
    
    func chatCompletion(
        _ request: InferenceRequest,
        priority: InferencePriority,
        speculativeConfig: SpeculativeConfiguration?,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // Convert InferenceRequest to MLWorkerRequest for chat task
        let mlRequest = try convertToMLWorkerRequest(request, task: .chat)
        
        // Execute ml-worker
        let response = try await executeMLWorker(request: mlRequest)
        
        // Convert MLWorkerResponse to InferenceResponse
        return try convertToInferenceResponse(response, originalRequest: request)
    }
    
    func backgroundTask(
        _ task: InferenceRequest,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // For background tasks, use worker plane (lower priority)
        return try await chatCompletion(task, priority: .background, speculativeConfig: nil, context: context)
    }
    
    func rerank(
        _ request: RerankRequest,
        priority: InferencePriority,
        context: ExecutionContext
    ) async throws -> RerankResponse {
        // Rerank not supported in initial implementation
        throw DaemonInferenceError("Rerank not yet implemented in DaemonInferenceAuthority")
    }
    
    func getStatus() async -> [InferencePlaneStatus] {
        // Check if ml-worker executable exists and is executable
        let isAvailable = FileManager.default.isExecutableFile(atPath: mlWorkerPath)
        return [
            InferencePlaneStatus(planeId: "daemon", isAvailable: isAvailable, currentLoad: 0.0)
        ]
    }
    
    // MARK: - Private Methods
    
    private func convertToMLWorkerRequest(_ request: InferenceRequest, task: MLWorkerTask) throws -> MLWorkerRequest {
        // Create temporary input file with the request input
        let tempDir = FileManager.default.temporaryDirectory
        let inputFile = tempDir.appendingPathComponent(UUID().uuidString + ".txt")
        try request.input.write(to: inputFile, atomically: true, encoding: .utf8)
        
        // Determine engine from request options or use default
        let engine = request.options["engine"]?.stringValue.flatMap { MLWorkerEngine(rawValue: $0) } ?? defaultEngine
        
        // Extract options from InferenceRequest
        let seed = request.options["seed"]?.integerValue ?? 42
        let maxTokens = request.options["max_tokens"]?.integerValue ?? 512
        let temperature = request.options["temperature"]?.numberValue ?? 0.7
        let topP = request.options["top_p"]?.numberValue ?? 0.9
        
        let options = MLTaskOptions(
            seed: seed,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            outputDirectory: nil
        )
        
        return MLWorkerRequest(
            requestId: request.correlationId,
            runId: "daemon-\(UUID().uuidString)",
            stepId: UUID().uuidString,
            engine: engine,
            task: task,
            inputs: [MLArtifactRef(path: inputFile.path, hash: "input")],
            options: options
        )
    }
    
    private func executeMLWorker(request: MLWorkerRequest) async throws -> MLWorkerResponse {
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        let requestString = String(data: requestData, encoding: .utf8) ?? ""
        
        // Execute ml-worker with request as stdin (NDJSON)
        let result = try await executeCommand(
            command: mlWorkerPath,
            arguments: ["--engine", request.engine.rawValue],
            stdin: requestString
        )
        
        guard result.exitCode == 0 else {
            throw DaemonInferenceError("ML worker failed with exit code \(result.exitCode): \(result.stderr)")
        }
        
        // Parse response
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(MLWorkerResponse.self, from: Data(result.stdout.utf8))
        } catch {
            // If parsing fails, check if ml-worker returned error
            if !result.stderr.isEmpty {
                throw RuntimeError("ML worker error: \(result.stderr)")
            } else {
                throw RuntimeError("Failed to parse ML worker response: \(error)")
            }
        }
    }
    
    private func convertToInferenceResponse(_ response: MLWorkerResponse, originalRequest: InferenceRequest) throws -> InferenceResponse {
        guard response.status == .completed else {
            throw RuntimeError("ML worker response status: \(response.status)")
        }
        
        // Extract output from first artifact
        // For chat tasks, ml-worker should output text file with response
        guard let firstArtifact = response.outputs.first else {
            throw RuntimeError("ML worker response has no outputs")
        }
        
        // Read output file
        let outputPath = firstArtifact.path
        guard FileManager.default.fileExists(atPath: outputPath) else {
            // If no file, use raw output string from response
            let output = response.outputs.first?.metadata?["text"] ?? "No output generated"
            return InferenceResponse(
                output: output,
                usage: InferenceUsage(inputTokens: nil, outputTokens: nil),
                metadata: ["source": "daemon-ml-worker"]
            )
        }
        
        let outputData = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        // Estimate token usage from metrics if available
        let inputTokens = response.metrics?.tokensProcessed
        let outputTokens = response.metrics?.tokensGenerated
        
        return InferenceResponse(
            output: output,
            usage: InferenceUsage(inputTokens: inputTokens, outputTokens: outputTokens),
            metadata: ["source": "daemon-ml-worker", "requestId": response.requestId]
        )
    }
    
    private func executeCommand(
        command: String,
        arguments: [String],
        stdin: String? = nil
    ) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        // Setup pipes
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        if let stdin = stdin {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            
            // Write stdin data in background task
            let stdinData = Data(stdin.utf8)
            try stdinPipe.fileHandleForWriting.write(contentsOf: stdinData)
            try stdinPipe.fileHandleForWriting.close()
        }
        
        // Set environment
        process.environment = ProcessInfo.processInfo.environment
        
        try process.run()
        
        // Wait for completion with timeout
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var timedOut = false
                let startTime = Date()
                
                while process.isRunning {
                    if Date().timeIntervalSince(startTime) > Double(self.timeoutSeconds) {
                        process.terminate()
                        timedOut = true
                        break
                    }
                    usleep(100_000) // 0.1 second
                }
                
                if timedOut {
                    continuation.resume(throwing: RuntimeError("Command timed out after \(self.timeoutSeconds) seconds"))
                    return
                }
                
                // Read outputs
                let stdoutData = try? stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
                let stderrData = try? stderrPipe.fileHandleForReading.readToEnd() ?? Data()
                
                let stdout = String(data: stdoutData ?? Data(), encoding: .utf8) ?? ""
                let stderr = String(data: stderrData ?? Data(), encoding: .utf8) ?? ""
                
                continuation.resume(returning: (stdout, stderr, process.terminationStatus))
            }
        }
    }
}

// Helper extension to access InferenceOptionValue
private extension InferenceOptionValue {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
    
    var integerValue: Int? {
        if case .integer(let value) = self {
            return value
        }
        return nil
    }
    
    var numberValue: Double? {
        if case .number(let value) = self {
            return value
        }
        return nil
    }
    
    var boolValue: Bool? {
        if case .boolean(let value) = self {
            return value
        }
        return nil
    }
}