import Foundation

/// Handles downloading and installing local models
actor ModelInstaller {
    private let config: CLIConfiguration
    private let database: CLIDatabase

    init(config: CLIConfiguration, database: CLIDatabase) {
        self.config = config
        self.database = database
    }

    func install(_ model: ModelRecommendation, progress: @escaping (Double) async -> Void) async throws {
        let modelDir = try await config.modelsDirectory()
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let destinationURL = modelDir.appendingPathComponent(model.fileName)

        // Check if already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try await recordInstallation(model, path: destinationURL)
            return
        }

        // Download model
        try await downloadModel(url: model.url, destination: destinationURL, progress: progress)

        // Verify download
        try await verifyModel(at: destinationURL)

        // Record in database
        try await recordInstallation(model, path: destinationURL)
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

    private func recordInstallation(_ model: ModelRecommendation, path: URL) async throws {
        let statement = """
            INSERT INTO installed_models (
                id, name, type, size_gb, path, quantization, installed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                installed_at = excluded.installed_at
            """

        try await database.execute(
            statement,
            params: [
                .text(model.id),
                .text(model.name),
                .text(model.type.rawValue),
                .real(model.sizeGB),
                .text(path.path),
                .text(model.quantization),
                .integer(Int64(Date().timeIntervalSince1970))
            ]
        )
    }

    func listInstalled() async throws -> [InstalledModel] {
        let statement = "SELECT * FROM installed_models ORDER BY installed_at DESC"
        let rows = try await database.query(statement)

        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let name = row["name"] as? String,
                  let typeStr = row["type"] as? String,
                  let type = ModelType(rawValue: typeStr),
                  let sizeGB = row["size_gb"] as? Double,
                  let path = row["path"] as? String else {
                return nil
            }

            return InstalledModel(
                id: id,
                name: name,
                type: type,
                sizeGB: sizeGB,
                path: URL(fileURLWithPath: path),
                quantization: row["quantization"] as? String ?? "unknown",
                installedAt: Date(timeIntervalSince1970: row["installed_at"] as? Double ?? 0)
            )
        }
    }

    func uninstall(modelID: String) async throws {
        // Get model path
        let statement = "SELECT path FROM installed_models WHERE id = ?"
        let rows = try await database.query(statement, params: [.text(modelID)])

        guard let path = rows.first?["path"] as? String else {
            throw ModelInstallerError.modelNotFound
        }

        // Delete file
        try FileManager.default.removeItem(atPath: path)

        // Remove from database
        let deleteStatement = "DELETE FROM installed_models WHERE id = ?"
        try await database.execute(deleteStatement, params: [.text(modelID)])
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
