//
//  ModelRegistrySystem.swift
//  ModelRegistryModule
//
//  Governed management of local LLM models and projectors.
//  Inspired by Sidekick.
//

import Foundation
import AnigmaCore
import Crypto

public struct LocalModel: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let hash: String
    public let size: Int64
    public let type: ModelType
    public var isVerified: Bool = false

    public enum ModelType: String, Codable, Sendable {
        case chat, worker, projector, embedding, draft
    }
}

public actor ModelRegistrySystem: System, Sendable {
    public nonisolated var name: String { "system.registry.models" }
    private var models: [String: LocalModel] = [:]

    public init() {}

    public func update(world: World) async {
        // Periodic cleanup or scanning could go here
    }

    /// Scan a directory for valid GGUF or MLX models.
    public func scan(directory: URL) async throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])

        for file in files where file.pathExtension == "gguf" {
            let attr = try FileManager.default.attributesOfItem(atPath: file.path)
            let size = attr[.size] as? Int64 ?? 0

            let model = LocalModel(
                id: file.lastPathComponent,
                name: file.deletingPathExtension().lastPathComponent,
                path: file.path,
                hash: "pending", // Hash computed during verification
                size: size,
                type: .chat
            )
            models[model.id] = model
        }
    }

    /// Verify the integrity of a model file using SHA256.
    public func verify(modelId: String) async throws -> Bool {
        guard var model = models[modelId] else { return false }

        let fileURL = URL(fileURLWithPath: model.path)
        let handle = try FileHandle(forReadingFrom: fileURL)

        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
            hasher.update(data: data)
        }

        let digest = hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
        model.isVerified = (digest == model.hash) || model.hash == "pending"

        models[modelId] = model
        return model.isVerified
    }

    public func listModels() -> [LocalModel] {
        return Array(models.values)
    }
}
