//
//  MLWorkerClient.swift
//  AnigmaHostMac
//
//  Client wrapper for MLWorker streaming NDJSON service.
//

import Foundation
import MLWorkerCommon
import ContractsCore

// Use MLWorkerCommon types to avoid ambiguity with ContractsCore
public typealias WorkerMLArtifactRef = MLWorkerCommon.MLArtifactRef
public typealias WorkerMLResponse = MLWorkerCommon.MLWorkerResponse
public typealias WorkerMLMetrics = MLWorkerCommon.MLWorkerMetrics

/// Client for interacting with ML Worker processes.
public struct MLWorkerClient: Sendable {

    public enum MLWorkerError: Error, LocalizedError {
        case processStartFailed
        case engineNotSupported(String)
        case requestEncodingFailed
        case responseDecodingFailed
        case workerCrashed
        case timeout
        case noResponse

        public var errorDescription: String? {
            switch self {
            case .processStartFailed:
                return "Failed to start ML worker process"
            case .engineNotSupported(let engine):
                return "Engine not supported: \(engine)"
            case .requestEncodingFailed:
                return "Failed to encode ML request"
            case .responseDecodingFailed:
                return "Failed to decode ML response"
            case .workerCrashed:
                return "ML worker process crashed"
            case .timeout:
                return "ML worker request timed out"
            case .noResponse:
                return "No response from ML worker"
            }
        }
    }

    private let mlWorkerPath: String

    public init(mlWorkerPath: String? = nil) {
        self.mlWorkerPath = mlWorkerPath ?? Self.findMLWorkerBinary()
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent().path {
            let existing = environment["DYLD_LIBRARY_PATH"].map { "\($0):\(executableDirectory)" } ?? executableDirectory
            environment["DYLD_LIBRARY_PATH"] = existing
        }
        return environment
    }

    // MARK: - Binary Location

    private static func findMLWorkerBinary() -> String {
        // 1. Check /usr/local/bin (installed location)
        let installedPath = "/usr/local/bin/ml-worker"
        if FileManager.default.fileExists(atPath: installedPath) {
            return installedPath
        }

        // 2. Check relative to bundle for development
        if let bundlePath = Bundle.main.executableURL?.deletingLastPathComponent().path {
            // Check in the same directory as the executable
            let sameDir = (bundlePath as NSString).appendingPathComponent("ml-worker")
            if FileManager.default.fileExists(atPath: sameDir) {
                return sameDir
            }
            
            // Check if we are in a SwiftPM build directory (.build/debug or .build/release)
            // By going up from the bundle if it's in .build/debug/Anigma.app/Contents/MacOS
            let projectRoot = URL(fileURLWithPath: bundlePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
            
            let releasePath = (projectRoot as NSString).appendingPathComponent(".build/release/ml-worker")
            if FileManager.default.fileExists(atPath: releasePath) {
                return releasePath
            }
            
            let debugPath = (projectRoot as NSString).appendingPathComponent(".build/debug/ml-worker")
            if FileManager.default.fileExists(atPath: debugPath) {
                return debugPath
            }
        }

        // 3. Fallback to PATH lookup
        return "ml-worker"
    }

    // MARK: - Worker Management

    /// Start an ML worker for a specific engine
    public func startWorker(engine: String) async throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mlWorkerPath)
        process.arguments = ["--engine", engine]
        process.environment = processEnvironment()

        // Set up pipes for communication
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw MLWorkerError.processStartFailed
        }

        return process
    }

    /// Submit a task to an ML worker process
    public func submitTask(
        to process: Process,
        request: MLWorkerCommon.MLWorkerRequest
    ) async throws -> WorkerMLResponse {
        guard let stdin = process.standardInput as? Pipe,
              let stdout = process.standardOutput as? Pipe else {
            throw MLWorkerError.processStartFailed
        }

        // Encode request as NDJSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        guard let requestData = try? encoder.encode(request) else {
            throw MLWorkerError.requestEncodingFailed
        }

        // Write request with newline
        var data = requestData
        data.append(contentsOf: [0x0A]) // newline

        try stdin.fileHandleForWriting.write(contentsOf: data)

        // Read response
        let responseData = stdout.fileHandleForReading.availableData
        guard !responseData.isEmpty else {
            throw MLWorkerError.noResponse
        }

        // Decode response
        let decoder = JSONDecoder()
        guard let response = try? decoder.decode(WorkerMLResponse.self, from: responseData) else {
            throw MLWorkerError.responseDecodingFailed
        }

        return response
    }

    /// Check if ml-worker binary exists
    public func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: mlWorkerPath)
    }

    /// Get available engines
    public func availableEngines() -> [String] {
        ["mlx", "llama", "deepseek"]
    }

    // MARK: - High-Level Operations

    /// Run a single ML task with automatic worker lifecycle
    public func runTask(
        engine: String,
        task: MLTaskKind,
        inputs: [WorkerMLArtifactRef],
        options: MLTaskOptions? = nil
    ) async throws -> WorkerMLResponse {
        // Validate engine
        guard availableEngines().contains(engine.lowercased()) else {
            throw MLWorkerError.engineNotSupported(engine)
        }

        // Start worker
        let process = try await startWorker(engine: engine)
        defer {
            process.terminate()
        }

        // Create request
        let request = MLWorkerCommon.MLWorkerRequest(
            requestId: UUID().uuidString,
            runId: UUID().uuidString,
            stepId: UUID().uuidString,
            engine: MLWorkerEngine(rawValue: engine) ?? .mlx,
            task: task,
            inputs: inputs,
            options: options ?? MLTaskOptions(
                seed: 42,
                maxTokens: nil,
                temperature: nil,
                topP: nil,
                outputDirectory: nil
            )
        )

        // Submit and wait for response
        return try await submitTask(to: process, request: request)
    }

    /// Execute a governed ML run with ModelSpec + RunSpec contract
    /// Returns ExecutionReceipt for court-safe evidence chain
    public func executeGovernedRun(
        modelSpec: ModelSpec,
        runSpec: RunSpec
    ) async throws -> ExecutionReceipt {
        // Validate model is runnable
        guard modelSpec.isRunnable else {
            throw MLWorkerError.engineNotSupported("Model not runnable: \(modelSpec.id)")
        }

        // Validate backend matches model
        let backendLower = runSpec.backend.lowercased()
        let modelBackend = modelSpec.backend.rawValue
        guard backendLower == modelBackend else {
            throw MLWorkerError.engineNotSupported("Backend \(runSpec.backend) does not match model backend \(modelBackend)")
        }

        // Map backend to engine string
        let engineString = backendLower

        // Start worker
        let process = try await startWorker(engine: engineString)
        defer {
            process.terminate()
        }

        // Create MLWorker request from RunSpec
        let request = MLWorkerCommon.MLWorkerRequest(
            requestId: runSpec.runId,
            runId: runSpec.runId,
            stepId: UUID().uuidString,
            engine: MLWorkerEngine(rawValue: engineString) ?? .mlx,
            task: mapTaskKind(runSpec.taskKind),
            inputs: runSpec.inputs.map { input in
                WorkerMLArtifactRef(
                    path: input.path ?? "",
                    hash: input.hash
                )
            },
            options: MLTaskOptions(
                seed: runSpec.seed,
                maxTokens: runSpec.maxTokens,
                temperature: runSpec.temperature,
                topP: runSpec.topP,
                outputDirectory: nil
            )
        )

        // Execute
        let response = try await submitTask(to: process, request: request)

        // Extract model and tokenizer hashes from artifactHashes dict
        let modelHash = modelSpec.artifactHashes["model"] ?? modelSpec.canonicalHash
        let tokenizerHash = modelSpec.tokenizerHash ?? modelSpec.artifactHashes["tokenizer"]

        // Build ExecutionReceipt
        let receipt = ExecutionReceipt(
            runId: runSpec.runId,
            modelId: modelSpec.id,
            modelHash: modelHash,
            tokenizerHash: tokenizerHash,
            taskKind: runSpec.taskKind,
            backend: runSpec.backend,
            inputs: runSpec.inputs,
            outputs: response.outputs.map { artifact in
                ExecutionReceipt.Output(
                    artifactId: artifact.hash,
                    path: artifact.path,
                    hash: artifact.hash,
                    kind: "artifact"
                )
            },
            seed: runSpec.seed,
            temperature: runSpec.temperature,
            topP: runSpec.topP,
            maxTokens: runSpec.maxTokens,
            executionTimeMs: response.metrics?.durationMs,
            tokensGenerated: response.metrics?.totalTokens,
            timestamp: Date(),
            deterministicHash: "" // Computed next
        )

        // Compute deterministic hash of receipt
        var mutableReceipt = receipt
        mutableReceipt.deterministicHash = receipt.computeHash()

        return mutableReceipt
    }

    /// Map MLTaskKind to MLWorkerTask
    private func mapTaskKind(_ kind: MLTaskKind) -> MLWorkerTask {
        // MLTaskKind is already MLWorkerTask, just return it
        return kind
    }

    // MARK: - Status Response Types

    public struct WorkerStatusResponse: Codable, Sendable {
        public let installed: Bool
        public let version: String?
        public let availableEngines: [String]
        public let binaryPath: String

        public init(installed: Bool, version: String?, availableEngines: [String], binaryPath: String) {
            self.installed = installed
            self.version = version
            self.availableEngines = availableEngines
            self.binaryPath = binaryPath
        }
    }

    public struct TaskStatusResponse: Codable, Sendable, Identifiable {
        public let id: String
        public let requestId: String
        public let engine: String
        public let task: String
        public let status: String
        public let createdAt: Date
        public let completedAt: Date?
        public let metrics: WorkerMLMetrics?

        public init(
            id: String,
            requestId: String,
            engine: String,
            task: String,
            status: String,
            createdAt: Date,
            completedAt: Date? = nil,
            metrics: WorkerMLMetrics? = nil
        ) {
            self.id = id
            self.requestId = requestId
            self.engine = engine
            self.task = task
            self.status = status
            self.createdAt = createdAt
            self.completedAt = completedAt
            self.metrics = metrics
        }
    }

    /// Get ML worker status
    public func getStatus() async -> WorkerStatusResponse {
        let installed = isInstalled()
        let version = installed ? "1.0.0" : nil // Could parse from --version if available

        return WorkerStatusResponse(
            installed: installed,
            version: version,
            availableEngines: availableEngines(),
            binaryPath: mlWorkerPath
        )
    }
}

// MARK: - MLWorkerArtifact

/// ML worker output artifact namespace
public enum MLWorkerOutput {
    /// ML worker output artifact
    public struct MLWorkerArtifact: Codable, Sendable, Identifiable {
        public let id: String
        public let path: String
        public let hash: String
        public let kind: String

        public init(id: String, path: String, hash: String, kind: String) {
            self.id = id
            self.path = path
            self.hash = hash
            self.kind = kind
        }
    }
}
