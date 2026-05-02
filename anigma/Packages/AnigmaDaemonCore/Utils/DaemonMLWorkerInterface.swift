//
//  DaemonMLWorkerInterface.swift
//  AnigmaDaemonCore
//
//  ML Worker interface that actually executes ml-worker command in daemon context.
//

import Foundation
import AnigmaCore
import ContractsCore
import MLWorkerInterfaces

public struct DaemonMLWorkerInterface: MLWorkerInterface, Sendable {
    private let mlWorkerPath: String
    private let timeoutSeconds: Int
    
    public init(mlWorkerPath: String? = nil, timeoutSeconds: Int = 120) {
        // Resolve ml-worker path:
        // 1. Use provided path
        // 2. Check ML_WORKER_PATH environment variable
        // 3. Default to .build/debug/ml-worker relative to current directory
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
    }
    
    public func performMLTask(
        task: MLWorkerTaskKind,
        input: String,
        modelID: String?,
        options: [String: AnyHashable]
    ) async throws -> String {
        // Create temporary input file
        let tempDir = FileManager.default.temporaryDirectory
        let inputFile = tempDir.appendingPathComponent(UUID().uuidString + ".txt")
        try input.write(to: inputFile, atomically: true, encoding: .utf8)
        
        // Create temporary output file
        let outputFile = tempDir.appendingPathComponent(UUID().uuidString + ".out.txt")
        
        defer {
            // Clean up temp files
            try? FileManager.default.removeItem(at: inputFile)
            try? FileManager.default.removeItem(at: outputFile)
        }
        
        // Build command arguments similar to MLWorkerProcessInterface but for ml-worker executable
        // Determine engine (default to llama for now)
        let engine = "llama"
        let commandArgs: [String] = ["--engine", engine]
        
        // Build ndjson request
        let request = ContractsCore.MLWorkerRequest(
            requestId: UUID().uuidString,
            runId: "daemon-\(UUID().uuidString)",
            stepId: UUID().uuidString,
            engine: ContractsCore.MLWorkerEngine(rawValue: engine) ?? .llama,
            task: task.toMLTaskKind(),
            inputs: [MLArtifactRef(path: inputFile.path, hash: "input")],
            options: ContractsCore.MLTaskOptions.fromDictionary(options)
        )
        
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        let requestString = String(data: requestData, encoding: .utf8) ?? ""
        
        // Execute ml-worker with request as stdin
        let result = try await executeCommand(
            command: mlWorkerPath,
            arguments: commandArgs,
            stdin: requestString
        )
        
        guard result.exitCode == 0 else {
            throw GenericCoreError("ML worker failed with exit code \(result.exitCode): \(result.stderr)")
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let response = try decoder.decode(ContractsCore.MLWorkerResponse.self, from: Data(result.stdout.utf8))

        guard response.status == ContractsCore.MLWorkerStatus.completed, let firstOutput = response.outputs.first else {
            throw GenericCoreError("ML worker response not successful: \(response.status)")
        }
        
        // Read actual output from artifact
        if FileManager.default.fileExists(atPath: firstOutput.path) {
            let outputData = try Data(contentsOf: URL(fileURLWithPath: firstOutput.path))
            return String(data: outputData, encoding: .utf8) ?? "ML worker response received (decoding failed)"
        }
        
        return "ML worker response received (artifact not found)"
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
            
            // Write stdin data
            let stdinData = Data(stdin.utf8)
            try stdinPipe.fileHandleForWriting.write(contentsOf: stdinData)
            try stdinPipe.fileHandleForWriting.close()
        }
        
        // Set environment
        process.environment = ProcessInfo.processInfo.environment
        
        try process.run()
        
        // Wait for completion with timeout
        var timedOut = false
        let startTime = Date()
        while process.isRunning {
            if Date().timeIntervalSince(startTime) > Double(timeoutSeconds) {
                process.terminate()
                timedOut = true
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        if timedOut {
            throw GenericCoreError("Command timed out after \(timeoutSeconds) seconds")
        }
        
        // Read outputs
        let stdoutData = try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
        let stderrData = try stderrPipe.fileHandleForReading.readToEnd() ?? Data()
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        return (stdout, stderr, process.terminationStatus)
    }
}

// Extensions for type conversions

extension MLWorkerTaskKind {
    func toMLTaskKind() -> ContractsCore.MLWorkerTask {
        switch self {
        case .embedding:
            return .embed
        case .chat:
            return .chat
        case .embed:
            return .embed
        case .generate:
            return .other
        }
    }
}

extension ContractsCore.MLTaskOptions {
    static func fromDictionary(_ dict: [String: AnyHashable]) -> ContractsCore.MLTaskOptions {
        ContractsCore.MLTaskOptions(
            seed: dict["seed"] as? Int ?? 42,
            maxTokens: dict["maxTokens"] as? Int,
            temperature: dict["temperature"] as? Double,
            topP: dict["topP"] as? Double,
            outputDirectory: dict["outputDirectory"] as? String
        )
    }
}
