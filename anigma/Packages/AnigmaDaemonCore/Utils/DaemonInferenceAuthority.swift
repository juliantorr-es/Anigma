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
import MLWorkerCommon
import OSLog

/// ML execution mode for the daemon
public enum MLExecutionMode: String, Sendable {
    /// Use in-process ML worker library (fastest, warm context)
    case inProcess
    /// Use legacy ml-worker binary subprocess (isolated)
    case subprocess
}

private struct DaemonInferenceError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
    
    init(_ message: String) {
        self.message = message
    }
}

actor DaemonInferenceAuthority: InferenceAuthority {
    private static let logger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "DaemonInferenceAuthority")
    private let mlWorkerPath: String
    private let timeoutSeconds: Int
    private let defaultEngine: MLWorkerCommon.MLWorkerEngine
    private let mlWorkerAvailable: Bool
    private let executionMode: MLExecutionMode
    private let inProcessWorker: MLWorker
    private let fallbackAuthority: MockInferenceAuthority?
    private let configuration: DaemonConfiguration?
    
    init(
        configuration: DaemonConfiguration? = nil,
        mlWorkerPath: String? = nil,
        timeoutSeconds: Int = 120,
        defaultEngine: MLWorkerCommon.MLWorkerEngine = .llama,
        executionMode: MLExecutionMode = .inProcess
    ) {
        // Resolve ml-worker path
        let resolvedPath: String
        if let path = mlWorkerPath {
            resolvedPath = path
        } else if let configPath = configuration?.daemon.mlWorkerPath {
            resolvedPath = configPath
        } else {
            // Alignment: Use governed runtime authority for paths
            let currentDir = RuntimeAuthority.shared.workingDirectory
            resolvedPath = "\(currentDir)/.build/debug/ml-worker"
        }
        self.mlWorkerPath = resolvedPath
        
        // Use configuration timeout if available
        let finalTimeout = configuration?.resources.timeoutSeconds ?? timeoutSeconds
        self.timeoutSeconds = finalTimeout
        
        // Determine execution mode from configuration if provided
        if let configMode = configuration?.daemon.executionMode {
            self.executionMode = (configMode == .subprocess) ? .subprocess : .inProcess
        } else {
            self.executionMode = executionMode
        }
        self.configuration = configuration
        
        // Initialize in-process worker
        self.inProcessWorker = MLWorker(engine: defaultEngine)
        
        // Check if ml-worker executable exists for subprocess mode
        var isExecutable = false
        if FileManager.default.fileExists(atPath: resolvedPath) {
            isExecutable = FileManager.default.isExecutableFile(atPath: resolvedPath)
        }
        self.mlWorkerAvailable = isExecutable
        self.timeoutSeconds = timeoutSeconds
        self.defaultEngine = defaultEngine
        
        // Create fallback mock authority if needed
        // If inProcess mode, we consider it "available" if MLWorker can initialize (usually it can)
        self.fallbackAuthority = (executionMode == .inProcess || mlWorkerAvailable) ? nil : MockInferenceAuthority()
        
        Self.logger.info("Initialized in \(self.executionMode.rawValue, privacy: .public) mode")
        if executionMode == .subprocess {
            if !mlWorkerAvailable {
                Self.logger.warning("ml-worker not available at \(resolvedPath, privacy: .public)")
            } else {
                Self.logger.info("ml-worker available at \(resolvedPath, privacy: .public)")
            }
        }
    }
    
    func chatCompletion(
        _ request: InferenceRequest,
        priority: InferencePriority,
        speculativeConfig: AnigmaCore.SpeculativeConfiguration?,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // Use fallback if nothing is available
        guard executionMode == .inProcess || mlWorkerAvailable else {
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
        
        // Execute based on mode
        let response: MLWorkerCommon.MLWorkerResponse
        switch executionMode {
        case .inProcess:
            response = try await inProcessWorker.performTaskAsync(mlRequest)
        case .subprocess:
            response = try await executeMLWorkerSubprocess(request: mlRequest)
        }
        
        // Convert MLWorkerResponse to InferenceResponse
        return try convertToInferenceResponse(response, requestDir: requestDir, originalRequest: request)
    }
    
    func backgroundTask(
        _ task: InferenceRequest,
        context: ExecutionContext
    ) async throws -> InferenceResponse {
        // Use fallback if needed
        guard executionMode == .inProcess || mlWorkerAvailable else {
            guard let fallback = fallbackAuthority else {
                throw DaemonInferenceError("ML worker not available and no fallback")
            }
            return try await fallback.backgroundTask(task, context: context)
        }
        
        // For background tasks, use worker plane (lower priority)
        return try await chatCompletion(task, priority: InferencePriority.background, speculativeConfig: nil as AnigmaCore.SpeculativeConfiguration?, context: context)
    }
    
    func rerank(
        _ request: AnigmaCore.RerankRequest,
        priority: InferencePriority,
        context: ExecutionContext
    ) async throws -> AnigmaCore.RerankResponse {
        // Rerank not supported in initial implementation
        throw DaemonInferenceError("Rerank not yet implemented in DaemonInferenceAuthority")
    }
    
    func getStatus() async -> [InferencePlaneStatus] {
        let isAvailable = executionMode == .inProcess || mlWorkerAvailable
        return [
            InferencePlaneStatus(planeId: "daemon", isAvailable: isAvailable, currentLoad: 0.0)
        ]
    }
    
    // MARK: - Private Methods
    
    private func convertToMLWorkerRequest(_ request: InferenceRequest, task: ContractsCore.MLWorkerTask) throws -> (MLWorkerCommon.MLWorkerRequest, URL, URL) {
        // Create temporary directory for this request
        let tempDir = FileManager.default.temporaryDirectory
        let requestDir = tempDir.appendingPathComponent("ml-worker-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: requestDir, withIntermediateDirectories: true)
        
        // Create input file
        let inputFile = requestDir.appendingPathComponent("input.txt")
        try request.input.write(to: inputFile, atomically: true, encoding: .utf8)
        
        // Determine engine from request options or use default
        let engine = request.options["engine"]?.asString.flatMap { MLWorkerCommon.MLWorkerEngine(rawValue: $0) } ?? defaultEngine
        
        // Extract options from InferenceRequest
        let seed = request.options["seed"]?.asInt ?? 42
        let maxTokens = request.options["max_tokens"]?.asInt ?? 512
        let temperature = request.options["temperature"]?.asDouble ?? 0.7
        let topP = request.options["top_p"]?.asDouble ?? 0.9
        
        let options = MLWorkerCommon.MLTaskOptions(
            seed: seed,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            outputDirectory: requestDir.path
        )
        
        let mlRequest = MLWorkerCommon.MLWorkerRequest(
            requestId: request.correlationId,
            runId: "daemon-\(UUID().uuidString)",
            stepId: UUID().uuidString,
            engine: engine,
            task: task,
            inputs: [MLWorkerCommon.MLArtifactRef(path: inputFile.path, hash: "input")],
            options: options
        )
        
        return (mlRequest, requestDir, inputFile)
    }
    
    private func executeMLWorkerSubprocess(request: MLWorkerCommon.MLWorkerRequest) async throws -> MLWorkerCommon.MLWorkerResponse {
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
            return try decoder.decode(MLWorkerCommon.MLWorkerResponse.self, from: Data(result.stdout.utf8))
        } catch {
            // If parsing fails, check if ml-worker returned error
            if !result.stderr.isEmpty {
                throw DaemonInferenceError("ML worker error: \(result.stderr)")
            } else {
                throw DaemonInferenceError("Failed to parse ML worker response: \(error)")
            }
        }
    }
    
    private func convertToInferenceResponse(_ response: MLWorkerCommon.MLWorkerResponse, requestDir: URL, originalRequest: InferenceRequest) throws -> InferenceResponse {
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
            Self.logger.warning("STUB INVOKED: DaemonInferenceAuthority.processInferenceResponse() - Output file not found")
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
        
        // Apply AnswerProvenanceGate validation
        let provenance = try applyProvenanceValidation(output: output, originalRequest: originalRequest)
        
        return InferenceResponse(
            output: output,
            usage: InferenceUsage(inputTokens: inputTokens, outputTokens: outputTokens),
            metadata: ["source": "daemon-ml-worker", "requestId": response.requestId],
            provenance: provenance
        )
    }
    
    private func applyProvenanceValidation(output: String, originalRequest: InferenceRequest) throws -> InferenceProvenance {
        // Create a basic provenance record with available information
        // In a full implementation, this would include actual sources and receipts from the inference pipeline
        
        let query = originalRequest.input
        let confidence = estimateConfidence(from: output)
        let topK = originalRequest.options["topK"]?.asInt
            ?? originalRequest.options["top_k"]?.asInt
            ?? 0
        let scanLimit = originalRequest.options["scanLimit"]?.asInt
            ?? originalRequest.options["scan_limit"]?.asInt
            ?? 0
        let threshold = originalRequest.options["threshold"]?.asDouble ?? 0.0
        let modelName = originalRequest.modelID ?? "daemon-ml-worker"
        let projectId = originalRequest.options["projectId"]?.asString
            ?? originalRequest.options["project_id"]?.asString
            ?? "daemon"
        let projectName = originalRequest.options["projectName"]?.asString
            ?? originalRequest.options["project_name"]?.asString
            ?? "Daemon"
        let sessionId = originalRequest.options["sessionId"]?.asString
            ?? originalRequest.options["session_id"]?.asString
            ?? originalRequest.correlationId
        let principalId = originalRequest.options["principalId"]?.asString
            ?? originalRequest.options["principal_id"]?.asString
            ?? "daemon"
        
        // Create minimal provenance record
        let provenanceRecord = AnswerProvenanceRecord(
            id: UUID().uuidString,
            query: query,
            answerText: output,
            modelName: modelName,
            projectId: projectId,
            projectName: projectName,
            sessionId: sessionId,
            principalId: principalId,
            topK: topK,
            scanLimit: scanLimit,
            threshold: threshold,
            confidence: confidence,
            sources: [], // No sources available in current pipeline
            receipts: [], // No receipts available in current pipeline
            missingContext: [],
            contextPolicy: AnswerProvenanceContextPolicy(),
            replay: AnswerProvenanceReplay(
                mode: "regenerate",
                replayable: false,
                deterministic: false,
                nondeterminismReasons: ["daemon inference provenance is synthesized without retrieval sources"],
                replayToken: originalRequest.correlationId,
                sourceGraphHash: "",
                contextPolicyHash: "",
                receiptChainHash: "",
                notes: "Daemon ML worker responses do not carry persisted source receipts."
            ),
            generatedAt: Date(),
            // The record is synthesized from the live request metadata.
        )
        
        // Apply provenance gate validation
        let gate = AnswerProvenanceGate(thresholds: .lenient) // Use lenient thresholds for initial integration
        let validationResult = gate.validateAndFilter(answerRecord: provenanceRecord)
        
        switch validationResult {
        case .grounded(let groundedAnswer):
            return InferenceProvenance(
                isGrounded: true,
                confidence: groundedAnswer.calibratedConfidence,
                coverageSummary: groundedAnswer.coverageSummary,
                missingContext: nil,
                sources: groundedAnswer.originalAnswer.sources,
                receipts: groundedAnswer.originalAnswer.receipts
            )
        case .abstention(let abstention):
            return InferenceProvenance(
                isGrounded: false,
                confidence: nil,
                coverageSummary: AnswerCoverageSummary(
                    sourceCount: abstention.sources.count,
                    highRelevanceCount: 0,
                    receiptCount: abstention.receipts.count,
                    missingContext: abstention.missingContext
                ),
                missingContext: abstention.missingContext,
                sources: abstention.sources,
                receipts: abstention.receipts
            )
        }
    }
    
    private func estimateConfidence(from output: String) -> Double {
        // Simple heuristic for confidence estimation
        // In a real implementation, this would come from the model or validation pipeline
        
        // Check for hedging language
        let hedgingPhrases = ["I'm not sure", "maybe", "possibly", "might be", "could be"]
        let containsHedging = hedgingPhrases.contains { output.lowercased().contains($0) }
        
        // Check for definitive language  
        let definitivePhrases = ["definitely", "certainly", "absolutely", "without doubt"]
        let containsDefinitive = definitivePhrases.contains { output.lowercased().contains($0) }
        
        // Simple confidence estimation
        if containsDefinitive {
            return 0.8
        } else if containsHedging {
            return 0.4
        } else {
            return 0.6 // Default confidence
        }
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
        if let configEnv = configuration?.environment {
            process.environment = configEnv
        } else {
            process.environment = ProcessInfo.processInfo.environment
        }
        
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
