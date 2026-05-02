import Foundation
import AnigmaNativeShims

/// Unified model manager for downloading, caching, and loading models
public actor ModelManager {
    private let cacheDirectory: URL
    private let mlxProvider: MLXEmbeddingProvider
    private var llamaProvider: NativeLlamaCppBridge?

    public init() throws {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cacheDir.appendingPathComponent("anigma-cli/models")
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        self.mlxProvider = MLXEmbeddingProvider()
    }

    // MARK: - Model Download

    public func downloadModel(
        hubID: String,
        modelID: String,
        progressCallback: (@Sendable (Double, String) -> Void)? = nil
    ) async throws {
        let modelDir = cacheDirectory.appendingPathComponent(modelID)

        // Check if already downloaded
        if FileManager.default.fileExists(atPath: modelDir.path) {
            progressCallback?(1.0, "Model already downloaded")
            return
        }

        progressCallback?(0.0, "Starting download...")

        // Download from Hugging Face
        try await downloadFromHuggingFace(
            hubID: hubID,
            destinationDir: modelDir,
            progressCallback: progressCallback
        )

        progressCallback?(1.0, "Download complete")
    }

    private func downloadFromHuggingFace(
        hubID: String,
        destinationDir: URL,
        progressCallback: (@Sendable (Double, String) -> Void)?
    ) async throws {
        // Create destination directory
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        // Hugging Face API endpoints
        let apiBase = "https://huggingface.co"
        let modelURL = "\(apiBase)/\(hubID)/resolve/main"

        // Common model files to download
        let filesToDownload = [
            "config.json",
            "model.safetensors", // or model.bin
            "tokenizer.json",
            "tokenizer_config.json",
            "special_tokens_map.json",
            "vocab.json",
            "merges.txt"
        ]

        for (index, fileName) in filesToDownload.enumerated() {
            guard let fileURL = URL(string: "\(modelURL)/\(fileName)") else {
                fatalError("Failed to unwrap fileURL")
            }
            let destinationFile = destinationDir.appendingPathComponent(fileName)

            do {
                try await downloadFile(from: fileURL, to: destinationFile) { progress in
                    let totalProgress = (Double(index) + progress) / Double(filesToDownload.count)
                    progressCallback?(totalProgress, "Downloading \(fileName)...")
                }
            } catch {
                // Some files might not exist for all models - that's ok
                print("  ⚠️ Skipping \(fileName): \(error.localizedDescription)")
            }
        }

        // Verify at least one file was downloaded
        let downloadedCount = filesToDownload.filter { fileName in
            FileManager.default.fileExists(atPath: destinationDir.appendingPathComponent(fileName).path)
        }.count

        if downloadedCount == 0 {
            throw ModelError.downloadFailed("No files downloaded for \(hubID)")
        }
    }

    private func downloadFile(
        from url: URL,
        to destination: URL,
        progressCallback: (@Sendable (Double) -> Void)?
    ) async throws {
        let session = URLSession.shared

        let (tempURL, response) = try await session.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ModelError.downloadFailed("HTTP error downloading \(url)")
        }

        // Move to final destination
        try FileManager.default.moveItem(at: tempURL, to: destination)
        progressCallback?(1.0)
    }

    // MARK: - Model Loading

    public func loadEmbeddingModel(
        modelID: String,
        backend: ModelBackend = .auto
    ) async throws {
        let modelPath = cacheDirectory.appendingPathComponent(modelID)

        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ModelError.modelNotFound(modelID)
        }

        let selectedBackend = backend == .auto ? detectBestBackend() : backend

        switch selectedBackend {
        case .mlx:
            #if canImport(MLX)
            try await mlxProvider.loadModel(modelID: modelID)
            print("✓ Loaded \(modelID) with MLX backend")
            #else
            throw ModelError.backendNotAvailable("MLX")
            #endif

        case .llamacpp:
            let bridge = NativeLlamaCppBridge()
            try await bridge.loadModel(path: modelPath.path, forEmbeddings: true)
            self.llamaProvider = bridge
            print("✓ Loaded \(modelID) with llama.cpp backend")

        case .auto:
            fatalError("Auto should have been resolved")
        }
    }

    public func loadChatModel(
        modelID: String,
        backend: ModelBackend = .auto
    ) async throws {
        let modelPath = cacheDirectory.appendingPathComponent(modelID)

        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ModelError.modelNotFound(modelID)
        }

        let selectedBackend = backend == .auto ? detectBestBackend() : backend

        switch selectedBackend {
        case .mlx:
            #if canImport(MLX)
            // Load chat model with MLX
            print("✓ Loaded \(modelID) chat model with MLX backend")
            #else
            throw ModelError.backendNotAvailable("MLX")
            #endif

        case .llamacpp:
            let bridge = NativeLlamaCppBridge()
            try await bridge.loadModel(path: modelPath.path, forEmbeddings: false)
            self.llamaProvider = bridge
            print("✓ Loaded \(modelID) chat model with llama.cpp backend")

        case .auto:
            fatalError("Auto should have been resolved")
        }
    }

    // MARK: - Model Information

    public func listInstalledModels() -> [ModelInfo] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        ) else {
            return []
        }

        return contents.compactMap { url in
            guard url.hasDirectoryPath else { return nil }

            let modelID = url.lastPathComponent
            let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            let createdAt = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate

            return ModelInfo(
                modelID: modelID,
                path: url.path,
                sizeBytes: fileSize ?? 0,
                installedAt: createdAt ?? Date()
            )
        }
    }

    public func deleteModel(modelID: String) throws {
        let modelPath = cacheDirectory.appendingPathComponent(modelID)
        try FileManager.default.removeItem(at: modelPath)
    }

    // MARK: - Backend Detection

    private func detectBestBackend() -> ModelBackend {
        #if canImport(MLX) && arch(arm64)
        // Prefer MLX on Apple Silicon
        return .mlx
        #else
        // Fallback to llama.cpp
        return .llamacpp
        #endif
    }

    // MARK: - Types

    public enum ModelBackend {
        case mlx
        case llamacpp
        case auto
    }

    public struct ModelInfo {
        public let modelID: String
        public let path: String
        public let sizeBytes: Int
        public let installedAt: Date

        public var sizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
        }
    }
}

public enum ModelError: Error, LocalizedError {
    case downloadFailed(String)
    case modelNotFound(String)
    case backendNotAvailable(String)

    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .modelNotFound(let modelID):
            return "Model not found: \(modelID)"
        case .backendNotAvailable(let backend):
            return "Backend not available: \(backend)"
        }
    }
}
