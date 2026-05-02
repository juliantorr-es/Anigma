import Foundation

public actor LlamaCppBackend {
    private let modelPath: String
    private var executablePath: String?

    public init(modelPath: String) {
        self.modelPath = modelPath

        // Try to find llama.cpp executable
        let searchPaths = [
            "/usr/local/bin/llama-cli",
            "/opt/homebrew/bin/llama-cli",
            "/usr/bin/llama-cli",
            ProcessInfo.processInfo.environment["HOME"]! + "/.local/bin/llama-cli"
        ]

        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                self.executablePath = path
                break
            }
        }
    }

    public static let shared = LlamaCppBackend(modelPath: "")

    public func isAvailable() async -> Bool {
        return executablePath != nil
    }

    public func loadModel() async throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LlamaCppError.modelNotFound(modelPath)
        }
    }

    public func generate(prompt: String) async throws -> String {
        guard let executable = executablePath else {
            throw LlamaCppError.notAvailable
        }

        return try await runGeneration(
            executable: executable,
            modelPath: modelPath,
            prompt: prompt,
            temperature: 0.7,
            maxTokens: 512
        )
    }

    public func generateEmbeddings(texts: [String], modelPath: String) async throws -> [[Float]] {
        guard let executable = executablePath else {
            throw LlamaCppError.notAvailable
        }

        var results: [[Float]] = []

        for text in texts {
            let embedding = try await runEmbedding(executable: executable, modelPath: modelPath, text: text)
            results.append(embedding)
        }

        return results
    }

    public func chat(prompt: String, modelPath: String, temperature: Double, maxTokens: Int) async throws -> String {
        guard let executable = executablePath else {
            throw LlamaCppError.notAvailable
        }

        return try await runGeneration(
            executable: executable,
            modelPath: modelPath,
            prompt: prompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    private func runGeneration(executable: String, modelPath: String, prompt: String, temperature: Double, maxTokens: Int) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [
            "-m", modelPath,
            "-p", prompt,
            "-n", String(maxTokens),
            "--temp", String(temperature),
            "-c", "8192",
            "-t", "8"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LlamaCppError.inferenceFailed("Process exited with code \(process.terminationStatus)")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw LlamaCppError.inferenceFailed("Failed to decode output")
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runEmbedding(executable: String, modelPath: String, text: String) async throws -> [Float] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [
            "-m", modelPath,
            "-p", text,
            "--embedding",
            "-c", "8192"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LlamaCppError.inferenceFailed("Embedding process failed")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw LlamaCppError.inferenceFailed("Failed to decode embedding")
        }

        let values = output.split(separator: " ").compactMap { Float($0) }
        return values
    }

    public func unload() {
        // No-op for process-based backend
    }
}
