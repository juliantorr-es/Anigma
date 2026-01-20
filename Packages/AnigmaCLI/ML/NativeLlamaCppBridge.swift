import Foundation

/// Native llama.cpp bridge for embeddings and inference
/// Uses llama.cpp CLI binaries when available, falls back gracefully
public actor NativeLlamaCppBridge {
    private var loadedModelPath: String?
    private var isEmbeddingMode: Bool = false
    private let llamaCppPath: String?
    private let embeddingPath: String?

    public init() {
        self.llamaCppPath = Self.findLlamaCppBinary("llama-cli")
        self.embeddingPath = Self.findLlamaCppBinary("llama-embedding")
    }

    public func loadModel(path: String, forEmbeddings: Bool = false) async throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LlamaCppBridgeError.modelLoadFailed("Model not found: \(path)")
        }

        if forEmbeddings {
            guard embeddingPath != nil else {
                throw LlamaCppBridgeError.llamaCppNotAvailable
            }
        } else {
            guard llamaCppPath != nil else {
                throw LlamaCppBridgeError.llamaCppNotAvailable
            }
        }

        self.loadedModelPath = path
        self.isEmbeddingMode = forEmbeddings
    }

    public func generateEmbedding(text: String) async throws -> [Float] {
        guard let modelPath = loadedModelPath, isEmbeddingMode else {
            throw LlamaCppBridgeError.notInEmbeddingMode
        }

        guard let binaryPath = embeddingPath else {
            throw LlamaCppBridgeError.llamaCppNotAvailable
        }

        // Write text to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let inputFile = tempDir.appendingPathComponent("embedding_input_\(UUID().uuidString).txt")
        try text.write(to: inputFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: inputFile)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "-m", modelPath,
            "-f", inputFile.path,
            "--embd-normalize", "2",
            "--embd-output-format", "json"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw LlamaCppBridgeError.embeddingExtractionFailed(errorMsg)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        // Parse JSON output
        struct EmbeddingResponse: Decodable {
            let embedding: [Float]
        }

        let response = try JSONDecoder().decode(EmbeddingResponse.self, from: outputData)
        return response.embedding
    }

    public func generateResponse(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        topK: Int = 40
    ) async throws -> String {
        guard let modelPath = loadedModelPath, !isEmbeddingMode else {
            throw LlamaCppBridgeError.notInChatMode
        }

        guard let binaryPath = llamaCppPath else {
            throw LlamaCppBridgeError.llamaCppNotAvailable
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "-m", modelPath,
            "-p", prompt,
            "-n", String(maxTokens),
            "--temp", String(temperature),
            "--top-p", String(topP),
            "--top-k", String(topK),
            "--no-display-prompt"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw LlamaCppBridgeError.decodeFailed(errorMsg)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let response = String(data: outputData, encoding: .utf8) else {
            throw LlamaCppBridgeError.detokenizationFailed("Failed to decode response")
        }

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func generateResponseStream(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        onToken: @escaping (String) -> Void
    ) async throws {
        guard let modelPath = loadedModelPath, !isEmbeddingMode else {
            throw LlamaCppBridgeError.notInChatMode
        }

        guard let binaryPath = llamaCppPath else {
            throw LlamaCppBridgeError.llamaCppNotAvailable
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "-m", modelPath,
            "-p", prompt,
            "-n", String(maxTokens),
            "--temp", String(temperature),
            "--no-display-prompt"
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()

        // Read streaming output
        let handle = outputPipe.fileHandleForReading
        var buffer = ""

        while process.isRunning {
            let data = handle.availableData
            if data.isEmpty { continue }

            if let chunk = String(data: data, encoding: .utf8) {
                buffer += chunk
                // Send complete tokens
                if let lastSpace = buffer.lastIndex(of: " ") {
                    let tokens = buffer[..<lastSpace]
                    onToken(String(tokens))
                    buffer = String(buffer[buffer.index(after: lastSpace)...])
                }
            }
        }

        // Send remaining buffer
        if !buffer.isEmpty {
            onToken(buffer)
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LlamaCppBridgeError.decodeFailed("Process terminated with error")
        }
    }

    private static func findLlamaCppBinary(_ name: String) -> String? {
        let searchPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            ProcessInfo.processInfo.environment["HOME"]! + "/.local/bin/\(name)",
            ProcessInfo.processInfo.environment["LLAMA_CPP_PATH"] ?? ""
        ]

        for path in searchPaths where !path.isEmpty {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try to find via 'which'
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            return nil
        }

        return nil
    }
}

public enum LlamaCppBridgeError: Error, LocalizedError {
    case llamaCppNotAvailable
    case modelLoadFailed(String)
    case contextCreationFailed
    case modelNotLoaded
    case notInEmbeddingMode
    case notInChatMode
    case tokenizationFailed
    case detokenizationFailed(String)
    case decodeFailed(String)
    case embeddingExtractionFailed(String)
    case logitsExtractionFailed

    public var errorDescription: String? {
        switch self {
        case .llamaCppNotAvailable:
            return "llama.cpp binaries not found. Install from https://github.com/ggerganov/llama.cpp"
        case .modelLoadFailed(let msg):
            return "Model load failed: \(msg)"
        case .contextCreationFailed:
            return "Failed to create llama.cpp context"
        case .modelNotLoaded:
            return "No model loaded"
        case .notInEmbeddingMode:
            return "Model not loaded in embedding mode"
        case .notInChatMode:
            return "Model not loaded in chat mode"
        case .tokenizationFailed:
            return "Failed to tokenize input"
        case .detokenizationFailed(let msg):
            return "Failed to detokenize output: \(msg)"
        case .decodeFailed(let msg):
            return "Decode failed: \(msg)"
        case .embeddingExtractionFailed(let msg):
            return "Embedding extraction failed: \(msg)"
        case .logitsExtractionFailed:
            return "Failed to extract logits"
        }
    }
}
