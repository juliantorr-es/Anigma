import Foundation
import CryptoKit

/// Governed model registry with ModelSpec contracts
@MainActor
public final class ModelRegistry {
    private let registryPath: URL
    private var specs: [String: ModelSpec] = [:]
    private let fileManager = FileManager.default

    public init(registryPath: URL) throws {
        self.registryPath = registryPath

        if !fileManager.fileExists(atPath: registryPath.path) {
            let parent = registryPath.deletingLastPathComponent()
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            let empty: [String: ModelSpec] = [:]
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(empty)
            try data.write(to: registryPath)
        }

        try load()
    }

    private func load() throws {
        let data = try Data(contentsOf: registryPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        specs = try decoder.decode([String: ModelSpec].self, from: data)
    }

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(specs)
        try data.write(to: registryPath, options: .atomic)
    }

    /// Register a new model with governed ModelSpec
    public func register(_ spec: ModelSpec) async throws {
        let specHash = try spec.canonicalHash()
        specs[spec.modelId] = spec
        try save()
    }

    /// Find model by ID
    public func find(id: String) async throws -> ModelSpec? {
        return specs[id]
    }

    /// Query models by criteria
    public func query(
        taskKind: TaskKind? = nil,
        trustTier: TrustTier? = nil,
        backendFormat: String? = nil
    ) async throws -> [ModelSpec] {
        return specs.values.filter { spec in
            if let task = taskKind, spec.taskKind != task {
                return false
            }
            if let tier = trustTier, spec.trustTier != tier {
                return false
            }
            if let backend = backendFormat, spec.backendFormat != backend {
                return false
            }
            return true
        }
    }

    /// Update model trust tier
    public func updateTrustTier(_ id: String, tier: TrustTier) async throws {
        guard let spec = specs[id] else {
            throw ModelRegistryError.notFound(id)
        }

        let updated = ModelSpec(
            modelId: spec.modelId,
            modelHash: spec.modelHash,
            taskKind: spec.taskKind,
            backendFormat: spec.backendFormat,
            dimension: spec.dimension,
            tokenizerHash: spec.tokenizerHash,
            license: spec.license,
            trustTier: tier,
            source: spec.source
        )

        specs[id] = updated
        try save()
    }

    /// Verify model artifact integrity by hash
    public func verifyIntegrity(_ id: String) async throws -> Bool {
        guard let spec = specs[id] else {
            throw ModelRegistryError.notFound(id)
        }

        let artifactPath = URL(fileURLWithPath: spec.source.location)
        guard fileManager.fileExists(atPath: artifactPath.path) else {
            return false
        }

        // Compute hash and compare
        let computedHash = try sha256(artifactPath)
        return computedHash == spec.modelHash
    }

    /// Remove model from registry
    public func delete(_ id: String) async throws {
        guard let spec = specs[id] else {
            throw ModelRegistryError.notFound(id)
        }

        // Only delete file if it's a local or imported model
        if spec.source.type != .bundled {
            let artifactPath = URL(fileURLWithPath: spec.source.location)
            if fileManager.fileExists(atPath: artifactPath.path) {
                try fileManager.removeItem(at: artifactPath)
            }
        }

        specs.removeValue(forKey: id)
        try save()
    }

    /// List all registered models
    public func listAll() async throws -> [ModelSpec] {
        return Array(specs.values)
    }

    private func sha256(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

public enum ModelRegistryError: Error {
    case notFound(String)
    case invalidPath(String)
    case verificationFailed(String)
}
