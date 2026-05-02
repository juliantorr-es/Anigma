import Foundation
import AnigmaSidecar

/// Handles downloading and installing local models
actor ModelInstaller {
    private let config: CLIConfiguration
    private let bridge: SidecarBridge

    init(config: CLIConfiguration, bridge: SidecarBridge) {
        self.config = config
        self.bridge = bridge
    }

    func install(_ model: ModelRecommendation, progress: @escaping (Double) async -> Void) async throws {
        let modelDir = try await config.modelsDirectory()
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let destinationURL = modelDir.appendingPathComponent(model.fileName)

        // Check if already installed via daemon
        let installedModels = try await listInstalled()
        if installedModels.contains(where: { $0.id == model.id }) {
            return
        }

        // Check if file already exists locally
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            // Register with daemon
            try await registerWithDaemon(model: model, path: destinationURL)
            return
        }

        // Download model
        try await downloadModel(url: model.url, destination: destinationURL, progress: progress)

        // Verify download
        try await verifyModel(at: destinationURL)

        // Register with daemon
        try await registerWithDaemon(model: model, path: destinationURL)
    }

    private func downloadModel(
        url: String,
        destination: URL,
        progress: @escaping (Double) async -> Void
    ) async throws {
        guard let downloadURL = URL(string: url) else {
            throw ModelInstallerError.invalidURL(url)
        }

        let session = URLSession.shared
        let (tempURL, response) = try await session.download(from: downloadURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelInstallerError.downloadFailed
        }

        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    private func verifyModel(at url: URL) async throws {
        // Check file exists and is readable
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw ModelInstallerError.verificationFailed
        }

        // Check file size is reasonable (> 100KB)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        guard fileSize > 100_000 else {
            throw ModelInstallerError.verificationFailed
        }
    }

    private func registerWithDaemon(model: ModelRecommendation, path: URL) async throws {
        // Use daemon's model installation with URL as repo parameter
        // The daemon's model registry will handle registration
        let response = try await bridge.installModel(
            modelId: model.id,
            repo: model.url,
            revision: nil,
            name: model.name,
            modelType: model.type.rawValue,
            sizeGB: model.sizeGB,
            quantization: model.quantization
        )
        
        if let error = response.error {
            // If daemon installation fails, that's okay - we still have the local file
            // This allows CLI to work even if daemon model registry has issues
            print("Warning: Failed to register model with daemon: \(error.message)")
        }
    }

    func listInstalled() async throws -> [InstalledModel] {
        let response = try await bridge.listModels()
        
        return response.models.map { modelInfo in
            // Convert ModelInfo to InstalledModel
            // Note: ModelInfo.type is String, we need to map it to ModelType
            let modelType: ModelType
            switch modelInfo.type.lowercased() {
            case "embedding": modelType = .embedding
            case "chat": modelType = .chat
            case "code": modelType = .code
            default: modelType = .chat
            }
            
            return InstalledModel(
                id: modelInfo.id,
                name: modelInfo.name,
                type: modelType,
                sizeGB: modelInfo.sizeGB,
                path: URL(fileURLWithPath: modelInfo.type), // Placeholder - daemon should provide path
                quantization: modelInfo.quantization,
                installedAt: modelInfo.installedAt ?? Date()
            )
        }
    }

    func uninstall(modelID: String) async throws {
        // First try daemon deletion
        let response = try await bridge.deleteModel(modelId: modelID)
        
        if !response.success, let error = response.error {
            // Fall back to local deletion
            throw ModelInstallerError.modelNotFound
        }
        
        // Note: The daemon handles file deletion for its managed models
        // For models downloaded by CLI, we may need additional cleanup
    }
}

struct InstalledModel: Codable {
    let id: String
    let name: String
    let type: ModelType
    let sizeGB: Double
    let path: URL
    let quantization: String
    let installedAt: Date
}

enum ModelInstallerError: Error {
    case invalidURL(String)
    case downloadFailed
    case verificationFailed
    case modelNotFound
}
