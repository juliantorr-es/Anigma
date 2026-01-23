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
    private let mlWorkerAvailable: Bool
    private let fallbackAuthority: MockInferenceAuthority?
    
    init(mlWorkerPath: String? = nil, timeoutSeconds: Int = 120, defaultEngine: MLWorkerEngine = .llama) {
        // Resolve ml-worker path
        let resolvedPath: String
        if let path = mlWorkerPath {
            resolvedPath = path
        } else if let envPath = ProcessInfo.processInfo.environment["ML_WORKER_PATH"] {
            resolvedPath = envPath
        } else {
            // Default to build directory
            let currentDir = FileManager.default.currentDirectoryPath
            resolvedPath = "\(currentDir)/.build/debug/ml-worker"
        }
        self.mlWorkerPath = resolvedPath
        
        // Check if ml-worker executable exists and is executable
        var isExecutable = false
        if FileManager.default.fileExists(atPath: resolvedPath) {
            isExecutable = FileManager.default.isExecutableFile(atPath: resolvedPath)
        }
        self.mlWorkerAvailable = isExecutable
        self.timeoutSeconds = timeoutSeconds
        self.defaultEngine = defaultEngine
        
        // Create fallback mock authority if ml-worker not available
        self.fallbackAuthority = mlWorkerAvailable ? nil : MockInferenceAuthority()
        
        if !mlWorkerAvailable {
            print("[DaemonInferenceAuthority] ml-worker not available at \(resolvedPath), using mock fallback")
        } else {
            print("[DaemonInferenceAuthority] ml-worker available at \(resolvedPath)")
        }
    }
    
    func chatCompletion(
        _ request: InferenceRequest,
        priority: InferencePriority,
        speculativeConfig: SpeculativeConfiguration?,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // Use fallback mock authority if ml-worker not available
        guard mlWorkerAvailable else {
            guard let fallback = fallbackAuthority else {
                throw DaemonInferenceError("ML worker not available and no fallback")
            }
            return try await fallback.chatCompletion(request, priority: priority, speculativeConfig: speculativeConfig, context: context)
        }
        
        // Convert InferenceRequest to MLWorkerRequest for chat task
        let (mlRequest, requestDir, _) = try convertToMLWorkerRequest(request, task: .chat)
        
        defer {
            // Clean up temporary directory
            try? FileManager.default.removeItem(at: requestDir)
        }
        
        // Execute ml-worker
        let response = try await executeMLWorker(request: mlRequest)
        
        // Convert MLWorkerResponse to InferenceResponse
        return try convertToInferenceResponse(response, requestDir: requestDir, originalRequest: request)
    }
    
    func backgroundTask(
        _ task: InferenceRequest,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // Use fallback if needed, otherwise proceed with normal chatCompletion
        guard mlWorkerAvailable else {
            guard let fallback = fallbackAuthority else {
                throw DaemonInferenceError("ML worker not available and no fallback")
            }
            return try await fallback.backgroundTask(task, context: context)
        }
        
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
        return [
            InferencePlaneStatus(planeId: "daemon", isAvailable: mlWorkerAvailable, currentLoad: 0.0)
        ]
    }
    
    // MARK: - Private Methods
    
    private func convertToMLWorkerRequest(_ request: InferenceRequest, task: MLWorkerTask) throws -> (MLWorkerRequest, URL, URL) {
        // Create temporary directory for this request
        let tempDir = FileManager.default.temporaryDirectory
        let requestDir = tempDir.appendingPathComponent("ml-worker-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: requestDir, withIntermediateDirectories: true)
        
        // Create input file
        let inputFile = requestDir.appendingPathComponent("input.txt")
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
            outputDirectory: requestDir.path
        )
        
        let mlRequest = MLWorkerRequest(
            requestId: request.correlationId,
            runId: "daemon-\(UUID().uuidString)",
            stepId: UUID().uuidString,
            engine: engine,
            task: task,
            inputs: [MLArtifactRef(path: inputFile.path, hash: "input")],
            options: options
        )
        
        return (mlRequest, requestDir, inputFile)
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
                throw DaemonInferenceError("ML worker error: \(result.stderr)")
            } else {
                throw DaemonInferenceError("Failed to parse ML worker response: \(error)")
            }
        }
    }
    
    private func convertToInferenceResponse(_ response: MLWorkerResponse, requestDir: URL, originalRequest: InferenceRequest) throws -> InferenceResponse {
        guard response.status == .completed else {
            throw DaemonInferenceError("ML worker response status: \(response.status)")
        }
        
        // Extract output from first artifact
        // For chat tasks, ml-worker should output text file with response
        guard let firstArtifact = response.outputs.first else {
            throw DaemonInferenceError("ML worker response has no outputs")
        }
        
        // Read output file - path might be relative to requestDir
        let outputPath = firstArtifact.path
        let outputURL: URL
        if FileManager.default.fileExists(atPath: outputPath) {
            outputURL = URL(fileURLWithPath: outputPath)
        } else {
            // Try relative to requestDir
            outputURL = requestDir.appendingPathComponent(outputPath)
        }
        
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            // If no file, check for embedded output in response
            // For now, return placeholder
            return InferenceResponse(
                output: "[ML worker completed but no output file found]",
                usage: InferenceUsage(inputTokens: nil, outputTokens: nil),
                metadata: ["source": "daemon-ml-worker", "requestId": response.requestId]
            )
        }
        
        let outputData = try Data(contentsOf: outputURL)
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
                    continuation.resume(throwing: DaemonInferenceError("Command timed out after \(self.timeoutSeconds) seconds"))
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