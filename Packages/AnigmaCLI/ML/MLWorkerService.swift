import Foundation
import MLWorkerCommon
import ContractsCore

/// Service to interact with the ml-worker subprocess
public actor MLWorkerService {
    public static let shared = MLWorkerService()

    private init() {}

    public func chat(
        modelPath: String,
        prompt: String,
        maxTokens: Int = 1024,
        temperature: Double = 0.7,
        engine: MLWorkerEngine = .mlx,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let requestId = UUID().uuidString
        let inputPath = FileManager.default.temporaryDirectory.appendingPathComponent("chat_input_\(requestId).txt")
        try prompt.write(to: inputPath, atomically: true, encoding: .utf8)

        let request = MLWorkerCommon.MLWorkerRequest(
            requestId: requestId,
            runId: "chat-session",
            stepId: "step-1",
            engine: engine,
            task: .chat,
            inputs: [MLWorkerCommon.MLArtifactRef(path: inputPath.path, hash: "")],
            options: MLTaskOptions(
                seed: 42,
                maxTokens: maxTokens,
                temperature: temperature,
                topP: 0.9,
                outputDirectory: nil
            )
        )

        let response = try await runWorker(request: request, onProgress: onProgress)

        try? FileManager.default.removeItem(at: inputPath)

        guard let output = response.outputs.first else {
            throw MLError.backendNotAvailable("No output from ml-worker")
        }

        return try String(contentsOfFile: output.path, encoding: .utf8)
    }

    private func runWorker(request: MLWorkerCommon.MLWorkerRequest, onProgress: (@Sendable (String) -> Void)? = nil) async throws -> MLWorkerCommon.MLWorkerResponse {
        guard let workerPath = resolveWorkerPath() else {
            throw MLError.backendNotAvailable("ml-worker binary not found")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: workerPath)
        process.arguments = ["--engine", request.engine.rawValue]

        let env = ProcessInfo.processInfo.environment
        process.environment = env

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Handle stderr streaming for progress
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                // Filter empty lines and clean up
                let lines = text.split(separator: "\n").map(String.init)
                for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    onProgress?(line)
                }
            }
        }

        try process.run()

        let encoder = JSONEncoder()
        let payload = try encoder.encode(request)
        try inputPipe.fileHandleForWriting.write(contentsOf: payload + Data("\n".utf8))
        try inputPipe.fileHandleForWriting.close()

        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()

        // Clean up handler
        errorPipe.fileHandleForReading.readabilityHandler = nil

        if process.terminationStatus != 0 {
            // Read any remaining stderr
            let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw MLError.backendNotAvailable("ml-worker failed: \(errorText)")
        }

        let responseLine = outputData.split(separator: 10).first
        guard let lineData = responseLine else {
            throw MLError.backendNotAvailable("Empty response from ml-worker")
        }

        return try JSONDecoder().decode(MLWorkerCommon.MLWorkerResponse.self, from: lineData)
    }

    private func resolveWorkerPath() -> String? {
        // Try to find ml-worker relative to current executable
        let bundleURL = Bundle.main.bundleURL
        let candidate = bundleURL.deletingLastPathComponent().appendingPathComponent("ml-worker")
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate.path
        }

        // Fallback to build directory (for dev)
        let cwd = FileManager.default.currentDirectoryPath
        let buildCandidate = "\(cwd)/.build/release/ml-worker"
        if FileManager.default.isExecutableFile(atPath: buildCandidate) {
            return buildCandidate
        }

        return nil
    }
}
