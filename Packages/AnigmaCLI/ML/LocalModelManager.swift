import Foundation

/// Manages local models for both MLX and llama.cpp
@available(macOS 13.0, *)
public actor LocalModelManager {
    public struct ModelInfo: Codable {
        let id: String
        let name: String
        let backend: UnifiedInferenceProvider.Backend
        let size: Int64
        let format: String
        let url: URL
        let capabilities: [String]

        public init(
            id: String,
            name: String,
            backend: UnifiedInferenceProvider.Backend,
            size: Int64,
            format: String,
            url: URL,
            capabilities: [String]
        ) {
            self.id = id
            self.name = name
            self.backend = backend
            self.size = size
            self.format = format
            self.url = url
            self.capabilities = capabilities
        }
    }

    private let modelsDirectory: URL
    private let indexPath: URL

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.modelsDirectory = home.appendingPathComponent(".anigma/models")
        self.indexPath = modelsDirectory.appendingPathComponent("index.json")

        try? FileManager.default.createDirectory(
            at: modelsDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Model Catalog

    nonisolated(unsafe) public static let recommendedModels: [ModelInfo] = [
        // MLX Models
        ModelInfo(
            id: "mlx-llama-3.2-3b",
            name: "Llama 3.2 3B (MLX)",
            backend: .mlx,
            size: 3_200_000_000,
            format: "mlx",
            url: URL(string: "https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit/resolve/main/model.safetensors")!,
            capabilities: ["chat", "instruct"]
        ),
        ModelInfo(
            id: "mlx-qwen-2.5-7b",
            name: "Qwen 2.5 7B (MLX)",
            backend: .mlx,
            size: 7_000_000_000,
            format: "mlx",
            url: URL(string: "https://huggingface.co/mlx-community/Qwen2.5-7B-Instruct-4bit/resolve/main/model.safetensors")!,
            capabilities: ["chat", "code", "instruct"]
        ),
        ModelInfo(
            id: "mlx-phi-3.5-mini",
            name: "Phi 3.5 Mini (MLX)",
            backend: .mlx,
            size: 3_800_000_000,
            format: "mlx",
            url: URL(string: "https://huggingface.co/mlx-community/Phi-3.5-mini-instruct-4bit/resolve/main/model.safetensors")!,
            capabilities: ["chat", "instruct"]
        ),

        // llama.cpp Models (GGUF)
        ModelInfo(
            id: "llama-3.2-3b-gguf",
            name: "Llama 3.2 3B (GGUF Q4)",
            backend: .llamacpp,
            size: 2_100_000_000,
            format: "gguf",
            url: URL(string: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf")!,
            capabilities: ["chat", "instruct"]
        ),
        ModelInfo(
            id: "qwen-2.5-7b-gguf",
            name: "Qwen 2.5 7B (GGUF Q4)",
            backend: .llamacpp,
            size: 4_370_000_000,
            format: "gguf",
            url: URL(string: "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf")!,
            capabilities: ["chat", "code", "instruct"]
        ),
        ModelInfo(
            id: "phi-3.5-mini-gguf",
            name: "Phi 3.5 Mini (GGUF Q4)",
            backend: .llamacpp,
            size: 2_200_000_000,
            format: "gguf",
            url: URL(string: "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf")!,
            capabilities: ["chat", "instruct"]
        ),

        // Embedding Models
        ModelInfo(
            id: "nomic-embed-text-gguf",
            name: "Nomic Embed Text (GGUF)",
            backend: .llamacpp,
            size: 274_000_000,
            format: "gguf",
            url: URL(string: "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf")!,
            capabilities: ["embeddings"]
        ),
        ModelInfo(
            id: "bge-small-en-gguf",
            name: "BGE Small English (GGUF)",
            backend: .llamacpp,
            size: 134_000_000,
            format: "gguf",
            url: URL(string: "https://huggingface.co/CompendiumLabs/bge-small-en-v1.5-gguf/resolve/main/bge-small-en-v1.5-q8_0.gguf")!,
            capabilities: ["embeddings"]
        )
    ]

    // MARK: - Download Management

    public func downloadModel(
        _ model: ModelInfo,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let destinationURL = modelsDirectory
            .appendingPathComponent(model.backend.rawValue)
            .appendingPathComponent("\(model.id).\(model.format)")

        // Create backend-specific directory
        try? FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Check if already downloaded
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("✓ Model already downloaded: \(destinationURL.path)")
            return destinationURL
        }

        print("📥 Downloading \(model.name)...")
        print("   URL: \(model.url)")
        print("   Size: \(ByteCountFormatter.string(fromByteCount: model.size, countStyle: .file))")

        // Download with progress
        let session = URLSession.shared
        let (tempURL, response) = try await session.download(from: model.url) { downloaded, total, _ in
            if total > 0 {
                let percent = Double(downloaded) / Double(total)
                progress(percent)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelDownloadError.downloadFailed
        }

        // Move to final location
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        // Update index
        try await updateIndex(add: model, path: destinationURL)

        print("✓ Downloaded: \(destinationURL.path)")
        return destinationURL
    }

    public func listInstalledModels() async throws -> [ModelInfo] {
        guard FileManager.default.fileExists(atPath: indexPath.path) else {
            return []
        }

        let data = try Data(contentsOf: indexPath)
        return try JSONDecoder().decode([ModelInfo].self, from: data)
    }

    public func getModelPath(id: String) async throws -> URL? {
        let installed = try await listInstalledModels()
        guard let model = installed.first(where: { $0.id == id }) else {
            return nil
        }

        let path = modelsDirectory
            .appendingPathComponent(model.backend.rawValue)
            .appendingPathComponent("\(model.id).\(model.format)")

        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    public func deleteModel(id: String) async throws {
        guard let path = try await getModelPath(id: id) else {
            throw ModelDownloadError.modelNotFound
        }

        try FileManager.default.removeItem(at: path)
        try await updateIndex(removeId: id)
        print("✓ Deleted model: \(id)")
    }

    // MARK: - Index Management

    private func updateIndex(add model: ModelInfo, path: URL) async throws {
        var models = (try? await listInstalledModels()) ?? []
        models.removeAll { $0.id == model.id }
        models.append(model)

        let data = try JSONEncoder().encode(models)
        try data.write(to: indexPath)
    }

    private func updateIndex(removeId id: String) async throws {
        var models = try await listInstalledModels()
        models.removeAll { $0.id == id }

        let data = try JSONEncoder().encode(models)
        try data.write(to: indexPath)
    }

    // MARK: - Recommendations

    public func recommendModels(
        for capabilities: [String],
        backend: UnifiedInferenceProvider.Backend? = nil,
        maxSize: Int64? = nil
    ) -> [ModelInfo] {
        var models = Self.recommendedModels

        if let backend = backend {
            models = models.filter { $0.backend == backend }
        }

        if let maxSize = maxSize {
            models = models.filter { $0.size <= maxSize }
        }

        if !capabilities.isEmpty {
            models = models.filter { model in
                capabilities.allSatisfy { model.capabilities.contains($0) }
            }
        }

        return models.sorted { $0.size < $1.size }
    }
}

public enum ModelDownloadError: Error {
    case downloadFailed
    case modelNotFound
    case invalidURL
}

// Extension to URLSession for progress tracking
extension URLSession {
    func download(
        from url: URL,
        progress: @escaping @Sendable (Int64, Int64, Error?) -> Void
    ) async throws -> (URL, URLResponse) {
        let delegate = DownloadDelegate(progress: progress)
        let (tempURL, response) = try await download(for: URLRequest(url: url), delegate: delegate)
        return (tempURL, response)
    }
}

private final class DownloadDelegate: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    let progress: @Sendable (Int64, Int64, Error?) -> Void

    init(progress: @escaping @Sendable (Int64, Int64, Error?) -> Void) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progress(totalBytesWritten, totalBytesExpectedToWrite, nil)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Required delegate method
    }
}
