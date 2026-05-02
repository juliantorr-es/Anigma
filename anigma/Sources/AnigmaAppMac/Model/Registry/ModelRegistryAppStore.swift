//
//  ModelRegistryAppStore.swift
//  AnigmaAppMac
//
//  AppStore integration for Model Registry - follows existing MLWorker pattern.
//

import Foundation
import SwiftUI
import Observation
import ContractsCore

/// Observable app store for model registry state
@MainActor
@Observable
public final class ModelRegistryAppStore {
    public var installedModels: [ModelRegistryEntry] = []
    public var selectedModel: ModelRegistryEntry?
    public var isImporting: Bool = false
    public var importProgress: Double = 0.0
    public var importStatus: String = ""
    public var lastError: String?
    public var totalStorageUsed: Int64 = 0

    private var hfAdapter: HuggingFaceAdapter?
    private var modelRegistry: ModelRegistryStore?
    private var isBootstrapped = false

    public init() {}

    public func bootstrap(storagePath: String, artifactStore: URL) async {
        guard !isBootstrapped else {
            return
        }

        do {
            let registry = try await ModelRegistryStore(storagePath: storagePath)
            let adapter = try HuggingFaceAdapter(cacheDir: artifactStore)
            self.modelRegistry = registry
            self.hfAdapter = adapter
            self.isBootstrapped = true
            self.lastError = nil
            await refreshModels()
        } catch {
            self.lastError = "Failed to initialize model registry: \(error.localizedDescription)"
        }
    }

    // MARK: - Public Actions

    public func refreshModels() async {
        guard let modelRegistry else {
            return
        }

        do {
            installedModels = try await modelRegistry.getAllModels()
        } catch {
            lastError = "Failed to load models: \(error.localizedDescription)"
        }
    }

    public func importFromHuggingFace(repo: String, revision: String? = nil) async {
        guard let modelRegistry, let hfAdapter else {
            lastError = "Model registry not ready"
            return
        }

        isImporting = true
        importStatus = "Fetching metadata for \(repo)..."
        importProgress = 0.1
        lastError = nil

        do {
            let descriptor = try await hfAdapter.describe(repo: repo, revision: revision ?? "main")

            guard descriptor.isRunnable else {
                importStatus = "Model not directly runnable"
                lastError = "Unsupported format or missing task classification"
                isImporting = false
                return
            }

            importStatus = "Downloading model files..."
            importProgress = 0.3

            let result = try await hfAdapter.importModel(
                repo: repo,
                revision: revision ?? "main"
            ) { progress in
                Task { @MainActor in
                    self.importProgress = 0.3 + (progress * 0.6)
                }
            }

            let entry = makeRegistryEntry(from: result)
            try await modelRegistry.insertModel(entry)

            importStatus = "Model imported successfully"
            importProgress = 1.0

            if !result.warnings.isEmpty {
                lastError = "Warnings: " + result.warnings.joined(separator: ", ")
            }

            await refreshModels()
        } catch {
            importStatus = "Import failed"
            lastError = error.localizedDescription
        }

        isImporting = false
    }

    public func deleteModel(id: String) async {
        guard let modelRegistry else {
            lastError = "Model registry not ready"
            return
        }

        do {
            try await modelRegistry.deleteModel(id: id)
            await refreshModels()
        } catch {
            lastError = "Failed to delete model: \(error.localizedDescription)"
        }
    }

    public func verifyModel(id: String) async {
        guard let modelRegistry else {
            lastError = "Model registry not ready"
            return
        }

        do {
            _ = try await modelRegistry.getModel(id: id)
            await refreshModels()
        } catch {
            lastError = "Failed to verify model: \(error.localizedDescription)"
        }
    }

    public func find(id: String) async throws -> ModelRegistryEntry? {
        guard let modelRegistry else {
            return nil
        }

        return try await modelRegistry.getModel(id: id)
    }

    private func makeRegistryEntry(from result: ModelImportResult) -> ModelRegistryEntry {
        let spec = result.spec
        let source = (type: "imported", location: spec.id, revision: nil as String?)
        let license = LicenseInfo(
            declared: spec.license.declared,
            allowed: spec.license.allowed,
            reason: spec.license.reason,
            reviewedAt: spec.license.timestamp
        )
        let backendCompatibility = ModelBackendCompatibility(
            supportedBackends: [spec.backend.rawValue],
            preferredBackend: spec.backend.rawValue
        )
        let status: ModelStatus
        switch spec.trustTier {
        case .quarantined:
            status = .quarantined
        case .experimental:
            status = result.conversionNeeded ? .converting : .degraded
        case .firstClass, .compatible:
            status = result.conversionNeeded ? .converting : .ready
        }

        return ModelRegistryEntry(
            modelId: spec.id,
            sourceType: source.type,
            sourceLocation: source.location,
            sourceRevision: source.revision,
            status: status,
            isRunnable: spec.isRunnable,
            taskKind: spec.task.rawValue,
            backendFormat: spec.backend.rawValue,
            dimension: nil,
            installPath: result.installPath,
            storageBytes: spec.storageBytes,
            artifactHash: manifestHash(from: spec.artifactHashes),
            tokenizerHash: spec.tokenizerHash,
            artifactHashes: spec.artifactHashes,
            registeredAt: spec.registeredAt,
            lastVerified: spec.verifiedAt,
            lastUsed: nil,
            usageCount: 0,
            license: license,
            backendCompatibility: backendCompatibility,
            trustTier: spec.trustTier.rawValue,
            conversionReceiptId: spec.conversionReceipt?.toolId
        )
    }

    private func manifestHash(from fileHashes: [String: String]) -> String {
        return ArtifactHashing.manifestHash(from: fileHashes)
    }
}

/// Protocol for audit logging
public protocol AuditLogProtocol: Sendable {
    func log(event: String, metadata: [String: String]) async
}
